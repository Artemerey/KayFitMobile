import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_state.dart';
import 'subscription_provider.dart';
import '../../features/paywall/screens/paywall_sheet.dart';

// In-memory cooldown — resets on app restart and on successful subscription.
// NOT stored in SharedPreferences so we never block a newly-subscribed user.
DateTime? _lastPaywallShown;

/// Call before any AI feature. Returns true if user may proceed.
///
/// Shows the paywall if user is not subscribed (with 24 h cooldown to avoid spam).
/// If [bypassInDebug] is true (default), always returns true in debug mode.
Future<bool> requireSubscription(
  BuildContext context,
  WidgetRef ref, {
  bool bypassInDebug = const bool.fromEnvironment(
    'ENFORCE_PAYWALL',
    defaultValue: false,
  ),
}) async {
  // Dev bypass: pass --dart-define=ENFORCE_PAYWALL=true to enable paywall in debug.
  if (!bypassInDebug) return true;

  final subState = ref.read(subscriptionNotifierProvider);

  if (subState is SubscriptionActive || subState is SubscriptionGracePeriod) {
    return true;
  }

  if (subState is SubscriptionPending) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Платёж обрабатывается. Попробуйте позже.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }

  final now = DateTime.now();
  if (_lastPaywallShown != null &&
      now.difference(_lastPaywallShown!) < const Duration(hours: 24)) {
    return false;
  }

  if (!context.mounted) return false;
  _lastPaywallShown = now;

  final result = await showPaywallSheet(context);
  if (result == PaywallResult.subscribed) {
    _lastPaywallShown = null;
    return true;
  }
  return false;
}
