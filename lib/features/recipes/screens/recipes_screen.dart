import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/kayfit2_theme.dart';
import '../i18n/recipes_strings.dart';
import '../models/recipe_recommendation.dart';
import '../providers/recipes_provider.dart';
import '../widgets/recipe_recommendation_card.dart';

/// Recipes screen (phase 5): Ишка's RAG recommendation for the user's day.
///
/// Standalone KF2 route (like `/journal-v2`, `/settings-v2`) — owns a top bar
/// with an explicit back button and no legacy ShellRoute bottom nav.
class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const t = K2Theme.light;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final async = ref.watch(recipeRecommendationProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(title: RecipesStrings.title(isRu)),
            Container(height: 1, color: t.hairline),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => _Empty(
                  isRu: isRu,
                  isError: true,
                  onRetry: () => ref.invalidate(recipeRecommendationProvider),
                ),
                data: (rec) {
                  if (rec.recipes.isEmpty) {
                    return _Empty(
                      isRu: isRu,
                      isError: false,
                      onRetry: () =>
                          ref.invalidate(recipeRecommendationProvider),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(recipeRecommendationProvider);
                      try {
                        await ref.read(recipeRecommendationProvider.future);
                      } catch (_) {
                        // The `data` branch keeps stale results on a failed
                        // refresh, so surface the failure explicitly.
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(RecipesStrings.errorTitle(isRu)),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: K2Colors.error,
                          ),
                        );
                      }
                    },
                    child: _RecommendationList(rec: rec, isRu: isRu),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationList extends StatelessWidget {
  const _RecommendationList({required this.rec, required this.isRu});

  final RecipeRecommendation rec;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (rec.ishkaText.trim().isNotEmpty) ...[
          _IshkaBanner(text: rec.ishkaText.trim()),
          const SizedBox(height: 20),
        ],
        Text(
          RecipesStrings.ishkaPicksHeader(isRu),
          style: const TextStyle(
            fontFamily: K2Fonts.sans,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: K2Colors.lightFgDim,
          ),
        ),
        const SizedBox(height: 12),
        for (final recipe in rec.recipes) ...[
          RecipeRecommendationCard(
            recipe: recipe,
            isRu: isRu,
            onTap: () => context.push('/recipes/${recipe.slug}'),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Text(
          RecipesStrings.macroDisclaimer(isRu),
          style: const TextStyle(
            fontFamily: K2Fonts.sans,
            fontSize: 11,
            color: K2Colors.lightFgMute,
          ),
        ),
      ],
    );
  }
}

/// Accent-tinted "fits your day" banner carrying Ишка's recommendation line.
class _IshkaBanner extends StatelessWidget {
  const _IshkaBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      decoration: BoxDecoration(
        color: K2Colors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: K2Colors.accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [K2Colors.accentLight, K2Colors.accent],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 14.5,
                height: 1.35,
                color: K2Colors.lightFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

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
                context.canPop() ? context.pop() : context.go('/journal-v2'),
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              title,
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

class _Empty extends StatelessWidget {
  const _Empty({
    required this.isRu,
    required this.isError,
    required this.onRetry,
  });

  final bool isRu;
  final bool isError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.cloud_off_rounded : Icons.restaurant_menu_rounded,
              color: K2Colors.lightFgMute,
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              isError
                  ? RecipesStrings.errorTitle(isRu)
                  : RecipesStrings.emptyTitle(isRu),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: K2Colors.lightFg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isError ? '' : RecipesStrings.emptyBody(isRu),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 14,
                height: 1.4,
                color: K2Colors.lightFgDim,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: Text(RecipesStrings.retry(isRu)),
            ),
          ],
        ),
      ),
    );
  }
}
