import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/i18n/generated/app_localizations.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../features/journal/screens/journal_screen.dart'
    show journalDayMealsProvider;
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
import '../../../shared/widgets/loading_indicator.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class EditMealScreen extends ConsumerStatefulWidget {
  final int mealId;
  const EditMealScreen({super.key, required this.mealId});

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
    _loadMeal();
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
      _nameCtrl.text = meal['name'] as String? ?? '';
      _caloriesCtrl.text = (meal['calories'] as num).toStringAsFixed(1);
      _proteinCtrl.text = (meal['protein'] as num).toStringAsFixed(1);
      _fatCtrl.text = (meal['fat'] as num).toStringAsFixed(1);
      _carbsCtrl.text = (meal['carbs'] as num).toStringAsFixed(1);
      final w = meal['weight'] as num?;
      _weightCtrl.text = w != null ? w.toStringAsFixed(0) : '';

      // Capture baseline for proportional recalc
      _origCalories = (meal['calories'] as num).toDouble();
      _origProtein = (meal['protein'] as num).toDouble();
      _origFat = (meal['fat'] as num).toDouble();
      _origCarbs = (meal['carbs'] as num).toDouble();
      _origWeight = w?.toDouble() ?? 0;

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

    return KeyboardDismisser(
      child: Scaffold(
        // iOS Settings system background
        backgroundColor: const Color(0xFFF2F2F7),
        body: _loading
            ? const Center(child: LoadingIndicator())
            : Form(
                key: _formKey,
                child: CustomScrollView(
                  slivers: [
                    // ── iOS-style white AppBar with hairline border ───
                    SliverAppBar(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      pinned: true,
                      elevation: 0,
                      leading: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      title: Text(
                        l10n.edit_meal_title,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(0),
                        child: Container(
                          height: 0.5,
                          color: const Color(0xFFE5E5EA),
                        ),
                      ),
                    ),

                    // ── Content ───────────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Compact neutral macro preview
                          _buildFade(
                            0,
                            _CompactMacroPreview(
                              protein: _protein,
                              fat: _fat,
                              carbs: _carbs,
                              calories: _calories,
                              macroCtrl: _macroCtrl,
                              l10n: l10n,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section: DETAILS
                          _buildFade(
                            1,
                            _SectionHeader(label: l10n.edit_meal_section_details),
                          ),
                          const SizedBox(height: 6),
                          _buildFade(
                            2,
                            _InsetGroup(
                              children: [
                                _GroupRow(
                                  label: l10n.edit_meal_name_label,
                                  child: _InlineTextField(
                                    controller: _nameCtrl,
                                    textAlign: TextAlign.end,
                                    keyboardType: TextInputType.text,
                                    validator: (v) =>
                                        v == null || v.trim().isEmpty
                                            ? l10n.edit_meal_name_error
                                            : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section: PORTION
                          _buildFade(
                            3,
                            _SectionHeader(label: l10n.edit_meal_section_portion),
                          ),
                          const SizedBox(height: 6),
                          _buildFade(
                            4,
                            _InsetGroup(
                              children: [
                                _GroupRow(
                                  label: l10n.edit_meal_weight_label,
                                  child: _InlineNumField(
                                    controller: _weightCtrl,
                                    suffix: l10n.macro_g,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return null;
                                      final n = double.tryParse(v);
                                      if (n == null || n < 0) {
                                        return l10n.edit_meal_err_invalid_number;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section: NUTRITION
                          _buildFade(
                            5,
                            _SectionHeader(
                                label: l10n.edit_meal_section_nutrition),
                          ),
                          const SizedBox(height: 6),
                          _buildFade(
                            6,
                            _InsetGroup(
                              children: [
                                _GroupRow(
                                  label: l10n.macro_calories,
                                  child: _InlineNumField(
                                    controller: _caloriesCtrl,
                                    suffix: l10n.macro_kcal,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return l10n.edit_meal_err_enter_value;
                                      }
                                      final n = double.tryParse(v);
                                      if (n == null || n < 0) {
                                        return l10n.edit_meal_err_invalid_number;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                _GroupDivider(),
                                _GroupRow(
                                  label: l10n.macro_protein,
                                  child: _InlineNumField(
                                    controller: _proteinCtrl,
                                    suffix: l10n.macro_g,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return l10n.edit_meal_err_enter_value;
                                      }
                                      final n = double.tryParse(v);
                                      if (n == null || n < 0) {
                                        return l10n.edit_meal_err_invalid_number;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                _GroupDivider(),
                                _GroupRow(
                                  label: l10n.macro_fat,
                                  child: _InlineNumField(
                                    controller: _fatCtrl,
                                    suffix: l10n.macro_g,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return l10n.edit_meal_err_enter_value;
                                      }
                                      final n = double.tryParse(v);
                                      if (n == null || n < 0) {
                                        return l10n.edit_meal_err_invalid_number;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                _GroupDivider(),
                                _GroupRow(
                                  label: l10n.macro_carbs,
                                  child: _InlineNumField(
                                    controller: _carbsCtrl,
                                    suffix: l10n.macro_g,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return l10n.edit_meal_err_enter_value;
                                      }
                                      final n = double.tryParse(v);
                                      if (n == null || n < 0) {
                                        return l10n.edit_meal_err_invalid_number;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // iOS blue filled Save button
                          _buildFade(
                            7,
                            _IosBlueButton(
                              saving: _saving,
                              label: l10n.common_save,
                              onTap: _save,
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

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 0),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: Color(0xFF8E8E93),
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ─── Inset grouped container ──────────────────────────────────────────────────

class _InsetGroup extends StatelessWidget {
  final List<Widget> children;
  const _InsetGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

// ─── Row inside group ─────────────────────────────────────────────────────────

class _GroupRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _GroupRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16),
      child: Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5EA)),
    );
  }
}

// ─── Inline text field (right-aligned value) ──────────────────────────────────

class _InlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextAlign textAlign;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _InlineTextField({
    required this.controller,
    this.textAlign = TextAlign.end,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textAlign: textAlign,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: Color(0xFF8E8E93),
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        errorStyle: TextStyle(height: 0, fontSize: 0),
      ),
    );
  }
}

// ─── Inline numeric field (right-aligned value + blue suffix) ─────────────────

class _InlineNumField extends StatelessWidget {
  final TextEditingController controller;
  final String suffix;
  final String? Function(String?)? validator;

  const _InlineNumField({
    required this.controller,
    required this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            textAlign: TextAlign.end,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: validator,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Color(0xFF8E8E93),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              errorStyle: TextStyle(height: 0, fontSize: 0),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          suffix,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: Color(0xFF007AFF),
          ),
        ),
      ],
    );
  }
}

// ─── Compact neutral macro preview card ──────────────────────────────────────

class _CompactMacroPreview extends StatelessWidget {
  final double protein;
  final double fat;
  final double carbs;
  final double calories;
  final AnimationController macroCtrl;
  final AppLocalizations l10n;

  const _CompactMacroPreview({
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.calories,
    required this.macroCtrl,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final total = protein + fat + carbs;
    final proteinFrac = total > 0 ? protein / total : 0.0;
    final fatFrac = total > 0 ? fat / total : 0.0;
    final carbsFrac = total > 0 ? carbs / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Simple neutral ring 80×80
          SizedBox(
            width: 80,
            height: 80,
            child: AnimatedBuilder(
              animation: macroCtrl,
              builder: (_, _) => CustomPaint(
                painter: _NeutralRingPainter(
                  proteinFrac: proteinFrac,
                  fatFrac: fatFrac,
                  carbsFrac: carbsFrac,
                  progress: macroCtrl.value,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        calories > 0
                            ? calories.toStringAsFixed(0)
                            : '—',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        l10n.macro_kcal,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Macro legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewLegendRow(
                  color: const Color(0xFF34C759),
                  label: l10n.macro_protein,
                  value: '${protein.toStringAsFixed(1)} ${l10n.macro_g}',
                ),
                const SizedBox(height: 8),
                _PreviewLegendRow(
                  color: const Color(0xFFFF9500),
                  label: l10n.macro_fat,
                  value: '${fat.toStringAsFixed(1)} ${l10n.macro_g}',
                ),
                const SizedBox(height: 8),
                _PreviewLegendRow(
                  color: const Color(0xFF007AFF),
                  label: l10n.macro_carbs,
                  value: '${carbs.toStringAsFixed(1)} ${l10n.macro_g}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _PreviewLegendRow({
    required this.color,
    required this.label,
    required this.value,
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
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Neutral ring painter ─────────────────────────────────────────────────────

class _NeutralRingPainter extends CustomPainter {
  final double proteinFrac;
  final double fatFrac;
  final double carbsFrac;
  final double progress;

  _NeutralRingPainter({
    required this.proteinFrac,
    required this.fatFrac,
    required this.carbsFrac,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    const strokeWidth = 9.0;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = const Color(0xFFF2F2F7),
    );

    if (proteinFrac + fatFrac + carbsFrac == 0) return;

    final segments = [
      (proteinFrac, const Color(0xFF34C759)),
      (fatFrac, const Color(0xFFFF9500)),
      (carbsFrac, const Color(0xFF007AFF)),
    ];

    double startAngle = -math.pi / 2;
    const gap = 0.04;

    for (final (frac, color) in segments) {
      if (frac <= 0) continue;
      final sweep = frac * 2 * math.pi * progress - gap;
      if (sweep <= 0) {
        startAngle += frac * 2 * math.pi * progress;
        continue;
      }
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + gap / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      startAngle += frac * 2 * math.pi * progress;
    }
  }

  @override
  bool shouldRepaint(_NeutralRingPainter old) =>
      old.proteinFrac != proteinFrac ||
      old.fatFrac != fatFrac ||
      old.carbsFrac != carbsFrac ||
      old.progress != progress;
}

// ─── iOS blue filled Save button ──────────────────────────────────────────────

class _IosBlueButton extends StatefulWidget {
  final bool saving;
  final String label;
  final VoidCallback onTap;

  const _IosBlueButton({
    required this.saving,
    required this.label,
    required this.onTap,
  });

  @override
  State<_IosBlueButton> createState() => _IosBlueButtonState();
}

class _IosBlueButtonState extends State<_IosBlueButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _scale = Tween(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: widget.saving ? null : (_) => _ctrl.forward(),
        onTapUp: widget.saving
            ? null
            : (_) {
                _ctrl.reverse();
                widget.onTap();
              },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          decoration: BoxDecoration(
            color: widget.saving
                ? const Color(0xFFADB5BD)
                : const Color(0xFF007AFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: widget.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
