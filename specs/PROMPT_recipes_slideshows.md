# Задача: залить разные слайдшоу из Carousel Factory в рецепты KayFit

## Цель
Каждый рецепт в приложении (вкладка **Рецепты** → карточка → детальный экран)
должен показывать **свою** карусель слайдов (готовое блюдо → ингредиенты →
шаги), взятую из Carousel Factory. Подписи слайдов — двуязычные (RU/EN) по
выбранному в приложении языку. CTA-слайд (промо App Store) в рецепт НЕ попадает.

## Что уже есть (контекст)
- **Carousel Factory:** `~/Desktop/КУРСОР/carousel_factory/`
  - Готовые рендеры: `output/slideshows/<NN>_<dish>/` (20 шт.), каждый —
    `slide_00_hero.png`, `slide_01..03.png`, `slide_04_cta.png`.
  - Пайплайн: `generate.py --input <папка_фото> --name <name> --export-db --slug <slug>`
    рендерит слайды И пишет `output/<name>/recipe.json` через `recipe_export.build_recipe`.
  - `recipe_export.build_recipe`: hero→title, ингредиент/шаг-подписи→slides,
    ингредиенты из подписей kind="ingredient"; макросы делятся на servings;
    `image_url = {RECIPE_IMAGE_BASE}/{slug}/{file}` (RECIPE_IMAGE_BASE =
    `https://app.carbcounter.online/static/recipes`); CTA-слайд исключается.
  - ⚠️ В `output/slideshows/*` **нет** `recipe.json` (рендерили без `--export-db`).
- **Бэкенд:** `~/Desktop/КУРСОР/CaloriesApp_backend/backend/`
  - Ингест: `app/services/recipe_service.py::ingest_recipe` (апсерт по slug,
    пересчёт эмбеддинга). Сид-скрипт `scripts/seed_recipes.py --dir <папка> --approve`
    сканирует `<папка>/*/recipe.json`.
  - **Двуязычность уже готова** (commit `c577776`): колонки `title_ru/name_ru/
    caption_ru`, ingest их пишет, read-эндпоинты отдают по `?lang`. Значит
    recipe.json должен содержать `title_ru`, `slides[].caption_ru`,
    `ingredients[].name_ru` — иначе RU отвалится на английский фолбэк.
  - Прод: Timeweb VPS `89.23.99.129`, `/root/calories/`, статика рецептов
    раздаётся frontend-nginx по `/static/recipes/<slug>/`. PNG слайдов нужно
    **залить на сервер** в этот каталог (rsync), иначе `Image.network` в
    приложении покажет битую картинку.
- **Приложение:** `~/Desktop/КУРСОР/mobileKayfit/`
  - Виджет карусели `lib/features/recipes/widgets/recipe_slide_carousel.dart`
    (PageView + Image.network + caption-оверлей) — **жив, но временно убран** из
    детального экрана коммитом `3106c02`. Надо вернуть.
  - Карточки списка (`recipe_recommendation_card.dart`) — текстовые, без картинок
    (в `/recommend` слайдов нет; картинки только в `/api/recipes/{slug}` detail).

## Шаги

### 0. Вернуть карусель в приложении
Откатить `3106c02` (KayFitMobile): в `lib/features/recipes/screens/recipe_detail_screen.dart`
вернуть `import '../widgets/recipe_slide_carousel.dart';` и первым элементом
`_DetailBody` снова `RecipeSlideCarousel(slides: detail.slides)` + отступ.

### 1. Сгенерировать recipe.json для каждого слайдшоу
Для каждой папки `output/slideshows/<NN>_<dish>/` нужен `recipe.json` в формате
ингеста с двуязычными подписями. Два пути:
- **A (предпочтительно, если живы исходные фото):** перегенерировать через
  `generate.py --input <папка_исходных_фото_блюда> --name slideshows/<NN>_<dish>
  --export-db --slug <slug>` — даст и слайды, и recipe.json.
- **B (если исходники не сохранились):** написать экспорт-скрипт, который по уже
  отрендеренным PNG восстанавливает структуру: hero-PNG → VLM `estimate_dish`
  (макросы) + dish_name; `slide_0N.png` → VLM `caption_photo` (подпись/ингредиент);
  затем `recipe_export.build_recipe` → `recipe.json`. VLM = `carousel_factory/vlm.py`
  (Qwen `qwen3-vl-flash`, ключ `QWEN_API_KEY` из `~/Desktop/КУРСОР/.env`).

slug — kebab-case от названия блюда (`grilled-chicken-bowl`). Свериться с
существующими 25 slug'ами в `backend/seeds/recipes_seed.json`: совпадающие
обновятся (апсерт), новые добавятся.

### 2. Добавить RU-перевод в каждый recipe.json
`recipe_export` пишет только английские `title`/`caption`/`name`. Дописать
`title_ru`, `slides[].caption_ru`, `ingredients[].name_ru`:
- либо расширить enrich-вызов в `recipe_export.py` (попросить Qwen вернуть RU),
- либо прогнать отдельным проходом по образцу
  `backend/scripts/translate_seed_ru.py` (глоссарий EN→RU, ассерт полного покрытия).

### 3. Залить PNG слайдов на прод-статику
rsync контент-слайдов (без `*_cta.png`) в `/static/recipes/<slug>/` на сервере
`89.23.99.129` так, чтобы `RECIPE_IMAGE_BASE/<slug>/<file>` отдавал 200.
Уточнить точный путь статики в `/root/calories` (frontend nginx volume).

### 4. Ингест в БД (через деплой-флоу, с бэкапом)
- Сначала **бэкап прод-БД** (`scripts/backup-db.sh` / скилл `kayfit-db-backup`).
- Прогнать `seed_recipes.py --dir <output/slideshows> --approve` против прод-БД
  (внутри backend-контейнера; апсерт по slug, пересчёт эмбеддингов). Решить с
  пользователем: оставлять ли 25 старых текстовых сидов без картинок или заменить
  их этими 20 (с реальными фото).
- Деплой бэкенда — по скиллу `kayfit-deploy` (НЕ `docker compose down`).

### 5. Проверка на устройстве
Собрать KayFit на iPhone (скилл `kayfit-release`, Procedure B), открыть
несколько рецептов: у каждого — своя карусель, подписи на RU при русской локали
и на EN при английской, битых картинок нет.

## Критерии приёмки
- [ ] Карусель снова на детальном экране (откат `3106c02`).
- [ ] У ≥20 рецептов в проде есть слайды (`/api/recipes/{slug}` возвращает
      непустой `slides` с рабочими `image_url`).
- [ ] Слайды разные у разных рецептов (не один шаблон на всех).
- [ ] Подписи слайдов и названия приходят на RU при `?lang=ru`, на EN при `?lang=en`.
- [ ] PNG отдаются с прод-статики (200), в приложении картинки грузятся.
- [ ] Прод-БД забэкаплена перед ингестом; деплой без даунтайма.

## Подводные камни
- nginx проксит на бэкенд только `^/(api|auth)` — статика идёт прямо с frontend.
- CTA-слайд (`*_cta.png`) — маркетинг, в рецепт не класть.
- Эмбеддинг считается на ingest (Qwen) — нужен `QWEN/DASHSCOPE` ключ в окружении.
- Без `caption_ru/title_ru/name_ru` RU молча упадёт на английский фолбэк.
- Имена в `output/slideshows` (`grilled_chicken_bowl`) → slug через дефисы
  (`grilled-chicken-bowl`); проверить коллизии со старыми сидами.
