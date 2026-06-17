// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_recommendation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecipeRecommendationMetaImpl _$$RecipeRecommendationMetaImplFromJson(
  Map<String, dynamic> json,
) => _$RecipeRecommendationMetaImpl(
  remainingKcal: (json['remaining_kcal'] as num).toInt(),
  goal: json['goal'] as String,
  kcalLo: (json['kcal_lo'] as num).toInt(),
  kcalHi: (json['kcal_hi'] as num).toInt(),
  coldStart: json['cold_start'] as bool,
  candidates: (json['candidates'] as num).toInt(),
  fallback: json['fallback'] as String?,
);

Map<String, dynamic> _$$RecipeRecommendationMetaImplToJson(
  _$RecipeRecommendationMetaImpl instance,
) => <String, dynamic>{
  'remaining_kcal': instance.remainingKcal,
  'goal': instance.goal,
  'kcal_lo': instance.kcalLo,
  'kcal_hi': instance.kcalHi,
  'cold_start': instance.coldStart,
  'candidates': instance.candidates,
  'fallback': instance.fallback,
};

_$RecipeRecommendationImpl _$$RecipeRecommendationImplFromJson(
  Map<String, dynamic> json,
) => _$RecipeRecommendationImpl(
  recipes:
      (json['recipes'] as List<dynamic>?)
          ?.map((e) => RecipeCard.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <RecipeCard>[],
  ishkaText: json['ishka_text'] as String? ?? '',
  meta: RecipeRecommendationMeta.fromJson(json['meta'] as Map<String, dynamic>),
);

Map<String, dynamic> _$$RecipeRecommendationImplToJson(
  _$RecipeRecommendationImpl instance,
) => <String, dynamic>{
  'recipes': instance.recipes,
  'ishka_text': instance.ishkaText,
  'meta': instance.meta,
};
