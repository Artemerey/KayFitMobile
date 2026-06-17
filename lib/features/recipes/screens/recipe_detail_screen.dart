import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/api/api_client.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../features/journal/screens/journal_screen.dart'
    show journalDayMealsProvider;
import '../../../shared/theme/kayfit2_theme.dart';
import '../i18n/recipes_strings.dart';
import '../models/recipe_detail.dart';
import '../providers/recipes_provider.dart';
import '../widgets/recipe_macro_chips.dart';

/// Recipe carousel viewer + "Add to diary" CTA (phase 5).
///
/// Logging reuses the proven `/api/meals/add_selected` path (the dedicated
/// `/api/recipes/{id}/log` endpoint and freemium gating are phase 6). The
/// recipe is added as a single meal entry with its per-serving macros, then the
/// journal/dashboard providers are invalidated so the new entry shows instantly.
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

/// Today's date as `yyyy-MM-dd`, matching the key `journal_v2_screen` uses for
/// `journalDayMealsProvider`. A logged recipe always lands on today, so only
/// today's cached instance needs invalidating (not the whole family).
String _todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  bool _saving = false;

  Future<void> _addToDiary(RecipeDetail detail) async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final r = detail.recipe;

    try {
      await apiDio.post(
        '/api/meals/add_selected',
        data: {
          'items': [
            {
              'name': r.title,
              'calories': r.kcal,
              'protein': r.proteinG,
              'fat': r.fatG,
              'carbs': r.carbG,
              'source': 'recipe',
              'source_url': r.slug,
            },
          ],
          if (r.mealType != null) 'meal_type': r.mealType,
        },
      );

      AnalyticsService.mealSaved(
        itemCount: 1,
        mode: 'recipe',
        totalCalories: r.kcal,
      );

      // Refresh every surface that shows today's intake.
      ref.invalidate(todayStatsProvider);
      ref.invalidate(todayMealsProvider);
      ref.invalidate(dailyKcalHistoryProvider);
      ref.invalidate(journalDayMealsProvider(_todayIso()));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(RecipesStrings.addedToDiary(isRu)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: K2Colors.accent,
        ),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(RecipesStrings.errorTitle(isRu)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: K2Colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const t = K2Theme.light;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final async = ref.watch(recipeDetailProvider(widget.slug));

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(isRu: isRu),
            Container(height: 1, color: t.hairline),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => _DetailError(isRu: isRu),
                data: (detail) => _DetailBody(
                  detail: detail,
                  isRu: isRu,
                  saving: _saving,
                  onAdd: () => _addToDiary(detail),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.isRu,
    required this.saving,
    required this.onAdd,
  });

  final RecipeDetail detail;
  final bool isRu;
  final bool saving;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final r = detail.recipe;
    final ingredients = detail.ingredients;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Text(
                r.title,
                style: const TextStyle(
                  fontFamily: K2Fonts.sans,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: K2Colors.lightFg,
                ),
              ),
              const SizedBox(height: 14),
              RecipeMacroChips(
                kcal: r.kcal,
                proteinG: r.proteinG,
                fatG: r.fatG,
                carbG: r.carbG,
              ),
              const SizedBox(height: 6),
              Text(
                RecipesStrings.macroDisclaimer(isRu),
                style: const TextStyle(
                  fontFamily: K2Fonts.sans,
                  fontSize: 11,
                  color: K2Colors.lightFgMute,
                ),
              ),
              if (ingredients.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  RecipesStrings.ingredientsHeader(isRu),
                  style: const TextStyle(
                    fontFamily: K2Fonts.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: K2Colors.lightFgDim,
                  ),
                ),
                const SizedBox(height: 10),
                for (final ing in ingredients) _IngredientRow(ingredient: ing),
              ],
            ],
          ),
        ),
        _AddBar(isRu: isRu, saving: saving, onAdd: onAdd),
      ],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient});

  final RecipeIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final amount = ingredient.amountG != null
        ? '${ingredient.amountG}${isRu ? 'г' : 'g'}'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ingredient.name,
              style: const TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 15,
                color: K2Colors.lightFg,
              ),
            ),
          ),
          if (amount.isNotEmpty)
            Text(
              amount,
              style: const TextStyle(
                fontFamily: K2Fonts.mono,
                fontSize: 14,
                color: K2Colors.lightFgDim,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.isRu,
    required this.saving,
    required this.onAdd,
  });

  final bool isRu;
  final bool saving;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: K2Colors.lightSurface,
        border: Border(top: BorderSide(color: K2Colors.lightHairline)),
      ),
      child: SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: saving ? null : onAdd,
          style: FilledButton.styleFrom(
            backgroundColor: K2Colors.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  RecipesStrings.addToDiary(isRu),
                  style: const TextStyle(
                    fontFamily: K2Fonts.sans,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isRu});

  final bool isRu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: K2Colors.lightFg,
              size: 20,
            ),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/recipes'),
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              RecipesStrings.title(isRu),
              style: const TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: K2Colors.lightFg,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.isRu});

  final bool isRu;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: K2Colors.lightFgMute,
            size: 44,
          ),
          const SizedBox(height: 16),
          Text(
            RecipesStrings.errorTitle(isRu),
            style: const TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: K2Colors.lightFg,
            ),
          ),
        ],
      ),
    );
  }
}
