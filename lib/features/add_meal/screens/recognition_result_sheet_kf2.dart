import 'package:dio/dio.dart' show DioException, Options;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/i18n/generated/app_localizations.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../features/journal/screens/journal_screen.dart' show journalDayMealsProvider;
import '../../../shared/models/ingredient_v2.dart';
import '../../../shared/models/nutrients_v2.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/kayfit2_theme.dart';
import '../../../shared/utils/nutrient_parser.dart';
import '../../../shared/widgets/dismissible_sheet_wrapper.dart';
import '../widgets/ingredient_search_sheet.dart';
import '../widgets/kf2_ai_correct_section.dart';
import '../widgets/kf2_hero_total.dart';
import '../widgets/kf2_item_tile.dart';
import '../widgets/kf2_meal_type_pills.dart';

// ── Immutable state model ─────────────────────────────────────────────────────

class _PreviewEditState {
  const _PreviewEditState({
    required this.items,
    required this.mealType,
    this.saving = false,
  });

  final List<IngredientV2> items;
  final String mealType;
  final bool saving;

  NutrientsV2 get totals {
    if (items.isEmpty) {
      return const NutrientsV2(calories: 0, protein: 0, fat: 0, carbs: 0);
    }
    double cal = 0, pro = 0, fat = 0, carb = 0;
    double? fiber, sugar, sa, nc, sf, mf, pf, sod, cho, pot;
    for (final item in items) {
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
    );
  }

  _PreviewEditState withItemAt(int index, IngredientV2 newItem) {
    final updated = List<IngredientV2>.from(items);
    updated[index] = newItem;
    return _copyWith(items: updated);
  }

  _PreviewEditState removeAt(int index) {
    final updated = List<IngredientV2>.from(items)..removeAt(index);
    return _copyWith(items: updated);
  }

  _PreviewEditState addItem(IngredientV2 item) {
    return _copyWith(items: [...items, item]);
  }

  _PreviewEditState addItems(List<IngredientV2> newItems) {
    return _copyWith(items: [...items, ...newItems]);
  }

  _PreviewEditState withWeightAt(int index, double w) {
    return withItemAt(index, items[index].withWeight(w));
  }

  _PreviewEditState withMacrosAt(
    int index,
    double p,
    double f,
    double c,
  ) {
    return withItemAt(
      index,
      rebuildIngredientMacros(items[index], p, f, c),
    );
  }

  _PreviewEditState withMealType(String t) => _copyWith(mealType: t);
  _PreviewEditState withSaving(bool v) => _copyWith(saving: v);
  _PreviewEditState withItems(List<IngredientV2> newItems) =>
      _copyWith(items: newItems);

  _PreviewEditState _copyWith({
    List<IngredientV2>? items,
    String? mealType,
    bool? saving,
  }) {
    return _PreviewEditState(
      items: items ?? this.items,
      mealType: mealType ?? this.mealType,
      saving: saving ?? this.saving,
    );
  }
}

// ── Main widget ───────────────────────────────────────────────────────────────

/// KF2-style recognition result sheet.
///
/// Drop-in replacement for [RecognitionResultSheetV2] behind a feature flag.
/// Same Navigator.pop(true/false) contract. Optional [onSaved] fires with the
/// dish name just before the pop — used by the chat screen to inject a
/// coaching message without depending on the Navigator return type.
class RecognitionResultSheetKF2 extends ConsumerStatefulWidget {
  const RecognitionResultSheetKF2({
    super.key,
    required this.dishName,
    required this.ingredients,
    this.mealDate,
    this.originalText,
    this.onSaved,
  });

  final String dishName;
  final List<IngredientV2> ingredients;
  final DateTime? mealDate;
  final String? originalText;
  /// Called with [dishName] immediately before Navigator.pop(true).
  final void Function(String dishName)? onSaved;

  @override
  ConsumerState<RecognitionResultSheetKF2> createState() =>
      _RecognitionResultSheetKF2State();
}

class _RecognitionResultSheetKF2State
    extends ConsumerState<RecognitionResultSheetKF2> {
  static const _theme = K2Theme.light;

  late _PreviewEditState _state;

  @override
  void initState() {
    super.initState();
    _state = _PreviewEditState(
      items: List.from(widget.ingredients),
      mealType: _inferMealType(),
    );
  }

  String _inferMealType() {
    final hour = (widget.mealDate ?? DateTime.now()).hour;
    if (hour < 11) return 'breakfast';
    if (hour < 15) return 'lunch';
    if (hour < 18) return 'snack';
    return 'dinner';
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  void _updateWeight(int index, double w) {
    if (w <= 0) return;
    setState(() => _state = _state.withWeightAt(index, w));
  }

  void _updateMacros(int index, double p, double f, double c) {
    setState(() => _state = _state.withMacrosAt(index, p, f, c));
  }

  void _delete(int index) {
    HapticFeedback.lightImpact();
    setState(() => _state = _state.removeAt(index));
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
        child: const IngredientSearchSheet(),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => _state = _state.addItems(result));
    }
  }

  // ── AI correction ──────────────────────────────────────────────────────────

  /// Returns an error string on failure, null on success (updates state).
  Future<String?> _applyCorrection(String correctionText) async {
    HapticFeedback.mediumImpact();
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final resp = await apiDio.post(
        '/api/v2/correct_recognition',
        data: {
          'current_items': _state.items.map((i) => i.name).toList(),
          'current_items_data': _state.items
              .map((i) => {'name': i.name, 'weight_grams': i.weightGrams})
              .toList(),
          'correction': correctionText,
          'language': lang,
          if (widget.originalText != null)
            'original_text': widget.originalText,
        },
        // Claude vision/text reasoning + FatSecret enrichment routinely
        // takes 40-60 s on a free-tier Claude account. The global 30 s
        // receiveTimeout aborts well before Claude responds — bump it
        // locally so the correction round-trip can actually complete.
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      final rawItems = (resp.data['items'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      if (rawItems.isEmpty) return 'No items returned by AI';
      final newItems = rawItems.map((raw) {
        final w = (raw['weight_grams'] as num?)?.toDouble() ?? 100.0;
        return ingredientV2FromSuggestion(raw, w);
      }).toList();
      if (mounted) {
        setState(() => _state = _state.withItems(newItems));
        HapticFeedback.mediumImpact();
      }
      return null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) return 'Session expired. Please restart the app and log in again.';
      if (status == 422) return 'Invalid request. Please try a different correction.';
      if (status != null) return 'Server error ($status). Try again in a moment.';
      return 'Network error. Check your connection and try again.';
    } on Exception catch (e) {
      return e.toString();
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_state.saving || _state.items.isEmpty) return;
    setState(() => _state = _state.withSaving(true));
    HapticFeedback.mediumImpact();

    try {
      final items = _state.items.map((item) {
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
          'sodium_mg': n.sodiumMg,
          'calcium_mg': n.calciumMg,
          'iron_mg': n.ironMg,
          'potassium_mg': n.potassiumMg,
          'cholesterol_mg': n.cholesterolMg,
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
        'meal_type': _state.mealType,
        if (widget.mealDate != null)
          'date':
              '${widget.mealDate!.year.toString().padLeft(4, '0')}-'
              '${widget.mealDate!.month.toString().padLeft(2, '0')}-'
              '${widget.mealDate!.day.toString().padLeft(2, '0')}',
      });

      AnalyticsService.mealSaved(
        itemCount: _state.items.length,
        mode: 'photo_dish_kf2',
        totalCalories: _state.totals.calories.round(),
      );

      // Stats + meals shown on Dashboard
      ref.invalidate(todayStatsProvider);
      ref.invalidate(todayMealsProvider);
      // Goals provider (KF2-Journal rings)
      ref.invalidate(userGoalsProvider);
      // Calendar status rings on KF2 Journal — recompute green/red dots
      ref.invalidate(dailyKcalHistoryProvider);
      // Journal V2 watches per-day meals — invalidate today's key.
      final today = widget.mealDate ?? DateTime.now();
      final todayIso = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      ref.invalidate(journalDayMealsProvider(todayIso));

      // Force-await refetch on the providers users will see immediately on return.
      // If any of these throw, swallow — user can pull-to-refresh.
      try {
        await Future.wait([
          ref.read(todayStatsProvider.future),
          ref.read(journalDayMealsProvider(todayIso).future),
          ref.read(dailyKcalHistoryProvider.future),
        ]);
      } catch (_) {
        // Refetch failure surfaces via UI's error path — don't block save success.
      }

      if (mounted) {
        widget.onSaved?.call(widget.dishName);
        Navigator.of(context).pop(true);
      }
    } on Exception catch (_) {
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
      if (mounted) setState(() => _state = _state.withSaving(false));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final totals = _state.totals;
    final isEmpty = _state.items.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ────────────────────────────────────────────────────
            _KF2SheetHeader(
              onClose: () => Navigator.of(context).pop(false),
              theme: t,
            ),

            // ── Scrollable body ───────────────────────────────────────────
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Meal type pills
                  SliverToBoxAdapter(
                    child: KF2MealTypePills(
                      selected: _state.mealType,
                      onChanged: (mt) =>
                          setState(() => _state = _state.withMealType(mt)),
                      theme: t,
                    ),
                  ),

                  // Hero total
                  SliverToBoxAdapter(
                    child: KF2HeroTotal(
                      totals: totals,
                      theme: t,
                      items: _state.items,
                    ),
                  ),

                  // Items label
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Text(
                        AppLocalizations.of(context)!.recognition_items_label,
                        style: TextStyle(
                          fontFamily: K2Fonts.sans,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: t.fgMute,
                        ),
                      ),
                    ),
                  ),

                  // Divider
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      height: 1,
                      color: t.hairline,
                    ),
                  ),

                  // Item list or empty state
                  if (isEmpty)
                    SliverToBoxAdapter(child: _EmptyState(theme: t))
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => KF2ItemTile(
                          key: ValueKey(
                              '${_state.items[i].name}_$i'),
                          item: _state.items[i],
                          onWeightChanged: (w) => _updateWeight(i, w),
                          onMacrosChanged: (p, f, c) =>
                              _updateMacros(i, p, f, c),
                          onDelete: () => _delete(i),
                          theme: t,
                        ),
                        childCount: _state.items.length,
                      ),
                    ),

                  // Add item row
                  SliverToBoxAdapter(
                    child: _AddItemRow(
                      onTap: _addIngredient,
                      theme: t,
                    ),
                  ),

                  // AI correct section
                  SliverToBoxAdapter(
                    child: KF2AiCorrectSection(
                      onApply: _applyCorrection,
                      theme: t,
                    ),
                  ),

                  // Bottom spacing
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),

            // ── Fixed Save button ─────────────────────────────────────────
            Container(
              color: t.bg,
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: GestureDetector(
                  onTap: (_state.saving || isEmpty) ? null : () {
                    // Dismiss keyboard and flush any pending weight edits
                    // before saving — the weight text field debounce may not
                    // have fired yet if the user typed and immediately tapped Save.
                    FocusScope.of(context).unfocus();
                    _save();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: (_state.saving || isEmpty)
                          ? t.fg.withValues(alpha: 0.3)
                          : t.fg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _state.saving
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: t.bg,
                              ),
                            )
                          : Text(
                              AppLocalizations.of(context)!.recognition_save_to_journal,
                              style: TextStyle(
                                fontFamily: K2Fonts.sans,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: t.bg,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _KF2SheetHeader extends StatelessWidget {
  const _KF2SheetHeader({
    required this.onClose,
    required this.theme,
  });

  final VoidCallback onClose;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(Icons.close, size: 22, color: theme.fgDim),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'KAYFIT',
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: theme.fg,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44), // Balance the close button
        ],
      ),
    );
  }
}

class _AddItemRow extends StatelessWidget {
  const _AddItemRow({required this.onTap, required this.theme});

  final VoidCallback onTap;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: GestureDetector(
        onTap: onTap,
        child: _DashedBorderRow(theme: theme),
      ),
    );
  }
}

class _DashedBorderRow extends StatelessWidget {
  const _DashedBorderRow({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: theme.fgMute),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 16, color: theme.fgMute),
            const SizedBox(width: 6),
            Text(
              'add item',
              style: TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: theme.fgMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashGap = 4.0;
    final radius = BorderRadius.circular(8);

    final path = Path()
      ..addRRect(
        radius.toRRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      );

    final dashPath = Path();
    double distance = 0;
    bool draw = true;
    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        final len = draw ? dashWidth : dashGap;
        if (draw) {
          dashPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.restaurant_outlined, size: 40, color: theme.fgMute),
          const SizedBox(height: 12),
          Text(
            'Nothing recognized',
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: theme.fgDim,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add items manually',
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 13,
              color: theme.fgMute,
            ),
          ),
        ],
      ),
    );
  }
}
