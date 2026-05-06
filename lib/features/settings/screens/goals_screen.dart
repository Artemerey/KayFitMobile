import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/i18n/generated/app_localizations.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _caloriesCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  late final AnimationController _enterCtrl;
  late final AnimationController _macroCtrl;

  // Live macro state for ring preview
  double _protein = 0;
  double _fat = 0;
  double _carbs = 0;
  double _calories = 0;

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

    AnalyticsService.goalsScreenOpened();
    _loadGoals();
  }

  void _onMacroChanged() {
    setState(() {
      _protein = double.tryParse(_proteinCtrl.text) ?? 0;
      _fat = double.tryParse(_fatCtrl.text) ?? 0;
      _carbs = double.tryParse(_carbsCtrl.text) ?? 0;
      _calories = double.tryParse(_caloriesCtrl.text) ?? 0;
    });
  }

  Future<void> _loadGoals() async {
    try {
      final resp = await apiDio.get('/api/goals');
      final data = resp.data as Map<String, dynamic>;
      _caloriesCtrl.text = (data['calories'] as num).toInt().toString();
      _proteinCtrl.text = (data['protein'] as num).toInt().toString();
      _fatCtrl.text = (data['fat'] as num).toInt().toString();
      _carbsCtrl.text = (data['carbs'] as num).toInt().toString();
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
      await apiDio.post('/api/goals', data: {
        'calories': int.parse(_caloriesCtrl.text),
        'protein': int.parse(_proteinCtrl.text),
        'fat': int.parse(_fatCtrl.text),
        'carbs': int.parse(_carbsCtrl.text),
      });
      // Force a refetch of stats from the backend BEFORE popping back, so the
      // dashboard rings render the new goals on the very next frame instead of
      // flashing stale values while the refetch is still in flight.
      ref.invalidate(todayStatsProvider);
      try {
        await ref.read(todayStatsProvider.future);
      } catch (_) {
        // Refetch failed — invalidation alone is enough, UI will retry when
        // it next subscribes. Don't block the save success path.
      }
      AnalyticsService.goalsSaved();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(l10n.goals_saved),
              ],
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.goals_error(e.toString())),
            backgroundColor: AppColors.accentOver,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _macroCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: _loading
          ? const Center(child: LoadingIndicator())
          : Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  // ── iOS-style large title AppBar ──────────────────
                  SliverAppBar(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    expandedHeight: 96,
                    pinned: true,
                    leading: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 17,
                          color: Color(0xFF3C3C43),
                        ),
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(0),
                      child: Container(
                        height: 0.33,
                        color: const Color(0xFFE5E5EA),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      title: Text(
                        l10n.goals_title,
                        style: const TextStyle(
                          color: Color(0xFF000000),
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      expandedTitleScale: 1.0,
                      background: const ColoredBox(color: Colors.white),
                    ),
                  ),

                  // ── Content ───────────────────────────────────────
                  SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 20),

                      // Compact macro ring preview
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _AppleMacroRing(
                          protein: _protein,
                          fat: _fat,
                          carbs: _carbs,
                          calories: _calories,
                          macroCtrl: _macroCtrl,
                          l10n: l10n,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // AI Nutritionist banner
                      _AiNutritionistBanner(context: context),
                      const SizedBox(height: 24),

                      // Section header
                      const Padding(
                        padding:
                            EdgeInsets.only(left: 16, right: 16, bottom: 8),
                        child: Text(
                          'DAILY TARGETS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF6E6E73),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),

                      // Inset-grouped fields section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _InsetGroupedSection(
                          children: [
                            _IosNumRow(
                              controller: _caloriesCtrl,
                              label: l10n.macro_calories,
                              suffix: l10n.macro_kcal,
                              icon: Icons.local_fire_department_rounded,
                              iconColor: const Color(0xFFFF3B30),
                              errEnterValue: l10n.goals_err_enter_value,
                              errEnterInt: l10n.goals_err_enter_int,
                              isLast: false,
                            ),
                            _IosNumRow(
                              controller: _proteinCtrl,
                              label: l10n.macro_protein,
                              suffix: l10n.macro_g,
                              icon: Icons.fitness_center_rounded,
                              iconColor: AppColors.accent,
                              errEnterValue: l10n.goals_err_enter_value,
                              errEnterInt: l10n.goals_err_enter_int,
                              isLast: false,
                            ),
                            _IosNumRow(
                              controller: _fatCtrl,
                              label: l10n.macro_fat,
                              suffix: l10n.macro_g,
                              icon: Icons.water_drop_rounded,
                              iconColor: AppColors.warm,
                              errEnterValue: l10n.goals_err_enter_value,
                              errEnterInt: l10n.goals_err_enter_int,
                              isLast: false,
                            ),
                            _IosNumRow(
                              controller: _carbsCtrl,
                              label: l10n.macro_carbs,
                              suffix: l10n.macro_g,
                              icon: Icons.grain_rounded,
                              iconColor: AppColors.support,
                              errEnterValue: l10n.goals_err_enter_value,
                              errEnterInt: l10n.goals_err_enter_int,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Save button — iOS blue filled
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _IosFilledButton(
                          saving: _saving,
                          label: l10n.common_save,
                          onTap: _save,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Apple compact macro ring ─────────────────────────────────────────────────

class _AppleMacroRing extends StatelessWidget {
  final double protein;
  final double fat;
  final double carbs;
  final double calories;
  final AnimationController macroCtrl;
  final AppLocalizations l10n;

  const _AppleMacroRing({
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ring — 80×80
          SizedBox(
            width: 80,
            height: 80,
            child: AnimatedBuilder(
              animation: macroCtrl,
              builder: (context0, child0) => CustomPaint(
                painter: _MacroRingPainter(
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
                          color: Color(0xFF000000),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        l10n.macro_kcal,
                        style: const TextStyle(
                          color: Color(0xFF6E6E73),
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
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AppleLegendRow(
                  color: AppColors.accent,
                  label: l10n.macro_protein,
                  value: '${protein.toStringAsFixed(0)} ${l10n.macro_g}',
                ),
                const SizedBox(height: 8),
                _AppleLegendRow(
                  color: AppColors.warm,
                  label: l10n.macro_fat,
                  value: '${fat.toStringAsFixed(0)} ${l10n.macro_g}',
                ),
                const SizedBox(height: 8),
                _AppleLegendRow(
                  color: AppColors.support,
                  label: l10n.macro_carbs,
                  value: '${carbs.toStringAsFixed(0)} ${l10n.macro_g}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppleLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _AppleLegendRow({
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
            color: Color(0xFF3C3C43),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF000000),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Ring painter ─────────────────────────────────────────────────────────────

class _MacroRingPainter extends CustomPainter {
  final double proteinFrac;
  final double fatFrac;
  final double carbsFrac;
  final double progress;

  _MacroRingPainter({
    required this.proteinFrac,
    required this.fatFrac,
    required this.carbsFrac,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = const Color(0xFFE5E5EA),
    );

    if (proteinFrac + fatFrac + carbsFrac == 0) return;

    final segments = [
      (proteinFrac, AppColors.accent),
      (fatFrac, AppColors.warm),
      (carbsFrac, AppColors.support),
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
  bool shouldRepaint(_MacroRingPainter old) =>
      old.proteinFrac != proteinFrac ||
      old.fatFrac != fatFrac ||
      old.carbsFrac != carbsFrac ||
      old.progress != progress;
}

// ─── AI Nutritionist banner ───────────────────────────────────────────────────

class _AiNutritionistBanner extends StatelessWidget {
  final BuildContext context;

  const _AiNutritionistBanner({required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF007AFF),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'AI Nutritionist',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Want to recalibrate your macro goals? Chat with our AI'
              ' Nutritionist for a personalized plan based on your'
              ' activity, diet, and progress.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF3C3C43),
                height: 1.35,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ctx.push('/chat');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'Chat with AI Nutritionist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
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

// ─── Inset-grouped section container ─────────────────────────────────────────

class _InsetGroupedSection extends StatelessWidget {
  final List<Widget> children;

  const _InsetGroupedSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// ─── iOS-style numeric input row ──────────────────────────────────────────────

class _IosNumRow extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final IconData icon;
  final Color iconColor;
  final String errEnterValue;
  final String errEnterInt;
  final bool isLast;

  const _IosNumRow({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.icon,
    required this.iconColor,
    required this.errEnterValue,
    required this.errEnterInt,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF000000),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF000000),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      errorStyle: const TextStyle(height: 0, fontSize: 0),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffix: Text(
                        ' $suffix',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return errEnterValue;
                      final n = int.tryParse(v);
                      if (n == null || n < 0) return errEnterInt;
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 46),
            child: Divider(
              height: 0.33,
              thickness: 0.33,
              color: Color(0xFFE5E5EA),
            ),
          ),
      ],
    );
  }
}

// ─── iOS blue filled save button ──────────────────────────────────────────────

class _IosFilledButton extends StatelessWidget {
  final bool saving;
  final String label;
  final VoidCallback onTap;

  const _IosFilledButton({
    required this.saving,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          color: saving ? const Color(0xFFAAAAAA) : const Color(0xFF007AFF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
        ),
      ),
    );
  }
}
