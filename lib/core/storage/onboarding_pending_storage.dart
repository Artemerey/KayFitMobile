import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPendingData {
  final int? age;
  final double? height;
  final String? gender;
  final double? weight;
  final double? targetWeight;
  final String trainingDays; // comma-separated or "none"
  final List<String> healthConditions;
  final String dietType;
  final String? foodRestrictions;
  final List<String> goals;
  final double? weightLossSpeedKgPerWeek;

  const OnboardingPendingData({
    this.age,
    this.height,
    this.gender,
    this.weight,
    this.targetWeight,
    this.trainingDays = '',
    this.healthConditions = const ['none'],
    this.dietType = 'none',
    this.foodRestrictions,
    this.goals = const [],
    this.weightLossSpeedKgPerWeek,
  });

  OnboardingPendingData copyWith({
    int? age,
    double? height,
    String? gender,
    double? weight,
    double? targetWeight,
    String? trainingDays,
    List<String>? healthConditions,
    String? dietType,
    String? foodRestrictions,
    List<String>? goals,
    double? weightLossSpeedKgPerWeek,
  }) => OnboardingPendingData(
    age: age ?? this.age,
    height: height ?? this.height,
    gender: gender ?? this.gender,
    weight: weight ?? this.weight,
    targetWeight: targetWeight ?? this.targetWeight,
    trainingDays: trainingDays ?? this.trainingDays,
    healthConditions: healthConditions ?? this.healthConditions,
    dietType: dietType ?? this.dietType,
    foodRestrictions: foodRestrictions ?? this.foodRestrictions,
    goals: goals ?? this.goals,
    weightLossSpeedKgPerWeek:
        weightLossSpeedKgPerWeek ?? this.weightLossSpeedKgPerWeek,
  );

  Map<String, dynamic> toJson() => {
    if (age != null) 'age': age,
    if (height != null) 'height': height,
    if (gender != null) 'gender': gender,
    if (weight != null) 'weight': weight,
    if (targetWeight != null) 'target_weight': targetWeight,
    'training_days': trainingDays,
    'health_conditions': healthConditions,
    'diet_type': dietType,
    if (foodRestrictions != null && foodRestrictions!.isNotEmpty)
      'food_restrictions': foodRestrictions,
    'goals': goals,
    if (weightLossSpeedKgPerWeek != null)
      'weight_loss_speed': weightLossSpeedKgPerWeek,
  };

  Map<String, dynamic> toRequestBody() => toJson();

  factory OnboardingPendingData.fromJson(
    Map<String, dynamic> json,
  ) => OnboardingPendingData(
    age: (json['age'] as num?)?.toInt(),
    height: (json['height'] as num?)?.toDouble(),
    gender: json['gender'] as String?,
    weight: (json['weight'] as num?)?.toDouble(),
    targetWeight: (json['target_weight'] as num?)?.toDouble(),
    trainingDays: json['training_days'] as String? ?? '',
    healthConditions:
        (json['health_conditions'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const ['none'],
    dietType: json['diet_type'] as String? ?? 'none',
    foodRestrictions: json['food_restrictions'] as String?,
    goals:
        (json['goals'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
    weightLossSpeedKgPerWeek: (json['weight_loss_speed'] as num?)?.toDouble(),
  );
}

class OnboardingPendingStorage {
  static const _key = 'onboarding_pending';

  static Future<void> save(OnboardingPendingData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  static Future<OnboardingPendingData?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return OnboardingPendingData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
