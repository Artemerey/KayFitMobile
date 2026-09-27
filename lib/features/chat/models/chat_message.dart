class ChatMessage {
  final int? id;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;
  final bool isLoading;
  final MealAdded? mealAdded;
  final String? clientOperationId;
  final String? correlationId;
  final String? runId;

  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isLoading = false,
    this.mealAdded,
    this.clientOperationId,
    this.correlationId,
    this.runId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final ma = json['meal_added'];
    return ChatMessage(
      id: json['id'] as int?,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      mealAdded: ma != null
          ? MealAdded.fromJson(ma as Map<String, dynamic>)
          : null,
      clientOperationId: json['client_operation_id'] as String?,
      correlationId: json['correlation_id'] as String?,
      runId: json['run_id'] as String?,
    );
  }

  String? get deliveryKey => id != null
      ? 'server:$id'
      : clientOperationId != null
      ? 'operation:$clientOperationId:$role'
      : null;
}

class MealAdded {
  final String name;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final int? mealId;
  final String? feedbackTargetId;

  const MealAdded({
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.mealId,
    this.feedbackTargetId,
  });

  factory MealAdded.fromJson(Map<String, dynamic> j) => MealAdded(
    name: j['name'] as String,
    calories: (j['calories'] as num).toDouble(),
    protein: (j['protein'] as num).toDouble(),
    fat: (j['fat'] as num).toDouble(),
    carbs: (j['carbs'] as num).toDouble(),
    mealId: (j['meal_id'] as num?)?.toInt(),
    feedbackTargetId: switch (j['feedback_target_id']) {
      final String id when id.trim().isNotEmpty => id.trim(),
      _ => null,
    },
  );
}
