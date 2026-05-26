"""
ПАТЧ: app/services/parse_meal_qwen.py
ЗАМЕНИТЬ: parse_meal_with_claude() в services.py
УБРАТЬ: import anthropic, _get_anthropic_client
Drop-in замена — идентичный интерфейс и возвращаемая структура.
"""
import asyncio
import json
import logging

from app.llm import router
from app.llm.errors import LLMUnavailable
from app.llm.prompts.parse_meal import SYSTEM_PROMPT

# TODO: confirm these paths match the server's services.py before deploy
from app.services import _has_cyrillic, search_food  # noqa: E402

logger = logging.getLogger(__name__)


async def parse_meal_with_qwen(text: str) -> dict:
    """
    Разбирает текстовое описание приёма пищи на ингредиенты.
    Идентична интерфейсу parse_meal_with_claude — drop-in замена.
    """
    raw = (text or "").strip()
    if not raw:
        return {"error": "Введите описание приёма пищи"}

    try:
        provider = router.get_text_provider()
        response_str = await provider.complete(
            system=SYSTEM_PROMPT,
            user=raw,
            model=router.text_model(),
            max_tokens=800,
            temperature=0.0,
        )
        data = json.loads(response_str)
        items_in = data.get("items") or []
    except LLMUnavailable as exc:
        return {"error": f"Сервис временно недоступен: {exc}"}
    except (json.JSONDecodeError, KeyError) as exc:
        return {"error": f"Ошибка разбора ответа: {exc}"}

    # Параллельный поиск в БД — логика идентична parse_meal_claude.py
    search_tasks = []
    item_data = []

    for it in items_in:
        name = (it.get("name") or "").strip()
        if not name:
            continue
        try:
            w = float(it.get("weight_grams") or 100)
        except (TypeError, ValueError):
            w = 100.0
        search_tasks.append(search_food(name))  # существующая функция из services.py
        item_data.append((name, w))

    search_results = await asyncio.gather(*search_tasks)

    items_out = []
    total_cal = total_p = total_f = total_c = 0.0
    names_for_summary = []

    for (name, w), row in zip(item_data, search_results):
        if not row:
            items_out.append({
                "name": name, "weight_grams": w, "found": False,
                "calories": 0, "protein": 0, "fat": 0, "carbs": 0,
            })
            continue

        _, food_name, cal, prot, fat, carb = row
        if _has_cyrillic(name) and not _has_cyrillic(food_name):
            food_name = name

        k = w / 100.0
        c, p, f, carb_v = cal * k, prot * k, fat * k, carb * k
        total_cal += c
        total_p += p
        total_f += f
        total_c += carb_v
        names_for_summary.append(name)

        items_out.append({
            "name": food_name,
            "weight_grams": round(w, 0),
            "found": True,
            "calories": round(c, 1),
            "protein": round(p, 1),
            "fat": round(f, 1),
            "carbs": round(carb_v, 1),
        })

    summary_name = ", ".join(names_for_summary[:5])
    if len(names_for_summary) > 5:
        summary_name += " и др."

    return {
        "items": items_out,
        "total": {
            "calories": round(total_cal, 1),
            "protein": round(total_p, 1),
            "fat": round(total_f, 1),
            "carbs": round(total_c, 1),
        },
        "summary_name": summary_name or "Приём пищи",
    }
