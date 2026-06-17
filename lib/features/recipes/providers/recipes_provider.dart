import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/locale/locale_provider.dart';
import '../models/recipe_detail.dart';
import '../models/recipe_recommendation.dart';

part 'recipes_provider.g.dart';

/// RAG recommendation for the current user: remaining kcal + goal + taste →
/// 1-3 recipes + Ишка's "fits your day" line.
///
/// Endpoint is `/api/recipes/recommend` — the production nginx only proxies
/// `^/(api|auth)`, so the `/api` prefix is mandatory (a bare `/recipes` would
/// hit the SPA). Context (goals, today's totals, profile) is assembled
/// server-side from the JWT; the client only sends the in-app selected locale
/// (`lang`) so recipe content + Ишка's line come back in the chosen language.
/// Watching [localeProvider] auto-refetches when the user switches language.
@riverpod
Future<RecipeRecommendation> recipeRecommendation(
  RecipeRecommendationRef ref,
) async {
  final lang = ref.watch(localeProvider).languageCode;
  debugPrint('[recipes] GET /api/recipes/recommend?lang=$lang');
  final resp = await apiDio.get(
    '/api/recipes/recommend',
    queryParameters: {'lang': lang},
  );
  final data = resp.data;
  if (data is! Map<String, dynamic>) {
    throw const FormatException('recommend: unexpected payload');
  }
  final rec = RecipeRecommendation.fromJson(data);
  debugPrint(
    '[recipes] recommend → ${rec.recipes.length} recipes, '
    'cold_start=${rec.meta.coldStart}, fallback=${rec.meta.fallback}',
  );
  return rec;
}

/// Full recipe detail (card + ordered slides + ingredients) for the carousel
/// viewer. Returns 404 for non-approved slugs — surfaced as a DioException the
/// screen renders as an empty/error state.
@riverpod
Future<RecipeDetail> recipeDetail(RecipeDetailRef ref, String slug) async {
  final lang = ref.watch(localeProvider).languageCode;
  debugPrint('[recipes] GET /api/recipes/$slug?lang=$lang');
  final resp = await apiDio.get(
    '/api/recipes/$slug',
    queryParameters: {'lang': lang},
  );
  final data = resp.data;
  if (data is! Map<String, dynamic>) {
    throw const FormatException('recipe detail: unexpected payload');
  }
  return RecipeDetail.fromJson(data);
}
