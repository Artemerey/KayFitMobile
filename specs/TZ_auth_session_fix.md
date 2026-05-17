# ТЗ: Исправление бага «iOS разлогинивает пользователя после закрытия приложения»

**Версия:** 1.0  
**Дата:** 2026-05-17  
**Исполнитель:** flutter frontend-dev  
**Проект:** mobileKayfit (Flutter, Riverpod, go_router, flutter_secure_storage 9.2.4)

---

## 1. Обзор задачи

### Симптом

После закрытия приложения (свайп из switcher) и повторного открытия пользователь видит экран логина. Keychain токены физически присутствуют, сессия на сервере активна.

### Корневые причины (6 независимых гипотез)

Все шесть исправлений применяются за один PR. Они не конфликтуют, но имеют зависимости порядка — см. Раздел 5.

### Затронутые файлы

| Файл | Роль |
|------|------|
| `lib/core/auth/auth_provider.dart` | H1, H3, H6 |
| `lib/core/auth/secure_token_storage.dart` | H5 |
| `lib/core/api/api_client.dart` | H4 |
| `lib/router.dart` | H4 |
| `lib/main.dart` | H2 |

### Допущения

- Проект использует `riverpod_annotation` + `build_runner` для кодогенерации.
- Сгенерированный файл `auth_provider.g.dart` коммитится в репозиторий — после изменения аннотации его нужно перегенерировать и закоммитить.
- Тесты пишутся в `test/core/auth/` и `test/core/api/` согласно существующей структуре.
- Используется паттерн `FakeSecureTokenStorage` из `test/core/api/auth_interceptor_test.dart` — расширять его, не дублировать.
- `WidgetsBindingObserver` подключается к существующему `_AppInitState` в `lib/main.dart` (не создавать новый StatefulWidget).

---

## 2. Исправления по гипотезам

---

### H1 — AutoDispose провайдер уничтожает сессию при навигации

**Файл:** `lib/core/auth/auth_provider.dart`, строка 27  
**Файл генерации:** `lib/core/auth/auth_provider.g.dart`

#### Что происходит сейчас

```dart
// строка 27
@riverpod
class AuthNotifier extends _$AuthNotifier {
```

Аннотация `@riverpod` генерирует `AutoDisposeNotifierProvider`. Riverpod уничтожает провайдер, когда ни один виджет не держит на него подписку. При навигации между экранами возникает кратковременный момент без слушателей — провайдер пересоздаётся с `AsyncValue.loading()`. Роутер видит `isLoading == true` → возвращает `null` (пропускает redirect). Затем провайдер выдаёт `AsyncValue.data(null)` (пустой build без кеша) → роутер редиректит на `/login`.

Из `auth_provider.g.dart` подтверждено: генерируется `AutoDisposeNotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>`.

#### Что сделать

Заменить аннотацию в строке 27:

```dart
// БЫЛО
@riverpod
class AuthNotifier extends _$AuthNotifier {

// СТАЛО
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
```

После замены обязательно перегенерировать код:

```
dart run build_runner build --delete-conflicting-outputs
```

Проверить, что в сгенерированном `auth_provider.g.dart` тип провайдера изменился с `AutoDisposeNotifierProvider` на `NotifierProvider`.

#### Ожидаемый результат после фикса

Провайдер живёт всё время жизни `ProviderScope`. При переходах между экранами состояние `AsyncValue.data(user)` сохраняется. Роутер больше не получает `data(null)` из-за пересоздания.

---

### H2 — Нет восстановления сессии при возврате из background

**Файл:** `lib/main.dart`, класс `_AppInitState` (строки 64-80)

#### Что происходит сейчас

`_AppInitState` не реализует `WidgetsBindingObserver`. При возврате приложения из background (через switcher, push-уведомление, universal link) `checkSession` не вызывается. Если access token истёк за время нахождения в фоне — следующий API-запрос получит 401 и инициирует logout через `_AuthInterceptor`.

#### Что сделать

`_AppInitState` должен реализовывать `WidgetsBindingObserver`. В `initState` регистрировать observer, в `dispose` удалять. В `didChangeAppLifecycleState` при переходе в `AppLifecycleState.resumed` вызывать `checkSession` с `backgroundRefresh: true`.

```dart
class _AppInitState extends ConsumerState<_AppInit>
    with WidgetsBindingObserver {          // <-- добавить mixin

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);   // <-- регистрация
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(authNotifierProvider.notifier);
      if (widget.cachedUser != null) {
        notifier.restoreFromCache(widget.cachedUser!);
      }
      notifier.checkSession(backgroundRefresh: widget.cachedUser != null);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);  // <-- очистка
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // backgroundRefresh: true — не сбрасывает UI в loading-состояние
      ref.read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) => const KayfitApp();
}
```

#### Ограничения

- `backgroundRefresh: true` передаётся намеренно: при resumed пользователь видит контент, нельзя показывать спиннер.
- Если приложение перешло в `paused` и сразу вернулось (< 5 секунд) — `checkSession` всё равно вызовется. Это допустимо: метод идемпотентен при живом токене.
- Вызов `ref.read` в `didChangeAppLifecycleState` безопасен: к моменту resumed виджет гарантированно смонтирован.

---

### H3 — catch-блок в checkSession не различает типы ошибок

**Файл:** `lib/core/auth/auth_provider.dart`, строки 97-100

#### Что происходит сейчас

```dart
// строки 97-100
} catch (e) {
  debugPrint('[auth] checkSession error: $e');
  if (!backgroundRefresh) state = const AsyncValue.data(null);
}
```

Любое исключение — сетевой таймаут, parse error, PlatformException из Keychain — трактуется одинаково и при `backgroundRefresh: false` выставляет `state = data(null)`. Роутер отправляет пользователя на `/login`, хотя токены в Keychain могут быть полностью валидны.

#### Что сделать

Разделить обработку исключений по типу. Логика:

1. `DioException` с типами timeout/connection — сеть недоступна, токены не скомпрометированы → не сбрасывать state, залогировать.
2. `KeychainUnavailableException` (вводится в H5) — Keychain временно недоступен → не сбрасывать state, залогировать.
3. Все остальные исключения → логировать, не разлогинивать (fail-safe: лучше остаться залогиненным с неработающей фичей, чем принудительно выбросить пользователя).

```dart
// БЫЛО (строки 97-100)
} catch (e) {
  debugPrint('[auth] checkSession error: $e');
  if (!backgroundRefresh) state = const AsyncValue.data(null);
}

// СТАЛО
} on DioException catch (e) {
  debugPrint('[auth] checkSession DioException: $e');
  final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError;
  if (!isNetworkError && !backgroundRefresh) {
    // Серверная ошибка (5xx, неожиданный JSON) — не разлогиниваем,
    // но и не оставляем в loading. Пусть следующий цикл разберётся.
    debugPrint('[auth] server-side error during checkSession, not logging out');
  }
  // При любом DioException не выставляем data(null).
} on KeychainUnavailableException catch (e) {
  debugPrint('[auth] Keychain unavailable: $e — not logging out');
  // Keychain заблокирован фоновым запуском — см. H5.
} catch (e) {
  debugPrint('[auth] unexpected checkSession error: $e');
  // Неизвестная ошибка — fail-safe, не разлогиниваем.
}
```

**Важно:** строка `if (!backgroundRefresh) state = const AsyncValue.data(null)` в catch-блоке удаляется полностью. Единственный путь к `state = data(null)` — явная проверка `pair == null` (строки 51-55) и завершение рефреш-цикла (строки 93-96).

Строки 93-96 (после неудачного refresh) оставляем как есть: там уже явно проверяется, что токены мертвы:

```dart
// строки 93-96 — оставить без изменений
await storage.clearTokens();
await _clearCache();
if (!backgroundRefresh) state = const AsyncValue.data(null);
```

---

### H4 — Глобальный _onLogout с race condition при пересоздании провайдера

**Файл:** `lib/core/api/api_client.dart`, строки 24-27 и 213-216  
**Файл:** `lib/router.dart`, строки 61-68  
**Файл:** `lib/core/auth/auth_provider.dart`, строки 31-33

#### Что происходит сейчас

```dart
// api_client.dart строки 24-27
typedef LogoutCallback = Future<void> Function();
LogoutCallback? _onLogout;
void setLogoutCallback(LogoutCallback cb) => _onLogout = cb;

// auth_provider.dart строки 31-33 — вызывается в build()
setLogoutCallback(() async {
  state = const AsyncValue.data(null);
});
```

`_onLogout` — глобальная переменная в `api_client.dart`. При AutoDispose (до фикса H1) AuthNotifier пересоздаётся → `build()` регистрирует новый callback. Но `_AuthInterceptor` держит ссылку на старый closure через глобал. Если в этот момент происходит 401 → `_handleLogout` → вызывает closure со старым `state` → очищает токены у новой сессии.

После H1 AutoDispose убирается, но глобальный механизм остаётся архитектурно ненадёжным: `_onLogout` может быть `null` в момент 401 (до первого `build()`).

#### Что сделать

**Шаг 1. Убрать `setLogoutCallback` из `build()` AuthNotifier.**

```dart
// БЫЛО (строки 31-34)
@override
AsyncValue<UserProfile?> build() {
  setLogoutCallback(() async {
    state = const AsyncValue.data(null);
  });
  return const AsyncValue.loading();
}

// СТАЛО
@override
AsyncValue<UserProfile?> build() {
  return const AsyncValue.loading();
}
```

**Шаг 2. Убрать вызов `_onLogout` из `_handleLogout` в `api_client.dart`.**

`_handleLogout` (строки 213-216) должен только очищать токены. Он не должен знать об AuthNotifier:

```dart
// БЫЛО (строки 213-216)
Future<void> _handleLogout() async {
  await _storage.clearTokens();
  await _onLogout?.call();
}

// СТАЛО
Future<void> _handleLogout() async {
  await _storage.clearTokens();
  // AuthNotifier обнаружит отсутствие токенов при следующем checkSession,
  // либо _RouterNotifier среагирует на изменение authNotifierProvider.
}
```

**Шаг 3. В `_RouterNotifier` добавить реакцию на data(null) через `_ref.listen`.**

После того как `_AuthInterceptor` очищает токены, следующий API-запрос вернёт 401, а `checkSession` при backgroundRefresh поставит `state = data(null)` — либо роутер обнаружит это при переходе. Для явного редиректа без ожидания запроса добавить listen:

```dart
// router.dart, класс _RouterNotifier, метод конструктор (строки 62-68)

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen(authNotifierProvider, (previous, next) {
      // Если переход из залогиненного состояния в data(null) — немедленно
      // уведомить GoRouter о необходимости пересчитать redirect.
      notifyListeners();
    });
    _ref.listen(onboardingDoneProvider, (_, __) => notifyListeners());
    _ref.listen(showWayToGoalProvider, (_, __) => notifyListeners());
    _ref.listen(aiConsentProvider, (_, __) => notifyListeners());
  }
  // ...
}
```

Метод redirect уже содержит корректную логику `!isLoggedIn → /login`. Дополнительных изменений в redirect не требуется.

**Шаг 4. Удалить глобальные символы `setLogoutCallback` и `_onLogout` из `api_client.dart`**, если они нигде больше не используются. Проверить через `grep -r "setLogoutCallback\|_onLogout" lib/`.

**Шаг 5.** Убрать импорт `setLogoutCallback` из `auth_provider.dart` (строка 8: `import '../api/api_client.dart'` — оставить, он нужен для `apiDio`; убрать только вызов функции).

#### Ожидаемый результат

`_AuthInterceptor` отвечает только за очистку токенов. Перевод в незалогиненное состояние — ответственность `AuthNotifier.checkSession` (вызывается через H2 при resumed или через явный API-вызов). Нет глобального мутируемого callback.

---

### H5 — Keychain недоступен при background launch до первой разблокировки

**Файл:** `lib/core/auth/secure_token_storage.dart`, строки 80-103

#### Что происходит сейчас

```dart
// строки 100-103
} on PlatformException catch (e) {
  debugPrint('[SecureTokenStorage] loadTokens PlatformException: $e');
  return null;   // <-- трактуется как «токенов нет» → logout
}
```

iOS запускает приложение в background (например, по Background App Refresh или silent push) до того, как пользователь разблокирует устройство после перезагрузки. Keychain с `KeychainAccessibility.first_unlock` недоступен до первой разблокировки. `PlatformException` с кодом `-25308` (`errSecInteractionNotAllowed`) возвращается → метод возвращает `null` → `checkSession` считает, что токенов нет → `state = data(null)` → logout.

#### Что сделать

**Шаг 1. Создать новый класс исключения** в `lib/core/auth/secure_token_storage.dart`:

```dart
/// Выбрасывается когда iOS Keychain временно недоступен
/// (устройство не было разблокировано после перезагрузки).
/// Код OSStatus: -25308 (errSecInteractionNotAllowed).
class KeychainUnavailableException implements Exception {
  const KeychainUnavailableException(this.platformCode);
  final String platformCode;

  @override
  String toString() =>
      'KeychainUnavailableException(code: $platformCode)';
}
```

**Шаг 2. Изменить catch в `loadTokens`**, `loadAccessToken`, `loadRefreshToken`:

```dart
// БЫЛО — loadTokens, строки 100-103
} on PlatformException catch (e) {
  debugPrint('[SecureTokenStorage] loadTokens PlatformException: $e');
  return null;
}

// СТАЛО
} on PlatformException catch (e) {
  debugPrint('[SecureTokenStorage] loadTokens PlatformException: $e');
  // errSecInteractionNotAllowed (-25308): Keychain locked — устройство
  // не разблокировано после перезагрузки. Это НЕ означает отсутствие токенов.
  if (e.code == '-25308' || e.code == 'errSecInteractionNotAllowed') {
    throw KeychainUnavailableException(e.code);
  }
  // Иные PlatformException (повреждение хранилища и т.д.) — возвращаем null.
  return null;
}
```

Применить аналогичный паттерн в `loadAccessToken` (строки 141-148) и `loadRefreshToken` (строки 150-158): при `-25308` выбрасывать `KeychainUnavailableException`, а не возвращать `null`.

**Шаг 3.** В `checkSession` (`auth_provider.dart`) убедиться, что `KeychainUnavailableException` перехватывается в блоке `on KeychainUnavailableException` до общего `catch` — это уже предусмотрено в H3.

#### Ограничения

- Код `-25308` проверяется как `String`, потому что `PlatformException.code` имеет тип `String` в Dart.
- На Android этот сценарий не воспроизводится: `EncryptedSharedPreferences` доступны без разблокировки. `KeychainUnavailableException` специфичен для iOS, но `catch` на Dart уровне работает на обеих платформах корректно.
- `FakeFlutterSecureStorage.throwOnRead = true` в тестах бросает `PlatformException(code: 'keychain_error')` — код не совпадёт с `-25308`, поэтому тест вернёт `null` (покрывает старый путь). Для нового пути добавить `throwKeychainUnavailable = true` в fake — см. Раздел 3.

---

### H6 — backgroundRefresh=true не очищает кеш при мёртвом refresh-токене

**Файл:** `lib/core/auth/auth_provider.dart`, строки 71-96

#### Что происходит сейчас

```dart
// строки 89-96
} on DioException catch (e) {
  debugPrint('[auth] refresh failed: $e');
}

// Refresh failed or /me still returned null → clear and log out.
await storage.clearTokens();
await _clearCache();
if (!backgroundRefresh) state = const AsyncValue.data(null);
```

При `backgroundRefresh: true` и мёртвом refresh-токене:
1. `clearTokens()` вызывается — токены удалены из Keychain.
2. `_clearCache()` вызывается — `cached_user` удалён из SharedPreferences.
3. Но `state` не обновляется (`backgroundRefresh: true` → ветка не выполняется).

При следующем холодном старте `cachedUser == null` (кеш очищен) → `backgroundRefresh: false` → `checkSession` вызывает `loadTokens()` → токены тоже удалены → `pair == null` → корректный путь к `state = data(null)`.

Проблема: кеш очищен, токены очищены, но `state` остался `data(user)`. Если до следующего холодного старта пользователь успеет отправить API-запрос — `_AuthInterceptor` попытается добавить Bearer-заголовок (`loadAccessToken()` вернёт `null`) → запрос уйдёт без токена → 401 → `_handleLogout` → `clearTokens()` (уже пусто) → по H4 logout не вызывается → UI завис в состоянии "залогинен, но все запросы падают".

#### Что сделать

При `backgroundRefresh: true` и неудачном refresh: очистить кеш SharedPreferences, но дополнительно установить `state = const AsyncValue.data(null)`, чтобы роутер немедленно отправил на `/login`.

```dart
// БЫЛО (строки 93-96)
// Refresh failed or /me still returned null → clear and log out.
await storage.clearTokens();
await _clearCache();
if (!backgroundRefresh) state = const AsyncValue.data(null);

// СТАЛО
// Refresh failed or /me still returned null → clear and log out.
await storage.clearTokens();
await _clearCache();
// При backgroundRefresh тоже ставим data(null): токены мертвы, дальше
// ждать смысла нет. Роутер увидит изменение и перейдёт на /login.
state = const AsyncValue.data(null);
```

Строку `if (!backgroundRefresh)` убрать — выставлять `data(null)` безусловно.

Аналогичное изменение применить к строке 54 (ветка `pair == null`):

```dart
// БЫЛО (строки 51-55)
if (pair == null) {
  await _clearCache();
  if (!backgroundRefresh) state = const AsyncValue.data(null);
  return;
}

// СТАЛО
if (pair == null) {
  await _clearCache();
  state = const AsyncValue.data(null);  // безусловно
  return;
}
```

#### Обоснование

Раньше `if (!backgroundRefresh)` защищало от мигания UI при resumed. После H2 `backgroundRefresh: true` означает «токены точно есть, просто проверь». Если токенов нет (pair == null) или refresh мёртв — сессии нет в любом случае, мигание UI лучше, чем зависший UI. Роутер в этот момент не перерисовывает текущий контент — он делает навигационный переход, что для пользователя выглядит как обычный redirekt.

---

## 3. Требования к тестам

### H1 — keepAlive

**Файл:** `test/core/auth/auth_notifier_keepalive_test.dart` (новый файл)

| # | Тест | Проверяет |
|---|------|-----------|
| 1 | `authNotifierProvider имеет тип NotifierProvider (не AutoDispose)` | После перегенерации провайдер — `NotifierProvider`, а не `AutoDisposeNotifierProvider`. Проверить через `authNotifierProvider is NotifierProvider`. |
| 2 | `state сохраняется когда нет подписчиков` | Создать `ProviderContainer`, прочитать провайдер, установить state через `notifier.restoreFromCache(user)`, удалить всех слушателей — state остаётся `data(user)` при повторном чтении. |

Паттерн теста:
```dart
test('провайдер keepAlive — state не сбрасывается без слушателей', () {
  final container = ProviderContainer(overrides: [
    secureStorageProvider.overrideWithValue(FakeSecureTokenStorage()),
  ]);
  addTearDown(container.dispose);

  // Читаем провайдер и устанавливаем state
  container.read(authNotifierProvider.notifier).restoreFromCache(testUser);
  expect(container.read(authNotifierProvider).value, equals(testUser));

  // Принудительно инвалидируем подписчиков (AutoDispose бы убил провайдер)
  // keepAlive — state должен выжить
  container.invalidate(authNotifierProvider); // не трогает, т.к. keepAlive
  // Проверяем, что без пересоздания NotifierProvider — state data(testUser)
  expect(
    container.read(authNotifierProvider),
    isA<AsyncData<UserProfile?>>(),
  );
});
```

### H2 — AppLifecycleState.resumed

**Файл:** `test/widget/app_lifecycle_resume_test.dart` (новый файл)

| # | Тест | Проверяет |
|---|------|-----------|
| 1 | `checkSession вызывается при resumed` | Через `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed)` убедиться, что `FakeAuthNotifier.checkSessionCallCount` увеличился. |
| 2 | `checkSession НЕ вызывается при paused` | При `AppLifecycleState.paused` счётчик не растёт. |
| 3 | `backgroundRefresh=true передаётся при resumed` | `FakeAuthNotifier` фиксирует `lastBackgroundRefreshValue == true`. |

Паттерн теста:
```dart
testWidgets('resumed вызывает checkSession(backgroundRefresh: true)', (tester) async {
  final notifier = FakeAuthNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith(() => notifier)],
      child: const _AppInit(cachedUser: null),
    ),
  );
  await tester.pump();

  notifier.resetCounts();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();

  expect(notifier.checkSessionCallCount, equals(1));
  expect(notifier.lastBackgroundRefresh, isTrue);
});
```

### H3 — Классификация ошибок в catch

**Файл:** `test/core/auth/check_session_errors_test.dart` (новый файл)

| # | Тест | Проверяет |
|---|------|-----------|
| 1 | `connectionTimeout не сбрасывает state` | FakeStorage бросает `DioException(type: connectionTimeout)` при `loadTokens` → state остаётся `loading()` или предыдущим `data(user)`. |
| 2 | `receiveTimeout не сбрасывает state` | Аналогично с `receiveTimeout`. |
| 3 | `KeychainUnavailableException не сбрасывает state` | FakeStorage бросает `KeychainUnavailableException` → state не становится `data(null)`. |
| 4 | `pair == null корректно ставит data(null)` | FakeStorage возвращает `null` → state = `data(null)`. |
| 5 | `backgroundRefresh=false + DioException не ставит data(null)` | Даже без backgroundRefresh при DioException state не сбрасывается. |

### H4 — Удаление глобального _onLogout

**Файл:** `test/core/api/auth_interceptor_test.dart` (расширить существующий)

| # | Тест | Проверяет |
|---|------|-----------|
| 1 | `_handleLogout очищает только токены, не вызывает внешний callback` | После 401 + failed refresh: `clearCount > 0`, но отдельный `logoutCallbackCalled` — `false` (если callback убран). |
| 2 | `Пересоздание AuthNotifier не регистрирует новый _onLogout` | Создать `ProviderContainer`, считать провайдер дважды — убедиться, что `_onLogout` (если переменная осталась для обратной совместимости) не изменилась или что её нет. |

Существующий тест `clears tokens and calls logout when refresh returns 401` нужно адаптировать: убрать проверку `logoutCalled == true`, оставить только `clearCount > 0`. Создать отдельный тест для проверки, что роутер реагирует на изменение провайдера (виджет-тест с FakeAuthNotifier).

### H5 — KeychainUnavailableException

**Файл:** `test/core/auth/secure_token_storage_test.dart` (расширить существующий)

Добавить в `FakeFlutterSecureStorage` флаг `throwKeychainUnavailable`:

```dart
bool throwKeychainUnavailable = false;

@override
Future<String?> read({required String key, ...}) async {
  if (throwOnRead) throw PlatformException(code: 'keychain_error');
  if (throwKeychainUnavailable) throw PlatformException(code: '-25308');
  return _store[key];
}
```

| # | Тест | Проверяет |
|---|------|-----------|
| 1 | `loadTokens бросает KeychainUnavailableException при code -25308` | `expect(() => storage.loadTokens(), throwsA(isA<KeychainUnavailableException>()))`. |
| 2 | `loadTokens возвращает null при других PlatformException` | `throwOnRead = true` (code: `keychain_error`) → возвращает `null`. |
| 3 | `loadAccessToken бросает KeychainUnavailableException при -25308` | Аналогично для `loadAccessToken`. |
| 4 | `loadRefreshToken бросает KeychainUnavailableException при -25308` | Аналогично для `loadRefreshToken`. |

### H6 — Безусловный data(null) при мёртвом refresh

**Файл:** `test/core/auth/check_session_errors_test.dart` (дополнить)

| # | Тест | Проверяет |
|---|------|-----------|
| 1 | `backgroundRefresh=true + pair==null → state=data(null)` | `checkSession(backgroundRefresh: true)` при пустом storage → state = `data(null)`. |
| 2 | `backgroundRefresh=true + failed refresh → state=data(null)` | Storage возвращает expired pair, refresh endpoint отвечает 401 → state = `data(null)`. |
| 3 | `backgroundRefresh=true + failed refresh → clearTokens вызван` | `fakeStorage.clearCount == 1`. |
| 4 | `backgroundRefresh=true + failed refresh → _clearCache вызван` | SharedPreferences не содержит `cached_user` после вызова. |

---

## 4. Порядок выполнения

Гипотезы применяются в следующем порядке — некоторые зависят от артефактов предыдущих:

```
Шаг 1  →  H5: добавить KeychainUnavailableException в secure_token_storage.dart
           (H3 ссылается на этот тип — он должен существовать)

Шаг 2  →  H3: изменить catch-блок в checkSession
           (зависит от KeychainUnavailableException из H5)

Шаг 3  →  H6: убрать if(!backgroundRefresh) перед state=data(null)
           (изменяет тот же метод checkSession — сделать вместе с H3)

Шаг 4  →  H1: заменить @riverpod на @Riverpod(keepAlive: true)
           + перегенерировать: dart run build_runner build --delete-conflicting-outputs
           (не зависит от H3/H6 функционально, но лучше делать после
            изменений в auth_provider.dart, чтобы одна генерация покрыла всё)

Шаг 5  →  H4: убрать setLogoutCallback из build(), изменить _handleLogout,
           обновить _RouterNotifier
           (зависит от H1: keepAlive гарантирует, что провайдер не пересоздаётся
            бесконтрольно, делая H4 менее критичным, но всё равно нужным)

Шаг 6  →  H2: добавить WidgetsBindingObserver в _AppInitState
           (последний шаг — не влияет на бизнес-логику выше, это UI-слой)
```

Визуальная зависимость:

```
H5 ──► H3 ──┐
             ├──► H1 ──► H4 ──► H2
        H6 ──┘
```

---

## 5. Критерии готовности

### Функциональные

- [ ] Пользователь открывает приложение после закрытия через switcher — видит dashboard, не экран логина (при живом refresh-токене).
- [ ] Пользователь открывает приложение после перезагрузки устройства без разблокировки (background launch) — приложение не разлогинивает.
- [ ] При отсутствии сети и живых токенах — пользователь остаётся залогиненным, не уходит на `/login`.
- [ ] При мёртвом refresh-токене (истёк > 30 дней) — пользователь корректно переходит на `/login` при открытии приложения.
- [ ] При возврате из background после > 1 часа (истёкший access, живой refresh) — тихое обновление токена без видимого logout.

### Кодовые

- [ ] `auth_provider.g.dart` перегенерирован: тип `NotifierProvider`, не `AutoDisposeNotifierProvider`.
- [ ] В `auth_provider.dart` нет вызова `setLogoutCallback`.
- [ ] В `api_client.dart` `_handleLogout` не вызывает `_onLogout?.call()`.
- [ ] `KeychainUnavailableException` определён в `secure_token_storage.dart` и экспортируется (или доступен через `api_client.dart` export).
- [ ] Catch-блок в `checkSession` не содержит `state = const AsyncValue.data(null)` в ветке, не связанной с явным отсутствием токенов.
- [ ] `_AppInitState` реализует `WidgetsBindingObserver` и вызывает `removeObserver` в `dispose`.

### Тестовые

- [ ] Все существующие тесты проходят: `flutter test`.
- [ ] Новые тесты добавлены в файлы, указанные в Разделе 3.
- [ ] `FakeFlutterSecureStorage` расширен флагом `throwKeychainUnavailable`.
- [ ] Тест на `KeychainUnavailableException` при коде `-25308` — зелёный.
- [ ] Тест на `resumed` → `checkSession(backgroundRefresh: true)` — зелёный.
- [ ] Тест на `backgroundRefresh=true` + мёртвый refresh → `state=data(null)` — зелёный.
- [ ] Покрытие `lib/core/auth/auth_provider.dart` не ниже 80% после изменений (`flutter test --coverage`).

### Ручная проверка (QA-сценарии)

| Сценарий | Шаги | Ожидаемый результат |
|----------|------|---------------------|
| S1: cold start после закрытия | Авторизоваться → закрыть свайпом → открыть | Dashboard, не /login |
| S2: background resume | Открыть → свернуть на 2 часа → вернуть | Dashboard, тихое обновление токена |
| S3: без сети | Авторизоваться → отключить сеть → закрыть → открыть | Dashboard (cached user), не /login |
| S4: мёртвая сессия | Авторизоваться → инвалидировать refresh на сервере → закрыть → открыть | /login |
| S5: background launch | Перезагрузить устройство → не разблокировать → получить push → приложение стартует в фоне → разблокировать и открыть | Dashboard, не /login |

---

## 6. Артефакты после реализации

После выполнения всех изменений запустить:

```bash
# Перегенерация (обязательно после H1)
dart run build_runner build --delete-conflicting-outputs

# Форматирование
dart format lib/ test/

# Анализ
dart analyze

# Тесты с покрытием
flutter test --coverage
```

Закоммитить `auth_provider.g.dart` вместе с изменениями в `auth_provider.dart` одним коммитом, чтобы генерированный код не расходился с источником.
