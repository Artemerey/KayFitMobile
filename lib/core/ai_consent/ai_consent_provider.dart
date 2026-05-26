import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

/// Exposed so [main.dart] can read the initial value synchronously before the
/// first router evaluation, preventing the race where the router briefly
/// redirects to /ai-consent for users who have already answered.
const kAiConsentLocalKey = 'ai_consent_local';

// Keep backward compat for internal use within this file.
const _kLocalConsentKey = kAiConsentLocalKey;

/// How long to wait for the server before surfacing a timeout error.
/// Must cover the worst-case auth-refresh chain: original POST (~3s)
/// + AuthInterceptor refresh (~3s) + retry (~3s) on slow mobile networks.
const _kConsentTimeout = Duration(seconds: 20);

/// null = not yet fetched / never answered
/// true = accepted
/// false = declined
class AiConsentNotifier extends Notifier<bool?> {
  /// Optionally pre-seed the state with a value read synchronously from
  /// SharedPreferences in [main.dart] before ProviderScope is created.
  AiConsentNotifier([this._initial]);
  final bool? _initial;

  @override
  bool? build() {
    if (_initial == null) {
      // No pre-seeded value — load async (first-launch or fresh install).
      Future.microtask(_loadLocal);
    }
    return _initial;
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
      await _loadLocal();
    } on DioException {
      await _loadLocal();
    } catch (e) {
      debugPrint('[ai_consent] load unexpected error: $e');
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
