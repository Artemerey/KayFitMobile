// Unit tests for K2MealRowData (KF2-FOUND-4 data model).

import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/shared/models/k2_meal_row_data.dart';

const _photo = K2MealRowData(
  id: 'p1',
  time: '08:24',
  type: 'breakfast',
  name: 'oatmeal',
  kcal: 320,
  protein: 12,
  fat: 6,
  carbs: 54,
  source: K2MealSource.photo,
  photoSeed: 1,
);

const _voice = K2MealRowData(
  id: 'v1',
  time: '13:10',
  type: 'lunch',
  name: 'chicken bowl',
  kcal: 540,
  protein: 42,
  fat: 14,
  carbs: 58,
  source: K2MealSource.voice,
);

void main() {
  group('K2MealSource.label', () {
    test('returns canonical uppercase labels', () {
      expect(K2MealSource.photo.label, 'PHOTO');
      expect(K2MealSource.voice.label, 'VOICE');
      expect(K2MealSource.text.label, 'TEXT');
      expect(K2MealSource.barcode.label, 'SCAN');
    });
  });

  group('K2MealRowData.hasPhoto', () {
    test('true when source=photo and photoSeed is set', () {
      expect(_photo.hasPhoto, isTrue);
    });

    test('false when source=voice', () {
      expect(_voice.hasPhoto, isFalse);
    });

    test('false when source=photo but photoSeed is null', () {
      const m = K2MealRowData(
        id: 'p2',
        time: '09:00',
        type: 'snack',
        name: 'apple',
        kcal: 95,
        protein: 0,
        fat: 0,
        carbs: 25,
        source: K2MealSource.photo,
      );
      expect(m.hasPhoto, isFalse);
    });
  });

  group('K2MealRowData.copyWith', () {
    test('returns identical data when no overrides', () {
      expect(_photo.copyWith(), _photo);
    });

    test('overrides kcal field only', () {
      final updated = _photo.copyWith(kcal: 999);
      expect(updated.kcal, 999);
      expect(updated.id, _photo.id);
      expect(updated.name, _photo.name);
    });

    test('overrides multiple fields', () {
      final updated = _photo.copyWith(
        name: 'changed',
        protein: 50,
        source: K2MealSource.text,
      );
      expect(updated.name, 'changed');
      expect(updated.protein, 50);
      expect(updated.source, K2MealSource.text);
      expect(updated.id, _photo.id);
    });
  });

  group('K2MealRowData equality', () {
    test('two identical instances are equal', () {
      const a = K2MealRowData(
        id: 'x',
        time: '10:00',
        type: 'snack',
        name: 'banana',
        kcal: 100,
        protein: 1,
        fat: 0,
        carbs: 27,
        source: K2MealSource.text,
      );
      const b = K2MealRowData(
        id: 'x',
        time: '10:00',
        type: 'snack',
        name: 'banana',
        kcal: 100,
        protein: 1,
        fat: 0,
        carbs: 27,
        source: K2MealSource.text,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('differs by id', () {
      final a = _voice;
      final b = _voice.copyWith(id: 'different');
      expect(a == b, isFalse);
    });

    test('differs by photoSeed', () {
      final a = _photo;
      final b = _photo.copyWith(photoSeed: 99);
      expect(a == b, isFalse);
    });
  });
}
