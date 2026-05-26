# Plan: Тотальная миграция KayFit backend Claude → Qwen

**Дата:** 2026-05-24  
**Статус:** Ready for implementation  
**Приоритет:** High

---

## Контекст

KayFit использует Claude Sonnet vision + text для:
- Распознавания еды на фото → ингредиенты + граммовка
- Парсинга текстового описания еды
- Поиска продуктов в БД
- Определения бренда в запросе

Цель: полностью заменить Claude на Qwen (DashScope). Никакого A/B с Claude — прямой переход.

---

## Приоритеты работы (порядок важен)

### Приоритет 1 — Качество распознавания ингредиентов и их массы
Сначала добиваемся хорошего ingredient recognition: правильные ингредиенты + правильная граммовка.  
**Не смешивать с КБЖУ** — это отдельная задача.

### Приоритет 2 — КБЖУ расчёт (после)
Только когда ингредиенты распознаются хорошо, подключаем nutrition lookup.

---

## Фаза 1: Замена recognize_photo (главный эндпоинт)

### Модель
`qwen3-vl-flash` — основная  
`qwen3-vl-plus` — fallback при: невалидный JSON / 0 ингредиентов / суммарный вес < 20г

### Стратегия промпта — Variant B (ингредиентная декомпозиция)
```
Фото → Qwen3-VL → список ингредиентов с граммовкой
```
Вариант "блюдо целиком → FatSecret" (Variant A) — отброшен для recognize_photo.  
Причина: не работает для домашней еды, смешанных блюд, международной кухни.

### Промпт
- Системная часть: **английский**
- JSON-поля: **английский** (`ingredient_name`, `weight_grams`)
- `response_format={"type": "json_object"}` обязательно
- `temperature=0.0`, `max_tokens=1200`
- Добавить 1 few-shot пример с реальным блюдом
- Препроцессинг изображения: resize до max 1024px, JPEG quality 85

### Целевой JSON-ответ
```json
{
  "dish_name": "grilled chicken with rice and vegetables",
  "ingredients": [
    {
      "name": "grilled chicken breast",
      "weight_grams": 120,
      "confidence": 0.9
    },
    {
      "name": "white rice",
      "weight_grams": 150,
      "confidence": 0.85
    }
  ],
  "total_weight_grams": 320,
  "scale_reasoning": "standard dinner plate ~25cm used as reference"
}
```

### Метрики качества (Фаза 1)
- **Ingredient F1** (precision + recall по ингредиентам)
- **Weight MAE** (средняя абсолютная ошибка граммовки по ингредиенту)
- **Schema validity rate** (цель: >98%)
- **p50 / p95 latency**
- НЕ смотрим kcal error на этом этапе

---

## Фаза 2: Замена text-эндпоинтов (низкий риск)

Все три переводятся на `qwen-turbo`:

| Эндпоинт | Текущий | Целевой |
|---|---|---|
| `parse_meal` | Claude Sonnet | qwen-turbo |
| `search_products` | Claude Sonnet | qwen-turbo (+qwen-plus при ошибке) |
| `_detect_brand` | Claude Sonnet | qwen-turbo |

**parse_meal специфика:** добавить в промпт справочник типичных порций (тарелка супа 300г, порция каши 250г, яблоко 180г и т.д.) — Qwen слабее Claude на русских разговорных единицах измерения.

---

## Фаза 3: КБЖУ расчёт (отдельная задача, после Фазы 1)

### Иерархия nutrition lookup (per ingredient)
```
1. USDA локальная БД (уже на сервере, fast, бесплатно)
   Проблема: плохой маппинг строк ингредиентов
   Решение: Qwen-turbo нормализует название перед поиском
   "grilled chicken" → Qwen → "chicken breast cooked" → USDA

2. FatSecret Premier API (бесплатный, US dataset, autocomplete)
   Credentials уже получены от James (FatSecret)
   Использовать autocomplete endpoint (быстрее foods.search)
   Лимит: уточнить RPD у James

3. Qwen-turbo fallback
   "What is КБЖУ per 100g of {ingredient}?" → structured JSON
   Лучше веб-поиска: быстрее, структурировано, не нужен парсинг
```

### USDA fix (нужно сделать до Фазы 3)
Основная проблема: Вариант 3 — модель называет ингредиент иначе чем записано в USDA.  
Решение: промежуточный Qwen-turbo нормализатор запроса перед USDA lookup.

---

## Провайдерный слой app/llm/

```
app/llm/
├── base.py              # Protocol: LLMTextProvider, LLMVisionProvider
├── providers/
│   ├── qwen.py          # openai SDK + DashScope base_url (основной)
│   └── claude.py        # только как fallback при 503/timeout Qwen (не для A/B)
├── router.py            # выбор провайдера по env vars
├── prompts/
│   ├── recognize_photo.py   # версия qwen_v1
│   ├── parse_meal.py
│   ├── search_products.py
│   └── detect_brand.py
└── errors.py            # LLMTimeout, LLMInvalidSchema, LLMRateLimit
```

### Feature flags (env vars)
```
DASHSCOPE_API_KEY=...
DASHSCOPE_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1
QWEN_VISION_MODEL=qwen3-vl-flash
QWEN_VISION_MODEL_FALLBACK=qwen3-vl-plus
QWEN_TEXT_MODEL=qwen-turbo

# Fallback на Claude только при hard errors (опционально)
LLM_FALLBACK_ENABLED=false   # включить если есть Claude ключ
ANTHROPIC_API_KEY=...

# FatSecret
FATSECRET_CONSUMER_KEY=...
FATSECRET_CONSUMER_SECRET=...
```

### Fallback без Claude
```
Qwen → retry ×2 (exponential backoff) → degraded response
- recognize_photo: {"error": "recognition_unavailable"} → UI показывает ручной ввод
- parse_meal: поиск продукта целиком в USDA по raw строке
- detect_brand: default false
```

---

## Экономия

| Эндпоинт | Claude Sonnet | Qwen | Экономия |
|---|---|---|---|
| recognize_photo (10k/день) | ~$1 260/мес | ~$120/мес | **-90%** |
| parse_meal + search + brand | ~$800/мес | ~$40/мес | **-95%** |
| **Итого** | **~$2 000+/мес** | **~$160/мес** | **-92%** |

---

## Валидация качества (без A/B с Claude)

1. **L2 бенчмарк офлайн** — Nutrition5k 749 блюд, метрики ingredient F1 + weight MAE
2. **AI-агент оценка** — выборка 50-100 результатов, Claude/GPT оценивает качественно (как делали в L1)
3. **Прод мониторинг** — schema_invalid_rate, p95 latency, выборочный ручной просмотр логов

---

## Порядок исполнения

- [ ] Фаза 1: Заменить `recognize_photo` на Qwen3-VL-Flash + Variant B промпт
- [ ] Фаза 1: Обновить `endpoint_recognize_photo_v2.py` и `recognize_photo_v2.py`
- [ ] Фаза 1: Добавить провайдерный слой `app/llm/`
- [ ] Фаза 2: Перевести `parse_meal`, `search_products`, `detect_brand` на qwen-turbo
- [ ] Фаза 2: Добавить справочник порций в parse_meal промпт
- [ ] USDA fix: Qwen-нормализатор перед USDA lookup
- [ ] Фаза 3: FatSecret интеграция (после USDA fix)
- [ ] Фаза 3: КБЖУ pipeline: USDA → FatSecret → Qwen fallback
