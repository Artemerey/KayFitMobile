// test/core/auth/auth_session_test.dart
//
// Tests covering the auth session fix hypotheses H1, H3, H5, H6.
//
// H1 — keepAlive: authNotifierProvider is NotifierProvider (not AutoDispose).
// H3 — catch classification: DioException network errors don't reset state.
// H5 — KeychainUnavailableException: -25308 throws, not returns null.
// H6 — backgroundRefresh=true + pair==null → state=data(null) unconditionally.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/auth/secure_token_storage.dart';
import 'package:kayfit/core/auth/token_pair.dart';
import 'package:kayfit/shared/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Fake SecureTokenStorage ──────────────────────────────────────────────────

class _FakeTokenStorage implements SecureTokenStorage {
  TokenPair? _pair;
  int clearCount = 0;

  /// When set, loadTokens() throws this object instead of returning _pair.
  Object? throwOnLoad;

  void seed(TokenPair pair) => _pair = pair;

  @override
  Future<void> saveTokens(TokenPair pair) async => _pair = pair;

  @override
  Future<TokenPair?> loadTokens() async {
    if (throwOnLoad != null) throw throwOnLoad!;
    return _pair;
  }

  @override
  Future<String?> loadAccessToken() async => _pair?.accessToken;

  @override
  Future<String?> loadRefreshToken() async => _pair?.refreshToken;

  @override
  Future<void> clearTokens() async {
    _pair = null;
    clearCount++;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _testUser = UserProfile(id: 42, email: 'test@example.com');

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ── H1: keepAlive ─────────────────────────────────────────────────────────

  group('H1 — keepAlive', () {
    test('authNotifierProvider is NotifierProvider (not AutoDispose)', () {
      // After regeneration with @Riverpod(keepAlive: true) the provider must
      // be NotifierProvider, not AutoDisposeNotifierProvider.
      expect(
        authNotifierProvider,
        isA<NotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>>(),
      );
    });

    test('state survives when there are no active listeners', () {
      final storage = _FakeTokenStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      // Manually set state via restoreFromCache.
      container.read(authNotifierProvider.notifier).restoreFromCache(_testUser);
      expect(container.read(authNotifierProvider).value, equals(_testUser));

      // With keepAlive: true, reading the provider again does NOT re-create it.
      // The state stays as data(_testUser) without any listeners.
      final stateAfter = container.read(authNotifierProvider);
      expect(stateAfter, isA<AsyncData<UserProfile?>>());
      expect(stateAfter.value, equals(_testUser));
    });
  });

  // ── H3: catch-block classification ────────────────────────────────────────

  group('H3 — DioException does not reset state', () {
    test('connectionTimeout from loadTokens does not set state to data(null)',
        () async {
      final storage = _FakeTokenStorage();
      // Make loadTokens() throw a connectionTimeout DioException.
      storage.throwOnLoad = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      );

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      // checkSession with backgroundRefresh:false — in old code this would set
      // data(null) on any exception; in fixed code it must not for network errors.
      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: false);

      // State must NOT be AsyncData(null): connectionTimeout ≠ dead tokens.
      // It may be loading() or data(someUser), but must never be data(null).
      final state = container.read(authNotifierProvider);
      expect(state, isNot(equals(const AsyncValue<UserProfile?>.data(null))));
    });

    test('receiveTimeout from loadTokens does not set state to data(null)',
        () async {
      final storage = _FakeTokenStorage();
      storage.throwOnLoad = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.receiveTimeout,
      );

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: false);

      final state = container.read(authNotifierProvider);
      expect(state, isNot(equals(const AsyncValue<UserProfile?>.data(null))));
    });

    test(
        'backgroundRefresh=false + DioException connectionError does not set '
        'state to data(null)', () async {
      final storage = _FakeTokenStorage();
      storage.throwOnLoad = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      );

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: false);

      final state = container.read(authNotifierProvider);
      expect(state, isNot(equals(const AsyncValue<UserProfile?>.data(null))));
    });
  });

  // ── H5: KeychainUnavailableException in checkSession ──────────────────────

  group('H5 — KeychainUnavailableException does not reset state', () {
    test('KeychainUnavailableException from loadTokens does not log out',
        () async {
      final storage = _FakeTokenStorage();
      storage.throwOnLoad = const KeychainUnavailableException('-25308');

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: false);

      // Keychain temporarily locked → state must NOT become data(null).
      // It remains loading() — the UI will retry when the device is unlocked.
      final state = container.read(authNotifierProvider);
      expect(state, isNot(equals(const AsyncValue<UserProfile?>.data(null))));
      // Tokens must not be cleared — Keychain just wasn't accessible.
      expect(storage.clearCount, equals(0));
    });
  });

  // ── H6: pair==null with backgroundRefresh=true → data(null) ──────────────

  group('H6 — backgroundRefresh=true + no tokens → state=data(null)', () {
    test('checkSession backgroundRefresh=true with empty storage → data(null)',
        () async {
      final storage = _FakeTokenStorage(); // empty — no tokens

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      // backgroundRefresh: true simulates the resumed lifecycle callback.
      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: true);

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, isNull);
    });

    test('checkSession backgroundRefresh=false with empty storage → data(null)',
        () async {
      final storage = _FakeTokenStorage();

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: false);

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, isNull);
    });

    test(
        'checkSession backgroundRefresh=true + pair==null clears cache',
        () async {
      SharedPreferences.setMockInitialValues({
        'cached_user': '{"id":42,"email":"old@example.com","isActive":true}',
      });
      final storage = _FakeTokenStorage(); // no tokens → pair == null

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_user'), isNull);
    });

    test(
        'checkSession backgroundRefresh=true with KeychainUnavailableException '
        '→ does not set data(null)',
        () async {
      // Simulate Keychain locked right when backgroundRefresh fires.
      // _FakeTokenStorage throws KeychainUnavailableException directly,
      // mimicking what SecureTokenStorageImpl does when it catches -25308.
      final storage = _FakeTokenStorage();
      storage.throwOnLoad = const KeychainUnavailableException('-25308');

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      // backgroundRefresh=true so we stay in data(user) — no loading flash.
      container.read(authNotifierProvider.notifier).restoreFromCache(_testUser);

      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: true);

      // State must remain data(_testUser) — Keychain locked ≠ no tokens.
      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, equals(_testUser));
    });
  });
}
