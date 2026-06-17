# KayFit — Рецепты + RAG-рекомендации: архитектура и план

> Дата: 2026-06-15 · Статус: дизайн, кода нет (утверждаем перед реализацией)
> Связано: [RESEARCH_recipes_feed_prior_art_2026-06-15.md](RESEARCH_recipes_feed_prior_art_2026-06-15.md) (вердикт совета: курация, не скрапинг) · авторинг карточек = `~/Desktop/КУРСОР/carousel_factory/`

## Решение и рамки

- **Без скрапинга.** Контент = собственные фотосессии еды (часть в маркетинг, часть в приложение). Источник — in-house, как у Fitia. Снимает юр-риск РФ и копирайт целиком.
- **Рецепт в приложении = карусель карточек** того же формата, что делает Carousel Factory: герой (блюдо + КБЖУ) → слайды ингредиентов/шагов → CTA.
- **RAG-база** в существующем проде: **PostgreSQL + расширение `pgvector`** на Timeweb VPS (89.23.99.129, стек `/root/calories`). Новой инфры не нужно.
- **Эмбеддинги** — Qwen `text-embedding-v3` (DashScope intl, тот же `QWEN_API_KEY`). Соответствует правилу «Qwen везде».
- **Сигналы рекомендации (выбор пользователя):**
  1. **Остаток дневных калорий + цель** → жёсткий SQL-фильтр.
  2. **История залогированной еды** → неявный вектор предпочтений (семантика).
  - *(Аллергии/диета — опциональный хард-фильтр безопасности: активен только если юзер их заполнил; без анкеты не мешает.)*

---

## Ключевая проблема, которую решаем

Carousel Factory сейчас извлекает структуру (`DishMacros`: название, ккал/Б/Ж/У; `Caption` по слайду: ingredient/step) — но **на выходе только PNG-слайды, структура теряется**. Для RAG её надо **персистить как структурированный рецепт + эмбеддинг**. То есть фабрика становится не только генератором картинок, но и **источником записей в рецепт-БД**.

```
Сейч: input/*.jpg → VLM → [структура в памяти] → PNG-слайды → output/   (структура выброшена)
Надо: input/*.jpg → VLM → структурный рецепт ──┬─→ PNG-слайды → output/ (контент/маркетинг)
                                                └─→ POST /ingest → Postgres+pgvector (RAG-база приложения)
```

---

## 1. Модель данных (PostgreSQL + pgvector)

```sql
CREATE EXTENSION IF NOT EXISTS vector;

-- Рецепт = карусель + структура для RAG
CREATE TABLE recipes (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            text UNIQUE NOT NULL,
    title           text NOT NULL,
    cuisine         text,                 -- 'asian' | 'italian' | ... (для семантики)
    meal_type       text,                 -- 'breakfast'|'lunch'|'dinner'|'snack'
    -- макросы на ПОРЦИЮ (хард-фильтр по калоражу)
    kcal            int  NOT NULL,
    protein_g       int  NOT NULL,
    fat_g           int  NOT NULL,
    carb_g          int  NOT NULL,
    servings        int  NOT NULL DEFAULT 1,
    cook_minutes    int,
    difficulty      text,                 -- 'easy'|'medium'|'hard'
    -- классификация для фильтров
    diet_flags      text[] DEFAULT '{}',  -- 'vegan','keto','halal','gluten_free'...
    allergens       text[] DEFAULT '{}',  -- 'nuts','lactose','gluten','seafood'...
    goal_fit        text[] DEFAULT '{}',  -- 'weight_loss','muscle_gain','maintenance'
    tags            text[] DEFAULT '{}',  -- 'high_protein','low_carb','quick'...
    -- RAG
    embed_text      text NOT NULL,        -- из чего считался эмбеддинг (для отладки)
    embedding       vector(1024),         -- Qwen text-embedding-v3
    -- контент
    is_free         bool NOT NULL DEFAULT true,   -- freemium-гейт (см. вердикт совета)
    qa_status       text NOT NULL DEFAULT 'draft',-- 'draft'|'need_review'|'approved'
    source          text NOT NULL DEFAULT 'inhouse',
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- Слайды карусели (порядок = order_idx)
CREATE TABLE recipe_slides (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id   uuid NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    order_idx   int  NOT NULL,
    kind        text NOT NULL,            -- 'hero'|'ingredient'|'step'|'cta'
    image_url   text NOT NULL,            -- путь/URL картинки слайда
    caption     text,                     -- '350g Chicken Breast' / 'Season & Grill'
    UNIQUE (recipe_id, order_idx)
);

-- Структурированные ингредиенты (для шопинг-листа и фактов, фаза 2)
CREATE TABLE recipe_ingredients (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id   uuid NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    name        text NOT NULL,
    amount_g    int,
    kcal        int
);

-- Скользящий вектор вкусов пользователя из истории логов
CREATE TABLE user_taste (
    user_id        bigint PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    embedding      vector(1024),          -- среднее по эмбеддингам залогированной еды
    logs_counted   int NOT NULL DEFAULT 0,
    updated_at     timestamptz NOT NULL DEFAULT now()
);

-- Индексы
CREATE INDEX ON recipes USING hnsw (embedding vector_cosine_ops);
CREATE INDEX ON recipes (kcal);
CREATE INDEX ON recipes (qa_status, is_free);
```

**Почему макросы на порцию, а не на всё блюдо:** хард-фильтр «впишется в остаток калоража» работает по порции, которую съест юзер. Carousel Factory оценивает всю тарелку → при ингесте делим на `servings`.

---

## 2. Авторинг: расширение Carousel Factory

Добавить в фабрику режим экспорта структуры (не ломая текущую генерацию PNG):

- Новый модуль `recipe_export.py`: собирает `Recipe` из уже извлечённых `DishMacros` + `Caption[]`, добивает недостающие поля **одним доп. VLM/LLM-вызовом** (`cuisine`, `meal_type`, `diet_flags`, `allergens`, `tags`, `cook_minutes`) — Qwen уже в стеке.
- Считает `embed_text` (см. §3) → запрашивает эмбеддинг Qwen → пишет вектор.
- Загружает слайды (картинки) в хранилище (S3-совместимое Timeweb или `/static` на фронт-nginx) → получает `image_url`.
- `POST /admin/recipes/ingest` на бэкенд с `qa_status='need_review'` (никакой авто-публикации — см. вердикт совета: human-QA обязателен).
- Флаг `--export-db` к `generate.py`: `python generate.py --name alpha_plate --export-db`.

**Точность:** макросы VLM приблизительны (потолок F13≈35%). Поэтому: (а) перед `approved` — ручная сверка КБЖУ нутрициологом; (б) в карточке маркер «КБЖУ ±15%, AI» + бейдж «Проверено» для approved (идея совета: тех-риск → премиум-актив).

---

## 3. Стратегия эмбеддинга

**Рецепт** (`embed_text`) — конкатенация значимых для подбора полей, НЕ сырой текст:
```
"{title}. Кухня: {cuisine}. {meal_type}. Профиль: {high_protein/low_carb/...}.
 Главные ингредиенты: {top-3 ingredient names}. Теги: {tags}. {cook_minutes} мин."
```
→ Qwen `text-embedding-v3` → `vector(1024)`.

**Вектор вкусов юзера** (`user_taste.embedding`) — из истории логов:
- На каждый лог еды: берём название блюда/продукта → эмбеддинг → **инкрементальное среднее** с весом-свежести (последние логи весомее).
- Обновляется фоном (не в горячем пути лога).
- **Cold-start** (новый юзер, `logs_counted < 5`): вектора нет → подбор только по жёстким фильтрам + `goal_fit` + популярность.

---

## 4. RAG-поиск (как Ишка находит рецепт)

Гибрид: **жёсткие фильтры (SQL) → семантический rerank (pgvector) → LLM-выбор (Ишка)**.

```sql
-- Шаг 1-2: кандидаты, прошедшие хард-фильтры, отранжированные по вкусу юзера
SELECT r.*, r.embedding <=> :user_taste AS distance
FROM recipes r
WHERE r.qa_status = 'approved'
  AND r.kcal BETWEEN :kcal_lo AND :kcal_hi        -- остаток калоража ± допуск
  AND (:goal = ANY(r.goal_fit) OR cardinality(r.goal_fit) = 0)
  AND NOT (r.allergens && :user_allergens)        -- безопасность (если заданы)
  AND (:diet IS NULL OR :diet = ANY(r.diet_flags))
  AND (:free_only = false OR r.is_free = true)     -- freemium-гейт
ORDER BY distance ASC
LIMIT 15;
```

- `:kcal_lo/hi` = окно вокруг остатка дневного калоража под текущий приём пищи (напр. ужин = 30-40% дневной нормы, не больше остатка).
- Если юзер в cold-start → `:user_taste` нет → `ORDER BY` по `goal_fit`-совпадению + популярности.

**Шаг 3 — Ишка (Qwen-turbo):** получает top-15 карточек (title, макросы, теги) + контекст юзера (остаток ккал, цель, что уже ел сегодня) → выбирает 1-3, объясняет «почему тебе» и генерит строку **«впишется в твой день: +420 ккал, добивает белок»**. RAG не даёт галлюцинировать рецепты — Ишка выбирает только из реальных approved-записей.

---

## 5. API (FastAPI, существующий бэкенд)

| Метод | Эндпоинт | Назначение |
|---|---|---|
| `POST` | `/admin/recipes/ingest` | приём рецепта от Carousel Factory (auth, `need_review`) |
| `GET` | `/recipes/{slug}` | карточки рецепта (слайды по порядку) для экрана |
| `GET` | `/recipes/recommend` | RAG-подбор под юзера (остаток ккал + цель + вкус) → 1-3 рецепта + текст Ишки |
| `GET` | `/recipes/feed` | вторичная лента-витрина (approved + free), пагинация |
| `POST` | `/recipes/{id}/log` | залогировать рецепт в дневник (главный CTA-крючок) |

Логирование рецепта (`/log`) — событие, которое (а) кормит `user_taste`, (б) триггерит CTA-момент из вердикта совета: после лога с закрытой целью → «Ишка соберёт весь день под цель? → Trial».

---

## 6. Экран «Рецепты» (Flutter)

- **Рекомендация Ишки** (верх): 1-3 карточки из `/recommend` + строка «впишется в твой день».
- **Карточка рецепта** = свайп-карусель слайдов (`recipe_slides` по `order_idx`) — тот же визуал, что в Carousel Factory.
- **Лента-витрина** (`/feed`) — вторична (вердикт совета: не каннибализировать логирование).
- Кнопка **«Добавить в дневник»** на каждой карточке → `/log`.
- Freemium: free-рецепты открыты; premium (авто-план, безлимит рекомендаций, swap, шопинг-лист) — за подпиской.

---

## 7. Фазы реализации (коммит по каждой фазе)

| Фаза | Содержание | Критерий готовности |
|---|---|---|
| **0. Юнит-экономика** | стоимость съёмки+нутрициолога на 100 рецептов, цена эмбеддинга/VLM на рецепт, окупаемость при LTV $1.21 / trial→paid 38-42% | решение GO зафиксировано числами |
| **1. Схема + pgvector** | миграция таблиц, расширение, индексы HNSW; бэкап БД перед миграцией | таблицы в проде, `\dx` показывает vector |
| **2. Авторинг** | `recipe_export.py` + `--export-db` в Carousel Factory; ингест 20-30 реальных рецептов с ручной QA | 20-30 approved-рецептов в БД с эмбеддингами |
| **3. RAG-эндпоинты** ✅ | `/recommend` (хард-фильтры + pgvector + Ишка), `/recipes/{slug}`, `/feed` | curl возвращает релевантные рецепты под тестового юзера → **commit `feat: recipes RAG endpoints — recommend/feed/slug (phase 3)`** |
| **4. Вектор вкусов** ✅ | `update_user_taste` (частотно-свежестный центроид из логов) + `scripts/backfill_user_taste.py` (батч/cron, `--only-stale`) | прод-юзер 66 (246 логов): cold-start→вектор 1024-dim, `logs_counted=100`, `recommend` meta.cold_start=false, ранжирование по `embedding <=> taste`; бэкфилл 36 юзеров → **commit `feat: taste vector backfill from meal logs (phase 4)`** |
| **5. Экран Flutter** ✅ | экран «Рецепты», карусель-вьюер, рекомендация Ишки, CTA «в дневник» | `lib/features/recipes/` (модели freezed, провайдеры `recipeRecommendation`/`recipeDetail`, экраны list+карусель, CTA = `POST /api/meals/add_selected` + invalidate журнала), вход — иконка в топ-баре journal-v2; собрано+установлено на iPhone (Kayfit.dev 1.2.2 b6) → **commit `feat: recipes screen — recommend + carousel + add-to-diary (phase 5)`** |
| **6. CTA + freemium** | момент-CTA после лога, гейт premium-фич, триал | конверсионный путь кликается end-to-end |

> Перед фазой 1 — обязательный бэкап прод-БД (скилл `kayfit-db-backup`). Деплой бэкенда — только через `./deploy.sh` (скилл `kayfit-deploy`), не `docker compose up --build` напрямую.

---

## Открытые вопросы

1. **Хранилище картинок слайдов** — S3 Timeweb vs `/static` на frontend-nginx? (влияет на §2 ingest и CDN).
2. ✅ **РЕШЕНО (фаза 3): адаптивное окно.** `kcal_window(remaining)`: при `remaining > 0` → `[max(150, min(remaining*0.40, 350)) .. remaining*1.15]`. Нижняя граница: 150 ккал floor (не «полпорции»), но с потолком 350 — рецепт = ОДИН приём пищи (250-700 ккал), поэтому при большом остатке (начало дня) не требуем гигантскую порцию, обычное блюдо тоже впишется (иначе при remaining=2000 весь каталог 320-640 ккал отсекался → пустой фоллбэк, подтверждено живым прогоном). Верхняя +15%, чтобы не отсекать почти-подходящие. При `remaining ≤ 0` (лимит выбран/превышен) → `[0 .. 400]` — только лёгкие рецепты + честный текст Ишки. Окно завязано на остаток дня (не на тип приёма пищи) — KISS.
3. **Размерность эмбеддинга** — `text-embedding-v3` (1024) подтвердить актуальной у DashScope перед миграцией (v4 может отличаться).
4. **Объём контента на старт** — сколько рецептов снять до запуска, чтобы лента/подбор не выглядели пустыми (Fitia стартовал с тысяч; реалистичный MVP — 50-100 approved).

### Фаза 4 — вектор вкусов (`user_taste`), решения

- **#A Источник сигнала — ✅ логи блюд (`meals.name`).** Богатый сигнал, наполняется ретроактивно из истории (на старте фичи рецепт-логов ещё нет). Названия блюд («Куриная грудка с рисом») ложатся в то же эмбеддинг-пространство, что и `recipes.embed_text` (title + ингредиенты), → корректный центроид для `embedding <=> taste`.
- **#B Агрегация — ✅ взвешенное среднее с экспоненциальным затуханием свежести (EMA-эквивалент).** Вес лога `w(rank) = _TASTE_RECENCY_DECAY ** rank`, где `rank=0` — самый свежий лог (history DESC); `_TASTE_RECENCY_DECAY = 0.97` → half-life ≈ 23 лога (`alpha = 1 − decay = 0.03`). Центроид нормируется L2 (для cosine `<=>`). «Скользящесть» = окно последних N логов.
- **#C Триггер — ✅ батч-пересчёт по последним N логам (`scripts/backfill_user_taste.py`), запускается вручную/по cron.** НЕ хук на каждый meal-add (нет эмбеддинг-косты на добавление, детерминизм). `--only-stale` пропускает юзеров, у кого `user_taste.updated_at` свежее последнего значимого лога → дешёвый cron. Ленивый пересчёт в `recommend` отвергнут (молча тормозил бы хот-путь подбора). `handle_meal_added` НЕ трогаем.
- **#D Контроль косты — ✅ дедуп уникальных названий + частотно-свежестный вес + кап `N=_TASTE_MAX_LOGS=100` + пропуск zero-calorie (`is_zero_calorie`) и `calories>0`.** Эмбеддим КАЖДОЕ уникальное название один раз (≈15-40 вызовов на юзера за пересчёт), а не каждый дубль; частота = сумма весов вхождений.
- **#E Семантика `logs_counted` — ✅ число значимых вхождений-логов** (после фильтра zero-calorie/`calories>0`, в пределах окна N), НЕ уникальных блюд. Бьётся с порогом cold-start `_TASTE_MIN_LOGS=5` из фазы 3: `update_user_taste` пишет вектор только при `significant ≥ 5`, иначе юзер остаётся cold-start (строка не трогается).
- **Краевые случаи:** `<5` значимых логов → возврат `cold_start`, вектор не пишем; только zero-calorie → тот же путь; сбой эмбеддинга → старый вектор НЕ перезаписывается (возврат `error_embed`).
