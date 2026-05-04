import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

const _kLocalConsentKey = 'ai_consent_local';

/// How long to wait for the server before surfacing a timeout error.
/// Must cover the worst-case auth-refresh chain: original POST (~3s)
/// + AuthInterceptor refresh (~3s) + retry (~3s) on slow mobile networks.
const _kConsentTimeout = Duration(seconds: 20);

/// null = not yet fetched / never answered
/// true = accepted
/// false = declined
class AiConsentNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    // Auto-load from local storage on first access (for unauthenticated users).
    Future.microtask(_loadLocal);
    return null;
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getBool(_kLocalConsentKey);
    if (local != null && state == null) state = local;
  }

  /// Called after login — syncs from server (overrides local value).
  Future<void> load() async {
    try {
      final resp = await apiDio
          .get('/api/user/ai_consent')
          .timeout(_kConsentTimeout);
      state = resp.data['consent'] as bool?;
    } on TimeoutException {
      // Server too slow — keep local value.
      await _loadLocal();
    } on DioException {
      // Server unavailable — keep local value.
      await _loadLocal();
    }
  }

  /// Persists consent, syncs with server.
  /// Throws [TimeoutException] if the server does not respond within 5 s.
  /// Throws [DioException] on network errors.
  Future<void> setConsent(bool value) async {
    debugPrint('[ai_consent] setConsent($value) START');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocalConsentKey, value);
    try {
      final resp = await apiDio
          .post('/api/user/ai_consent', data: {'consent': value})
          .timeout(_kConsentTimeout);
      debugPrint('[ai_consent] OK status=${resp.statusCode}');
      state = value;
    } on TimeoutException {
      debugPrint('[ai_consent] TIMEOUT after $_kConsentTimeout');
      rethrow;
    } on DioException catch (e) {
      debugPrint('[ai_consent] DIOERR type=${e.type} '
          'status=${e.response?.statusCode} '
          'body=${e.response?.data} '
          'msg=${e.message}');
      rethrow;
    }
  }
}

final aiConsentProvider =
    NotifierProvider<AiConsentNotifier, bool?>(AiConsentNotifier.new);
