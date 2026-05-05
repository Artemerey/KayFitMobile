// KF2-JOURNAL — Journal V2 screen (Kayfit 2.0 redesign).
//
// Assembles the four KF2-FOUND foundation widgets into the full Journal layout:
//   TopBar → Kayfit2CalendarStrip → KayfitRingsSummary → grouped MealRows
//   → Kayfit2TabBar (sticky bottom)
//
// Gated via --dart-define=KF2_JOURNAL=true in router.dart.
// The legacy JournalScreen remains untouched.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../features/journal/screens/journal_screen.dart'
    show journalDayMealsProvider;
import '../../../shared/models/k2_meal_row_data.dart';
import '../../../shared/models/meal.dart';
import '../../../shared/theme/kayfit2_theme.dart';
import '../../../shared/widgets/kayfit2_calendar_strip.dart';
import '../../../shared/widgets/kayfit2_meal_row.dart';
import '../../../shared/widgets/kayfit2_tab_bar.dart';
import '../../../shared/widgets/kayfit_rings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Seed fallback meals (used when provider fails or is loading)
// ─────────────────────────────────────────────────────────────────────────────

const _kFallbackMeals = <K2MealRowData>[
  K2MealRowData(
    id: 'fb-m1',
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
    id: 'fb-m2',
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
    id: 'fb-m3',
    time: '16:30',
    type: 'snack',
    name: 'greek yogurt, almonds',
    kcal: 210,
    protein: 18,
    fat: 11,
    carbs: 9,
    source: K2MealSource.text,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns today's date as an ISO string 'yyyy-MM-dd'.
String _todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

/// Converts a [Meal] from the API into the KF2 view-model.
K2MealRowData _toRowData(Meal m) {
  // Extract HH:MM from ISO createdAt, fallback to '--:--'.
  String time = '--:--';
  final raw = m.createdAt;
  if (raw != null) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt != null) {
      time = '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  // Source: photo when source == 'photo' or image_url is present.
  final isPhoto = m.source == 'photo' || m.sourceUrl != null;
  final source = isPhoto ? K2MealSource.photo : K2MealSource.text;
  final photoSeed = isPhoto ? m.id.hashCode % 3 : null;

  return K2MealRowData(
    id: m.id.toString(),
    time: time,
    type: m.mealType?.toLowerCase() ?? 'other',
    name: m.dishName ?? m.name,
    kcal: m.calories.round(),
    protein: m.protein.round(),
    fat: m.fat.round(),
    carbs: m.carbs.round(),
    source: source,
    photoSeed: photoSeed,
  );
}

/// Groups a list of [K2MealRowData] by type, in canonical order.
///
/// Order: breakfast → lunch → snack → dinner → other.
List<(String, List<K2MealRowData>)> _groupRows(List<K2MealRowData> rows) {
  const order = ['breakfast', 'lunch', 'snack', 'dinner', 'other'];
  final map = <String, List<K2MealRowData>>{};
  for (final r in rows) {
    final key = order.contains(r.type) ? r.type : 'other';
    map.putIfAbsent(key, () => []).add(r);
  }
  return [
    for (final key in order)
      if (map[key]?.isNotEmpty ?? false) (key, map[key]!),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class JournalV2Screen extends ConsumerStatefulWidget {
  const JournalV2Screen({super.key});

  @override
  ConsumerState<JournalV2Screen> createState() => _JournalV2ScreenState();
}

class _JournalV2ScreenState extends ConsumerState<JournalV2Screen> {
  bool _calExpanded = false;
  String _calSelected = 'today';

  // The date key that drives provider lookups.
  String get _dateKey =>
      _calSelected == 'today' ? _todayIso() : _calSelected;

  @override
  Widget build(BuildContext context) {
    const t = K2Theme.light;

    final statsAsync = ref.watch(todayStatsProvider);
    final mealsAsync = ref.watch(journalDayMealsProvider(_dateKey));

    return Scaffold(
      backgroundColor: t.bg,
      bottomNavigationBar: Kayfit2TabBar(
        theme: t,
        active: 'journal',
        onTab: (key) {
          if (key == 'chat') context.go('/chat');
        },
        onAdd: () => context.go('/chat'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar ─────────────────────────────────────────────────────
            _TopBar(theme: t),

            // ── Calendar strip ───────────────────────────────────────────────
            Kayfit2CalendarStrip(
              theme: t,
              expanded: _calExpanded,
              onToggle: () =>
                  setState(() => _calExpanded = !_calExpanded),
              selectedIso: _calSelected,
              onSelect: (iso) => setState(() => _calSelected = iso),
            ),

            // ── Rings summary ────────────────────────────────────────────────
            statsAsync.when(
              loading: () => const _RingsLoading(),
              error: (_, __) => const _RingsFallback(),
              data: (stats) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: KayfitRingsSummary(
                  theme: t,
                  values: KayfitRingsValues(
                    kcal: stats.caloriesEaten,
                    kcalGoal: stats.caloriesGoal > 0
                        ? stats.caloriesGoal
                        : 2100,
                    protein: stats.proteinEaten,
                    proteinGoal: stats.proteinGoal > 0
                        ? stats.proteinGoal
                        : 130,
                    carbs: stats.carbsEaten,
                    carbsGoal: stats.carbsGoal > 0
                        ? stats.carbsGoal
                        : 250,
                    fat: stats.fatEaten,
                    fatGoal: stats.fatGoal > 0 ? stats.fatGoal : 70,
                  ),
                ),
              ),
            ),

            Container(height: 1, color: t.hairline),

            // ── Meal list ────────────────────────────────────────────────────
            Expanded(
              child: mealsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => _MealList(
                  rows: _kFallbackMeals,
                  theme: t,
                  onRowTap: (id) {},
                ),
                data: (meals) {
                  if (meals.isEmpty) {
                    return _EmptyMeals(theme: t);
                  }
                  final rows = meals.map(_toRowData).toList();
                  return _MealList(
                    rows: rows,
                    theme: t,
                    onRowTap: (id) {},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TopBar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.theme});

  final K2Theme theme;

  static const _kHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Account icon
            IconButton(
              icon: Icon(
                Icons.account_circle_outlined,
                color: theme.fg,
                size: 26,
              ),
              onPressed: () => context.go('/settings'),
              tooltip: 'Account',
            ),
            const Spacer(),
            // App wordmark
            Text(
              'KAYFIT',
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 2.5,
                fontFamily: K2Fonts.sans,
                fontWeight: FontWeight.w600,
                color: theme.fg,
              ),
            ),
            const Spacer(),
            // Menu icon
            IconButton(
              icon: Icon(
                Icons.more_horiz_rounded,
                color: theme.fg,
                size: 26,
              ),
              onPressed: () => context.go('/settings'),
              tooltip: 'Menu',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rings loading / fallback placeholders
// ─────────────────────────────────────────────────────────────────────────────

class _RingsLoading extends StatelessWidget {
  const _RingsLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 140 + 24 + 16, // ringSize + top + bottom padding
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _RingsFallback extends StatelessWidget {
  const _RingsFallback();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: KayfitRingsSummary(
        theme: K2Theme.light,
        values: const KayfitRingsValues(
          kcal: 0,
          kcalGoal: 2100,
          protein: 0,
          proteinGoal: 130,
          carbs: 0,
          carbsGoal: 250,
          fat: 0,
          fatGoal: 70,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meal list (grouped)
// ─────────────────────────────────────────────────────────────────────────────

class _MealList extends StatelessWidget {
  const _MealList({
    required this.rows,
    required this.theme,
    required this.onRowTap,
  });

  final List<K2MealRowData> rows;
  final K2Theme theme;
  final ValueChanged<String> onRowTap;

  @override
  Widget build(BuildContext context) {
    final groups = _groupRows(rows);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final (type, meals) in groups) ...[
          _GroupHeader(type: type, theme: theme),
          for (final meal in meals)
            Kayfit2MealRow(
              key: ValueKey(meal.id),
              meal: meal,
              theme: theme,
              onTap: () => onRowTap(meal.id),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group header
// ─────────────────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.type, required this.theme});

  final String type;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.0,
          fontFamily: K2Fonts.sans,
          fontWeight: FontWeight.w500,
          color: theme.fgMute,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_menu_outlined,
                    size: 40,
                    color: theme.fgMute,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No meals today',
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.fgDim,
                      fontFamily: K2Fonts.sans,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to log your first meal',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.fgMute,
                      fontFamily: K2Fonts.sans,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
