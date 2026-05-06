// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$todayStatsHash() => r'd0a45de0f10882c43cc97edc82ae240238787495';

/// See also [todayStats].
@ProviderFor(todayStats)
final todayStatsProvider = AutoDisposeFutureProvider<MacroStats>.internal(
  todayStats,
  name: r'todayStatsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$todayStatsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TodayStatsRef = AutoDisposeFutureProviderRef<MacroStats>;
String _$todayMealsHash() => r'c1db4093d36f671e782942db2b36633a5c8aea51';

/// See also [todayMeals].
@ProviderFor(todayMeals)
final todayMealsProvider = AutoDisposeFutureProvider<List<Meal>>.internal(
  todayMeals,
  name: r'todayMealsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$todayMealsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TodayMealsRef = AutoDisposeFutureProviderRef<List<Meal>>;
String _$userGoalsHash() => r'266bc0149d7b85f80c66f82f73d6866436c71eb1';

/// See also [userGoals].
@ProviderFor(userGoals)
final userGoalsProvider = AutoDisposeFutureProvider<MacroGoals>.internal(
  userGoals,
  name: r'userGoalsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userGoalsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserGoalsRef = AutoDisposeFutureProviderRef<MacroGoals>;
String _$dailyKcalHistoryHash() => r'ba1b2c9a0aa6f921c14fc50dc042f0a7b9bcb5fc';

/// Per-day kcal totals derived from the user's full meal history.
///
/// The KF2 calendar strip uses these to render the green/red status ring on
/// each date cell. Dates not present in the map render as empty (no meals
/// logged that day).
///
/// Lazy-fetches `/api/meals/history?limit=500` once and groups by local
/// (yyyy-MM-dd) date. Recompute is triggered by invalidating the provider
/// from the meal-save and meal-edit code paths.
///
/// Copied from [dailyKcalHistory].
@ProviderFor(dailyKcalHistory)
final dailyKcalHistoryProvider =
    AutoDisposeFutureProvider<Map<String, double>>.internal(
      dailyKcalHistory,
      name: r'dailyKcalHistoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$dailyKcalHistoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DailyKcalHistoryRef = AutoDisposeFutureProviderRef<Map<String, double>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
