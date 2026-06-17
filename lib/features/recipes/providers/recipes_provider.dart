import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../models/recipe_detail.dart';
import '../models/recipe_recommendation.dart';

part 'recipes_provider.g.dart';

/// RAG recommendation for the current user: remaining kcal + goal + taste →
/// 1-3 recipes + Ишка's "fits your day" line.
///
/// Endpoint is `/api/recipes/recommend` — the production nginx only proxies
/// `^/(api|auth)`, so the `/api` prefix is mandatory (a bare `/recipes` would
/// hit the SPA). All context (goals, today's totals, profile) is assembled
/// server-side from the JWT; the client sends no query params here.
@riverpod
Future<RecipeRecommendation> recipeRecommendation(
  RecipeRecommendationRef ref,
) async {
  debugPrint('[recipes] GET /api/recipes/recommend');
  final resp = await apiDio.get('/api/recipes/recommend');
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
  debugPrint('[recipes] GET /api/recipes/$slug');
  final resp = await apiDio.get('/api/recipes/$slug');
  final data = resp.data;
  if (data is! Map<String, dynamic>) {
    throw const FormatException('recipe detail: unexpected payload');
  }
  return RecipeDetail.fromJson(data);
}
