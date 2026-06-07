import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../api/api_client.dart';
import 'subscription_state.dart';

part 'subscription_provider.g.dart';

enum PaywallResult { subscribed, cancelled, pending }

@Riverpod(keepAlive: true)
class SubscriptionNotifier extends _$SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionUnknown();

  Future<void> refresh() async {
    try {
      final info = await Purchases.getCustomerInfo();
      state = _stateFrom(info);
    } on PlatformException {
      // Keep current state — transient network error
    }
  }

  Future<PaywallResult> purchase(Package package) async {
    try {
      final info = await Purchases.purchasePackage(package);
      state = _stateFrom(info);
      return state is SubscriptionActive
          ? PaywallResult.subscribed
          : PaywallResult.cancelled;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PaywallResult.cancelled;
      }
      if (code == PurchasesErrorCode.paymentPendingError) {
        state = const SubscriptionPending();
        return PaywallResult.pending;
      }
      rethrow;
    }
  }

  Future<void> restore() async {
    final info = await Purchases.restorePurchases();
    state = _stateFrom(info);
  }

  SubscriptionState _stateFrom(CustomerInfo info) {
    final premium = info.entitlements.all['premium'];
    if (premium == null || !premium.isActive) return const SubscriptionExpired();
    final expiresAt = _parseDate(premium.expirationDate);
    if (premium.billingIssueDetectedAt != null) {
      return SubscriptionGracePeriod(
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 16)),
      );
    }
    return SubscriptionActive(
      productId: premium.productIdentifier,
      expiresAt: expiresAt ?? DateTime(2099),
    );
  }

  DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

/// Loads the current RevenueCat offering.
/// Returns null if RC is not configured or network is unavailable.
@riverpod
Future<Offering?> currentOffering(Ref ref) async {
  try {
    final offerings = await Purchases.getOfferings();
    return offerings.current;
  } on PlatformException {
    return null;
  }
}

/// Loads the "discount" RevenueCat offering (must be created in RC dashboard).
/// Returns null if the offering is not configured or unavailable.
final discountOfferingProvider = FutureProvider<Offering?>((ref) async {
  try {
    final offerings = await Purchases.getOfferings();
    return offerings.getOffering('discount');
  } on PlatformException {
    return null;
  }
});

/// Backend subscription check (for YooKassa web payments).
final backendSubscriptionProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  try {
    final resp = await apiDio.get<Map<String, dynamic>>('/api/payments/subscription');
    return resp.data;
  } catch (_) {
    return null;
  }
});
