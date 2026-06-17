import 'package:flutter/material.dart';

import '../../../shared/theme/kayfit2_theme.dart';

/// Compact per-serving macro row: kcal · P · F · C, each tinted with the same
/// Apple-ring colour the journal uses, so the recipe screen reads as part of
/// the KF2 design system rather than a bolt-on.
class RecipeMacroChips extends StatelessWidget {
  const RecipeMacroChips({
    super.key,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    this.dense = false,
  });

  final int kcal;
  final int proteinG;
  final int fatG;
  final int carbG;

  /// Tighter spacing + smaller type for use inside list cards.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final gap = dense ? 8.0 : 12.0;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final g = isRu ? 'г' : 'g';
    return Wrap(
      spacing: gap,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Chip(
          value: '$kcal',
          label: isRu ? 'ккал' : 'kcal',
          color: K2RingColors.kcal.from,
          dense: dense,
        ),
        _Chip(
          value: '$proteinG$g',
          label: isRu ? 'Б' : 'P',
          color: K2RingColors.protein.to,
          dense: dense,
        ),
        _Chip(
          value: '$fatG$g',
          label: isRu ? 'Ж' : 'F',
          color: K2RingColors.fat.from,
          dense: dense,
        ),
        _Chip(
          value: '$carbG$g',
          label: isRu ? 'У' : 'C',
          color: K2RingColors.carbs.from,
          dense: dense,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.value,
    required this.label,
    required this.color,
    required this.dense,
  });

  final String value;
  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: dense ? 7 : 8,
          height: dense ? 7 : 8,
          margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: K2Fonts.mono,
            fontSize: dense ? 13 : 15,
            fontWeight: FontWeight.w600,
            color: K2Colors.lightFg,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: K2Fonts.sans,
            fontSize: dense ? 11 : 12,
            fontWeight: FontWeight.w500,
            color: K2Colors.lightFgDim,
          ),
        ),
      ],
    );
  }
}
