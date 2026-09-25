import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/api/meal_copy_result.dart';

void main() {
  group('MealCopyResult', () {
    test('uses server dates for yesterday, tomorrow, and a selected date', () {
      final result = MealCopyResult.fromJson({
        'copies': [
          {'id': 41, 'date': '2026-09-24'},
          {'id': 42, 'date': '2026-09-26'},
          {'id': 43, 'date': '2026-10-12'},
        ],
        'copied_ids': [41, 42, 43],
        'failed': 0,
      });

      expect(result.mealIds, [41, 42, 43]);
      expect(result.savedDates, [
        DateTime(2026, 9, 24),
        DateTime(2026, 9, 26),
        DateTime(2026, 10, 12),
      ]);
      expect(result.firstSavedDateIso, '2026-09-24');
    });

    test('calendar-only server date is stable at timezone boundaries', () {
      final result = MealCopyResult.fromJson({
        'copies': [
          {'id': 51, 'date': '2026-09-26'},
        ],
      });

      final saved = result.savedDates.single;
      expect(saved.isUtc, isFalse);
      expect(saved, DateTime(2026, 9, 26));
      expect(result.firstSavedDateIso, '2026-09-26');
    });

    test('rejects copy response without server-confirmed dates', () {
      expect(
        () => MealCopyResult.fromJson({
          'copied_ids': [61],
          'failed': 0,
        }),
        throwsFormatException,
      );
    });
  });
}
