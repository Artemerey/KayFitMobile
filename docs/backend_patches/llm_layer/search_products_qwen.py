"""
ПАТЧ: app/services/search_products_qwen.py
ЗАМЕНИТЬ: search_products_claude(), _detect_brand_claude() в services.py
УБРАТЬ: import anthropic, _get_anthropic_client
СОХРАНИТЬ БЕЗ ИЗМЕНЕНИЙ: _suggestion_row(), search_products_web()
  (только поменять source="qwen" / source="web+qwen")

Минимальный diff — только точки вызова Claude заменяются на Qwen.
"""
import json
import logging

from app.llm import router
from app.llm.errors import LLMUnavailable
from app.llm.prompts.detect_brand import build_prompt as detect_brand_prompt
from app.llm.prompts.search_products import build_prompt as search_prompt

# TODO: confirm these paths match the server's services.py before deploy
from app.services import search_food_multi, search_products_web  # noqa: E402

logger = logging.getLogger(__name__)


# ── detect_brand ──────────────────────────────────────────────────────────

async def _detect_brand_qwen(query: str) -> bool:
    """Определяет — упоминается ли бренд. Замена _detect_brand_claude."""
    if not (query or "").strip():
        return False
    try:
        provider = router.get_text_provider()
        raw = await provider.complete(
            system="",
            user=detect_brand_prompt(query),
            model=router.text_model(),
            max_tokens=20,
            temperature=0.0,
        )
        data = json.loads(raw)
        return bool(data.get("is_brand", False))
    except Exception as exc:
        logger.warning("_detect_brand_qwen error: %s", exc)
        return False  # безопасный default


# ── search_products ───────────────────────────────────────────────────────

async def search_products_qwen(query: str, limit: int = 3) -> list:
    """
    Ищет продукты/блюда через Qwen и возвращает список _suggestion_row.
    Замена search_products_claude().
    """
    if not (query or "").strip():
        return []

    try:
        provider = router.get_text_provider()
        raw = await provider.complete(
            system="",
            user=search_prompt(query, limit),
            model=router.text_model(),
            max_tokens=1000,
            temperature=0.0,
        )
        data = json.loads(raw)
        products = data.get("products") or []
    except (LLMUnavailable, json.JSONDecodeError) as exc:
        logger.warning("search_products_qwen error: %s", exc)
        return []

    results = []
    for p in products[:limit]:
        name = (p.get("name") or "").strip()
        if not name:
            continue

        per_piece = None
        if p.get("calories_per_piece") is not None:
            per_piece = {
                "calories": _sf(p.get("calories_per_piece")),
                "protein":  _sf(p.get("protein_per_piece")),
                "fat":      _sf(p.get("fat_per_piece")),
                "carbs":    _sf(p.get("carbs_per_piece")),
            }

        results.append(_suggestion_row(
            name=name,
            calories=_sf(p.get("calories")),
            protein=_sf(p.get("protein")),
            fat=_sf(p.get("fat")),
            carbs=_sf(p.get("carbs")),
            fiber=_sf(p.get("fiber")),
            sugar=_sf(p.get("sugar")),
            sugar_alcohols=_sf(p.get("sugar_alcohols")),
            saturated_fat=_sf(p.get("saturated_fat")),
            unsaturated_fat=_sf(p.get("unsaturated_fat")),
            glycemic_index=p.get("glycemic_index"),
            per_piece=per_piece,
            source="qwen",
        ))

    return results


# ── get_product_suggestions (точка входа) ────────────────────────────────

async def get_product_suggestions(query: str, limit: int = 3) -> list:
    """
    Замена текущей get_product_suggestions в services.py.
    Логика роутинга: бренд → web+qwen, иначе → локальная БД → qwen.
    """
    query = (query or "").strip()
    if not query:
        return []

    is_brand = await _detect_brand_qwen(query)

    if is_brand:
        # Для брендов — веб-поиск + Qwen-извлечение
        # search_products_web остаётся без изменений, только source="web+qwen"
        return await search_products_web(query, limit)

    # Сначала локальная БД
    db_results = await search_food_multi(query, limit)  # существующая функция
    if db_results and len(db_results) >= limit:
        return db_results

    # Добираем из Qwen
    qwen_results = await search_products_qwen(query, limit - len(db_results))
    return db_results + qwen_results


# ── _suggestion_row — БЕЗ ИЗМЕНЕНИЙ (скопировать из search_products_openai_v2.py) ──

def _suggestion_row(
    name: str,
    calories: float,
    protein: float,
    fat: float,
    carbs: float,
    id_val: int = 0,
    per_piece: dict = None,
    fiber: float = 0,
    sugar: float = 0,
    sugar_alcohols: float = 0,
    saturated_fat: float = 0,
    unsaturated_fat: float = 0,
    glycemic_index: int | None = None,
    source: str = "qwen",
) -> dict:
    """Единый формат варианта продукта: КБЖУ + расширенные нутриенты на 100 г."""
    row = {
        "id": id_val,
        "name": name,
        "calories": round(float(calories), 1),
        "protein": round(float(protein), 1),
        "fat": round(float(fat), 1),
        "carbs": round(float(carbs), 1),
        "calories_per_100g": round(float(calories), 1),
        "protein_per_100g": round(float(protein), 1),
        "fat_per_100g": round(float(fat), 1),
        "carbs_per_100g": round(float(carbs), 1),
        "fiber_per_100g": round(float(fiber), 1),
        "sugar_per_100g": round(float(sugar), 1),
        "sugar_alcohols_per_100g": round(float(sugar_alcohols), 1),
        "saturated_fat_per_100g": round(float(saturated_fat), 1),
        "unsaturated_fat_per_100g": round(float(unsaturated_fat), 1),
        "glycemic_index": glycemic_index,
        "source": source,
    }
    if per_piece:
        row["per_piece"] = per_piece
    return row


def _sf(val, default: float = 0.0) -> float:
    if val is None:
        return default
    try:
        return round(float(val), 1)
    except (TypeError, ValueError):
        return default
