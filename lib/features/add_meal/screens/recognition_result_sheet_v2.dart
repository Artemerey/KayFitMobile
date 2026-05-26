import 'dart:math' show pi;

import 'package:dio/dio.dart' show Options;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/api/api_client.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../shared/models/ingredient_v2.dart';
import '../../../shared/models/nutrients_v2.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/nutrient_parser.dart';
import '../../../shared/widgets/dismissible_sheet_wrapper.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
import '../../../shared/widgets/meal_type_picker.dart';
import '../../../shared/widgets/nutrient_detail_sheet.dart';

/// Full-screen bottom sheet shown after v2 AI recognition (photo / text / voice).
///
/// Shows rich nutrient data from the v2 API including fiber, GI, micro-
/// nutrients, and fat sub-types. Each ingredient row expands into a detailed
/// nutrient breakdown card.
class RecognitionResultSheetV2 extends ConsumerStatefulWidget {
  final String dishName;
  final List<IngredientV2> ingredients;
  final DateTime? mealDate;
  final String? originalText;

  const RecognitionResultSheetV2({
    super.key,
    required this.dishName,
    required this.ingredients,
    this.mealDate,
    this.originalText,
  });

  @override
  ConsumerState<RecognitionResultSheetV2> createState() =>
      _RecognitionResultSheetV2State();
}

class _RecognitionResultSheetV2State
    extends ConsumerState<RecognitionResultSheetV2>
    with SingleTickerProviderStateMixin {
  late List<IngredientV2> _items;
  late String _mealType;
  bool _saving = false;
  // Which ingredient index is expanded, null = none.
  int? _expandedIndex;

  bool _correcting = false;
  bool _correctionLoading = false;
  final _correctionCtrl = TextEditingController();
  final _correctionFocus = FocusNode();

  String _dishName = '';

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.ingredients);
    _dishName = widget.dishName;
    _mealType = _inferMealType();
  }

  @override
  void dispose() {
    _correctionCtrl.dispose();
    _correctionFocus.dispose();
    super.dispose();
  }

  String _inferMealType() {
    final hour = (widget.mealDate ?? DateTime.now()).hour;
    if (hour < 11) return 'breakfast';
    if (hour < 15) return 'lunch';
    if (hour < 18) return 'snack';
    return 'dinner';
  }

  // ── Computed totals ──────────────────────────────────────────────────────

  List<IngredientV2> get _selected =>
      _items.where((i) => i.selected).toList();

  NutrientsV2 get _totals {
    if (_selected.isEmpty) {
      return const NutrientsV2(calories: 0, protein: 0, fat: 0, carbs: 0);
    }
    double cal = 0, pro = 0, fat = 0, carb = 0;
    double? fiber, sugar, sa, nc, sf, mf, pf, sod, cho, pot;
    int? gi;

    for (final item in _selected) {
      final n = item.nutrientsTotal;
      cal += n.calories;
      pro += n.protein;
      fat += n.fat;
      carb += n.carbs;
      if (n.fiber != null) fiber = (fiber ?? 0) + n.fiber!;
      if (n.sugar != null) sugar = (sugar ?? 0) + n.sugar!;
      if (n.sugarAlcohols != null) sa = (sa ?? 0) + n.sugarAlcohols!;
      if (n.netCarbs != null) nc = (nc ?? 0) + n.netCarbs!;
      if (n.saturatedFat != null) sf = (sf ?? 0) + n.saturatedFat!;
      if (n.monounsaturatedFat != null) mf = (mf ?? 0) + n.monounsaturatedFat!;
      if (n.polyunsaturatedFat != null) pf = (pf ?? 0) + n.polyunsaturatedFat!;
      if (n.sodiumMg != null) sod = (sod ?? 0) + n.sodiumMg!;
      if (n.cholesterolMg != null) cho = (cho ?? 0) + n.cholesterolMg!;
      if (n.potassiumMg != null) pot = (pot ?? 0) + n.potassiumMg!;
    }

    // Weighted average GI by carbs
    double carbSum = 0, giSum = 0;
    for (final item in _selected) {
      final n = item.nutrientsPer100g;
      if (n.glycemicIndex != null && item.nutrientsTotal.carbs > 0) {
        giSum += n.glycemicIndex! * item.nutrientsTotal.carbs;
        carbSum += item.nutrientsTotal.carbs;
      }
    }
    if (carbSum > 0) gi = (giSum / carbSum).round();

    return NutrientsV2(
      calories: cal,
      protein: pro,
      fat: fat,
      carbs: carb,
      fiber: fiber,
      sugar: sugar,
      sugarAlcohols: sa,
      netCarbs: nc,
      saturatedFat: sf,
      monounsaturatedFat: mf,
      polyunsaturatedFat: pf,
      sodiumMg: sod,
      cholesterolMg: cho,
      potassiumMg: pot,
      glycemicIndex: gi,
    );
  }

  // ── Mutations ────────────────────────────────────────────────────────────

  void _toggle(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _items[index] = _items[index].copyWith(selected: !_items[index].selected);
    });
  }

  void _updateWeight(int index, double newWeight) {
    if (newWeight <= 0) return;
    setState(() {
      _items[index] = _items[index].withWeight(newWeight);
    });
  }

  void _delete(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_expandedIndex == index) _expandedIndex = null;
      _items.removeAt(index);
    });
  }

  Future<void> _addIngredient() async {
    final result = await showModalBottomSheet<List<IngredientV2>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      builder: (_) => DismissibleSheetWrapper(
        child: const _V2IngredientSearchSheet(),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _items.addAll(result));
    }
  }

  // ── Correction ───────────────────────────────────────────────────────────

  Future<void> _applyCorrection() async {
    final text = _correctionCtrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _correctionLoading = true);
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final resp = await apiDio.post(
        '/api/v2/correct_recognition',
        data: {
          'current_items': _items.map((i) => i.name).toList(),
          'current_items_data': _items
              .map((i) => {'name': i.name, 'weight_grams': i.weightGrams})
              .toList(),
          'correction': text,
          'language': lang,
          if (widget.originalText != null) 'original_text': widget.originalText,
        },
        // See recognition_result_sheet_kf2.dart for rationale: Claude
        // correction calls routinely exceed the global 30 s receiveTimeout.
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      final rawItems = (resp.data['items'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      if (rawItems.isNotEmpty && mounted) {
        final newItems = rawItems.map((raw) {
          final w = (raw['weight_grams'] as num?)?.toDouble() ?? 100.0;
          return ingredientV2FromSuggestion(raw, w);
        }).toList();
        setState(() {
          _items = newItems;
          _dishName = newItems.map((i) => i.name).join(', ');
          _correcting = false;
          _correctionLoading = false;
          _correctionCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error_unknown),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accentOver,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _correctionLoading = false);
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving || _selected.isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final items = _selected.map((item) {
        final n = item.nutrientsTotal;
        final mono = n.monounsaturatedFat ?? 0;
        final poly = n.polyunsaturatedFat ?? 0;
        return {
          'name': item.name,
          'calories': n.calories,
          'protein': n.protein,
          'fat': n.fat,
          'carbs': n.carbs,
          'weight': item.weightGrams,
          'fiber': n.fiber,
          'sugar': n.sugar,
          'sugar_alcohols': n.sugarAlcohols,
          'net_carbs': n.netCarbs,
          'saturated_fat': n.saturatedFat,
          'unsaturated_fat': mono + poly > 0 ? mono + poly : null,
          'glycemic_index': item.nutrientsPer100g.glycemicIndex,
          // Minerals
          'sodium_mg': n.sodiumMg,
          'calcium_mg': n.calciumMg,
          'iron_mg': n.ironMg,
          'potassium_mg': n.potassiumMg,
          'cholesterol_mg': n.cholesterolMg,
          // Vitamins
          'vitamin_a_mcg': n.vitaminAMcg,
          'vitamin_c_mg': n.vitaminCMg,
          'vitamin_d_mcg': n.vitaminDMcg,
          'source': item.source,
          'source_url': item.sourceUrl,
        };
      }).toList();

      await apiDio.post('/api/meals/add_selected', data: {
        'items': items,
        'dish_name': widget.dishName,
        'meal_type': _mealType,
        if (widget.mealDate != null)
          'date':
              '${widget.mealDate!.year.toString().padLeft(4, '0')}-'
              '${widget.mealDate!.month.toString().padLeft(2, '0')}-'
              '${widget.mealDate!.day.toString().padLeft(2, '0')}',
      });

      AnalyticsService.mealSaved(
        itemCount: _selected.length,
        mode: 'photo_dish_v2',
        totalCalories: _totals.calories.round(),
      );

      ref.invalidate(todayStatsProvider);
      ref.invalidate(todayMealsProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.error_unknown),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.accentOver,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totals = _totals;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: NutrientColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Header: dish name + total cal ──
                  _HeaderSection(
                    dishName: _dishName,
                    totals: totals,
                    items: _selected,
                    l10n: l10n,
                  ),

                  // ── Macro donut + totals row ──
                  _MacroSummaryRow(totals: totals, l10n: l10n),

                  // ── Composition label + add button ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        Text(
                          l10n.recogV2_composition,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NutrientColors.tertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        _IconBtn(
                          icon: Icons.add_rounded,
                          color: NutrientColors.netCarbs,
                          bg: NutrientColors.netCarbsSoft,
                          onTap: _addIngredient,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Ingredient list (sliver so it scrolls with the sheet) ──
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _IngredientTile(
                    key: ValueKey(_items[i].name + i.toString()),
                    item: _items[i],
                    isExpanded: _expandedIndex == i,
                    onTap: () => setState(() {
                      _expandedIndex = _expandedIndex == i ? null : i;
                    }),
                    onToggle: () => _toggle(i),
                    onWeightChanged: (w) => _updateWeight(i, w),
                    onDelete: () => _delete(i),
                    l10n: l10n,
                  ),
                  childCount: _items.length,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Meal type picker ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.recogV2_meal_type,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: NutrientColors.tertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        MealTypePicker(
                          selected: _mealType,
                          onChanged: (t) => setState(() => _mealType = t),
                        ),
                      ],
                    ),
                  ),

                  // ── Correction button ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _correcting = !_correcting);
                        if (!_correcting) return;
                        Future.delayed(const Duration(milliseconds: 350), () {
                          if (mounted) _correctionFocus.requestFocus();
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            Text(
                              l10n.recogV2_correct_btn,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Save CTA ──
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (_saving || _selected.isEmpty) ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NutrientColors.netCarbs,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              NutrientColors.netCarbs.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add_rounded, size: 20),
                        label: Text(
                          _saving
                              ? l10n.recogV2_saving
                              : _saveBtnLabel(l10n),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // ── Correction panel overlay ──
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: _correcting ? 0 : -200,
          left: 0,
          right: 0,
          child: _CorrectionPanel(
            ctrl: _correctionCtrl,
            focus: _correctionFocus,
            loading: _correctionLoading,
            onSend: _applyCorrection,
            onClose: () => setState(() {
              _correcting = false;
              _correctionCtrl.clear();
            }),
            l10n: l10n,
          ),
        ),

        // ── Close (X) button ──────────────────────────────────────────
        Positioned(
          top: 20,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close_rounded),
            iconSize: 20,
            color: AppColors.textMuted,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
        ),
      ),
    );
  }

  String _saveBtnLabel(AppLocalizations l10n) {
    return switch (_mealType) {
      'breakfast' => l10n.recogV2_add_breakfast,
      'lunch' => l10n.recogV2_add_lunch,
      'dinner' => l10n.recogV2_add_dinner,
      'snack' => l10n.recogV2_add_snack,
      _ => l10n.recogV2_add_meal,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header section
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  final String dishName;
  final NutrientsV2 totals;
  final List<IngredientV2> items;
  final AppLocalizations l10n;

  const _HeaderSection({
    required this.dishName,
    required this.totals,
    required this.items,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dishName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${totals.calories.toStringAsFixed(0)} ${l10n.macro_kcal}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: NutrientColors.netCarbs,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Macro summary: donut chart + KBJU pills
// ─────────────────────────────────────────────────────────────────────────────

class _MacroSummaryRow extends StatelessWidget {
  final NutrientsV2 totals;
  final AppLocalizations l10n;
  const _MacroSummaryRow({required this.totals, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final pro = totals.protein;
    final fat = totals.fat;
    final carb = totals.carbs;
    final total = pro + fat + carb;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NutrientColors.bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Mini donut chart
            SizedBox(
              width: 72,
              height: 72,
              child: total > 0
                  ? PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 22,
                        sections: [
                          PieChartSectionData(
                            value: pro,
                            color: NutrientColors.protein,
                            radius: 12,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: fat,
                            color: NutrientColors.fatGood,
                            radius: 12,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: carb,
                            color: NutrientColors.netCarbs,
                            radius: 12,
                            showTitle: false,
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: NutrientColors.border,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            // Macro pills
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MacroPill(
                    label: l10n.macro_protein,
                    value: '${pro.toStringAsFixed(0)}${l10n.macro_g}',
                    color: NutrientColors.protein,
                    bg: NutrientColors.proteinSoft,
                    fraction: total > 0 ? pro / total : 0,
                  ),
                  const SizedBox(height: 6),
                  _MacroPill(
                    label: l10n.macro_fat,
                    value: '${fat.toStringAsFixed(0)}${l10n.macro_g}',
                    color: NutrientColors.fatGood,
                    bg: NutrientColors.fatGoodSoft,
                    fraction: total > 0 ? fat / total : 0,
                  ),
                  const SizedBox(height: 6),
                  _MacroPill(
                    label: l10n.macro_carbs,
                    value: '${carb.toStringAsFixed(0)}${l10n.macro_g}',
                    color: NutrientColors.netCarbs,
                    bg: NutrientColors.netCarbsSoft,
                    fraction: total > 0 ? carb / total : 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final double fraction;
  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: NutrientColors.secondary)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ingredient tile with expandable nutrient breakdown
// ─────────────────────────────────────────────────────────────────────────────

class _IngredientTile extends StatefulWidget {
  final IngredientV2 item;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback onDelete;
  final AppLocalizations l10n;

  const _IngredientTile({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onTap,
    required this.onToggle,
    required this.onWeightChanged,
    required this.onDelete,
    required this.l10n,
  });

  @override
  State<_IngredientTile> createState() => _IngredientTileState();
}

class _IngredientTileState extends State<_IngredientTile>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _weightCtrl;
  late final FocusNode _weightFocus;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
        text: widget.item.weightGrams.toStringAsFixed(0));
    // Apply weight when the field loses focus (tap outside, keyboard dismiss).
    // Without this `onSubmitted` only fires on the Return key — most users
    // never press Return on a numeric keyboard, so calories never updated.
    _weightFocus = FocusNode()..addListener(_onWeightFocusChange);
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.isExpanded ? 1.0 : 0.0,
    );
    _expandAnim =
        CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutCubic);
  }

  void _onWeightFocusChange() {
    if (_weightFocus.hasFocus) return;
    final w = double.tryParse(_weightCtrl.text.trim());
    if (w != null && w > 0 && w != widget.item.weightGrams) {
      widget.onWeightChanged(w);
    }
  }

  @override
  void didUpdateWidget(_IngredientTile old) {
    super.didUpdateWidget(old);
    if (old.item.weightGrams != widget.item.weightGrams) {
      // Preserve cursor when the new value already matches the field
      // (typical onChanged round-trip — no need to disturb the user).
      final newText = widget.item.weightGrams.toStringAsFixed(0);
      if (_weightCtrl.text != newText) {
        _weightCtrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    }
    if (old.isExpanded != widget.isExpanded) {
      widget.isExpanded ? _expandCtrl.forward() : _expandCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _weightFocus
      ..removeListener(_onWeightFocusChange)
      ..dispose();
    _weightCtrl.dispose();
    _expandCtrl.dispose();
    super.dispose();
  }

  void _showDetailSheet(BuildContext context) {
    final item = widget.item;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      builder: (_) => DismissibleSheetWrapper(
        child: NutrientDetailSheet(
          name: item.name,
          weightGrams: item.weightGrams,
          per100g: item.nutrientsPer100g,
          total: item.nutrientsTotal,
          source: item.source,
          sourceUrl: item.sourceUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final n = item.nutrientsTotal;
    final l10n = widget.l10n;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: NutrientColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        children: [
          // ── Row: checkbox / name / weight / cal / expand chevron ──
          InkWell(
            onTap: widget.onTap,
            onLongPress: () => _showDetailSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: widget.onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: item.selected
                            ? NutrientColors.netCarbs
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: item.selected
                              ? NutrientColors.netCarbs
                              : NutrientColors.border,
                          width: 2,
                        ),
                      ),
                      child: item.selected
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Name + weight + tags
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        SourceBadge(
                          source: item.source,
                          sourceUrl: item.sourceUrl,
                          compact: true,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            SizedBox(
                              width: 44,
                              height: 22,
                              child: TextField(
                                controller: _weightCtrl,
                                focusNode: _weightFocus,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: NutrientColors.netCarbs,
                                ),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: NutrientColors.netCarbs,
                                        width: 1.5),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: NutrientColors.netCarbs,
                                        width: 1.5),
                                  ),
                                  filled: false,
                                ),
                                // Apply on every keystroke so calories
                                // recompute live as the user types — keyboard
                                // dismiss / focus loss / Return all redundant
                                // safety nets but this is the primary path.
                                onChanged: (v) {
                                  final w = double.tryParse(v.trim());
                                  if (w != null && w > 0 &&
                                      w != widget.item.weightGrams) {
                                    widget.onWeightChanged(w);
                                  }
                                },
                                onSubmitted: (v) {
                                  final w = double.tryParse(v);
                                  if (w != null && w > 0) {
                                    widget.onWeightChanged(w);
                                  }
                                },
                              ),
                            ),
                            Text(' ${l10n.macro_g}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: NutrientColors.tertiary)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Calories + delete + chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${n.calories.toStringAsFixed(0)} ${l10n.macro_kcal}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: NutrientColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Icon(Icons.close_rounded,
                            size: 16, color: NutrientColors.tertiary),
                      ),
                      const SizedBox(height: 4),
                      AnimatedBuilder(
                        animation: _expandAnim,
                        builder: (_, __) => Transform.rotate(
                          angle: _expandAnim.value * pi,
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: NutrientColors.tertiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable breakdown ──
          SizeTransition(
            sizeFactor: _expandAnim,
            child: _NutrientBreakdownCard(
              nutrients: item.nutrientsTotal,
              per100g: item.nutrientsPer100g,
              l10n: l10n,
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Nutrient breakdown card (shown when ingredient is expanded)
// ─────────────────────────────────────────────────────────────────────────────

class _NutrientBreakdownCard extends StatelessWidget {
  final NutrientsV2 nutrients;
  final NutrientsV2 per100g;
  final AppLocalizations l10n;

  const _NutrientBreakdownCard({
    required this.nutrients,
    required this.per100g,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final n = nutrients;
    final gi = per100g.glycemicIndex;
    final giCat = per100g.glycemicIndexCategory;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 32),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NutrientColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Macros 2x2 grid ──
          _SectionLabel(l10n.recogV2_macros),
          const SizedBox(height: 8),
          Row(
            children: [
              _NutrientCell(
                  label: l10n.macro_calories,
                  value: '${n.calories.toStringAsFixed(0)} ${l10n.macro_kcal}',
                  color: NutrientColors.kcal,
                  icon: Icons.local_fire_department_rounded),
              const SizedBox(width: 6),
              _NutrientCell(
                  label: l10n.macro_protein,
                  value: '${n.protein.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.protein,
                  icon: Icons.fitness_center_rounded),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _NutrientCell(
                  label: l10n.macro_fat,
                  value: '${n.fat.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.fatGood,
                  icon: Icons.water_drop_rounded),
              const SizedBox(width: 6),
              _NutrientCell(
                  label: l10n.macro_carbs,
                  value: '${n.carbs.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.netCarbs,
                  icon: Icons.grain_rounded),
            ],
          ),

          // ── GI badge ──
          if (gi != null) ...[
            const SizedBox(height: 10),
            _GiBadge(gi: gi, category: giCat, l10n: l10n),
          ],

          // ── Carbs detail ──
          if (n.netCarbs != null ||
              n.fiber != null ||
              n.sugar != null ||
              n.sugarAlcohols != null)
            ...[
            const SizedBox(height: 12),
            _SectionLabel(l10n.recogV2_carbs_detail),
            const SizedBox(height: 6),
            if (n.netCarbs != null)
              _NutrientRow(
                  label: l10n.recogV2_net_carbs,
                  value: '${n.netCarbs!.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.netCarbs,
                  fraction: n.carbs > 0 ? n.netCarbs! / n.carbs : 0),
            if (n.fiber != null)
              _NutrientRow(
                  label: l10n.recogV2_fiber,
                  value: '${n.fiber!.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.fiber,
                  fraction: n.carbs > 0 ? n.fiber! / n.carbs : 0),
            if (n.sugar != null)
              _NutrientRow(
                  label: Localizations.localeOf(context).languageCode == 'ru'
                      ? 'Сахар'
                      : 'Sugar',
                  value: '${n.sugar!.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.sugar,
                  fraction: n.carbs > 0 ? n.sugar! / n.carbs : 0),
            if (n.sugarAlcohols != null)
              _NutrientRow(
                  label: l10n.recogV2_sugar_alcohols,
                  value: '${n.sugarAlcohols!.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.sugar,
                  fraction: n.carbs > 0 ? n.sugarAlcohols! / n.carbs : 0),
          ],

          // ── Fats detail ──
          if (n.saturatedFat != null ||
              n.monounsaturatedFat != null ||
              n.polyunsaturatedFat != null)
            ...[
            const SizedBox(height: 12),
            _SectionLabel(l10n.recogV2_fats_detail),
            const SizedBox(height: 6),
            if (n.saturatedFat != null)
              _NutrientRow(
                  label: l10n.recogV2_sat_fat,
                  value: '${n.saturatedFat!.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.fatBad,
                  fraction: n.fat > 0 ? n.saturatedFat! / n.fat : 0),
            if (n.monounsaturatedFat != null)
              _NutrientRow(
                  label: l10n.recogV2_mono_fat,
                  value:
                      '${n.monounsaturatedFat!.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.fatGood,
                  fraction: n.fat > 0 ? n.monounsaturatedFat! / n.fat : 0),
            if (n.polyunsaturatedFat != null)
              _NutrientRow(
                  label: l10n.recogV2_poly_fat,
                  value:
                      '${n.polyunsaturatedFat!.toStringAsFixed(1)}${l10n.macro_g}',
                  color: NutrientColors.fiber,
                  fraction: n.fat > 0 ? n.polyunsaturatedFat! / n.fat : 0),
          ],

          // ── Micronutrients ──
          if (n.sodiumMg != null || n.cholesterolMg != null || n.potassiumMg != null)
            ...[
            const SizedBox(height: 12),
            _SectionLabel(l10n.recogV2_micro),
            const SizedBox(height: 6),
            if (n.sodiumMg != null)
              _MicroRow(
                  label: l10n.recogV2_sodium,
                  value: '${n.sodiumMg!.toStringAsFixed(0)} ${l10n.recogV2_mg}'),
            if (n.cholesterolMg != null)
              _MicroRow(
                  label: l10n.recogV2_cholesterol,
                  value: '${n.cholesterolMg!.toStringAsFixed(0)} ${l10n.recogV2_mg}'),
            if (n.potassiumMg != null)
              _MicroRow(
                  label: l10n.recogV2_potassium,
                  value: '${n.potassiumMg!.toStringAsFixed(0)} ${l10n.recogV2_mg}'),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: NutrientColors.tertiary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _NutrientCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _NutrientCell(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          color: color.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double fraction;

  const _NutrientRow({
    required this.label,
    required this.value,
    required this.color,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Column(
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: NutrientColors.secondary,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroRow extends StatelessWidget {
  final String label;
  final String value;
  const _MicroRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: NutrientColors.secondary,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: NutrientColors.secondary)),
        ],
      ),
    );
  }
}

class _GiBadge extends StatelessWidget {
  final int gi;
  final String? category;
  final AppLocalizations l10n;
  const _GiBadge({required this.gi, this.category, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cat = category ?? (gi < 55 ? 'low' : gi < 70 ? 'medium' : 'high');
    final (color, bg, label) = switch (cat) {
      'low' => (
          const Color(0xFF16A34A),
          const Color(0xFFDCFCE7),
          l10n.recogV2_gi_low
        ),
      'medium' => (
          const Color(0xFFD97706),
          const Color(0xFFFEF3C7),
          l10n.recogV2_gi_medium
        ),
      _ => (
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
          l10n.recogV2_gi_high
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${l10n.recogV2_gi_label} $gi',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            '· $label',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon button helper
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? bg;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, this.color, this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bg ?? NutrientColors.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color ?? NutrientColors.secondary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// V2 Ingredient Search Sheet
// Bottom sheet: text → /api/v2/parse_meal_suggestions → IngredientV2
// ─────────────────────────────────────────────────────────────────────────────

// ─── Model for a parsed variant group ────────────────────────────────────────

class _VariantGroup {
  final String food;
  final List<Map<String, dynamic>> variants;
  int selectedIndex;

  _VariantGroup({
    required this.food,
    required this.variants,
    this.selectedIndex = 0,
  });
}

// ─── Add ingredient sheet with variant picker ─────────────────────────────────

class _V2IngredientSearchSheet extends StatefulWidget {
  final String? initialQuery;
  const _V2IngredientSearchSheet({this.initialQuery});

  @override
  State<_V2IngredientSearchSheet> createState() =>
      _V2IngredientSearchSheetState();
}

class _V2IngredientSearchSheetState extends State<_V2IngredientSearchSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  List<_VariantGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) _ctrl.text = widget.initialQuery!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _focus.unfocus();
    setState(() { _loading = true; _groups = []; });
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final resp = await apiDio.post(
        '/api/v2/parse_meal_variants',
        data: {'text': text, 'language': lang},
      );
      final rawGroups = (resp.data['groups'] as List<dynamic>?) ?? [];
      final groups = rawGroups.map((g) {
        final variants = ((g['variants'] as List<dynamic>?) ?? [])
            .map((v) => v as Map<String, dynamic>)
            .toList();
        return _VariantGroup(
          food: g['food'] as String? ?? '',
          variants: variants,
        );
      }).where((g) => g.variants.isNotEmpty).toList();
      if (mounted) setState(() => _groups = groups);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addSelected() {
    if (_groups.isEmpty) return;
    HapticFeedback.mediumImpact();
    final items = _groups.map((g) {
      final raw = g.variants[g.selectedIndex];
      final w = (raw['weight_grams'] as num?)?.toDouble() ?? 100.0;
      return ingredientV2FromSuggestion(raw, w);
    }).toList();
    Navigator.pop(context, items);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final keyboardPad = MediaQuery.of(context).viewInsets.bottom;

    return KeyboardDismisser(
      child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: keyboardPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: NutrientColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l10n.recogV2_search_ingredient,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: NutrientColors.secondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: l10n.recogV2_search_hint,
                      filled: true,
                      fillColor: NutrientColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _search,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: NutrientColors.netCarbs,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search_rounded,
                            color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Variant groups
          if (_groups.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _groups.length,
                itemBuilder: (_, gi) {
                  final group = _groups[gi];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.food,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...group.variants.asMap().entries.map((entry) {
                          final vi = entry.key;
                          final v = entry.value;
                          final isSelected = group.selectedIndex == vi;
                          final name = v['name'] as String? ?? '';
                          final per100 = v['nutrients_per_100g']
                              as Map<String, dynamic>? ?? {};
                          final cal =
                              (per100['calories'] as num?)?.toDouble() ?? 0;
                          final w =
                              (v['weight_grams'] as num?)?.toDouble() ?? 100;
                          return GestureDetector(
                            onTap: () => setState(
                                () => group.selectedIndex = vi),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? NutrientColors.netCarbsSoft
                                    : NutrientColors.bg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? NutrientColors.netCarbs
                                      : NutrientColors.border,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? NutrientColors.netCarbs
                                                : AppColors.text,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${cal.toStringAsFixed(0)} ${l10n.macro_kcal}/100${l10n.macro_g}  ·  '
                                          '${w.toStringAsFixed(0)}${l10n.macro_g}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: NutrientColors.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle_rounded,
                                        color: NutrientColors.netCarbs,
                                        size: 18),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          // Add button
          if (_groups.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NutrientColors.netCarbs,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isRu ? 'Добавить выбранные' : 'Add selected',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          if (_groups.isEmpty && !_loading)
            SizedBox(height: bottomPad + 16),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Correction panel — slides up from bottom
// ─────────────────────────────────────────────────────────────────────────────

class _CorrectionPanel extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool loading;
  final VoidCallback onSend;
  final VoidCallback onClose;
  final AppLocalizations l10n;

  const _CorrectionPanel({
    required this.ctrl,
    required this.focus,
    required this.loading,
    required this.onSend,
    required this.onClose,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.edit_note_rounded, size: 18, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Text(
                l10n.recogV2_correct_title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  focusNode: focus,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: l10n.recogV2_correct_hint,
                    hintStyle: TextStyle(fontSize: 13, color: NutrientColors.tertiary),
                    filled: true,
                    fillColor: NutrientColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: loading ? null : onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: loading
                        ? const Color(0xFF059669).withValues(alpha: 0.5)
                        : const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
