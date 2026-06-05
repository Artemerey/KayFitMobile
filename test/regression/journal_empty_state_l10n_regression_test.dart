// Regression test: BUG-R-EMPTY — journal empty state must use l10n, not hardcoded EN.
//
// Previously _EmptyMeals widget showed 'No meals today' and 'Tap + to log your
// first meal' hardcoded in English regardless of device locale.
// Fix: replaced with AppLocalizations.of(context)!.journal_no_meals_today /
//      journal_tap_plus_to_log.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/shared/theme/kayfit2_theme.dart';
import 'package:kayfit/features/journal/screens/journal_v2_screen.dart'
    show emptyMealsWidgetForTest;

Widget _wrap(Widget child, {Locale locale = const Locale('ru')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('BUG-R-EMPTY — journal empty state is localised', () {
    testWidgets('shows Russian text when locale is ru', (tester) async {
      await tester.pumpWidget(
        _wrap(
          emptyMealsWidgetForTest(K2Theme.light),
          locale: const Locale('ru'),
        ),
      );
      await tester.pump();

      expect(find.text('Блюд за сегодня нет'), findsOneWidget);
      expect(
        find.text('Нажми + чтобы добавить первое блюдо'),
        findsOneWidget,
      );
    });

    testWidgets('shows English text when locale is en', (tester) async {
      await tester.pumpWidget(
        _wrap(
          emptyMealsWidgetForTest(K2Theme.light),
          locale: const Locale('en'),
        ),
      );
      await tester.pump();

      expect(find.text('No meals today'), findsOneWidget);
      expect(find.text('Tap + to log your first meal'), findsOneWidget);
    });

    testWidgets('never shows hardcoded Russian when locale is en', (tester) async {
      await tester.pumpWidget(
        _wrap(
          emptyMealsWidgetForTest(K2Theme.light),
          locale: const Locale('en'),
        ),
      );
      await tester.pump();

      expect(find.text('Блюд за сегодня нет'), findsNothing);
    });
  });
}
