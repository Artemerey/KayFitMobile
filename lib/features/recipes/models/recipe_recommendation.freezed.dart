// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipe_recommendation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

RecipeRecommendationMeta _$RecipeRecommendationMetaFromJson(
  Map<String, dynamic> json,
) {
  return _RecipeRecommendationMeta.fromJson(json);
}

/// @nodoc
mixin _$RecipeRecommendationMeta {
  @JsonKey(name: 'remaining_kcal')
  int get remainingKcal => throw _privateConstructorUsedError;
  String get goal => throw _privateConstructorUsedError;
  @JsonKey(name: 'kcal_lo')
  int get kcalLo => throw _privateConstructorUsedError;
  @JsonKey(name: 'kcal_hi')
  int get kcalHi => throw _privateConstructorUsedError;
  @JsonKey(name: 'cold_start')
  bool get coldStart => throw _privateConstructorUsedError;
  int get candidates => throw _privateConstructorUsedError;
  String? get fallback => throw _privateConstructorUsedError;

  /// Serializes this RecipeRecommendationMeta to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipeRecommendationMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeRecommendationMetaCopyWith<RecipeRecommendationMeta> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeRecommendationMetaCopyWith<$Res> {
  factory $RecipeRecommendationMetaCopyWith(
    RecipeRecommendationMeta value,
    $Res Function(RecipeRecommendationMeta) then,
  ) = _$RecipeRecommendationMetaCopyWithImpl<$Res, RecipeRecommendationMeta>;
  @useResult
  $Res call({
    @JsonKey(name: 'remaining_kcal') int remainingKcal,
    String goal,
    @JsonKey(name: 'kcal_lo') int kcalLo,
    @JsonKey(name: 'kcal_hi') int kcalHi,
    @JsonKey(name: 'cold_start') bool coldStart,
    int candidates,
    String? fallback,
  });
}

/// @nodoc
class _$RecipeRecommendationMetaCopyWithImpl<
  $Res,
  $Val extends RecipeRecommendationMeta
>
    implements $RecipeRecommendationMetaCopyWith<$Res> {
  _$RecipeRecommendationMetaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipeRecommendationMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? remainingKcal = null,
    Object? goal = null,
    Object? kcalLo = null,
    Object? kcalHi = null,
    Object? coldStart = null,
    Object? candidates = null,
    Object? fallback = freezed,
  }) {
    return _then(
      _value.copyWith(
            remainingKcal: null == remainingKcal
                ? _value.remainingKcal
                : remainingKcal // ignore: cast_nullable_to_non_nullable
                      as int,
            goal: null == goal
                ? _value.goal
                : goal // ignore: cast_nullable_to_non_nullable
                      as String,
            kcalLo: null == kcalLo
                ? _value.kcalLo
                : kcalLo // ignore: cast_nullable_to_non_nullable
                      as int,
            kcalHi: null == kcalHi
                ? _value.kcalHi
                : kcalHi // ignore: cast_nullable_to_non_nullable
                      as int,
            coldStart: null == coldStart
                ? _value.coldStart
                : coldStart // ignore: cast_nullable_to_non_nullable
                      as bool,
            candidates: null == candidates
                ? _value.candidates
                : candidates // ignore: cast_nullable_to_non_nullable
                      as int,
            fallback: freezed == fallback
                ? _value.fallback
                : fallback // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RecipeRecommendationMetaImplCopyWith<$Res>
    implements $RecipeRecommendationMetaCopyWith<$Res> {
  factory _$$RecipeRecommendationMetaImplCopyWith(
    _$RecipeRecommendationMetaImpl value,
    $Res Function(_$RecipeRecommendationMetaImpl) then,
  ) = __$$RecipeRecommendationMetaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'remaining_kcal') int remainingKcal,
    String goal,
    @JsonKey(name: 'kcal_lo') int kcalLo,
    @JsonKey(name: 'kcal_hi') int kcalHi,
    @JsonKey(name: 'cold_start') bool coldStart,
    int candidates,
    String? fallback,
  });
}

/// @nodoc
class __$$RecipeRecommendationMetaImplCopyWithImpl<$Res>
    extends
        _$RecipeRecommendationMetaCopyWithImpl<
          $Res,
          _$RecipeRecommendationMetaImpl
        >
    implements _$$RecipeRecommendationMetaImplCopyWith<$Res> {
  __$$RecipeRecommendationMetaImplCopyWithImpl(
    _$RecipeRecommendationMetaImpl _value,
    $Res Function(_$RecipeRecommendationMetaImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipeRecommendationMeta
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? remainingKcal = null,
    Object? goal = null,
    Object? kcalLo = null,
    Object? kcalHi = null,
    Object? coldStart = null,
    Object? candidates = null,
    Object? fallback = freezed,
  }) {
    return _then(
      _$RecipeRecommendationMetaImpl(
        remainingKcal: null == remainingKcal
            ? _value.remainingKcal
            : remainingKcal // ignore: cast_nullable_to_non_nullable
                  as int,
        goal: null == goal
            ? _value.goal
            : goal // ignore: cast_nullable_to_non_nullable
                  as String,
        kcalLo: null == kcalLo
            ? _value.kcalLo
            : kcalLo // ignore: cast_nullable_to_non_nullable
                  as int,
        kcalHi: null == kcalHi
            ? _value.kcalHi
            : kcalHi // ignore: cast_nullable_to_non_nullable
                  as int,
        coldStart: null == coldStart
            ? _value.coldStart
            : coldStart // ignore: cast_nullable_to_non_nullable
                  as bool,
        candidates: null == candidates
            ? _value.candidates
            : candidates // ignore: cast_nullable_to_non_nullable
                  as int,
        fallback: freezed == fallback
            ? _value.fallback
            : fallback // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeRecommendationMetaImpl implements _RecipeRecommendationMeta {
  const _$RecipeRecommendationMetaImpl({
    @JsonKey(name: 'remaining_kcal') required this.remainingKcal,
    required this.goal,
    @JsonKey(name: 'kcal_lo') required this.kcalLo,
    @JsonKey(name: 'kcal_hi') required this.kcalHi,
    @JsonKey(name: 'cold_start') required this.coldStart,
    required this.candidates,
    this.fallback,
  });

  factory _$RecipeRecommendationMetaImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeRecommendationMetaImplFromJson(json);

  @override
  @JsonKey(name: 'remaining_kcal')
  final int remainingKcal;
  @override
  final String goal;
  @override
  @JsonKey(name: 'kcal_lo')
  final int kcalLo;
  @override
  @JsonKey(name: 'kcal_hi')
  final int kcalHi;
  @override
  @JsonKey(name: 'cold_start')
  final bool coldStart;
  @override
  final int candidates;
  @override
  final String? fallback;

  @override
  String toString() {
    return 'RecipeRecommendationMeta(remainingKcal: $remainingKcal, goal: $goal, kcalLo: $kcalLo, kcalHi: $kcalHi, coldStart: $coldStart, candidates: $candidates, fallback: $fallback)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeRecommendationMetaImpl &&
            (identical(other.remainingKcal, remainingKcal) ||
                other.remainingKcal == remainingKcal) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.kcalLo, kcalLo) || other.kcalLo == kcalLo) &&
            (identical(other.kcalHi, kcalHi) || other.kcalHi == kcalHi) &&
            (identical(other.coldStart, coldStart) ||
                other.coldStart == coldStart) &&
            (identical(other.candidates, candidates) ||
                other.candidates == candidates) &&
            (identical(other.fallback, fallback) ||
                other.fallback == fallback));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    remainingKcal,
    goal,
    kcalLo,
    kcalHi,
    coldStart,
    candidates,
    fallback,
  );

  /// Create a copy of RecipeRecommendationMeta
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeRecommendationMetaImplCopyWith<_$RecipeRecommendationMetaImpl>
  get copyWith =>
      __$$RecipeRecommendationMetaImplCopyWithImpl<
        _$RecipeRecommendationMetaImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeRecommendationMetaImplToJson(this);
  }
}

abstract class _RecipeRecommendationMeta implements RecipeRecommendationMeta {
  const factory _RecipeRecommendationMeta({
    @JsonKey(name: 'remaining_kcal') required final int remainingKcal,
    required final String goal,
    @JsonKey(name: 'kcal_lo') required final int kcalLo,
    @JsonKey(name: 'kcal_hi') required final int kcalHi,
    @JsonKey(name: 'cold_start') required final bool coldStart,
    required final int candidates,
    final String? fallback,
  }) = _$RecipeRecommendationMetaImpl;

  factory _RecipeRecommendationMeta.fromJson(Map<String, dynamic> json) =
      _$RecipeRecommendationMetaImpl.fromJson;

  @override
  @JsonKey(name: 'remaining_kcal')
  int get remainingKcal;
  @override
  String get goal;
  @override
  @JsonKey(name: 'kcal_lo')
  int get kcalLo;
  @override
  @JsonKey(name: 'kcal_hi')
  int get kcalHi;
  @override
  @JsonKey(name: 'cold_start')
  bool get coldStart;
  @override
  int get candidates;
  @override
  String? get fallback;

  /// Create a copy of RecipeRecommendationMeta
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeRecommendationMetaImplCopyWith<_$RecipeRecommendationMetaImpl>
  get copyWith => throw _privateConstructorUsedError;
}

RecipeRecommendation _$RecipeRecommendationFromJson(Map<String, dynamic> json) {
  return _RecipeRecommendation.fromJson(json);
}

/// @nodoc
mixin _$RecipeRecommendation {
  List<RecipeCard> get recipes => throw _privateConstructorUsedError;
  @JsonKey(name: 'ishka_text')
  String get ishkaText => throw _privateConstructorUsedError;
  RecipeRecommendationMeta get meta => throw _privateConstructorUsedError;

  /// Serializes this RecipeRecommendation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecipeRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecipeRecommendationCopyWith<RecipeRecommendation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecipeRecommendationCopyWith<$Res> {
  factory $RecipeRecommendationCopyWith(
    RecipeRecommendation value,
    $Res Function(RecipeRecommendation) then,
  ) = _$RecipeRecommendationCopyWithImpl<$Res, RecipeRecommendation>;
  @useResult
  $Res call({
    List<RecipeCard> recipes,
    @JsonKey(name: 'ishka_text') String ishkaText,
    RecipeRecommendationMeta meta,
  });

  $RecipeRecommendationMetaCopyWith<$Res> get meta;
}

/// @nodoc
class _$RecipeRecommendationCopyWithImpl<
  $Res,
  $Val extends RecipeRecommendation
>
    implements $RecipeRecommendationCopyWith<$Res> {
  _$RecipeRecommendationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecipeRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? recipes = null,
    Object? ishkaText = null,
    Object? meta = null,
  }) {
    return _then(
      _value.copyWith(
            recipes: null == recipes
                ? _value.recipes
                : recipes // ignore: cast_nullable_to_non_nullable
                      as List<RecipeCard>,
            ishkaText: null == ishkaText
                ? _value.ishkaText
                : ishkaText // ignore: cast_nullable_to_non_nullable
                      as String,
            meta: null == meta
                ? _value.meta
                : meta // ignore: cast_nullable_to_non_nullable
                      as RecipeRecommendationMeta,
          )
          as $Val,
    );
  }

  /// Create a copy of RecipeRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RecipeRecommendationMetaCopyWith<$Res> get meta {
    return $RecipeRecommendationMetaCopyWith<$Res>(_value.meta, (value) {
      return _then(_value.copyWith(meta: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RecipeRecommendationImplCopyWith<$Res>
    implements $RecipeRecommendationCopyWith<$Res> {
  factory _$$RecipeRecommendationImplCopyWith(
    _$RecipeRecommendationImpl value,
    $Res Function(_$RecipeRecommendationImpl) then,
  ) = __$$RecipeRecommendationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<RecipeCard> recipes,
    @JsonKey(name: 'ishka_text') String ishkaText,
    RecipeRecommendationMeta meta,
  });

  @override
  $RecipeRecommendationMetaCopyWith<$Res> get meta;
}

/// @nodoc
class __$$RecipeRecommendationImplCopyWithImpl<$Res>
    extends _$RecipeRecommendationCopyWithImpl<$Res, _$RecipeRecommendationImpl>
    implements _$$RecipeRecommendationImplCopyWith<$Res> {
  __$$RecipeRecommendationImplCopyWithImpl(
    _$RecipeRecommendationImpl _value,
    $Res Function(_$RecipeRecommendationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RecipeRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? recipes = null,
    Object? ishkaText = null,
    Object? meta = null,
  }) {
    return _then(
      _$RecipeRecommendationImpl(
        recipes: null == recipes
            ? _value._recipes
            : recipes // ignore: cast_nullable_to_non_nullable
                  as List<RecipeCard>,
        ishkaText: null == ishkaText
            ? _value.ishkaText
            : ishkaText // ignore: cast_nullable_to_non_nullable
                  as String,
        meta: null == meta
            ? _value.meta
            : meta // ignore: cast_nullable_to_non_nullable
                  as RecipeRecommendationMeta,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RecipeRecommendationImpl implements _RecipeRecommendation {
  const _$RecipeRecommendationImpl({
    final List<RecipeCard> recipes = const <RecipeCard>[],
    @JsonKey(name: 'ishka_text') this.ishkaText = '',
    required this.meta,
  }) : _recipes = recipes;

  factory _$RecipeRecommendationImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecipeRecommendationImplFromJson(json);

  final List<RecipeCard> _recipes;
  @override
  @JsonKey()
  List<RecipeCard> get recipes {
    if (_recipes is EqualUnmodifiableListView) return _recipes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recipes);
  }

  @override
  @JsonKey(name: 'ishka_text')
  final String ishkaText;
  @override
  final RecipeRecommendationMeta meta;

  @override
  String toString() {
    return 'RecipeRecommendation(recipes: $recipes, ishkaText: $ishkaText, meta: $meta)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecipeRecommendationImpl &&
            const DeepCollectionEquality().equals(other._recipes, _recipes) &&
            (identical(other.ishkaText, ishkaText) ||
                other.ishkaText == ishkaText) &&
            (identical(other.meta, meta) || other.meta == meta));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_recipes),
    ishkaText,
    meta,
  );

  /// Create a copy of RecipeRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecipeRecommendationImplCopyWith<_$RecipeRecommendationImpl>
  get copyWith =>
      __$$RecipeRecommendationImplCopyWithImpl<_$RecipeRecommendationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RecipeRecommendationImplToJson(this);
  }
}

abstract class _RecipeRecommendation implements RecipeRecommendation {
  const factory _RecipeRecommendation({
    final List<RecipeCard> recipes,
    @JsonKey(name: 'ishka_text') final String ishkaText,
    required final RecipeRecommendationMeta meta,
  }) = _$RecipeRecommendationImpl;

  factory _RecipeRecommendation.fromJson(Map<String, dynamic> json) =
      _$RecipeRecommendationImpl.fromJson;

  @override
  List<RecipeCard> get recipes;
  @override
  @JsonKey(name: 'ishka_text')
  String get ishkaText;
  @override
  RecipeRecommendationMeta get meta;

  /// Create a copy of RecipeRecommendation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecipeRecommendationImplCopyWith<_$RecipeRecommendationImpl>
  get copyWith => throw _privateConstructorUsedError;
}
