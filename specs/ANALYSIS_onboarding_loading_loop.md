# Анализ: «вечная загрузка» после экрана расчёта цели

Дата: 2026-06-11. Статус: **корневая причина найдена и доказана кодом. Рабочее
дерево откатано в чистый master; фикс НЕ применён — это 1 строка, см. ниже.**

## TL;DR

Вечный спиннер — это **не** экран review-prompt и **не** auth-провайдер. Это
**пре-существующий баг в master**: последний шаг онбординга `_Step.auth` попадает
в бесконечную петлю редиректа, потому что `_navigateToLogin()` зовёт
`context.go('/login')` без предварительного `logout()`, а Keychain-токен
переживает переустановку.

**Важно:** review-prompt-фича его не вызывала. Даже если переписать экран
review-prompt идеально, петля останется, пока не починить `_navigateToLogin`.

## Корневая причина (доказательство, master)

1. `_Step.result` (расчёт плана) → «Перейти на вход» → `_goNext()` → `_Step.auth`.
2. `_Step.auth` ([onboarding_screen.dart:893-896](../lib/features/onboarding/screens/onboarding_screen.dart#L893-L896))
   рисует `CircularProgressIndicator` и в post-frame зовёт `_navigateToLogin()`.
3. `_navigateToLogin()` ([:426-446](../lib/features/onboarding/screens/onboarding_screen.dart#L426-L446))
   делает `context.go('/login')` **без logout**.
4. iOS **не стирает Keychain при переустановке** (а SharedPreferences стирает).
   После реинсталла дев-сборки: `isLoggedIn=true`, `onboarding_done=false`.
5. Роутер: `isLoggedIn && loc=='/login'` → `/journal-v2`; затем reinstall-guard
   `!onboardingDone && loc!='/onboarding'` → `/onboarding`. Онбординг снова
   монтирует `_Step.auth` → спиннер → снова `_navigateToLogin()` → **петля**.

**Соседний код уже чинит этот же баг:** колбэк `onLogin` («У меня уже есть
аккаунт», [:726-733](../lib/features/onboarding/screens/onboarding_screen.dart#L726-L733))
делает `await logout()` ПЕРЕД `context.go('/login')` и в комментарии описывает
ровно этот bounce. В `_navigateToLogin` этой строки нет — единственная асимметрия.

## Фикс (1 строка)

В `_navigateToLogin()`, перед `context.go('/login')`:
```dart
if (mounted) {
  await ref.read(authNotifierProvider.notifier).logout();
}
if (mounted) context.go('/login');
```
Зеркало лендинг-колбэка. Фреш-юзера (без токена) не ломает; реинсталл-юзера
выводит на /login чисто, без петли.

## Почему 4 предыдущие попытки не сработали

Чинили `auth_provider.checkSession` / splash / router-`isLoading` — всё вне пути
этой петли. Петля — чистый redirect-bounce на `isLoggedIn && !onboardingDone`.
Урок: **сначала найти конкретный виджет со спиннером и проследить реальную
навигацию, потом чинить.** (Спиннер = `CircularProgressIndicator` на `_Step.auth`,
не data-провайдер: все провайдеры ограничены 30-сек таймаутом apiDio и имеют
error-ветку.)

## Архитектурный вывод (для рерайта пост-онбординг-флоу)

Самое хрупкое место — пост-онбординг навигация. Смелы:

1. **Императивные `context.go()` внутрь «жирного» redirect из 6+ гейтов** (auth,
   onboarding, way-to-goal, ai-consent, review-prompt, reinstall-guard). Порядок
   гейтов зависит от глобальных `StateProvider`; гонки лечатся точечными
   `context.go`, которые порождают новые гонки.
2. **«Показать экран X once» в глобальных `StateProvider`** (`showWayToGoal*`,
   `showReviewPrompt*`, `consentFromOnboarding`) + чтение из редиректа.
   `showWayToGoalProvider` — мёртвый гейт (нигде не ставится `true`).
3. **`_Step.auth` как экран-редирект со спиннером** — анти-паттерн: рендерит
   индикатор и надеется на навигацию; если навигация отбита → вечный спиннер.

### Рекомендации к чистому рерайту

- `_navigateToLogin` → **сначала нормализовать auth** (logout если токен есть, а
  онбординг не завершён), потом вести на регистрацию. Идемпотентно.
- review-prompt: показывать **явной императивной навигацией** после успешной
  регистрации (`context.push('/review-prompt')` один раз), а НЕ через глобальный
  `StateProvider` + redirect-гейт. Так не будет гонки с ai-consent gate.
- Выкинуть мёртвый `showWayToGoalProvider` гейт.
- Любой экран загрузки — с таймаутом/recovery, не вечный спиннер.

## Состояние репозитория

Рабочее дерево откатано в чистый master (review-prompt-фича и спекулятивные
правки убраны). Единственный незакоммиченный файл — этот документ.
Установленная на телефон сборка **устарела** относительно master (в ней были мои
откатанные правки) — для чистого теста нужна пересборка с master + 1-строчным
фиксом.
