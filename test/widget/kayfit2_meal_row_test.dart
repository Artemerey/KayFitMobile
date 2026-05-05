// Widget tests for KF2-FOUND-4: Kayfit2MealRow + Kayfit2MealPhoto.
//
// Covers:
//   - Photo row renders thumbnail widget (Kayfit2MealPhoto)
//   - Non-photo rows render time + source label column
//   - Kcal value is displayed in all rows
//   - Meal name is displayed
//   - onTap fires when row is tapped
//   - Kayfit2MealPhoto renders for each seed variant (0, 1, 2, 7)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/shared/models/k2_meal_row_data.dart';
import 'package:kayfit/shared/theme/kayfit2_theme.dart';
import 'package:kayfit/shared/widgets/kayfit2_meal_photo.dart';
import 'package:kayfit/shared/widgets/kayfit2_meal_row.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Wraps a widget in a minimal MaterialApp so Text/InkWell resolve their
/// inherited widget requirements.
Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

const _light = K2Theme.light;

K2MealRowData _photoMeal({int seed = 1}) => K2MealRowData(
      id: 'p1',
      time: '08:24',
      type: 'breakfast',
      name: 'oatmeal with berries',
      kcal: 320,
      protein: 12,
      fat: 6,
      carbs: 54,
      source: K2MealSource.photo,
      photoSeed: seed,
    );

const _voiceMeal = K2MealRowData(
  id: 'v1',
  time: '13:10',
  type: 'lunch',
  name: 'chicken bowl, rice, broccoli',
  kcal: 540,
  protein: 42,
  fat: 14,
  carbs: 58,
  source: K2MealSource.voice,
);

const _textMeal = K2MealRowData(
  id: 't1',
  time: '16:30',
  type: 'snack',
  name: 'greek yogurt, almonds',
  kcal: 210,
  protein: 18,
  fat: 11,
  carbs: 9,
  source: K2MealSource.text,
);

const _barcodeMeal = K2MealRowData(
  id: 'b1',
  time: '09:00',
  type: 'snack',
  name: 'protein bar',
  kcal: 180,
  protein: 20,
  fat: 5,
  carbs: 18,
  source: K2MealSource.barcode,
);

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  // ── Kayfit2MealPhoto ──────────────────────────────────────────────────────

  group('Kayfit2MealPhoto', () {
    for (final seed in [0, 1, 2, 7]) {
      testWidgets('renders without error for seed $seed', (tester) async {
        await tester.pumpWidget(
          _wrap(Kayfit2MealPhoto(seed: seed, theme: _light)),
        );
        expect(find.byType(Kayfit2MealPhoto), findsOneWidget);
      });
    }

    testWidgets('respects custom size', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealPhoto(seed: 1, theme: _light, size: 80)),
      );

      final sizedBox = tester.widget<SizedBox>(
        find
            .descendant(
              of: find.byType(Kayfit2MealPhoto),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sizedBox.width, 80);
      expect(sizedBox.height, 80);
    });

    testWidgets('shows camera icon', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealPhoto(seed: 0, theme: _light)),
      );
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    });
  });

  // ── Kayfit2MealRow — photo row ────────────────────────────────────────────

  group('Kayfit2MealRow photo row', () {
    testWidgets('renders Kayfit2MealPhoto thumbnail', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealRow(meal: _photoMeal(), theme: _light)),
      );
      expect(find.byType(Kayfit2MealPhoto), findsOneWidget);
    });

    testWidgets('displays meal name', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealRow(meal: _photoMeal(), theme: _light)),
      );
      expect(find.text('oatmeal with berries'), findsOneWidget);
    });

    testWidgets('displays kcal value', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealRow(meal: _photoMeal(), theme: _light)),
      );
      expect(find.text('320'), findsOneWidget);
    });

    testWidgets('displays time next to type when hasPhoto', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealRow(meal: _photoMeal(), theme: _light)),
      );
      expect(find.textContaining('08:24'), findsOneWidget);
    });

    testWidgets('does not show standalone PHOTO label', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealRow(meal: _photoMeal(), theme: _light)),
      );
      // source label column should not appear when thumbnail is shown
      expect(find.text('PHOTO'), findsNothing);
    });
  });

  // ── Kayfit2MealRow — non-photo rows ──────────────────────────────────────

  group('Kayfit2MealRow non-photo rows', () {
    final cases = [
      (_voiceMeal, 'VOICE', '540', 'chicken bowl, rice, broccoli'),
      (_textMeal, 'TEXT', '210', 'greek yogurt, almonds'),
      (_barcodeMeal, 'SCAN', '180', 'protein bar'),
    ];

    for (final tc in cases) {
      final meal = tc.$1;
      final label = tc.$2;
      final kcal = tc.$3;
      final name = tc.$4;

      testWidgets('${meal.source.name}: shows source label $label',
          (tester) async {
        await tester.pumpWidget(
          _wrap(Kayfit2MealRow(meal: meal, theme: _light)),
        );
        expect(find.text(label), findsOneWidget);
      });

      testWidgets('${meal.source.name}: shows kcal $kcal', (tester) async {
        await tester.pumpWidget(
          _wrap(Kayfit2MealRow(meal: meal, theme: _light)),
        );
        expect(find.text(kcal), findsOneWidget);
      });

      testWidgets('${meal.source.name}: shows name', (tester) async {
        await tester.pumpWidget(
          _wrap(Kayfit2MealRow(meal: meal, theme: _light)),
        );
        expect(find.text(name), findsOneWidget);
      });

      testWidgets('${meal.source.name}: no photo thumbnail', (tester) async {
        await tester.pumpWidget(
          _wrap(Kayfit2MealRow(meal: meal, theme: _light)),
        );
        expect(find.byType(Kayfit2MealPhoto), findsNothing);
      });
    }
  });

  // ── Kayfit2MealRow — onTap ────────────────────────────────────────────────

  group('Kayfit2MealRow tap interaction', () {
    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          Kayfit2MealRow(
            meal: _voiceMeal,
            theme: _light,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.byType(Kayfit2MealRow));
      expect(tapped, isTrue);
    });

    testWidgets('does not throw when onTap is null', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealRow(meal: _voiceMeal, theme: _light)),
      );
      await tester.tap(find.byType(Kayfit2MealRow));
      // no exception expected — tap is silently absorbed
    });
  });

  // ── Kayfit2MealRow — dense mode ───────────────────────────────────────────

  group('Kayfit2MealRow dense mode', () {
    testWidgets('renders in dense mode without error', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealRow(meal: _voiceMeal, theme: _light, dense: true)),
      );
      expect(find.byType(Kayfit2MealRow), findsOneWidget);
    });
  });

  // ── Kayfit2MealRow — dark theme ───────────────────────────────────────────

  group('Kayfit2MealRow dark theme', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        _wrap(Kayfit2MealRow(meal: _photoMeal(seed: 2), theme: K2Theme.dark)),
      );
      expect(find.byType(Kayfit2MealRow), findsOneWidget);
      expect(find.byType(Kayfit2MealPhoto), findsOneWidget);
    });
  });
}
