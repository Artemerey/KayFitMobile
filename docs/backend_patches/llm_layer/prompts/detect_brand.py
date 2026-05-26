"""
app/llm/prompts/detect_brand.py
Промпт для определения — упоминается ли бренд в запросе.
"""


def build_prompt(query: str) -> str:
    return (
        f'Does this food description mention a specific brand or trademark '
        f'(e.g. "Coca-Cola", "Простоквашино", "Danone", "Lay\'s", "Activia")? '
        f'Return JSON only: {{"is_brand": true}} or {{"is_brand": false}}. '
        f'Description: "{query.strip()}"'
    )
