// Regression test for the "permanent grey screen on resume" bug.
//
// Bug: with the photo recognition result sheet open (/kf2/result), backgrounding
// the app and returning painted a permanent grey screen recoverable only by a
// force-quit. Root cause: the route builder hard-cast `state.extra as
// RecognitionResultArgs`. On resume iOS re-delivers RouteInformation, go_router
// rebuilds the route with `extra == null`, the cast threw a CastError, and the
// release ErrorWidget rendered a dead grey rectangle.
//
// Fix: the payload is stashed in `activeRecognitionResultProvider` and read from
// there first, so a route refresh re-renders the sheet. If the payload is truly
// gone the page bounces to /chat-v2 instead of crashing.
//
// These tests exercise [Kf2ResultPage] — the extracted route page — directly:
//   - provider holds args  → renders the sheet (no crash)
//   - provider null + extra null (the refresh case) → redirects to /chat-v2
//   - provider null + extra present → renders from the fallback

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kayfit/features/add_meal/screens/kf2_result_page.dart';
import 'package:kayfit/features/add_meal/screens/recognition_result_args.dart';
import 'package:kayfit/features/add_meal/screens/recognition_result_sheet_kf2.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';

RecognitionResultArgs _args() =>
    const RecognitionResultArgs(dishName: 'Test dish', items: []);

/// Builds a minimal GoRouter exposing only [Kf2ResultPage] plus a sentinel
/// `/chat-v2` route so the redirect target is observable.
GoRouter _router({RecognitionResultArgs? extraArgs}) => GoRouter(
  initialLocation: '/kf2/result',
  routes: [
    GoRoute(
      path: '/kf2/result',
      builder: (context, state) => Kf2ResultPage(extraArgs: extraArgs),
    ),
    GoRoute(
      path: '/chat-v2',
      builder: (context, state) =>
          const Scaffold(body: Text('CHAT_V2_SENTINEL')),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  GoRouter router, {
  RecognitionResultArgs? activeArgs,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (activeArgs != null)
          activeRecognitionResultProvider.overrideWith((ref) => activeArgs),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the result sheet when the provider holds args', (
    tester,
  ) async {
    await _pump(tester, _router(), activeArgs: _args());

    // The sheet builds without throwing — no grey ErrorWidget.
    expect(find.byType(RecognitionResultSheetKF2), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('CHAT_V2_SENTINEL'), findsNothing);
  });

  testWidgets(
    'redirects to /chat-v2 when the payload is lost (resume refresh case)',
    (tester) async {
      // No active result and no extra — mirrors go_router rebuilding the route
      // after the app is resumed with extra dropped.
      await _pump(tester, _router());

      expect(tester.takeException(), isNull);
      expect(find.text('CHAT_V2_SENTINEL'), findsOneWidget);
      expect(find.byType(RecognitionResultSheetKF2), findsNothing);
    },
  );

  testWidgets('falls back to extra args when the provider is empty', (
    tester,
  ) async {
    await _pump(tester, _router(extraArgs: _args()));

    expect(find.byType(RecognitionResultSheetKF2), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
