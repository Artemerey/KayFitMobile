// test/regression/tariffs_discount_regression_test.dart
//
// Regression tests for two bugs fixed 2026-06-08:
//
//   BUG-D1 — Discount badge showed hardcoded "−20%" for ALL users.
//            Fix: _discountBadge() now computes pct from discounted_price/price.
//            If no discounted_price → badge must be empty string.
//
//   BUG-D2 — Countdown timer fired for ALL users regardless of promo code.
//            Fix: timer is gated behind hasDiscount check.
//            If no tariff has discounted_price → hasDiscount must be false.
//
// Private helpers in tariffs_screen.dart are replicated here as pure
// functions — same pattern as router_auth_regression_test.dart.

import 'package:flutter_test/flutter_test.dart';

// ─── Replicated helpers (must stay in sync with tariffs_screen.dart) ──────────

num? _discountedPrice(Map<String, dynamic> t) {
  final v = t['discounted_price'];
  if (v == null) return null;
  final n = v as num;
  final price = (t['price'] as num?) ?? 0;
  return n < price ? n : null;
}

String _discountBadge(Map<String, dynamic> t) {
  final discounted = _discountedPrice(t);
  if (discounted == null) return '';
  final price = (t['price'] as num?) ?? 0;
  if (price <= 0) return '';
  final pct = ((1 - discounted / price) * 100).round();
  return '−$pct%';
}

bool _hasDiscount(List<Map<String, dynamic>> tariffs) =>
    tariffs.any((t) => _discountedPrice(t) != null);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // BUG-D1: badge computation
  group('_discountBadge (BUG-D1 regression)', () {
    test('returns empty string when discounted_price is absent', () {
      final t = {'code': 'monthly', 'price': 299};
      expect(_discountBadge(t), '');
    });

    test('returns empty string when discounted_price equals price', () {
      final t = {'code': 'monthly', 'price': 299, 'discounted_price': 299};
      expect(_discountBadge(t), '');
    });

    test('returns empty string when discounted_price exceeds price', () {
      final t = {'code': 'monthly', 'price': 299, 'discounted_price': 400};
      expect(_discountBadge(t), '');
    });

    test('returns empty string when price is zero', () {
      final t = {'code': 'monthly', 'price': 0, 'discounted_price': 0};
      expect(_discountBadge(t), '');
    });

    test('returns correct 20% badge for a 20-percent promo', () {
      final t = {'code': 'monthly', 'price': 299, 'discounted_price': 239.2};
      expect(_discountBadge(t), '−20%');
    });

    test('returns correct 30% badge for a 30-percent promo', () {
      final t = {'code': 'yearly', 'price': 1990, 'discounted_price': 1393.0};
      expect(_discountBadge(t), '−30%');
    });

    test('never returns hardcoded −20% when discount is not 20%', () {
      // e.g. a 10% promo must not show −20%
      final t = {'code': 'monthly', 'price': 299, 'discounted_price': 269.1};
      final badge = _discountBadge(t);
      expect(badge, isNot('−20%'));
      expect(badge, '−10%');
    });
  });

  // BUG-D2: timer guard
  group('hasDiscount timer gate (BUG-D2 regression)', () {
    test('false when no tariff has discounted_price', () {
      final tariffs = [
        {'code': 'monthly', 'price': 299},
        {'code': 'yearly', 'price': 1990},
      ];
      expect(_hasDiscount(tariffs), false);
    });

    test('false when all discounted_prices equal or exceed price', () {
      final tariffs = [
        {'code': 'monthly', 'price': 299, 'discounted_price': 299},
        {'code': 'yearly', 'price': 1990, 'discounted_price': 2000},
      ];
      expect(_hasDiscount(tariffs), false);
    });

    test('true when at least one tariff has a real discount', () {
      final tariffs = [
        {'code': 'monthly', 'price': 299, 'discounted_price': 239.2},
        {'code': 'yearly', 'price': 1990},
      ];
      expect(_hasDiscount(tariffs), true);
    });

    test('true when all tariffs have a discount', () {
      final tariffs = [
        {'code': 'monthly', 'price': 299, 'discounted_price': 239.2},
        {'code': 'yearly', 'price': 1990, 'discounted_price': 1393.0},
      ];
      expect(_hasDiscount(tariffs), true);
    });

    test('false for empty tariff list', () {
      expect(_hasDiscount([]), false);
    });
  });
}
