"""
ПАТЧ: app/services/recognize_photo_qwen.py
ЗАМЕНИТЬ: текущую функцию recognize_photo в services.py (или recognize_photo_v2.py)
УБРАТЬ: import anthropic, _get_anthropic_client, ANTHROPIC_API_KEY
ДОБАВИТЬ: from app.llm import router, from app.llm.image_utils import preprocess_image

Стратегия: Variant B — ингредиентная декомпозиция.
Фаза 1: КБЖУ не считаем, возвращаем нулевые suggestions.
         В Фазе 3 заменить _empty_suggestion() на nutrition_lookup(name).
"""
import json
import logging

from app.llm import router
from app.llm.errors import LLMInvalidSchema, LLMUnavailable
from app.llm.image_utils import preprocess_image
from app.llm.prompts.recognize_photo import SYSTEM_PROMPT, USER_PROMPT

logger = logging.getLogger(__name__)

# Пороги деградации
_MIN_TOTAL_WEIGHT_G = 20
_MIN_INGREDIENTS = 1


async def recognize_photo(image_data: bytes, language: str = "ru") -> dict:
    """
    Распознаёт ингредиенты на фото через Qwen3-VL-Flash.
    При деградации (0 ингредиентов / суммарный вес < 20г / невалидный JSON)
    повторяет через qwen3-vl-plus.

    Возвращает:
    {
        "items": [
            {
                "name": str,
                "weight_grams": float,
                "confidence": float,
                "suggestions": [<нулевой stub>],
                "source": "qwen",
            }
        ],
        "dish_name": str | None,
        "error": str | None,
    }
    """
    provider = router.get_vision_provider()
    image_b64 = preprocess_image(image_data)

    # Попытка 1: qwen3-vl-flash
    data = await _call_vision(provider, image_b64, model=router.vision_model())

    # Fallback на plus при деградации
    if _is_degraded(data):
        logger.info("recognize_photo: degraded on flash → retrying with plus")
        data = await _call_vision(
            provider, image_b64, model=router.vision_model_fallback()
        )

    if data is None:
        return {"items": [], "dish_name": None, "error": "recognition_unavailable"}

    if "error" in data:
        # Модель ответила {"error": "no_food_detected"}
        return {"items": [], "dish_name": None, "error": data["error"]}

    dish_name = (data.get("dish_name") or "").strip() or None
    raw_ingredients = data.get("ingredients") or []

    items_out = []
    for ing in raw_ingredients:
        name = (ing.get("name") or "").strip()
        if not name:
            continue

        weight_grams = _safe_float(ing.get("weight_grams"), default=100.0)
        confidence = _safe_float(ing.get("confidence"), default=0.8)

        # Фаза 1: нулевые suggestions без КБЖУ.
        # TODO Фаза 3: заменить на nutrition_lookup(name, weight_grams)
        suggestion = _empty_suggestion(name)

        items_out.append({
            "name": name,
            "weight_grams": weight_grams,
            "confidence": confidence,
            "suggestions": [suggestion],
            "source": "qwen",
        })

    return {"items": items_out, "dish_name": dish_name, "error": None}


# ── helpers ───────────────────────────────────────────────────────────────

async def _call_vision(provider, image_b64: str, *, model: str) -> dict | None:
    try:
        raw = await provider.complete_vision(
            SYSTEM_PROMPT,
            USER_PROMPT,
            image_b64,
            model=model,
            max_tokens=1200,
            temperature=0.0,
        )
        return json.loads(raw)
    except (LLMInvalidSchema, LLMUnavailable, json.JSONDecodeError) as exc:
        logger.warning("_call_vision model=%s error: %s", model, exc)
        return None


def _is_degraded(data: dict | None) -> bool:
    if data is None:
        return True
    if data.get("error") == "no_food_detected":
        return False  # корректный ответ "нет еды" — не деградация
    if "error" in data:
        return True  # любой другой error-ключ — деградация, пробуем plus
    ingredients = data.get("ingredients") or []
    if len(ingredients) < _MIN_INGREDIENTS:
        return True
    total = sum(_safe_float(i.get("weight_grams")) for i in ingredients)
    return total < _MIN_TOTAL_WEIGHT_G


def _empty_suggestion(name: str) -> dict:
    """Нулевой stub для Фазы 1. В Фазе 3 заменить на реальный lookup."""
    return {
        "id": 0,
        "name": name,
        "calories": 0.0,
        "protein": 0.0,
        "fat": 0.0,
        "carbs": 0.0,
        "calories_per_100g": 0.0,
        "protein_per_100g": 0.0,
        "fat_per_100g": 0.0,
        "carbs_per_100g": 0.0,
        "fiber_per_100g": 0.0,
        "sugar_per_100g": 0.0,
        "sugar_alcohols_per_100g": 0.0,
        "saturated_fat_per_100g": 0.0,
        "unsaturated_fat_per_100g": 0.0,
        "glycemic_index": None,
        "source": "qwen",
    }


def _safe_float(val, default: float = 0.0) -> float:
    if val is None:
        return default
    try:
        return round(float(val), 1)
    except (TypeError, ValueError):
        return default
