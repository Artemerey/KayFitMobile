# DEV BUILD BRIEF — KayFit 1.2.2 (build 8)

**Дата:** 2026-06-21
**Версия:** `1.2.2+8` (маркетинговая 1.2.2, прод 1.0.2 — публичный номер 1.2.2 выставлен намеренно)
**Базовая для сравнения:** 1.0.3+1 (v13, последняя одобренная Apple)
**Назначение:** устранение замечаний ревью по сборке 7 (`v122_build7_FEEDBACK_RU.md`).
Платежи/подписки **удалены из исходников полностью** (не выключены флагом) —
снимает риск Guideline 2.3.1 при статическом анализе бинаря.

---

## Что сделано в build 8 (поверх build 7)

### Блокирующие
1. **Платёжный слой удалён из исходников целиком:**
   - удалены `lib/features/paywall/` (`paywall_sheet.dart`, `paywall_feature_row.dart`, `paywall_plan_card.dart`)
   - удалён `lib/core/paywall/paywall_auto_show.dart` (авто-показ по `languageCode=='ru'` — это сокрытие, не решение)
   - удалён `lib/core/subscription/` (`subscription_provider.dart` + `.g.dart`, `require_subscription.dart`, `subscription_state.dart`)
   - вызовы `requireSubscription(...)` убраны из `add_meal_sheet.dart` и `chat_v2_screen.dart`
   - убраны промокоды (`POST /api/promo/apply`) и таймер «скидка сгорает»
   - в `lib/main.dart` убраны `import purchases_flutter` и `Purchases.configure(RC_IOS_KEY)`
   - `purchases_flutter` удалён из `pubspec.yaml`; `ios/Podfile.lock` перегенерирован (`pod install`) — RevenueCat/PurchasesHybridCommon больше не линкуются
2. **YooKassa / цены в ₽ удалены:** `backendSubscriptionProvider` (`GET /api/payments/subscription`) удалён вместе с `subscription_provider.dart`; ключи `tariffs_*` и символ `₽` в `lib/` отсутствуют.
3. **Юр-документы:** `lib/features/settings/screens/document_screen.dart` **не редактировался** — юр-тексты ведутся на стороне заказчика.
4. **F3 FatSecret:** `lib/shared/widgets/nutrient_detail_sheet.dart`, `_sourceConfig`, ветка `'fatsecret'` → `url: null` (бренд без лицензии не показываем). Ветки `usda`/`claude` без изменений.

### Мелкие
- **F5:** удалён мёртвый экран v1 `lib/features/add_meal/screens/barcode_scanner_screen.dart` (используется только `_v2`).
- Удалены остатки Telegram-логина: строка `auth_telegram` (arb) и `AppConfig.telegramBotUrl`.
- `ios/Runner/whatsnew.txt`: убрана строка про «месяц Premium за отзыв» (Guideline 5.6.1).
- Удалены осиротевшие строки подписки из локали (попадали в бинарь): `settings_sub_promo`, `settings_sale_ends`, `settings_sub_active_badge` — в `app_en.arb` и `app_ru.arb`, локализации перегенерированы.
- Удалён старый снапшот `build/appstore_release/KayFit_1.2.2_build7{,.zip}` (содержал полный paywall-код — не отгружать коллеге).

### Не менялось (оставлено как есть)
- Фикс разлогина (гонка refresh-токенов в `checkSession()` / `_refreshCompleter`).
- Фикс «вечной загрузки» в онбординге (`logout()` перед `/login`).
- Брендовый splash-экран.
- Нативный `InAppReview.requestReview()` (без звёзд / награды / таймера).
- SIWA + push-энтайтлменты, строки доступа (камера/микрофон/Face ID/фото/речь), iOS 16.

---

## Изменённые файлы (build 7 → build 8)

**Удалены:**
```
lib/core/paywall/paywall_auto_show.dart
lib/core/subscription/require_subscription.dart
lib/core/subscription/subscription_provider.dart
lib/core/subscription/subscription_provider.g.dart
lib/core/subscription/subscription_state.dart
lib/features/paywall/screens/paywall_sheet.dart
lib/features/paywall/widgets/paywall_feature_row.dart
lib/features/paywall/widgets/paywall_plan_card.dart
lib/features/add_meal/screens/barcode_scanner_screen.dart
```

**Изменены:**
```
lib/main.dart                                  — убран RevenueCat init/import
lib/core/analytics/analytics_service.dart      — убраны paywall/purchase события
lib/core/auth/auth_provider.dart               — убран Purchases (logout/identity)
lib/core/config/app_config.dart                — убран telegramBotUrl
lib/core/i18n/app_en.arb                        — убраны tariffs_*/sub_* строки, auth_telegram
lib/core/i18n/app_ru.arb                        — убраны tariffs_*/sub_* строки, auth_telegram
lib/core/i18n/generated/app_localizations*.dart— регенерация
lib/features/add_meal/screens/add_meal_sheet.dart — убран requireSubscription(...)
lib/features/chat/screens/chat_v2_screen.dart  — убран requireSubscription(...)
lib/shared/widgets/nutrient_detail_sheet.dart  — FatSecret url: null
ios/Runner/whatsnew.txt                        — убрана строка про Premium за отзыв
ios/Podfile.lock                               — pod install без RevenueCat
pubspec.yaml                                   — version 1.2.2+8, убран purchases_flutter
pubspec.lock                                   — регенерация
```

---

## dart-define для сборки

Платёжных dart-define **нет** (`RC_IOS_KEY` больше не используется). Активные:

| Define | Назначение | Default |
|---|---|---|
| `KF2_JOURNAL` | журнал v2 (роутер) | `true` |
| `KF2_CHAT` | вкладка чата | `true` |
| `KF2_RECOG` | ИИ-распознавание | `true` |
| `APPLE_SERVICES_ID` | Service ID для Sign in with Apple | `com.kayfit.app.auth` |
| `APPLE_REDIRECT_URI` | redirect callback SIWA | `https://app.carbcounter.online/api/v1/auth/apple/callback` |

Дефолты подходят для прод-сборки — можно собирать **без** дополнительных `--dart-define`.

---

## Проверки перед отгрузкой
- [x] `flutter analyze` — без ошибок (живой `lib/`)
- [x] нет ссылок на `purchases_flutter`/`RevenueCat`/`requireSubscription`/`api/promo`/`tariffs_*`/`₽` в `lib/`
- [x] `ios/Podfile.lock` без RevenueCat
- [x] `document_screen.dart` не тронут
- [ ] финальная сборка `flutter build ios --release` и свежий пакет в `build/appstore_release/`
