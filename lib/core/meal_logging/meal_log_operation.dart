import 'package:flutter/foundation.dart';

enum MealLogSource { text, photo, voice, manual, barcode, chat, recipe }

enum MealLogStage {
  inputStarted,
  inputAcquired,
  recognitionStarted,
  recognitionCompleted,
  saveStarted,
  saveResponseReceived,
  savePersisted,
  successRendered,
  failed,
  cancelledByUser,
}

@immutable
class MealLogOperation {
  const MealLogOperation({
    required this.id,
    required this.source,
    required this.stage,
    required this.updatedAt,
    this.added,
    this.mealIds = const <int>[],
    this.errorCode,
  });

  final String id;
  final MealLogSource source;
  final MealLogStage stage;
  final DateTime updatedAt;
  final int? added;
  final List<int> mealIds;
  final String? errorCode;

  bool get isTerminal => switch (stage) {
    MealLogStage.successRendered ||
    MealLogStage.failed ||
    MealLogStage.cancelledByUser => true,
    _ => false,
  };

  MealLogOperation advance(
    MealLogStage next, {
    int? added,
    List<int>? mealIds,
    String? errorCode,
  }) => MealLogOperation(
    id: id,
    source: source,
    stage: next,
    updatedAt: DateTime.now().toUtc(),
    added: added ?? this.added,
    mealIds: mealIds ?? this.mealIds,
    errorCode: errorCode,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source.name,
    'stage': stage.name,
    'updated_at': updatedAt.toIso8601String(),
    if (added != null) 'added': added,
    'meal_ids': mealIds,
    if (errorCode != null) 'error_code': errorCode,
  };

  factory MealLogOperation.fromJson(Map<String, dynamic> json) =>
      MealLogOperation(
        id: json['id'] as String,
        source: MealLogSource.values.byName(json['source'] as String),
        stage: MealLogStage.values.byName(json['stage'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        added: (json['added'] as num?)?.toInt(),
        mealIds: (json['meal_ids'] as List? ?? const [])
            .whereType<num>()
            .map((value) => value.toInt())
            .toList(growable: false),
        errorCode: json['error_code'] as String?,
      );
}
