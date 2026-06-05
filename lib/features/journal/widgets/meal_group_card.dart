import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/i18n/generated/app_localizations.dart';
import '../../../shared/models/meal.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/dismissible_sheet_wrapper.dart';
import '../../../shared/widgets/extended_nutrients_grid.dart';

({String emoji, String label}) _mealTypeLabel(
  String type,
  AppLocalizations l10n,
) => switch (type) {
  'breakfast' => (emoji: '🌅', label: l10n.mealType_breakfast),
  'lunch' => (emoji: '☀️', label: l10n.mealType_lunch),
  'dinner' => (emoji: '🌙', label: l10n.mealType_dinner),
  'snack' => (emoji: '🍎', label: l10n.mealType_snack),
  _ => (emoji: '🍽', label: type),
};

String _dishEmojiFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('кофе') || n.contains('coffee') || n.contains('tea') || n.contains('чай')) return '☕';
  if (n.contains('салат') || n.contains('salad')) return '🥗';
  if (n.contains('хлеб') || n.contains('bread')) return '🍞';
  if (n.contains('банан') || n.contains('banana')) return '🍌';
  if (n.contains('творог') || n.contains('yogurt') || n.contains('cottage')) return '🥜';
  if (n.contains('овс') || n.contains('oat') || n.contains('каша')) return '🥣';
  if (n.contains('плов') || n.contains('рис') || n.contains('rice')) return '🍛';
  if (n.contains('суп') || n.contains('soup')) return '🍲';
  if (n.contains('яйц') || n.contains('egg')) return '🍳';
  return '🍽';
}

/// Grouped meal card for the journal. Shows a meal type (Breakfast/Lunch/etc)
/// with summary stats and list of dishes inside.
/// Each dish row is tappable and opens [_MealDetailSheet].
/// The "Details" footer navigates to /journal.
class MealGroupCard extends StatelessWidget {
  final String mealType;
  final String time;
  final List<Meal> meals;
  final VoidCallback? onTap;
  final void Function(int id)? onDeleteMeal;
  final void Function(int id)? onEditMeal;

  const MealGroupCard({
    super.key,
    required this.mealType,
    required this.time,
    required this.meals,
    this.onTap,
    this.onDeleteMeal,
    this.onEditMeal,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = _mealTypeLabel(mealType, l10n);
    final emoji = config.emoji;
    final title = config.label;

    // Compute totals
    final totalCal = meals.fold<double>(0, (s, m) => s + m.calories);
    final totalProtein = meals.fold<double>(0, (s, m) => s + m.protein);
    final totalFat = meals.fold<double>(0, (s, m) => s + m.fat);
    final totalNetCarbs =
        meals.fold<double>(0, (s, m) => s + (m.netCarbs ?? m.carbs));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NutrientColors.border),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: NutrientColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(time,
                    style: TextStyle(
                        fontSize: 12, color: NutrientColors.tertiary)),
              ],
            ),
          ),

          // Stats chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _Chip('Net ${totalNetCarbs.toStringAsFixed(0)}g',
                    NutrientColors.netCarbs, NutrientColors.netCarbsSoft),
                const SizedBox(width: 6),
                _Chip('P ${totalProtein.toStringAsFixed(0)}g',
                    NutrientColors.protein, NutrientColors.proteinSoft),
                const SizedBox(width: 6),
                _Chip('F ${totalFat.toStringAsFixed(0)}g',
                    NutrientColors.fatGood, NutrientColors.fatGoodSoft),
                const SizedBox(width: 6),
                _Chip('${totalCal.toStringAsFixed(0)} kcal',
                    NutrientColors.kcal, NutrientColors.kcalSoft),
              ],
            ),
          ),

          // Dish list — each row is tappable
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              children: meals.map((m) {
                final net = m.netCarbs ?? m.carbs;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showMealDetail(context, m);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: NutrientColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(_dishEmojiFor(m.name),
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.dishName ?? m.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Net ${net.toStringAsFixed(0)}g · P ${m.protein.toStringAsFixed(0)}g · F ${m.fat.toStringAsFixed(0)}g',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: NutrientColors.secondary),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${m.calories.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: NutrientColors.tertiary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded,
                                size: 14,
                                color: NutrientColors.tertiary
                                    .withValues(alpha: 0.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Details link — shows group nutrient summary
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showGroupDetail(context);
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.dashboard_details,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NutrientColors.netCarbs,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: NutrientColors.netCarbs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      builder: (_) => DismissibleSheetWrapper(
        child: _GroupDetailSheet(mealType: mealType, meals: meals),
      ),
    );
  }

  void _showMealDetail(BuildContext context, Meal meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      builder: (_) => DismissibleSheetWrapper(
        child: _MealDetailSheet(
          meal: meal,
          onDelete: onDeleteMeal,
          onEdit: onEditMeal,
        ),
      ),
    );
  }

}

// ── _Chip ──────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const _Chip(this.text, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── helpers ────────────────────────────────────────────────────────────────

bool _hasExtendedData(Meal meal) {
  final net = meal.netCarbs ?? meal.carbs;
  return (meal.fiber != null && meal.fiber! > 0) ||
      (meal.sugar != null && meal.sugar! > 0) ||
      (meal.sugarAlcohols != null && meal.sugarAlcohols! > 0) ||
      net > 0 ||
      (meal.saturatedFat != null && meal.saturatedFat! > 0) ||
      (meal.unsaturatedFat != null && meal.unsaturatedFat! > 0) ||
      (meal.sodium != null && meal.sodium! > 0) ||
      (meal.cholesterol != null && meal.cholesterol! > 0) ||
      (meal.potassium != null && meal.potassium! > 0) ||
      (meal.calcium != null && meal.calcium! > 0) ||
      (meal.iron != null && meal.iron! > 0) ||
      (meal.vitaminA != null && meal.vitaminA! > 0) ||
      (meal.vitaminC != null && meal.vitaminC! > 0) ||
      (meal.vitaminD != null && meal.vitaminD! > 0) ||
      (meal.vitaminB12 != null && meal.vitaminB12! > 0) ||
      meal.glycemicIndex != null;
}

// ── _MealDetailSheet ───────────────────────────────────────────────────────

class _MealDetailSheet extends StatelessWidget {
  final Meal meal;
  final void Function(int id)? onDelete;
  final void Function(int id)? onEdit;
  const _MealDetailSheet({required this.meal, this.onDelete, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = meal.dishName ?? meal.name;
    final net = meal.netCarbs ?? meal.carbs;

    final extendedGrid = ExtendedNutrientsGrid(
      fiber: meal.fiber,
      sugar: meal.sugar,
      sugarAlcohols: meal.sugarAlcohols,
      netCarbs: net > 0 ? net : null,
      saturatedFat: meal.saturatedFat,
      unsaturatedFat: meal.unsaturatedFat,
      sodiumMg: meal.sodium,
      cholesterolMg: meal.cholesterol,
      potassiumMg: meal.potassium,
      calciumMg: meal.calcium,
      ironMg: meal.iron,
      vitaminAMcg: meal.vitaminA,
      vitaminCMg: meal.vitaminC,
      vitaminDMcg: meal.vitaminD,
      vitaminB12Mcg: meal.vitaminB12,
      glycemicIndex: meal.glycemicIndex,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 0,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: NutrientColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Meal name + emoji
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (meal.glycemicIndex != null) ...[
                const SizedBox(width: 10),
                _GiBadge(gi: meal.glycemicIndex!),
              ],
            ],
          ),

          if (meal.weight != null && meal.weight! > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${meal.weight!.toStringAsFixed(0)} g',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Primary macro grid: calories, protein, fat, carbs
          _MacroGrid(meal: meal),

          // Extended nutrients via shared widget — only when data is present
          if (_hasExtendedData(meal)) ...[
            const SizedBox(height: 14),
            Text(
              'EXTENDED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: NutrientColors.tertiary,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            extendedGrid,
          ],

          const SizedBox(height: 20),
          const Divider(height: 1, color: NutrientColors.border),
          const SizedBox(height: 14),

          // Actions row
          Row(
            children: [
              if (onEdit != null)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.edit_rounded,
                    label: l10n.common_edit,
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.of(context).pop();
                      onEdit!(meal.id);
                    },
                  ),
                ),
              if (onEdit != null && onDelete != null)
                const SizedBox(width: 10),
              if (onDelete != null)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: l10n.common_delete,
                    color: AppColors.accentOver,
                    onTap: () {
                      Navigator.of(context).pop();
                      onDelete!(meal.id);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _MacroGrid ─────────────────────────────────────────────────────────────

class _MacroGrid extends StatelessWidget {
  final Meal meal;
  const _MacroGrid({required this.meal});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _MacroCell(
            label: l10n.macro_calories,
            value: '${meal.calories.toStringAsFixed(0)}',
            unit: l10n.macro_kcal,
            color: NutrientColors.kcal,
            bg: NutrientColors.kcalSoft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroCell(
            label: l10n.macro_protein,
            value: meal.protein.toStringAsFixed(1),
            unit: l10n.macro_g,
            color: NutrientColors.protein,
            bg: NutrientColors.proteinSoft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroCell(
            label: l10n.macro_fat,
            value: meal.fat.toStringAsFixed(1),
            unit: l10n.macro_g,
            color: NutrientColors.fatGood,
            bg: NutrientColors.fatGoodSoft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MacroCell(
            label: l10n.macro_carbs,
            value: meal.carbs.toStringAsFixed(1),
            unit: l10n.macro_g,
            color: NutrientColors.netCarbs,
            bg: NutrientColors.netCarbsSoft,
          ),
        ),
      ],
    );
  }
}

class _MacroCell extends StatelessWidget {
  final String label, value, unit;
  final Color color, bg;
  const _MacroCell({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.7),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _GiBadge ───────────────────────────────────────────────────────────────

class _GiBadge extends StatelessWidget {
  final int gi;
  const _GiBadge({required this.gi});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (gi < 55) {
      color = AppColors.accent;
      label = 'Low GI';
    } else if (gi < 70) {
      color = AppColors.warm;
      label = 'Med GI';
    } else {
      color = AppColors.accentOver;
      label = 'High GI';
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

// ── _ActionButton ──────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _GroupDetailSheet ───────────────────────────────────────────────────────

class _GroupDetailSheet extends StatelessWidget {
  final String mealType;
  final List<Meal> meals;
  const _GroupDetailSheet({required this.mealType, required this.meals});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = _mealTypeLabel(mealType, l10n);
    final emoji = config.emoji;
    final title = config.label;

    final totalCal = meals.fold<double>(0, (s, m) => s + m.calories);
    final totalP   = meals.fold<double>(0, (s, m) => s + m.protein);
    final totalF   = meals.fold<double>(0, (s, m) => s + m.fat);
    final totalC   = meals.fold<double>(0, (s, m) => s + m.carbs);
    final totalNet = meals.fold<double>(0, (s, m) => s + (m.netCarbs ?? m.carbs));

    // Aggregated extended nutrients — null-collapse to null if total is zero
    double _sumOrNull(double Function(Meal) fn) =>
        meals.fold<double>(0, (s, m) => s + fn(m));
    final aggFiber      = _sumOrNull((m) => m.fiber ?? 0);
    final aggSugar      = _sumOrNull((m) => m.sugar ?? 0);
    final aggSugarAlc   = _sumOrNull((m) => m.sugarAlcohols ?? 0);
    final aggSatFat     = _sumOrNull((m) => m.saturatedFat ?? 0);
    final aggUnsatFat   = _sumOrNull((m) => m.unsaturatedFat ?? 0);
    final aggSodiumMg   = _sumOrNull((m) => m.sodium ?? 0);
    final aggCholMg     = _sumOrNull((m) => m.cholesterol ?? 0);
    final aggPotMg      = _sumOrNull((m) => m.potassium ?? 0);
    final hasExtended = aggFiber > 0 || aggSugar > 0 || aggSugarAlc > 0 ||
        totalNet > 0 || aggSatFat > 0 || aggUnsatFat > 0 ||
        aggSodiumMg > 0 || aggCholMg > 0 || aggPotMg > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: NutrientColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text, letterSpacing: -0.3)),
                const Spacer(),
                Text(
                  l10n.mealGroup_itemsCount(meals.length),
                  style: TextStyle(fontSize: 12, color: NutrientColors.tertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _MacroCell(label: l10n.macro_calories, value: totalCal.toStringAsFixed(0), unit: l10n.macro_kcal, color: NutrientColors.kcal, bg: NutrientColors.kcalSoft)),
                const SizedBox(width: 8),
                Expanded(child: _MacroCell(label: l10n.macro_protein, value: totalP.toStringAsFixed(1), unit: l10n.macro_g, color: NutrientColors.protein, bg: NutrientColors.proteinSoft)),
                const SizedBox(width: 8),
                Expanded(child: _MacroCell(label: l10n.macro_fat, value: totalF.toStringAsFixed(1), unit: l10n.macro_g, color: NutrientColors.fatGood, bg: NutrientColors.fatGoodSoft)),
                const SizedBox(width: 8),
                Expanded(child: _MacroCell(label: l10n.macro_carbs, value: totalC.toStringAsFixed(1), unit: l10n.macro_g, color: NutrientColors.netCarbs, bg: NutrientColors.netCarbsSoft)),
              ],
            ),
          ),
          if (hasExtended) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ExtendedNutrientsGrid(
                fiber: aggFiber > 0 ? aggFiber : null,
                sugar: aggSugar > 0 ? aggSugar : null,
                sugarAlcohols: aggSugarAlc > 0 ? aggSugarAlc : null,
                netCarbs: totalNet > 0 ? totalNet : null,
                saturatedFat: aggSatFat > 0 ? aggSatFat : null,
                unsaturatedFat: aggUnsatFat > 0 ? aggUnsatFat : null,
                sodiumMg: aggSodiumMg > 0 ? aggSodiumMg : null,
                cholesterolMg: aggCholMg > 0 ? aggCholMg : null,
                potassiumMg: aggPotMg > 0 ? aggPotMg : null,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20, color: NutrientColors.border),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              itemCount: meals.length,
              itemBuilder: (_, i) {
                final m = meals[i];
                final net = m.netCarbs ?? m.carbs;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(_dishEmojiFor(m.name), style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.dishName ?? m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('Net ${net.toStringAsFixed(0)}g · P ${m.protein.toStringAsFixed(0)}g · F ${m.fat.toStringAsFixed(0)}g', style: TextStyle(fontSize: 11, color: NutrientColors.secondary)),
                          ],
                        ),
                      ),
                      Text('${m.calories.toStringAsFixed(0)} kcal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: NutrientColors.kcal)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
