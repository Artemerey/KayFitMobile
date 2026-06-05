import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/secure_token_storage.dart';
import '../auth/token_pair.dart';
import 'locale_interceptor.dart';

export '../auth/secure_token_storage.dart';
export '../auth/token_pair.dart';

const _baseUrl = 'https://app.carbcounter.online';

const baseUrl = _baseUrl;

late Dio apiDio;

// ── Singleton SecureTokenStorage shared by the entire app ─────────────────────
// Created once in initApiClient() and used by both _AuthInterceptor and
// AuthNotifier to avoid circular-dependency issues.
late SecureTokenStorage secureTokenStorage;

Future<void> initApiClient({
  SecureTokenStorage? storage,
  @visibleForTesting RefreshDioFactory? refreshDioFactory,
}) async {
  secureTokenStorage = storage ?? SecureTokenStorageImpl();

  apiDio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    // 30s connect — production tester hit `[connection timeout]` after 15s on
    // weak LTE because the TLS handshake couldn't complete in time. Server
    // round-trip from a healthy network is <100ms, so 30s only kicks in when
    // the radio is genuinely degraded and we'd rather wait than instantly fail.
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  apiDio.interceptors.add(LocaleInterceptor());

  apiDio.interceptors.add(
    _AuthInterceptor(
      apiDio,
      secureTokenStorage,
      refreshDioFactory: refreshDioFactory,
    ),
  );
}

/// Optional factory for creating the refresh Dio, injected in tests.
typedef RefreshDioFactory = Dio Function();

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(
    this._dio,
    this._storage, {
    @visibleForTesting RefreshDioFactory? refreshDioFactory,
  }) : _refreshDioFactory = refreshDioFactory;

  final Dio _dio;
  final SecureTokenStorage _storage;
  final RefreshDioFactory? _refreshDioFactory;

  /// Non-null while a token refresh is in progress.
  /// Completes with the new access token, or null if refresh failed.
  /// All concurrent 401s wait on this and retry with the new token.
  Completer<String?>? _refreshCompleter;

  // In-memory fallback for the access token. Updated immediately after a
  // successful refresh so subsequent requests use the new token even when the
  // keychain write fails silently (PlatformException swallowed in saveTokens).
  // The backend uses refresh token rotation — a revoked refresh token causes
  // the server to revoke ALL user tokens, so we must avoid re-sending a
  // refresh token that was already consumed.
  String? _inMemoryAccessToken;

  static bool _isAuthPath(String path) =>
      path.contains('/api/v1/auth/login') ||
      path.contains('/api/v1/auth/register') ||
      path.contains('/api/v1/auth/refresh') ||
      path.contains('/api/v1/auth/apple');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthPath(options.path)) {
      // Prefer the in-memory token (set right after a successful refresh) over
      // the keychain read. If the keychain write failed silently after a prior
      // refresh, _inMemoryAccessToken has the fresh token while the keychain
      // still holds the expired one.
      final token = _inMemoryAccessToken ?? await _storage.loadAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Don't intercept auth endpoints themselves
    if (_isAuthPath(err.requestOptions.path)) {
      handler.next(err);
      return;
    }

    // ── If a refresh is already in progress, wait for it then retry ──────────
    if (_refreshCompleter != null) {
      final newToken = await _refreshCompleter!.future;
      if (newToken != null) {
        try {
          final opts = _cloneForRetry(err.requestOptions, newToken);
          final retryResp = await _dio.fetch(opts);
          handler.resolve(retryResp);
        } catch (_) {
          handler.next(err);
        }
      } else {
        // Refresh already failed (logout triggered by the first refresher)
        handler.next(err);
      }
      return;
    }

    // ── This request is the first to get 401 — do the refresh ────────────────
    _refreshCompleter = Completer<String?>();
    String? newAccess;
    try {
      final refreshToken = await _storage.loadRefreshToken();
      if (refreshToken == null) {
        if (!_refreshCompleter!.isCompleted) {
          _refreshCompleter!.complete(null);
        }
        await _handleLogout();
        handler.next(err);
        return;
      }

      final refreshDio = _refreshDioFactory != null
          ? _refreshDioFactory()
          : Dio(BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 15),
            ));
      final resp = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = resp.data as Map<String, dynamic>;
      newAccess = data['access_token'] as String;
      final newPair = TokenPair.fromApiResponse(data);
      // Cache in memory immediately — saveTokens may fail silently with a
      // PlatformException (keychain temporarily unavailable). Without this,
      // subsequent requests read the old expired token from keychain, re-send
      // the already-consumed refresh token, and the backend (rotation policy)
      // revokes all sessions for the user.
      _inMemoryAccessToken = newAccess;
      await _storage.saveTokens(newPair);

      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(newAccess);
      }
    } on DioException catch (e) {
      // EC8: network timeout on refresh → do NOT logout; let caller retry later.
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        if (!_refreshCompleter!.isCompleted) {
          _refreshCompleter!.complete(null);
        }
        _refreshCompleter = null;
        // Surface error without clearing tokens — session may still be valid.
        handler.next(err);
        return;
      }
      // Auth/server error → logout.
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(null);
      }
      _refreshCompleter = null;
      await _handleLogout();
      handler.next(err);
      return;
    } catch (_) {
      // Refresh itself failed — token is dead, log out
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(null);
      }
      _refreshCompleter = null;
      await _handleLogout();
      handler.next(err);
      return;
    }

    // Refresh succeeded. Clear in-flight marker BEFORE retrying so concurrent
    // 401s don't queue forever.
    _refreshCompleter = null;

    // Retry the original request that triggered the 401
    try {
      final opts = _cloneForRetry(err.requestOptions, newAccess);
      final retryResp = await _dio.fetch(opts);
      handler.resolve(retryResp);
    } catch (e) {
      // Retry failed for non-auth reasons (timeout, network, server error).
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(err);
      }
    }
  }

  /// Returns a fresh `RequestOptions` safe to re-send after a 401-refresh.
  ///
  /// Dio's `RequestOptions.data` may be a `FormData` whose internal multipart
  /// stream is single-consumption — if we re-`fetch(opts)` after the first
  /// send, the body is empty and the backend either rejects (4xx) or
  /// re-issues 401, masking the refresh path. `FormData.clone()` re-creates
  /// the stream from the same fields/files. Other body types (Map, String,
  /// bytes) are safe to re-send as-is.
  RequestOptions _cloneForRetry(RequestOptions opts, String newAccessToken) {
    final data = opts.data is FormData ? (opts.data as FormData).clone() : opts.data;
    final headers = Map<String, dynamic>.from(opts.headers)
      ..['Authorization'] = 'Bearer $newAccessToken';
    return opts.copyWith(data: data, headers: headers);
  }

  Future<void> _handleLogout() async {
    // Only clear tokens. AuthNotifier detects the absence of tokens on the
    // next checkSession call (triggered via H2 WidgetsBindingObserver on
    // resumed, or on the next API-driven auth check). There is no global
    // callback — that was a race-condition source (H4).
    await _storage.clearTokens();
  }
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class PaymentRequiredException implements Exception {
  const PaymentRequiredException();
  @override
  String toString() => 'PaymentRequiredException';
}
