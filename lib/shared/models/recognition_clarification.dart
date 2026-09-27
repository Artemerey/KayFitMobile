enum RecognitionUncertainField { weight, calories, macros }

class RecognitionClarification {
  const RecognitionClarification({
    required this.required,
    required this.question,
    required this.options,
    required this.uncertaintyReasons,
  });

  final bool required;
  final String question;
  final List<String> options;
  final List<String> uncertaintyReasons;

  RecognitionUncertainField get primaryField {
    if (uncertaintyReasons.any((reason) => reason.contains('portion_mass'))) {
      return RecognitionUncertainField.weight;
    }
    if (uncertaintyReasons.any(
      (reason) => reason.contains('calorie') || reason.contains('energy_'),
    )) {
      return RecognitionUncertainField.calories;
    }
    return RecognitionUncertainField.macros;
  }

  static RecognitionClarification? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final required = raw['required'] == true;
    final question = raw['question']?.toString().trim() ?? '';
    final options =
        (raw['options'] as List?)
            ?.map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        const <String>[];
    final reasons =
        (raw['uncertainty_reasons'] as List?)
            ?.map((value) => value.toString())
            .toList() ??
        const <String>[];
    if (!required || question.isEmpty || options.length < 2) return null;
    return RecognitionClarification(
      required: true,
      question: question,
      options: options,
      uncertaintyReasons: reasons,
    );
  }
}
