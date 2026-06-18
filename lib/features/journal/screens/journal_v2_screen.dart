// KF2-JOURNAL — Journal V2 screen (Kayfit 2.0 redesign).
//
// Assembles the four KF2-FOUND foundation widgets into the full Journal layout:
//   TopBar → Kayfit2CalendarStrip → KayfitRingsSummary → grouped MealRows
//   → Kayfit2TabBar (sticky bottom)
//
// Gated via --dart-define=KF2_JOURNAL=true in router.dart.
// The legacy JournalScreen remains untouched.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/api/api_client.dart';
import '../../../core/i18n/generated/app_localizations.dart';
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
import '../widgets/copy_target_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────

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

/// Matches a trailing `(NNNg)` / `(NNN g)` / `(NNN гр)` suffix and captures
/// the numeric value. Legacy meals were stored with weight embedded in
/// `display_name` (`add_selected_meals` did `f"{name} ({int(w)}g)"`). The
/// new pipeline keeps weight in its own column, but old rows in the DB
/// still carry the suffix — extract it so the pill has a value to show.
final _kWeightSuffixRe = RegExp(
  r'\s*[\(\[]\s*(\d+(?:[.,]\d+)?)\s*(?:g|г|gr|гр)\s*[\)\]]\s*$',
  caseSensitive: false,
);

/// Strips the legacy weight suffix from a meal name (see [_kWeightSuffixRe]).
String _stripWeightSuffix(String name) =>
    name.replaceAll(_kWeightSuffixRe, '').trim();

/// Extracts the numeric weight from a legacy `(NNNg)` suffix, if present.
/// Returns null when the suffix isn't there or the number is unparseable.
double? _extractWeightFromName(String name) {
  final m = _kWeightSuffixRe.firstMatch(name);
  if (m == null) return null;
  return double.tryParse(m.group(1)!.replaceAll(',', '.'));
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

  // Prefer dishName when present; clean either source from the legacy
  // "(NNN g)" suffix so the row can show the weight as its own pill.
  final rawName = m.dishName ?? m.name;
  final cleanName = _stripWeightSuffix(rawName);

  // weightGrams resolution order:
  //   1. Backend column `weight` (new pipeline, after 2026-05-26)
  //   2. Parsed from legacy `(NNNg)` suffix in the original name (old rows)
  //   3. null — pill shows "+ масса" placeholder for the user to fill in
  final double? weightGrams = (m.weight != null && m.weight! > 0)
      ? m.weight
      : _extractWeightFromName(rawName);

  return K2MealRowData(
    id: m.id.toString(),
    time: time,
    type: m.mealType?.toLowerCase() ?? 'other',
    name: cleanName,
    kcal: m.calories.round(),
    protein: m.protein.round(),
    fat: m.fat.round(),
    carbs: m.carbs.round(),
    source: source,
    weightGrams: weightGrams,
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.journal_meal_deleted),
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.journal_could_not_delete),
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

  /// IDs of the most recently copied meals — used for Undo.
  List<int>? _lastCopiedIds;

  /// Target dates of the most recent copy — used to invalidate providers on Undo.
  List<String>? _lastCopiedDates;

  /// Cancels the Undo window when it expires or a new copy starts.
  Timer? _undoTimer;

  /// Tracks in-flight inline weight PATCHes per meal id so a fast double-tap
  /// can't fire two requests for the same row.
  final Set<int> _weightInflight = <int>{};

  /// Inline weight pill handler — PATCHes the meal with the new weight AND
  /// macros scaled proportionally to the new/old weight ratio, then refreshes
  /// rings + list. Falls back gracefully (snackbar) on bad input or HTTP
  /// failure.
  Future<void> _onRowWeightChange(String idStr, double newGrams) async {
    final intId = int.tryParse(idStr);
    if (intId == null || newGrams <= 0 || _weightInflight.contains(intId)) {
      return;
    }
    final meals = ref.read(journalDayMealsProvider(_dateKey)).valueOrNull;
    final meal = meals?.firstWhere(
      (m) => m.id == intId,
      orElse: () => meals.first,
    );
    if (meal == null) return;
    // Resolve the baseline weight the same way _toRowData does: column first,
    // legacy `(NNNg)` suffix second. This keeps macro scaling consistent for
    // pre-2026-05-26 rows that only carry the weight in the display name.
    final rawName = meal.dishName ?? meal.name;
    final oldGrams = (meal.weight != null && meal.weight! > 0)
        ? meal.weight
        : _extractWeightFromName(rawName);
    if (oldGrams == null || oldGrams <= 0) {
      // No prior weight at all (truly legacy row). Commit weight alone and
      // leave macros — user can then edit macros from the detail screen.
      await _patchMealWeight(intId, newGrams: newGrams);
      return;
    }
    if ((newGrams - oldGrams).abs() < 0.5) return; // unchanged
    final ratio = newGrams / oldGrams;
    await _patchMealWeight(
      intId,
      newGrams: newGrams,
      calories: meal.calories * ratio,
      protein: meal.protein * ratio,
      fat: meal.fat * ratio,
      carbs: meal.carbs * ratio,
    );
  }

  Future<void> _patchMealWeight(
    int mealId, {
    required double newGrams,
    double? calories,
    double? protein,
    double? fat,
    double? carbs,
  }) async {
    _weightInflight.add(mealId);
    HapticFeedback.selectionClick();
    try {
      await apiDio.patch('/api/meals/$mealId', data: {
        'weight_grams': newGrams,
        'calories': ?calories,
        'protein': ?protein,
        'fat': ?fat,
        'carbs': ?carbs,
      });
      // Refresh everything that displays this meal so the row + rings update.
      ref.invalidate(journalDayMealsProvider(_dateKey));
      ref.invalidate(todayStatsProvider);
      ref.invalidate(todayMealsProvider);
      ref.invalidate(dailyKcalHistoryProvider);
    } on Exception {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.journal_could_not_update_weight),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      _weightInflight.remove(mealId);
    }
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _clearUndo() {
    _undoTimer?.cancel();
    _undoTimer = null;
    _lastCopiedIds = null;
    _lastCopiedDates = null;
  }

  Future<void> _undoLastCopy() async {
    final ids = _lastCopiedIds;
    final dates = _lastCopiedDates;
    _clearUndo();
    if (ids == null || ids.isEmpty) return;

    await Future.wait(
      ids.map((id) async {
        try {
          await apiDio.delete('/api/meals/$id');
        } on Exception {
          // Ignore individual delete failures during undo
        }
      }),
    );

    if (dates != null) {
      for (final iso in dates) {
        ref.invalidate(journalDayMealsProvider(iso));
      }
    }
    ref.invalidate(todayStatsProvider);
    ref.invalidate(todayMealsProvider);
    ref.invalidate(dailyKcalHistoryProvider);

    if (!mounted) return;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isRu ? 'Скопированные записи удалены' : 'Copy undone'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Opens [CopyTargetSheet], then copies [mealIds] to every selected date.
  Future<void> _openCopySheet(List<int> mealIds) async {
    if (_isCopying) return;
    HapticFeedback.selectionClick();

    final targetDates = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CopyTargetSheet(currentDate: _dateKey),
    );

    if (targetDates == null || targetDates.isEmpty || !mounted) return;
    await _copyMealsBatch(mealIds, targetDates);
  }

  Future<void> _copyMealsBatch(
    List<int> mealIds,
    List<String> targetDates,
  ) async {
    setState(() => _isCopying = true);
    _clearUndo();
    try {
      final response = await apiDio.post('/api/meals/copy-batch', data: {
        'meal_ids': mealIds,
        'target_dates': targetDates,
      });
      final copiedIds =
          (response.data['copied_ids'] as List).cast<int>();

      _lastCopiedIds = copiedIds;
      _lastCopiedDates = targetDates;

      for (final iso in targetDates) {
        ref.invalidate(journalDayMealsProvider(iso));
      }
      ref.invalidate(dailyKcalHistoryProvider);

      if (!mounted) return;
      HapticFeedback.lightImpact();

      // Navigate to the first (earliest) target date so the user sees the result.
      setState(() => _calSelected = targetDates.first);

      final l10n = AppLocalizations.of(context)!;
      final isRu = l10n.localeName == 'ru';
      final n = targetDates.length;
      final snackText = n == 1
          ? l10n.journal_copied_to(_humanReadableDate(targetDates.first, l10n: l10n))
          : l10n.journal_copied_n_dates(n, isRu ? _russianDayWord(n) : (n == 1 ? 'day' : 'days'));

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackText),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: isRu ? 'Отменить' : 'Undo',
            onPressed: _undoLastCopy,
          ),
        ),
      );

      _undoTimer = Timer(const Duration(seconds: 4), _clearUndo);
    } on Exception {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.journal_could_not_copy),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCopying = false);
    }
  }

  String _russianDayWord(int n) {
    if (n % 100 >= 11 && n % 100 <= 14) return 'дн.';
    return switch (n % 10) {
      1 => 'день',
      2 || 3 || 4 => 'дня',
      _ => 'дн.',
    };
  }

  /// Long-press handler — opens CopyTargetSheet for a single meal.
  Future<void> _onCopyTapped(String idStr) async {
    final intId = int.tryParse(idStr);
    if (intId == null) return;
    await _openCopySheet([intId]);
  }

  /// ⋮ handler on a meal-type group header — copies all meals in the group.
  Future<void> _onCopyGroupTapped(
    String mealType,
    List<String> ids,
  ) async {
    final intIds = ids.map(int.parse).toList();
    if (intIds.isEmpty) return;
    await _openCopySheet(intIds);
  }

  String _humanReadableDate(String iso, {required AppLocalizations l10n}) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return iso;
    if (m < 1 || m > 12) return iso;
    try {
      final locale = l10n.localeName;
      return intl.DateFormat('d MMM', locale).format(DateTime(y, m, d));
    } on Object {
      return iso;
    }
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
          if (key == 'recipes') context.go('/recipes');
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
            // Rings: while meals are loading we render empty rings (0/goal)
            // rather than a second CircularProgressIndicator — the meal list
            // below already shows one, and stacking two indicators on the
            // same screen looked like a glitch.
            Builder(builder: (_) {
              final meals = mealsAsync.valueOrNull ?? const <Meal>[];
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
            }),

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
                  error: (err, st) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: _EmptyMeals(theme: t),
                      ),
                    ],
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
                    // Build a lookup so the row tap can hand the Meal to
                    // EditMealScreen via `extra` — skips the history fetch.
                    final mealById = {
                      for (final m in meals) m.id.toString(): m,
                    };
                    return _MealList(
                      rows: rows,
                      theme: t,
                      onRowTap: (id) {
                        final intId = int.tryParse(id);
                        if (intId == null) return;
                        context.push(
                          '/meals/$intId/edit',
                          extra: mealById[id],
                        );
                      },
                      onDelete: _deleteMeal,
                      onCopy: _onCopyTapped,
                      onCopyGroup: _onCopyGroupTapped,
                      onWeightChange: _onRowWeightChange,
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
// Meal list (grouped)
// ─────────────────────────────────────────────────────────────────────────────

class _MealList extends StatelessWidget {
  const _MealList({
    required this.rows,
    required this.theme,
    required this.onRowTap,
    this.onDelete,
    this.onCopy,
    this.onCopyGroup,
    this.onWeightChange,
  });

  final List<K2MealRowData> rows;
  final K2Theme theme;
  final ValueChanged<String> onRowTap;

  /// Returns a Future that resolves to true if delete succeeded, false to
  /// keep the row. Null means the parent doesn't support delete (fallback
  /// rows in error state pass null and don't render the swipe action).
  final Future<bool> Function(String id)? onDelete;

  /// Long-press / ⋮ handler that copies a single meal.
  final void Function(String id)? onCopy;

  /// ⋮ handler on a group header — copies the entire meal-type group.
  final void Function(String mealType, List<String> ids)? onCopyGroup;

  /// Inline weight edit committed on a row. Receives `(mealId, newGrams)`.
  /// Null disables the inline edit (pill becomes read-only).
  final void Function(String id, double grams)? onWeightChange;

  @override
  Widget build(BuildContext context) {
    final groups = _groupRows(rows);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final (type, meals) in groups) ...[
          _GroupHeader(
            type: type,
            meals: meals,
            theme: theme,
            onCopyGroup: onCopyGroup == null
                ? null
                : () => onCopyGroup!(
                      type,
                      meals.map((m) => m.id).toList(),
                    ),
          ),
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
                  onMore: onCopy == null ? null : () => onCopy!(meal.id),
                  onWeightChange: onWeightChange == null
                      ? null
                      : (g) => onWeightChange!(meal.id, g),
                ),
              )
            else
              Kayfit2MealRow(
                key: ValueKey(meal.id),
                meal: meal,
                theme: theme,
                onTap: () => onRowTap(meal.id),
                onLongPress: onCopy == null ? null : () => onCopy!(meal.id),
                onMore: onCopy == null ? null : () => onCopy!(meal.id),
                onWeightChange: onWeightChange == null
                    ? null
                    : (g) => onWeightChange!(meal.id, g),
              ),
        ],
        const SizedBox(height: 16),
      ],
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

({String emoji, String label}) _groupTitle(String type, AppLocalizations l10n) =>
    switch (type) {
      'breakfast' => (emoji: '🌅', label: l10n.mealType_breakfast),
      'lunch' => (emoji: '☀️', label: l10n.mealType_lunch),
      'snack' => (emoji: '🍎', label: l10n.mealType_snack),
      'dinner' => (emoji: '🌙', label: l10n.mealType_dinner),
      _ => (emoji: '🍽', label: type),
    };

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.type,
    required this.meals,
    required this.theme,
    this.onCopyGroup,
  });

  final String type;
  final List<K2MealRowData> meals;
  final K2Theme theme;

  /// When non-null, a ⋮ icon button appears at the trailing edge of the header
  /// and triggers copying the entire group.
  final VoidCallback? onCopyGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cfg = _groupTitle(type, l10n);
    final emoji = cfg.emoji;
    final title = cfg.label;
    final totalKcal = meals.fold<int>(0, (s, m) => s + m.kcal);

    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 4),
      padding: EdgeInsets.fromLTRB(16, 12, onCopyGroup != null ? 4 : 16, 8),
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
            '$totalKcal ${l10n.macro_kcal}',
            style: TextStyle(
              fontSize: 12,
              fontFamily: K2Fonts.mono,
              fontWeight: FontWeight.w500,
              color: theme.fgDim,
            ),
          ),
          if (onCopyGroup != null) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.content_copy_rounded,
                  size: 16,
                  color: theme.fgMute,
                ),
                onPressed: onCopyGroup,
                tooltip: l10n.journal_copy_to_another_date,
              ),
            ),
          ],
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
                    AppLocalizations.of(context)!.journal_no_meals_today,
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.fgDim,
                      fontFamily: K2Fonts.sans,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.journal_tap_plus_to_log,
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        l10n.journal_disclaimer,
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

/// Exposes [_EmptyMeals] for widget tests only.
@visibleForTesting
Widget emptyMealsWidgetForTest(K2Theme theme) => _EmptyMeals(theme: theme);
