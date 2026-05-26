# Phase 3: КБЖУ Pipeline Spec

**Дата:** 2026-05-25  
**Статус:** Ready for implementation (after Фазы 1+2)  
**Зависимости:** провайдерный слой `app/llm/` (готов), USDA локальная БД (есть на сервере), FatSecret Premier credentials (получены от James)

---

## 1. Архитектура

### Pipeline (per ingredient)

```
recognize_photo_qwen.py → items[i] = {name, weight_grams, confidence}
        │
        ▼
nutrition_lookup(name, weight_grams)              [app/services/nutrition/lookup.py]
        │
        ├─► Step 1: USDA local (sync, ~5ms)
        │     │
        │     ├─ usda_cache.get(name) → hit? return
        │     │
        │     ├─ qwen_normalizer.normalize(name)    [qwen-turbo, cached]
        │     │   "grilled chicken" → "Chicken, broilers or fryers, breast,
        │     │                       meat only, cooked, roasted"
        │     │
        │     ├─ usda_repo.find_exact(normalized)
        │     │
        │     └─ если miss → usda_repo.substring_search(normalized) or (raw name)
        │
        │   ✓ найдено → NutritionFacts(source="usda")
        │   ✗ не найдено ▼
        │
        ├─► Step 2: FatSecret Premier autocomplete (HTTP, ~200ms)
        │     │
        │     ├─ rate_limiter.check() → RPD не превышен
        │     ├─ fatsecret_client.autocomplete(normalized) → top-1 match
        │     ├─ fatsecret_client.food_get(food_id) → per-100g facts
        │     └─ fatsecret_cache.set(name, facts)
        │
        │   ✓ найдено → NutritionFacts(source="fatsecret")
        │   ✗ не найдено / rate-limit / network error ▼
        │
        └─► Step 3: Qwen-turbo fallback (~600ms)
              │
              ├─ qwen_nutrition.estimate(name) → JSON {kcal, p, f, c per 100g}
              └─ nutrition_cache.set(name, facts, ttl=30d)
        │
        ▼
NutritionFacts (per 100g) × (weight_grams / 100)
        │
        ▼
suggestion dict (тот же shape, что _empty_suggestion в recognize_photo_qwen.py)
```

### Контракт результата

`nutrition_lookup` возвращает `NutritionFacts` — иммутабельный dataclass per-100g:

```python
@dataclass(frozen=True)
class NutritionFacts:
    name_used: str               # имя, по которому реально нашли
    calories_per_100g: float
    protein_per_100g: float
    fat_per_100g: float
    carbs_per_100g: float
    fiber_per_100g: float = 0.0
    sugar_per_100g: float = 0.0
    saturated_fat_per_100g: float = 0.0
    source: str                  # "usda" | "fatsecret" | "qwen"
    confidence: float            # 1.0 USDA, 0.8 FatSecret, 0.5 Qwen
```

Конвертация в существующий `suggestion` dict — в одном месте: `to_suggestion(facts, weight_grams)`.

---

## 2. USDA Normalizer

### Зачем

Локальная USDA БД содержит ингредиенты в строгом формате (`"Chicken, broilers or fryers, breast, meat only, cooked, roasted"`), а Qwen возвращает разговорные имена (`"grilled chicken breast"`, `"жареная картошка"`). Прямой substring-поиск даёт низкий hit-rate. Промежуточный qwen-turbo-нормализатор переводит произвольное имя в каноническую USDA-форму.

### Промпт нормализатора

Файл: `app/llm/prompts/usda_normalizer.py`

```python
SYSTEM_PROMPT = """You are a food name normalizer for the USDA FoodData Central database.

Your task: convert any food name (English or Russian, casual or formal) into the
canonical USDA description format.

USDA format conventions:
- Primary ingredient first, then qualifiers (cut, part, preparation)
- Comma-separated descriptors
- "cooked" qualifier with method: "boiled", "roasted", "fried", "grilled"
- For meat: include species/cut/preparation
- For vegetables: include "raw" or "cooked, boiled/steamed/etc"
- For grains: state of preparation (raw, cooked)
- Use canonical English food names only

Examples:
"grilled chicken breast" → "Chicken, broilers or fryers, breast, meat only, cooked, roasted"
"жареная картошка" → "Potatoes, french fried, all types, salt added in processing, frozen, oven-heated"
"варёный рис" → "Rice, white, long-grain, regular, cooked"
"яичница" → "Egg, whole, cooked, fried"
"авокадо" → "Avocados, raw, all commercial varieties"
"oat porridge with milk" → "Oatmeal, cooked, regular, with milk, unenriched"

Respond ONLY with JSON:
{"usda_name": "<canonical name>", "confidence": <0.0-1.0>}

If you cannot confidently normalize (unknown food, ambiguous), respond:
{"usda_name": null, "confidence": 0.0}
"""

USER_PROMPT_TEMPLATE = 'Normalize: "{name}"'
```

Вызов: `qwen-turbo`, `temperature=0.0`, `max_tokens=120`, `response_format={"type": "json_object"}`.

### Кэширование нормализаций

**Решение: Redis с TTL=30 дней, in-memory LRU как L1.**

Обоснование:
- Без shared cache каждый воркер FastAPI/Gunicorn платит за нормализацию заново: 10k recognize/day × 3 ингредиента = 30k вызовов qwen-turbo.
- Redis — shared cache между воркерами.
- L1 LRU (size=2048) снимает round-trip к Redis для горячих ингредиентов.

Ключ: `usda_norm:v1:{sha1(lower(name).strip())}`  
Значение: `{"usda_name": "...", "confidence": 0.93}` или `null` (negative cache, TTL=7д).

```python
class UsdaNormalizer:
    def __init__(self, redis_client, text_provider):
        self._redis = redis_client
        self._provider = text_provider
        self._l1: dict[str, NormalizationResult | None] = {}  # LRU обернуть

    async def normalize(self, name: str) -> NormalizationResult | None:
        key = self._cache_key(name)
        if key in self._l1:
            return self._l1[key]
        cached = await self._redis.get(key)
        if cached is not None:
            result = self._deserialize(cached)
            self._l1[key] = result
            return result
        result = await self._call_qwen(name)
        await self._redis.setex(
            key,
            ttl_seconds(30) if result else ttl_seconds(7),
            self._serialize(result),
        )
        self._l1[key] = result
        return result
```

### Failure handling

1. Qwen timeout/rate-limit/invalid JSON → `None`, не пишем negative cache.
2. `usda_name=null` (модель не уверена) → negative cache на 7д, используем raw name для substring search.
3. USDA exact-match не нашёл → fallback:
   - substring search по `normalized.split(",")[0]` (основной ингредиент)
   - substring search по raw name
   - если оба пусты → Step 2 (FatSecret)

Метрики:
- `usda_normalizer_calls_total`
- `usda_normalizer_cache_hit_ratio`
- `usda_exact_hit_after_normalize_ratio` — главный KPI нормализатора

---

## 3. FatSecret Integration

### Endpoint

**`autocomplete.v2`** → `foods.search.v3` → `food.get.v4` для per-100g фактов.

Base URL: `https://platform.fatsecret.com/rest/server.api`

### Auth: OAuth 1.0a

Использовать `authlib` — не катать свой OAuth.

```python
from authlib.integrations.httpx_client import AsyncOAuth1Client

class FatSecretClient:
    def __init__(self, consumer_key: str, consumer_secret: str):
        self._client = AsyncOAuth1Client(
            client_id=consumer_key,
            client_secret=consumer_secret,
            signature_type="QUERY",
            timeout=httpx.Timeout(connect=2.0, read=5.0, write=5.0, pool=5.0),
        )
```

Premier-доступ: 2-legged OAuth (только consumer creds, без user tokens).

### Запросы

**Autocomplete:**
```
GET /rest/server.api?method=foods.autocomplete.v2&expression={name}&max_results=4&format=json
```

**Foods search:**
```
GET /rest/server.api?method=foods.search.v3&search_expression={suggestion}&max_results=1&format=json
```

**Food get:**
```
GET /rest/server.api?method=food.get.v4&food_id={id}&format=json
```

### Парсинг ответа (food.get)

Берём serving с `metric_serving_unit == "g"`, нормализуем на 100г:

```python
def _extract_per_100g(food: dict) -> NutritionFacts | None:
    servings = food.get("servings", {}).get("serving", [])
    if isinstance(servings, dict):
        servings = [servings]

    metric = next(
        (s for s in servings if s.get("metric_serving_unit") == "g"),
        None,
    )
    if not metric:
        return None

    grams = float(metric["metric_serving_amount"])
    if grams <= 0:
        return None

    scale = 100.0 / grams
    return NutritionFacts(
        name_used=food["food_name"],
        calories_per_100g=float(metric["calories"]) * scale,
        protein_per_100g=float(metric["protein"]) * scale,
        fat_per_100g=float(metric["fat"]) * scale,
        carbs_per_100g=float(metric["carbohydrate"]) * scale,
        fiber_per_100g=float(metric.get("fiber") or 0) * scale,
        sugar_per_100g=float(metric.get("sugar") or 0) * scale,
        saturated_fat_per_100g=float(metric.get("saturated_fat") or 0) * scale,
        source="fatsecret",
        confidence=0.8,
    )
```

### Rate limit

Redis-based sliding-day counter (проектируем под 10 000 RPD — уточнить у James):

```python
class FatSecretRateLimiter:
    KEY = "fatsecret:rpd:{date_utc}"
    DAILY_LIMIT = int(os.environ.get("FATSECRET_DAILY_LIMIT", "10000"))
    SOFT_THRESHOLD = 0.9

    async def acquire(self) -> bool:
        key = self.KEY.format(date_utc=date.today().isoformat())
        used = await self._redis.incr(key)
        if used == 1:
            await self._redis.expire(key, 86400 + 3600)
        if used > self.DAILY_LIMIT:
            return False
        if used > self.DAILY_LIMIT * self.SOFT_THRESHOLD:
            logger.warning("FatSecret RPD at %d/%d", used, self.DAILY_LIMIT)
        return True
```

`acquire() == False` → пропускаем FatSecret, идём в Qwen fallback без блокировки юзера.

### Кэш FatSecret

Ключ: `fatsecret:facts:v1:{sha1(name)}`, TTL=30д. Negative cache TTL=24ч.

### Failure handling

| Случай | Действие |
|---|---|
| Timeout / connection error | retry ×1 с jitter 100ms → Step 3 |
| OAuth 401/403 | лог CRITICAL, не retry, → Step 3 |
| `error.code` 13/14 (no results) | → Step 3 |
| Rate limit local (RPD) | сразу Step 3, метрика `fatsecret_rate_limited_total` |
| `_extract_per_100g` вернул None | → Step 3 |

---

## 4. Qwen Fallback

### Промпт

Файл: `app/llm/prompts/nutrition_estimate.py`

```python
SYSTEM_PROMPT = """You are a nutrition database. For any food name, return its
nutrition facts per 100 grams of the prepared/edible portion.

Use authoritative sources (USDA, official food databases) as your reference.
If preparation method is implied by the name (e.g. "grilled", "boiled"), use
that prepared form.

Respond ONLY with JSON, no commentary:
{
  "name_normalized": "<canonical English name>",
  "calories_per_100g": <number>,
  "protein_per_100g": <number>,
  "fat_per_100g": <number>,
  "carbs_per_100g": <number>,
  "fiber_per_100g": <number>,
  "sugar_per_100g": <number>,
  "saturated_fat_per_100g": <number>,
  "confidence": <0.0-1.0>
}

If the food name is non-food, gibberish, or unidentifiable:
{"error": "unknown_food"}

Examples:
Input: "grilled chicken breast"
Output: {"name_normalized": "grilled chicken breast", "calories_per_100g": 165,
"protein_per_100g": 31, "fat_per_100g": 3.6, "carbs_per_100g": 0,
"fiber_per_100g": 0, "sugar_per_100g": 0, "saturated_fat_per_100g": 1.0, "confidence": 0.9}

Input: "варёный рис"
Output: {"name_normalized": "boiled white rice", "calories_per_100g": 130,
"protein_per_100g": 2.7, "fat_per_100g": 0.3, "carbs_per_100g": 28,
"fiber_per_100g": 0.4, "sugar_per_100g": 0.1, "saturated_fat_per_100g": 0.1, "confidence": 0.95}
"""

USER_PROMPT_TEMPLATE = 'Food: "{name}"'
```

Вызов: `qwen-turbo`, `temperature=0.0`, `max_tokens=300`, `response_format={"type": "json_object"}`.

### Sanity validation

```python
def _validate_facts(d: dict) -> bool:
    if "error" in d:
        return False
    # Caloric coherence: 4*p + 9*f + 4*c ~ calories ± 30%
    expected = 4 * d["protein_per_100g"] + 9 * d["fat_per_100g"] + 4 * d["carbs_per_100g"]
    actual = d["calories_per_100g"]
    if actual <= 0 or actual > 900:
        return False
    if abs(expected - actual) / max(actual, 1) > 0.30:
        return False
    return all(0 <= d[k] <= 100 for k in
               ("protein_per_100g", "fat_per_100g", "carbs_per_100g"))
```

Если санити не прошёл → возвращаем degraded, не кэшируем.

Кэш: `nutrition:qwen:v1:{sha1(name)}`, TTL=30д. Negative TTL=24ч.

---

## 5. Файловая структура

### Новые файлы

```
app/services/nutrition/
├── __init__.py
├── lookup.py                # orchestrator: nutrition_lookup(name, grams)
├── facts.py                 # @dataclass(frozen=True) NutritionFacts + to_suggestion
├── usda/
│   ├── __init__.py
│   ├── normalizer.py        # UsdaNormalizer (Qwen + Redis + L1)
│   ├── repository.py        # find_exact / substring_search над USDA БД
│   └── cache.py
├── fatsecret/
│   ├── __init__.py
│   ├── client.py            # FatSecretClient (httpx + authlib OAuth1)
│   ├── rate_limiter.py      # Redis daily counter
│   ├── parser.py            # _extract_per_100g
│   └── cache.py
└── qwen_estimator/
    ├── __init__.py
    ├── estimator.py         # QwenNutritionEstimator (qwen-turbo + validator)
    └── validator.py         # sanity-валидация

app/llm/prompts/
├── usda_normalizer.py       # SYSTEM_PROMPT + USER_PROMPT_TEMPLATE
└── nutrition_estimate.py    # SYSTEM_PROMPT + USER_PROMPT_TEMPLATE

tests/nutrition/
├── test_lookup_pipeline.py
├── test_usda_normalizer.py
├── test_fatsecret_client.py
├── test_fatsecret_parser.py
├── test_qwen_estimator.py
└── fixtures/
    ├── fatsecret_chicken.json
    ├── fatsecret_no_metric.json
    └── usda_normalizer_responses.json
```

### Изменяемые файлы

| Файл | Изменение |
|---|---|
| `app/services/recognize_photo_qwen.py` | строка 81: `_empty_suggestion(name)` → `await nutrition_lookup(name, weight_grams)` |
| `app/config.py` | добавить: `FATSECRET_CONSUMER_KEY`, `FATSECRET_CONSUMER_SECRET`, `FATSECRET_DAILY_LIMIT`, `REDIS_URL`, `USDA_NORMALIZER_TTL_DAYS=30` |
| `requirements.txt` | `authlib>=1.3`, `httpx>=0.27`, `redis>=5.0` |
| `.env.example` | задокументировать новые ключи |

---

## 6. Порядок имплементации

1. **Контракты** — `nutrition/facts.py`: `NutritionFacts` frozen dataclass + `to_suggestion(facts, weight_grams) -> dict`. Тесты на масштабирование per-100g × grams/100.

2. **Промпты** — `prompts/usda_normalizer.py` + `prompts/nutrition_estimate.py`. Smoke-тесты с реальным qwen-turbo на 5-10 примерах.

3. **USDA Normalizer** — `usda/cache.py` (Redis + L1 LRU), `usda/normalizer.py`, `usda/repository.py`. Тесты: cache hit/miss, qwen failure → None, negative cache.

4. **Step 1 интеграция (USDA only)** — `lookup.py` v1 только USDA-путь. Подключить в `recognize_photo_qwen.py`, прогнать на 50 блюдах. Цель: `usda_hit_rate ≥ 60%`.

5. **FatSecret client + парсер** — `fatsecret/client.py` с authlib OAuth1, retry, timeout. `fatsecret/parser.py` с edge-кейсами. `fatsecret/rate_limiter.py`. Записать live-ответы как fixtures. Integration тест `@pytest.mark.integration`.

6. **Step 2 интеграция** — `lookup.py` v2: USDA → FatSecret. Цель совокупного hit-rate: ≥ 90%.

7. **Qwen estimator** — `qwen_estimator/estimator.py` + `validator.py`. Кэш. Тесты на sanity (положительные и невалидные кейсы).

8. **Полный pipeline** — `lookup.py` v3. Прогон на Nutrition5k 749 блюд.

9. **Замена в recognize_photo_qwen.py** — удалить `_empty_suggestion`, заменить на `asyncio.gather` по ингредиентам параллельно.

10. **Метрики** — Prometheus counters: `nutrition_lookup_total{source}`, `nutrition_lookup_latency_ms{step}`, `fatsecret_rpd_used`. Alert: `degraded_ratio > 5%` за 1 час.

11. **Документация** — обновить `docs/backend_patches/llm_layer/README.md`. ADR `docs/adr/001-nutrition-pipeline.md`.

---

## 7. Параллелизация ингредиентов (критично для latency)

```python
from app.services.nutrition.lookup import nutrition_lookup

nutrition_tasks = [
    nutrition_lookup(ing["name"], ing["weight_grams"])
    for ing in raw_ingredients
]
nutrition_results = await asyncio.gather(*nutrition_tasks, return_exceptions=True)
```

3 ингредиента × 600ms последовательно = 1.8s. Параллельно = ~600ms. Обязательно.

---

## 8. Риски и mitigation

| Риск | Вероятность | Impact | Mitigation |
|---|---|---|---|
| USDA-нормализатор галлюцинирует несуществующие USDA-имена | Средняя | Средний | `find_exact()` после нормализации — если не нашли, идём в substring search по первой части; логировать топ miss'ов |
| FatSecret autocomplete top-1 ошибается на коротких запросах | Высокая | Высокий | `foods.search.v3` с `max_results=3`, выбирать лучший по fuzzy-match, предпочитать `food_type=Generic` над брендами |
| FatSecret RPD исчерпался к середине дня | Средняя | Средний | Soft threshold 90% → warning; per-user rate limit; graceful → Qwen |
| Qwen-turbo несогласованные КБЖУ | Высокая | Высокий | Sanity ±30%; при фейле не кэшировать, метрика `qwen_nutrition_sanity_fail_ratio > 10%` → доработать промпт |
| Cascade latency USDA+FS+Qwen > 800ms p95 | Высокая | Средний | `asyncio.gather` FatSecret и Qwen после USDA miss; агрессивный кэш |
| Cache stampede при concurrent requests | Низкая | Низкий | Redis `SET NX EX 10` dogpile-lock перед вызовом qwen-turbo |
| OAuth signing ломается на русских именах | Средняя | Высокий | Используем authlib; тест с `expression="яблоко"`; логировать raw ответ при 401 |
| Sanity-валидатор режет валидные данные (чистый сахар) | Низкая | Средний | Допуск ±30%; edge case >90% макроса — отдельная ветка; прогон на USDA top-500 |
| Redis unavailable | Низкая | Высокий | Cache no-op (try/except), pipeline работает; alert при ошибках Redis |
| Регрессия после раскатки | Средняя | Средний | Golden-set 100 блюд перед merge; канареечный rollout 10% → 50% → 100% |

---

## 9. Definition of Done (Фаза 3)

- [ ] `nutrition_lookup` покрыт unit + integration тестами, coverage ≥ 80%
- [ ] Прогон на Nutrition5k 749 блюд: kcal MAE < 25%, macros MAE < 30%
- [ ] hit-rate breakdown: USDA ≥ 60%, +FatSecret ≥ 85%, +Qwen ≥ 98%
- [ ] p95 nutrition_lookup latency < 700ms (с прогретым кэшем — < 50ms)
- [ ] `degraded_ratio` < 2% на проде
- [ ] FatSecret RPD usage < 70% от квоты на типичном дне
- [ ] Все секреты в env, нет хардкода
- [ ] ADR-001 написан, README обновлён
