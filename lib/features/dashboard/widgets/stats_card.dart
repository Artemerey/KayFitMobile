import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../shared/models/meal.dart';
import '../../../shared/models/stats.dart';
import '../../../shared/theme/app_theme.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StatsCard — animated ring + macro bars + expandable micro-nutrients
// ─────────────────────────────────────────────────────────────────────────────

class StatsCard extends StatefulWidget {
  final MacroStats stats;
  final List<Meal>? meals;

  const StatsCard({super.key, required this.stats, this.meals});

  @override
  State<StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<StatsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _updateAnimation();
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(StatsCard old) {
    super.didUpdateWidget(old);
    if (old.stats != widget.stats) {
      _updateAnimation();
      _ctrl
        ..reset()
        ..forward();
    }
  }

  void _updateAnimation() {
    final ratio = widget.stats.caloriesGoal > 0
        ? (widget.stats.caloriesEaten / widget.stats.caloriesGoal).clamp(0.0, 1.2)
        : 0.0;
    _progress = Tween<double>(begin: 0, end: ratio).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Aggregate a field from all meals, null → 0
  double _sum(double? Function(Meal) pick) =>
      (widget.meals ?? []).fold(0.0, (acc, m) => acc + (pick(m) ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = widget.stats;
    final isOver = s.caloriesGoal > 0 && s.caloriesEaten > s.caloriesGoal;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.md,
      ),
      child: Column(
        children: [
          // ── Top: ring + numbers ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isOver
                    ? [const Color(0xFFFFF1F2), const Color(0xFFFFE4E6)]
                    : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) => _CalorieRing(
                    progress: _progress.value,
                    isOver: isOver,
                    eaten: s.caloriesEaten,
                    goal: s.caloriesGoal,
                    animValue: _ctrl.value,
                    l10n: l10n,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: l10n.macro_eaten,
                        value: '${s.caloriesEaten.toStringAsFixed(0)} ${l10n.macro_kcal}',
                        color: isOver ? AppColors.accentOver : AppColors.accent,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: isOver ? l10n.dashboard_remaining_over : l10n.macro_remaining,
                        value: '${(s.caloriesGoal - s.caloriesEaten).abs().toStringAsFixed(0)} ${l10n.macro_kcal}',
                        color: isOver ? AppColors.accentOver : AppColors.textMuted,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: l10n.macro_goal,
                        value: '${s.caloriesGoal.toStringAsFixed(0)} ${l10n.macro_kcal}',
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom: macros ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                _AnimatedMacro(
                  label: l10n.macro_protein,
                  eaten: s.proteinEaten,
                  goal: s.proteinGoal,
                  color: AppColors.accent,
                  softColor: AppColors.accentSoft,
                  unit: l10n.macro_g,
                  parentCtrl: _ctrl,
                ),
                const SizedBox(width: 8),
                _AnimatedMacro(
                  label: l10n.macro_fat,
                  eaten: s.fatEaten,
                  goal: s.fatGoal,
                  color: AppColors.warm,
                  softColor: AppColors.warmSoft,
                  unit: l10n.macro_g,
                  parentCtrl: _ctrl,
                ),
                const SizedBox(width: 8),
                _AnimatedMacro(
                  label: l10n.macro_carbs,
                  eaten: s.carbsEaten,
                  goal: s.carbsGoal,
                  color: AppColors.support,
                  softColor: AppColors.supportSoft,
                  unit: l10n.macro_g,
                  parentCtrl: _ctrl,
                ),
              ],
            ),
          ),

          // ── Expand / collapse button ─────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _expanded ? l10n.stats_hide_details : l10n.stats_show_details,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable micro-nutrients section ───────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 8),
            secondChild: _MicroNutrientsGrid(
              fiber: _sum((m) => m.fiber),
              sodium: _sum((m) => m.sodium),
              potassium: _sum((m) => m.potassium),
              cholesterol: _sum((m) => m.cholesterol),
              iron: _sum((m) => m.iron),
              calcium: _sum((m) => m.calcium),
              vitaminC: _sum((m) => m.vitaminC),
              vitaminD: _sum((m) => m.vitaminD),
            ),
          ),

          // ── Citation note ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    l10n.stats_mifflin_disclaimer,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Micro-nutrients 2-column grid
// ─────────────────────────────────────────────────────────────────────────────

class _MicroNutrientsGrid extends StatelessWidget {
  final double fiber;
  final double sodium;
  final double potassium;
  final double cholesterol;
  final double iron;
  final double calcium;
  final double vitaminC;
  final double vitaminD;

  const _MicroNutrientsGrid({
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.cholesterol,
    required this.iron,
    required this.calcium,
    required this.vitaminC,
    required this.vitaminD,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final g = l10n.macro_g;
    final mg = l10n.nds_unit_mg;
    final mcg = l10n.nds_unit_mcg;
    final items = [
      _MicroItem(
        icon: Icons.grass_rounded,
        color: NutrientColors.fiber,
        label: l10n.nds_nutrient_fiber,
        value: '${fiber.toStringAsFixed(1)}$g',
      ),
      _MicroItem(
        icon: Icons.water_drop_outlined,
        color: const Color(0xFF0284C7),
        label: l10n.nds_nutrient_sodium,
        value: '${sodium.toStringAsFixed(0)}$mg',
      ),
      _MicroItem(
        icon: Icons.bolt_rounded,
        color: const Color(0xFF7C3AED),
        label: l10n.nds_nutrient_potassium,
        value: '${potassium.toStringAsFixed(0)}$mg',
      ),
      _MicroItem(
        icon: Icons.favorite_border_rounded,
        color: AppColors.accentOver,
        label: l10n.nds_nutrient_cholesterol,
        value: '${cholesterol.toStringAsFixed(0)}$mg',
      ),
      _MicroItem(
        icon: Icons.bloodtype_outlined,
        color: const Color(0xFFB45309),
        label: l10n.nds_nutrient_iron,
        value: '${iron.toStringAsFixed(1)}$mg',
      ),
      _MicroItem(
        icon: Icons.shield_outlined,
        color: const Color(0xFF0369A1),
        label: l10n.nds_nutrient_calcium,
        value: '${calcium.toStringAsFixed(0)}$mg',
      ),
      _MicroItem(
        icon: Icons.wb_sunny_outlined,
        color: NutrientColors.kcal,
        label: l10n.nds_nutrient_vit_c_short,
        value: '${vitaminC.toStringAsFixed(1)}$mg',
      ),
      _MicroItem(
        icon: Icons.brightness_5_rounded,
        color: const Color(0xFFF59E0B),
        label: l10n.nds_nutrient_vit_d_short,
        value: '${vitaminD.toStringAsFixed(1)}$mcg',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _MicroCell(item: items[i]),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _MicroItem {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _MicroItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
}

class _MicroCell extends StatelessWidget {
  final _MicroItem item;
  const _MicroCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 18, color: item.color),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textMuted,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Circular ring painter
// ─────────────────────────────────────────────────────────────────────────────

class _CalorieRing extends StatelessWidget {
  final double progress;
  final bool isOver;
  final double eaten;
  final double goal;
  final double animValue;
  final AppLocalizations l10n;

  const _CalorieRing({
    required this.progress,
    required this.isOver,
    required this.eaten,
    required this.goal,
    required this.animValue,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = isOver ? AppColors.accentOver : AppColors.accent;
    final displayedEaten = (eaten * animValue).toStringAsFixed(0);

    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          trackColor: isOver ? AppColors.accentOverSoft : AppColors.accentSoft,
          fillColor: ringColor,
          overFill: isOver,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayedEaten,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isOver ? AppColors.accentOver : AppColors.text,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.macro_kcal,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final bool overFill;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.overFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 9.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect, -math.pi / 2, 2 * math.pi, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.fillColor != fillColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row on the right side of the ring
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated macro bar
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedMacro extends StatelessWidget {
  final String label;
  final double eaten;
  final double goal;
  final Color color;
  final Color softColor;
  final String unit;
  final AnimationController parentCtrl;

  const _AnimatedMacro({
    required this.label,
    required this.eaten,
    required this.goal,
    required this.color,
    required this.softColor,
    required this.unit,
    required this.parentCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = goal > 0 ? (eaten / goal).clamp(0.0, 1.0) : 0.0;
    final widthAnim = Tween<double>(begin: 0, end: ratio).animate(
      CurvedAnimation(parent: parentCtrl, curve: Curves.easeOutCubic),
    );

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: softColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${eaten.toStringAsFixed(0)}/${goal.toStringAsFixed(0)}$unit',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                height: 1,
              ),
            ),
            const SizedBox(height: 7),
            LayoutBuilder(builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: softColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: widthAnim,
                    builder: (context, _) => FractionallySizedBox(
                      widthFactor: widthAnim.value,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
