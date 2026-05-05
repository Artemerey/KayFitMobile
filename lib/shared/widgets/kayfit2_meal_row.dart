// KF2-FOUND-4 — Meal row widget for Kayfit 2.0.
//
// Renders a single meal entry in the Journal list.
// Layout (left → right):
//   LEFT  — [Kayfit2MealPhoto] thumbnail  ─OR─  time + source-label column
//   CENTER — meal type badge + name + macro string  (flex 1)
//   RIGHT  — kcal number + "KCAL" label
//
// Spec: specs/kayfit_2.0/source_handoff/project/kayfit-app.jsx lines 453-490.

import 'package:flutter/material.dart';

import '../models/k2_meal_row_data.dart';
import '../theme/kayfit2_theme.dart';
import 'kayfit2_meal_photo.dart';

/// Displays a single [K2MealRowData] entry styled to the Kayfit 2.0 spec.
///
/// Supports [dense] mode (12 pt vertical padding) and normal mode (14 pt).
/// Tap is surfaced via the optional [onTap] callback.
class Kayfit2MealRow extends StatelessWidget {
  const Kayfit2MealRow({
    super.key,
    required this.meal,
    required this.theme,
    this.dense = false,
    this.onTap,
  });

  /// Meal data to render.
  final K2MealRowData meal;

  /// Kayfit 2.0 design token bundle.
  final K2Theme theme;

  /// When true the row uses 12 pt vertical padding; otherwise 14 pt.
  final bool dense;

  /// Called when the user taps the row. Null disables the tap ripple.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final vertPad = dense ? 12.0 : 14.0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: vertPad),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.hairline, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT: photo thumbnail or time / source column ──────────────
            _LeftColumn(meal: meal, theme: theme),

            const SizedBox(width: 12),

            // ── CENTER: type · name · macros ───────────────────────────────
            Expanded(child: _CenterColumn(meal: meal, theme: theme)),

            const SizedBox(width: 12),

            // ── RIGHT: kcal number + label ─────────────────────────────────
            _KcalColumn(meal: meal, theme: theme),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────────────────────

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.meal, required this.theme});

  final K2MealRowData meal;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    if (meal.hasPhoto) {
      return Kayfit2MealPhoto(
        seed: meal.photoSeed!,
        theme: theme,
      );
    }

    // No photo: compact time + source-label column
    return SizedBox(
      width: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            meal.time,
            style: TextStyle(
              fontFamily: K2Fonts.mono,
              fontSize: 11,
              color: theme.fgDim,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            meal.source.label,
            style: TextStyle(
              fontSize: 9,
              color: theme.fgMute,
              letterSpacing: 0.6,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterColumn extends StatelessWidget {
  const _CenterColumn({required this.meal, required this.theme});

  final K2MealRowData meal;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Type badge row (+ time when photo row)
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              meal.type.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: theme.fgMute,
                letterSpacing: 1,
                height: 1.2,
              ),
            ),
            if (meal.hasPhoto) ...[
              const SizedBox(width: 6),
              Text(
                '· ${meal.time}',
                style: TextStyle(
                  fontFamily: K2Fonts.mono,
                  fontSize: 10,
                  color: theme.fgMute,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        // Meal name
        Text(
          meal.name,
          style: TextStyle(
            fontSize: 14,
            color: theme.fg,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Macro string: P 12 · F 6 · C 54
        _MacroLine(meal: meal, theme: theme),
      ],
    );
  }
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({required this.meal, required this.theme});

  final K2MealRowData meal;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final dimStyle = TextStyle(
      fontFamily: K2Fonts.mono,
      fontSize: 11,
      color: theme.fgDim,
      height: 1.2,
    );
    final sepStyle = dimStyle.copyWith(
      color: theme.fgDim.withValues(alpha: 0.4),
    );

    return Text.rich(
      TextSpan(
        style: dimStyle,
        children: [
          TextSpan(text: 'P ${meal.protein}'),
          TextSpan(text: '  ·  ', style: sepStyle),
          TextSpan(text: 'F ${meal.fat}'),
          TextSpan(text: '  ·  ', style: sepStyle),
          TextSpan(text: 'C ${meal.carbs}'),
        ],
      ),
    );
  }
}

class _KcalColumn extends StatelessWidget {
  const _KcalColumn({required this.meal, required this.theme});

  final K2MealRowData meal;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${meal.kcal}',
          style: TextStyle(
            fontFamily: K2Fonts.mono,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: theme.fg,
            letterSpacing: -0.4,
            height: 1.1,
          ),
        ),
        Text(
          'KCAL',
          style: TextStyle(
            fontSize: 9,
            color: theme.fgMute,
            letterSpacing: 0.8,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
