// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipe_card.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecipeCard _$RecipeCardFromJson(Map<String, dynamic> json) {
  return _RecipeCard.fromJson(json);
}

/// @nodoc
mixin _$RecipeCard {
  String get id => throw _privateConstructorUsedError;
  String get slug => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get cuisine => throw _privateConstructorUsedError;
  @JsonKey(name: 'meal_type')
  String? get mealType => throw _privateConstructorUsedError;
  int get kcal => throw _privateConstructorUsedError;
  @JsonKey(name: 'protein_g')
  int get proteinG => throw _privateConstructorUsedError;
  @JsonKey(name: 'fat_g')
  int get fatG => throw _privateConstructorUsedError;
  @JsonKey(name: 'carb_g')
  int get carbG => throw _privateConstructorUsedError;
  int? get servings => throw _privateConstructorUsedError;
  @JsonKey(name: 'cook_minutes')
  int? get cookMinutes => throw _privateConstructorUsedError;
  String? get difficulty => throw _privateConstructorUsedError;
  @JsonKey(name: 'diet_flags')
  List<String> get dietFlags => throw _privateConstructorUsedError;
  List<String> get allergens => throw _privateConstructorUsedError;
  @JsonKey(name: 'goal_fit')
  List<String> get goalFit => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_free')
  bool? get isFree => throw _privateConstructorUsedError;
  String? get source => throw _privateConstructorUsedError;
  double? get distance => throw _privateConstructorUsedError;

  /// Serializes this RecipeCard to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipeCard
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeCardCopyWith<RecipeCard> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeCardCopyWith<$Res> {
  factory $RecipeCardCopyWith(
    RecipeCard value,
    $Res Function(RecipeCard) then,
  ) = _$RecipeCardCopyWithImpl<$Res, RecipeCard>;
  @useResult
  $Res call({
    String id,
    String slug,
    String title,
    String? cuisine,
    @JsonKey(name: 'meal_type') String? mealType,
    int kcal,
    @JsonKey(name: 'protein_g') int proteinG,
    @JsonKey(name: 'fat_g') int fatG,
    @JsonKey(name: 'carb_g') int carbG,
    int? servings,
    @JsonKey(name: 'cook_minutes') int? cookMinutes,
    String? difficulty,
    @JsonKey(name: 'diet_flags') List<String> dietFlags,
    List<String> allergens,
    @JsonKey(name: 'goal_fit') List<String> goalFit,
    List<String> tags,
    @JsonKey(name: 'is_free') bool? isFree,
    String? source,
    double? distance,
  });
}

/// @nodoc
class _$RecipeCardCopyWithImpl<$Res, $Val extends RecipeCard>
    implements $RecipeCardCopyWith<$Res> {
  _$RecipeCardCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipeCard
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? title = null,
    Object? cuisine = freezed,
    Object? mealType = freezed,
    Object? kcal = null,
    Object? proteinG = null,
    Object? fatG = null,
    Object? carbG = null,
    Object? servings = freezed,
    Object? cookMinutes = freezed,
    Object? difficulty = freezed,
    Object? dietFlags = null,
    Object? allergens = null,
    Object? goalFit = null,
    Object? tags = null,
    Object? isFree = freezed,
    Object? source = freezed,
    Object? distance = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            slug: null == slug
                ? _value.slug
                : slug // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            cuisine: freezed == cuisine
                ? _value.cuisine
                : cuisine // ignore: cast_nullable_to_non_nullable
                      as String?,
            mealType: freezed == mealType
                ? _value.mealType
                : mealType // ignore: cast_nullable_to_non_nullable
                      as String?,
            kcal: null == kcal
                ? _value.kcal
                : kcal // ignore: cast_nullable_to_non_nullable
                      as int,
            proteinG: null == proteinG
                ? _value.proteinG
                : proteinG // ignore: cast_nullable_to_non_nullable
                      as int,
            fatG: null == fatG
                ? _value.fatG
                : fatG // ignore: cast_nullable_to_non_nullable
                      as int,
            carbG: null == carbG
                ? _value.carbG
                : carbG // ignore: cast_nullable_to_non_nullable
                      as int,
            servings: freezed == servings
                ? _value.servings
                : servings // ignore: cast_nullable_to_non_nullable
                      as int?,
            cookMinutes: freezed == cookMinutes
                ? _value.cookMinutes
                : cookMinutes // ignore: cast_nullable_to_non_nullable
                      as int?,
            difficulty: freezed == difficulty
                ? _value.difficulty
                : difficulty // ignore: cast_nullable_to_non_nullable
                      as String?,
            dietFlags: null == dietFlags
                ? _value.dietFlags
                : dietFlags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            allergens: null == allergens
                ? _value.allergens
                : allergens // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            goalFit: null == goalFit
                ? _value.goalFit
                : goalFit // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isFree: freezed == isFree
                ? _value.isFree
                : isFree // ignore: cast_nullable_to_non_nullable
                      as bool?,
            source: freezed == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as String?,
            distance: freezed == distance
                ? _value.distance
                : distance // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipeCardImplCopyWith<$Res>
    implements $RecipeCardCopyWith<$Res> {
  factory _$$RecipeCardImplCopyWith(
    _$RecipeCardImpl value,
    $Res Function(_$RecipeCardImpl) then,
  ) = __$$RecipeCardImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String slug,
    String title,
    String? cuisine,
    @JsonKey(name: 'meal_type') String? mealType,
    int kcal,
    @JsonKey(name: 'protein_g') int proteinG,
    @JsonKey(name: 'fat_g') int fatG,
    @JsonKey(name: 'carb_g') int carbG,
    int? servings,
    @JsonKey(name: 'cook_minutes') int? cookMinutes,
    String? difficulty,
    @JsonKey(name: 'diet_flags') List<String> dietFlags,
    List<String> allergens,
    @JsonKey(name: 'goal_fit') List<String> goalFit,
    List<String> tags,
    @JsonKey(name: 'is_free') bool? isFree,
    String? source,
    double? distance,
  });
}

/// @nodoc
class __$$RecipeCardImplCopyWithImpl<$Res>
    extends _$RecipeCardCopyWithImpl<$Res, _$RecipeCardImpl>
    implements _$$RecipeCardImplCopyWith<$Res> {
  __$$RecipeCardImplCopyWithImpl(
    _$RecipeCardImpl _value,
    $Res Function(_$RecipeCardImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipeCard
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? slug = null,
    Object? title = null,
    Object? cuisine = freezed,
    Object? mealType = freezed,
    Object? kcal = null,
    Object? proteinG = null,
    Object? fatG = null,
    Object? carbG = null,
    Object? servings = freezed,
    Object? cookMinutes = freezed,
    Object? difficulty = freezed,
    Object? dietFlags = null,
    Object? allergens = null,
    Object? goalFit = null,
    Object? tags = null,
    Object? isFree = freezed,
    Object? source = freezed,
    Object? distance = freezed,
  }) {
    return _then(
      _$RecipeCardImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        slug: null == slug
            ? _value.slug
            : slug // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        cuisine: freezed == cuisine
            ? _value.cuisine
            : cuisine // ignore: cast_nullable_to_non_nullable
                  as String?,
        mealType: freezed == mealType
            ? _value.mealType
            : mealType // ignore: cast_nullable_to_non_nullable
                  as String?,
        kcal: null == kcal
            ? _value.kcal
            : kcal // ignore: cast_nullable_to_non_nullable
                  as int,
        proteinG: null == proteinG
            ? _value.proteinG
            : proteinG // ignore: cast_nullable_to_non_nullable
                  as int,
        fatG: null == fatG
            ? _value.fatG
            : fatG // ignore: cast_nullable_to_non_nullable
                  as int,
        carbG: null == carbG
            ? _value.carbG
            : carbG // ignore: cast_nullable_to_non_nullable
                  as int,
        servings: freezed == servings
            ? _value.servings
            : servings // ignore: cast_nullable_to_non_nullable
                  as int?,
        cookMinutes: freezed == cookMinutes
            ? _value.cookMinutes
            : cookMinutes // ignore: cast_nullable_to_non_nullable
                  as int?,
        difficulty: freezed == difficulty
            ? _value.difficulty
            : difficulty // ignore: cast_nullable_to_non_nullable
                  as String?,
        dietFlags: null == dietFlags
            ? _value._dietFlags
            : dietFlags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        allergens: null == allergens
            ? _value._allergens
            : allergens // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        goalFit: null == goalFit
            ? _value._goalFit
            : goalFit // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isFree: freezed == isFree
            ? _value.isFree
            : isFree // ignore: cast_nullable_to_non_nullable
                  as bool?,
        source: freezed == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String?,
        distance: freezed == distance
            ? _value.distance
            : distance // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeCardImpl implements _RecipeCard {
  const _$RecipeCardImpl({
    required this.id,
    required this.slug,
    required this.title,
    this.cuisine,
    @JsonKey(name: 'meal_type') this.mealType,
    required this.kcal,
    @JsonKey(name: 'protein_g') required this.proteinG,
    @JsonKey(name: 'fat_g') required this.fatG,
    @JsonKey(name: 'carb_g') required this.carbG,
    this.servings,
    @JsonKey(name: 'cook_minutes') this.cookMinutes,
    this.difficulty,
    @JsonKey(name: 'diet_flags')
    final List<String> dietFlags = const <String>[],
    final List<String> allergens = const <String>[],
    @JsonKey(name: 'goal_fit') final List<String> goalFit = const <String>[],
    final List<String> tags = const <String>[],
    @JsonKey(name: 'is_free') this.isFree,
    this.source,
    this.distance,
  }) : _dietFlags = dietFlags,
       _allergens = allergens,
       _goalFit = goalFit,
       _tags = tags;

  factory _$RecipeCardImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeCardImplFromJson(json);

  @override
  final String id;
  @override
  final String slug;
  @override
  final String title;
  @override
  final String? cuisine;
  @override
  @JsonKey(name: 'meal_type')
  final String? mealType;
  @override
  final int kcal;
  @override
  @JsonKey(name: 'protein_g')
  final int proteinG;
  @override
  @JsonKey(name: 'fat_g')
  final int fatG;
  @override
  @JsonKey(name: 'carb_g')
  final int carbG;
  @override
  final int? servings;
  @override
  @JsonKey(name: 'cook_minutes')
  final int? cookMinutes;
  @override
  final String? difficulty;
  final List<String> _dietFlags;
  @override
  @JsonKey(name: 'diet_flags')
  List<String> get dietFlags {
    if (_dietFlags is EqualUnmodifiableListView) return _dietFlags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dietFlags);
  }

  final List<String> _allergens;
  @override
  @JsonKey()
  List<String> get allergens {
    if (_allergens is EqualUnmodifiableListView) return _allergens;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allergens);
  }

  final List<String> _goalFit;
  @override
  @JsonKey(name: 'goal_fit')
  List<String> get goalFit {
    if (_goalFit is EqualUnmodifiableListView) return _goalFit;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_goalFit);
  }

  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey(name: 'is_free')
  final bool? isFree;
  @override
  final String? source;
  @override
  final double? distance;

  @override
  String toString() {
    return 'RecipeCard(id: $id, slug: $slug, title: $title, cuisine: $cuisine, mealType: $mealType, kcal: $kcal, proteinG: $proteinG, fatG: $fatG, carbG: $carbG, servings: $servings, cookMinutes: $cookMinutes, difficulty: $difficulty, dietFlags: $dietFlags, allergens: $allergens, goalFit: $goalFit, tags: $tags, isFree: $isFree, source: $source, distance: $distance)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeCardImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.cuisine, cuisine) || other.cuisine == cuisine) &&
            (identical(other.mealType, mealType) ||
                other.mealType == mealType) &&
            (identical(other.kcal, kcal) || other.kcal == kcal) &&
            (identical(other.proteinG, proteinG) ||
                other.proteinG == proteinG) &&
            (identical(other.fatG, fatG) || other.fatG == fatG) &&
            (identical(other.carbG, carbG) || other.carbG == carbG) &&
            (identical(other.servings, servings) ||
                other.servings == servings) &&
            (identical(other.cookMinutes, cookMinutes) ||
                other.cookMinutes == cookMinutes) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            const DeepCollectionEquality().equals(
              other._dietFlags,
              _dietFlags,
            ) &&
            const DeepCollectionEquality().equals(
              other._allergens,
              _allergens,
            ) &&
            const DeepCollectionEquality().equals(other._goalFit, _goalFit) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.isFree, isFree) || other.isFree == isFree) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.distance, distance) ||
                other.distance == distance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    slug,
    title,
    cuisine,
    mealType,
    kcal,
    proteinG,
    fatG,
    carbG,
    servings,
    cookMinutes,
    difficulty,
    const DeepCollectionEquality().hash(_dietFlags),
    const DeepCollectionEquality().hash(_allergens),
    const DeepCollectionEquality().hash(_goalFit),
    const DeepCollectionEquality().hash(_tags),
    isFree,
    source,
    distance,
  ]);

  /// Create a copy of RecipeCard
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeCardImplCopyWith<_$RecipeCardImpl> get copyWith =>
      __$$RecipeCardImplCopyWithImpl<_$RecipeCardImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeCardImplToJson(this);
  }
}

abstract class _RecipeCard implements RecipeCard {
  const factory _RecipeCard({
    required final String id,
    required final String slug,
    required final String title,
    final String? cuisine,
    @JsonKey(name: 'meal_type') final String? mealType,
    required final int kcal,
    @JsonKey(name: 'protein_g') required final int proteinG,
    @JsonKey(name: 'fat_g') required final int fatG,
    @JsonKey(name: 'carb_g') required final int carbG,
    final int? servings,
    @JsonKey(name: 'cook_minutes') final int? cookMinutes,
    final String? difficulty,
    @JsonKey(name: 'diet_flags') final List<String> dietFlags,
    final List<String> allergens,
    @JsonKey(name: 'goal_fit') final List<String> goalFit,
    final List<String> tags,
    @JsonKey(name: 'is_free') final bool? isFree,
    final String? source,
    final double? distance,
  }) = _$RecipeCardImpl;

  factory _RecipeCard.fromJson(Map<String, dynamic> json) =
      _$RecipeCardImpl.fromJson;

  @override
  String get id;
  @override
  String get slug;
  @override
  String get title;
  @override
  String? get cuisine;
  @override
  @JsonKey(name: 'meal_type')
  String? get mealType;
  @override
  int get kcal;
  @override
  @JsonKey(name: 'protein_g')
  int get proteinG;
  @override
  @JsonKey(name: 'fat_g')
  int get fatG;
  @override
  @JsonKey(name: 'carb_g')
  int get carbG;
  @override
  int? get servings;
  @override
  @JsonKey(name: 'cook_minutes')
  int? get cookMinutes;
  @override
  String? get difficulty;
  @override
  @JsonKey(name: 'diet_flags')
  List<String> get dietFlags;
  @override
  List<String> get allergens;
  @override
  @JsonKey(name: 'goal_fit')
  List<String> get goalFit;
  @override
  List<String> get tags;
  @override
  @JsonKey(name: 'is_free')
  bool? get isFree;
  @override
  String? get source;
  @override
  double? get distance;

  /// Create a copy of RecipeCard
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeCardImplCopyWith<_$RecipeCardImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
