// Unit tests for `PendingMealNotifier` — the in-memory state that survives
// chat navigation and powers the pending meal card on the chat screen.
//
// Covers:
//   - initial state is empty / inactive
//   - setMeal seeds items + mealType, clears isAdding
//   - replaceItem swaps at an index; other items + mealType preserved
//   - replaceItem is a no-op for out-of-range / null cases
//   - clear nulls items but leaves mealType (so re-entering the flow keeps
//     the previously selected meal type as a reasonable default)
//   - setMealType updates only the meal type
//   - setAdding toggles only the in-flight flag

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/chat/providers/pending_meal_provider.dart';
import 'package:kayfit/shared/models/ingredient_v2.dart';
import 'package:kayfit/shared/models/nutrients_v2.dart';

const _n = NutrientsV2(calories: 100, protein: 5, fat: 3, carbs: 12);

IngredientV2 _ing(String name, double w) => IngredientV2(
      name: name,
      weightGrams: w,
      nutrientsPer100g: _n,
      nutrientsTotal: _n,
    );

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('PendingMealNotifier', () {
    test('initial state has no items and is inactive', () {
      final c = _container();
      final s = c.read(pendingMealProvider);
      expect(s.items, isNull);
      expect(s.isActive, isFalse);
      expect(s.mealType, 'snack');
      expect(s.isAdding, isFalse);
    });

    test('setMeal seeds items and meal type, resets isAdding', () {
      final c = _container();
      // Pretend a previous AI call left isAdding=true mid-flight, then
      // setMeal was called from a new turn — the flag must reset.
      c.read(pendingMealProvider.notifier).setAdding(true);
      c.read(pendingMealProvider.notifier).setMeal(
        [_ing('a', 100), _ing('b', 200)],
        'breakfast',
      );
      final s = c.read(pendingMealProvider);
      expect(s.items?.length, 2);
      expect(s.items?[1].name, 'b');
      expect(s.mealType, 'breakfast');
      expect(s.isAdding, isFalse);
      expect(s.isActive, isTrue);
    });

    test('replaceItem swaps target index without touching the rest', () {
      final c = _container();
      c.read(pendingMealProvider.notifier).setMeal(
        [_ing('a', 100), _ing('b', 200), _ing('c', 300)],
        'lunch',
      );
      c.read(pendingMealProvider.notifier).replaceItem(1, _ing('B-NEW', 250));
      final items = c.read(pendingMealProvider).items!;
      expect(items[0].name, 'a');
      expect(items[1].name, 'B-NEW');
      expect(items[1].weightGrams, 250);
      expect(items[2].name, 'c');
      // mealType is preserved across replaceItem
      expect(c.read(pendingMealProvider).mealType, 'lunch');
    });

    test('replaceItem is a no-op when items is null', () {
      final c = _container();
      c.read(pendingMealProvider.notifier).replaceItem(0, _ing('x', 50));
      expect(c.read(pendingMealProvider).items, isNull);
    });

    test('replaceItem is a no-op for negative / out-of-range index', () {
      final c = _container();
      c.read(pendingMealProvider.notifier).setMeal([_ing('a', 100)], 'snack');
      c.read(pendingMealProvider.notifier).replaceItem(-1, _ing('x', 50));
      c.read(pendingMealProvider.notifier).replaceItem(5, _ing('x', 50));
      final items = c.read(pendingMealProvider).items!;
      expect(items.length, 1);
      expect(items.first.name, 'a');
    });

    test('clear nulls items + isAdding, leaves mealType', () {
      final c = _container();
      c.read(pendingMealProvider.notifier).setMeal(
        [_ing('a', 100)],
        'dinner',
      );
      c.read(pendingMealProvider.notifier).setAdding(true);
      c.read(pendingMealProvider.notifier).clear();
      final s = c.read(pendingMealProvider);
      expect(s.items, isNull);
      expect(s.isAdding, isFalse);
      expect(s.mealType, 'dinner');
      expect(s.isActive, isFalse);
    });

    test('setMealType updates type without touching items', () {
      final c = _container();
      c.read(pendingMealProvider.notifier).setMeal([_ing('a', 100)], 'snack');
      c.read(pendingMealProvider.notifier).setMealType('breakfast');
      final s = c.read(pendingMealProvider);
      expect(s.mealType, 'breakfast');
      expect(s.items?.length, 1);
    });

    test('setAdding toggles in-flight flag only', () {
      final c = _container();
      c.read(pendingMealProvider.notifier).setMeal([_ing('a', 100)], 'snack');
      c.read(pendingMealProvider.notifier).setAdding(true);
      expect(c.read(pendingMealProvider).isAdding, isTrue);
      expect(c.read(pendingMealProvider).items?.length, 1);
      c.read(pendingMealProvider.notifier).setAdding(false);
      expect(c.read(pendingMealProvider).isAdding, isFalse);
    });
  });

  group('PendingMealState.isActive', () {
    test('false when items is null', () {
      const s = PendingMealState();
      expect(s.isActive, isFalse);
    });

    test('false when items is empty', () {
      const s = PendingMealState(items: []);
      expect(s.isActive, isFalse);
    });

    test('true when items has at least one entry', () {
      final s = PendingMealState(items: [_ing('a', 100)]);
      expect(s.isActive, isTrue);
    });
  });
}
