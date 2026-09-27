import 'package:flutter/material.dart';
import '../../core/i18n/generated/app_localizations.dart';

import '../models/recognition_clarification.dart';

class RecognitionClarificationCard extends StatelessWidget {
  const RecognitionClarificationCard({
    super.key,
    required this.clarification,
    required this.confirmed,
    required this.onConfirm,
    required this.onEdit,
  });

  final RecognitionClarification clarification;
  final bool confirmed;
  final VoidCallback onConfirm;
  final ValueChanged<RecognitionUncertainField> onEdit;

  String _reasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
    'portion_mass_out_of_range' => l10n.recognition_uncertainty_portion,
    'calories_per_100g_out_of_range' => l10n.recognition_uncertainty_calories,
    'unexpected_zero_calories' => l10n.recognition_uncertainty_zero_calories,
    'macronutrients_out_of_range' => l10n.recognition_uncertainty_macros,
    'macronutrient_mass_exceeds_food_mass' =>
      l10n.recognition_uncertainty_macro_mass,
    'energy_macros_materially_inconsistent' =>
      l10n.recognition_uncertainty_energy_macros,
    'low_model_confidence' => l10n.recognition_uncertainty_low_confidence,
    'provider_requested_clarification' => l10n.recognition_uncertainty_provider,
    'energy_unit_missing' => l10n.recognition_uncertainty_energy_unit,
    _ => l10n.recognition_uncertainty_fallback,
  };

  @override
  Widget build(BuildContext context) {
    if (confirmed) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey('recognition_clarification_card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            clarification.question,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onTertiaryContainer,
            ),
          ),
          if (clarification.uncertaintyReasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final reason in clarification.uncertaintyReasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _reasonLabel(l10n, reason),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onTertiaryContainer,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onEdit(clarification.primaryField),
            child: Text(clarification.options.first),
          ),
          const SizedBox(height: 4),
          FilledButton.tonal(
            onPressed: onConfirm,
            child: Text(clarification.options[1]),
          ),
        ],
      ),
    );
  }
}
