// Kayfit 2.0 — 4-ring Apple Activity-style summary widget.
//
// Mirrors the SVG implementation from the Claude Design handoff
// (specs/kayfit_2.0/source_handoff/project/kayfit-app.jsx, function
// SummaryAppleRings).
//
// Four concentric rings, outer → inner: kcal · protein · carbs · fat.
// Each ring uses a linear-gradient stroke (from → to) and a soft track.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/kayfit2_theme.dart';

@immutable
class KayfitRingsValues {
  const KayfitRingsValues({
    required this.kcal,
    required this.kcalGoal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.fat,
    required this.fatGoal,
  });

  final double kcal;
  final double kcalGoal;
  final double protein;
  final double proteinGoal;
  final double carbs;
  final double carbsGoal;
  final double fat;
  final double fatGoal;

  double _ratio(double v, double g) =>
      g <= 0 ? 0 : math.min(1.0, math.max(0.0, v / g));

  double get kcalRatio => _ratio(kcal, kcalGoal);
  double get proteinRatio => _ratio(protein, proteinGoal);
  double get carbsRatio => _ratio(carbs, carbsGoal);
  double get fatRatio => _ratio(fat, fatGoal);
}

class KayfitRings extends StatelessWidget {
  const KayfitRings({
    super.key,
    required this.values,
    required this.theme,
    this.size = 140,
    this.strokeWidth = 10,
  });

  final KayfitRingsValues values;
  final K2Theme theme;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KayfitRingsPainter(
          values: values,
          isDark: theme.isDark,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _KayfitRingsPainter extends CustomPainter {
  _KayfitRingsPainter({
    required this.values,
    required this.isDark,
    required this.strokeWidth,
  });

  final KayfitRingsValues values;
  final bool isDark;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Radii match the JSX prototype: outer to inner.
    // Original: [60, 48, 36, 24] inside a 140×140 svg.
    // We scale proportionally to whatever size the widget got.
    final scale = size.width / 140.0;
    final radii = [60.0, 48.0, 36.0, 24.0].map((r) => r * scale).toList();

    final ringColors = [
      K2RingColors.kcal,
      K2RingColors.protein,
      K2RingColors.carbs,
      K2RingColors.fat,
    ];
    final ratios = [
      values.kcalRatio,
      values.proteinRatio,
      values.carbsRatio,
      values.fatRatio,
    ];

    for (var i = 0; i < 4; i++) {
      _drawRing(
        canvas,
        center: Offset(cx, cy),
        radius: radii[i],
        ratio: ratios[i],
        colors: ringColors[i],
      );
    }
  }

  void _drawRing(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double ratio,
    required K2RingColors colors,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (full circle, soft tint).
    final trackPaint = Paint()
      ..color = isDark ? colors.trackDark : colors.trackLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (ratio <= 0) return;

    // Foreground arc with linear gradient.
    final shader = LinearGradient(
      colors: [colors.from, colors.to],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);

    final arcPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start at 12 o'clock (rotate -90°). Sweep proportionally to ratio.
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * ratio;
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _KayfitRingsPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.isDark != isDark ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Right-side legend rows that pair with [KayfitRings].
/// Renders 4 rows: kcal / protein / carbs / fat, each with a dot in ring color
/// and a `<value><unit>/<goal><unit>` label in mono font.
class KayfitRingsLegend extends StatelessWidget {
  const KayfitRingsLegend({
    super.key,
    required this.values,
    required this.theme,
  });

  final KayfitRingsValues values;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final rows = <_LegendRow>[
      _LegendRow(
        label: 'kcal',
        value: values.kcal.toInt().toString(),
        goal: values.kcalGoal.toInt().toString(),
        unit: '',
        color: K2RingColors.kcal.to,
      ),
      _LegendRow(
        label: 'protein',
        value: values.protein.toInt().toString(),
        goal: values.proteinGoal.toInt().toString(),
        unit: 'g',
        color: K2RingColors.protein.to,
      ),
      _LegendRow(
        label: 'carbs',
        value: values.carbs.toInt().toString(),
        goal: values.carbsGoal.toInt().toString(),
        unit: 'g',
        color: K2RingColors.carbs.to,
      ),
      _LegendRow(
        label: 'fat',
        value: values.fat.toInt().toString(),
        goal: values.fatGoal.toInt().toString(),
        unit: 'g',
        color: K2RingColors.fat.to,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows) ...[
          _legendRow(r),
          const SizedBox(height: 7),
        ],
      ],
    );
  }

  Widget _legendRow(_LegendRow r) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            r.label,
            style: TextStyle(
              fontSize: 10,
              color: theme.fgDim,
              letterSpacing: 0.8,
              fontFamily: K2Fonts.sans,
            ),
            textWidthBasis: TextWidthBasis.parent,
          ),
        ),
        const Spacer(),
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontFamily: K2Fonts.mono,
              fontSize: 13,
              color: theme.fg,
            ),
            children: [
              TextSpan(text: '${r.value}${r.unit}'),
              TextSpan(
                text: '/${r.goal}${r.unit}',
                style: TextStyle(
                  color: theme.fgMute,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

@immutable
class _LegendRow {
  const _LegendRow({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String goal;
  final String unit;
  final Color color;
}

/// Convenience composite: rings + legend in a row, matching the JSX layout.
class KayfitRingsSummary extends StatelessWidget {
  const KayfitRingsSummary({
    super.key,
    required this.values,
    required this.theme,
    this.ringSize = 140,
    this.gap = 18,
  });

  final KayfitRingsValues values;
  final K2Theme theme;
  final double ringSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        KayfitRings(values: values, theme: theme, size: ringSize),
        SizedBox(width: gap),
        Expanded(
          child: KayfitRingsLegend(values: values, theme: theme),
        ),
      ],
    );
  }
}
