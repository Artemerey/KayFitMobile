// Regression test: BUG-1 / AUTH-EXPIRY
//
// Scenario: user sits in the app, refresh token expires on the server.
// _AuthInterceptor calls _handleLogout() → sessionExpiredStream fires →
// AuthNotifier sets state = data(null) AND wasExpiredByServer = true.
// When GoRouter redirects to /login, LoginScreen reads the flag, shows a
// "Session expired" snackbar, and calls clearExpiredFlag() so the snackbar
// does NOT repeat on subsequent visits.
//
// LoginScreen itself is not testable in isolation (Firebase / Analytics
// platform channels would hang).  These tests cover the state-machine half:
// flag lifecycle, stream → state wiring, and clear semantics.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/api/api_client.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/auth/secure_token_storage.dart';
import 'package:kayfit/core/auth/token_pair.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Minimal fake storage ──────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initApiClient(storage: _EmptyStorage());
  });

  group('BUG-1 / AUTH-EXPIRY — wasExpiredByServer flag', () {
    test('starts as false on fresh notifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(authNotifierProvider.notifier).wasExpiredByServer,
        isFalse,
      );
    });

    test('becomes true when sessionExpiredStream fires', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build the notifier so its stream subscription is active.
      container.read(authNotifierProvider.notifier);

      fireSessionExpiredForTest();
      await Future<void>.delayed(Duration.zero); // drain async listener

      expect(
        container.read(authNotifierProvider.notifier).wasExpiredByServer,
        isTrue,
        reason: 'flag must be set so LoginScreen can show the snackbar',
      );
    });

    test('AuthNotifier state becomes data(null) when stream fires', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authNotifierProvider.notifier);
      fireSessionExpiredForTest();
      await Future<void>.delayed(Duration.zero);

      // valueOrNull avoids the generic-type mismatch between
      // AsyncData<dynamic> and AsyncData<UserProfile?>.
      expect(
        container.read(authNotifierProvider).valueOrNull,
        isNull,
        reason: 'router must redirect to /login immediately without waiting '
            'for the next checkSession() call',
      );
    });

    test('clearExpiredFlag() resets flag to false', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authNotifierProvider.notifier);
      fireSessionExpiredForTest();
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(authNotifierProvider.notifier);
      expect(notifier.wasExpiredByServer, isTrue);

      notifier.clearExpiredFlag();
      expect(notifier.wasExpiredByServer, isFalse);
    });

    test('flag survives multiple reads before clear', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authNotifierProvider.notifier);
      fireSessionExpiredForTest();
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(authNotifierProvider.notifier);
      // Reading the flag must NOT clear it automatically.
      final r1 = notifier.wasExpiredByServer;
      final r2 = notifier.wasExpiredByServer;
      expect(r1 && r2, isTrue); // both reads return true
      expect(notifier.wasExpiredByServer, isTrue,
          reason: 'only clearExpiredFlag() must reset the flag — reading it '
              'must not clear it (LoginScreen reads before clearing)');
    });

    test('second stream event does not double-clear already-false flag', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(authNotifierProvider.notifier);
      fireSessionExpiredForTest();
      await Future<void>.delayed(Duration.zero);

      // LoginScreen clears the flag.
      container.read(authNotifierProvider.notifier).clearExpiredFlag();
      expect(
          container.read(authNotifierProvider.notifier).wasExpiredByServer,
          isFalse);

      // A second expiry event re-arms the flag.
      fireSessionExpiredForTest();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(authNotifierProvider.notifier).wasExpiredByServer,
        isTrue,
        reason: 'a genuine second expiry must re-arm the flag',
      );
    });
  });
}

