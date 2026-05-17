// test/regression/ai_consent_regression_test.dart
//
// Block C — AiConsentScreen logout behaviour after H4 change.
//
// H4: decline flow does NOT call logout().
//     Only a 401 from the server during setConsent triggers _handleSessionExpired
//     (which calls logout internally).
//
// Uses the same _wrap() pattern as ai_consent_screen_test.dart.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kayfit/core/ai_consent/ai_consent_provider.dart';
import 'package:kayfit/core/auth/auth_provider.dart';
import 'package:kayfit/core/navigation/navigation_providers.dart';
import 'package:kayfit/features/ai_consent/screens/ai_consent_screen.dart';
import 'package:kayfit/shared/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Fake notifiers ───────────────────────────────────────────────────────────

/// Consent notifier that stores consent without network.
class _FakeConsentNotifier extends AiConsentNotifier {
  @override
  bool? build() => null;

  @override
  Future<void> setConsent(bool value) async => state = value;
}

/// Consent notifier that throws a 401 DioException on setConsent(true).
/// Simulates an expired session detected server-side during Accept.
class _UnauthorisedConsentNotifier extends AiConsentNotifier {
  @override
  bool? build() => null;

  @override
  Future<void> setConsent(bool value) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/api/user/ai_consent'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/user/ai_consent'),
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

/// AuthNotifier that records logout() calls.
class _RecordingAuthNotifier extends AuthNotifier {
  bool logoutCalled = false;

  @override
  AsyncValue<UserProfile?> build() =>
      const AsyncValue.data(UserProfile(id: 1, email: 'reg@test.com'));

  @override
  Future<void> logout() async {
    logoutCalled = true;
    state = const AsyncValue.data(null);
  }
}

// ─── Widget helpers ───────────────────────────────────────────────────────────

Widget _wrap({
  required AiConsentNotifier consent,
  required _RecordingAuthNotifier auth,
}) {
  final router = GoRouter(
    initialLocation: '/consent',
    routes: [
      GoRoute(
        path: '/consent',
        builder: (_, __) => const AiConsentScreen(),
      ),
      GoRoute(path: '/', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/login', builder: (_, __) => const SizedBox()),
      GoRoute(path: '/onboarding', builder: (_, __) => const SizedBox()),
    ],
  );

  return ProviderScope(
    overrides: [
      aiConsentProvider.overrideWith(() => consent),
      authNotifierProvider.overrideWith(() => auth),
      consentFromOnboardingProvider.overrideWith((ref) => false),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

const _kCheckbox = Key('consent_checkbox');
const _kAccept = Key('accept_inkwell');

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── C1: Decline → dialog → confirm → logout NOT called ───────────────────

  testWidgets(
    'C1 — tapping Decline + confirming dialog does NOT call logout (H4)',
    (tester) async {
      final auth = _RecordingAuthNotifier();
      final consent = _FakeConsentNotifier();

      await _pump(tester, _wrap(consent: consent, auth: auth));

      // Scroll to Decline button and tap.
      await tester.scrollUntilVisible(
        find.text('Decline'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Decline'));
      await tester.pump(); // open dialog

      // Confirm in the dialog — find "Decline" inside AlertDialog specifically.
      final declineInDialog = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Decline'),
      );
      expect(declineInDialog, findsOneWidget);
      await tester.tap(declineInDialog);
      await tester.pumpAndSettle();

      // H4: logout must NOT have been called.
      expect(
        auth.logoutCalled,
        isFalse,
        reason: 'Decline must not log the user out (H4)',
      );
    },
  );

  // ── C2: Accept success → logout NOT called ───────────────────────────────

  testWidgets(
    'C2 — successful Accept does NOT call logout',
    (tester) async {
      final auth = _RecordingAuthNotifier();
      final consent = _FakeConsentNotifier();

      await _pump(tester, _wrap(consent: consent, auth: auth));

      // Enable checkbox.
      await tester.ensureVisible(find.byKey(_kCheckbox));
      await tester.tap(find.byKey(_kCheckbox));
      await tester.pump();

      // Tap Accept & Continue.
      await tester.ensureVisible(find.byKey(_kAccept));
      await tester.tap(find.byKey(_kAccept));
      await tester.pumpAndSettle();

      expect(
        auth.logoutCalled,
        isFalse,
        reason: 'Successful accept must not log the user out',
      );
    },
  );

  // ── C3: Accept + server 401 → logout IS called ───────────────────────────

  testWidgets(
    'C3 — Accept with server 401 triggers logout via _handleSessionExpired',
    (tester) async {
      final auth = _RecordingAuthNotifier();
      final consent = _UnauthorisedConsentNotifier();

      await _pump(tester, _wrap(consent: consent, auth: auth));

      // Enable checkbox.
      await tester.ensureVisible(find.byKey(_kCheckbox));
      await tester.tap(find.byKey(_kCheckbox));
      await tester.pump();

      // Tap Accept & Continue — consent throws 401.
      await tester.ensureVisible(find.byKey(_kAccept));
      await tester.tap(find.byKey(_kAccept));
      await tester.pumpAndSettle();

      expect(
        auth.logoutCalled,
        isTrue,
        reason: 'Server 401 on setConsent must call logout()',
      );
    },
  );
}
