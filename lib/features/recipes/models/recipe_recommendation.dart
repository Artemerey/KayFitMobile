import 'package:freezed_annotation/freezed_annotation.dart';

import 'recipe_card.dart';

part 'recipe_recommendation.freezed.dart';
part 'recipe_recommendation.g.dart';

/// Debug/context metadata attached to a `/recommend` response. `kcal_window`
/// returns an `int` tuple, so [kcalLo]/[kcalHi] are ints. [fallback] is `"feed"`
/// when no candidate passed the hard filters (Ишка returned light feed items),
/// otherwise `null`.
@freezed
class RecipeRecommendationMeta with _$RecipeRecommendationMeta {
  const factory RecipeRecommendationMeta({
    @JsonKey(name: 'remaining_kcal') required int remainingKcal,
    required String goal,
    @JsonKey(name: 'kcal_lo') required int kcalLo,
    @JsonKey(name: 'kcal_hi') required int kcalHi,
    @JsonKey(name: 'cold_start') required bool coldStart,
    required int candidates,
    String? fallback,
  }) = _RecipeRecommendationMeta;

  factory RecipeRecommendationMeta.fromJson(Map<String, dynamic> json) =>
      _$RecipeRecommendationMetaFromJson(json);
}

/// Response of `GET /api/recipes/recommend`: 1-3 recipes chosen by Ишка (or up
/// to 5 feed fallbacks), the personalised "fits your day" line ([ishkaText]),
/// and [meta].
@freezed
class RecipeRecommendation with _$RecipeRecommendation {
  const factory RecipeRecommendation({
    @Default(<RecipeCard>[]) List<RecipeCard> recipes,
    @JsonKey(name: 'ishka_text') @Default('') String ishkaText,
    required RecipeRecommendationMeta meta,
  }) = _RecipeRecommendation;

  factory RecipeRecommendation.fromJson(Map<String, dynamic> json) =>
      _$RecipeRecommendationFromJson(json);
}
