// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentOfferingHash() => r'32d54dcb6f2a67dd661f73b509a276516f3ecdb6';

/// Loads the current RevenueCat offering.
/// Returns null if RC is not configured or network is unavailable.
///
/// Copied from [currentOffering].
@ProviderFor(currentOffering)
final currentOfferingProvider = AutoDisposeFutureProvider<Offering?>.internal(
  currentOffering,
  name: r'currentOfferingProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentOfferingHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentOfferingRef = AutoDisposeFutureProviderRef<Offering?>;
String _$subscriptionNotifierHash() =>
    r'a4c32506eb6da066dee4c775fdd3cf0d4ddadb39';

/// See also [SubscriptionNotifier].
@ProviderFor(SubscriptionNotifier)
final subscriptionNotifierProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>.internal(
      SubscriptionNotifier.new,
      name: r'subscriptionNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$subscriptionNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SubscriptionNotifier = Notifier<SubscriptionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
