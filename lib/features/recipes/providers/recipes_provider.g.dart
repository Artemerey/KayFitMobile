// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recipeRecommendationHash() =>
    r'83c766867a8702d8a71f796419a5bb86ab9c5468';

/// RAG recommendation for the current user: remaining kcal + goal + taste →
/// 1-3 recipes + Ишка's "fits your day" line.
///
/// Endpoint is `/api/recipes/recommend` — the production nginx only proxies
/// `^/(api|auth)`, so the `/api` prefix is mandatory (a bare `/recipes` would
/// hit the SPA). All context (goals, today's totals, profile) is assembled
/// server-side from the JWT; the client sends no query params here.
///
/// Copied from [recipeRecommendation].
@ProviderFor(recipeRecommendation)
final recipeRecommendationProvider =
    AutoDisposeFutureProvider<RecipeRecommendation>.internal(
      recipeRecommendation,
      name: r'recipeRecommendationProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recipeRecommendationHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecipeRecommendationRef =
    AutoDisposeFutureProviderRef<RecipeRecommendation>;
String _$recipeDetailHash() => r'da3c690af887273645d38739851ccab2236f0837';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Full recipe detail (card + ordered slides + ingredients) for the carousel
/// viewer. Returns 404 for non-approved slugs — surfaced as a DioException the
/// screen renders as an empty/error state.
///
/// Copied from [recipeDetail].
@ProviderFor(recipeDetail)
const recipeDetailProvider = RecipeDetailFamily();

/// Full recipe detail (card + ordered slides + ingredients) for the carousel
/// viewer. Returns 404 for non-approved slugs — surfaced as a DioException the
/// screen renders as an empty/error state.
///
/// Copied from [recipeDetail].
class RecipeDetailFamily extends Family<AsyncValue<RecipeDetail>> {
  /// Full recipe detail (card + ordered slides + ingredients) for the carousel
  /// viewer. Returns 404 for non-approved slugs — surfaced as a DioException the
  /// screen renders as an empty/error state.
  ///
  /// Copied from [recipeDetail].
  const RecipeDetailFamily();

  /// Full recipe detail (card + ordered slides + ingredients) for the carousel
  /// viewer. Returns 404 for non-approved slugs — surfaced as a DioException the
  /// screen renders as an empty/error state.
  ///
  /// Copied from [recipeDetail].
  RecipeDetailProvider call(String slug) {
    return RecipeDetailProvider(slug);
  }

  @override
  RecipeDetailProvider getProviderOverride(
    covariant RecipeDetailProvider provider,
  ) {
    return call(provider.slug);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'recipeDetailProvider';
}

/// Full recipe detail (card + ordered slides + ingredients) for the carousel
/// viewer. Returns 404 for non-approved slugs — surfaced as a DioException the
/// screen renders as an empty/error state.
///
/// Copied from [recipeDetail].
class RecipeDetailProvider extends AutoDisposeFutureProvider<RecipeDetail> {
  /// Full recipe detail (card + ordered slides + ingredients) for the carousel
  /// viewer. Returns 404 for non-approved slugs — surfaced as a DioException the
  /// screen renders as an empty/error state.
  ///
  /// Copied from [recipeDetail].
  RecipeDetailProvider(String slug)
    : this._internal(
        (ref) => recipeDetail(ref as RecipeDetailRef, slug),
        from: recipeDetailProvider,
        name: r'recipeDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$recipeDetailHash,
        dependencies: RecipeDetailFamily._dependencies,
        allTransitiveDependencies:
            RecipeDetailFamily._allTransitiveDependencies,
        slug: slug,
      );

  RecipeDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
  }) : super.internal();

  final String slug;

  @override
  Override overrideWith(
    FutureOr<RecipeDetail> Function(RecipeDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RecipeDetailProvider._internal(
        (ref) => create(ref as RecipeDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<RecipeDetail> createElement() {
    return _RecipeDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RecipeDetailProvider && other.slug == slug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RecipeDetailRef on AutoDisposeFutureProviderRef<RecipeDetail> {
  /// The parameter `slug` of this provider.
  String get slug;
}

class _RecipeDetailProviderElement
    extends AutoDisposeFutureProviderElement<RecipeDetail>
    with RecipeDetailRef {
  _RecipeDetailProviderElement(super.provider);

  @override
  String get slug => (origin as RecipeDetailProvider).slug;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
