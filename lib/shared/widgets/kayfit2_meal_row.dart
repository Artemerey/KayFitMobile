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

import '../../core/i18n/generated/app_localizations.dart';
import '../models/k2_meal_row_data.dart';
import '../theme/kayfit2_theme.dart';
import 'kayfit2_meal_photo.dart';

/// Displays a single [K2MealRowData] entry styled to the Kayfit 2.0 spec.
///
/// Supports [dense] mode (12 pt vertical padding) and normal mode (14 pt).
/// Tap is surfaced via the optional [onTap] callback.
///
/// When [onWeightChange] is supplied AND the row has a known weight, the
/// weight is rendered as a tappable pill that morphs into an inline
/// `TextField` on tap. On commit the callback is invoked with the new value
/// in grams — the parent is responsible for PATCH-ing the meal and
/// recomputing macros proportionally.
class Kayfit2MealRow extends StatelessWidget {
  const Kayfit2MealRow({
    super.key,
    required this.meal,
    required this.theme,
    this.dense = false,
    this.onTap,
    this.onLongPress,
    this.onMore,
    this.onWeightChange,
  });

  /// Meal data to render.
  final K2MealRowData meal;

  /// Kayfit 2.0 design token bundle.
  final K2Theme theme;

  /// When true the row uses 12 pt vertical padding; otherwise 14 pt.
  final bool dense;

  /// Called when the user taps the row. Null disables the tap ripple.
  final VoidCallback? onTap;

  /// Called when the user long-presses the row. Used by the journal to
  /// surface the "Copy to another date" action — keeps the primary tap
  /// gesture available for the meal-edit screen.
  final VoidCallback? onLongPress;

  /// When non-null, a ⋮ icon button is rendered at the trailing edge of the
  /// row and calls this callback on press (same action as long-press).
  final VoidCallback? onMore;

  /// Called when the user commits an inline weight edit on this row.
  /// Receives the new weight in grams. Null disables the inline edit
  /// (the pill is still shown read-only when [K2MealRowData.weightGrams]
  /// is non-null).
  final ValueChanged<double>? onWeightChange;

  @override
  Widget build(BuildContext context) {
    final vertPad = dense ? 12.0 : 14.0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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

            // ── CENTER: type · name · weight pill + macros ─────────────────
            Expanded(
              child: _CenterColumn(
                meal: meal,
                theme: theme,
                onWeightChange: onWeightChange,
              ),
            ),

            const SizedBox(width: 12),

            // ── RIGHT: kcal number + label ─────────────────────────────────
            _KcalColumn(meal: meal, theme: theme),

            // ── FAR RIGHT: ⋮ copy button (optional) ───────────────────────
            if (onMore != null) ...[
              const SizedBox(width: 2),
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.content_copy_rounded,
                    size: 16,
                    color: theme.fgMute,
                  ),
                  onPressed: onMore,
                ),
              ),
            ],
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
        seed: meal.photoSeed,
        photoUrl: meal.photoUrl,
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
  const _CenterColumn({
    required this.meal,
    required this.theme,
    required this.onWeightChange,
  });

  final K2MealRowData meal;
  final K2Theme theme;
  final ValueChanged<double>? onWeightChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (meal.hasPhoto)
          Text(
            meal.time,
            style: TextStyle(
              fontFamily: K2Fonts.mono,
              fontSize: 10,
              color: theme.fgMute,
              height: 1.2,
            ),
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
        const SizedBox(height: 6),
        // Weight pill + macro line, side by side.
        // The pill is ALWAYS rendered (when onWeightChange is wired up). When
        // [meal.weightGrams] is null we show a placeholder ("+ масса") so the
        // user can set the weight for the first time on legacy meals.
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (onWeightChange != null || meal.weightGrams != null) ...[
              _WeightPill(
                grams: meal.weightGrams,
                theme: theme,
                onCommit: onWeightChange,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: _MacroLine(meal: meal, theme: theme)),
          ],
        ),
      ],
    );
  }
}

// ─── Inline-editable weight pill ─────────────────────────────────────────────
//
// Tap → morphs into a TextField with the current weight pre-selected. On
// submit / focus-loss, commits the new value via [onCommit]. When [onCommit]
// is null the pill is read-only (still visible).

class _WeightPill extends StatefulWidget {
  const _WeightPill({
    required this.grams,
    required this.theme,
    required this.onCommit,
  });

  /// Current weight in grams. Null means "not set yet" — the pill renders as
  /// a tappable placeholder ("+ масса") inviting the user to set it.
  final double? grams;
  final K2Theme theme;
  final ValueChanged<double>? onCommit;

  @override
  State<_WeightPill> createState() => _WeightPillState();
}

class _WeightPillState extends State<_WeightPill> {
  final _focus = FocusNode();
  late final TextEditingController _ctrl;
  bool _editing = false;

  String _displayText(double? g) => g == null ? '' : g.toStringAsFixed(0);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _displayText(widget.grams));
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _WeightPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.grams != widget.grams) {
      _ctrl.text = _displayText(widget.grams);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus && _editing) _commit();
  }

  void _startEdit() {
    if (widget.onCommit == null) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _ctrl.text.length,
      );
    });
  }

  void _commit() {
    final v = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    final cur = widget.grams;
    if (v == null || v <= 0) {
      _ctrl.text = _displayText(cur);
    } else if (cur == null || (v - cur).abs() > 0.5) {
      widget.onCommit?.call(v);
    }
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final accent = K2Colors.accent;
    final editable = widget.onCommit != null;
    final grams = widget.grams;
    final isPlaceholder = grams == null;

    if (_editing) {
      // iOS number pad has no "Done" key, so we surface a tap-target check
      // mark inside the pill to commit. Focus-loss commit still works for
      // taps outside the pill on Android.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 70,
            height: 26,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              textAlign: TextAlign.center,
              onSubmitted: (_) => _commit(),
              style: TextStyle(
                fontSize: 12,
                color: t.fg,
                fontFamily: K2Fonts.mono,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: t.fgMute,
                  fontFamily: K2Fonts.mono,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide(color: accent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide(color: accent, width: 1.5),
                ),
                suffixText: 'г',
                suffixStyle: TextStyle(
                  fontSize: 10,
                  color: t.fgMute,
                  fontFamily: K2Fonts.mono,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _commit,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.check_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
        ],
      );
    }

    final label = isPlaceholder ? '+ масса' : '${grams.toStringAsFixed(0)} г';
    final borderColor = editable
        ? accent.withValues(alpha: isPlaceholder ? 0.7 : 0.4)
        : t.border;
    final bgColor = isPlaceholder
        ? accent.withValues(alpha: 0.06)
        : t.bg;

    return GestureDetector(
      onTap: editable ? _startEdit : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: borderColor,
            width: isPlaceholder ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isPlaceholder ? accent : t.fg,
                fontFamily: K2Fonts.mono,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (editable && !isPlaceholder) ...[
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 11, color: accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({required this.meal, required this.theme});

  final K2MealRowData meal;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          TextSpan(text: '${l10n.macro_protein_abbr} ${meal.protein}'),
          TextSpan(text: '  ·  ', style: sepStyle),
          TextSpan(text: '${l10n.macro_fat_abbr} ${meal.fat}'),
          TextSpan(text: '  ·  ', style: sepStyle),
          TextSpan(text: '${l10n.macro_carbs_abbr} ${meal.carbs}'),
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
    final l10n = AppLocalizations.of(context)!;
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
          l10n.macro_kcal.toUpperCase(),
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
