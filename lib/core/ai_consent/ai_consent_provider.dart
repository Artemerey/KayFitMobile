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

/// True once the initial consent state has been resolved — either from
/// SharedPreferences (fast path, pre-seeded in main.dart) or from the server
/// (slow path, on reinstall where SharedPreferences was cleared but the
/// Keychain auth token survived).  The router waits for this to be true
/// before redirecting to /ai-consent so returning users never see a flash.
final aiConsentReadyProvider = StateProvider<bool>((ref) => false);

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
      // No pre-seeded value (reinstall or fresh install) — resolve async.
      // _initialize tries local first, then server, then marks ready.
      Future.microtask(_initialize);
    }
    return _initial;
  }

  Future<void> _initialize() async {
    await _loadLocal();
    if (state == null) {
      // Nothing locally (e.g. reinstall) — check server.  Silently swallows
      // network errors via load()'s own fallback to _loadLocal.
      await load();
    }
    ref.read(aiConsentReadyProvider.notifier).state = true;
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

  /// Persists consent locally and syncs with server best-effort.
  /// Throws [DioException] with status 401 only (session expired → logout).
  /// Timeouts and other network errors are logged but do not block the caller —
  /// the local save already recorded the user's choice.
  Future<void> setConsent(bool value) async {
    debugPrint('[ai_consent] setConsent($value) START');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocalConsentKey, value);
    state = value; // update state from local save immediately
    try {
      final resp = await apiDio
          .post('/api/user/ai_consent', data: {'consent': value})
          .timeout(_kConsentTimeout);
      debugPrint('[ai_consent] OK status=${resp.statusCode}');
    } on TimeoutException {
      // Local save succeeded — don't block the user on a slow network.
      debugPrint('[ai_consent] server sync timeout — proceeding with local value');
    } on DioException catch (e) {
      debugPrint('[ai_consent] DIOERR type=${e.type} '
          'status=${e.response?.statusCode} '
          'body=${e.response?.data} '
          'msg=${e.message}');
      if (e.response?.statusCode == 401) {
        rethrow; // session expired — screen handles logout
      }
      // Other network errors: local save succeeded, proceed silently.
    }
  }
}

final aiConsentProvider =
    NotifierProvider<AiConsentNotifier, bool?>(AiConsentNotifier.new);
