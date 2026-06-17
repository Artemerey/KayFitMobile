import 'package:freezed_annotation/freezed_annotation.dart';

import 'recipe_card.dart';

part 'recipe_detail.freezed.dart';
part 'recipe_detail.g.dart';

/// One carousel slide of a recipe (`recipe_slides` row), ordered by [orderIdx].
///
/// [imageUrl] is stored relative on the backend (e.g.
/// `/static/recipes/{slug}/01.jpg`); resolve it against `AppConfig.baseUrl`
/// before loading. [kind] is one of `hero` | `ingredient` | `step` | `cta`.
@freezed
class RecipeSlide with _$RecipeSlide {
  const factory RecipeSlide({
    @JsonKey(name: 'order_idx') required int orderIdx,
    required String kind,
    @JsonKey(name: 'image_url') required String imageUrl,
    String? caption,
  }) = _RecipeSlide;

  factory RecipeSlide.fromJson(Map<String, dynamic> json) =>
      _$RecipeSlideFromJson(json);
}

/// A structured ingredient row (`recipe_ingredients`). [amountG] and [kcal] are
/// nullable — not every authored recipe fills them in.
@freezed
class RecipeIngredient with _$RecipeIngredient {
  const factory RecipeIngredient({
    required String name,
    @JsonKey(name: 'amount_g') int? amountG,
    int? kcal,
  }) = _RecipeIngredient;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      _$RecipeIngredientFromJson(json);
}

/// Full recipe payload from `GET /api/recipes/{slug}`: the card plus its
/// ordered slides and structured ingredients.
@freezed
class RecipeDetail with _$RecipeDetail {
  const factory RecipeDetail({
    required RecipeCard recipe,
    @Default(<RecipeSlide>[]) List<RecipeSlide> slides,
    @Default(<RecipeIngredient>[]) List<RecipeIngredient> ingredients,
  }) = _RecipeDetail;

  factory RecipeDetail.fromJson(Map<String, dynamic> json) =>
      _$RecipeDetailFromJson(json);
}
