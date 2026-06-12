# KayFit 1.2.2+6 — Changelog

**Дата:** 2026-06-12

## Исправления

- **Спонтанный разлогин (критический баг)** — устранена гонка токенов, которая вызывала случайный выход из аккаунта при каждом возобновлении приложения.

  **Причина:** `checkSession()` создавал собственный `Dio` и вызывал `/api/v1/auth/refresh` напрямую — параллельно с `_AuthInterceptor`, который делал то же самое для активных API-запросов. Оба использовали одинаковый refresh token одновременно. Бэкенд интерпретировал повторное использование токена как кражу сессии и отзывал **все** активные сессии пользователя, что приводило к принудительному logout.

  **Исправление:** `checkSession()` теперь маршрутизирует запрос `/me` через `apiDio`, где `_AuthInterceptor` сериализует обновление токенов через `_refreshCompleter`. Гонка полностью исключена — refresh происходит ровно один раз, независимо от количества параллельных запросов.

- **Вечная загрузка после экрана плана в онбординге** — устранена бесконечная петля редиректа. Шаг `_Step.auth` уходил на `/login` без `logout()`, а переживший переустановку Keychain-токен заставлял роутер крутить `/login → /journal-v2 → /onboarding`. Теперь перед переходом на вход выполняется `logout()` — цепочка редиректов чисто завершается на `/login`.

- **Экран «месяц бесплатно» не показывался при входе через Apple** — переход на review-prompt был подключён только в экране входа по email. `LoginScreen._afterLogin` (Apple) теперь тоже вызывает `markOnboardingDone` и ведёт на `/review-prompt`, а также корректно проставляет `onboarding_done` (раньше Apple-путь этого не делал — потенциальный возврат петли).

## Новое

- **Экран «Месяц Premium в подарок»** (post-onboarding review-prompt): бейдж 🎁 GIFT, часовой таймер обратного отсчёта, перечень функций Premium (из тарифов), оценка 1–5★. На 4–5★ открывается форма отзыва в App Store, на 1–3★ — благодарность. Показывается один раз.

- **Брендовый splash-экран** на старте — убирает мелькание legacy-экрана `/` пока резолвится состояние авторизации.

## Технические изменения

- `lib/core/auth/auth_provider.dart`: `checkSession()` переработан — удалён дублирующий блок refresh, `_fetchMe()` заменён на `_fetchMeViaInterceptor()` (использует `apiDio`).
- `lib/features/onboarding/screens/onboarding_screen.dart`: `_navigateToLogin()` делает `logout()` перед `context.go('/login')`.
- `lib/features/auth/screens/login_screen.dart`: `_afterLogin()` зеркалит email-путь (`markOnboardingDone` + `refreshUser` + переход на `/review-prompt`).
- `lib/features/review_prompt/screens/review_prompt_screen.dart`: новый экран; переиспользует `PaywallFeatureRow` из тарифов.
- `lib/features/splash/screens/splash_screen.dart` + `lib/router.dart`: `/splash` как `initialLocation` и парковка при `authNotifier.isLoading`.
- `lib/core/config/app_config.dart`: `appStoreId` + `appStoreReviewUrl`.
- `lib/core/paywall/paywall_flags.dart`: `kBypassPaywall` (compile-time, дефолт `false` — на прод не влияет).
