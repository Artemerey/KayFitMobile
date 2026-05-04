import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/models/calculation_result.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/i18n/generated/app_localizations.dart';

/// Shared plan-result view used by WayToGoalScreen and OnboardingScreen (_ResultStep).
/// CTA buttons are owned by the parent (sticky bottom in WayToGoalScreen,
/// onboarding scaffold in onboarding) — this widget renders only the scroll
/// content. [bottomPadding] reserves space below the last card so a fixed
/// footer outside this widget does not occlude content.
/// [currentWeight] enables maintenance detection: when |current - target| < 0.5 kg
/// the chart and days-to-goal block are hidden in favour of a maintain message.
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
    // Detect by calorie target vs TDEE first — handles muscle-gain or
    // recomposition where current_weight == target_weight but the user
    // is actually on a surplus/deficit.
    final calDelta = (calc.targetCalories - calc.tdee).abs();
    if (calDelta > 80) return false; // significant surplus or deficit
    // Otherwise fall back to weight delta.
    final tw = calc.targetWeight;
    final cw = currentWeight;
    if (tw == null || cw == null) return false;
    return (tw - cw).abs() < 0.5;
  }

  /// Direction of the plan: surplus / deficit / maintain.
  /// Computed from calorie delta relative to TDEE (matches _isMaintain).
  _PlanDirection get _direction {
    final delta = calc.targetCalories - calc.tdee;
    if (delta > 80) return _PlanDirection.gain;
    if (delta < -80) return _PlanDirection.lose;
    return _PlanDirection.maintain;
  }

  /// Local fallback for the personalised banner: shown when the backend
  /// hasn't returned `personalizedPlan` yet (PR-4-BE not deployed).
  /// Direction-aware copy + protein recommendation from current weight.
  String _localPlanFallback(bool isRu) {
    final cw = currentWeight ?? calc.targetWeight ?? 70;
    // Roughly 1.6 g/kg for general goals, 1.8–2.0 g/kg for muscle gain.
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

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final maintain = _isMaintain;
    final maintainTitle = isRu ? 'Поддержание веса' : 'Weight maintenance';
    final maintainBody = isRu
        ? 'Текущий и целевой вес совпадают. Эти калории помогут удержать форму без потери и набора.'
        : 'Your current and target weight match. These calories will keep you steady — no loss, no gain.';

    return ListView(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding),
      children: [
        const SizedBox(height: 24),

        // ── Personalized AI plan banner (focal point — always visible) ──────
        // Server text wins; otherwise we compute a direction-aware fallback
        // locally so the focal banner is never empty.
        _PersonalPlanBanner(
          text: (calc.personalizedPlan != null &&
                  calc.personalizedPlan!.isNotEmpty)
              ? calc.personalizedPlan!
              : _localPlanFallback(isRu),
          isRu: isRu,
        ),
        const SizedBox(height: 12),

        // ── Hero gradient card ───────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: OBColors.gradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: OBColors.buttonShadow,
          ),
          child: Column(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                l10n.wg_plan_ready,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.wg_personal_calc,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Text(
                      calc.targetCalories.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: OBColors.pink,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      l10n.wg_kcal_day,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Macros card ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.wg_macronutrients,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MacroChip(
                    label: l10n.macro_protein,
                    value: calc.protein,
                    color: AppColors.accent,
                    bgColor: AppColors.accentSoft,
                    unit: l10n.macro_g,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: l10n.macro_fat,
                    value: calc.fat,
                    color: AppColors.warm,
                    bgColor: AppColors.warmSoft,
                    unit: l10n.macro_g,
                  ),
                  const SizedBox(width: 8),
                  _MacroChip(
                    label: l10n.macro_carbs,
                    value: calc.carbs,
                    color: AppColors.support,
                    bgColor: AppColors.supportSoft,
                    unit: l10n.macro_g,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Scientific source citation (prominent placement) ─────────────
        _CitationCard(l10n: l10n),

        if (maintain) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.balance_rounded,
                    size: 22, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(maintainTitle,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text)),
                      const SizedBox(height: 4),
                      Text(maintainBody,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (calc.daysToGoal != null || calc.targetWeight != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                if (calc.daysToGoal != null)
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: l10n.wg_days_to_goal(calc.daysToGoal as int),
                  ),
                if (calc.daysToGoal != null && calc.targetWeight != null)
                  const SizedBox(height: 10),
                if (calc.targetWeight != null)
                  _InfoRow(
                    icon: Icons.flag_outlined,
                    text: l10n.wg_target_weight_val(
                        (calc.targetWeight as double).toStringAsFixed(1)),
                  ),
              ],
            ),
          ),
        ],

        // ── Weight forecast chart (skipped in maintain mode) ─────────────────
        if (!maintain) ...[
          const SizedBox(height: 12),
          _WeightChart(calc: calc, l10n: l10n),
        ],

        const SizedBox(height: 12),

        // ── How to reach card ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.wg_how_to_reach,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const SizedBox(height: 14),
              _FeatureRow(
                  emoji: '📸',
                  title: l10n.wg_feature_photo_title,
                  desc: l10n.wg_feature_photo_desc),
              const SizedBox(height: 12),
              _FeatureRow(
                  emoji: '🎤',
                  title: l10n.wg_feature_voice_title,
                  desc: l10n.wg_feature_voice_desc),
              const SizedBox(height: 12),
              _FeatureRow(
                  emoji: '📊',
                  title: l10n.wg_feature_track_title,
                  desc: l10n.wg_feature_track_desc),
            ],
          ),
        ),

        const SizedBox(height: 28),
      ],
    );
  }
}

// ── Personalized AI plan banner ─────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.35,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PlanDirection { gain, lose, maintain }

// ── Macro chip ──────────────────────────────────────────────────────────────

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final Color bgColor;
  final String unit;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '${value.toStringAsFixed(0)}$unit',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Info row ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: OBColors.pink),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 15, color: AppColors.text)),
      ],
    );
  }
}

// ── Feature row ─────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;

  const _FeatureRow({required this.emoji, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: OBColors.pinkSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Scientific source citation ───────────────────────────────────────────────

class _CitationCard extends StatelessWidget {
  final AppLocalizations l10n;
  const _CitationCard({required this.l10n});

  static const _pubmedUrl = 'https://pubmed.ncbi.nlm.nih.gov/2305711/';
  static const _whoUrl = 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet';

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    final citationText = isRu
        ? 'Расчёт калорий основан на формуле Mifflin-St Jeor (Mifflin MD et al., The American Journal of Clinical Nutrition, 1990). Коэффициенты активности — ВОЗ/ФАО. Нормы макронутриентов — по рекомендациям ВОЗ.'
        : 'Calorie calculation is based on the Mifflin-St Jeor formula (Mifflin MD et al., The American Journal of Clinical Nutrition, 1990). Activity coefficients from WHO/FAO. Macronutrient ranges per WHO dietary guidelines.';
    final pubmedLabel = isRu ? 'PubMed' : 'PubMed';
    final whoLabel = isRu ? 'Рекомендации ВОЗ' : 'WHO Guidelines';
    final disclaimerText = isRu
        ? '\n\nЭто информационный расчёт. Проконсультируйтесь с врачом перед изменением рациона.'
        : '\n\nThis is an informational estimate. Consult a healthcare professional before changing your diet.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
                children: [
                  TextSpan(text: '$citationText\n'),
                  TextSpan(
                    text: pubmedLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3B82F6),
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                            Uri.parse(_pubmedUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                  ),
                  const TextSpan(text: '  ·  '),
                  TextSpan(
                    text: whoLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF3B82F6),
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                            Uri.parse(_whoUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                  ),
                  TextSpan(text: disclaimerText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weight forecast chart ────────────────────────────────────────────────────

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

    if (deficit > 0) {
      // Weight loss scenario
      if (calc.daysToGoal != null && targetW != null) {
        final days = calc.daysToGoal!.toDouble();
        final totalKgLoss = deficit * days / 7700.0;
        final startW = targetW + totalKgLoss;
        const steps = 6;
        return List.generate(steps + 1, (i) {
          final t = i / steps;
          return FlSpot(days * t, startW - totalKgLoss * t);
        });
      }

      if (targetW != null) {
        const projDays = 90.0;
        final totalKgLoss = deficit * projDays / 7700.0;
        final startW = targetW + totalKgLoss;
        const steps = 6;
        return List.generate(steps + 1, (i) {
          final t = i / steps;
          return FlSpot(projDays * t, startW - totalKgLoss * t);
        });
      }
    } else {
      // Weight gain / muscle surplus scenario
      final surplus = calc.targetCalories - calc.tdee;
      if (surplus > 0) {
        if (calc.daysToGoal != null && targetW != null) {
          final days = calc.daysToGoal!.toDouble();
          final totalKgGain = surplus * days / 7700.0;
          final startW = targetW - totalKgGain;
          const steps = 6;
          return List.generate(steps + 1, (i) {
            final t = i / steps;
            return FlSpot(days * t, startW + totalKgGain * t);
          });
        }

        if (targetW != null) {
          const projDays = 90.0;
          final totalKgGain = surplus * projDays / 7700.0;
          final startW = targetW - totalKgGain;
          const steps = 6;
          return List.generate(steps + 1, (i) {
            final t = i / steps;
            return FlSpot(projDays * t, startW + totalKgGain * t);
          });
        }
      }
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    if (spots.isEmpty) return const SizedBox.shrink();

    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final isGain = calc.targetCalories > calc.tdee;
    final lineColor = isGain ? AppColors.accent : OBColors.pink;

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
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              chartTitle,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: minY - yPad,
                maxY: maxY + yPad,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, meta) => Text(
                        v.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
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
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textMuted));
                        }
                        final maxDay = spots.last.x.toInt();
                        if (day == maxDay) {
                          return Text('${day}d',
                              style: const TextStyle(
                                  fontSize: 9, color: AppColors.textMuted));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
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
                          lineColor.withValues(alpha: 0.2),
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
