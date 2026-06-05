import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/models/calculation_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/i18n/generated/app_localizations.dart';

/// Shared plan-result view used by WayToGoalScreen and OnboardingScreen (_ResultStep).
/// CTA buttons are owned by the parent. [bottomPadding] reserves space below the last
/// card so a fixed footer outside this widget does not occlude content.
class PlanResultView extends StatelessWidget {
  final CalculationResult calc;
  final AppLocalizations l10n;
  final double? currentWeight;
  final double bottomPadding;

  const PlanResultView({
    super.key,
    required this.calc,
    required this.l10n,
    this.currentWeight,
    this.bottomPadding = 24,
  });

  bool get _isMaintain {
    final calDelta = (calc.targetCalories - calc.tdee).abs();
    if (calDelta > 80) return false;
    final tw = calc.targetWeight;
    final cw = currentWeight;
    if (tw == null || cw == null) return false;
    return (tw - cw).abs() < 0.5;
  }

  _PlanDirection get _direction {
    final delta = calc.targetCalories - calc.tdee;
    if (delta > 80) return _PlanDirection.gain;
    if (delta < -80) return _PlanDirection.lose;
    return _PlanDirection.maintain;
  }

  String _localPlanFallback(bool isRu) {
    final cw = currentWeight ?? calc.targetWeight ?? 70;
    final dir = _direction;
    final perKg = dir == _PlanDirection.gain ? 1.8 : 1.6;
    final proteinG = (cw * perKg).round();
    if (isRu) {
      switch (dir) {
        case _PlanDirection.gain:
          return 'Набор массы: цельтесь в $proteinG г белка/день, добавьте 1–2 силовые тренировки и углеводы вокруг тренировок.';
        case _PlanDirection.lose:
          return 'Снижение веса: $proteinG г белка/день, овощи в каждом приёме, вода до еды — мягкий дефицит без срывов.';
        case _PlanDirection.maintain:
          return 'Поддержание формы: $proteinG г белка/день, сбалансированная тарелка — ½ овощи, ¼ белок, ¼ сложные углеводы.';
      }
    }
    switch (dir) {
      case _PlanDirection.gain:
        return 'Muscle gain: aim for $proteinG g protein/day, add 1–2 strength sessions, time carbs around training.';
      case _PlanDirection.lose:
        return 'Weight loss: $proteinG g protein/day, veggies on every plate, water before meals — gentle deficit, no crashes.';
      case _PlanDirection.maintain:
        return 'Maintain: $proteinG g protein/day, balanced plate — ½ veg, ¼ protein, ¼ complex carbs.';
    }
  }

  String _goalDateLabel(bool isRu) {
    if (calc.daysToGoal == null || calc.targetWeight == null) return '';
    final goalDate = DateTime.now().add(Duration(days: calc.daysToGoal!));
    final monthsRu = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
                      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    final monthsEn = ['January', 'February', 'March', 'April', 'May', 'June',
                      'July', 'August', 'September', 'October', 'November', 'December'];
    final months = isRu ? monthsRu : monthsEn;
    return '${goalDate.day} ${months[goalDate.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final maintain = _isMaintain;

    final planText = (calc.personalizedPlan != null && calc.personalizedPlan!.isNotEmpty)
        ? calc.personalizedPlan!
        : _localPlanFallback(isRu);

    final headerTitle = isRu ? 'Отлично!' : 'Great!';
    final headerSubtitle = isRu ? 'Ваш персональный план готов' : 'Your personal plan is ready';

    final dailyRecTitle = isRu ? 'Рекомендация на день' : 'Daily recommendation';
    final howToTitle = isRu ? 'Как достичь ваших целей:' : 'How to reach your goals:';
    final scienceTitle = isRu
        ? 'План основан на надёжных научных исследованиях и медицинской экспертизе'
        : 'Plan based on trusted scientific research and medical expertise';

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      children: [
        const SizedBox(height: 24),

        // ── Personalized plan banner ──────────────────────────────────────────
        _PersonalPlanBanner(text: planText, isRu: isRu),
        const SizedBox(height: 16),

        // ── Celebration header ────────────────────────────────────────────────
        Text(
          headerTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          headerSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),

        // ── Goal date card (only when losing/gaining weight with a target) ────
        if (!maintain && calc.daysToGoal != null && calc.targetWeight != null) ...[
          _GoalDateCard(
            targetWeight: calc.targetWeight!,
            dateLabel: _goalDateLabel(isRu),
            isRu: isRu,
          ),
          const SizedBox(height: 16),
        ],

        // ── Daily recommendation section ──────────────────────────────────────
        Text(
          dailyRecTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 10),

        // Calories card
        _EditableStatCard(
          label: l10n.macro_calories,
          value: calc.targetCalories.toStringAsFixed(0),
          unit: '',
          badgeColor: null,
          badgeInitial: null,
        ),
        const SizedBox(height: 8),

        // Protein card
        _EditableStatCard(
          label: l10n.macro_protein,
          value: calc.protein.toStringAsFixed(0),
          unit: l10n.macro_g,
          badgeColor: const Color(0xFF3B82F6),
          badgeInitial: l10n.macro_protein_abbr,
        ),
        const SizedBox(height: 8),

        // Fat card
        _EditableStatCard(
          label: l10n.macro_fat,
          value: calc.fat.toStringAsFixed(0),
          unit: l10n.macro_g,
          badgeColor: const Color(0xFFF59E0B),
          badgeInitial: l10n.macro_fat_abbr,
        ),
        const SizedBox(height: 8),

        // Carbs card
        _EditableStatCard(
          label: l10n.macro_carbs,
          value: calc.carbs.toStringAsFixed(0),
          unit: l10n.macro_g,
          badgeColor: const Color(0xFFEF4444),
          badgeInitial: l10n.macro_carbs_abbr,
        ),
        const SizedBox(height: 20),

        // ── How to reach goals ────────────────────────────────────────────────
        Text(
          howToTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 10),
        _HowToCard(isRu: isRu, l10n: l10n),
        const SizedBox(height: 20),

        // ── Scientific citations ──────────────────────────────────────────────
        Text(
          scienceTitle,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        _CitationLinks(isRu: isRu),
        const SizedBox(height: 20),

        // ── Weight forecast chart (skipped in maintain mode) ──────────────────
        if (!maintain) ...[
          _WeightChart(calc: calc, l10n: l10n),
          const SizedBox(height: 20),
        ],

        // ── Maintain mode info ────────────────────────────────────────────────
        if (maintain) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.balance_rounded, size: 22, color: Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu ? 'Поддержание веса' : 'Weight maintenance',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isRu
                            ? 'Текущий и целевой вес совпадают. Эти калории помогут удержать форму.'
                            : 'Your current and target weight match. These calories will keep you steady.',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// ── Personalized AI plan banner ──────────────────────────────────────────────

class _PersonalPlanBanner extends StatelessWidget {
  final String text;
  final bool isRu;
  const _PersonalPlanBanner({required this.text, required this.isRu});

  @override
  Widget build(BuildContext context) {
    final label = isRu ? 'Ваш персональный план' : 'Your personal plan';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Goal date card with laurels ──────────────────────────────────────────────

class _GoalDateCard extends StatelessWidget {
  final double targetWeight;
  final String dateLabel;
  final bool isRu;
  const _GoalDateCard({required this.targetWeight, required this.dateLabel, required this.isRu});

  @override
  Widget build(BuildContext context) {
    final label = isRu
        ? 'Вы должны достичь\n${targetWeight.toStringAsFixed(0)} кг к $dateLabel'
        : 'You should reach\n${targetWeight.toStringAsFixed(0)} kg by $dateLabel';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OBColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
              height: 1.3,
            ),
          ),
          const SizedBox(width: 12),
          const Text('🏆', style: TextStyle(fontSize: 28)),
        ],
      ),
    );
  }
}

// ── Editable stat card (Calories / Protein / Fat / Carbs) ────────────────────

class _EditableStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? badgeColor;
  final String? badgeInitial;

  const _EditableStatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.badgeColor,
    required this.badgeInitial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OBColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (badgeColor != null && badgeInitial != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                badgeInitial!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  '$value$unit',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

// ── How to reach card ────────────────────────────────────────────────────────

class _HowToCard extends StatelessWidget {
  final bool isRu;
  final AppLocalizations l10n;
  const _HowToCard({required this.isRu, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final items = isRu ? [
      ('🍽️', 'Ешь, что любишь', 'Найдите вкусную и сытную еду, которая поможет вам достичь ваших целей.'),
      ('📸', 'Лёгкий учёт питания', 'Щёлкните фото, оно распознаётся — и готово!'),
      ('📊', 'Следуйте своему персональному плану калорий', 'Мы создали персональный план специально для вас на основе ваших данных.'),
      ('⚖️', 'Поддерживайте баланс макроэлементов', 'Соблюдайте баланс белков, жиров и углеводов, чтобы оставаться на пути к цели.'),
    ] : [
      ('🍽️', 'Eat what you love', 'Find delicious and filling foods that help you reach your goals.'),
      ('📸', 'Easy food tracking', 'Take a photo, it gets recognized — done!'),
      ('📊', 'Follow your personal calorie plan', 'We built a personal plan just for you based on your data.'),
      ('⚖️', 'Balance your macronutrients', 'Keep protein, fat, and carbs balanced to stay on track.'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OBColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (i > 0) const Divider(height: 20, color: OBColors.border),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Citation links ────────────────────────────────────────────────────────────

class _CitationLinks extends StatelessWidget {
  final bool isRu;
  const _CitationLinks({required this.isRu});

  static const _harvardUrl = 'https://www.health.harvard.edu/diet-and-weight-loss/calorie-counting-made-easy';
  static const _usdaUrl = 'https://www.dietaryguidelines.gov/';
  static const _mifflinUrl = 'https://pubmed.ncbi.nlm.nih.gov/2305711/';

  @override
  Widget build(BuildContext context) {
    final links = isRu ? [
      ('Подсчёт калорий стал проще - Harvard', _harvardUrl),
      ('Рекомендации по питанию на день - USDA', _usdaUrl),
      ('Mifflin-St Jeor для специалистов по питанию', _mifflinUrl),
    ] : [
      ('Calorie counting made easy - Harvard', _harvardUrl),
      ('Daily dietary guidelines - USDA', _usdaUrl),
      ('Mifflin-St Jeor for nutrition specialists', _mifflinUrl),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: links.map((link) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(link.$2), mode: LaunchMode.externalApplication),
          child: Text(
            '— ${link.$1}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF3B82F6),
              decoration: TextDecoration.underline,
              height: 1.4,
            ),
          ),
        ),
      )).toList(),
    );
  }
}

enum _PlanDirection { gain, lose, maintain }

// ── Weight forecast chart ─────────────────────────────────────────────────────

class _WeightChart extends StatelessWidget {
  final CalculationResult calc;
  final AppLocalizations l10n;
  const _WeightChart({required this.calc, required this.l10n});

  List<FlSpot> _buildSpots() {
    if (calc.chartData != null && (calc.chartData as List).isNotEmpty) {
      final list = calc.chartData as List;
      final spots = <FlSpot>[];
      for (final item in list) {
        if (item is Map) {
          final day = (item['day'] as num?)?.toDouble();
          final weight = (item['weight'] as num?)?.toDouble();
          if (day != null && weight != null) {
            spots.add(FlSpot(day, weight));
          }
        }
      }
      if (spots.isNotEmpty) return spots;
    }

    final targetW = calc.targetWeight;
    final deficit = calc.tdee - calc.targetCalories;

    if (deficit > 0 && calc.daysToGoal != null && targetW != null) {
      final days = calc.daysToGoal!.toDouble();
      final totalKgLoss = deficit * days / 7700.0;
      final startW = targetW + totalKgLoss;
      const steps = 6;
      return List.generate(steps + 1, (i) {
        final t = i / steps;
        return FlSpot(days * t, startW - totalKgLoss * t);
      });
    }

    if (deficit > 0 && targetW != null) {
      const projDays = 90.0;
      final totalKgLoss = deficit * projDays / 7700.0;
      final startW = targetW + totalKgLoss;
      const steps = 6;
      return List.generate(steps + 1, (i) {
        final t = i / steps;
        return FlSpot(projDays * t, startW - totalKgLoss * t);
      });
    }

    final surplus = calc.targetCalories - calc.tdee;
    if (surplus > 0 && targetW != null) {
      final days = calc.daysToGoal != null ? calc.daysToGoal!.toDouble() : 90.0;
      final totalKgGain = surplus * days / 7700.0;
      final startW = targetW - totalKgGain;
      const steps = 6;
      return List.generate(steps + 1, (i) {
        final t = i / steps;
        return FlSpot(days * t, startW + totalKgGain * t);
      });
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    if (spots.isEmpty) return const SizedBox.shrink();

    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final isGain = calc.targetCalories > calc.tdee;
    final lineColor = isGain ? const Color(0xFF3B82F6) : OBColors.pink;

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY).clamp(0.5, double.infinity) * 0.2;

    final chartTitle = isGain
        ? (isRu ? 'Прогноз набора массы' : 'Muscle gain forecast')
        : l10n.wg_weight_forecast;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OBColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              chartTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: minY - yPad,
                maxY: maxY + yPad,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: OBColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, meta) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, meta) {
                        final day = v.toInt();
                        if (day == 0) {
                          return Text(l10n.wg_now,
                              style: const TextStyle(fontSize: 9, color: AppColors.textMuted));
                        }
                        final maxDay = spots.last.x.toInt();
                        if (day == maxDay) {
                          return Text('${day}d',
                              style: const TextStyle(fontSize: 9, color: AppColors.textMuted));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, _) =>
                          spot.x == spots.first.x || spot.x == spots.last.x,
                      getDotPainter: (a, b, c, d) => FlDotCirclePainter(
                        radius: 4,
                        color: lineColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          lineColor.withValues(alpha: 0.18),
                          lineColor.withValues(alpha: 0.0),
                        ],
                      ),
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
