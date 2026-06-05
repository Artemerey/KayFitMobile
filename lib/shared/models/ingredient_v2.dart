import '../utils/zero_calorie_whitelist.dart';
import 'nutrients_v2.dart';

/// A food item returned by the v2 recognition / parse endpoints.
///
/// Not a freezed model because we parse it manually from the nested
/// `nutrients_per_100g` / `nutrients_total` structure.
class IngredientV2 {
  final String name;
  final double weightGrams;
  final NutrientsV2 nutrientsPer100g;
  final NutrientsV2 nutrientsTotal;
  final String source;
  final String? sourceUrl;
  final bool selected;
  final bool needsManualEntry;

  const IngredientV2({
    required this.name,
    required this.weightGrams,
    required this.nutrientsPer100g,
    required this.nutrientsTotal,
    this.source = 'claude',
    this.sourceUrl,
    this.selected = true,
    this.needsManualEntry = false,
  });

  /// Parse from a v2 API item that contains both `nutrients_per_100g` and
  /// `nutrients_total` sub-objects.
  factory IngredientV2.fromApiItem(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final weight = (item['weight_grams'] as num?)?.toDouble() ?? 100.0;

    // Frontend zero-calorie guard: water, tea, ice, etc. — backend may still
    // miss some variants on free-form text input, so we override here.
    if (isZeroCalorieName(name) || (item['is_zero_calorie'] as bool? ?? false)) {
      final zero = NutrientsV2.zero();
      return IngredientV2(
        name: name,
        weightGrams: weight,
        nutrientsPer100g: zero,
        nutrientsTotal: zero,
        source: item['source'] as String? ?? 'claude',
        sourceUrl: item['source_url'] as String?,
      );
    }

    final per100Raw =
        item['nutrients_per_100g'] as Map<String, dynamic>? ?? {};
    final totalRaw =
        item['nutrients_total'] as Map<String, dynamic>? ?? {};

    final per100 = NutrientsV2.fromJson(_ensureDoubles(per100Raw));
    final total = NutrientsV2.fromJson(_ensureDoubles(totalRaw));

    return IngredientV2(
      name: name,
      weightGrams: weight,
      nutrientsPer100g: per100,
      nutrientsTotal: total,
      source: item['source'] as String? ?? 'claude',
      sourceUrl: item['source_url'] as String?,
      needsManualEntry: item['needs_manual_entry'] as bool? ?? false,
    );
  }

  /// Parse from a v2 suggestion item which only has `nutrients_per_100g`.
  /// [weightGrams] is provided by the caller (user hint or default 100 g).
  factory IngredientV2.fromSuggestion(
      Map<String, dynamic> item, double weightGrams) {
    final name = item['name'] as String? ?? '';

    // Frontend zero-calorie guard for the text-input flow (HIGH-3).
    if (isZeroCalorieName(name) || (item['is_zero_calorie'] as bool? ?? false)) {
      final zero = NutrientsV2.zero();
      return IngredientV2(
        name: name,
        weightGrams: weightGrams,
        nutrientsPer100g: zero,
        nutrientsTotal: zero,
        source: item['source'] as String? ?? 'claude',
        sourceUrl: item['source_url'] as String?,
      );
    }

    final per100Raw =
        item['nutrients_per_100g'] as Map<String, dynamic>? ?? {};
    final per100 = NutrientsV2.fromJson(_ensureDoubles(per100Raw));
    final total = _scaleNutrients(per100, weightGrams / 100.0);

    return IngredientV2(
      name: name,
      weightGrams: weightGrams,
      nutrientsPer100g: per100,
      nutrientsTotal: total,
      source: item['source'] as String? ?? 'claude',
      sourceUrl: item['source_url'] as String?,
      needsManualEntry: item['needs_manual_entry'] as bool? ?? false,
    );
  }

  /// True when there are no known nutrients AND the user hasn't filled them in.
  /// Combines the backend signal (`needsManualEntry`) with the current data
  /// state (`nutrientsTotal.calories == 0`) so UI consumers have one predicate.
  bool get needsManualNutrition =>
      needsManualEntry && nutrientsTotal.calories == 0;

  IngredientV2 copyWith({
    String? name,
    double? weightGrams,
    NutrientsV2? nutrientsPer100g,
    NutrientsV2? nutrientsTotal,
    String? source,
    String? sourceUrl,
    bool? selected,
    bool? needsManualEntry,
  }) {
    return IngredientV2(
      name: name ?? this.name,
      weightGrams: weightGrams ?? this.weightGrams,
      nutrientsPer100g: nutrientsPer100g ?? this.nutrientsPer100g,
      nutrientsTotal: nutrientsTotal ?? this.nutrientsTotal,
      source: source ?? this.source,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      selected: selected ?? this.selected,
      needsManualEntry: needsManualEntry ?? this.needsManualEntry,
    );
  }

  /// Returns a new [IngredientV2] with weight set to [newWeight] and
  /// `nutrientsTotal` recalculated from `nutrientsPer100g`.
  IngredientV2 withWeight(double newWeight) {
    final ratio = newWeight / 100.0;
    return copyWith(
      weightGrams: newWeight,
      nutrientsTotal: _scaleNutrients(nutrientsPer100g, ratio),
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

/// Coerce all num values to double so that [NutrientsV2.fromJson] doesn't
/// throw on integer JSON values (e.g. `"glycemic_index": 30`).
Map<String, dynamic> _ensureDoubles(Map<String, dynamic> raw) {
  return raw.map((key, value) {
    if (key == 'glycemic_index') return MapEntry(key, value);
    if (value is int) return MapEntry(key, value.toDouble());
    return MapEntry(key, value);
  });
}

NutrientsV2 _scaleNutrients(NutrientsV2 per100, double factor) {
  return NutrientsV2(
    calories: per100.calories * factor,
    protein: per100.protein * factor,
    fat: per100.fat * factor,
    carbs: per100.carbs * factor,
    fiber: per100.fiber != null ? per100.fiber! * factor : null,
    sugar: per100.sugar != null ? per100.sugar! * factor : null,
    sugarAlcohols:
        per100.sugarAlcohols != null ? per100.sugarAlcohols! * factor : null,
    netCarbs: per100.netCarbs != null ? per100.netCarbs! * factor : null,
    saturatedFat:
        per100.saturatedFat != null ? per100.saturatedFat! * factor : null,
    monounsaturatedFat: per100.monounsaturatedFat != null
        ? per100.monounsaturatedFat! * factor
        : null,
    polyunsaturatedFat: per100.polyunsaturatedFat != null
        ? per100.polyunsaturatedFat! * factor
        : null,
    sodiumMg: per100.sodiumMg != null ? per100.sodiumMg! * factor : null,
    cholesterolMg:
        per100.cholesterolMg != null ? per100.cholesterolMg! * factor : null,
    potassiumMg:
        per100.potassiumMg != null ? per100.potassiumMg! * factor : null,
    calciumMg: per100.calciumMg != null ? per100.calciumMg! * factor : null,
    ironMg: per100.ironMg != null ? per100.ironMg! * factor : null,
    vitaminAMcg:
        per100.vitaminAMcg != null ? per100.vitaminAMcg! * factor : null,
    vitaminCMg:
        per100.vitaminCMg != null ? per100.vitaminCMg! * factor : null,
    vitaminDMcg:
        per100.vitaminDMcg != null ? per100.vitaminDMcg! * factor : null,
    glycemicIndex: per100.glycemicIndex,
    glycemicIndexCategory: per100.glycemicIndexCategory,
  );
}
