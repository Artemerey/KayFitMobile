// test/regression/router_auth_regression_test.dart
//
// Block A — Router redirect logic after H1/H4/H6 changes.
//
// _RouterNotifier.redirect() is private — we replicate its logic as a pure
// function _redirectFor() (same pattern as app_lifecycle_resume_test.dart).
// This avoids Firebase initialisation issues with the real routerProvider.
//
// Hypotheses under test:
//   H1 — authNotifierProvider is NotifierProvider (not AutoDispose).
//   H6 — isLoggedIn = auth.value != null. data(null) → not logged in.
//   H4 — declined consent (false) does NOT redirect to /ai-consent.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/auth/secure_token_storage.dart';
import 'package:kayfit/core/auth/token_pair.dart';
import 'package:kayfit/shared/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Replicated redirect logic ────────────────────────────────────────────────
// Matches router.dart _RouterNotifier.redirect() exactly.
// Feature flags are set to their production defaults (KF2_JOURNAL=true).

String? _redirectFor({
  required AsyncValue<UserProfile?> auth,
  required bool onboardingDone,
  required bool? aiConsent,
  required String loc,
  bool showWayToGoal = false,
}) {
  if (auth.isLoading) return null;

  final isLoggedIn = auth.value != null; // H6: value==null → false

  const kfJournal = true; // KF2_JOURNAL default
  const kfChat = true; // KF2_CHAT default

  final isPublic = loc == '/login' ||
      loc == '/email-auth' ||
      loc == '/onboarding' ||
      loc == '/way-to-goal' ||
      loc == '/ai-consent' ||
      loc == '/kayfit2/preview';

  if (!isLoggedIn) {
    if (isPublic) return null;
    return onboardingDone ? '/login' : '/onboarding';
  }

  // Logged in
  if (loc == '/login' || loc == '/email-auth' || loc == '/onboarding') {
    return kfJournal ? '/journal-v2' : '/';
  }

  if (showWayToGoal && loc != '/way-to-goal') {
    return '/way-to-goal';
  }

  if (kfJournal && loc == '/') {
    return '/journal-v2';
  }

  if (kfChat && loc == '/chat') {
    return '/chat-v2';
  }

  if (kfJournal && loc == '/settings') {
    return '/settings-v2';
  }

  // AI consent: only null triggers redirect (H4: declined=false passes through)
  if (isLoggedIn &&
      aiConsent == null &&
      !showWayToGoal &&
      loc != '/ai-consent' &&
      loc != '/way-to-goal' &&
      loc != '/kayfit2/preview') {
    return '/ai-consent';
  }

  return null;
}

// ─── Fake storage ─────────────────────────────────────────────────────────────

class _EmptyStorage implements SecureTokenStorage {
  @override
  Future<void> saveTokens(TokenPair pair) async {}
  @override
  Future<TokenPair?> loadTokens() async => null;
  @override
  Future<String?> loadAccessToken() async => null;
  @override
  Future<String?> loadRefreshToken() async => null;
  @override
  Future<void> clearTokens() async {}
}

// ─── Constants ────────────────────────────────────────────────────────────────

const _user = UserProfile(id: 1, email: 'test@kayfit.app');

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── A1: data(null) redirects correctly ───────────────────────────────────

  group('A1 — data(null) = not logged in', () {
    test('data(null) + onboardingDone + /journal-v2 → /login', () {
      final result = _redirectFor(
        auth: const AsyncValue.data(null),
        onboardingDone: true,
        aiConsent: null,
        loc: '/journal-v2',
      );
      expect(result, equals('/login'));
    });

    test('data(null) + onboarding NOT done + /journal-v2 → /onboarding', () {
      final result = _redirectFor(
        auth: const AsyncValue.data(null),
        onboardingDone: false,
        aiConsent: null,
        loc: '/journal-v2',
      );
      expect(result, equals('/onboarding'));
    });

    test('data(null) + onboardingDone + /login (public page) → null', () {
      final result = _redirectFor(
        auth: const AsyncValue.data(null),
        onboardingDone: true,
        aiConsent: null,
        loc: '/login',
      );
      expect(result, isNull);
    });
  });

  // ── A2: logged-in + consent=true/false → no redirect to /ai-consent ──────

  group('A2 — declined consent does NOT redirect (H4)', () {
    test('data(user) + consent=true + /journal-v2 → null', () {
      final result = _redirectFor(
        auth: const AsyncValue.data(_user),
        onboardingDone: true,
        aiConsent: true,
        loc: '/journal-v2',
      );
      expect(result, isNull);
    });

    test('data(user) + consent=false (declined) + /journal-v2 → null', () {
      // H4: declined users must NOT be redirected to /ai-consent.
      final result = _redirectFor(
        auth: const AsyncValue.data(_user),
        onboardingDone: true,
        aiConsent: false,
        loc: '/journal-v2',
      );
      expect(result, isNull);
    });
  });

  // ── A3: loading state → no redirect ──────────────────────────────────────

  group('A3 — loading state produces no redirect', () {
    test('AsyncValue.loading() → null (router waits)', () {
      final result = _redirectFor(
        auth: const AsyncValue.loading(),
        onboardingDone: true,
        aiConsent: null,
        loc: '/journal-v2',
      );
      expect(result, isNull);
    });
  });

  // ── A4: logout → state becomes data(null) → router redirects ─────────────

  group('A4 — logout changes state to data(null)', () {
    test('after logout() state is AsyncData(null)', () async {
      final storage = _EmptyStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      // Set a logged-in user first.
      container
          .read(authNotifierProvider.notifier)
          .restoreFromCache(_user);
      expect(container.read(authNotifierProvider).value, equals(_user));

      // Call logout — internal POST and NotificationService errors are swallowed.
      await container.read(authNotifierProvider.notifier).logout();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, isNull);
    });

    test('data(null) after logout → redirect goes to /login', () async {
      final storage = _EmptyStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      container
          .read(authNotifierProvider.notifier)
          .restoreFromCache(_user);
      await container.read(authNotifierProvider.notifier).logout();

      final postLogoutState = container.read(authNotifierProvider);
      final redirect = _redirectFor(
        auth: postLogoutState,
        onboardingDone: true,
        aiConsent: null,
        loc: '/journal-v2',
      );
      expect(redirect, equals('/login'));
    });
  });

  // ── A5: authNotifierProvider.value semantics (H1 / H6) ───────────────────

  group('A5 — authNotifier.value semantics', () {
    test('value is non-null after restoreFromCache', () {
      final storage = _EmptyStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      container
          .read(authNotifierProvider.notifier)
          .restoreFromCache(_user);
      expect(container.read(authNotifierProvider).value, isNotNull);
    });

    test('value is null after checkSession with empty storage (H6)', () async {
      final storage = _EmptyStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .checkSession(backgroundRefresh: true);

      expect(container.read(authNotifierProvider).value, isNull);
    });
  });
}
