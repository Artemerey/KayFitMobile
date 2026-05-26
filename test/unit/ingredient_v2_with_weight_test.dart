// Unit tests for `IngredientV2.withWeight` — the core macro-scaling op behind
// both inline weight pills (chat pending card, journal edit screen).
//
// Covers:
//   - macros scale linearly with weight
//   - per-100g stays untouched (it's the baseline)
//   - 0 weight gives zero totals (edge — UI guards against this but model must
//     not crash)
//   - half / double scaling produces the expected fractions
//   - extended nutrients (sodium, vitaminC) scale too when present

import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/shared/models/ingredient_v2.dart';
import 'package:kayfit/shared/models/nutrients_v2.dart';

const _per100 = NutrientsV2(
  calories: 200,
  protein: 10,
  fat: 8,
  carbs: 24,
  sodiumMg: 400,
  vitaminCMg: 12,
);

IngredientV2 _ing(double w) => IngredientV2(
      name: 'test',
      weightGrams: 100,
      nutrientsPer100g: _per100,
      nutrientsTotal: _per100,
    ).withWeight(w);

void main() {
  group('IngredientV2.withWeight', () {
    test('150g scales macros 1.5x', () {
      final r = _ing(150);
      expect(r.weightGrams, 150);
      expect(r.nutrientsTotal.calories, closeTo(300, 0.01));
      expect(r.nutrientsTotal.protein, closeTo(15, 0.01));
      expect(r.nutrientsTotal.fat, closeTo(12, 0.01));
      expect(r.nutrientsTotal.carbs, closeTo(36, 0.01));
    });

    test('50g halves the macros', () {
      final r = _ing(50);
      expect(r.nutrientsTotal.calories, closeTo(100, 0.01));
      expect(r.nutrientsTotal.protein, closeTo(5, 0.01));
      expect(r.nutrientsTotal.fat, closeTo(4, 0.01));
      expect(r.nutrientsTotal.carbs, closeTo(12, 0.01));
    });

    test('per100g is the baseline — unchanged across withWeight', () {
      final r = _ing(250);
      expect(r.nutrientsPer100g.calories, 200);
      expect(r.nutrientsPer100g.protein, 10);
      expect(r.nutrientsPer100g.fat, 8);
      expect(r.nutrientsPer100g.carbs, 24);
    });

    test('extended nutrients also scale (sodium, vitamin C)', () {
      final r = _ing(250);
      expect(r.nutrientsTotal.sodiumMg, closeTo(1000, 0.01));
      expect(r.nutrientsTotal.vitaminCMg, closeTo(30, 0.01));
    });

    test('0 weight produces zero totals without throwing', () {
      final r = _ing(0);
      expect(r.weightGrams, 0);
      expect(r.nutrientsTotal.calories, 0);
      expect(r.nutrientsTotal.protein, 0);
    });

    test('chained edits compose: 200 → 100 yields 1× baseline', () {
      final r = _ing(200).withWeight(100);
      expect(r.nutrientsTotal.calories, closeTo(200, 0.01));
      expect(r.nutrientsTotal.protein, closeTo(10, 0.01));
    });
  });
}
