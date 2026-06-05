import 'package:flutter/material.dart';

import '../../core/i18n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

/// Displays extended nutrient values as chips in a Wrap layout.
/// Only shows nutrients with non-null, non-zero values.
///
/// Units:
/// - fiber, sugar, sugarAlcohols, netCarbs, saturatedFat, unsaturatedFat → grams
/// - sodiumMg, cholesterolMg, potassiumMg → milligrams (pass raw mg values)
/// - glycemicIndex → number + low/med/high badge
class ExtendedNutrientsGrid extends StatelessWidget {
  final double? fiber;
  final double? sugar;
  final double? sugarAlcohols;
  final double? netCarbs;
  final double? saturatedFat;
  final double? unsaturatedFat;
  final double? sodiumMg;
  final double? cholesterolMg;
  final double? potassiumMg;
  final double? calciumMg;
  final double? ironMg;
  final double? vitaminAMcg;
  final double? vitaminCMg;
  final double? vitaminDMcg;
  final double? vitaminB12Mcg;
  final int? glycemicIndex;
  final String? glycemicIndexCategory;

  const ExtendedNutrientsGrid({
    super.key,
    this.fiber,
    this.sugar,
    this.sugarAlcohols,
    this.netCarbs,
    this.saturatedFat,
    this.unsaturatedFat,
    this.sodiumMg,
    this.cholesterolMg,
    this.potassiumMg,
    this.calciumMg,
    this.ironMg,
    this.vitaminAMcg,
    this.vitaminCMg,
    this.vitaminDMcg,
    this.vitaminB12Mcg,
    this.glycemicIndex,
    this.glycemicIndexCategory,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final g = l10n.nds_unit_g;
    final mg = l10n.nds_unit_mg;
    final mcg = l10n.nds_unit_mcg;
    final chips = <Widget>[
      if (fiber != null && fiber! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_fiber,
          value: fiber!.toStringAsFixed(1),
          unit: g,
          color: NutrientColors.fiber,
          bg: NutrientColors.fiberSoft,
        ),
      if (netCarbs != null && netCarbs! > 0)
        _NutrientChip(
          label: l10n.nutrient_net_carbs,
          value: netCarbs!.toStringAsFixed(1),
          unit: g,
          color: NutrientColors.netCarbs,
          bg: NutrientColors.netCarbsSoft,
        ),
      if (sugar != null && sugar! > 0)
        _NutrientChip(
          label: l10n.nutrient_sugar,
          value: sugar!.toStringAsFixed(1),
          unit: g,
          color: NutrientColors.sugar,
          bg: NutrientColors.sugarSoft,
        ),
      if (sugarAlcohols != null && sugarAlcohols! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_sugar_alcohols,
          value: sugarAlcohols!.toStringAsFixed(1),
          unit: g,
          color: NutrientColors.sugar,
          bg: NutrientColors.sugarSoft,
        ),
      if (saturatedFat != null && saturatedFat! > 0)
        _NutrientChip(
          label: l10n.nutrient_saturated_fat,
          value: saturatedFat!.toStringAsFixed(1),
          unit: g,
          color: NutrientColors.fatBad,
          bg: NutrientColors.fatBadSoft,
        ),
      if (unsaturatedFat != null && unsaturatedFat! > 0)
        _NutrientChip(
          label: l10n.nutrient_unsaturated_fat,
          value: unsaturatedFat!.toStringAsFixed(1),
          unit: g,
          color: NutrientColors.fatGood,
          bg: NutrientColors.fatGoodSoft,
        ),
      if (sodiumMg != null && sodiumMg! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_sodium,
          value: sodiumMg!.toStringAsFixed(0),
          unit: mg,
          color: AppColors.textMuted,
          bg: NutrientColors.bg,
        ),
      if (cholesterolMg != null && cholesterolMg! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_cholesterol,
          value: cholesterolMg!.toStringAsFixed(0),
          unit: mg,
          color: AppColors.textMuted,
          bg: NutrientColors.bg,
        ),
      if (potassiumMg != null && potassiumMg! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_potassium,
          value: potassiumMg!.toStringAsFixed(0),
          unit: mg,
          color: AppColors.textMuted,
          bg: NutrientColors.bg,
        ),
      if (calciumMg != null && calciumMg! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_calcium,
          value: calciumMg!.toStringAsFixed(0),
          unit: mg,
          color: AppColors.textMuted,
          bg: NutrientColors.bg,
        ),
      if (ironMg != null && ironMg! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_iron,
          value: ironMg!.toStringAsFixed(1),
          unit: mg,
          color: AppColors.textMuted,
          bg: NutrientColors.bg,
        ),
      if (vitaminAMcg != null && vitaminAMcg! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_vitamin_a,
          value: vitaminAMcg!.toStringAsFixed(0),
          unit: mcg,
          color: NutrientColors.fiber,
          bg: NutrientColors.fiberSoft,
        ),
      if (vitaminCMg != null && vitaminCMg! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_vitamin_c,
          value: vitaminCMg!.toStringAsFixed(1),
          unit: mg,
          color: NutrientColors.fiber,
          bg: NutrientColors.fiberSoft,
        ),
      if (vitaminDMcg != null && vitaminDMcg! > 0)
        _NutrientChip(
          label: l10n.nds_nutrient_vitamin_d,
          value: vitaminDMcg!.toStringAsFixed(1),
          unit: mcg,
          color: NutrientColors.fiber,
          bg: NutrientColors.fiberSoft,
        ),
      if (vitaminB12Mcg != null && vitaminB12Mcg! > 0)
        _NutrientChip(
          label: l10n.nutrient_vitamin_b12,
          value: vitaminB12Mcg!.toStringAsFixed(1),
          unit: mcg,
          color: NutrientColors.fiber,
          bg: NutrientColors.fiberSoft,
        ),
      if (glycemicIndex != null) _GiBadgeChip(gi: glycemicIndex!, l10n: l10n),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _NutrientChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final Color bg;

  const _NutrientChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: '$value $unit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiBadgeChip extends StatelessWidget {
  final int gi;
  final AppLocalizations l10n;
  const _GiBadgeChip({required this.gi, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (gi < 55) {
      color = AppColors.accent;
      label = l10n.gi_low_badge;
    } else if (gi < 70) {
      color = AppColors.warm;
      label = l10n.gi_medium_badge;
    } else {
      color = AppColors.accentOver;
      label = l10n.gi_high_badge;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label $gi',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
