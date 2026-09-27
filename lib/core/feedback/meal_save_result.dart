class MealSaveResult {
  const MealSaveResult({
    required this.added,
    this.operationId,
    this.mealIds = const [],
    this.feedbackTargetId,
  });

  final int added;
  final String? operationId;
  final List<int> mealIds;
  final String? feedbackTargetId;

  bool get canRequestFeedback => added > 0 && feedbackTargetId != null;

  factory MealSaveResult.fromJson(Object? value) {
    final json = value is Map<String, dynamic>
        ? value
        : value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    final rawIds = json['meal_ids'];
    final ids = rawIds is List
        ? rawIds
              .whereType<num>()
              .map((id) => id.toInt())
              .toList(growable: false)
        : const <int>[];
    final rawTarget = json['feedback_target_id'];
    final target = rawTarget is String && rawTarget.trim().isNotEmpty
        ? rawTarget.trim()
        : null;
    return MealSaveResult(
      added: (json['added'] as num?)?.toInt() ?? ids.length,
      operationId: switch (json['operation_id']) {
        final String id when id.trim().isNotEmpty => id.trim(),
        _ => null,
      },
      mealIds: ids,
      feedbackTargetId: target,
    );
  }

  factory MealSaveResult.fromCopyBatchJson(Object? value) {
    final json = value is Map<String, dynamic>
        ? value
        : value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    final copied = json['copied_ids'];
    final ids = copied is List
        ? copied
              .whereType<num>()
              .map((id) => id.toInt())
              .toList(growable: false)
        : const <int>[];
    return MealSaveResult(
      added: ids.length,
      mealIds: ids,
      feedbackTargetId: switch (json['feedback_target_id']) {
        final String id when id.trim().isNotEmpty => id.trim(),
        _ => null,
      },
    );
  }
}
