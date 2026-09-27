import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/feedback/meal_save_result.dart';

void main() {
  test('parses additive add_selected response', () {
    final result = MealSaveResult.fromJson({
      'added': 2,
      'meal_ids': [10, 11],
      'feedback_target_id': 'target-uuid',
    });

    expect(result.added, 2);
    expect(result.mealIds, [10, 11]);
    expect(result.feedbackTargetId, 'target-uuid');
    expect(result.canRequestFeedback, isTrue);
  });

  test('keeps legacy response compatible and does not invent target', () {
    final result = MealSaveResult.fromJson({'added': 1});

    expect(result.added, 1);
    expect(result.mealIds, isEmpty);
    expect(result.canRequestFeedback, isFalse);
  });

  test('copy batch requires at least one copied id and a target', () {
    final success = MealSaveResult.fromCopyBatchJson({
      'copied_ids': [21, 22],
      'feedback_target_id': 'copy-target',
    });
    final zero = MealSaveResult.fromCopyBatchJson({
      'copied_ids': <int>[],
      'feedback_target_id': 'unexpected-target',
    });

    expect(success.canRequestFeedback, isTrue);
    expect(zero.canRequestFeedback, isFalse);
  });
}
