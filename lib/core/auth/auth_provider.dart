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
      final pair = await storage.loadTokens();

      if (pair == null) {
        await _clearCache();
        state = const AsyncValue.data(null);
        return;
      }

      // Route /me through apiDio so _AuthInterceptor owns ALL token refreshes.
      // Previously checkSession used a plain Dio and called /refresh directly,
      // racing with the interceptor when the access token expired — both would
      // send the same refresh token simultaneously. The backend's token-reuse
      // detector treats that as theft and revokes every session for the user.
      // Using apiDio serialises the refresh via _refreshCompleter, eliminating
      // the race entirely.
      final user = await _fetchMeViaInterceptor();
      if (user != null) {
        await _saveCache(user);
        state = AsyncValue.data(user);
        _postLoginSideEffects();
        return;
      }
      // user == null → /me returned 401 and _AuthInterceptor already fired
      // sessionExpiredStream (tokens cleared). Set the terminal logged-out
      // state explicitly rather than relying on the async _sessionExpiredSub,
      // so we never return with `state` still in loading().
      state = const AsyncValue.data(null);
    } on DioException catch (e) {
      // Network errors — tokens are not compromised, do not log out.
      debugPrint('[auth] checkSession DioException: $e');
    } on KeychainUnavailableException catch (e) {
      // Keychain locked after reboot — tokens exist but cannot be read yet.
      debugPrint('[auth] Keychain unavailable: $e — not logging out');
    } catch (e) {
      // Unexpected error — fail-safe: do not log the user out.
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

  /// Reads the last cached [UserProfile] (mirror of [_saveCache] and the
  /// cold-start decode in main.dart). Used by checkSession's loading() safety
  /// net to keep a known user logged in across a transient refresh error.
  static Future<UserProfile?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_kCachedUserKey);
      if (cachedJson == null) return null;
      return UserProfile.fromJson(
        jsonDecode(cachedJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile?> _fetchMeViaInterceptor() async {
    try {
      final resp = await apiDio.get('/api/v1/auth/me');
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
    // refreshUser is the post-login foreground refresh. checkSession leaves
    // `state` in loading() on a transient network error (H3 contract — it must
    // not log a returning user out). But the GoRouter redirect freezes on
    // authNotifier.isLoading, so a stuck loading() here = infinite spinner with
    // no recovery. Resolve to the cached user (stay logged in) or logged-out so
    // navigation always proceeds.
    if (state.isLoading) {
      state = AsyncValue.data(await _loadCachedUser());
    }
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
