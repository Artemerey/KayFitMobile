# HLD: Paywall + In-App Purchase — KayFit

**Дата:** 2026-05-26  
**Статус:** Ожидает одобрения  
**Версия:** 1.0.4+1

---

## Контекст

Все AI-фичи (фото-распознавание, голосовой ввод, чат с нутрициологом) переходят в подписку.  
Бесплатно остаётся только ручной поиск продуктов в базе USDA.  
Платёж через внешний WebView запрещён (App Store Guideline 3.1.1) — реализуем через IAP.

---

## 1. Архитектурное решение: `in_app_purchase` vs RevenueCat

| | `in_app_purchase` | RevenueCat |
|---|---|---|
| Зависимость | Официальный Flutter plugin | Сторонний SDK |
| StoreKit 2 | ✅ автоматически на iOS 15+ | ✅ |
| Серверная валидация | Самостоятельно (наш бэкенд) | Их сервер (платно при росте) |
| Контроль | Полный | Ограничен |
| Сложность | Средняя | Низкая |

**Решение: `in_app_purchase: ^3.2.0`**  
Причина: наш бэкенд уже существует, есть `/api/payments/tariffs`. Не хотим зависеть от стороннего сервиса и платить RevenueCat при росте MAU. StoreKit 2 доступен — iOS target 16.0.

---

## 2. Продукты в App Store Connect (нужно создать вручную)

Тип: **Auto-Renewable Subscriptions** → группа `KayFit Premium`

| Product ID | Период | Intro offer (free trial) |
|---|---|---|
| `com.kayfit.app.sub.monthly` | 1 месяц | 7 дней бесплатно |
| `com.kayfit.app.sub.quarterly` | 3 месяца | 7 дней бесплатно |
| `com.kayfit.app.sub.yearly` | 1 год | 7 дней бесплатно |

> Trial = intro offer на каждом продукте, настраивается в App Store Connect.  
> Старый `trial` тариф из бэкенда больше не используется как отдельный продукт.  
> Пользователь может использовать trial один раз на Apple ID (Apple enforces это автоматически).

---

## 3. Файловая структура (новые файлы)

```
lib/
├── core/
│   └── iap/
│       ├── iap_service.dart          # Singleton: load products, purchase, restore
│       ├── iap_provider.dart         # Riverpod: subscriptionStateProvider
│       └── subscription_state.dart   # sealed class: Active | Expired | Unknown
│
├── features/
│   └── paywall/
│       ├── screens/
│       │   └── paywall_sheet.dart    # Modal bottom sheet (основной экран)
│       └── widgets/
│           ├── paywall_feature_row.dart   # Одна строка фичи
│           └── paywall_plan_card.dart     # Карточка тарифного плана
│
pubspec.yaml                          # + in_app_purchase: ^3.2.0
```

Изменяемые файлы:
```
lib/router.dart                       # + /paywall route (fullscreenDialog)
lib/features/add_meal/screens/
    add_meal_sheet.dart               # gate: фото/голос → проверить подписку
    kf2_capture_screen.dart           # gate: вход в фото-поток
lib/features/chat/screens/
    chat_v2_screen.dart               # gate: отправка сообщения
lib/core/i18n/app_ru.arb             # + новые строки
lib/core/i18n/app_en.arb             # + новые строки
```

---

## 4. State management

```dart
// subscription_state.dart
sealed class SubscriptionState {
  const SubscriptionState();
}
final class SubscriptionActive extends SubscriptionState {
  const SubscriptionActive({required this.productId, required this.expiresAt});
  final String productId;
  final DateTime expiresAt;
}
final class SubscriptionExpired extends SubscriptionState {
  const SubscriptionExpired();
}
final class SubscriptionUnknown extends SubscriptionState {
  // Начальное состояние — пока не проверили
  const SubscriptionUnknown();
}
```

```dart
// iap_provider.dart (Riverpod)
@Riverpod(keepAlive: true)
class SubscriptionNotifier extends _$SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionUnknown();

  Future<void> refresh() async { /* проверить текущие entitlements */ }
  Future<bool> purchase(ProductDetails product) async { /* ... */ }
  Future<void> restore() async { /* restorePurchases */ }
}
```

**Правило entitlement:**
1. При старте — `IapService.checkCurrentEntitlements()` (StoreKit 2: `Transaction.currentEntitlements`)
2. При покупке — слушаем `InAppPurchase.instance.purchaseStream`
3. Серверная валидация — POST `/api/payments/verify-iap` с JWS-транзакцией (бэкенд проверяет через Apple App Store Server API)

---

## 5. Логика показа пейвола

```dart
// Утилита — вызывать перед каждой AI-фичей
Future<bool> requireSubscription(BuildContext context, WidgetRef ref) async {
  final state = ref.read(subscriptionNotifierProvider);
  if (state is SubscriptionActive) return true;

  // Проверить cooldown — не показывать чаще раза в 24ч
  final prefs = await SharedPreferences.getInstance();
  final lastShown = prefs.getInt('paywall_last_shown') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - lastShown < const Duration(hours: 24).inMilliseconds) {
    return false; // молча блокируем, не спамим
  }
  await prefs.setInt('paywall_last_shown', now);

  if (!context.mounted) return false;
  final result = await showPaywall(context);
  return result == PaywallResult.subscribed;
}
```

**Точки вызова:**
- `Kf2CaptureScreen` — перед открытием камеры
- `AddMealSheet` — при нажатии на кнопку «Голос»
- `ChatV2Screen` — при отправке первого сообщения в сессии

---

## 6. UI: Wireframe

```
┌──────────────────────────────────────────────────┐
│                  ▬▬▬  (drag handle)              │
│                                                  │
│    ╔══════════════════════════════════════════╗  │
│    ║  [лого / иллюстрация с едой ~180px]      ║  │
│    ╚══════════════════════════════════════════╝  │
│                                                  │
│         ИИ считает калории.              32px B  │
│         Ты просто ешь.                   32px B  │
│                                                  │
│  Сфотографируй тарелку, скажи голосом    14px   │
│  или спроси нутрициолога — KayFit        14px   │
│  запишет всё сам.                        14px   │
│                                                  │
│  ─────────────────────────────────────────────  │
│                                                  │
│  📸  Фото → КБЖУ за секунды                     │
│      ИИ определяет ингредиенты и вес порции      │
│                                                  │
│  🎙️  Скажи вслух                                │
│      «Съел куриный плов» → залогировано сразу    │
│                                                  │
│  💬  Нутрициолог в кармане                       │
│      Спроси о питании — ответит и запишет        │
│                                                  │
│  ─────────────────────────────────────────────  │
│                                                  │
│  ┌───────────┐  ┌───────────┐  ┌─────────────┐ │
│  │  СТАРТ    │  │  Месяц    │  │   3 месяца  │ │
│  │ 7 дней 🆓 │  │ ХХХ ₽/мес │  │  ★ ЛУЧШИЙ  │ │
│  │ затем...  │  │           │  │  ХХХ ₽/мес  │ │
│  └───────────┘  └───────────┘  └─────────────┘ │
│              ┌─────────────┐                    │
│              │    Год      │                    │
│              │  🔥 −40%    │                    │
│              │  ХХХ ₽/мес  │                    │
│              └─────────────┘                    │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │       Начать 7 дней бесплатно            │   │  ← #FF597D
│  └──────────────────────────────────────────┘   │
│                                                  │
│   Отменить до конца 7 дней — ничего не спишется  │  ← 12px grey
│                                                  │
│           Нет, буду вводить руками               │  ← link
│                                                  │
│   Восстановить · Условия · Политика              │  ← 11px grey
└──────────────────────────────────────────────────┘
```

**Визуальные параметры:**
- Фон: `#FFF1EA` (тот же, что у tariffs_screen)
- Акцент: `#FF597D`
- Карточки планов: белые, selected = `rgba(255,89,125,0.16)` + border `#FF597D`
- Hero-иллюстрация: кастомная SVG или PNG (нужен ассет)
- Drag handle: серый, 4×32px, rounded
- Кнопка CTA: rounded 14px, высота 56px, жирный шрифт
- Dismiss: `TextButton`, цвет `#AAB2BD`, размер 14px

**План по умолчанию:** `quarterly` (≈ "Популярный") — выделен визуально.

---

## 7. Изменения бэкенда

### Новый endpoint: `POST /api/payments/verify-iap`

```json
Request:
{
  "transaction_jws": "<JWS из StoreKit 2>",
  "product_id": "com.kayfit.app.sub.yearly"
}

Response 200:
{
  "active": true,
  "expires_at": "2027-05-26T00:00:00Z",
  "product_id": "com.kayfit.app.sub.yearly"
}
```

Бэкенд верифицирует JWS через Apple App Store Server API (публичный ключ Apple).  
Обновляет запись `subscriptions` пользователя в БД.

### Изменения в `/api/payments/tariffs`
Убрать `trial` как отдельный тариф (7-дневный trial теперь intro offer на продуктах Apple).  
Оставить `monthly`, `quarterly`, `yearly` — нужны для цен, которые подтягиваем из StoreKit (не бэкенд).

> ⚠️ Цены отображаем из StoreKit, НЕ из бэкенда — Apple требует показывать цены из App Store, не хардкодить.

---

## 8. Порядок реализации

- [ ] **Шаг 1 (App Store Connect):** создать 3 subscription products + 7-day trial intro offer
- [ ] **Шаг 2 (pubspec):** добавить `in_app_purchase: ^3.2.0`
- [ ] **Шаг 3 (core/iap):** `IapService`, `SubscriptionState`, `subscriptionNotifierProvider`
- [ ] **Шаг 4 (UI):** `PaywallSheet` — полный экран с wireframe выше
- [ ] **Шаг 5 (gates):** `requireSubscription()` в capture, voice, chat
- [ ] **Шаг 6 (i18n):** новые строки в `app_ru.arb` / `app_en.arb`
- [ ] **Шаг 7 (бэкенд):** `POST /api/payments/verify-iap`
- [ ] **Шаг 8 (тест):** StoreKit Testing в Xcode Simulator (без реальной карты)

---

## 9. Scope НЕ входит в эту задачу

- Android (Google Play Billing) — отдельная задача
- Push-напоминание об истекающей подписке
- Страница управления подпиской внутри приложения
- A/B тест заголовков пейвола

---

## Риски

| Риск | Митигация |
|---|---|
| Apple Review отклонит — нет реального IAP | Тестируем через StoreKit Sandbox до сабмита |
| Цена отличается от App Store tier | Цены только через `ProductDetails.price` от StoreKit, не хардкодим |
| Двойное списание при ошибке сети | `finishTransaction` только после подтверждения сервера |
| iOS < 15 (маловероятно, target 16.0) | `in_app_purchase` деградирует на Original API автоматически |
