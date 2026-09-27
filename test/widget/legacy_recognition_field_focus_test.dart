import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/features/add_meal/screens/recognition_result_sheet_v2.dart';
import 'package:kayfit/shared/models/ingredient_v2.dart';
import 'package:kayfit/shared/models/nutrients_v2.dart';
import 'package:kayfit/shared/models/recognition_clarification.dart';

void main() {
  const nutrients = NutrientsV2(calories: 180, protein: 12, fat: 6, carbs: 20);
  const item = IngredientV2(
    name: 'Тестовое блюдо',
    weightGrams: 250,
    nutrientsPer100g: nutrients,
    nutrientsTotal: nutrients,
  );

  for (final scenario in <(String, Key)>[
    ('portion_mass_out_of_range', const ValueKey('legacy_weight_field')),
    ('calories_per_100g_out_of_range', const ValueKey('legacy_calories_field')),
    ('macronutrients_out_of_range', const ValueKey('legacy_protein_field')),
  ]) {
    testWidgets('legacy edit focuses ${scenario.$1}', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RecognitionResultSheetV2(
                dishName: 'Ужин',
                ingredients: const [item],
                clarification: RecognitionClarification(
                  required: true,
                  question: 'Проверьте результат',
                  options: const ['Редактировать', 'Всё верно'],
                  uncertaintyReasons: [scenario.$1],
                ),
              ),
            ),
          ),
        ),
      );
      final editButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Редактировать'),
      );
      editButton.onPressed!();
      await tester.pumpAndSettle();
      final field = find.byKey(scenario.$2);
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);
    });
  }

  for (final localeCase in <(Locale, String)>[
    (const Locale('ru'), 'Редактировать'),
    (const Locale('en'), 'Edit'),
  ]) {
    testWidgets(
      'legacy RU/EN flow edits mass, calories and all macros with taps, scroll and keyboard ${localeCase.$1.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: localeCase.$1,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: RecognitionResultSheetV2(
                  dishName: 'Meal',
                  ingredients: const [item],
                  clarification: RecognitionClarification(
                    required: true,
                    question: 'Check result',
                    options: [localeCase.$2, 'OK'],
                    uncertaintyReasons: const [
                      'macronutrients_out_of_range',
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final edit = find.widgetWithText(OutlinedButton, localeCase.$2);
        await tester.scrollUntilVisible(
          edit,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(edit);
        await tester.pumpAndSettle();

        for (final editCase in <(Key, String)>[
          (const ValueKey('legacy_weight_field'), '320'),
          (const ValueKey('legacy_calories_field'), '210'),
          (const ValueKey('legacy_protein_field'), '18'),
          (const ValueKey('legacy_fat_field'), '9'),
          (const ValueKey('legacy_carbs_field'), '24'),
        ]) {
          final field = find.byKey(editCase.$1);
          await tester.scrollUntilVisible(
            field,
            120,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(field);
          await tester.showKeyboard(field);
          await tester.enterText(field, editCase.$2);
          await tester.pump();
          expect(tester.testTextInput.isVisible, isTrue);
          expect(tester.widget<TextField>(field).controller?.text, editCase.$2);
        }

        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      },
    );
  }
}
