// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_card.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecipeCardImpl _$$RecipeCardImplFromJson(
  Map<String, dynamic> json,
) => _$RecipeCardImpl(
  id: json['id'] as String,
  slug: json['slug'] as String,
  title: json['title'] as String,
  cuisine: json['cuisine'] as String?,
  mealType: json['meal_type'] as String?,
  kcal: (json['kcal'] as num).toInt(),
  proteinG: (json['protein_g'] as num).toInt(),
  fatG: (json['fat_g'] as num).toInt(),
  carbG: (json['carb_g'] as num).toInt(),
  servings: (json['servings'] as num?)?.toInt(),
  cookMinutes: (json['cook_minutes'] as num?)?.toInt(),
  difficulty: json['difficulty'] as String?,
  dietFlags:
      (json['diet_flags'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  allergens:
      (json['allergens'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  goalFit:
      (json['goal_fit'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  isFree: json['is_free'] as bool?,
  source: json['source'] as String?,
  distance: (json['distance'] as num?)?.toDouble(),
);

Map<String, dynamic> _$$RecipeCardImplToJson(_$RecipeCardImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'title': instance.title,
      'cuisine': instance.cuisine,
      'meal_type': instance.mealType,
      'kcal': instance.kcal,
      'protein_g': instance.proteinG,
      'fat_g': instance.fatG,
      'carb_g': instance.carbG,
      'servings': instance.servings,
      'cook_minutes': instance.cookMinutes,
      'difficulty': instance.difficulty,
      'diet_flags': instance.dietFlags,
      'allergens': instance.allergens,
      'goal_fit': instance.goalFit,
      'tags': instance.tags,
      'is_free': instance.isFree,
      'source': instance.source,
      'distance': instance.distance,
    };
