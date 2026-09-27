# Prompt: KayFit 1.3.2 — anonymous onboarding feedback must reach Telegram before registration

## Роль и цель

Ты senior Flutter + FastAPI engineer. Исправь архитектурный дефект KayFit: отзыв о рассчитанном onboarding-плане сейчас остаётся только в локальной очереди `pending_auth` и не попадает в backend/Telegram, пока пользователь не зарегистрируется. Если продукт не понравился и человек ушёл, владелец никогда не узнает об этом отзыве.

Работай с двумя репозиториями:

- mobile: `/Users/user/Desktop/КУРСОР/mobileKayfit`
- backend: `/Users/user/Desktop/КУРСОР/CaloriesApp_backend`

Не ограничивайся UI-текстом. Измени API-контракт, persistence, mobile queue, механизм позднейшей привязки к account и production deployment.

## Зафиксированное воспроизведение

1. Новый анонимный пользователь завершает onboarding и видит план.
2. Ставит like/dislike, при необходимости пишет comment.
3. UI показывает `Спасибо за обратную связь!`.
4. Mobile сохраняет событие с unresolved `pending_submission_id`, `ownerBinding == null` и не вызывает API.
5. В production записи `user_feedback`/`feedback_telegram_outbox` не появляются; Telegram не приходит.
6. Если человек не регистрируется, feedback навсегда остаётся только на его устройстве.

Перед реализацией подтверди это автотестом и безопасным production-запросом без PII/секретов.

## Целевой UX

1. Анонимный onboarding создаёт на backend несекретный feedback-capability, привязанный к конкретному onboarding submission/plan.
2. Like/dislike сразу отправляется без auth token.
3. API атомарно создаёт feedback + Telegram outbox.
4. `Спасибо` показывается только после надёжной локальной постановки в retry-queue; UI ясно различает `сохранено для отправки` и terminal failure.
5. При сети feedback доходит до Telegram до нажатия CTA регистрации.
6. Если сети нет, mobile повторяет anonymous submit при возврате connectivity/app resume/cold start. Регистрация для retry не требуется.
7. Если позже появляется account, тот же feedback привязывается к user без создания дубля и без второго Telegram-сообщения.

## Backend-контракт

Исследуй текущие onboarding submission API/models/migrations и feedback API/service/outbox. Не изобретай вторую систему feedback.

Реализуй один из безопасных контрактов, предпочтительно:

- onboarding calculation/submission response возвращает:
  - `feedback_target_id` — server UUID плана;
  - `feedback_capability` — случайный opaque token с высокой энтропией, хранящийся на сервере только как hash;
  - TTL/expiry, если нужно.
- anonymous endpoint, например `POST /api/feedback/anonymous`, принимает:
  - `event_id` / idempotency key;
  - `feedback_target_id`;
  - `feedback_capability`;
  - `rating`, `source=onboarding`, `reason_codes`, `comment`, safe context/platform/app_version/locale.

Обязательно:

- не доверять одному client-generated UUID как авторизации;
- capability должен разрешать feedback только для одного target и не давать доступ к onboarding-данным;
- не включать capability в Telegram, logs, analytics и error body;
- rate limit по IP + target/capability; ограничить body/comment;
- тот же `event_id` должен возвращать идемпотентный success и не создавать новый feedback/outbox;
- feedback + outbox создаются в одной DB-транзакции;
- worker отправляет каждый like/dislike, как и в auth flow;
- Telegram message содержит rating, `onboarding_plan`, `onboarding`, reasons, comment, UTC timestamp и короткий feedback/event ID, но не PII/capability;
- позднейшая auth/submission sync атомарно дозаполняет `user_id` для уже существующего anonymous feedback, не дублируя event/outbox.

## Mobile

Измени `lib/core/feedback/*`, onboarding pending storage/sync и result host:

1. Храни в pending onboarding payload server `feedback_target_id` и capability. Capability храни как sensitive data; не логируй.
2. `FeedbackTargetRef` должен уметь сразу отправлять anonymous onboarding feedback без `ownerBinding`.
3. Выдели в repository auth и anonymous transport; не ослабляй auth-контракт для `meal_save`.
4. `meal_save` по-прежнему требует auth; anonymous capability разрешен только для `onboarding_plan`.
5. Queue повторяет network/5xx/429 с backoff, останавливается на permanent invalid/expired capability и не зацикливается.
6. Flush anonymous queue запускается сразу после enqueue, при app start/resume и connectivity recovery.
7. Не теряй feedback при anonymous → auth navigation, back, cold restart и failed registration.
8. После registration привяжи уже отправленный feedback к account на backend; не создавай его повторно.
9. Аналитика должна различать `anonymous_queued`, `anonymous_sent`, `anonymous_retryable`, `anonymous_permanent`, но не содержать capability/comment.

## Тесты

Работай по TDD: сначала RED-тесты на текущий дефект, затем реализация.

Backend minimum:

- anonymous like без comment → `201`, feedback + outbox;
- anonymous dislike + reason + comment → `201`, Telegram formatter содержит correction;
- запрос без/с неверной capability → safe `401/403`, без записей;
- capability не подходит к другому target;
- anonymous endpoint отклоняет `meal_save`;
- повтор с тем же event ID не создаёт дубль;
- rate limit/body limits;
- registration/link заполняет user_id без второго outbox;
- migration up/down/idempotent на disposable PostgreSQL;
- pending/failed/sent diagnostics видят anonymous events.

Mobile minimum:

- anonymous onboarding like вызывает anonymous repository до auth navigation;
- dislike передаёт reasons/comment;
- offline enqueue → app restart/connectivity recovery → sent без login;
- same event ID сохраняется между retry;
- invalid capability даёт recoverable/terminal UX, а не ложное `Спасибо, отправлено`;
- feedback survives back/cold restart/failed registration;
- successful registration links existing feedback and does not resubmit;
- fresh anonymous, stale Keychain token and clean reinstall scenarios.

## Production E2E

Используй существующий KayFit Timeweb SSH на port `2222` согласно workspace instructions. Не печатай секреты, capability, токены, PII и secret-bearing URLs.

После backup/migration/deploy выполни на реальном iPhone:

1. Чистая установка, не входить/не регистрироваться.
2. Завершить onboarding, поставить like без comment.
3. До перехода в auth подтвердить: API accepted, DB feedback, outbox, Telegram `sent`, фактическое получение.
4. На новом anonymous submission поставить dislike + reason + comment; подтвердить второе Telegram-сообщение.
5. Повторить request с тем же event ID; подтвердить отсутствие дубля в DB и Telegram.
6. Только после этого зарегистрироваться; подтвердить link к user без нового Telegram-собщения.
7. Offline test: оставить anonymous feedback без сети, закрыть/открыть app, вернуть сеть и подтвердить доставку без auth.

## Definition of Done

- Владелец получает каждую onboarding-оценку, даже если человек никогда не зарегистрировался.
- Anonymous feedback не даёт доступ к onboarding data/account и защищён от простого spam/replay.
- Feedback + outbox атомарны, retry переживает restart, idempotency не даёт дублей.
- Поздняя регистрация привязывает тот же feedback, а не повторяет его.
- Добавлены backend/mobile contract, unit, widget, integration и migration tests.
- Production E2E фактически подтверждает anonymous like и dislike в Telegram до auth.
- Финальный отчёт содержит первопричину, контракт, threat model, migrations, test results, E2E evidence и remaining risks.

Не объявляй задачу завершённой, пока anonymous like и dislike не приняты production API и не получены в Telegram до регистрации.
