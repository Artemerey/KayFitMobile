import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/models/ingredient_v2.dart';
import '../../../shared/models/nutrients_v2.dart';
import '../../../shared/theme/kayfit2_theme.dart';

// ── Macro ring colors ──────────────────────────────────────────────────────────

const _kcalColor = K2Colors.accent; // Apple blue
const _proteinColor = Color(0xFF22C55E); // green
const _fatColor = Color(0xFFF59E0B); // amber
const _carbsColor = Color(0xFF8B5CF6); // purple

// ── Public widget ─────────────────────────────────────────────────────────────

/// Hero section: 4 decorative macro circles + optional glycemic-index badge.
class KF2HeroTotal extends StatelessWidget {
  const KF2HeroTotal({
    super.key,
    required this.totals,
    required this.theme,
    this.items = const [],
  });

  final NutrientsV2 totals;
  final K2Theme theme;

  /// Used to compute the average glycemic index badge.
  final List<IngredientV2> items;

  // ── GI computation ───────────────────────────────────────────────────────

  ({int gi, String category})? _avgGi() {
    final giItems = items
        .where((i) => i.nutrientsPer100g.glycemicIndex != null)
        .toList();
    if (giItems.isEmpty) return null;
    final sum = giItems.fold<int>(
      0,
      (s, i) => s + i.nutrientsPer100g.glycemicIndex!,
    );
    final avg = (sum / giItems.length).round();
    final category = avg < 55
        ? 'Low'
        : avg < 70
            ? 'Med'
            : 'High';
    return (gi: avg, category: category);
  }

  @override
  Widget build(BuildContext context) {
    final gi = _avgGi();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "TOTAL" label + optional GI badge ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontFamily: K2Fonts.sans,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: theme.fgMute,
                ),
              ),
              if (gi != null) ...[
                const SizedBox(width: 10),
                _GiBadge(gi: gi.gi, category: gi.category),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // ── Four macro circles ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MacroCircle(
                value: totals.calories.toStringAsFixed(0),
                unit: 'kcal',
                label: 'kcal',
                color: _kcalColor,
                theme: theme,
              ),
              _MacroCircle(
                value: totals.protein.toStringAsFixed(0),
                unit: 'g',
                label: 'Protein',
                color: _proteinColor,
                theme: theme,
              ),
              _MacroCircle(
                value: totals.fat.toStringAsFixed(0),
                unit: 'g',
                label: 'Fat',
                color: _fatColor,
                theme: theme,
              ),
              _MacroCircle(
                value: totals.carbs.toStringAsFixed(0),
                unit: 'g',
                label: 'Carbs',
                color: _carbsColor,
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Glycemic index badge ──────────────────────────────────────────────────────

class _GiBadge extends StatelessWidget {
  const _GiBadge({required this.gi, required this.category});

  final int gi;
  final String category;

  Color get _bg {
    if (gi < 55) return const Color(0xFF22C55E);
    if (gi < 70) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bg.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        'GI $gi · $category',
        style: TextStyle(
          fontFamily: K2Fonts.mono,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: _bg,
        ),
      ),
    );
  }
}

// ── Single macro circle ───────────────────────────────────────────────────────

class _MacroCircle extends StatelessWidget {
  const _MacroCircle({
    required this.value,
    required this.unit,
    required this.label,
    required this.color,
    required this.theme,
  });

  final String value;
  final String unit;
  final String label;
  final Color color;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: CustomPaint(
            painter: _MacroRingPainter(color: color),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: K2Fonts.mono,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      letterSpacing: -0.5,
                      color: theme.fg,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    unit,
                    style: TextStyle(
                      fontFamily: K2Fonts.mono,
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: theme.fgMute,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: K2Fonts.sans,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.fgDim,
          ),
        ),
      ],
    );
  }
}

// ── Ring painter — decorative full circle, no progress ────────────────────────

class _MacroRingPainter extends CustomPainter {
  const _MacroRingPainter({required this.color});

  final Color color;

  static const _strokeWidth = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track: full circle, muted
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Fill: full solid circle (decorative, progress = 1.0)
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_MacroRingPainter old) => old.color != color;
}
