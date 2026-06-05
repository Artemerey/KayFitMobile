// Unit tests for `IngredientV2.needsManualEntry` — parsing and copyWith behaviour.
//
// Covers:
//   - fromApiItem with needs_manual_entry: true  → needsManualEntry == true
//   - fromApiItem without needs_manual_entry key → default false
//   - fromApiItem with needs_manual_entry: false  → needsManualEntry == false
//   - copyWith(needsManualEntry: false) flips the flag correctly
//   - fromApiItem for a zero-calorie item (early return) → needsManualEntry == false
//   - fromSuggestion (no needs_manual_entry field) → default false

import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/shared/models/ingredient_v2.dart';

// Minimal nutrients sub-map used in API payloads.
const _kNutrients = <String, dynamic>{
  'calories': 200.0,
  'protein': 10.0,
  'fat': 8.0,
  'carbs': 24.0,
};

// A regular food item payload — not on the zero-calorie whitelist.
Map<String, dynamic> _regularItem({bool? needsManualEntry}) => {
      'name': 'Chicken breast',
      'weight_grams': 150,
      'nutrients_per_100g': _kNutrients,
      'nutrients_total': _kNutrients,
      if (needsManualEntry != null) 'needs_manual_entry': needsManualEntry,
    };

// A zero-calorie item payload (name is on the whitelist).
Map<String, dynamic> _zeroCalorieItem() => {
      'name': 'water',
      'weight_grams': 250,
      'nutrients_per_100g': _kNutrients,
      'nutrients_total': _kNutrients,
      'needs_manual_entry': true, // should be ignored by the early-return path
    };

// A suggestion payload — fromSuggestion never carries needs_manual_entry.
Map<String, dynamic> _suggestionItem() => {
      'name': 'Oats',
      'nutrients_per_100g': _kNutrients,
    };

void main() {
  group('IngredientV2.needsManualEntry — fromApiItem', () {
    test('true when needs_manual_entry: true is present', () {
      final result = IngredientV2.fromApiItem(_regularItem(needsManualEntry: true));
      expect(result.needsManualEntry, isTrue);
    });

    test('false (default) when needs_manual_entry key is absent', () {
      final result = IngredientV2.fromApiItem(_regularItem());
      expect(result.needsManualEntry, isFalse);
    });

    test('false when needs_manual_entry: false is explicit', () {
      final result = IngredientV2.fromApiItem(_regularItem(needsManualEntry: false));
      expect(result.needsManualEntry, isFalse);
    });

    test('false for zero-calorie item (early return skips the field)', () {
      // The payload carries needs_manual_entry: true but the zero-calorie guard
      // returns early without reading that field — result must be false.
      final result = IngredientV2.fromApiItem(_zeroCalorieItem());
      expect(result.needsManualEntry, isFalse);
    });

    test('zero-calorie early return also zeroes out all macros', () {
      final result = IngredientV2.fromApiItem(_zeroCalorieItem());
      expect(result.nutrientsTotal.calories, 0);
      expect(result.nutrientsPer100g.calories, 0);
    });
  });

  group('IngredientV2.needsManualEntry — fromSuggestion', () {
    test('always false — suggestion items have no needs_manual_entry field', () {
      final result = IngredientV2.fromSuggestion(_suggestionItem(), 100.0);
      expect(result.needsManualEntry, isFalse);
    });
  });

  group('IngredientV2.needsManualEntry — copyWith', () {
    test('copyWith(needsManualEntry: false) clears flag on a true instance', () {
      final original = IngredientV2.fromApiItem(_regularItem(needsManualEntry: true));
      expect(original.needsManualEntry, isTrue); // precondition

      final updated = original.copyWith(needsManualEntry: false);
      expect(updated.needsManualEntry, isFalse);
    });

    test('copyWith without needsManualEntry preserves existing true value', () {
      final original = IngredientV2.fromApiItem(_regularItem(needsManualEntry: true));
      final updated = original.copyWith(weightGrams: 200.0);
      expect(updated.needsManualEntry, isTrue);
    });

    test('copyWith does not mutate the original instance', () {
      final original = IngredientV2.fromApiItem(_regularItem(needsManualEntry: true));
      original.copyWith(needsManualEntry: false);
      expect(original.needsManualEntry, isTrue);
    });
  });

  group('IngredientV2.needsManualEntry — source field unaffected', () {
    test('source is preserved correctly alongside needsManualEntry: true', () {
      final item = {
        ..._regularItem(needsManualEntry: true),
        'source': 'usda',
      };
      final result = IngredientV2.fromApiItem(item);
      expect(result.needsManualEntry, isTrue);
      expect(result.source, 'usda');
    });
  });
}
