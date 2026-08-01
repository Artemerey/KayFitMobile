import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/storage/onboarding_pending_storage.dart';

void main() {
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
}
