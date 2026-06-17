import 'package:freezed_annotation/freezed_annotation.dart';

part 'recipe_card.freezed.dart';
part 'recipe_card.g.dart';

/// A recipe card as returned by `/api/recipes/recommend`, `/feed`, and the
/// `recipe` field of `/api/recipes/{slug}`.
///
/// Macros are per-serving INTEGER columns on the backend (`recipes` table), so
/// every numeric field arrives as a JSON int. `distance` is only present in the
/// `recommend` payload (pgvector cosine distance to the user's taste vector).
@freezed
class RecipeCard with _$RecipeCard {
  const factory RecipeCard({
    required String id,
    required String slug,
    required String title,
    String? cuisine,
    @JsonKey(name: 'meal_type') String? mealType,
    required int kcal,
    @JsonKey(name: 'protein_g') required int proteinG,
    @JsonKey(name: 'fat_g') required int fatG,
    @JsonKey(name: 'carb_g') required int carbG,
    int? servings,
    @JsonKey(name: 'cook_minutes') int? cookMinutes,
    String? difficulty,
    @JsonKey(name: 'diet_flags') @Default(<String>[]) List<String> dietFlags,
    @Default(<String>[]) List<String> allergens,
    @JsonKey(name: 'goal_fit') @Default(<String>[]) List<String> goalFit,
    @Default(<String>[]) List<String> tags,
    @JsonKey(name: 'is_free') bool? isFree,
    String? source,
    double? distance,
  }) = _RecipeCard;

  factory RecipeCard.fromJson(Map<String, dynamic> json) =>
      _$RecipeCardFromJson(json);
}
