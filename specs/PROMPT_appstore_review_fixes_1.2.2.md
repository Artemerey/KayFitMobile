# Стартовый промт — App Store review fixes для KayFit 1.2.2(6)

Скопируй всё ниже в новое окно Claude Code.

---

Проект **KayFit** (Flutter): `/Users/user/Desktop/КУРСОР/mobileKayfit`, ветка `master`, версия сейчас `1.2.2+6`.
Бэкенд: `/Users/user/Desktop/КУРСОР/CaloriesApp_backend` (прод уже живой, трогать не нужно).
Прод-сервер для приложения: `https://app.carbcounter.online`.

## Задача

Взять текущую сборку master `1.2.2+6` и внести правки по **отчёту App Store review** (это блокеры повторной отправки в стор). Цель — собрать билд, который пройдёт ревью. Перед стартом прочитай отчёт целиком: `specs/REVIEW_1.2.2+6.md` (если файла нет — он вставлен в конце этого промта). Работай по TDD/аккуратно, после правок собери и поставь на iPhone (скилл `kayfit-release`), затем подготовь чистый SOURCE-пакет для коллеги (раздел «App Store handoff» в том же скилле).

## Что НЕ трогать (эти фиксы корректны, сохранить)

- Фикс спонтанного разлогина (гонка refresh-токенов в `checkSession()`).
- Фикс «вечной загрузки» после экрана плана в онбординге.
- Брендовый splash-экран на старте.
- Серверные фиксы kJ/ккал и калорийности напитков (они уже в проде, это другой репозиторий).

## Блокеры из отчёта — что сделать

### 1. Убрать экран «Получи Premium в подарок» (review-prompt) ПОЛНОСТЬЮ
- Файл: `lib/features/review_prompt/screens/review_prompt_screen.dart`, маршрут `/review-prompt`.
- Показывается каждому после онбординга (и email-, и Apple-вход). Нарушает Guideline **5.6.1 / 3.2.2** (награда за отзыв) и фильтрует по оценке (4–5★ → форма в App Store, 1–3★ → локальная «благодарность») + фейковый таймер.
- Удалить: сам экран, его маршрут и логику в `lib/router.dart` (там `showReviewPromptProvider`, выставляется в `true` ~строка 82 после онбординга; маршрут `/review-prompt` ~строка 194), переходы из `login_screen`.
- Запрос отзыва, если нужен, — ТОЛЬКО нативный `InAppReview.requestReview()` (`SKStoreReviewController`) в нейтральный момент, без звёзд / награды / прямой ссылки на форму. Зависимость `in_app_review: ^2.0.9` уже есть, обёртка — `lib/core/review/app_review_service.dart`.

### 2. Убрать российскую оплату мимо Apple + видимый paywall
- Сейчас сборка идёт без `--dart-define=BYPASS_PAYWALL=true`, т.е. `kBypassPaywall=false`, и экраны тарифов/paywall видны в проде. Единственная рабочая кнопка оплаты ведёт на рос. веб-оплату `app.carbcounter.online/tariffs` (`/api/payments/request-session`), «Мир»/СБП. Нарушает Guideline **3.1.1** + риск на весь аккаунт разработчика.
- **Удалить** платёжный слой, связанный с Россией: веб-оплата в `TariffsScreen` (`lib/features/tariffs/screens/tariffs_screen.dart`), `payment_help_screen.dart`, `payment_method_sheet.dart`, «Мир»/СБП, инструкции по смене региона Apple ID, метод `openPaymentPage()`.
- **НЕ прятать по локали.** Сейчас в `lib/router.dart:72` есть `if (langCode == 'ru' && !kBypassPaywall)` — скрытие по `languageCode == 'ru'` само по себе нарушение Guideline **2.3.1**. Убрать поверхности по-настоящему, а не за условием локали.
- Paywall/тарифы **не включать** в проде, пока не будет отдельной команды. Для текущего билда приложение по факту без платных стен (всё доступно). Свериться со всеми местами `kBypassPaywall` (`journal_v2_screen.dart`, `settings_v2_screen.dart`, `settings_screen.dart`, `paywall_flags.dart`).

### 3. Юридические документы — вернуть нашу версию (v13 = `1.0.3+1`)
- Файл: `lib/features/settings/screens/document_screen.dart`.
- В сборке 1.2.2(6) тексты снова переписаны (ИП Чистяков, ИНН/ОГРНИП, Саратов, ФЗ-152, цены в ₽, личный Gmail `artemeree@gmail.com`) — это НЕ наша версия.
- Откатить к эталону v13: `git show v1.0.3+1:lib/features/settings/screens/document_screen.dart` — взять оттуда контент. Дальше файл не трогать.

## После правок

1. Поднять build-номер в `pubspec.yaml` (`1.2.2+6` → `1.2.2+7` или по согласованию), `flutter pub get`.
2. `flutter analyze` чисто, прогнать тесты.
3. Собрать и поставить на iPhone через скилл `kayfit-release` (Procedure B, устройство `00008101-000E39143E90801E`). Дать чек-лист на проверку: онбординг без экрана review-prompt, в настройках/журнале нет paywall и рос. оплаты, легал-доки — наша версия.
4. Подготовить SOURCE-пакет для коллеги в `build/appstore_release/` (НЕ бинарь), по разделу «App Store handoff» скилла. Коммиты — по фазам, как обычно.

## Важные нюансы окружения

- В рабочем дереве есть `lib/core/paywall/paywall_flags.dart` (`BYPASS_PAYWALL`). Решение по удалению поверхностей должно работать БЕЗ флага (для стора), а не полагаться на `BYPASS_PAYWALL=true`.
- pbxproj должен оставаться стоковым (`com.kayfit.app`, team `MH4VYBU68D`) для App Store; dev-патчи для установки на телефон откатывать после сборки (скилл это описывает).
- Перед хэндовером: `git diff ios/Runner.xcodeproj/project.pbxproj` пустой, нет `RunnerDebug.entitlements`, `git stash list` чистый.

---

(Вставь сюда полный текст отчёта `KayFit_1.2.2+6_отчёт_полный.md`, если новой сессии нужен исходник дословно.)
