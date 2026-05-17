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
    connectTimeout: const Duration(seconds: 15),
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
      final token = await _storage.loadAccessToken();
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
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
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
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ));
      final resp = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = resp.data as Map<String, dynamic>;
      newAccess = data['access_token'] as String;
      final newPair = TokenPair.fromApiResponse(data);
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
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccess';
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
