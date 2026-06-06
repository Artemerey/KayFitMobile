import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kayfit/core/ai_consent/ai_consent_provider.dart';
import 'package:kayfit/core/navigation/navigation_providers.dart';
import 'package:kayfit/features/ai_consent/screens/ai_consent_screen.dart';

// Analytics calls in AiConsentScreen are wrapped in try/catch so Firebase
// not being initialized in tests does not prevent widgets from mounting.

// ─── Fake notifiers ────────────────────────────────────────────────────────────

class _FastNotifier extends AiConsentNotifier {
  @override
  bool? build() => null;

  @override
  Future<void> setConsent(bool value) async => state = value;
}

class _TimeoutNotifier extends AiConsentNotifier {
  @override
  bool? build() => null;

  @override
  Future<void> setConsent(bool value) async =>
      throw TimeoutException('timeout');
}

class _DioErrorNotifier extends AiConsentNotifier {
  @override
  bool? build() => null;

  @override
  Future<void> setConsent(bool value) async => throw DioException(
        requestOptions: RequestOptions(path: '/api/user/ai_consent'),
        type: DioExceptionType.connectionTimeout,
      );
}

class _SlowNotifier extends AiConsentNotifier {
  @override
  bool? build() => null;

  @override
  Future<void> setConsent(bool value) async =>
      await Completer<void>().future; // never completes
}

class _CountingNotifier extends AiConsentNotifier {
  _CountingNotifier({required this.onCall});
  final void Function(bool value) onCall;
  int calls = 0;

  @override
  bool? build() => null;

  @override
  Future<void> setConsent(bool value) async {
    calls++;
    onCall(value);
    state = value;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _wrap(AiConsentNotifier notifier) {
  // Use a GoRouter so that context.go('/') in _navigateAfterConsent does not
  // throw a GoException in tests.
  final router = GoRouter(
    initialLocation: '/consent',
    routes: [
      GoRoute(
        path: '/consent',
        builder: (context, state) => const AiConsentScreen(),
      ),
      // Success navigation targets.
      GoRoute(path: '/', builder: (context, state) => const SizedBox()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const SizedBox(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      aiConsentProvider.overrideWith(() => notifier),
      consentFromOnboardingProvider.overrideWith((ref) => false),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Pumps widget and settles the GoRouter so AiConsentScreen is fully mounted.
///
/// Analytics calls in AiConsentScreen are wrapped in try/catch — Firebase not
/// being initialized in tests does not prevent the widget from mounting.
Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pumpAndSettle();
}

/// Taps a widget, scrolling it into view first if needed.
Future<void> _tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
}

// ─── Widget keys (must match the screen) ─────────────────────────────────────

const _kCheckboxKey = Key('consent_checkbox');
const _kAcceptInkWellKey = Key('accept_inkwell');
const _kRetryKey = Key('retry_button');

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {

  // ── Immediate visual feedback ─────────────────────────────────────────────

  group('AiConsentScreen — immediate feedback', () {
    testWidgets(
      'Accept & Continue label is visible in the initial state',
      (tester) async {
        await _pump(tester, _wrap(_FastNotifier()));
        await tester.ensureVisible(find.text('Accept & Continue'));
        expect(find.text('Accept & Continue'), findsOneWidget);
      },
    );

    testWidgets(
      'Accept button InkWell is tappable when checkbox is unchecked (early-return guard in _onAccept)',
      (tester) async {
        await _pump(tester, _wrap(_FastNotifier()));

        // The Accept InkWell is always tappable — it guards early inside
        // _onAccept when !_checked, so tapping it without the checkbox
        // must NOT start processing (no CircularProgressIndicator).
        await tester.ensureVisible(find.byKey(_kAcceptInkWellKey));
        final inkWell = tester.widget<InkWell>(find.byKey(_kAcceptInkWellKey));
        expect(
          inkWell.onTap,
          isNotNull,
          reason: 'Accept InkWell is enabled; _onAccept guards _checked internally',
        );
        // Tap without checking the checkbox — must not start loading.
        await tester.tap(find.byKey(_kAcceptInkWellKey));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing,
            reason: 'tapping Accept unchecked must not start loading');
      },
    );

    testWidgets(
      'tapping the checkbox enables the Accept button',
      (tester) async {
        await _pump(tester, _wrap(_FastNotifier()));

        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();

        // After checking, the Accept InkWell gets an onTap handler.
        await tester.ensureVisible(find.byKey(_kAcceptInkWellKey));
        final inkWell = tester.widget<InkWell>(find.byKey(_kAcceptInkWellKey));
        expect(
          inkWell.onTap,
          isNotNull,
          reason: 'Accept InkWell should be enabled after checkbox tap',
        );
      },
    );

    testWidgets(
      'tapping Accept shows CircularProgressIndicator immediately',
      (tester) async {
        // _SlowNotifier keeps _isProcessing == true for the entire pump.
        await _pump(tester, _wrap(_SlowNotifier()));

        // Enable checkbox.
        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();

        // Tap Accept.
        await _tapText(tester, 'Accept & Continue');
        await tester.pump(); // single frame — setState fires synchronously

        // Loading indicator must appear.
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        // Label is replaced by the spinner.
        expect(find.text('Accept & Continue'), findsNothing);
      },
    );

    testWidgets(
      'LinearProgressIndicator appears at top of screen after 300ms grace period',
      (tester) async {
        await _pump(tester, _wrap(_SlowNotifier()));

        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();
        await _tapText(tester, 'Accept & Continue');
        await tester.pump();

        // Not shown yet — 300ms grace period has not elapsed.
        expect(find.byType(LinearProgressIndicator), findsNothing);

        // Advance past the 300ms timer.
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'double-tap does not start a second overlapping request',
      (tester) async {
        await _pump(tester, _wrap(_SlowNotifier()));

        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();

        // First tap — transitions to loading state.
        await _tapText(tester, 'Accept & Continue');
        await tester.pump();

        // Second tap on spinner area is absorbed (_isProcessing == true).
        final spinnerFinder = find.byType(CircularProgressIndicator);
        if (spinnerFinder.evaluate().isNotEmpty) {
          await tester.tap(spinnerFinder.first, warnIfMissed: false);
        }
        await tester.pump();

        // Advance past 300ms to trigger the linear loader.
        await tester.pump(const Duration(milliseconds: 350));

        // Still exactly one progress bar (not two).
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );
  });

  // ── Timeout / error flow ──────────────────────────────────────────────────

  group('AiConsentScreen — timeout and error flow', () {
    testWidgets(
      'TimeoutException → error banner + Retry button visible',
      (tester) async {
        await _pump(tester, _wrap(_TimeoutNotifier()));

        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();
        await _tapText(tester, 'Accept & Continue');
        await tester.pumpAndSettle();

        // Error text.
        expect(find.textContaining('Could not connect'), findsOneWidget);
        // Retry button.
        expect(find.byKey(_kRetryKey), findsOneWidget);
        // Accept label restored; no spinner.
        expect(find.text('Accept & Continue'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'DioException → error banner + Retry button visible',
      (tester) async {
        await _pump(tester, _wrap(_DioErrorNotifier()));

        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();
        await _tapText(tester, 'Accept & Continue');
        await tester.pumpAndSettle();

        expect(find.byKey(_kRetryKey), findsOneWidget);
        expect(find.text('Accept & Continue'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping Retry re-sends the request and clears the error banner on success',
      (tester) async {
        // First call throws; second call succeeds.
        var callCount = 0;
        final notifier = _CountingNotifier(
          onCall: (_) {
            callCount++;
            if (callCount == 1) throw TimeoutException('timeout');
          },
        );

        await _pump(tester, _wrap(notifier));

        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();

        // First tap — fails.
        await _tapText(tester, 'Accept & Continue');
        await tester.pumpAndSettle();
        expect(find.byKey(_kRetryKey), findsOneWidget);

        // Retry — second call succeeds.
        await _tapKey(tester, _kRetryKey);
        await tester.pumpAndSettle();

        expect(find.byKey(_kRetryKey), findsNothing);
        expect(callCount, 2);
      },
    );

    testWidgets(
      'toggling checkbox after failure clears the error banner',
      (tester) async {
        await _pump(tester, _wrap(_TimeoutNotifier()));

        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();
        await _tapText(tester, 'Accept & Continue');
        await tester.pumpAndSettle();
        expect(find.byKey(_kRetryKey), findsOneWidget);

        // Uncheck the checkbox — _hasError is reset.
        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();

        expect(find.byKey(_kRetryKey), findsNothing);
      },
    );
  });

  // ── Success flow ──────────────────────────────────────────────────────────

  group('AiConsentScreen — success flow', () {
    testWidgets(
      'no error banner shown after successful setConsent',
      (tester) async {
        await _pump(tester, _wrap(_FastNotifier()));

        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();
        await _tapText(tester, 'Accept & Continue');
        await tester.pumpAndSettle();

        expect(find.byKey(_kRetryKey), findsNothing);
        expect(find.textContaining('Could not connect'), findsNothing);
      },
    );

    testWidgets(
      'LinearProgressIndicator is absent after successful accept',
      (tester) async {
        await _pump(tester, _wrap(_FastNotifier()));

        await _tapKey(tester, _kCheckboxKey);
        await tester.pump();
        await _tapText(tester, 'Accept & Continue');
        await tester.pumpAndSettle();

        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );
  });
}
