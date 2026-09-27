import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/onboarding/onboarding_calculation.dart';

void main() {
  group('calculateOnboardingPreview', () {
    OnboardingCalculationInput input(Set<String> goals, {double speed = 0.5}) =>
        OnboardingCalculationInput(
          age: 30,
          weight: 85,
          height: 180,
          gender: 'male',
          trainingFrequency: '3-4',
          goals: goals,
          weightLossSpeedKgPerWeek: speed,
        );

    test('gain muscle uses a surplus even with a leaner body-form goal', () {
      final result = calculateOnboardingPreview(input({'gain_muscle'}));

      expect(result.targetCalories, greaterThan(result.tdee));
      expect(result.targetCalories, isNot(1200));
      expect(result.targetCalories, closeTo(3120.15, 0.01));
    });

    test('maintain and stay toned use maintenance calories', () {
      for (final goals in [
        {'maintain_weight'},
        {'stay_toned'},
      ]) {
        final result = calculateOnboardingPreview(input(goals));
        expect(result.targetCalories, closeTo(result.tdee, 0.1));
      }
    });

    test('weight-loss speed changes the safe deficit', () {
      final targets = [0.25, 0.5, 1.0]
          .map(
            (speed) => calculateOnboardingPreview(
              input({'lose_weight'}, speed: speed),
            ).targetCalories,
          )
          .toList();

      expect(targets[0], greaterThan(targets[1]));
      expect(targets[1], greaterThan(targets[2]));
    });

    test('legacy empty goals preserve active-loss compatibility', () {
      final result = calculateOnboardingPreview(input({}));
      expect(result.targetCalories, lessThan(result.tdee));
    });

    test('edited source answers recalculate instead of reusing stale plan', () {
      final before = calculateOnboardingPreview(input({'gain_muscle'}));
      final after = calculateOnboardingPreview(
        input({'lose_weight'}, speed: 0.25),
      );

      expect(before.targetCalories, greaterThan(before.tdee));
      expect(after.targetCalories, lessThan(after.tdee));
      expect(after.targetCalories, isNot(before.targetCalories));
    });

    test(
      'conflicting primary goals throw instead of silently choosing loss',
      () {
        expect(
          () =>
              calculateOnboardingPreview(input({'lose_weight', 'gain_muscle'})),
          throwsArgumentError,
        );
      },
    );
  });
}
