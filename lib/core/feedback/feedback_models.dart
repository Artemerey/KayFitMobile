enum FeedbackTargetType {
  mealSave('meal_save'),
  onboardingPlan('onboarding_plan');

  const FeedbackTargetType(this.apiValue);
  final String apiValue;
}

enum FeedbackRating {
  like('like'),
  dislike('dislike');

  const FeedbackRating(this.apiValue);
  final String apiValue;
}

enum FeedbackReason {
  tooFewCalories('too_few_calories', FeedbackTargetType.onboardingPlan),
  tooManyCalories('too_many_calories', FeedbackTargetType.onboardingPlan),
  wrongGoal('wrong_goal', FeedbackTargetType.onboardingPlan),
  wrongMacrosOnboarding('wrong_macros', FeedbackTargetType.onboardingPlan),
  answersNotConsidered(
    'answers_not_considered',
    FeedbackTargetType.onboardingPlan,
  ),
  otherOnboarding('other', FeedbackTargetType.onboardingPlan),
  wrongFood('wrong_food', FeedbackTargetType.mealSave),
  missingItem('missing_item', FeedbackTargetType.mealSave),
  extraItem('extra_item', FeedbackTargetType.mealSave),
  wrongWeight('wrong_weight', FeedbackTargetType.mealSave),
  wrongCalories('wrong_calories', FeedbackTargetType.mealSave),
  wrongMacrosMeal('wrong_macros', FeedbackTargetType.mealSave),
  recognitionTooSlow('recognition_too_slow', FeedbackTargetType.mealSave),
  otherMeal('other', FeedbackTargetType.mealSave);

  const FeedbackReason(this.apiValue, this.targetType);
  final String apiValue;
  final FeedbackTargetType targetType;

  static FeedbackReason parse(String value, FeedbackTargetType target) =>
      values.firstWhere(
        (reason) => reason.apiValue == value && reason.targetType == target,
      );
}

enum FeedbackSource {
  photo,
  voice,
  text,
  manual,
  barcode,
  chat,
  recipe,
  copy,
  onboarding;

  String get apiValue => name;
}

enum FeedbackSubmissionState { idle, submitting, success, error, dismissed }

class FeedbackRequest {
  const FeedbackRequest({
    required this.rating,
    required this.source,
    this.reasons = const [],
    this.comment,
    this.context = const {},
    this.appVersion,
    this.platform,
    this.locale,
  });

  final FeedbackRating rating;
  final FeedbackSource source;
  final List<FeedbackReason> reasons;
  final String? comment;
  final Map<String, Object> context;
  final String? appVersion;
  final String? platform;
  final String? locale;

  Map<String, Object?> toJson() => {
    'rating': rating.apiValue,
    'reason_codes': reasons.map((reason) => reason.apiValue).toList(),
    'comment': _normalizedComment,
    'source': source.apiValue,
    'context': context,
    'app_version': ?appVersion,
    'platform': ?platform,
    'locale': ?locale,
  };

  String? get _normalizedComment {
    final value = comment?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  factory FeedbackRequest.fromJson(
    Map<String, dynamic> json,
    FeedbackTargetType target,
  ) => FeedbackRequest(
    rating: FeedbackRating.values.firstWhere(
      (value) => value.apiValue == json['rating'],
    ),
    source: FeedbackSource.values.firstWhere(
      (value) => value.apiValue == json['source'],
    ),
    reasons: (json['reason_codes'] as List<dynamic>? ?? const [])
        .map((value) => FeedbackReason.parse(value as String, target))
        .toList(growable: false),
    comment: json['comment'] as String?,
    context: Map<String, Object>.from(
      json['context'] as Map<String, dynamic>? ?? const {},
    ),
    appVersion: json['app_version'] as String?,
    platform: json['platform'] as String?,
    locale: json['locale'] as String?,
  );
}

class FeedbackTargetRef {
  const FeedbackTargetRef({
    required this.type,
    this.serverId,
    this.pendingSubmissionId,
    this.feedbackCapability,
  });

  final FeedbackTargetType type;
  final String? serverId;
  final String? pendingSubmissionId;
  // In-memory only. FeedbackQueueStorage persists it in Keychain/EncryptedPrefs.
  final String? feedbackCapability;
  bool get canSubmitAnonymously =>
      type == FeedbackTargetType.onboardingPlan &&
      serverId != null &&
      feedbackCapability != null;
  bool get isResolved => serverId != null;

  FeedbackTargetRef resolve(String id) => FeedbackTargetRef(
    type: type,
    serverId: id,
    pendingSubmissionId: pendingSubmissionId,
    feedbackCapability: feedbackCapability,
  );

  Map<String, Object> toJson() => {
    'type': type.apiValue,
    'server_id': ?serverId,
    'pending_submission_id': ?pendingSubmissionId,
  };

  factory FeedbackTargetRef.fromJson(Map<String, dynamic> json) =>
      FeedbackTargetRef(
        type: FeedbackTargetType.values.firstWhere(
          (value) => value.apiValue == json['type'],
        ),
        serverId: json['server_id'] as String?,
        pendingSubmissionId: json['pending_submission_id'] as String?,
      );
}

class PendingFeedback {
  const PendingFeedback({
    required this.eventId,
    required this.targetRef,
    required this.request,
    required this.createdAt,
    required this.nextAttemptAt,
    this.ownerBinding,
    this.attemptCount = 0,
    this.lastErrorCode,
  });

  final String eventId;
  final FeedbackTargetRef targetRef;
  final FeedbackRequest request;
  final DateTime createdAt;
  final DateTime nextAttemptAt;
  final String? ownerBinding;
  final int attemptCount;
  final String? lastErrorCode;

  PendingFeedback copyWith({
    FeedbackTargetRef? targetRef,
    String? ownerBinding,
    int? attemptCount,
    DateTime? nextAttemptAt,
    String? lastErrorCode,
  }) => PendingFeedback(
    eventId: eventId,
    targetRef: targetRef ?? this.targetRef,
    request: request,
    createdAt: createdAt,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    ownerBinding: ownerBinding ?? this.ownerBinding,
    attemptCount: attemptCount ?? this.attemptCount,
    lastErrorCode: lastErrorCode,
  );

  Map<String, Object?> toJson() => {
    'event_id': eventId,
    'target_ref': targetRef.toJson(),
    'request': request.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'attempt_count': attemptCount,
    'next_attempt_at': nextAttemptAt.toUtc().toIso8601String(),
    'last_error_code': lastErrorCode,
    'owner_binding': ownerBinding,
  };

  factory PendingFeedback.fromJson(Map<String, dynamic> json) {
    final target = FeedbackTargetRef.fromJson(
      json['target_ref'] as Map<String, dynamic>,
    );
    return PendingFeedback(
      eventId: json['event_id'] as String,
      targetRef: target,
      request: FeedbackRequest.fromJson(
        json['request'] as Map<String, dynamic>,
        target.type,
      ),
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      attemptCount: json['attempt_count'] as int? ?? 0,
      nextAttemptAt: DateTime.parse(json['next_attempt_at'] as String).toUtc(),
      lastErrorCode: json['last_error_code'] as String?,
      ownerBinding: json['owner_binding'] as String?,
    );
  }
}
