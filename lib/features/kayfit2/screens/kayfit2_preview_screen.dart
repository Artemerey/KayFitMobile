// Kayfit 2.0 preview screen — wires the new design tokens + KayfitRings widget
// onto a real route so the look can be validated on simulator/device before
// the full redesign lands.
//
// Settings → AI Data Processing-style entry → /kayfit2/preview.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/k2_meal_row_data.dart';
import '../../../shared/theme/kayfit2_theme.dart';
import '../../../shared/widgets/kayfit2_calendar_strip.dart';
import '../../../shared/widgets/kayfit2_meal_row.dart';
import '../../../shared/widgets/kayfit2_tab_bar.dart';
import '../../../shared/widgets/kayfit_rings.dart';

/// Seed data matching JSX prototype lines 13-30.
const _kSampleMeals = [
  K2MealRowData(
    id: 'm1',
    time: '08:24',
    type: 'breakfast',
    name: 'oatmeal with berries',
    kcal: 320,
    protein: 12,
    fat: 6,
    carbs: 54,
    source: K2MealSource.photo,
    photoSeed: 1,
  ),
  K2MealRowData(
    id: 'm2',
    time: '13:10',
    type: 'lunch',
    name: 'chicken bowl, rice, broccoli',
    kcal: 540,
    protein: 42,
    fat: 14,
    carbs: 58,
    source: K2MealSource.voice,
  ),
  K2MealRowData(
    id: 'm3',
    time: '16:30',
    type: 'snack',
    name: 'greek yogurt, almonds',
    kcal: 210,
    protein: 18,
    fat: 11,
    carbs: 9,
    source: K2MealSource.text,
  ),
  K2MealRowData(
    id: 'm4',
    time: '11:05',
    type: 'snack',
    name: 'cappuccino + croissant',
    kcal: 380,
    protein: 8,
    fat: 19,
    carbs: 42,
    source: K2MealSource.photo,
    photoSeed: 2,
  ),
];

class Kayfit2PreviewScreen extends StatefulWidget {
  const Kayfit2PreviewScreen({super.key});

  @override
  State<Kayfit2PreviewScreen> createState() => _Kayfit2PreviewScreenState();
}

class _Kayfit2PreviewScreenState extends State<Kayfit2PreviewScreen> {
  bool _dark = false;
  String _activeTab = 'journal';

  // ── KF2-FOUND-2: Calendar strip state ─────────────────────────────────────
  bool _calExpanded = false;
  String _calSelected = 'today';

  /// Hard-coded demo statuses: 3 good, 1 over, rest empty.
  Map<String, K2DayStatus> _buildDemoStatuses() {
    final today = DateTime.now();
    return {
      _isoPreview(today.subtract(const Duration(days: 6))): K2DayStatus.good,
      _isoPreview(today.subtract(const Duration(days: 4))): K2DayStatus.good,
      _isoPreview(today.subtract(const Duration(days: 2))): K2DayStatus.over,
      _isoPreview(today.subtract(const Duration(days: 1))): K2DayStatus.good,
    };
  }

  static String _isoPreview(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = _dark ? K2Theme.dark : K2Theme.light;

    final values = const KayfitRingsValues(
      kcal: 1450,
      kcalGoal: 2100,
      protein: 65,
      proteinGoal: 130,
      carbs: 180,
      carbsGoal: 250,
      fat: 30,
      fatGoal: 70,
    );

    return Scaffold(
      backgroundColor: t.bg,
      bottomNavigationBar: Kayfit2TabBar(
        theme: t,
        active: _activeTab,
        onTab: (key) => setState(() => _activeTab = key),
        onAdd: () => setState(() => _activeTab = 'chat'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar: back + title + theme toggle ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: t.fg,
                      size: 20,
                    ),
                    onPressed: () => context.pop(),
                    splashRadius: 22,
                  ),
                  const Spacer(),
                  Text(
                    'KAYFIT 2.0 · PREVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: t.fgDim,
                      fontFamily: K2Fonts.sans,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _dark,
                    onChanged: (v) => setState(() => _dark = v),
                    activeThumbColor: K2Colors.accent,
                    activeTrackColor: K2Colors.accent.withAlpha(77),
                  ),
                ],
              ),
            ),

            Container(height: 1, color: t.hairline),

            // ── Hero rings card ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: KayfitRingsSummary(values: values, theme: t),
            ),

            // ── KF2-FOUND-2: Calendar strip ─────────────────────────────────
            Kayfit2CalendarStrip(
              theme: t,
              expanded: _calExpanded,
              onToggle: () => setState(() => _calExpanded = !_calExpanded),
              selectedIso: _calSelected,
              onSelect: (iso) => setState(() => _calSelected = iso),
              statusByIso: _buildDemoStatuses(),
            ),

            // ── KF2-FOUND-4: Sample meals ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: _SectionLabel('sample meals · KF2-FOUND-4', t),
            ),
            ..._kSampleMeals.map(
              (meal) => Kayfit2MealRow(
                key: ValueKey(meal.id),
                meal: meal,
                theme: t,
              ),
            ),

            // ── Notes ───────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('what this shows', t),
                    const SizedBox(height: 8),
                    _Body(
                      'Foundation widget KF2-FOUND-1: Apple Activity 4-ring '
                      'summary. Outer → inner: kcal · protein · carbs · fat. '
                      'Each ring is a CustomPainter arc with a linear-gradient '
                      'shader matching the JSX prototype.',
                      t,
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('next foundation tickets', t),
                    const SizedBox(height: 8),
                    _Bullet('KF2-FOUND-2 · Calendar strip + month grid ✓', t),
                    _Bullet('KF2-FOUND-3 · Tab bar Apple-style with center + ✓', t),
                    _Bullet('KF2-FOUND-4 · Meal photo placeholder + meal row ✓', t),
                    _Bullet('KF2-JOURNAL · JournalV2 screen (assemble)', t),
                    _Bullet('KF2-CHAT · ChatV2 screen + thinking bubble', t),
                    const SizedBox(height: 20),
                    _SectionLabel('design source', t),
                    const SizedBox(height: 8),
                    _Body(
                      'specs/kayfit_2.0/HLD_kayfit_2.0_redesign.md\n'
                      'specs/kayfit_2.0/source_handoff/project/Kayfit 2.0.html',
                      t,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.t);

  final String text;
  final K2Theme t;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        letterSpacing: 1.2,
        color: t.fgDim,
        fontFamily: K2Fonts.sans,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text, this.t);

  final String text;
  final K2Theme t;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: t.fg,
        fontFamily: K2Fonts.sans,
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, this.t);

  final String text;
  final K2Theme t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 10),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: t.fgMute,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: t.fg,
                fontFamily: K2Fonts.mono,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
