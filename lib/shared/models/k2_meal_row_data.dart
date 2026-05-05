// KF2-FOUND-4 — Meal row data model for Kayfit 2.0.
//
// A lightweight value type consumed by Kayfit2MealRow.
// Intentionally separate from the backend Meal model (freezed/JSON)
// so the UI layer has no coupling to the API schema.

import 'package:flutter/foundation.dart';

/// The input method used to log the meal.
enum K2MealSource {
  photo,
  voice,
  text,
  barcode;

  /// Short uppercase label shown in the row when there is no photo thumbnail.
  String get label => switch (this) {
        K2MealSource.photo => 'PHOTO',
        K2MealSource.voice => 'VOICE',
        K2MealSource.text => 'TEXT',
        K2MealSource.barcode => 'SCAN',
      };
}

/// Immutable view-model for a single meal entry rendered by [Kayfit2MealRow].
@immutable
class K2MealRowData {
  const K2MealRowData({
    required this.id,
    required this.time,
    required this.type,
    required this.name,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.source,
    this.photoSeed,
  });

  /// Unique identifier — used as widget key material.
  final String id;

  /// Display time in 'HH:MM' format.
  final String time;

  /// Meal category: 'breakfast' | 'lunch' | 'dinner' | 'snack'.
  final String type;

  /// Human-readable meal name.
  final String name;

  /// Calories.
  final int kcal;

  /// Protein in grams.
  final int protein;

  /// Fat in grams.
  final int fat;

  /// Carbohydrates in grams.
  final int carbs;

  /// How the meal was logged.
  final K2MealSource source;

  /// Deterministic seed for the striped photo placeholder gradient.
  /// Only meaningful when [source] == [K2MealSource.photo].
  final int? photoSeed;

  /// Whether this row should render the [Kayfit2MealPhoto] thumbnail.
  bool get hasPhoto =>
      source == K2MealSource.photo && photoSeed != null;

  K2MealRowData copyWith({
    String? id,
    String? time,
    String? type,
    String? name,
    int? kcal,
    int? protein,
    int? fat,
    int? carbs,
    K2MealSource? source,
    int? photoSeed,
  }) {
    return K2MealRowData(
      id: id ?? this.id,
      time: time ?? this.time,
      type: type ?? this.type,
      name: name ?? this.name,
      kcal: kcal ?? this.kcal,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
      source: source ?? this.source,
      photoSeed: photoSeed ?? this.photoSeed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is K2MealRowData &&
        other.id == id &&
        other.time == time &&
        other.type == type &&
        other.name == name &&
        other.kcal == kcal &&
        other.protein == protein &&
        other.fat == fat &&
        other.carbs == carbs &&
        other.source == source &&
        other.photoSeed == photoSeed;
  }

  @override
  int get hashCode => Object.hash(
        id,
        time,
        type,
        name,
        kcal,
        protein,
        fat,
        carbs,
        source,
        photoSeed,
      );
}
