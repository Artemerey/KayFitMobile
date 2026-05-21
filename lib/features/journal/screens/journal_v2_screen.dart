// KF2-JOURNAL — Journal V2 screen (Kayfit 2.0 redesign).
//
// Assembles the four KF2-FOUND foundation widgets into the full Journal layout:
//   TopBar → Kayfit2CalendarStrip → KayfitRingsSummary → grouped MealRows
//   → Kayfit2TabBar (sticky bottom)
//
// Gated via --dart-define=KF2_JOURNAL=true in router.dart.
// The legacy JournalScreen remains untouched.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
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
    photoUrl: m.sourceUrl,
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

  ({double kcal, double protein, double carbs, double fat}) _resolveGoals(
    AsyncValue<MacroGoals> goalsAsync,
  ) {
    final goals = goalsAsync.valueOrNull;
    double pick(double fromGoals, double fallback) =>
        fromGoals > 0 ? fromGoals : fallback;
    return (
      kcal: pick(goals?.calories ?? 0, 2100),
      protein: pick(goals?.protein ?? 0, 130),
      carbs: pick(goals?.carbs ?? 0, 250),
      fat: pick(goals?.fat ?? 0, 70),
    );
  }

  /// Swipe-to-delete handler for journal rows.
  /// Returns true to let `Dismissible` collapse the row, false to bounce back.
  /// On success: DELETE /api/meals/$id, invalidate dashboard + calendar +
  /// per-day meals so rings/headers update immediately.
  Future<bool> _deleteMeal(String idStr) async {
    final intId = int.tryParse(idStr);
    if (intId == null) return false;
    HapticFeedback.mediumImpact();
    try {
      await apiDio.delete('/api/meals/$intId');
      ref.invalidate(todayStatsProvider);
      ref.invalidate(todayMealsProvider);
      ref.invalidate(dailyKcalHistoryProvider);
      ref.invalidate(journalDayMealsProvider(_dateKey));
      if (mounted) {
        final isRu = Localizations.localeOf(context).languageCode == 'ru';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isRu ? 'Приём пищи удалён' : 'Meal deleted'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return true;
    } on Exception {
      if (mounted) {
        final isRu = Localizations.localeOf(context).languageCode == 'ru';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isRu ? 'Не удалось удалить' : 'Could not delete'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
  }

  /// Tracks in-flight copy requests so a double long-press doesn't fire the
  /// same copy twice.
  bool _isCopying = false;

  /// Long-press handler — confirms the intent, picks a target date, copies
  /// the meal, refreshes the affected day's provider, shows a snackbar with
  /// a CTA back to that date.
  Future<void> _onCopyTapped(String idStr) async {
    final intId = int.tryParse(idStr);
    if (intId == null || _isCopying) return;
    HapticFeedback.selectionClick();
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _CopyMealActionSheet(isRu: isRu),
    );
    if (confirmed != true || !mounted) return;

    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
      helpText: isRu ? 'Дата копии' : 'Copy to date',
      cancelText: isRu ? 'Отмена' : 'Cancel',
      confirmText: isRu ? 'Копировать' : 'Copy',
    );
    if (picked == null || !mounted) return;

    final targetIso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await _copyMealToDate(intId, targetIso, isRu: isRu);
  }

  Future<void> _copyMealToDate(
    int mealId,
    String targetIso, {
    required bool isRu,
  }) async {
    setState(() => _isCopying = true);
    try {
      await apiDio.post(
        '/api/meals/$mealId/copy',
        data: {'target_date': targetIso},
      );
      // Refresh the destination day so a switch via the snackbar CTA shows
      // the copied meal. The source day doesn't change.
      ref.invalidate(journalDayMealsProvider(targetIso));
      ref.invalidate(dailyKcalHistoryProvider);
      // If the copy landed on the currently-visible day, the watch above
      // will rebuild it automatically; nothing extra needed.
      if (!mounted) return;
      final humanDate = _humanReadableDate(targetIso, isRu: isRu);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu ? 'Скопировано на $humanDate' : 'Copied to $humanDate',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: isRu ? 'Перейти' : 'Open',
            onPressed: () {
              if (!mounted) return;
              // `_dateKey` is a getter over `_calSelected`, so updating
              // the latter is enough to re-watch the new date.
              setState(() => _calSelected = targetIso);
            },
          ),
        ),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu ? 'Не удалось скопировать' : 'Could not copy',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCopying = false);
    }
  }

  String _humanReadableDate(String iso, {required bool isRu}) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return iso;
    const monthsRu = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final months = isRu ? monthsRu : monthsEn;
    if (m < 1 || m > 12) return iso;
    return isRu ? '$d ${months[m - 1]}' : '${months[m - 1]} $d';
  }

  /// Sum macros over the meal list for the currently-selected day.
  /// Replaces /api/stats which only ever returns "today" — the rings now
  /// stay in lock-step with what's actually rendered in the list below.
  ///
  /// Each meal's value is rounded BEFORE summing to match the per-row
  /// display rounding (Kayfit2MealRow renders `m.kcal.round()` etc).
  /// Without per-meal rounding, the rings drift by ±1 from the visible
  /// row totals (e.g. raw sum 2518.7 → ring shows 2518 while the journal
  /// rows visibly add up to 2519).
  ({double kcal, double protein, double carbs, double fat}) _sumMeals(
    List<Meal> meals,
  ) {
    double k = 0, p = 0, f = 0, c = 0;
    for (final m in meals) {
      k += m.calories.round();
      p += m.protein.round();
      f += m.fat.round();
      c += m.carbs.round();
    }
    return (kcal: k, protein: p, fat: f, carbs: c);
  }

  @override
  Widget build(BuildContext context) {
    const t = K2Theme.light;

    final goalsAsync = ref.watch(userGoalsProvider);
    final mealsAsync = ref.watch(journalDayMealsProvider(_dateKey));
    final kcalHistory = ref.watch(dailyKcalHistoryProvider).valueOrNull;
    final dayGoal = goalsAsync.valueOrNull?.calories ?? 0;
    final statusByIso = (kcalHistory == null || dayGoal <= 0)
        ? <String, K2DayStatus>{}
        : <String, K2DayStatus>{
            for (final entry in kcalHistory.entries)
              if (entry.value > 0)
                entry.key:
                    entry.value > dayGoal ? K2DayStatus.over : K2DayStatus.good,
          };

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
              statusByIso: statusByIso,
            ),

            // ── Rings summary ────────────────────────────────────────────────
            // Rings derive their "eaten" totals from the same meal list shown
            // below — single source of truth, always in sync with the
            // calendar-selected day. /api/stats is intentionally NOT used here:
            // it only returns "today", which would desync the rings whenever
            // the user picks a different date.
            mealsAsync.when(
              loading: () => const _RingsLoading(),
              error: (_, __) => const _RingsFallback(),
              data: (meals) {
                final eaten = _sumMeals(meals);
                final g = _resolveGoals(goalsAsync);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: KayfitRingsSummary(
                    theme: t,
                    values: KayfitRingsValues(
                      kcal: eaten.kcal,
                      kcalGoal: g.kcal,
                      protein: eaten.protein,
                      proteinGoal: g.protein,
                      carbs: eaten.carbs,
                      carbsGoal: g.carbs,
                      fat: eaten.fat,
                      fatGoal: g.fat,
                    ),
                  ),
                );
              },
            ),

            // Guideline 1.4.1 — disclaimer required on every screen with
            // calculated health values.
            _JournalDisclaimerBar(theme: t),

            Container(height: 1, color: t.hairline),

            // ── Meal list ────────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(todayStatsProvider);
                  ref.invalidate(userGoalsProvider);
                  ref.invalidate(journalDayMealsProvider(_dateKey));
                  ref.invalidate(dailyKcalHistoryProvider);
                  try {
                    await Future.wait([
                      ref.read(todayStatsProvider.future),
                      ref.read(userGoalsProvider.future),
                      ref.read(journalDayMealsProvider(_dateKey).future),
                      ref.read(dailyKcalHistoryProvider.future),
                    ]);
                  } catch (_) {
                    // Swallow — UI errored already shows fallback state.
                  }
                },
                child: mealsAsync.when(
                  loading: () => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 200),
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  error: (err, st) => _MealList(
                    rows: _kFallbackMeals,
                    theme: t,
                    onRowTap: (id) {},
                  ),
                  data: (meals) {
                    if (meals.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: _EmptyMeals(theme: t),
                          ),
                        ],
                      );
                    }
                    final rows = meals.map(_toRowData).toList();
                    return _MealList(
                      rows: rows,
                      theme: t,
                      onRowTap: (id) {
                        final intId = int.tryParse(id);
                        if (intId != null) context.push('/meals/$intId/edit');
                      },
                      onDelete: _deleteMeal,
                      onCopy: _onCopyTapped,
                    );
                  },
                ),
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
    this.onDelete,
    this.onCopy,
  });

  final List<K2MealRowData> rows;
  final K2Theme theme;
  final ValueChanged<String> onRowTap;

  /// Returns a Future that resolves to true if delete succeeded, false to
  /// keep the row. Null means the parent doesn't support delete (fallback
  /// rows in error state pass null and don't render the swipe action).
  final Future<bool> Function(String id)? onDelete;

  /// Long-press handler that copies the meal to another date.
  final void Function(String id)? onCopy;

  @override
  Widget build(BuildContext context) {
    final groups = _groupRows(rows);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final (type, meals) in groups) ...[
          _GroupHeader(type: type, meals: meals, theme: theme),
          for (final meal in meals)
            if (onDelete != null)
              Dismissible(
                key: ValueKey('dismiss_${meal.id}'),
                direction: DismissDirection.endToStart,
                background: _DeleteSwipeBackground(theme: theme),
                confirmDismiss: (_) async {
                  return await onDelete!(meal.id);
                },
                child: Kayfit2MealRow(
                  key: ValueKey(meal.id),
                  meal: meal,
                  theme: theme,
                  onTap: () => onRowTap(meal.id),
                  onLongPress: onCopy == null ? null : () => onCopy!(meal.id),
                ),
              )
            else
              Kayfit2MealRow(
                key: ValueKey(meal.id),
                meal: meal,
                theme: theme,
                onTap: () => onRowTap(meal.id),
                onLongPress: onCopy == null ? null : () => onCopy!(meal.id),
              ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Bottom sheet shown on long-press of a meal row. A confirmation step
/// before the date picker so accidental long-presses don't immediately
/// open the calendar.
class _CopyMealActionSheet extends StatelessWidget {
  const _CopyMealActionSheet({required this.isRu});

  final bool isRu;

  @override
  Widget build(BuildContext context) {
    const t = K2Theme.light;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                isRu ? 'Действия с приёмом пищи' : 'Meal actions',
                style: TextStyle(
                  fontSize: 13,
                  color: t.fgMute,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Container(height: 1, color: t.hairline),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: Text(
                isRu ? 'Копировать на другую дату' : 'Copy to another date',
              ),
              onTap: () => Navigator.of(context).pop(true),
            ),
            Container(height: 1, color: t.hairline),
            ListTile(
              title: Text(isRu ? 'Отмена' : 'Cancel'),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Red trash background revealed under a meal row during right-to-left swipe.
class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: const Color(0xFFFF3B30), // iOS systemRed
      child: const Icon(
        Icons.delete_outline_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group header
// ─────────────────────────────────────────────────────────────────────────────

const _kGroupTitles = <String, (String, String)>{
  'breakfast': ('🌅', 'Breakfast'),
  'lunch': ('☀️', 'Lunch'),
  'snack': ('🍎', 'Snack'),
  'dinner': ('🌙', 'Dinner'),
  'other': ('🍽', 'Other'),
};

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.type,
    required this.meals,
    required this.theme,
  });

  final String type;
  final List<K2MealRowData> meals;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final cfg = _kGroupTitles[type] ?? ('🍽', type);
    final emoji = cfg.$1;
    final title = cfg.$2;
    final totalKcal = meals.fold<int>(0, (s, m) => s + m.kcal);

    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.hairline),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontFamily: K2Fonts.sans,
              fontWeight: FontWeight.w600,
              color: theme.fg,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· ${meals.length}',
            style: TextStyle(
              fontSize: 12,
              fontFamily: K2Fonts.mono,
              color: theme.fgMute,
            ),
          ),
          const Spacer(),
          Text(
            '$totalKcal kcal',
            style: TextStyle(
              fontSize: 12,
              fontFamily: K2Fonts.mono,
              fontWeight: FontWeight.w500,
              color: theme.fgDim,
            ),
          ),
        ],
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

// ── Guideline 1.4.1 disclaimer ───────────────────────────────────────────────

class _JournalDisclaimerBar extends StatelessWidget {
  const _JournalDisclaimerBar({required this.theme});
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final text = isRu
        ? 'Расчёты КБЖУ — ориентировочные. Не заменяют консультацию врача.'
        : 'Calorie estimates are approximate. Not a substitute for medical advice.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: theme.fgMute,
          fontFamily: K2Fonts.sans,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
