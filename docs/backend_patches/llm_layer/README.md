# LLM Layer — Патчи миграции Claude → Qwen

Дата: 2026-05-24  
План: `specs/plans/PLAN_qwen_migration_2026-05-24.md`

## Структура файлов

```
llm_layer/
├── README.md                  ← этот файл
├── errors.py                  → app/llm/errors.py
├── base.py                    → app/llm/base.py
├── image_utils.py             → app/llm/image_utils.py
├── router.py                  → app/llm/router.py
├── config_patch.py            → добавить в app/config.py
├── providers/
│   ├── qwen.py                → app/llm/providers/qwen.py
│   └── claude.py              → app/llm/providers/claude.py
├── prompts/
│   ├── recognize_photo.py     → app/llm/prompts/recognize_photo.py
│   ├── parse_meal.py          → app/llm/prompts/parse_meal.py
│   ├── search_products.py     → app/llm/prompts/search_products.py
│   └── detect_brand.py       → app/llm/prompts/detect_brand.py
├── recognize_photo_qwen.py    → app/services/recognize_photo_qwen.py
├── parse_meal_qwen.py         → app/services/parse_meal_qwen.py
└── search_products_qwen.py    → app/services/search_products_qwen.py
```

## Порядок применения на сервере

### 1. Создать структуру директорий
```bash
mkdir -p app/llm/providers app/llm/prompts
touch app/llm/__init__.py app/llm/providers/__init__.py app/llm/prompts/__init__.py
```

### 2. Скопировать файлы (в таком порядке)
```bash
# Основа
cp llm_layer/errors.py        app/llm/errors.py
cp llm_layer/base.py          app/llm/base.py
cp llm_layer/image_utils.py   app/llm/image_utils.py

# Промпты
cp llm_layer/prompts/*.py     app/llm/prompts/

# Провайдеры
cp llm_layer/providers/*.py   app/llm/providers/

# Роутер
cp llm_layer/router.py        app/llm/router.py

# Сервисы
cp llm_layer/recognize_photo_qwen.py   app/services/
cp llm_layer/parse_meal_qwen.py        app/services/
cp llm_layer/search_products_qwen.py   app/services/
```

### 3. Обновить config.py
Добавить содержимое `config_patch.py` в существующий `app/config.py`.

### 4. Обновить .env на сервере
```env
DASHSCOPE_API_KEY=sk-...           # обязательно
DASHSCOPE_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1
QWEN_VISION_MODEL=qwen3-vl-flash
QWEN_VISION_MODEL_FALLBACK=qwen3-vl-plus
QWEN_TEXT_MODEL=qwen-turbo

# Оставить существующие (для fallback если нужен)
ANTHROPIC_API_KEY=...
LLM_FALLBACK_ENABLED=false

# FatSecret (Фаза 3)
FATSECRET_CONSUMER_KEY=...
FATSECRET_CONSUMER_SECRET=...
```

### 5. Обновить импорты в services.py / main.py
```python
# Было:
from services import recognize_photo  # Claude версия

# Стало:
from app.services.recognize_photo_qwen import recognize_photo
from app.services.parse_meal_qwen import parse_meal_with_qwen as parse_meal_with_claude
from app.services.search_products_qwen import get_product_suggestions
```

### 6. Установить зависимости
```bash
pip install openai>=1.30.0 Pillow>=10.0.0
```

### 7. Проверить
```bash
# Smoke test — отправить одно фото
curl -X POST /api/recognize_photo -F "image=@test.jpg"
# Ожидаем: {"items": [...], "dish_name": "...", "error": null}
```

## Что НЕ меняется в Фазе 1
- `endpoint_recognize_photo_v2.py` — только `source="qwen"` вместо `"claude"`
- `search_food()` — существующая функция поиска в локальной БД
- `_has_cyrillic()` — утилита
- `search_products_web()` — только `source="web+qwen"`
- Flutter-клиент — контракт API не меняется

## Фаза 3 — КБЖУ (TODO)
В `recognize_photo_qwen.py` найти комментарий:
```python
# TODO Фаза 3: заменить на nutrition_lookup(name, weight_grams)
```
Там подключить pipeline: USDA local → FatSecret Premier → Qwen fallback.
