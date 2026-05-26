import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/i18n/generated/app_localizations.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../features/journal/screens/journal_screen.dart'
    show journalDayMealsProvider;
import '../../../shared/models/meal.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/theme/kayfit2_theme.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
import '../../../shared/widgets/loading_indicator.dart';

// Legacy meals (pre-2026-05-26) stored weight as a `(NNNg)` suffix inside the
// display name. New meals keep it in the dedicated `weight` column. These two
// helpers normalise both formats so the edit screen always shows a clean name
// AND a populated weight field.
final _kWeightSuffixRe = RegExp(
  r'\s*[\(\[]\s*(\d+(?:[.,]\d+)?)\s*(?:g|г|gr|гр)\s*[\)\]]\s*$',
  caseSensitive: false,
);
String _stripWeightSuffix(String name) =>
    name.replaceAll(_kWeightSuffixRe, '').trim();
double? _extractWeightFromName(String name) {
  final m = _kWeightSuffixRe.firstMatch(name);
  if (m == null) return null;
  return double.tryParse(m.group(1)!.replaceAll(',', '.'));
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class EditMealScreen extends ConsumerStatefulWidget {
  final int mealId;

  /// Optional pre-loaded Meal passed from the caller (Journal list / dashboard)
  /// so the screen can populate its fields synchronously without the
  /// `/api/meals/history` round-trip. Falls back to the network fetch when
  /// null (deep links, push notifications).
  final Meal? initial;

  const EditMealScreen({super.key, required this.mealId, this.initial});

  @override
  ConsumerState<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends ConsumerState<EditMealScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  late final AnimationController _enterCtrl;
  late final AnimationController _macroCtrl;

  // Live macro state for preview
  double _protein = 0;
  double _fat = 0;
  double _carbs = 0;
  double _calories = 0;

  // Baseline KBJU values captured on load — used for proportional recalc
  double _origCalories = 0;
  double _origProtein = 0;
  double _origFat = 0;
  double _origCarbs = 0;
  double _origWeight = 0;

  // Actual date of the meal (YYYY-MM-DD), used to invalidate the correct
  // journal provider after save. Falls back to today if unknown.
  String? _mealDateKey;

  Timer? _weightDebounce;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _macroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    for (final ctrl in [_proteinCtrl, _fatCtrl, _carbsCtrl, _caloriesCtrl]) {
      ctrl.addListener(_onMacroChanged);
    }
    _weightCtrl.addListener(_onWeightChanged);

    AnalyticsService.editMealOpened(widget.mealId);

    // Fast path: caller passed the Meal directly (Journal row tap). Populate
    // synchronously and start the entrance animation right away — no spinner.
    final pre = widget.initial;
    if (pre != null) {
      _hydrateFromMeal(pre);
      _loading = false;
      _enterCtrl.forward().then((_) => _macroCtrl.forward());
    } else {
      _loadMeal();
    }
  }

  /// Mirrors `_loadMeal`'s field population from an in-memory Meal. Strips
  /// the legacy `(NNNg)` weight suffix from the name and uses the parsed
  /// number as the weight when the dedicated column is empty.
  void _hydrateFromMeal(Meal m) {
    final rawName = m.dishName ?? m.name;
    _nameCtrl.text = _stripWeightSuffix(rawName);
    _caloriesCtrl.text = m.calories.toStringAsFixed(1);
    _proteinCtrl.text = m.protein.toStringAsFixed(1);
    _fatCtrl.text = m.fat.toStringAsFixed(1);
    _carbsCtrl.text = m.carbs.toStringAsFixed(1);

    final colWeight = (m.weight != null && m.weight! > 0) ? m.weight : null;
    final legacyWeight = _extractWeightFromName(rawName);
    final w = colWeight ?? legacyWeight;
    _weightCtrl.text = w != null ? w.toStringAsFixed(0) : '';

    _origCalories = m.calories;
    _origProtein = m.protein;
    _origFat = m.fat;
    _origCarbs = m.carbs;
    _origWeight = w ?? 0;

    final raw = m.createdAt;
    if (raw != null) {
      final dt = DateTime.tryParse(raw)?.toLocal();
      if (dt != null) {
        _mealDateKey = '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')}';
      }
    }
  }

  void _onMacroChanged() {
    setState(() {
      _protein = double.tryParse(_proteinCtrl.text) ?? 0;
      _fat = double.tryParse(_fatCtrl.text) ?? 0;
      _carbs = double.tryParse(_carbsCtrl.text) ?? 0;
      _calories = double.tryParse(_caloriesCtrl.text) ?? 0;
    });
  }

  void _onWeightChanged() {
    _weightDebounce?.cancel();
    _weightDebounce = Timer(const Duration(milliseconds: 300), () {
      final newW = double.tryParse(_weightCtrl.text.trim());
      if (newW == null || newW <= 0) return;
      if (newW == _origWeight) return; // no change
      // When `_origWeight` is known, scale from it. Otherwise — legacy meals
      // without a stored weight — fall back to a 100 g baseline so the user
      // still gets proportional updates: typing 200 doubles the macros,
      // typing 50 halves them. The first edit they make becomes the new
      // baseline below, so subsequent edits scale from THAT value.
      final baseline = _origWeight > 0 ? _origWeight : 100.0;
      final ratio = newW / baseline;
      _caloriesCtrl.text = (_origCalories * ratio).toStringAsFixed(1);
      _proteinCtrl.text = (_origProtein * ratio).toStringAsFixed(1);
      _fatCtrl.text = (_origFat * ratio).toStringAsFixed(1);
      _carbsCtrl.text = (_origCarbs * ratio).toStringAsFixed(1);
      // Re-baseline so that further edits compute against the user's most
      // recent confirmed numbers, not the original (which they've now
      // overridden). Without this, typing 200 → 250 → 300 would re-derive
      // each value from the ORIGINAL macros rather than chaining smoothly.
      _origCalories = double.parse(_caloriesCtrl.text);
      _origProtein = double.parse(_proteinCtrl.text);
      _origFat = double.parse(_fatCtrl.text);
      _origCarbs = double.parse(_carbsCtrl.text);
      _origWeight = newW;
      // _onMacroChanged fires automatically via listeners — updates preview
    });
  }

  Future<void> _loadMeal() async {
    try {
      // Use the history endpoint so meals from any date can be loaded, not
      // just today's. Limit=500 matches what journalDayMealsProvider fetches.
      final resp = await apiDio.get(
        '/api/meals/history',
        queryParameters: {'limit': 500},
      );
      final list = resp.data as List<dynamic>;
      final meal = list
          .cast<Map<String, dynamic>>()
          .firstWhere((m) => m['id'] == widget.mealId);
      final rawName = (meal['dish_name'] as String?)
          ?? (meal['name'] as String?)
          ?? '';
      _nameCtrl.text = _stripWeightSuffix(rawName);
      _caloriesCtrl.text = (meal['calories'] as num).toStringAsFixed(1);
      _proteinCtrl.text = (meal['protein'] as num).toStringAsFixed(1);
      _fatCtrl.text = (meal['fat'] as num).toStringAsFixed(1);
      _carbsCtrl.text = (meal['carbs'] as num).toStringAsFixed(1);
      final colW = (meal['weight'] as num?)?.toDouble();
      final w = (colW != null && colW > 0)
          ? colW
          : _extractWeightFromName(rawName);
      _weightCtrl.text = w != null ? w.toStringAsFixed(0) : '';

      // Capture baseline for proportional recalc
      _origCalories = (meal['calories'] as num).toDouble();
      _origProtein = (meal['protein'] as num).toDouble();
      _origFat = (meal['fat'] as num).toDouble();
      _origCarbs = (meal['carbs'] as num).toDouble();
      _origWeight = w ?? 0;

      // Capture the meal's actual date so we invalidate the right provider.
      final timeRaw = meal['time'] as String?;
      if (timeRaw != null) {
        final dt = DateTime.tryParse(timeRaw)?.toLocal();
        if (dt != null) {
          _mealDateKey = '${dt.year.toString().padLeft(4, '0')}-'
              '${dt.month.toString().padLeft(2, '0')}-'
              '${dt.day.toString().padLeft(2, '0')}';
        }
      }
    } catch (_) {
      // leave fields empty
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _enterCtrl.forward().then((_) => _macroCtrl.forward());
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final wRaw = _weightCtrl.text.trim();
      final parsedWeight = wRaw.isEmpty ? null : double.tryParse(wRaw);
      if (wRaw.isNotEmpty && parsedWeight == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.edit_meal_err_invalid_number),
              backgroundColor: AppColors.accentOver,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        setState(() => _saving = false);
        return;
      }
      await apiDio.patch('/api/meals/${widget.mealId}', data: {
        'name': _nameCtrl.text.trim(),
        'calories': double.parse(_caloriesCtrl.text),
        'protein': double.parse(_proteinCtrl.text),
        'fat': double.parse(_fatCtrl.text),
        'carbs': double.parse(_carbsCtrl.text),
        'weight_grams': ?parsedWeight,
      });
      AnalyticsService.editMealSaved(widget.mealId);

      // Invalidate everything that displays this meal — list rows, totals, rings.
      // Use the meal's actual date (captured on load) so journal providers for
      // past dates are also refreshed correctly. Falls back to today.
      final today = DateTime.now();
      final todayIso = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      final mealDateIso = _mealDateKey ?? todayIso;
      ref.invalidate(todayStatsProvider);
      ref.invalidate(todayMealsProvider);
      ref.invalidate(journalDayMealsProvider(mealDateIso));
      if (mealDateIso != todayIso) {
        ref.invalidate(journalDayMealsProvider(todayIso));
      }
      ref.invalidate(dailyKcalHistoryProvider);
      try {
        await Future.wait([
          ref.read(todayStatsProvider.future),
          ref.read(todayMealsProvider.future),
          ref.read(journalDayMealsProvider(mealDateIso).future),
          ref.read(dailyKcalHistoryProvider.future),
        ]);
      } catch (_) {
        // Refetch failure surfaces via UI's error path — don't block save success.
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(l10n.edit_meal_saved),
              ],
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.edit_meal_error(e.toString())),
            backgroundColor: AppColors.accentOver,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _weightDebounce?.cancel();
    _weightCtrl.removeListener(_onWeightChanged);
    _enterCtrl.dispose();
    _macroCtrl.dispose();
    _nameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Animation<double> _fadeFor(int i) => CurvedAnimation(
        parent: _enterCtrl,
        curve: Interval(
          (i * 0.1).clamp(0.0, 0.7),
          ((i * 0.1) + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      );

  Animation<Offset> _slideFor(int i) =>
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _enterCtrl,
          curve: Interval(
            (i * 0.1).clamp(0.0, 0.7),
            ((i * 0.1) + 0.4).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );

  Widget _buildFade(int i, Widget child) {
    return FadeTransition(
      opacity: _fadeFor(i),
      child: SlideTransition(position: _slideFor(i), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const t = K2Theme.light;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    return KeyboardDismisser(
      child: Scaffold(
        backgroundColor: t.bg,
        body: _loading
            ? const Center(child: LoadingIndicator())
            : Form(
                key: _formKey,
                child: CustomScrollView(
                  slivers: [
                    // ── K2 top bar ────────────────────────────────────
                    SliverAppBar(
                      backgroundColor: t.bg,
                      surfaceTintColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      pinned: true,
                      elevation: 0,
                      leading: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: t.fg,
                        ),
                      ),
                      title: Text(
                        l10n.edit_meal_title,
                        style: TextStyle(
                          color: t.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          fontFamily: K2Fonts.sans,
                        ),
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(0),
                        child: Container(height: 1, color: t.hairline),
                      ),
                    ),

                    // ── Content card ─────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildFade(
                            0,
                            _K2IngredientCard(
                              theme: t,
                              nameCtrl: _nameCtrl,
                              weightCtrl: _weightCtrl,
                              caloriesCtrl: _caloriesCtrl,
                              proteinCtrl: _proteinCtrl,
                              fatCtrl: _fatCtrl,
                              carbsCtrl: _carbsCtrl,
                              calories: _calories,
                              protein: _protein,
                              fat: _fat,
                              carbs: _carbs,
                              isRu: isRu,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildFade(
                            1,
                            _K2SaveButton(
                              saving: _saving,
                              label: l10n.common_save,
                              onTap: _save,
                              theme: t,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─── K2 ingredient card — name + weight pill + filled KБЖУ row ───────────────
//
// Single self-contained card. Each numeric value (weight / kcal / protein /
// fat / carbs) is a tappable chip that morphs into an inline TextField on
// tap. Weight edits propagate to macros via the listener wired in initState
// (`_onWeightChanged`); the macro chips also commit their controllers via
// `_onMacroChanged` so the live preview stays in sync.

class _K2IngredientCard extends StatelessWidget {
  const _K2IngredientCard({
    required this.theme,
    required this.nameCtrl,
    required this.weightCtrl,
    required this.caloriesCtrl,
    required this.proteinCtrl,
    required this.fatCtrl,
    required this.carbsCtrl,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.isRu,
    required this.l10n,
  });

  final K2Theme theme;
  final TextEditingController nameCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController caloriesCtrl;
  final TextEditingController proteinCtrl;
  final TextEditingController fatCtrl;
  final TextEditingController carbsCtrl;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final bool isRu;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final unit = isRu ? 'г' : 'g';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name (header) ────────────────────────────────────────
          TextFormField(
            controller: nameCtrl,
            validator: (v) => v == null || v.trim().isEmpty
                ? l10n.edit_meal_name_error
                : null,
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.fg,
              fontFamily: K2Fonts.sans,
            ),
            decoration: InputDecoration(
              hintText: l10n.edit_meal_name_label,
              hintStyle: TextStyle(
                fontSize: 17,
                color: theme.fgMute,
                fontFamily: K2Fonts.sans,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 1, color: theme.hairline),
          const SizedBox(height: 14),

          // ── Weight pill (standalone button, inline editable) ─────
          Row(
            children: [
              Text(
                isRu ? 'Вес' : 'Weight',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.fgMute,
                  fontFamily: K2Fonts.sans,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              _InlinePill(
                controller: weightCtrl,
                suffix: unit,
                width: 110,
                fontSize: 16,
                bold: true,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Filled KБЖУ row — 4 tappable chips ───────────────────
          Text(
            isRu ? 'КБЖУ' : 'KBJU',
            style: TextStyle(
              fontSize: 11,
              color: theme.fgMute,
              fontFamily: K2Fonts.sans,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MacroCell(
                  label: isRu ? 'ккал' : 'kcal',
                  controller: caloriesCtrl,
                  highlighted: true,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MacroCell(
                  label: isRu ? 'Б' : 'P',
                  controller: proteinCtrl,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MacroCell(
                  label: isRu ? 'Ж' : 'F',
                  controller: fatCtrl,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MacroCell(
                  label: isRu ? 'У' : 'C',
                  controller: carbsCtrl,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Inline editable pill (used for the weight button) ───────────────────────
//
// Renders as a chip with the controller's text + suffix + edit icon. Tap →
// expands to a TextField focused on the value. On submit / focus loss the
// pill returns and the listener attached to `controller` (in the parent
// State) fires its recalc logic.

class _InlinePill extends StatefulWidget {
  const _InlinePill({
    required this.controller,
    required this.suffix,
    required this.theme,
    this.width = 96,
    this.fontSize = 14,
    this.bold = false,
  });

  final TextEditingController controller;
  final String suffix;
  final K2Theme theme;
  final double width;
  final double fontSize;
  final bool bold;

  @override
  State<_InlinePill> createState() => _InlinePillState();
}

class _InlinePillState extends State<_InlinePill> {
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus && _editing) {
      setState(() => _editing = false);
    }
  }

  void _start() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    if (_editing) {
      return SizedBox(
        width: widget.width,
        height: 36,
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          textAlign: TextAlign.center,
          onSubmitted: (_) => setState(() => _editing = false),
          style: TextStyle(
            fontSize: widget.fontSize,
            color: t.fg,
            fontFamily: K2Fonts.mono,
            fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w600,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: K2Colors.accent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: K2Colors.accent, width: 1.5),
            ),
            suffixText: widget.suffix,
            suffixStyle: TextStyle(
              fontSize: 12,
              color: t.fgMute,
              fontFamily: K2Fonts.mono,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _start,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        width: widget.width,
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: K2Colors.accent.withValues(alpha: 0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.controller.text.isEmpty ? '—' : widget.controller.text,
              style: TextStyle(
                fontSize: widget.fontSize,
                color: t.fg,
                fontFamily: K2Fonts.mono,
                fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              widget.suffix,
              style: TextStyle(
                fontSize: 12,
                color: t.fgMute,
                fontFamily: K2Fonts.mono,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.edit_outlined,
              size: 13,
              color: K2Colors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single KБЖУ cell (label below value, tappable to edit) ──────────────────

class _MacroCell extends StatefulWidget {
  const _MacroCell({
    required this.label,
    required this.controller,
    required this.theme,
    this.highlighted = false,
  });

  final String label;
  final TextEditingController controller;
  final K2Theme theme;
  final bool highlighted;

  @override
  State<_MacroCell> createState() => _MacroCellState();
}

class _MacroCellState extends State<_MacroCell> {
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
    widget.controller.addListener(_listen);
  }

  void _listen() => mounted ? setState(() {}) : null;

  @override
  void dispose() {
    widget.controller.removeListener(_listen);
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus && _editing) {
      setState(() => _editing = false);
    }
  }

  void _start() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.controller.text.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final bg = widget.highlighted ? K2Colors.accent.withValues(alpha: 0.08) : t.bg;
    final borderColor = widget.highlighted
        ? K2Colors.accent.withValues(alpha: 0.35)
        : t.border;
    final valueColor = widget.highlighted ? K2Colors.accent : t.fg;

    return GestureDetector(
      onTap: _editing ? null : _start,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_editing)
              SizedBox(
                height: 24,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  onSubmitted: (_) => setState(() => _editing = false),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                    fontFamily: K2Fonts.mono,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              )
            else
              Text(
                _displayValue(widget.controller.text),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  fontFamily: K2Fonts.mono,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                color: t.fgMute,
                fontFamily: K2Fonts.sans,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show a rounded integer when the controller has a fractional zero
  /// (`120.0` → `120`); else show the raw text so user edits aren't reformatted.
  String _displayValue(String raw) {
    if (raw.isEmpty) return '—';
    final v = double.tryParse(raw);
    if (v == null) return raw;
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }
}

// ─── K2 save button — full-width black/white pill ────────────────────────────

class _K2SaveButton extends StatefulWidget {
  const _K2SaveButton({
    required this.saving,
    required this.label,
    required this.onTap,
    required this.theme,
  });

  final bool saving;
  final String label;
  final VoidCallback onTap;
  final K2Theme theme;

  @override
  State<_K2SaveButton> createState() => _K2SaveButtonState();
}

class _K2SaveButtonState extends State<_K2SaveButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return ScaleTransition(
      scale: _press,
      child: GestureDetector(
        onTapDown: (_) => _press.reverse(),
        onTapUp: (_) {
          _press.forward();
          if (!widget.saving) widget.onTap();
        },
        onTapCancel: () => _press.forward(),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: widget.saving ? t.fgMute : t.fg,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: widget.saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.bg,
                  ),
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.bg,
                    fontFamily: K2Fonts.sans,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
