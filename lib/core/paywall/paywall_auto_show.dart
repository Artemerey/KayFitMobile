import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/paywall/screens/paywall_sheet.dart';

const _kPaywallDiscountStartMs = 'paywall_discount_start_ms';

// In-memory flag: resets on app restart, survives Journal state recreation.
final _paywallAutoShownProvider = StateProvider<bool>((ref) => false);

Future<void> maybeShowPaywallOnce(BuildContext context, WidgetRef ref) async {
  if (Localizations.localeOf(context).languageCode != 'ru') return;

  if (ref.read(_paywallAutoShownProvider)) return;

  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;

  final stored = prefs.getInt(_kPaywallDiscountStartMs);
  if (stored == null) {
    await prefs.setInt(
      _kPaywallDiscountStartMs,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (!context.mounted) return;
    ref.read(_paywallAutoShownProvider.notifier).state = true;
    await showPaywallSheet(context);
    return;
  }

  final elapsed = DateTime.now().millisecondsSinceEpoch - stored;
  if (elapsed < 3600000) {
    if (!context.mounted) return;
    ref.read(_paywallAutoShownProvider.notifier).state = true;
    await showPaywallSheet(context);
  }
}
