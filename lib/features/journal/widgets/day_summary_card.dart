import 'package:flutter/material.dart';

import '../../../core/i18n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';

/// Compact DAY TOTAL card.
///
/// Primary row: Calories progress bar + 4 macro chips (protein, fat, net carbs, calories).
/// Secondary section: expandable row with extended nutrients (fiber, sugar, sat fat, good fat).
class DaySummaryCard extends StatefulWidget {
  final double netCarbs, netCarbsGoal;
  final double sugar, sugarGoal;
  final double fiber, fiberGoal;
  final double protein, proteinGoal;
  final double goodFat, goodFatGoal;
  final double satFat, satFatGoal;
  final double calories, caloriesGoal;

  const DaySummaryCard({
    super.key,
    required this.netCarbs,
    required this.netCarbsGoal,
    required this.sugar,
    required this.sugarGoal,
    required this.fiber,
    required this.fiberGoal,
    required this.protein,
    required this.proteinGoal,
    required this.goodFat,
    required this.goodFatGoal,
    required this.satFat,
    required this.satFatGoal,
    required this.calories,
    required this.caloriesGoal,
  });

  @override
  State<DaySummaryCard> createState() => _DaySummaryCardState();
}

class _DaySummaryCardState extends State<DaySummaryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRu = l10n.localeName == 'ru';
    final calPct = widget.caloriesGoal > 0
        ? (widget.calories / widget.caloriesGoal).clamp(0.0, 1.0)
        : 0.0;

    final remaining = (widget.caloriesGoal - widget.calories).round();
    final isOver = remaining < 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NutrientColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: label + remaining badge
          Row(
            children: [
              Text(
                'DAY TOTAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: NutrientColors.tertiary,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isOver
                      ? AppColors.accentOverSoft
                      : AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOver
                      ? '+${(-remaining).round()} ${isRu ? "ккал" : "kcal"}'
                      : '${remaining.round()} ${isRu ? "ккал до цели" : "kcal left"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOver
                        ? AppColors.accentOver
                        : AppColors.accentDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Calories progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: LinearProgressIndicator(
                value: calPct,
                backgroundColor:
                    NutrientColors.kcal.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation(
                  isOver ? AppColors.accentOver : AppColors.accent,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Calories value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '/ ${widget.caloriesGoal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Primary macro chips: net carbs, protein, fat
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MacroChip(
                  label: l10n.macro_net_carbs_abbr,
                  value: widget.netCarbs,
                  goal: widget.netCarbsGoal,
                  color: NutrientColors.netCarbs,
                  bg: NutrientColors.netCarbsSoft,
                ),
                const SizedBox(width: 6),
                _MacroChip(
                  label: l10n.macro_protein,
                  value: widget.protein,
                  goal: widget.proteinGoal,
                  color: NutrientColors.protein,
                  bg: NutrientColors.proteinSoft,
                ),
                const SizedBox(width: 6),
                _MacroChip(
                  label: l10n.macro_fat,
                  value: widget.goodFat + widget.satFat,
                  goal: widget.goodFatGoal + widget.satFatGoal,
                  color: NutrientColors.fatGood,
                  bg: NutrientColors.fatGoodSoft,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Expandable secondary nutrients
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _SecondaryChip(
                    label: l10n.nds_nutrient_fiber,
                    value: widget.fiber,
                    goal: widget.fiberGoal,
                    color: NutrientColors.fiber,
                    bg: NutrientColors.fiberSoft,
                  ),
                  _SecondaryChip(
                    label: l10n.nutrient_sugar,
                    value: widget.sugar,
                    goal: widget.sugarGoal,
                    color: NutrientColors.sugar,
                    bg: NutrientColors.sugarSoft,
                  ),
                  _SecondaryChip(
                    label: l10n.macro_sat_fat_short,
                    value: widget.satFat,
                    goal: widget.satFatGoal,
                    color: NutrientColors.fatBad,
                    bg: NutrientColors.fatBadSoft,
                  ),
                  _SecondaryChip(
                    label: l10n.macro_good_fat_short,
                    value: widget.goodFat,
                    goal: widget.goodFatGoal,
                    color: NutrientColors.fatGood,
                    bg: NutrientColors.fatGoodSoft,
                  ),
                ],
              ),
            ),
          ),

          // Expand/collapse toggle
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: NutrientColors.tertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _expanded ? 'Hide' : 'More nutrients',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: NutrientColors.tertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _MacroChip — compact pill showing value / goal with small progress arc ──

class _MacroChip extends StatelessWidget {
  final String label;
  final double value, goal;
  final Color color, bg;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final pct = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 2.5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: 0.75),
                  height: 1.1,
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)}g',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _SecondaryChip — smaller secondary nutrient pill ──

class _SecondaryChip extends StatelessWidget {
  final String label;
  final double value, goal;
  final Color color, bg;

  const _SecondaryChip({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final pct = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    final pctStr = '${(pct * 100).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.75),
              ),
            ),
            TextSpan(
              text: '${value.toStringAsFixed(0)}g',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            TextSpan(
              text: ' · $pctStr',
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
