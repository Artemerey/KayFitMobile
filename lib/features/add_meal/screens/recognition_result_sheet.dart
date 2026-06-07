import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../shared/models/ingredient.dart';
import '../../../shared/utils/nutrient_parser.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/meal_type_picker.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';

/// Full-screen bottom sheet shown after AI recognizes a dish from photo/voice/text.
class RecognitionResultSheet extends ConsumerStatefulWidget {
  final String dishName;
  final List<Ingredient> ingredients;
  final double totalCalories;
  final double totalWeight;
  final int? glycemicIndex;
  final DateTime? mealDate;

  const RecognitionResultSheet({
    super.key,
    required this.dishName,
    required this.ingredients,
    required this.totalCalories,
    required this.totalWeight,
    this.glycemicIndex,
    this.mealDate,
  });

  @override
  ConsumerState<RecognitionResultSheet> createState() =>
      _RecognitionResultSheetState();
}

class _RecognitionResultSheetState
    extends ConsumerState<RecognitionResultSheet> {
  late List<Ingredient> _ingredients;
  late String _mealType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ingredients = List.from(widget.ingredients);
    _mealType = _inferMealType();
    // DEBUG
    debugPrint('🍽 RecognitionResultSheet: dishName=${widget.dishName}');
    debugPrint('🍽 ingredients count: ${_ingredients.length}');
    for (final i in _ingredients) {
      debugPrint('🍽 ${i.name}: cal=${i.calories}, p=${i.protein}, f=${i.fat}, c=${i.carbs}, net=${i.netCarbs}, w=${i.weightGrams}');
    }
  }

  String _inferMealType() {
    final hour = (widget.mealDate ?? DateTime.now()).hour;
    if (hour < 11) return 'breakfast';
    if (hour < 15) return 'lunch';
    if (hour < 18) return 'snack';
    return 'dinner';
  }

  // ── Computed totals from selected ingredients ──
  List<Ingredient> get _selected =>
      _ingredients.where((i) => i.selected).toList();

  double get _totalCal =>
      _selected.fold(0.0, (s, i) => s + i.calories);
  double get _totalProtein =>
      _selected.fold(0.0, (s, i) => s + i.protein);
  double get _totalFat =>
      _selected.fold(0.0, (s, i) => s + i.fat);
  double get _totalCarbs =>
      _selected.fold(0.0, (s, i) => s + i.carbs);
  double get _totalSugar =>
      _selected.fold(0.0, (s, i) => s + i.sugar);
  double get _totalNetCarbs =>
      _selected.fold(0.0, (s, i) => s + i.netCarbs);
  double get _totalSatFat =>
      _selected.fold(0.0, (s, i) => s + i.saturatedFat);
  double get _totalUnsatFat =>
      _selected.fold(0.0, (s, i) => s + i.unsaturatedFat);

  void _toggleIngredient(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      final ing = _ingredients[index];
      _ingredients[index] = ing.copyWith(selected: !ing.selected);
    });
  }

  void _updateWeight(int index, double newWeight) {
    final ing = _ingredients[index];
    if (ing.weightGrams == 0) return;
    final ratio = newWeight / ing.weightGrams;
    setState(() {
      _ingredients[index] = ing.copyWith(
        weightGrams: newWeight,
        calories: ing.calories * ratio,
        protein: ing.protein * ratio,
        fat: ing.fat * ratio,
        carbs: ing.carbs * ratio,
        fiber: ing.fiber * ratio,
        sugar: ing.sugar * ratio,
        sugarAlcohols: ing.sugarAlcohols * ratio,
        netCarbs: ing.netCarbs * ratio,
        saturatedFat: ing.saturatedFat * ratio,
        unsaturatedFat: ing.unsaturatedFat * ratio,
      );
    });
  }

  // ── Add ingredient by text search ──
  Future<void> _addIngredient() async {
    final result = await showModalBottomSheet<Ingredient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _IngredientSearchSheet(),
    );
    if (result != null && mounted) {
      setState(() => _ingredients.add(result));
    }
  }

  // ── Edit ingredient by text search (replace existing) ──
  Future<void> _editIngredient(int index) async {
    final current = _ingredients[index];
    final result = await showModalBottomSheet<Ingredient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IngredientSearchSheet(initialQuery: current.name),
    );
    if (result != null && mounted) {
      setState(() => _ingredients[index] = result);
    }
  }

  // ── Delete ingredient ──
  void _deleteIngredient(int index) {
    HapticFeedback.lightImpact();
    setState(() => _ingredients.removeAt(index));
  }

  Future<void> _save() async {
    if (_saving || _selected.isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    try {
      final items = _selected
          .map((i) => {
                'name': i.name,
                'calories': i.calories,
                'protein': i.protein,
                'fat': i.fat,
                'carbs': i.carbs,
                'weight': i.weightGrams,
                'fiber': i.fiber,
                'sugar': i.sugar,
                'sugar_alcohols': i.sugarAlcohols,
                'net_carbs': i.netCarbs,
                'glycemic_index': i.glycemicIndex,
                'saturated_fat': i.saturatedFat,
                'unsaturated_fat': i.unsaturatedFat,
              })
          .toList();

      await apiDio.post('/api/meals/add_selected', data: {
        'items': items,
        'dish_name': widget.dishName,
        'meal_type': _mealType,
      });

      AnalyticsService.mealSaved(
        itemCount: _selected.length,
        mode: 'photo_dish',
        totalCalories: _totalCal.round(),
      );

      ref.invalidate(todayStatsProvider);
      ref.invalidate(todayMealsProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealLabel = {
      'breakfast': 'breakfast',
      'lunch': 'lunch',
      'dinner': 'dinner',
      'snack': 'snack',
    }[_mealType] ?? 'meal';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20),
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

              // ── Photo placeholder ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C3E2D), Color(0xFF3D5A3E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📸', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7BAE7F),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Dish recognized',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Dish name ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.dishName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.totalWeight.toStringAsFixed(0)} g · ${_totalCal.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        fontSize: 13,
                        color: NutrientColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── KBJU row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KBJU',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NutrientColors.tertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MacroCard('Calories',
                            '${_totalCal.toStringAsFixed(0)}',
                            NutrientColors.kcal, NutrientColors.kcalSoft),
                        const SizedBox(width: 8),
                        _MacroCard('Protein',
                            '${_totalProtein.toStringAsFixed(0)}g',
                            NutrientColors.protein, NutrientColors.proteinSoft),
                        const SizedBox(width: 8),
                        _MacroCard('Fat',
                            '${_totalFat.toStringAsFixed(0)}g',
                            NutrientColors.fatGood, NutrientColors.fatGoodSoft),
                        const SizedBox(width: 8),
                        _MacroCard('Carbs',
                            '${_totalCarbs.toStringAsFixed(0)}g',
                            NutrientColors.netCarbs, NutrientColors.netCarbsSoft),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Details: sugar, net carbs, good/bad fats ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DETAILS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NutrientColors.tertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MacroCard('Sugar',
                            '${_totalSugar.toStringAsFixed(0)}g',
                            NutrientColors.sugar, NutrientColors.sugarSoft),
                        const SizedBox(width: 8),
                        _MacroCard('Net carbs',
                            '${_totalNetCarbs.toStringAsFixed(0)}g',
                            NutrientColors.netCarbs, NutrientColors.netCarbsSoft),
                        const SizedBox(width: 8),
                        _MacroCard('Good fats',
                            '${_totalUnsatFat.toStringAsFixed(0)}g',
                            NutrientColors.fatGood, NutrientColors.fatGoodSoft),
                        const SizedBox(width: 8),
                        _MacroCard('Sat. fats',
                            '${_totalSatFat.toStringAsFixed(0)}g',
                            NutrientColors.fatBad, NutrientColors.fatBadSoft),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Ingredients ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'COMPOSITION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: NutrientColors.tertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    // Add ingredient button
                    _IconBtn(
                      icon: Icons.add_rounded,
                      color: NutrientColors.netCarbs,
                      bg: NutrientColors.netCarbsSoft,
                      onTap: _addIngredient,
                    ),
                  ],
                ),
              ),

              // Ingredient list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: List.generate(_ingredients.length, (i) {
                    final ing = _ingredients[i];
                    return _IngredientRow(
                      ingredient: ing,
                      onToggle: () => _toggleIngredient(i),
                      onWeightChanged: (w) => _updateWeight(i, w),
                      onEdit: () => _editIngredient(i),
                      onDelete: () => _deleteIngredient(i),
                    );
                  }),
                ),
              ),

              // ── Meal type picker ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEAL TYPE',
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

              // ── CTA ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NutrientColors.netCarbs,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                      'Add to $mealLabel',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small helpers ──

class _MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _MacroCard(this.label, this.value, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.65))),
          ],
        ),
      ),
    );
  }
}

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
        child: Icon(icon,
            size: 16, color: color ?? NutrientColors.secondary),
      ),
    );
  }
}

class _IngredientRow extends StatefulWidget {
  final Ingredient ingredient;
  final VoidCallback onToggle;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _IngredientRow({
    required this.ingredient,
    required this.onToggle,
    required this.onWeightChanged,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> {
  late final TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
        text: widget.ingredient.weightGrams.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(_IngredientRow old) {
    super.didUpdateWidget(old);
    if (old.ingredient.weightGrams != widget.ingredient.weightGrams) {
      _weightCtrl.text = widget.ingredient.weightGrams.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.ingredient;
    final onToggle = widget.onToggle;
    final onWeightChanged = widget.onWeightChanged;
    final onEdit = widget.onEdit;
    final onDelete = widget.onDelete;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: NutrientColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: i.selected ? NutrientColors.netCarbs : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: i.selected
                      ? NutrientColors.netCarbs
                      : NutrientColors.border,
                  width: 2,
                ),
              ),
              child: i.selected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tappable name — opens ingredient search to replace
                GestureDetector(
                  onTap: onEdit,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(i.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.swap_horiz_rounded,
                          size: 14, color: NutrientColors.netCarbs),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                // Editable weight
                Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 22,
                      child: TextField(
                        controller: _weightCtrl,
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
                                color: NutrientColors.netCarbs, width: 1.5),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: NutrientColors.netCarbs, width: 1.5),
                          ),
                          filled: false,
                        ),
                        onSubmitted: (v) {
                          final w = double.tryParse(v);
                          if (w != null && w > 0) onWeightChanged(w);
                        },
                      ),
                    ),
                    Text(' g',
                        style: TextStyle(
                            fontSize: 11, color: NutrientColors.tertiary)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_rounded,
                        size: 12, color: NutrientColors.tertiary),
                  ],
                ),
                const SizedBox(height: 4),
                // Tags
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (i.protein > 0)
                      _Tag('P ${i.protein.toStringAsFixed(0)}g',
                          NutrientColors.protein, NutrientColors.proteinSoft),
                    if (i.fat > 0)
                      _Tag('F ${i.fat.toStringAsFixed(0)}g',
                          NutrientColors.fatGood, NutrientColors.fatGoodSoft),
                    _Tag('Net ${i.netCarbs.toStringAsFixed(0)}g',
                        NutrientColors.netCarbs, NutrientColors.netCarbsSoft),
                    if (i.glycemicIndex != null)
                      _Tag('GI ${i.glycemicIndex}',
                          NutrientColors.sugar, NutrientColors.sugarSoft),
                  ],
                ),
              ],
            ),
          ),

          // Calories + delete
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${i.calories.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: NutrientColors.secondary,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close_rounded,
                    size: 16, color: NutrientColors.tertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const _Tag(this.text, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style:
              TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ─── Ingredient Search Sheet ────────────────────────────────────────────────
// Bottom sheet with text input → calls /api/parse_meal_suggestions → returns Ingredient

class _IngredientSearchSheet extends StatefulWidget {
  final String? initialQuery;
  const _IngredientSearchSheet({this.initialQuery});

  @override
  State<_IngredientSearchSheet> createState() => _IngredientSearchSheetState();
}

class _IngredientSearchSheetState extends State<_IngredientSearchSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _ctrl.text = widget.initialQuery!;
    }
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
    setState(() => _loading = true);
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final resp = await apiDio.post('/api/parse_meal_suggestions', data: {
        'text': text,
        'language': lang,
      });
      final items = (resp.data['items'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
      if (mounted) setState(() => _results = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Search ingredient',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: NutrientColors.secondary)),
          ),
          const SizedBox(height: 12),
          // Search field
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
                      hintText: 'e.g. chicken breast 150g',
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
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded,
                            color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Results
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemBuilder: (_, i) {
                final r = _results[i];
                final name = r['name'] as String? ?? '';
                final w = (r['weight_grams'] as num?)?.toDouble() ?? 100;
                final cal = (r['calories_per_100g'] as num?)?.toDouble()
                    ?? (r['calories'] as num?)?.toDouble() ?? 0;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('${w.toStringAsFixed(0)}g · ${cal.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                          fontSize: 12, color: NutrientColors.secondary)),
                  trailing: Icon(Icons.add_circle_outline_rounded,
                      color: NutrientColors.netCarbs),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, ingredientFromJson(r));
                  },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

