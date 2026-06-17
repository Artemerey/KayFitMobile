import 'package:flutter/material.dart';

import '../../../shared/theme/kayfit2_theme.dart';
import '../i18n/recipes_strings.dart';
import '../models/recipe_card.dart';
import 'recipe_macro_chips.dart';

/// A tappable recipe row in the recommendation list.
///
/// The `/recommend` payload carries no slide images, so this card is
/// text-forward (title + macros + meta) and opens the slide carousel on tap —
/// no guessing of image filenames.
class RecipeRecommendationCard extends StatelessWidget {
  const RecipeRecommendationCard({
    super.key,
    required this.recipe,
    required this.isRu,
    required this.onTap,
  });

  final RecipeCard recipe;
  final bool isRu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metaBits = <String>[
      if (recipe.cookMinutes != null)
        RecipesStrings.cookMinutes(isRu, recipe.cookMinutes!),
      ...recipe.tags.take(2),
    ];

    return Material(
      color: K2Colors.lightCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: K2Colors.lightBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: K2Fonts.sans,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: K2Colors.lightFg,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RecipeMacroChips(
                      kcal: recipe.kcal,
                      proteinG: recipe.proteinG,
                      fatG: recipe.fatG,
                      carbG: recipe.carbG,
                      dense: true,
                    ),
                    if (metaBits.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        metaBits.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: K2Fonts.sans,
                          fontSize: 12,
                          color: K2Colors.lightFgMute,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: K2Colors.lightFgMute,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
