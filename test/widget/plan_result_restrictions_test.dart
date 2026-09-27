import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/features/way_to_goal/widgets/plan_result_view.dart';
import 'package:kayfit/shared/models/calculation_result.dart';

const _calculation = CalculationResult(
  bmr: 1400,
  tdee: 2000,
  targetCalories: 1700,
  protein: 110,
  fat: 60,
  carbs: 180,
);

Widget _app(Locale locale, List<String> restrictions) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: PlanResultView(
        calc: _calculation,
        l10n: AppLocalizations.of(context)!,
        restrictionNames: restrictions,
      ),
    ),
  ),
);

void main() {
  testWidgets('shows selected restrictions and exclusion confirmation in RU', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const Locale('ru'), const ['Глютен', 'Орехи']),
    );

    expect(find.text('Учтённые ограничения'), findsOneWidget);
    expect(find.text('Глютен'), findsOneWidget);
    expect(find.text('Орехи'), findsOneWidget);
    expect(find.textContaining('Меню будет составлено без'), findsOneWidget);
  });

  testWidgets('shows one selected restriction in EN', (tester) async {
    await tester.pumpWidget(_app(const Locale('en'), const ['Dairy']));

    expect(find.text('Your restrictions'), findsOneWidget);
    expect(find.text('Dairy'), findsOneWidget);
    expect(find.textContaining('Your menu will exclude'), findsOneWidget);
  });

  testWidgets('hides restrictions card for an empty selection', (tester) async {
    await tester.pumpWidget(_app(const Locale('en'), const []));

    expect(find.text('Your restrictions'), findsNothing);
    expect(find.textContaining('Your menu will exclude'), findsNothing);
  });

  testWidgets('plan result lets the user edit source answers', (tester) async {
    var editCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: PlanResultView(
              calc: _calculation,
              l10n: AppLocalizations.of(context)!,
              currentWeight: 75,
              onEditAnswers: () => editCount++,
            ),
          ),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Edit answers'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Edit answers'));
    await tester.pump();

    expect(editCount, 1);
  });
}
