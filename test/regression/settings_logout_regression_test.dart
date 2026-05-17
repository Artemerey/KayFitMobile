// test/regression/settings_logout_regression_test.dart
//
// Block D — Settings logout after H4 change.
//
// H4: Settings logout does NOT call any global callback.
//     It calls ref.read(authNotifierProvider.notifier).logout() directly.
//     logout() clears tokens and sets state = data(null).
//
// Uses the same _FakeAuthNotifier / _buildRouterApp / _pumpApp pattern as
// settings_v2_screen_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kayfit/core/ai_consent/ai_consent_provider.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/auth/secure_token_storage.dart';
import 'package:kayfit/core/auth/token_pair.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/core/locale/locale_provider.dart';
import 'package:kayfit/features/settings/screens/settings_v2_screen.dart';
import 'package:kayfit/shared/models/user_profile.dart';

// ─── Fakes ────────────────────────────────────────────────────────────────────

class _FakeConsentNotifier extends AiConsentNotifier {
  @override
  bool? build() => true;
}

class _FakeLocaleNotifier extends StateNotifier<Locale>
    implements LocaleNotifier {
  _FakeLocaleNotifier() : super(const Locale('en'));

  @override
  Future<void> setLocale(Locale locale) async => state = locale;
}

class _FakeAuthNotifier extends AuthNotifier {
  bool logoutCalled = false;

  @override
  AsyncValue<UserProfile?> build() => const AsyncValue.data(
        UserProfile(id: 1, email: 'test@kayfit.app', username: 'Kay'),
      );

  @override
  Future<void> logout() async {
    logoutCalled = true;
    state = const AsyncValue.data(null);
  }
}

/// Counting token storage — records how many times clearTokens was called.
class _CountingStorage implements SecureTokenStorage {
  int clearCount = 0;
  TokenPair? _pair;

  void seed(TokenPair pair) => _pair = pair;

  @override
  Future<void> saveTokens(TokenPair pair) async => _pair = pair;
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

// ─── Error suppression ────────────────────────────────────────────────────────

void Function(FlutterErrorDetails)? _savedHandler;

void _suppressFirebase() {
  _savedHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    if (msg.contains('Firebase') ||
        msg.contains('firebase') ||
        msg.contains('No Firebase App') ||
        msg.contains('DioException') ||
        msg.contains('SocketException')) {
      return;
    }
    _savedHandler?.call(details);
  };
}

void _restoreHandler() => FlutterError.onError = _savedHandler;

// ─── Widget helpers ───────────────────────────────────────────────────────────

Widget _buildRouterApp({_FakeAuthNotifier? authNotifier}) {
  final fakeAuth = authNotifier ?? _FakeAuthNotifier();

  final router = GoRouter(
    initialLocation: '/settings-v2',
    routes: [
      GoRoute(
        path: '/journal-v2',
        builder: (_, __) => const Scaffold(
            body: Center(child: Text('journal'))),
      ),
      GoRoute(
        path: '/settings/goals',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('goals'))),
      ),
      GoRoute(
        path: '/ai-consent',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('ai-consent'))),
      ),
      GoRoute(
        path: '/settings-v2',
        builder: (_, __) => const SettingsV2Screen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => fakeAuth),
      localeProvider.overrideWith((_) => _FakeLocaleNotifier()),
      aiConsentProvider.overrideWith(() => _FakeConsentNotifier()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ru')],
    ),
  );
}

Future<void> _pumpApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  tester.takeException(); // drain Firebase exception
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    _suppressFirebase();
  });
  tearDown(_restoreHandler);

  // ── D1: widget — tapping Log out calls auth.logout() ─────────────────────

  testWidgets(
    'D1 — tapping "Log out" in SettingsV2Screen calls auth.logout()',
    (tester) async {
      final fakeAuth = _FakeAuthNotifier();
      await _pumpApp(tester, _buildRouterApp(authNotifier: fakeAuth));

      await tester.scrollUntilVisible(
        find.text('Log out'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.text('Log out'));
      await tester.pump();

      expect(
        fakeAuth.logoutCalled,
        isTrue,
        reason: 'Log out button must invoke auth.logout()',
      );
    },
  );

  // ── D2: unit — logout() sets state to data(null) ─────────────────────────

  test(
    'D2 — AuthNotifier.logout() sets state to data(null)',
    () async {
      final storage = _CountingStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      container
          .read(authNotifierProvider.notifier)
          .restoreFromCache(const UserProfile(id: 7, email: 'u@test.com'));

      await container.read(authNotifierProvider.notifier).logout();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, isNull);
    },
  );

  // ── D3: unit — logout() calls clearTokens on storage ─────────────────────

  test(
    'D3 — AuthNotifier.logout() clears tokens in storage (H4)',
    () async {
      final storage = _CountingStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      container
          .read(authNotifierProvider.notifier)
          .restoreFromCache(const UserProfile(id: 7, email: 'u@test.com'));

      await container.read(authNotifierProvider.notifier).logout();

      expect(
        storage.clearCount,
        greaterThan(0),
        reason: 'logout() must call clearTokens() on the token storage',
      );
    },
  );
}
