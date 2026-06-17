// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RecipeSlideImpl _$$RecipeSlideImplFromJson(Map<String, dynamic> json) =>
    _$RecipeSlideImpl(
      orderIdx: (json['order_idx'] as num).toInt(),
      kind: json['kind'] as String,
      imageUrl: json['image_url'] as String,
      caption: json['caption'] as String?,
    );

Map<String, dynamic> _$$RecipeSlideImplToJson(_$RecipeSlideImpl instance) =>
    <String, dynamic>{
      'order_idx': instance.orderIdx,
      'kind': instance.kind,
      'image_url': instance.imageUrl,
      'caption': instance.caption,
    };

_$RecipeIngredientImpl _$$RecipeIngredientImplFromJson(
  Map<String, dynamic> json,
) => _$RecipeIngredientImpl(
  name: json['name'] as String,
  amountG: (json['amount_g'] as num?)?.toInt(),
  kcal: (json['kcal'] as num?)?.toInt(),
);

Map<String, dynamic> _$$RecipeIngredientImplToJson(
  _$RecipeIngredientImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'amount_g': instance.amountG,
  'kcal': instance.kcal,
};

_$RecipeDetailImpl _$$RecipeDetailImplFromJson(Map<String, dynamic> json) =>
    _$RecipeDetailImpl(
      recipe: RecipeCard.fromJson(json['recipe'] as Map<String, dynamic>),
      slides:
          (json['slides'] as List<dynamic>?)
              ?.map((e) => RecipeSlide.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <RecipeSlide>[],
      ingredients:
          (json['ingredients'] as List<dynamic>?)
              ?.map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <RecipeIngredient>[],
    );

Map<String, dynamic> _$$RecipeDetailImplToJson(_$RecipeDetailImpl instance) =>
    <String, dynamic>{
      'recipe': instance.recipe,
      'slides': instance.slides,
      'ingredients': instance.ingredients,
    };
