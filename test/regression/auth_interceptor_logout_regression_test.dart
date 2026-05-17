// test/regression/auth_interceptor_logout_regression_test.dart
//
// Block B — _AuthInterceptor logout behaviour after H4 change.
//
// H4: _handleLogout() only clears tokens; no global callback.
//     AuthNotifier detects missing tokens on next checkSession call.
//
// These are pure unit tests (no WidgetsFlutterBinding) — matches the style
// of the existing auth_interceptor_test.dart.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/api/api_client.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/auth/secure_token_storage.dart';
import 'package:kayfit/core/auth/token_pair.dart';
import 'package:kayfit/shared/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Fake storage ─────────────────────────────────────────────────────────────

class _FakeStorage implements SecureTokenStorage {
  TokenPair? _pair;
  int clearCount = 0;

  void seed(TokenPair pair) => _pair = pair;

  @override
  Future<void> saveTokens(TokenPair pair) async => _pair = pair;
  @override
  Future<TokenPair?> loadTokens() async => _pair;
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

// ─── MockClientAdapter (same pattern as auth_interceptor_test.dart) ───────────

typedef _RequestHandler = Future<ResponseBody> Function(RequestOptions opts);

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._onRequest);
  final _RequestHandler _onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      _onRequest(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

TokenPair _validPair() => TokenPair(
      accessToken: 'access_tok',
      refreshToken: 'refresh_tok',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStorage fakeStorage;

  setUp(() {
    fakeStorage = _FakeStorage();
    SharedPreferences.setMockInitialValues({});
  });

  // ── B1: 401 → refresh 401 → only clearTokens, no immediate state change ──

  test(
    'B1 — 401 + failed refresh: clearTokens is called, '
    'authNotifier state is NOT immediately set to data(null) by interceptor (H4)',
    () async {
      // H4: _handleLogout() only clears tokens.
      // AuthNotifier remains in its current state — next checkSession() handles it.
      fakeStorage.seed(_validPair());

      final refreshAdapter = _MockAdapter(
        (_) async => _json('{}', 401),
      );

      await initApiClient(
        storage: fakeStorage,
        refreshDioFactory: () {
          final d =
              Dio(BaseOptions(baseUrl: 'https://app.carbcounter.online'));
          d.httpClientAdapter = refreshAdapter;
          return d;
        },
      );
      apiDio.httpClientAdapter =
          _MockAdapter((_) async => _json('{}', 401));

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(fakeStorage)],
      );
      addTearDown(container.dispose);

      // Set a known state before the 401 fires.
      container
          .read(authNotifierProvider.notifier)
          .restoreFromCache(const UserProfile(id: 1, email: 'u@test.com'));

      try {
        await apiDio.get('/api/v1/protected');
      } on DioException catch (_) {}

      // clearTokens must be called (interceptor did its job).
      expect(fakeStorage.clearCount, greaterThan(0));

      // AuthNotifier state must NOT have been set to data(null) by interceptor.
      // H4: there is no global callback — the state is changed only by
      // AuthNotifier.checkSession() on the next lifecycle resume.
      final state = container.read(authNotifierProvider);
      expect(
        state.value,
        isNotNull,
        reason: 'Interceptor must not mutate AuthNotifier state directly (H4)',
      );
    },
  );

  // ── B2: network timeout on refresh → tokens NOT cleared ──────────────────

  test(
    'B2 — receiveTimeout during refresh: tokens not cleared (H3 / EC8)',
    () async {
      fakeStorage.seed(_validPair());

      final refreshAdapter = _MockAdapter((_) async {
        throw DioException(
          requestOptions:
              RequestOptions(path: '/api/v1/auth/refresh'),
          type: DioExceptionType.receiveTimeout,
        );
      });

      await initApiClient(
        storage: fakeStorage,
        refreshDioFactory: () {
          final d =
              Dio(BaseOptions(baseUrl: 'https://app.carbcounter.online'));
          d.httpClientAdapter = refreshAdapter;
          return d;
        },
      );
      apiDio.httpClientAdapter =
          _MockAdapter((_) async => _json('{}', 401));

      try {
        await apiDio.get('/api/v1/protected');
      } catch (_) {}

      // Timeout → session may still be valid → tokens must survive.
      expect(fakeStorage.clearCount, equals(0));
    },
  );

  // ── B3: empty storage + checkSession backgroundRefresh → data(null) ───────

  test(
    'B3 — empty storage after interceptor clearTokens: '
    'checkSession(backgroundRefresh: true) → state = data(null) (H6 chain)',
    () async {
      // Simulate the state of storage after _handleLogout() cleared tokens.
      // fakeStorage starts empty (clearTokens already called).

      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(fakeStorage)],
      );
      addTearDown(container.dispose);

      // Set user state as if they were previously logged in.
      container
          .read(authNotifierProvider.notifier)
          .restoreFromCache(const UserProfile(id: 99, email: 'x@t.com'));

      // Simulate H2: app resumes → backgroundRefresh fires.
      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: true);

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, isNull,
          reason: 'pair==null must set data(null) even on backgroundRefresh (H6)');
    },
  );

  // ── B4: non-401 network error → tokens NOT cleared ────────────────────────

  test(
    'B4 — connectionError (not 401) on main request: tokens not cleared',
    () async {
      fakeStorage.seed(_validPair());

      await initApiClient(
        storage: fakeStorage,
        refreshDioFactory: () => Dio(),
      );
      apiDio.httpClientAdapter = _MockAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/protected'),
          type: DioExceptionType.connectionError,
        );
      });

      try {
        await apiDio.get('/api/v1/protected');
      } catch (_) {}

      // Network error (not 401) must not trigger token clearing.
      expect(fakeStorage.clearCount, equals(0));
    },
  );
}
