import '../../shared/models/calculation_result.dart';

const _primaryGoals = {'lose_weight', 'maintain_weight', 'gain_muscle'};

class OnboardingCalculationInput {
  const OnboardingCalculationInput({
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.trainingFrequency,
    required this.goals,
    this.targetWeight,
    this.weightLossSpeedKgPerWeek = 0.5,
  });

  final int age;
  final double weight;
  final double height;
  final String gender;
  final String trainingFrequency;
  final Set<String> goals;
  final double? targetWeight;
  final double weightLossSpeedKgPerWeek;
}

String resolveOnboardingCalculationMode(Set<String> goals) {
  if (goals.isEmpty) return 'active';
  final selected = goals.intersection(_primaryGoals);
  if (selected.length > 1) {
    throw ArgumentError.value(
      goals,
      'goals',
      'Conflicting primary weight goals',
    );
  }
  if (selected.contains('lose_weight')) return 'lose';
  if (selected.contains('gain_muscle')) return 'gain';
  return 'maintain';
}

double _activityCoefficient(String frequency) => switch (frequency) {
  'daily' || '6-7' => 1.725,
  '3-4' || '3-5' => 1.55,
  '1-2' => 1.375,
  _ => 1.2,
};

CalculationResult calculateOnboardingPreview(OnboardingCalculationInput input) {
  final genderOffset = input.gender == 'male' ? 5.0 : -161.0;
  final bmr =
      10 * input.weight + 6.25 * input.height - 5 * input.age + genderOffset;
  final tdee = bmr * _activityCoefficient(input.trainingFrequency);
  final mode = resolveOnboardingCalculationMode(input.goals);

  final double targetCalories;
  if (mode == 'gain') {
    targetCalories = tdee + (tdee * 0.10).clamp(150.0, 300.0);
  } else if (mode == 'maintain') {
    targetCalories = tdee;
  } else {
    final requestedDeficit = mode == 'active'
        ? 600.0
        : (input.weightLossSpeedKgPerWeek * 7700 / 7).clamp(100.0, 1100.0);
    final safeDeficit = requestedDeficit
        .clamp(0.0, tdee * 0.25)
        .clamp(0.0, (tdee - bmr).clamp(0.0, double.infinity));
    targetCalories = (tdee - safeDeficit).clamp(
      bmr > 1200 ? bmr : 1200.0,
      double.infinity,
    );
  }

  final protein = input.weight * 1.6;
  final fat = input.weight * 0.9;
  final carbs = ((targetCalories - protein * 4 - fat * 9) / 4).clamp(
    0.0,
    double.infinity,
  );
  int? daysToGoal;
  if (mode == 'lose' &&
      input.targetWeight != null &&
      input.targetWeight! < input.weight) {
    final deficit = tdee - targetCalories;
    if (deficit > 0) {
      daysToGoal = ((input.weight - input.targetWeight!) * 7700 / deficit)
          .round();
    }
  }

  return CalculationResult(
    bmr: bmr,
    tdee: tdee,
    targetCalories: targetCalories,
    protein: protein,
    fat: fat,
    carbs: carbs,
    daysToGoal: daysToGoal,
    targetWeight: mode == 'lose' ? input.targetWeight : null,
  );
}
