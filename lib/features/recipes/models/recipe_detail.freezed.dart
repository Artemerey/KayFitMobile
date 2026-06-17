// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipe_detail.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecipeSlide _$RecipeSlideFromJson(Map<String, dynamic> json) {
  return _RecipeSlide.fromJson(json);
}

/// @nodoc
mixin _$RecipeSlide {
  @JsonKey(name: 'order_idx')
  int get orderIdx => throw _privateConstructorUsedError;
  String get kind => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String get imageUrl => throw _privateConstructorUsedError;
  String? get caption => throw _privateConstructorUsedError;

  /// Serializes this RecipeSlide to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipeSlide
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeSlideCopyWith<RecipeSlide> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeSlideCopyWith<$Res> {
  factory $RecipeSlideCopyWith(
    RecipeSlide value,
    $Res Function(RecipeSlide) then,
  ) = _$RecipeSlideCopyWithImpl<$Res, RecipeSlide>;
  @useResult
  $Res call({
    @JsonKey(name: 'order_idx') int orderIdx,
    String kind,
    @JsonKey(name: 'image_url') String imageUrl,
    String? caption,
  });
}

/// @nodoc
class _$RecipeSlideCopyWithImpl<$Res, $Val extends RecipeSlide>
    implements $RecipeSlideCopyWith<$Res> {
  _$RecipeSlideCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipeSlide
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderIdx = null,
    Object? kind = null,
    Object? imageUrl = null,
    Object? caption = freezed,
  }) {
    return _then(
      _value.copyWith(
            orderIdx: null == orderIdx
                ? _value.orderIdx
                : orderIdx // ignore: cast_nullable_to_non_nullable
                      as int,
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as String,
            imageUrl: null == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            caption: freezed == caption
                ? _value.caption
                : caption // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipeSlideImplCopyWith<$Res>
    implements $RecipeSlideCopyWith<$Res> {
  factory _$$RecipeSlideImplCopyWith(
    _$RecipeSlideImpl value,
    $Res Function(_$RecipeSlideImpl) then,
  ) = __$$RecipeSlideImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'order_idx') int orderIdx,
    String kind,
    @JsonKey(name: 'image_url') String imageUrl,
    String? caption,
  });
}

/// @nodoc
class __$$RecipeSlideImplCopyWithImpl<$Res>
    extends _$RecipeSlideCopyWithImpl<$Res, _$RecipeSlideImpl>
    implements _$$RecipeSlideImplCopyWith<$Res> {
  __$$RecipeSlideImplCopyWithImpl(
    _$RecipeSlideImpl _value,
    $Res Function(_$RecipeSlideImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipeSlide
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderIdx = null,
    Object? kind = null,
    Object? imageUrl = null,
    Object? caption = freezed,
  }) {
    return _then(
      _$RecipeSlideImpl(
        orderIdx: null == orderIdx
            ? _value.orderIdx
            : orderIdx // ignore: cast_nullable_to_non_nullable
                  as int,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as String,
        imageUrl: null == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        caption: freezed == caption
            ? _value.caption
            : caption // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeSlideImpl implements _RecipeSlide {
  const _$RecipeSlideImpl({
    @JsonKey(name: 'order_idx') required this.orderIdx,
    required this.kind,
    @JsonKey(name: 'image_url') required this.imageUrl,
    this.caption,
  });

  factory _$RecipeSlideImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeSlideImplFromJson(json);

  @override
  @JsonKey(name: 'order_idx')
  final int orderIdx;
  @override
  final String kind;
  @override
  @JsonKey(name: 'image_url')
  final String imageUrl;
  @override
  final String? caption;

  @override
  String toString() {
    return 'RecipeSlide(orderIdx: $orderIdx, kind: $kind, imageUrl: $imageUrl, caption: $caption)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeSlideImpl &&
            (identical(other.orderIdx, orderIdx) ||
                other.orderIdx == orderIdx) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.caption, caption) || other.caption == caption));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, orderIdx, kind, imageUrl, caption);

  /// Create a copy of RecipeSlide
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeSlideImplCopyWith<_$RecipeSlideImpl> get copyWith =>
      __$$RecipeSlideImplCopyWithImpl<_$RecipeSlideImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeSlideImplToJson(this);
  }
}

abstract class _RecipeSlide implements RecipeSlide {
  const factory _RecipeSlide({
    @JsonKey(name: 'order_idx') required final int orderIdx,
    required final String kind,
    @JsonKey(name: 'image_url') required final String imageUrl,
    final String? caption,
  }) = _$RecipeSlideImpl;

  factory _RecipeSlide.fromJson(Map<String, dynamic> json) =
      _$RecipeSlideImpl.fromJson;

  @override
  @JsonKey(name: 'order_idx')
  int get orderIdx;
  @override
  String get kind;
  @override
  @JsonKey(name: 'image_url')
  String get imageUrl;
  @override
  String? get caption;

  /// Create a copy of RecipeSlide
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeSlideImplCopyWith<_$RecipeSlideImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RecipeIngredient _$RecipeIngredientFromJson(Map<String, dynamic> json) {
  return _RecipeIngredient.fromJson(json);
}

/// @nodoc
mixin _$RecipeIngredient {
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'amount_g')
  int? get amountG => throw _privateConstructorUsedError;
  int? get kcal => throw _privateConstructorUsedError;

  /// Serializes this RecipeIngredient to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeIngredientCopyWith<RecipeIngredient> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeIngredientCopyWith<$Res> {
  factory $RecipeIngredientCopyWith(
    RecipeIngredient value,
    $Res Function(RecipeIngredient) then,
  ) = _$RecipeIngredientCopyWithImpl<$Res, RecipeIngredient>;
  @useResult
  $Res call({String name, @JsonKey(name: 'amount_g') int? amountG, int? kcal});
}

/// @nodoc
class _$RecipeIngredientCopyWithImpl<$Res, $Val extends RecipeIngredient>
    implements $RecipeIngredientCopyWith<$Res> {
  _$RecipeIngredientCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amountG = freezed,
    Object? kcal = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            amountG: freezed == amountG
                ? _value.amountG
                : amountG // ignore: cast_nullable_to_non_nullable
                      as int?,
            kcal: freezed == kcal
                ? _value.kcal
                : kcal // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipeIngredientImplCopyWith<$Res>
    implements $RecipeIngredientCopyWith<$Res> {
  factory _$$RecipeIngredientImplCopyWith(
    _$RecipeIngredientImpl value,
    $Res Function(_$RecipeIngredientImpl) then,
  ) = __$$RecipeIngredientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, @JsonKey(name: 'amount_g') int? amountG, int? kcal});
}

/// @nodoc
class __$$RecipeIngredientImplCopyWithImpl<$Res>
    extends _$RecipeIngredientCopyWithImpl<$Res, _$RecipeIngredientImpl>
    implements _$$RecipeIngredientImplCopyWith<$Res> {
  __$$RecipeIngredientImplCopyWithImpl(
    _$RecipeIngredientImpl _value,
    $Res Function(_$RecipeIngredientImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amountG = freezed,
    Object? kcal = freezed,
  }) {
    return _then(
      _$RecipeIngredientImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        amountG: freezed == amountG
            ? _value.amountG
            : amountG // ignore: cast_nullable_to_non_nullable
                  as int?,
        kcal: freezed == kcal
            ? _value.kcal
            : kcal // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeIngredientImpl implements _RecipeIngredient {
  const _$RecipeIngredientImpl({
    required this.name,
    @JsonKey(name: 'amount_g') this.amountG,
    this.kcal,
  });

  factory _$RecipeIngredientImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeIngredientImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey(name: 'amount_g')
  final int? amountG;
  @override
  final int? kcal;

  @override
  String toString() {
    return 'RecipeIngredient(name: $name, amountG: $amountG, kcal: $kcal)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeIngredientImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amountG, amountG) || other.amountG == amountG) &&
            (identical(other.kcal, kcal) || other.kcal == kcal));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, amountG, kcal);

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeIngredientImplCopyWith<_$RecipeIngredientImpl> get copyWith =>
      __$$RecipeIngredientImplCopyWithImpl<_$RecipeIngredientImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeIngredientImplToJson(this);
  }
}

abstract class _RecipeIngredient implements RecipeIngredient {
  const factory _RecipeIngredient({
    required final String name,
    @JsonKey(name: 'amount_g') final int? amountG,
    final int? kcal,
  }) = _$RecipeIngredientImpl;

  factory _RecipeIngredient.fromJson(Map<String, dynamic> json) =
      _$RecipeIngredientImpl.fromJson;

  @override
  String get name;
  @override
  @JsonKey(name: 'amount_g')
  int? get amountG;
  @override
  int? get kcal;

  /// Create a copy of RecipeIngredient
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeIngredientImplCopyWith<_$RecipeIngredientImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RecipeDetail _$RecipeDetailFromJson(Map<String, dynamic> json) {
  return _RecipeDetail.fromJson(json);
}

/// @nodoc
mixin _$RecipeDetail {
  RecipeCard get recipe => throw _privateConstructorUsedError;
  List<RecipeSlide> get slides => throw _privateConstructorUsedError;
  List<RecipeIngredient> get ingredients => throw _privateConstructorUsedError;

  /// Serializes this RecipeDetail to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipeDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeDetailCopyWith<RecipeDetail> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeDetailCopyWith<$Res> {
  factory $RecipeDetailCopyWith(
    RecipeDetail value,
    $Res Function(RecipeDetail) then,
  ) = _$RecipeDetailCopyWithImpl<$Res, RecipeDetail>;
  @useResult
  $Res call({
    RecipeCard recipe,
    List<RecipeSlide> slides,
    List<RecipeIngredient> ingredients,
  });

  $RecipeCardCopyWith<$Res> get recipe;
}

/// @nodoc
class _$RecipeDetailCopyWithImpl<$Res, $Val extends RecipeDetail>
    implements $RecipeDetailCopyWith<$Res> {
  _$RecipeDetailCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipeDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? recipe = null,
    Object? slides = null,
    Object? ingredients = null,
  }) {
    return _then(
      _value.copyWith(
            recipe: null == recipe
                ? _value.recipe
                : recipe // ignore: cast_nullable_to_non_nullable
                      as RecipeCard,
            slides: null == slides
                ? _value.slides
                : slides // ignore: cast_nullable_to_non_nullable
                      as List<RecipeSlide>,
            ingredients: null == ingredients
                ? _value.ingredients
                : ingredients // ignore: cast_nullable_to_non_nullable
                      as List<RecipeIngredient>,
          )
          as $Val,
    );
  }

  /// Create a copy of RecipeDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RecipeCardCopyWith<$Res> get recipe {
    return $RecipeCardCopyWith<$Res>(_value.recipe, (value) {
      return _then(_value.copyWith(recipe: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RecipeDetailImplCopyWith<$Res>
    implements $RecipeDetailCopyWith<$Res> {
  factory _$$RecipeDetailImplCopyWith(
    _$RecipeDetailImpl value,
    $Res Function(_$RecipeDetailImpl) then,
  ) = __$$RecipeDetailImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    RecipeCard recipe,
    List<RecipeSlide> slides,
    List<RecipeIngredient> ingredients,
  });

  @override
  $RecipeCardCopyWith<$Res> get recipe;
}

/// @nodoc
class __$$RecipeDetailImplCopyWithImpl<$Res>
    extends _$RecipeDetailCopyWithImpl<$Res, _$RecipeDetailImpl>
    implements _$$RecipeDetailImplCopyWith<$Res> {
  __$$RecipeDetailImplCopyWithImpl(
    _$RecipeDetailImpl _value,
    $Res Function(_$RecipeDetailImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipeDetail
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? recipe = null,
    Object? slides = null,
    Object? ingredients = null,
  }) {
    return _then(
      _$RecipeDetailImpl(
        recipe: null == recipe
            ? _value.recipe
            : recipe // ignore: cast_nullable_to_non_nullable
                  as RecipeCard,
        slides: null == slides
            ? _value._slides
            : slides // ignore: cast_nullable_to_non_nullable
                  as List<RecipeSlide>,
        ingredients: null == ingredients
            ? _value._ingredients
            : ingredients // ignore: cast_nullable_to_non_nullable
                  as List<RecipeIngredient>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeDetailImpl implements _RecipeDetail {
  const _$RecipeDetailImpl({
    required this.recipe,
    final List<RecipeSlide> slides = const <RecipeSlide>[],
    final List<RecipeIngredient> ingredients = const <RecipeIngredient>[],
  }) : _slides = slides,
       _ingredients = ingredients;

  factory _$RecipeDetailImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeDetailImplFromJson(json);

  @override
  final RecipeCard recipe;
  final List<RecipeSlide> _slides;
  @override
  @JsonKey()
  List<RecipeSlide> get slides {
    if (_slides is EqualUnmodifiableListView) return _slides;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_slides);
  }

  final List<RecipeIngredient> _ingredients;
  @override
  @JsonKey()
  List<RecipeIngredient> get ingredients {
    if (_ingredients is EqualUnmodifiableListView) return _ingredients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ingredients);
  }

  @override
  String toString() {
    return 'RecipeDetail(recipe: $recipe, slides: $slides, ingredients: $ingredients)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeDetailImpl &&
            (identical(other.recipe, recipe) || other.recipe == recipe) &&
            const DeepCollectionEquality().equals(other._slides, _slides) &&
            const DeepCollectionEquality().equals(
              other._ingredients,
              _ingredients,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    recipe,
    const DeepCollectionEquality().hash(_slides),
    const DeepCollectionEquality().hash(_ingredients),
  );

  /// Create a copy of RecipeDetail
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeDetailImplCopyWith<_$RecipeDetailImpl> get copyWith =>
      __$$RecipeDetailImplCopyWithImpl<_$RecipeDetailImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeDetailImplToJson(this);
  }
}

abstract class _RecipeDetail implements RecipeDetail {
  const factory _RecipeDetail({
    required final RecipeCard recipe,
    final List<RecipeSlide> slides,
    final List<RecipeIngredient> ingredients,
  }) = _$RecipeDetailImpl;

  factory _RecipeDetail.fromJson(Map<String, dynamic> json) =
      _$RecipeDetailImpl.fromJson;

  @override
  RecipeCard get recipe;
  @override
  List<RecipeSlide> get slides;
  @override
  List<RecipeIngredient> get ingredients;

  /// Create a copy of RecipeDetail
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeDetailImplCopyWith<_$RecipeDetailImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
