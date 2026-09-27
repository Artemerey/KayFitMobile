import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../feedback/secure_uuid.dart';

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
  final List<String> restrictionTagIds;
  final List<String> goals;
  final double? weightLossSpeedKgPerWeek;
  final String? submissionId;
  final String? feedbackTargetId;

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
    this.restrictionTagIds = const [],
    this.goals = const [],
    this.weightLossSpeedKgPerWeek,
    this.submissionId,
    this.feedbackTargetId,
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
    List<String>? restrictionTagIds,
    List<String>? goals,
    double? weightLossSpeedKgPerWeek,
    String? submissionId,
    String? feedbackTargetId,
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
    restrictionTagIds: restrictionTagIds ?? this.restrictionTagIds,
    goals: goals ?? this.goals,
    weightLossSpeedKgPerWeek:
        weightLossSpeedKgPerWeek ?? this.weightLossSpeedKgPerWeek,
    submissionId: submissionId ?? this.submissionId,
    feedbackTargetId: feedbackTargetId ?? this.feedbackTargetId,
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
    'restriction_tag_ids': restrictionTagIds,
    'goals': goals,
    if (weightLossSpeedKgPerWeek != null)
      'weight_loss_speed': weightLossSpeedKgPerWeek,
    if (submissionId != null) 'submission_id': submissionId,
    if (feedbackTargetId != null) 'feedback_target_id': feedbackTargetId,
  };

  Map<String, dynamic> toRequestBody() {
    final body = toJson();
    body.remove('feedback_target_id');
    body.remove('restriction_tag_ids');
    return body;
  }

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
    restrictionTagIds:
        (json['restriction_tag_ids'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [],
    goals:
        (json['goals'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
    weightLossSpeedKgPerWeek: (json['weight_loss_speed'] as num?)?.toDouble(),
    submissionId: json['submission_id'] as String?,
    feedbackTargetId: json['feedback_target_id'] as String?,
  );
}

class OnboardingPendingStorage {
  static const _key = 'onboarding_pending';
  static const _lastServerTargetKey = 'onboarding_last_server_target';

  static Future<void> save(OnboardingPendingData data) async {
    final prefs = await SharedPreferences.getInstance();
    String? existingSubmissionId;
    final existingRaw = prefs.getString(_key);
    if (existingRaw != null) {
      try {
        existingSubmissionId =
            (jsonDecode(existingRaw) as Map<String, dynamic>)['submission_id']
                as String?;
      } catch (_) {
        // Replace corrupt data with a fresh stable submission identifier.
      }
    }
    final stable = data.submissionId == null
        ? data.copyWith(submissionId: existingSubmissionId ?? SecureUuid.v4())
        : data;
    await prefs.setString(_key, jsonEncode(stable.toJson()));
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

  static Future<void> saveLastServerTarget(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastServerTargetKey, id);
  }

  static Future<void> saveFeedbackTarget(String id) async {
    final pending = await read();
    if (pending != null) await save(pending.copyWith(feedbackTargetId: id));
  }

  static Future<String?> readLastServerTarget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastServerTargetKey);
  }
}
