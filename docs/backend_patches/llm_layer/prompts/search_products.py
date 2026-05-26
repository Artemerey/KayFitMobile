"""
app/llm/prompts/search_products.py
Промпт для поиска продуктов и получения нутриентов на 100г.
"""


def build_prompt(query: str, limit: int = 3) -> str:
    return f"""\
Give exactly {limit} product or dish variants for the food query below.
For each provide accurate nutrients per 100 g using USDA or Skurikhin tables as reference.

Return JSON only:
{{
  "products": [
    {{
      "name": "название продукта на русском",
      "calories": <number>,
      "protein": <number>,
      "fat": <number>,
      "carbs": <number>,
      "fiber": <number>,
      "sugar": <number>,
      "sugar_alcohols": <number>,
      "saturated_fat": <number>,
      "unsaturated_fat": <number>,
      "glycemic_index": <number or null>,
      "calories_per_piece": <number or null>,
      "protein_per_piece": <number or null>,
      "fat_per_piece": <number or null>,
      "carbs_per_piece": <number or null>
    }}
  ]
}}

Data accuracy rules:
- saturated_fat + unsaturated_fat must be ≤ fat
- fiber + sugar must be ≤ carbs
- calories ≈ protein*4 + carbs*4 + fat*9 (allow ±5%)
- Add per_piece fields only for naturally piece-portioned foods (fruit, egg, bread roll)
- Set per_piece fields to null for all other products

Query: "{query}"\
"""
