import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/generated/app_localizations.dart';
import '../../../shared/models/ingredient_v2.dart';
import '../../../shared/models/nutrients_v2.dart';
import '../../../shared/theme/kayfit2_theme.dart';
import '../../../shared/widgets/nutrient_detail_sheet.dart';

/// A single ingredient row in the KF2 preview-edit sheet.
///
/// Shows: item name + kcal on the first row; weight pill + P·F·C on the
/// second row; ✏ and × action icons on the right.
///
/// Tapping ✏ reveals inline P/F/C TextFields that recalculate kcal by the
/// 4/9/4 rule. Tapping × removes the item (caller handles list mutation).
class KF2ItemTile extends StatefulWidget {
  const KF2ItemTile({
    super.key,
    required this.item,
    required this.onWeightChanged,
    required this.onMacrosChanged,
    required this.onCaloriesChanged,
    required this.onDelete,
    required this.theme,
  });

  final IngredientV2 item;
  final ValueChanged<double> onWeightChanged;

  /// Called with (protein, fat, carbs) in grams when the user edits macros.
  final void Function(double p, double f, double c) onMacrosChanged;

  /// Called with the new calories value when the user edits kcal directly.
  final ValueChanged<double> onCaloriesChanged;
  final VoidCallback onDelete;
  final K2Theme theme;

  @override
  State<KF2ItemTile> createState() => _KF2ItemTileState();
}

class _KF2ItemTileState extends State<KF2ItemTile> {
  late final TextEditingController _weightCtrl;
  late final FocusNode _weightFocus;

  late bool _editingMacros;
  bool _weightFocused = false;

  late final TextEditingController _proteinCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _caloriesCtrl;
  late final FocusNode _proteinFocus;
  late final FocusNode _fatFocus;
  late final FocusNode _carbsFocus;
  late final FocusNode _caloriesFocus;

  @override
  void initState() {
    super.initState();
    _editingMacros = widget.item.needsManualNutrition;
    final w = widget.item.weightGrams;
    _weightCtrl = TextEditingController(text: w.toStringAsFixed(0));
    _weightFocus = FocusNode()..addListener(_onWeightFocusChange);

    final n = widget.item.nutrientsTotal;
    _proteinCtrl =
        TextEditingController(text: n.protein.toStringAsFixed(1));
    _fatCtrl = TextEditingController(text: n.fat.toStringAsFixed(1));
    _carbsCtrl = TextEditingController(text: n.carbs.toStringAsFixed(1));
    _caloriesCtrl =
        TextEditingController(text: n.calories.toStringAsFixed(0));

    _proteinFocus = FocusNode();
    _fatFocus = FocusNode();
    _carbsFocus = FocusNode();
    _caloriesFocus = FocusNode();
  }

  @override
  void didUpdateWidget(KF2ItemTile old) {
    super.didUpdateWidget(old);
    // Keep weight field in sync when weight changes externally (e.g. from
    // another source), but preserve cursor position.
    if (old.item.weightGrams != widget.item.weightGrams &&
        !_weightFocus.hasFocus) {
      final newText = widget.item.weightGrams.toStringAsFixed(0);
      if (_weightCtrl.text != newText) {
        _weightCtrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    }
    // Keep macro fields in sync when macros change externally.
    if (!_editingMacros) {
      final n = widget.item.nutrientsTotal;
      _syncMacroField(_proteinCtrl, n.protein);
      _syncMacroField(_fatCtrl, n.fat);
      _syncMacroField(_carbsCtrl, n.carbs);
      _syncCaloriesField(n.calories);
    }
    // Edge-triggered: open macro editor when item transitions into the
    // "needs manual nutrition" state (e.g. after an undo that clears calories).
    final wasNeeded = old.item.needsManualNutrition;
    final isNeeded = widget.item.needsManualNutrition;
    if (!wasNeeded && isNeeded) {
      setState(() => _editingMacros = true);
    }
  }

  void _syncMacroField(TextEditingController ctrl, double value) {
    final newText = value.toStringAsFixed(1);
    if (ctrl.text != newText) {
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _syncCaloriesField(double value) {
    final newText = value.toStringAsFixed(0);
    if (_caloriesCtrl.text != newText && !_caloriesFocus.hasFocus) {
      _caloriesCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  @override
  void dispose() {
    _weightFocus
      ..removeListener(_onWeightFocusChange)
      ..dispose();
    _weightCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinFocus.dispose();
    _fatFocus.dispose();
    _carbsFocus.dispose();
    _caloriesFocus.dispose();
    super.dispose();
  }

  void _onWeightFocusChange() {
    final focused = _weightFocus.hasFocus;
    if (_weightFocused != focused) setState(() => _weightFocused = focused);
    if (!focused) {
      // Apply any pending value on focus loss (e.g. tap elsewhere).
      final w = double.tryParse(_weightCtrl.text.trim());
      if (w != null && w > 0 && w != widget.item.weightGrams) {
        widget.onWeightChanged(w);
      }
    }
  }

  void _onWeightChanged(String v) {
    // Apply immediately so _state in the parent sheet is always up to date.
    // This ensures that pressing Save right after typing uses the correct weight
    // rather than waiting for a debounce timer.
    final w = double.tryParse(v.trim());
    if (w != null && w > 0 && w != widget.item.weightGrams) {
      widget.onWeightChanged(w);
    }
  }

  void _onMacroChanged() {
    final p = double.tryParse(_proteinCtrl.text.trim()) ?? 0;
    final f = double.tryParse(_fatCtrl.text.trim()) ?? 0;
    final c = double.tryParse(_carbsCtrl.text.trim()) ?? 0;
    widget.onMacrosChanged(p.clamp(0, double.infinity),
        f.clamp(0, double.infinity), c.clamp(0, double.infinity));
    // Sync calories field to reflect recalculated value (4/9/4 rule).
    final recalc = p * 4 + f * 9 + c * 4;
    _syncCaloriesField(recalc);
  }

  void _onCaloriesChanged(String v) {
    final kcal = double.tryParse(v.trim());
    if (kcal != null && kcal >= 0) {
      widget.onCaloriesChanged(kcal);
    }
  }

  void _showDetailSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      builder: (_) => NutrientDetailSheet(
        name: widget.item.name,
        weightGrams: widget.item.weightGrams,
        per100g: widget.item.nutrientsPer100g,
        total: widget.item.nutrientsTotal,
        source: widget.item.source,
        sourceUrl: widget.item.sourceUrl,
      ),
    );
  }

  void _toggleMacroEdit() {
    setState(() => _editingMacros = !_editingMacros);
    if (_editingMacros) {
      Future.delayed(const Duration(milliseconds: 80),
          () => _proteinFocus.requestFocus());
    }
  }

  bool get _weightInvalid {
    final w = double.tryParse(_weightCtrl.text.trim());
    return w == null || w <= 0;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final n = item.nutrientsTotal;
    final t = widget.theme;
    final l10n = AppLocalizations.of(context)!;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: _showDetailSheet,
        child: Container(
          decoration: BoxDecoration(
            color: t.card,
            border: Border(
              bottom: BorderSide(color: t.hairline),
            ),
          ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: name · kcal · actions ────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontFamily: K2Fonts.sans,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: t.fg,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  n.calories.toStringAsFixed(0),
                  style: TextStyle(
                    fontFamily: K2Fonts.mono,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.fgDim,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _toggleMacroEdit,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: _editingMacros ? K2Colors.accent : t.fgMute,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onDelete();
                  },
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: K2Colors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _SourceBadge(source: item.source, theme: t),
            const SizedBox(height: 6),
            // ── Row 2: weight pill · apply button · P·F·C ────────────────
            Row(
              children: [
                _WeightPill(
                  ctrl: _weightCtrl,
                  focus: _weightFocus,
                  isInvalid: _weightInvalid,
                  onChanged: _onWeightChanged,
                  onSubmitted: (v) {
                    _onWeightChanged(v);
                    FocusScope.of(context).unfocus();
                  },
                  theme: t,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.macro_g,
                  style: TextStyle(
                    fontFamily: K2Fonts.mono,
                    fontSize: 12,
                    color: t.fgMute,
                  ),
                ),
                if (_weightFocused) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: K2Colors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ] else
                  const SizedBox(width: 10),
                if (!_weightFocused)
                  Text(
                    '${l10n.macro_protein_abbr} ${n.protein.toStringAsFixed(0)} · '
                    '${l10n.macro_fat_abbr} ${n.fat.toStringAsFixed(0)} · '
                    '${l10n.macro_carbs_abbr} ${n.carbs.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontFamily: K2Fonts.mono,
                      fontSize: 11,
                      color: t.fgMute,
                    ),
                  ),
              ],
            ),
            // ── Manual entry warning ─────────────────────────────────────
            if (item.needsManualNutrition) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() => _editingMacros = true),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 13, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      l10n.item_enter_nutrition_manually,
                      style: TextStyle(
                        fontFamily: K2Fonts.sans,
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // ── Macro inline edit ────────────────────────────────────────
            if (_editingMacros) ...[
              const SizedBox(height: 10),
              _KF2MacroInlineEdit(
                proteinCtrl: _proteinCtrl,
                fatCtrl: _fatCtrl,
                carbsCtrl: _carbsCtrl,
                caloriesCtrl: _caloriesCtrl,
                proteinFocus: _proteinFocus,
                fatFocus: _fatFocus,
                carbsFocus: _carbsFocus,
                caloriesFocus: _caloriesFocus,
                onMacrosChanged: _onMacroChanged,
                onCaloriesChanged: _onCaloriesChanged,
                onDone: () => setState(() => _editingMacros = false),
                theme: t,
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

// ── Source badge ─────────────────────────────────────────────────────────────

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source, required this.theme});

  final String source;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(source);
    final color = _colorFor(source);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: K2Fonts.mono,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }

  static String _labelFor(String source) {
    switch (source.toLowerCase()) {
      case 'usda':
        return 'USDA';
      case 'fatsecret':
        return 'DB';
      case 'cache':
        return 'CACHE';
      case 'claude':
      case 'anthropic':
        return 'AI';
      case 'openfoodfacts':
        return 'Open Food Facts';
      case 'label':
        return 'Этикетка';
      default:
        return source.toUpperCase();
    }
  }

  static Color _colorFor(String source) {
    switch (source.toLowerCase()) {
      case 'usda':
        return const Color(0xFF059669); // green — official
      case 'fatsecret':
        return const Color(0xFF2563EB); // blue — third-party DB
      case 'cache':
        return const Color(0xFF6B7280); // gray — local
      case 'claude':
      case 'anthropic':
        return const Color(0xFF7C3AED); // purple — AI
      case 'openfoodfacts':
        return const Color(0xFF059669); // green — trusted DB
      case 'label':
        return const Color(0xFF0284C7); // blue — direct read from packaging
      default:
        return const Color(0xFF7C3AED); // purple — AI
    }
  }
}

// ── Weight pill ──────────────────────────────────────────────────────────────

class _WeightPill extends StatelessWidget {
  const _WeightPill({
    required this.ctrl,
    required this.focus,
    required this.isInvalid,
    required this.onChanged,
    required this.onSubmitted,
    required this.theme,
  });

  final TextEditingController ctrl;
  final FocusNode focus;
  final bool isInvalid;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isInvalid && ctrl.text.isNotEmpty ? K2Colors.error : theme.border;

    return Container(
      width: 52,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: TextField(
          controller: ctrl,
          focusNode: focus,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: K2Fonts.mono,
            fontSize: 12,
            color: theme.fg,
          ),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}

// ── Macro inline edit ────────────────────────────────────────────────────────

class _KF2MacroInlineEdit extends StatelessWidget {
  const _KF2MacroInlineEdit({
    required this.proteinCtrl,
    required this.fatCtrl,
    required this.carbsCtrl,
    required this.caloriesCtrl,
    required this.proteinFocus,
    required this.fatFocus,
    required this.carbsFocus,
    required this.caloriesFocus,
    required this.onMacrosChanged,
    required this.onCaloriesChanged,
    required this.onDone,
    required this.theme,
  });

  final TextEditingController proteinCtrl;
  final TextEditingController fatCtrl;
  final TextEditingController carbsCtrl;
  final TextEditingController caloriesCtrl;
  final FocusNode proteinFocus;
  final FocusNode fatFocus;
  final FocusNode carbsFocus;
  final FocusNode caloriesFocus;
  final VoidCallback onMacrosChanged;
  final ValueChanged<String> onCaloriesChanged;
  final VoidCallback onDone;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calories row (direct edit)
        Row(
          children: [
            Expanded(
              child: _MacroField(
                label: 'KCAL',
                ctrl: caloriesCtrl,
                focus: caloriesFocus,
                onChanged: onCaloriesChanged,
                theme: theme,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _MacroField(
              label: l10n.macro_protein.toUpperCase(),
              ctrl: proteinCtrl,
              focus: proteinFocus,
              onChanged: (_) => onMacrosChanged(),
              theme: theme,
            ),
            const SizedBox(width: 8),
            _MacroField(
              label: l10n.macro_fat.toUpperCase(),
              ctrl: fatCtrl,
              focus: fatFocus,
              onChanged: (_) => onMacrosChanged(),
              theme: theme,
            ),
            const SizedBox(width: 8),
            _MacroField(
              label: l10n.macro_carbs.toUpperCase(),
              ctrl: carbsCtrl,
              focus: carbsFocus,
              onChanged: (_) => onMacrosChanged(),
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            onDone();
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: theme.fg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l10n.common_done,
              style: TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.bg,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MacroField extends StatelessWidget {
  const _MacroField({
    required this.label,
    required this.ctrl,
    required this.focus,
    required this.onChanged,
    required this.theme,
  });

  final String label;
  final TextEditingController ctrl;
  final FocusNode focus;
  final ValueChanged<String> onChanged;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: theme.fgDim,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              child: TextField(
                controller: ctrl,
                focusNode: focus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: K2Fonts.mono,
                  fontSize: 12,
                  color: theme.fg,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds a [NutrientsV2] instance with updated macros, recalculating
/// [NutrientsV2.calories] using the 4/9/4 rule and back-computing
/// [IngredientV2.nutrientsPer100g] so that future [IngredientV2.withWeight]
/// calls remain accurate.
IngredientV2 rebuildIngredientMacros(
  IngredientV2 item,
  double protein,
  double fat,
  double carbs,
) {
  final calories = protein * 4 + fat * 9 + carbs * 4;
  final weight = item.weightGrams;
  final ratio = weight > 0 ? weight / 100.0 : 1.0;

  final newTotal = NutrientsV2(
    calories: calories,
    protein: protein,
    fat: fat,
    carbs: carbs,
    // Preserve optional fields scaled down from existing total.
    fiber: item.nutrientsTotal.fiber,
    sugar: item.nutrientsTotal.sugar,
    sugarAlcohols: item.nutrientsTotal.sugarAlcohols,
    netCarbs: item.nutrientsTotal.netCarbs,
    saturatedFat: item.nutrientsTotal.saturatedFat,
    monounsaturatedFat: item.nutrientsTotal.monounsaturatedFat,
    polyunsaturatedFat: item.nutrientsTotal.polyunsaturatedFat,
    sodiumMg: item.nutrientsTotal.sodiumMg,
    cholesterolMg: item.nutrientsTotal.cholesterolMg,
    potassiumMg: item.nutrientsTotal.potassiumMg,
    calciumMg: item.nutrientsTotal.calciumMg,
    ironMg: item.nutrientsTotal.ironMg,
    vitaminAMcg: item.nutrientsTotal.vitaminAMcg,
    vitaminCMg: item.nutrientsTotal.vitaminCMg,
    vitaminDMcg: item.nutrientsTotal.vitaminDMcg,
    glycemicIndex: item.nutrientsPer100g.glycemicIndex,
    glycemicIndexCategory: item.nutrientsPer100g.glycemicIndexCategory,
  );

  // Back-compute per-100g so withWeight stays accurate.
  final newPer100 = NutrientsV2(
    calories: calories / ratio,
    protein: protein / ratio,
    fat: fat / ratio,
    carbs: carbs / ratio,
    fiber: item.nutrientsTotal.fiber != null
        ? item.nutrientsTotal.fiber! / ratio
        : null,
    sugar: item.nutrientsTotal.sugar != null
        ? item.nutrientsTotal.sugar! / ratio
        : null,
    sugarAlcohols: item.nutrientsTotal.sugarAlcohols != null
        ? item.nutrientsTotal.sugarAlcohols! / ratio
        : null,
    netCarbs: item.nutrientsTotal.netCarbs != null
        ? item.nutrientsTotal.netCarbs! / ratio
        : null,
    saturatedFat: item.nutrientsTotal.saturatedFat != null
        ? item.nutrientsTotal.saturatedFat! / ratio
        : null,
    monounsaturatedFat: item.nutrientsTotal.monounsaturatedFat != null
        ? item.nutrientsTotal.monounsaturatedFat! / ratio
        : null,
    polyunsaturatedFat: item.nutrientsTotal.polyunsaturatedFat != null
        ? item.nutrientsTotal.polyunsaturatedFat! / ratio
        : null,
    sodiumMg: item.nutrientsTotal.sodiumMg != null
        ? item.nutrientsTotal.sodiumMg! / ratio
        : null,
    cholesterolMg: item.nutrientsTotal.cholesterolMg != null
        ? item.nutrientsTotal.cholesterolMg! / ratio
        : null,
    potassiumMg: item.nutrientsTotal.potassiumMg != null
        ? item.nutrientsTotal.potassiumMg! / ratio
        : null,
    calciumMg: item.nutrientsTotal.calciumMg != null
        ? item.nutrientsTotal.calciumMg! / ratio
        : null,
    ironMg: item.nutrientsTotal.ironMg != null
        ? item.nutrientsTotal.ironMg! / ratio
        : null,
    vitaminAMcg: item.nutrientsTotal.vitaminAMcg != null
        ? item.nutrientsTotal.vitaminAMcg! / ratio
        : null,
    vitaminCMg: item.nutrientsTotal.vitaminCMg != null
        ? item.nutrientsTotal.vitaminCMg! / ratio
        : null,
    vitaminDMcg: item.nutrientsTotal.vitaminDMcg != null
        ? item.nutrientsTotal.vitaminDMcg! / ratio
        : null,
    glycemicIndex: item.nutrientsPer100g.glycemicIndex,
    glycemicIndexCategory: item.nutrientsPer100g.glycemicIndexCategory,
  );

  return item.copyWith(
    nutrientsTotal: newTotal,
    nutrientsPer100g: newPer100,
  );
}
