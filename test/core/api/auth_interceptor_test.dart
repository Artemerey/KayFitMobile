// test/core/api/auth_interceptor_test.dart
//
// Unit tests for _AuthInterceptor behaviour.
//
// Strategy:
// - Inject FakeSecureTokenStorage to observe token reads/writes.
// - Inject a MockClientAdapter on apiDio to stub responses.
// - Inject a refreshDioFactory that returns a second Dio with its own
//   MockClientAdapter — this intercepts the in-interceptor refresh call.
// - Use dart test (not TestWidgetsFlutterBinding) to avoid the
//   "all HTTP returns 400" stub applied by the widget binding.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/api/api_client.dart';
import 'package:kayfit/core/auth/secure_token_storage.dart';
import 'package:kayfit/core/auth/token_pair.dart';

// ─── Fake SecureTokenStorage ──────────────────────────────────────────────────

class FakeSecureTokenStorage implements SecureTokenStorage {
  TokenPair? _pair;
  int saveCount = 0;
  int clearCount = 0;

  void seed(TokenPair pair) => _pair = pair;

  @override
  Future<void> saveTokens(TokenPair pair) async {
    _pair = pair;
    saveCount++;
  }

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

// ─── Minimal MockClientAdapter ────────────────────────────────────────────────

typedef _RequestHandler = Future<ResponseBody> Function(RequestOptions opts);

class MockClientAdapter implements HttpClientAdapter {
  MockClientAdapter(this._onRequest);
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

ResponseBody _jsonResponse(String body, int status) => ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

// ─── Helpers ──────────────────────────────────────────────────────────────────

TokenPair _validPair({
  String access = 'valid_access',
  String refresh = 'valid_refresh',
}) =>
    TokenPair(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeSecureTokenStorage fakeStorage;

  setUp(() {
    fakeStorage = FakeSecureTokenStorage();
  });

  // ── onRequest ─────────────────────────────────────────────────────────────

  group('onRequest', () {
    test('adds Authorization header when access token exists', () async {
      fakeStorage.seed(_validPair(access: 'tok_123'));

      String? capturedAuth;
      await initApiClient(
        storage: fakeStorage,
        refreshDioFactory: () => Dio(),
      );
      apiDio.httpClientAdapter = MockClientAdapter((opts) async {
        capturedAuth = opts.headers['Authorization'] as String?;
        return _jsonResponse('{}', 200);
      });

      await apiDio.get('/api/v1/user/profile');

      expect(capturedAuth, equals('Bearer tok_123'));
    });

    test('does NOT add Authorization header for login path', () async {
      fakeStorage.seed(_validPair());

      String? capturedAuth = 'present';
      await initApiClient(storage: fakeStorage, refreshDioFactory: () => Dio());
      apiDio.httpClientAdapter = MockClientAdapter((opts) async {
        capturedAuth = opts.headers['Authorization'] as String?;
        return _jsonResponse('{}', 200);
      });

      await apiDio.post('/api/v1/auth/login', data: {});

      expect(capturedAuth, isNull);
    });

    test('does NOT add Authorization header when no token is stored', () async {
      // fakeStorage is empty.
      String? capturedAuth = 'present';
      await initApiClient(storage: fakeStorage, refreshDioFactory: () => Dio());
      apiDio.httpClientAdapter = MockClientAdapter((opts) async {
        capturedAuth = opts.headers['Authorization'] as String?;
        return _jsonResponse('{}', 200);
      });

      await apiDio.get('/api/v1/user/profile');

      expect(capturedAuth, isNull);
    });
  });

  // ── 401 → refresh → retry ─────────────────────────────────────────────────

  group('401 handling', () {
    test('401 triggers refresh then retries original request', () async {
      fakeStorage.seed(_validPair());

      int mainCallCount = 0;
      int refreshCallCount = 0;

      // Set up a refresh Dio that returns a new token pair.
      final refreshAdapter = MockClientAdapter((opts) async {
        refreshCallCount++;
        return _jsonResponse(
          '{"access_token":"new_access","refresh_token":"new_refresh","expires_in":3600}',
          200,
        );
      });

      await initApiClient(
        storage: fakeStorage,
        refreshDioFactory: () {
          final d = Dio(BaseOptions(baseUrl: 'https://app.carbcounter.online'));
          d.httpClientAdapter = refreshAdapter;
          return d;
        },
      );

      apiDio.httpClientAdapter = MockClientAdapter((opts) async {
        mainCallCount++;
        if (mainCallCount == 1) {
          // First call → 401 to trigger refresh.
          return _jsonResponse('{"detail":"Unauthorized"}', 401);
        }
        // Retry after refresh → success.
        return _jsonResponse('{"ok":true}', 200);
      });

      final response = await apiDio.get('/api/v1/some/protected');

      expect(response.statusCode, equals(200));
      expect(refreshCallCount, equals(1));
      // saveTokens called exactly once: after successful refresh.
      expect(fakeStorage.saveCount, equals(1));
    });

    test('clears tokens (only) when refresh returns 401', () async {
      // H4: _handleLogout no longer calls a global logout callback.
      // It only clears tokens; AuthNotifier detects the absence on next
      // checkSession (triggered via WidgetsBindingObserver on resumed).
      fakeStorage.seed(_validPair());

      final refreshAdapter = MockClientAdapter(
        (_) async => _jsonResponse('{}', 401),
      );

      await initApiClient(
        storage: fakeStorage,
        refreshDioFactory: () {
          final d = Dio(BaseOptions(baseUrl: 'https://app.carbcounter.online'));
          d.httpClientAdapter = refreshAdapter;
          return d;
        },
      );
      apiDio.httpClientAdapter = MockClientAdapter(
        (_) async => _jsonResponse('{}', 401),
      );

      try {
        await apiDio.get('/api/v1/protected');
      } on DioException catch (_) {}

      expect(fakeStorage.clearCount, greaterThan(0));
      expect(await fakeStorage.loadAccessToken(), isNull);
    });

    test('401 on auth path is not intercepted (no token clear)', () async {
      fakeStorage.seed(_validPair());

      await initApiClient(storage: fakeStorage, refreshDioFactory: () => Dio());
      apiDio.httpClientAdapter = MockClientAdapter(
        (_) async => _jsonResponse('{}', 401),
      );

      try {
        await apiDio.post('/api/v1/auth/login', data: {});
      } on DioException catch (_) {}

      // Auth paths should NOT trigger token clear.
      expect(fakeStorage.clearCount, equals(0));
    });

    test('network timeout on refresh does NOT clear tokens', () async {
      fakeStorage.seed(_validPair());

      final refreshAdapter = MockClientAdapter((_) async {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/v1/auth/refresh'),
          type: DioExceptionType.receiveTimeout,
        );
      });

      await initApiClient(
        storage: fakeStorage,
        refreshDioFactory: () {
          final d = Dio(BaseOptions(baseUrl: 'https://app.carbcounter.online'));
          d.httpClientAdapter = refreshAdapter;
          return d;
        },
      );
      apiDio.httpClientAdapter = MockClientAdapter(
        (_) async => _jsonResponse('{}', 401),
      );

      try {
        await apiDio.get('/api/v1/protected');
      } catch (_) {}

      // Timeout → session may still be valid; tokens must not be cleared.
      expect(fakeStorage.clearCount, equals(0));
    });

    test('no refresh token → clears tokens immediately', () async {
      // fakeStorage is empty — no token.
      // H4: no logout callback; _handleLogout only clears tokens.
      // Since storage is empty, clearCount stays 0 but the 401 propagates.
      await initApiClient(storage: fakeStorage, refreshDioFactory: () => Dio());
      apiDio.httpClientAdapter = MockClientAdapter(
        (_) async => _jsonResponse('{}', 401),
      );

      DioException? thrown;
      try {
        await apiDio.get('/api/v1/protected');
      } on DioException catch (e) {
        thrown = e;
      }

      // The 401 should have propagated as a DioException.
      expect(thrown, isNotNull);
      // clearTokens called once (even though storage was empty — idempotent).
      expect(fakeStorage.clearCount, equals(1));
    });
  });
}
