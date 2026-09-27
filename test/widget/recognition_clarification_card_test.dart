import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/shared/models/recognition_clarification.dart';
import 'package:kayfit/shared/widgets/recognition_clarification_card.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';

void main() {
  Widget localized(Widget child, {Locale locale = const Locale('ru')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
  const clarification = RecognitionClarification(
    required: true,
    question: 'Проверьте блюдо и порцию',
    options: ['Изменить блюдо или порцию', 'Всё верно'],
    uncertaintyReasons: ['low_model_confidence'],
  );

  test('parses additive backend clarification safely', () {
    final parsed = RecognitionClarification.fromJson({
      'required': true,
      'question': 'Уточните порцию',
      'options': ['Изменить', 'Всё верно'],
      'uncertainty_reasons': ['portion_mass_out_of_range'],
    });
    expect(parsed?.required, isTrue);
    expect(parsed?.uncertaintyReasons, ['portion_mass_out_of_range']);
    expect(RecognitionClarification.fromJson(null), isNull);
  });

  testWidgets('requires an explicit edit or confirmation choice', (
    tester,
  ) async {
    var confirmed = false;
    var edited = false;
    await tester.pumpWidget(
      localized(
        RecognitionClarificationCard(
          clarification: clarification,
          confirmed: confirmed,
          onConfirm: () => confirmed = true,
          onEdit: (_) => edited = true,
        ),
      ),
    );

    expect(find.text('Проверьте блюдо и порцию'), findsOneWidget);
    await tester.tap(find.text('Всё верно'));
    expect(confirmed, isTrue);
    await tester.tap(find.text('Изменить блюдо или порцию'));
    expect(edited, isTrue);
  });

  testWidgets(
    'shows friendly reasons and requests the concrete uncertain field',
    (tester) async {
      RecognitionUncertainField? requestedField;
      await tester.pumpWidget(
        localized(
          RecognitionClarificationCard(
            clarification: const RecognitionClarification(
              required: true,
              question: 'Нужно проверить результат',
              options: ['Редактировать', 'Всё верно'],
              uncertaintyReasons: [
                'portion_mass_out_of_range',
                'energy_macros_materially_inconsistent',
              ],
            ),
            confirmed: false,
            onConfirm: () {},
            onEdit: (field) => requestedField = field,
          ),
        ),
      );

      expect(find.text('Проверьте размер порции'), findsOneWidget);
      expect(
        find.text('Калории не совпадают с составом продукта'),
        findsOneWidget,
      );
      await tester.tap(find.text('Редактировать'));
      expect(requestedField, RecognitionUncertainField.weight);
    },
  );

  testWidgets('localizes uncertainty reasons in English through ARB', (
    tester,
  ) async {
    await tester.pumpWidget(
      localized(
        RecognitionClarificationCard(
          clarification: const RecognitionClarification(
            required: true,
            question: 'Check the result',
            options: ['Edit', 'Correct'],
            uncertaintyReasons: ['portion_mass_out_of_range'],
          ),
          confirmed: false,
          onConfirm: () {},
          onEdit: (_) {},
        ),
        locale: const Locale('en'),
      ),
    );
    expect(find.text('Check the portion size'), findsOneWidget);
    expect(find.text('Проверьте размер порции'), findsNothing);
  });
}
