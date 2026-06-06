import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/user_profile.dart';
import '../api/api_client.dart';
import '../notifications/notification_service.dart';
import '../ai_consent/ai_consent_provider.dart';
import '../subscription/subscription_provider.dart';
import 'onboarding_sync.dart';

part 'auth_provider.g.dart';

const _kCachedUserKey = 'cached_user';

// ── SecureTokenStorage Riverpod provider ────────────────────────────────────
// Returns the singleton instance created in initApiClient() so all parts of
// the app share the same storage object (and the same underlying Keychain).

// ignore: deprecated_member_use
final secureStorageProvider = Provider<SecureTokenStorage>(
  (_) => secureTokenStorage,
);

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  StreamSubscription<void>? _sessionExpiredSub;

  /// True when the last logout was triggered by an expired/revoked refresh
  /// token (i.e. the server forced it, not a manual logout). LoginScreen
  /// reads this once to show a "session expired" snackbar, then clears it.
  bool _wasExpiredByServer = false;
  bool get wasExpiredByServer => _wasExpiredByServer;
  void clearExpiredFlag() => _wasExpiredByServer = false;

  @override
  AsyncValue<UserProfile?> build() {
    _sessionExpiredSub?.cancel();
    _sessionExpiredSub = sessionExpiredStream.listen((_) async {
      // _AuthInterceptor already cleared tokens in storage; update Riverpod
      // state immediately so GoRouter redirects to /login without waiting
      // for the next checkSession() (app resume / cold start).
      _wasExpiredByServer = true;
      await _clearCache();
      state = const AsyncValue.data(null);
    });
    ref.onDispose(() => _sessionExpiredSub?.cancel());
    return const AsyncValue.loading();
  }

  void restoreFromCache(UserProfile user) {
    state = AsyncValue.data(user);
  }

  Future<void> checkSession({bool backgroundRefresh = false}) async {
    if (!backgroundRefresh) state = const AsyncValue.loading();

    final storage = ref.read(secureStorageProvider);

    try {
      // Load the full token pair so we can inspect expiresAt locally and
      // avoid one unnecessary round-trip (EC3 / UC2 optimisation).
      final pair = await storage.loadTokens();

      if (pair == null) {
        // No tokens at all → not logged in. Unconditionally set data(null)
        // so the router redirects to /login regardless of backgroundRefresh.
        await _clearCache();
        state = const AsyncValue.data(null);
        return;
      }

      // If token not yet expired, try /me with it.
      if (!pair.isExpired) {
        final user = await _fetchMe(pair.accessToken);
        if (user != null) {
          await _saveCache(user);
          state = AsyncValue.data(user);
          _postLoginSideEffects();
          return;
        }
        // /me returned 401 despite non-expired token (clock skew, early revoke)
        // → fall through to refresh.
      }

      // Token is expired (or /me returned 401) → attempt silent refresh.
      try {
        final plain = Dio(BaseOptions(baseUrl: baseUrl));
        final resp = await plain.post(
          '/api/v1/auth/refresh',
          data: {'refresh_token': pair.refreshToken},
        );
        final data = resp.data as Map<String, dynamic>;
        final newPair = TokenPair.fromApiResponse(data);
        await storage.saveTokens(newPair);

        final refreshedUser = await _fetchMe(newPair.accessToken);
        if (refreshedUser != null) {
          await _saveCache(refreshedUser);
          state = AsyncValue.data(refreshedUser);
          _postLoginSideEffects();
          return;
        }
      } on DioException catch (e) {
        final isNetworkError =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.connectionError;
        if (isNetworkError) {
          rethrow; // caught by outer DioException handler → tokens stay intact
        }
        debugPrint('[auth] refresh failed: $e');
      }

      // Refresh failed or /me still returned null → clear and log out.
      // Unconditionally set data(null): tokens are dead, there is no point
      // keeping the UI in a logged-in state even during a background refresh.
      await storage.clearTokens();
      await _clearCache();
      state = const AsyncValue.data(null);
    } on DioException catch (e) {
      // H3: network errors — tokens are not compromised, do not log out.
      debugPrint('[auth] checkSession DioException: $e');
      // state is intentionally not modified for any DioException.
    } on KeychainUnavailableException catch (e) {
      // H5: Keychain locked after reboot — tokens exist but cannot be read yet.
      // Do not log out; the user will unlock the device and try again.
      debugPrint('[auth] Keychain unavailable: $e — not logging out');
    } catch (e) {
      // Unexpected error — fail-safe: do not log the user out for unknown
      // exceptions to avoid spurious logouts on transient issues.
      debugPrint('[auth] unexpected checkSession error: $e');
    }
  }

  void _postLoginSideEffects() {
    syncOnboardingPending().catchError(
      (e) {
        debugPrint('[auth] onboarding retry error: $e');
        return false;
      },
    );
    NotificationService.registerTokenAfterLogin();
    ref.read(aiConsentProvider.notifier).load();
    _syncRevenueCat();
  }

  void _syncRevenueCat() {
    final user = state.valueOrNull;
    if (user == null) return;
    // Guard against builds where `RC_IOS_KEY`/`RC_ANDROID_KEY` were not
    // provided via --dart-define. Without those, `Purchases.configure` is
    // never called in main(), and calling `logIn` then hits a Swift
    // assertionFailure in PurchasesHybridCommon which crashes the whole
    // app (EXC_BREAKPOINT). Skip silently in dev / Profile builds.
    () async {
      try {
        final configured = await Purchases.isConfigured;
        if (!configured) {
          debugPrint('[rc] skip logIn — Purchases.configure not called');
          return;
        }
        await Purchases.logIn(user.id.toString());
        ref.read(subscriptionNotifierProvider.notifier).refresh();
      } on Exception catch (e) {
        debugPrint('[rc] logIn error: $e');
      }
    }();
  }

  static Future<void> _saveCache(UserProfile user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCachedUserKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  static Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCachedUserKey);
    } catch (_) {}
  }

  Future<UserProfile?> _fetchMe(String token) async {
    try {
      final plain = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'Authorization': 'Bearer $token'},
      ));
      final resp = await plain.get('/api/v1/auth/me');
      return UserProfile.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      rethrow;
    }
  }

  Future<void> loginWithTokens(String access, String refresh) async {
    // Construct a TokenPair with unknown expiresAt → will refresh immediately.
    final pair = TokenPair(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: DateTime.now(),
    );
    final storage = ref.read(secureStorageProvider);
    await storage.saveTokens(pair);
    await checkSession();
  }

  Future<void> loginWithTokenPair(TokenPair pair) async {
    final storage = ref.read(secureStorageProvider);
    await storage.saveTokens(pair);
    await checkSession();
  }

  Future<void> refreshUser() async {
    await checkSession();
  }

  Future<void> logout() async {
    await NotificationService.unregisterToken();

    final storage = ref.read(secureStorageProvider);

    try {
      final refreshToken = await storage.loadRefreshToken();
      if (refreshToken != null) {
        // Best-effort revocation — errors are swallowed intentionally (UC8).
        await apiDio.post(
          '/api/v1/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {}

    await storage.clearTokens();
    await _clearCacheAndProgress();
    state = const AsyncValue.data(null);
  }

  Future<void> deleteAccount() async {
    // Throws on network/server error — caller must surface to user (Guideline 5.1.1v).
    await apiDio.delete('/api/v1/auth/account');
    final storage = ref.read(secureStorageProvider);
    await storage.clearTokens();
    await _clearCacheAndProgress();
    state = const AsyncValue.data(null);
  }

  /// Clears cached_user and onboarding progress keys on logout (UC8).
  /// onboarding_done is intentionally kept so the user is sent to /login
  /// instead of /onboarding on next cold start.
  static Future<void> _clearCacheAndProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_kCachedUserKey),
        prefs.remove('onboarding_answers'),
        prefs.remove('onboarding_current_step'),
      ]);
    } catch (_) {}
  }
}
