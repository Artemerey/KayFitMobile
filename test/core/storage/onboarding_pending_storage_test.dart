import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/storage/onboarding_pending_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('weight-loss speed survives pending JSON round-trip and payload', () {
    const pending = OnboardingPendingData(
      age: 30,
      weight: 85,
      height: 180,
      gender: 'male',
      trainingDays: '3-4',
      goals: ['lose_weight'],
      weightLossSpeedKgPerWeek: 0.25,
    );

    final json = pending.toJson();
    final restored = OnboardingPendingData.fromJson(json);

    expect(json['weight_loss_speed'], 0.25);
    expect(restored.weightLossSpeedKgPerWeek, 0.25);
    expect(restored.toRequestBody()['weight_loss_speed'], 0.25);
  });

  test('legacy pending JSON without speed remains readable', () {
    final restored = OnboardingPendingData.fromJson(const {
      'goals': ['lose_weight'],
      'training_days': '1-2',
    });

    expect(restored.weightLossSpeedKgPerWeek, isNull);
    expect(restored.toRequestBody(), isNot(contains('weight_loss_speed')));
  });

  test('save, read and clear preserve the complete pending model', () async {
    const pending = OnboardingPendingData(
      age: 35,
      height: 175,
      gender: 'female',
      weight: 70,
      targetWeight: 65,
      trainingDays: '3-4',
      healthConditions: ['none'],
      dietType: 'vegetarian',
      foodRestrictions: 'nuts',
      goals: ['lose_weight'],
      weightLossSpeedKgPerWeek: 0.5,
    );

    await OnboardingPendingStorage.save(pending);
    final restored = await OnboardingPendingStorage.read();

    expect(restored?.age, 35);
    expect(restored?.foodRestrictions, 'nuts');
    expect(restored?.weightLossSpeedKgPerWeek, 0.5);

    await OnboardingPendingStorage.clear();
    expect(await OnboardingPendingStorage.read(), isNull);
  });

  test('read returns null for corrupted pending JSON', () async {
    SharedPreferences.setMockInitialValues({'onboarding_pending': '{not-json'});

    expect(await OnboardingPendingStorage.read(), isNull);
  });

  test('copyWith updates speed without dropping other answers', () {
    const pending = OnboardingPendingData(
      age: 30,
      goals: ['lose_weight'],
      weightLossSpeedKgPerWeek: 0.25,
    );

    final updated = pending.copyWith(weightLossSpeedKgPerWeek: 0.75);

    expect(updated.age, 30);
    expect(updated.goals, ['lose_weight']);
    expect(updated.weightLossSpeedKgPerWeek, 0.75);
  });
}
