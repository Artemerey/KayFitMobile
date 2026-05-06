import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/meal.dart';
import '../../../shared/models/stats.dart';

part 'dashboard_provider.g.dart';

@riverpod
Future<MacroStats> todayStats(TodayStatsRef ref) async {
  try {
    // Backend's /api/stats returns today's aggregate when called without args.
    // Passing a `date` query parameter currently triggers a server-side 500
    // ("Внутренняя ошибка сервера") — confirmed against production on 2026-05-05.
    // If/when the date filter is fixed server-side, swap this back.
    debugPrint('[stats] GET /api/stats (no date — server bug)');
    final resp = await apiDio.get('/api/stats');
    final raw = resp.data;
    debugPrint('[stats] /api/stats status=${resp.statusCode} raw=$raw');

    if (raw is! Map<String, dynamic>) {
      debugPrint('[stats] unexpected payload type ${raw.runtimeType}');
      return _zeroStats;
    }
    final data = raw;

    // Backend returns nested: {calories: {current, goal}, protein: {current, goal}, ...}
    double cur(String key) {
      final m = data[key];
      if (m is Map) return (m['current'] as num?)?.toDouble() ?? 0;
      return (data['${key}_eaten'] as num?)?.toDouble() ?? 0;
    }
    double gol(String key) {
      final m = data[key];
      if (m is Map) return (m['goal'] as num?)?.toDouble() ?? 0;
      return (data['${key}_goal'] as num?)?.toDouble() ?? 0;
    }

    final stats = MacroStats(
      caloriesEaten: cur('calories'),
      caloriesGoal: gol('calories'),
      proteinEaten: cur('protein'),
      proteinGoal: gol('protein'),
      fatEaten: cur('fat'),
      fatGoal: gol('fat'),
      carbsEaten: cur('carbs'),
      carbsGoal: gol('carbs'),
      compulsiveCount: (data['compulsive_count'] as num?)?.toInt() ?? 0,
    );
    debugPrint('[stats] parsed kcal=${stats.caloriesEaten}/${stats.caloriesGoal} '
        'P=${stats.proteinEaten}/${stats.proteinGoal} '
        'F=${stats.fatEaten}/${stats.fatGoal} '
        'C=${stats.carbsEaten}/${stats.carbsGoal}');
    return stats;
  } catch (e, st) {
    debugPrint('[stats] /api/stats FAILED: $e');
    debugPrint('[stats] stack: $st');
    return _zeroStats;
  }
}

const _zeroStats = MacroStats(
  caloriesEaten: 0, caloriesGoal: 0,
  proteinEaten: 0, proteinGoal: 0,
  fatEaten: 0, fatGoal: 0,
  carbsEaten: 0, carbsGoal: 0,
);

@riverpod
Future<List<Meal>> todayMeals(TodayMealsRef ref) async {
  // Same server bug as /api/stats — passing `date` triggers 500.
  // /api/meals without args returns today's meals (matches backend semantics).
  final resp = await apiDio.get('/api/meals');
  final list = resp.data as List<dynamic>;
  return list.map((e) => Meal.fromJson(e as Map<String, dynamic>)).toList();
}

class MacroGoals {
  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  const MacroGoals({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  bool get isSet =>
      calories > 0 || protein > 0 || fat > 0 || carbs > 0;

  static const empty = MacroGoals(
    calories: 0,
    protein: 0,
    fat: 0,
    carbs: 0,
  );
}

@riverpod
Future<MacroGoals> userGoals(UserGoalsRef ref) async {
  try {
    final resp = await apiDio.get('/api/goals');
    final data = resp.data as Map<String, dynamic>;
    debugPrint('[goals] /api/goals raw response: $data');
    return MacroGoals(
      calories: (data['calories'] as num?)?.toDouble() ?? 0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0,
      carbs: (data['carbs'] as num?)?.toDouble() ?? 0,
    );
  } catch (_) {
    debugPrint('[goals] /api/goals failed — returning empty');
    return MacroGoals.empty;
  }
}

/// Per-day kcal totals derived from the user's full meal history.
///
/// The KF2 calendar strip uses these to render the green/red status ring on
/// each date cell. Dates not present in the map render as empty (no meals
/// logged that day).
///
/// Lazy-fetches `/api/meals/history?limit=500` once and groups by local
/// (yyyy-MM-dd) date. Recompute is triggered by invalidating the provider
/// from the meal-save and meal-edit code paths.
@riverpod
Future<Map<String, double>> dailyKcalHistory(DailyKcalHistoryRef ref) async {
  try {
    final resp = await apiDio.get(
      '/api/meals/history',
      queryParameters: {'limit': 500},
    );
    final list = (resp.data as List<dynamic>);
    final byDate = <String, double>{};
    for (final raw in list) {
      final m = raw as Map<String, dynamic>;
      final iso = (m['createdAt'] ?? m['time']) as String?;
      if (iso == null) continue;
      final dt = DateTime.tryParse(iso)?.toLocal();
      if (dt == null) continue;
      final key = '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}';
      // Each row's kcal is rounded to match journal-row display rounding,
      // keeping the calendar status in lock-step with what the user sees.
      final kcal = (m['calories'] as num?)?.round().toDouble() ?? 0;
      byDate[key] = (byDate[key] ?? 0) + kcal;
    }
    debugPrint('[history] dailyKcalHistory loaded ${byDate.length} dates');
    return byDate;
  } catch (e) {
    debugPrint('[history] dailyKcalHistory failed: $e');
    return const {};
  }
}
