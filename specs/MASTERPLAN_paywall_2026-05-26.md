# MASTERPLAN: Paywall + RevenueCat — KayFit
**Дата:** 2026-05-26  
**Статус:** Утверждён к реализации  
**Версия приложения:** 1.0.4+1  
**Bundle ID:** `com.kayfit.app`

---

## 1. Финальная архитектура

### Решение: RevenueCat вместо `in_app_purchase`

**Что используем:**
- `purchases_flutter` (RevenueCat Flutter SDK) вместо `in_app_purchase`
- RevenueCat Dashboard как единственный источник истины по статусу подписки
- Webhook от RevenueCat → FastAPI бэкенд для обновления БД
- Apple StoreKit 2 (задействуется автоматически на iOS 15+, у нас target 16.0)

**Ключевые решения:**
- RevenueCat кэширует `CustomerInfo` in-memory автоматически — не нужно отдельного кэша
- Receipt validation делает RevenueCat на своей стороне, бэкенд только получает webhook
- `SubscriptionState` включает `GracePeriod` (billing issue, grace period у Apple = 16 дней)
- `PurchaseStatus.pending` (Ask-to-Buy) обрабатывается явно — показывается "Ожидание"
- Cooldown показа пейвола — in-memory `DateTime?`, не SharedPreferences; сбрасывается при активной подписке
- Системный диалог Apple появляется поверх sheet — sheet остаётся открытым до финального статуса
- `lib/core/iap/` — удалить полностью, заменить на `lib/core/subscription/`
- Цены в UI — исключительно из RevenueCat `StoreProduct.localizedPriceString`, не хардкодить

**Почему RevenueCat победил:**
- Нулевая серверная логика валидации чеков (Risk: двойное списание, network failure mid-purchase)
- Встроенная обработка pending transactions (Ask-to-Buy), grace period, refund events
- Offline caching + idempotency из коробки
- Webhook готов за 20 минут vs custom Apple Server API
- Бесплатен до $2500 MRR

---

## 2. Зависимости и блокеры (до кода)

> Всё нижеперечисленное — ручная работа, не автоматизируется. Блокирует Track A, который блокирует Track B, D.

### 2.1 App Store Connect (Manuel)

**Шаг 1: Subscription Group**
1. Войти в [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Выбрать приложение KayFit → **Monetization → Subscriptions**
3. Создать группу: `KayFit Premium` (reference name)

**Шаг 2: Создать 3 продукта**

| Product ID | Название (RU) | Длительность | Цена (рекомендовано) |
|---|---|---|---|
| `com.kayfit.app.sub.monthly` | KayFit Premium — Месяц | 1 Month | Tier 3 (~299₽) |
| `com.kayfit.app.sub.quarterly` | KayFit Premium — 3 Месяца | 3 Months | Tier 7 (~699₽) |
| `com.kayfit.app.sub.yearly` | KayFit Premium — Год | 1 Year | Tier 12 (~1990₽) |

Для каждого продукта:
- Добавить локализацию RU: название + описание
- Добавить локализацию EN: название + описание
- **Introductory Offers → Add** → Free Trial → 7 Days → Customer Eligibility: **New subscribers only**

**Шаг 3: Налоги и банковские данные**
- Agreements, Tax, and Banking → убедиться что Paid Apps Agreement подписан
- Без этого покупки не работают даже в sandbox

**Шаг 4: Sandbox тестовые аккаунты**
- Users and Access → Sandbox → Testers → Add 2-3 тестовых Apple ID (не твой реальный)
- Email должен быть реальным (используется для активации)

### 2.2 RevenueCat Dashboard

**Шаг 1: Создать проект**
1. [app.revenuecat.com](https://app.revenuecat.com) → New Project → `KayFit`
2. Add App → App Store → Bundle ID: `com.kayfit.app`
3. Получить **Public API Key** (начинается с `appl_...`) — нужен в Flutter
4. Получить **Secret API Key** — нужен для webhook авторизации

**Шаг 2: Добавить продукты**
- RevenueCat Dashboard → Products → Import from App Store Connect
- Если авто-импорт недоступен — добавить вручную 3 Product ID

**Шаг 3: Создать Entitlement**
- Entitlements → `+ New` → Identifier: `premium` → прикрепить все 3 продукта

**Шаг 4: Создать Offering**
- Offerings → `+ New` → Identifier: `default`
- Packages: добавить `$rc_monthly`, `$rc_three_month`, `$rc_annual` (или custom IDs)
- Прикрепить соответствующие продукты к пакетам

**Шаг 5: Настроить webhook**
- Integrations → Webhooks → Add Endpoint
- URL: `https://app.carbcounter.online/api/payments/revenuecat-webhook`
- Events: `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `EXPIRATION`, `BILLING_ISSUE`, `REFUND`, `SUBSCRIBER_ALIAS`
- Authorization header value: придумать shared secret (UUID или 32+ символов) → записать в `.env` бэкенда

**Шаг 6: Получить ключи**
- Project Settings → API Keys → скопировать iOS Public SDK key
- Записать в Flutter в `lib/core/config/app_config.dart` или через `--dart-define`

### 2.3 Что нужно передать разработчику Flutter
```
REVENUECAT_IOS_KEY=appl_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 2.4 Что нужно передать разработчику бэкенда
```
REVENUECAT_WEBHOOK_SECRET=<shared_secret_из_п2.5>
```

---

## 3. Параллельные треки работы

```
Track A (Manuel): App Store + RevenueCat setup
    │
    ├──► Track B: Flutter Core (subscription_provider, RC init)
    │        │
    │        ├──► Track D: Gates (зависит от Track B)
    │        └──► Track C: Paywall UI (может идти параллельно с mock)
    │
    ├──► Track C: Paywall UI (независим, mock state)
    ├──► Track E: Backend webhook (независим от frontend)
    └──► Track F: i18n (независим от всего, кроме строк)
```

**Критический путь:** A → B → D  
**Параллельно с B:** C, E, F

---

## 4. Детальные задачи по трекам

---

### Track A: Setup (Manuel, блокирует B и D)

**A-1: App Store Connect**
- Файлы: нет (web UI)
- Что сделать: создать Subscription Group + 3 продукта + 7-day trial offer (см. §2.1)
- Done when: все 3 продукта в статусе "Ready to Submit" в App Store Connect

**A-2: RevenueCat project**
- Файлы: нет (web UI)
- Что сделать: создать проект, добавить iOS app, продукты, entitlement `premium`, offering `default` (см. §2.2)
- Done when: в RevenueCat Dashboard видны 3 пакета в offering `default`, entitlement `premium` прикреплён

**A-3: Выдать ключи**
- Что сделать: передать `REVENUECAT_IOS_KEY` разработчику Flutter; `REVENUECAT_WEBHOOK_SECRET` — бэкенду
- Done when: ключи получены обеими сторонами

---

### Track B: Flutter — Core

**B-1: Добавить зависимость**
- Файл: `pubspec.yaml`
- Что сделать: добавить `purchases_flutter: ^8.0.0` в `dependencies`
- Done when: `flutter pub get` проходит без ошибок

**B-2: Subscription state**
- Файл: `lib/core/subscription/subscription_state.dart` (новый)
- Что сделать:
```dart
sealed class SubscriptionState {
  const SubscriptionState();
}

final class SubscriptionActive extends SubscriptionState {
  const SubscriptionActive({
    required this.productId,
    required this.expiresAt,
  });
  final String productId;
  final DateTime expiresAt;
}

final class SubscriptionExpired extends SubscriptionState {
  const SubscriptionExpired();
}

final class SubscriptionGracePeriod extends SubscriptionState {
  /// Apple grace period: до 16 дней при billing issue.
  /// Контент доступен, но нужно предупреждение об оплате.
  const SubscriptionGracePeriod({required this.expiresAt});
  final DateTime expiresAt;
}

final class SubscriptionPending extends SubscriptionState {
  /// Ask-to-Buy: покупка ожидает одобрения родителя.
  const SubscriptionPending();
}

final class SubscriptionUnknown extends SubscriptionState {
  /// Начальное состояние — RevenueCat ещё не ответил.
  const SubscriptionUnknown();
}
```
- Done when: файл создан, компилируется

**B-3: Subscription provider**
- Файл: `lib/core/subscription/subscription_provider.dart` (новый)
- Что сделать:
```dart
@Riverpod(keepAlive: true)
class SubscriptionNotifier extends _$SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionUnknown();

  /// Вызывать при старте приложения и при resume.
  Future<void> refresh() async {
    try {
      final info = await Purchases.getCustomerInfo();
      state = _stateFromCustomerInfo(info);
    } on PurchasesErrorCode catch (_) {
      // Не меняем state — оставляем последний известный
    }
  }

  Future<PaywallResult> purchase(Package package) async {
    try {
      final info = await Purchases.purchasePackage(package);
      state = _stateFromCustomerInfo(info);
      return state is SubscriptionActive
          ? PaywallResult.subscribed
          : PaywallResult.cancelled;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return PaywallResult.cancelled;
      }
      if (e == PurchasesErrorCode.paymentPendingError) {
        state = const SubscriptionPending();
        return PaywallResult.pending;
      }
      rethrow;
    }
  }

  Future<void> restore() async {
    final info = await Purchases.restorePurchases();
    state = _stateFromCustomerInfo(info);
  }

  SubscriptionState _stateFromCustomerInfo(CustomerInfo info) {
    final premium = info.entitlements.all['premium'];

    if (premium != null && premium.isActive) {
      if (premium.billingIssueDetectedAt != null) {
        // Grace period — Apple даёт 16 дней при проблеме с оплатой
        return SubscriptionGracePeriod(
          expiresAt: premium.expirationDate ?? DateTime.now().add(const Duration(days: 16)),
        );
      }
      return SubscriptionActive(
        productId: premium.productIdentifier,
        expiresAt: premium.expirationDate ?? DateTime(2099),
      );
    }
    return const SubscriptionExpired();
  }
}

enum PaywallResult { subscribed, cancelled, pending }
```
- Зависимости: B-2, Track A (ключ RevenueCat)
- Done when: провайдер компилируется, unit-тест с mock CustomerInfo проходит

**B-4: Инициализация RevenueCat в main.dart**
- Файл: `lib/main.dart`
- Что сделать: добавить `Purchases.configure(PurchasesConfiguration(revenueCatApiKey))` до `runApp`; API key через `const String.fromEnvironment('REVENUECAT_IOS_KEY')` или `AppConfig.revenueCatKey`
- Добавить `Purchases.setLogLevel(LogLevel.debug)` только для debug builds
- Done when: приложение стартует без ошибок RevenueCat, в логах виден инит

**B-5: Refresh при resume**
- Файл: `lib/main.dart` (в `_AppInitState.didChangeAppLifecycleState`)
- Что сделать: при `AppLifecycleState.resumed` вызывать `ref.read(subscriptionNotifierProvider.notifier).refresh()`
- Done when: после возврата из настроек подписки iOS статус обновляется

**B-6: Paywall gate utility**
- Файл: `lib/core/subscription/require_subscription.dart` (новый)
- Что сделать:
```dart
// Cooldown: не показывать пейвол чаще 1 раза в 24ч при SubscriptionExpired.
// in-memory — сбрасывается при перезапуске и при активной подписке.
DateTime? _lastPaywallShown;

Future<bool> requireSubscription(BuildContext context, WidgetRef ref) async {
  final state = ref.read(subscriptionNotifierProvider);

  // Активна или grace period — пропускаем
  if (state is SubscriptionActive || state is SubscriptionGracePeriod) return true;

  // Pending — показываем заглушку и возвращаем false
  if (state is SubscriptionPending) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.paywall_pending_message)),
      );
    }
    return false;
  }

  // Cooldown — не спамим пейволом
  final now = DateTime.now();
  if (_lastPaywallShown != null &&
      now.difference(_lastPaywallShown!) < const Duration(hours: 24)) {
    return false;
  }

  if (!context.mounted) return false;
  _lastPaywallShown = now;

  final result = await showPaywallSheet(context, ref);

  // Если подписался — сбрасываем cooldown
  if (result == PaywallResult.subscribed) {
    _lastPaywallShown = null;
    return true;
  }
  return false;
}
```
- Зависимости: B-3
- Done when: функция компилируется, cooldown работает в unit-тесте

---

### Track C: Frontend — Paywall UI

> Не зависит от Track A/B если использует mock state. Можно делать параллельно.

**C-1: PaywallFeatureRow widget**
- Файл: `lib/features/paywall/widgets/paywall_feature_row.dart` (новый)
- Что сделать: виджет из одной строки фичи: emoji-иконка (40px) + колонка(title 14px bold + subtitle 13px grey). Stateless, принимает `icon`, `title`, `subtitle`.
- Done when: виджет отображается корректно в изоляции (widget test)

**C-2: PaywallPlanCard widget**
- Файл: `lib/features/paywall/widgets/paywall_plan_card.dart` (новый)
- Что сделать: карточка тарифа. Параметры: `label`, `price`, `period`, `badge` (nullable), `isSelected`, `onTap`.
  - Выбранная: фон `Color(0x29FF597D)`, border `Color(0xFFFF597D)` 1.5px
  - Невыбранная: фон white, border `Color(0xFFE5E7EB)`
  - Если `badge != null` — показать pill-бейдж (★ ПОПУЛЯРНЫЙ / 🔥 −40%)
- Done when: обе вариации (selected/unselected) выглядят по wireframe

**C-3: PaywallSheet основной экран**
- Файл: `lib/features/paywall/screens/paywall_sheet.dart` (новый)
- Что сделать: полноэкранный `DraggableScrollableSheet` (или `showModalBottomSheet` с `isScrollControlled: true`)

  Структура:
  1. Drag handle (серый, 4×32px, centered, `BorderRadius.circular(2)`)
  2. Hero-иллюстрация, 180px высота, placeholder `Container(color: Color(0xFFFFD4C2))` — заменить когда появится ассет
  3. Заголовок: две строки `paywall_title_line1` + `paywall_title_line2`, 32px, bold, `Color(0xFF060606)`
  4. Подзаголовок: `paywall_subtitle`, 14px, `Color(0xFF606770)`
  5. Divider
  6. 3x `PaywallFeatureRow`: фото, голос, чат
  7. Divider
  8. Ряд из 3 карточек: Monthly, Quarterly (selected по умолчанию), Trial/Free-7-days
  9. Широкая карточка Yearly ниже (растянутая на всю ширину) — отдельный Row
  10. CTA кнопка: `paywall_cta`, высота 56px, `BorderRadius.circular(14)`, `Color(0xFFFF597D)`, белый текст 16px bold
  11. `paywall_cta_hint`, 12px, `Color(0xFFAAB2BD)`
  12. TextButton `paywall_dismiss`, 14px, `Color(0xFFAAB2BD)`
  13. Row из TextButton: `paywall_restore` · `paywall_terms` · `paywall_privacy`

  Цвет фона: `Color(0xFFFFF1EA)` (тот же что у `tariffs_screen`)

  State:
  - `_selectedPackage`: Package из RevenueCat Offering, default = quarterly
  - При получении Offering из RevenueCat — заполнять цены из `StoreProduct.localizedPriceString`
  - Пока Offering грузится — `CircularProgressIndicator` вместо карточек
  - При нажатии CTA — вызывать `ref.read(subscriptionNotifierProvider.notifier).purchase(_selectedPackage)`
  - Держать sheet открытым во время покупки (Apple диалог появляется поверх)
  - После ответа `PaywallResult.subscribed` → `Navigator.pop(context, PaywallResult.subscribed)`
  - После `PaywallResult.cancelled` → sheet остаётся открытым (пользователь может выбрать другой план)
  - После `PaywallResult.pending` → показать `paywall_pending_message`, закрыть sheet

  Функция открытия:
  ```dart
  Future<PaywallResult?> showPaywallSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<PaywallResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(parent: ProviderScope.containerOf(context),
        child: const PaywallSheet()),
    );
  }
  ```

- Зависимости: C-1, C-2, B-3 (или mock state)
- Done when: sheet открывается, карточки кликабельны, CTA делает покупку через RC

**C-4: Restore purchases**
- В рамках C-3: кнопка "Восстановить" вызывает `ref.read(subscriptionNotifierProvider.notifier).restore()`, затем если `state is SubscriptionActive` — закрыть sheet с `PaywallResult.subscribed`, иначе — `SnackBar` "Активная подписка не найдена"
- Done when: restore работает в sandbox

---

### Track D: Frontend — Gates (зависит от B-3, B-6)

**D-1: Gate в kf2_capture_screen.dart**
- Файл: `lib/features/add_meal/screens/kf2_capture_screen.dart`
- Что сделать: в точке открытия камеры (до `ImagePicker.pickImage`) добавить:
  ```dart
  final allowed = await requireSubscription(context, ref);
  if (!allowed) return;
  ```
- Done when: без подписки нажатие на кнопку камеры открывает пейвол

**D-2: Gate в add_meal_sheet.dart (голос)**
- Файл: `lib/features/add_meal/screens/add_meal_sheet.dart`
- Что сделать: в `onVoice` callback (строка ~485 — `_switchMode(_InputMode.voice)`) добавить check перед `_switchMode`:
  ```dart
  final allowed = await requireSubscription(context, ref);
  if (!allowed) return;
  ```
- Done when: нажатие на 🎙️ без подписки открывает пейвол

**D-3: Gate в chat_v2_screen.dart**
- Файл: `lib/features/chat/screens/chat_v2_screen.dart`
- Что сделать: в методе `_send()` (~строка 327) в начале добавить:
  ```dart
  final allowed = await requireSubscription(context, ref);
  if (!allowed) return;
  ```
  Проверять только один раз на сессию (не при каждом сообщении): добавить `bool _subscriptionChecked = false` в state, устанавливать в `true` после первой успешной проверки.
- Done when: первое сообщение в чате без подписки открывает пейвол

---

### Track E: Backend

**E-1: RevenueCat webhook endpoint**
- Файл(ы): `app/api/payments/` (конкретный путь — по структуре бэкенда)
- Что сделать: `POST /api/payments/revenuecat-webhook`

  ```python
  @router.post("/revenuecat-webhook")
  async def revenuecat_webhook(
      request: Request,
      db: AsyncSession = Depends(get_db),
  ):
      # 1. Верификация
      auth = request.headers.get("Authorization", "")
      if auth != f"Bearer {settings.REVENUECAT_WEBHOOK_SECRET}":
          raise HTTPException(status_code=401)

      body = await request.json()
      event_type = body.get("event", {}).get("type")
      subscriber = body.get("event", {}).get("app_user_id")  # или original_app_user_id

      # 2. Обработка событий
      if event_type in ("INITIAL_PURCHASE", "RENEWAL"):
          expires_at = body["event"].get("expiration_at_ms")
          await upsert_subscription(db, subscriber, active=True,
                                     expires_at=ms_to_dt(expires_at))

      elif event_type in ("CANCELLATION", "EXPIRATION"):
          await upsert_subscription(db, subscriber, active=False)

      elif event_type == "BILLING_ISSUE":
          # Grace period — не деактивируем, RevenueCat сам деактивирует по expiration
          pass

      elif event_type == "REFUND":
          await upsert_subscription(db, subscriber, active=False)

      return {"ok": True}
  ```

  RevenueCat `app_user_id` должен совпадать с нашим user ID. Устанавливать при логине:
  ```dart
  await Purchases.logIn(userId);  // после успешной аутентификации
  ```

- Зависимости: Track A (webhook URL и secret)
- Done when: тестовый POST с корректным `Authorization` header возвращает 200; с неверным — 401

**E-2: Схема БД**
- Файл: новая Alembic миграция или добавление в существующую таблицу `subscriptions`
- Что сделать: убедиться что таблица `subscriptions` имеет поля: `user_id`, `is_active`, `expires_at`, `product_id`, `updated_at`. Добавить индекс по `user_id`.
- Done when: миграция применяется без ошибок

**E-3: Endpoint статуса подписки (опционально, но рекомендуется)**
- `GET /api/payments/subscription-status` → `{"is_active": bool, "expires_at": "ISO8601 | null"}`
- Используется Flutter при старте как дополнительная верификация (RevenueCat = источник истины, бэкенд = кэш для серверных проверок)
- Done when: endpoint возвращает корректный статус после webhook

---

### Track F: i18n (независим)

- Файлы: `lib/core/i18n/app_ru.arb`, `lib/core/i18n/app_en.arb`
- Что сделать: добавить все строки из §5
- Done when: `flutter gen-l10n` проходит без ошибок, все новые ключи доступны в `AppLocalizations`

---

## 5. Полный список i18n-строк

### app_ru.arb — добавить

```json
{
  "paywall_title_line1": "ИИ считает калории.",
  "paywall_title_line2": "Ты просто ешь.",
  "paywall_subtitle": "Сфотографируй тарелку, скажи голосом или спроси нутрициолога — KayFit запишет всё сам.",

  "paywall_feature_photo_title": "Фото → КБЖУ за секунды",
  "paywall_feature_photo_subtitle": "ИИ определяет ингредиенты и вес порции",
  "paywall_feature_voice_title": "Скажи вслух",
  "paywall_feature_voice_subtitle": "«Съел куриный плов» → залогировано сразу",
  "paywall_feature_chat_title": "Нутрициолог в кармане",
  "paywall_feature_chat_subtitle": "Спроси о питании — ответит и запишет",

  "paywall_plan_trial_label": "7 дней",
  "paywall_plan_trial_sub": "бесплатно",
  "paywall_plan_trial_then": "затем {price}/мес",
  "@paywall_plan_trial_then": {
    "placeholders": {
      "price": {"type": "String"}
    }
  },
  "paywall_plan_monthly_label": "Месяц",
  "paywall_plan_quarterly_label": "3 месяца",
  "paywall_plan_quarterly_badge": "★ ПОПУЛЯРНЫЙ",
  "paywall_plan_yearly_label": "Год",
  "paywall_plan_yearly_badge": "🔥 −40%",
  "paywall_plan_per_month": "{price}/мес",
  "@paywall_plan_per_month": {
    "placeholders": {
      "price": {"type": "String"}
    }
  },

  "paywall_cta": "Начать 7 дней бесплатно",
  "paywall_cta_no_trial": "Оформить подписку",
  "paywall_cta_hint": "Отменить до конца 7 дней — ничего не спишется",
  "paywall_dismiss": "Нет, буду вводить руками",

  "paywall_restore": "Восстановить",
  "paywall_terms": "Условия",
  "paywall_privacy": "Политика",

  "paywall_restore_success": "Подписка восстановлена",
  "paywall_restore_not_found": "Активная подписка не найдена",
  "paywall_restore_error": "Не удалось восстановить подписку",

  "paywall_loading_error": "Не удалось загрузить тарифы",
  "paywall_purchase_error": "Ошибка при оформлении. Попробуйте снова.",
  "paywall_pending_message": "Покупка ожидает подтверждения",

  "paywall_grace_period_banner": "Проблема с оплатой. Обновите способ оплаты в настройках Apple ID."
}
```

### app_en.arb — добавить

```json
{
  "paywall_title_line1": "AI counts calories.",
  "paywall_title_line2": "You just eat.",
  "paywall_subtitle": "Snap a plate, say it out loud, or ask the nutritionist — KayFit logs it all.",

  "paywall_feature_photo_title": "Photo → Nutrition in seconds",
  "paywall_feature_photo_subtitle": "AI identifies ingredients and portion weight",
  "paywall_feature_voice_title": "Just say it",
  "paywall_feature_voice_subtitle": "\"Had chicken rice\" → logged instantly",
  "paywall_feature_chat_title": "Nutritionist in your pocket",
  "paywall_feature_chat_subtitle": "Ask about nutrition — it answers and logs",

  "paywall_plan_trial_label": "7 days",
  "paywall_plan_trial_sub": "free",
  "paywall_plan_trial_then": "then {price}/mo",
  "@paywall_plan_trial_then": {
    "placeholders": {
      "price": {"type": "String"}
    }
  },
  "paywall_plan_monthly_label": "Monthly",
  "paywall_plan_quarterly_label": "3 Months",
  "paywall_plan_quarterly_badge": "★ POPULAR",
  "paywall_plan_yearly_label": "Yearly",
  "paywall_plan_yearly_badge": "🔥 −40%",
  "paywall_plan_per_month": "{price}/mo",
  "@paywall_plan_per_month": {
    "placeholders": {
      "price": {"type": "String"}
    }
  },

  "paywall_cta": "Start 7 Days Free",
  "paywall_cta_no_trial": "Subscribe Now",
  "paywall_cta_hint": "Cancel before 7 days — you won't be charged",
  "paywall_dismiss": "No thanks, I'll log manually",

  "paywall_restore": "Restore",
  "paywall_terms": "Terms",
  "paywall_privacy": "Privacy",

  "paywall_restore_success": "Subscription restored",
  "paywall_restore_not_found": "No active subscription found",
  "paywall_restore_error": "Couldn't restore subscription",

  "paywall_loading_error": "Failed to load plans",
  "paywall_purchase_error": "Purchase failed. Please try again.",
  "paywall_pending_message": "Purchase is pending approval",

  "paywall_grace_period_banner": "Payment issue. Update your payment method in Apple ID settings."
}
```

---

## 6. Порядок мёрджа

```
PR 1: feat/paywall-backend        (Track E — независим)
  ↓  (параллельно)
PR 2: feat/paywall-i18n           (Track F — независим)
  ↓  (после Track A завершён)
PR 3: feat/paywall-core           (Track B — B-1, B-2, B-3, B-4, B-5)
  ↓
PR 4: feat/paywall-ui             (Track C — требует PR 2 + PR 3)
  ↓
PR 5: feat/paywall-gates          (Track D — требует PR 3 + PR 4)
```

**Порядок ревью:**
1. PR 1 и PR 2 — независимы, ревьюить параллельно
2. PR 3 — после получения ключей RevenueCat (Track A завершён)
3. PR 4 — после мёрджа PR 2 (i18n) и PR 3 (core)
4. PR 5 — финальный, после мёрджа PR 3 + PR 4; перед мёрджем — полный smoke test

---

## 7. Тестирование

### 7.1 Без реальной карты (StoreKit Testing + RevenueCat Sandbox)

**Способ 1: Xcode StoreKit Configuration (для unit/widget тестов)**
1. Xcode → File → New → File → StoreKit Configuration File → `KayFitTest.storekit`
2. Добавить 3 Auto-Renewable Subscriptions с теми же Product ID
3. Схема запуска: Xcode → Edit Scheme → Run → Options → StoreKit Configuration → `KayFitTest.storekit`
4. В этом режиме покупки проходят моментально без подтверждения

**Способ 2: Sandbox TestFlight (для E2E тестов на устройстве)**
1. Использовать Sandbox Apple ID (создан в §2.1 шаг 4)
2. На устройстве: Settings → App Store → выйти из реального Apple ID → войти с Sandbox ID
3. RevenueCat Dashboard → Customers → найти пользователя → проверить события
4. В Sandbox: подписки автоматически ускоряются (1 месяц = 5 минут)

**RevenueCat Debug overlay:**
```dart
// Только в debug режиме — показывает оверлей с CustomerInfo
if (kDebugMode) {
  await Purchases.setDebugLogsEnabled(true);
}
```

### 7.2 Обязательные сценарии перед релизом

| # | Сценарий | Ожидаемый результат |
|---|---|---|
| 1 | Новый пользователь → нажать 📸 камеру → пейвол появился | Пейвол открывается |
| 2 | Нажать "Начать 7 дней бесплатно" (Sandbox) → подтвердить | Пейвол закрывается, камера открывается |
| 3 | Закрыть приложение, открыть снова → нажать 📸 | Камера открывается сразу (нет пейвола) |
| 4 | Нажать 🎙️ голос без подписки | Пейвол открывается |
| 5 | Открыть чат без подписки → набрать сообщение → отправить | Пейвол появляется |
| 6 | Нажать "Нет, буду вводить руками" | Пейвол закрывается, фича недоступна |
| 7 | Нажать "Восстановить" с активной подпиской на другом Apple ID | SnackBar "Подписка восстановлена" |
| 8 | Нажать "Восстановить" без активной подписки | SnackBar "Активная подписка не найдена" |
| 9 | Выбрать Monthly → нажать CTA | RevenueCat получает событие INITIAL_PURCHASE |
| 10 | Ask-to-Buy: купить с дочернего Sandbox аккаунта | SnackBar "Покупка ожидает подтверждения" |
| 11 | Cooldown: закрыть пейвол → немедленно нажать 📸 снова | Пейвол НЕ открывается (cooldown 24ч) |
| 12 | RevenueCat webhook: отправить тестовый INITIAL_PURCHASE | БД обновлена, `is_active=true` |
| 13 | Пейвол открыт → системный диалог Apple → отмена | Sheet остаётся открытым |
| 14 | Пейвол открыт → системный диалог Apple → успех | Sheet закрывается с `subscribed` |

### 7.3 Unit тесты (обязательно написать в PR 3)

```
test/core/subscription/subscription_provider_test.dart
  ✓ SubscriptionActive при active entitlement без billingIssue
  ✓ SubscriptionGracePeriod при active entitlement с billingIssueDetectedAt != null
  ✓ SubscriptionExpired при inactive entitlement
  ✓ SubscriptionPending при PurchasesErrorCode.paymentPendingError
  ✓ cooldown: second call within 24h returns false without showing paywall

test/features/paywall/paywall_sheet_test.dart
  ✓ показывает loading indicator пока грузится Offering
  ✓ отображает карточки после загрузки Offering
  ✓ quarterly выбран по умолчанию
  ✓ CTA текст меняется при выборе yearly
```

---

## 8. Чеклист перед App Review

Apple проверяет следующее при наличии IAP:

### Обязательно (reject при отсутствии)

- [ ] **Кнопка Restore** — обязательна на экране с платным контентом (GUIDELINE 3.1.1)
- [ ] **Кнопка Terms of Service** — ссылка на EULA
- [ ] **Кнопка Privacy Policy** — ссылка на Privacy Policy
- [ ] **Цены из StoreKit** — не хардкодить, брать из `StoreProduct.localizedPriceString`
- [ ] **Период подписки явно указан** — "1 месяц", "3 месяца", "1 год" — не просто "подписка"
- [ ] **Сумма списания указана** — пользователь должен видеть цену ДО нажатия CTA
- [ ] **Условия пробного периода** — "7 дней бесплатно, затем [цена]/[период]" на экране перед покупкой

### Критично для UI

- [ ] **Hint под кнопкой** — `paywall_cta_hint`: "Отменить до конца 7 дней — ничего не спишется" — должна быть видна без прокрутки
- [ ] **Тип подписки** — Auto-Renewable Subscription (не разовая)
- [ ] **Subscription group** — все 3 продукта в одной группе (иначе возможно двойное списание)

### Технические требования Apple

- [ ] **`finishTransaction` не вызывать вручную** — RevenueCat делает это автоматически (не смешивать с ручным `in_app_purchase`)
- [ ] **Не блокировать контент до получения ответа** — показывать loading state
- [ ] **Обрабатывать canceled purchases** — не показывать ошибку при отмене
- [ ] **Отсутствие `in_app_purchase`** — если старая зависимость осталась в `pubspec.yaml`, убрать

### Метаданные приложения (App Store Connect)

- [ ] **Subscription description** — заполнена для каждого продукта (EN + RU)
- [ ] **Privacy policy URL** — указан в App Store Connect
- [ ] **Promotional text** — не обязателен, но рекомендован

### Тестирование перед сабмитом

- [ ] Полный purchase flow проходит в Sandbox без ошибок (все 3 плана)
- [ ] Restore purchase работает в Sandbox
- [ ] Приложение не крашится при отсутствии сети (RevenueCat кэш)
- [ ] Приложение не крашится если RevenueCat SDK не инициализировался (try/catch в main)
- [ ] На скриншотах для Review видна кнопка Restore и условия trial

---

## Приложение: новые файлы

```
lib/core/subscription/
├── subscription_state.dart       # sealed SubscriptionState
├── subscription_provider.dart    # Riverpod SubscriptionNotifier
└── require_subscription.dart     # Gate utility

lib/features/paywall/
├── screens/
│   └── paywall_sheet.dart        # Full-screen modal
└── widgets/
    ├── paywall_feature_row.dart   # Feature row widget
    └── paywall_plan_card.dart     # Plan card widget
```

## Приложение: удаляемые файлы

```
lib/core/iap/  ← удалить целиком
  iap_service.dart
  iap_provider.dart
```
(если директория уже существует от предыдущих попыток)

## Приложение: изменяемые файлы

```
pubspec.yaml                                      + purchases_flutter ^8.0.0
lib/main.dart                                     + RC init, + refresh on resume
lib/router.dart                                   (без изменений — sheet не требует route)
lib/features/add_meal/screens/kf2_capture_screen.dart  + gate D-1
lib/features/add_meal/screens/add_meal_sheet.dart       + gate D-2
lib/features/chat/screens/chat_v2_screen.dart           + gate D-3
lib/core/i18n/app_ru.arb                          + paywall_* строки
lib/core/i18n/app_en.arb                          + paywall_* строки
```
