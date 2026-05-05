// Widget tests for SettingsV2Screen.
//
// Strategy:
//
//   • Tests 1 & 2 (top bar, back button) use a _FakeTopBar shell so
//     Firebase is never touched and no GoRouter is required.
//
//   • Tests 3, 4, 5 (goals nav, logout, delete dialog) use the real
//     SettingsV2Screen inside a minimal GoRouter app.
//     - AnalyticsService.settingsOpened() fires via addPostFrameCallback
//       (one frame after mount), so the screen mounts cleanly.
//     - After the first pump(), tester.pump() is called once more and
//       tester.takeException() drains the resulting FirebaseException.
//     - ListView items below the fold are reached with ensureVisible().
//
// All providers are overridden with hand-written fakes.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kayfit/core/ai_consent/ai_consent_provider.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/core/locale/locale_provider.dart';
import 'package:kayfit/features/settings/screens/settings_v2_screen.dart';
import 'package:kayfit/shared/models/user_profile.dart';
import 'package:kayfit/shared/theme/kayfit2_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fakes
// ─────────────────────────────────────────────────────────────────────────────

class _FakeConsentNotifier extends AiConsentNotifier {
  @override
  bool? build() => true;
}

class _FakeLocaleNotifier extends StateNotifier<Locale>
    implements LocaleNotifier {
  _FakeLocaleNotifier() : super(const Locale('en'));

  @override
  Future<void> setLocale(Locale locale) async {
    state = locale;
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  bool logoutCalled = false;
  bool deleteAccountCalled = false;

  @override
  AsyncValue<UserProfile?> build() {
    return const AsyncValue.data(
      UserProfile(
        id: 1,
        email: 'test@kayfit.app',
        username: 'Kay',
      ),
    );
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalled = true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error suppression
// ─────────────────────────────────────────────────────────────────────────────

void Function(FlutterErrorDetails)? _savedHandler;

void _suppressFirebase() {
  _savedHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    if (msg.contains('Firebase') ||
        msg.contains('firebase') ||
        msg.contains('No Firebase App') ||
        msg.contains('FirebaseException') ||
        msg.contains('DioException') ||
        msg.contains('SocketException')) {
      return;
    }
    _savedHandler?.call(details);
  };
}

void _restoreHandler() => FlutterError.onError = _savedHandler;

// ─────────────────────────────────────────────────────────────────────────────
// _FakeTopBar — mirrors _TopBar from SettingsV2Screen for isolated unit tests.
// Using a Scaffold prevents the Stack from being clipped at (0,0).
// ─────────────────────────────────────────────────────────────────────────────

class _TopBarShell extends StatelessWidget {
  const _TopBarShell({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const t = K2Theme.light;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(
          bottom: BorderSide(color: t.hairline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('settings_v2_back'),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
            ),
            onPressed: onBack,
          ),
          const Expanded(
            child: Center(
              child: Text(
                'settings',
                key: Key('settings_v2_title'),
                style: TextStyle(
                  fontFamily: K2Fonts.sans,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Router app — wraps real SettingsV2Screen for integration-style tests
// ─────────────────────────────────────────────────────────────────────────────

Widget _buildRouterApp({_FakeAuthNotifier? authNotifier}) {
  final fakeAuth = authNotifier ?? _FakeAuthNotifier();

  final router = GoRouter(
    initialLocation: '/settings-v2',
    routes: [
      GoRoute(
        path: '/journal-v2',
        builder: (_, __) => Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => ctx.push('/settings-v2'),
              child: const Text('open settings'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings/goals',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('goals screen'))),
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

/// Pump the router app, drain the post-frame Firebase exception, then pump
/// once more so the final frame is clean.
Future<void> _pumpApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  // First pump — screen mounts; addPostFrameCallback schedules analytics.
  await tester.pump();
  // Second pump — postFrameCallback fires, Firebase error is thrown.
  await tester.pump(const Duration(milliseconds: 50));
  // Drain the FirebaseException before any assertions.
  tester.takeException();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    _suppressFirebase();
  });

  tearDown(_restoreHandler);

  // ── 1. Top bar title ────────────────────────────────────────────────────────

  group('SettingsV2Screen — top bar', () {
    testWidgets('renders_title — top bar shows "settings" label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [_TopBarShell(onBack: () {})],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('settings_v2_title')), findsOneWidget);
      expect(find.text('settings'), findsOneWidget);
    });

    testWidgets('renders_back_icon — back arrow icon is present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [_TopBarShell(onBack: () {})],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    });
  });

  // ── 2. Back button pops navigator ───────────────────────────────────────────

  group('SettingsV2Screen — back navigation', () {
    testWidgets('back_button_fires_callback — onBack is called when tapped',
        (tester) async {
      var backCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [_TopBarShell(onBack: () => backCalled = true)],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('settings_v2_back')));
      await tester.pump();

      expect(backCalled, isTrue);
    });

    testWidgets(
        'back_button_router — tapping back from pushed /settings-v2 returns to previous route',
        (tester) async {
      // Start on /journal-v2 so /settings-v2 is pushed (canPop = true).
      final router = GoRouter(
        initialLocation: '/journal-v2',
        routes: [
          GoRoute(
            path: '/journal-v2',
            builder: (_, __) => Builder(
              builder: (ctx) => Scaffold(
                body: TextButton(
                  onPressed: () => ctx.push('/settings-v2'),
                  child: const Text('open settings'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/settings-v2',
            builder: (_, __) => const SettingsV2Screen(),
          ),
          GoRoute(
            path: '/settings/goals',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('goals screen'))),
          ),
          GoRoute(
            path: '/ai-consent',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('ai-consent'))),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
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
        ),
      );

      // Open /settings-v2.
      await tester.tap(find.text('open settings'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Confirm settings screen is on top.
      expect(find.byKey(const Key('settings_v2_back')), findsOneWidget);

      // Tap back.
      await tester.tap(find.byKey(const Key('settings_v2_back')));
      await tester.pumpAndSettle();

      // Back on journal.
      expect(find.text('open settings'), findsOneWidget);
    });
  });

  // ── 3. Goal & macros row navigates to /settings/goals ───────────────────────

  group('SettingsV2Screen — goals row', () {
    testWidgets(
        'goals_row_navigation — tapping Macro goals navigates to /settings/goals',
        (tester) async {
      await _pumpApp(tester, _buildRouterApp());

      await tester.tap(find.text('Macro goals'));
      await tester.pumpAndSettle();

      expect(find.text('goals screen'), findsOneWidget);
    });
  });

  // ── 4. Sign out calls auth.logout ───────────────────────────────────────────

  group('SettingsV2Screen — sign out', () {
    testWidgets(
        'logout_calls_auth — auth.logout() is called when Log out is tapped',
        (tester) async {
      final fakeAuth = _FakeAuthNotifier();
      await _pumpApp(tester, _buildRouterApp(authNotifier: fakeAuth));

      // Scroll down to the Log out row.
      await tester.scrollUntilVisible(
        find.text('Log out'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.text('Log out'));
      await tester.pump();

      expect(fakeAuth.logoutCalled, isTrue);
    });
  });

  // ── 5. Delete account opens confirm dialog ──────────────────────────────────

  group('SettingsV2Screen — delete account', () {
    testWidgets(
        'delete_dialog_opens — tapping Delete account shows confirm dialog',
        (tester) async {
      await _pumpApp(tester, _buildRouterApp());

      await tester.scrollUntilVisible(
        find.text('Delete account'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.text('Delete account'));
      await tester.pump();

      expect(find.text('Delete account?'), findsOneWidget);
    });

    testWidgets(
        'delete_dialog_cancel — Cancel closes dialog without deleting',
        (tester) async {
      final fakeAuth = _FakeAuthNotifier();
      await _pumpApp(tester, _buildRouterApp(authNotifier: fakeAuth));

      await tester.scrollUntilVisible(
        find.text('Delete account'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.text('Delete account'));
      await tester.pump();

      expect(find.text('Delete account?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(fakeAuth.deleteAccountCalled, isFalse);
      expect(find.text('Delete account?'), findsNothing);
    });
  });
}
