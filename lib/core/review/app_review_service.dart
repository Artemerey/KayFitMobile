import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for in-app review requests.
///
/// Rules:
/// - Max 3 requests per 365 days.
/// - Minimum 14 days between requests.
/// - If 3 requests have already been made in the past 365 days, never show again.
///
/// Key moments to call [tryRequest] (via [markPositiveMoment]):
/// - After user logs their 5th meal
/// - After user has used the app for 7+ days
/// - After user opens the personal plan (way-to-goal) screen for the 2nd time
class AppReviewService {
  AppReviewService._();

  static const _kDatesKey = 'review_request_dates';
  static const _kFirstLaunchKey = 'first_launch_date';
  static const _kMaxPerYear = 3;
  static const _kMinIntervalDays = 14;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Checks all conditions and calls [InAppReview.requestReview] if appropriate.
  ///
  /// Also ensures [_kFirstLaunchKey] is persisted on first ever call.
  static Future<void> tryRequest() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Persist first launch date if not yet saved.
      if (!prefs.containsKey(_kFirstLaunchKey)) {
        await prefs.setString(
          _kFirstLaunchKey,
          DateTime.now().toUtc().toIso8601String(),
        );
      }

      if (!await _canRequest(prefs)) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      await review.requestReview();
      await _saveRequestDate(prefs);
    } catch (e) {
      debugPrint('[AppReview] tryRequest error (ignored): $e');
    }
  }

  /// Call this at positive moments in the user journey.
  /// Internally delegates to [tryRequest].
  static Future<void> markPositiveMoment() => tryRequest();

  /// Returns the date of first app launch, or null if not yet recorded.
  static Future<DateTime?> firstLaunchDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFirstLaunchKey);
      if (raw == null) return null;
      return DateTime.tryParse(raw)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  static Future<bool> _canRequest(SharedPreferences prefs) async {
    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(const Duration(days: 365));

    final dates = _loadDates(prefs);
    final datesInYear =
        dates.where((d) => d.isAfter(cutoff)).toList()..sort();

    // Never show again once 3 requests have been made in the last 365 days.
    if (datesInYear.length >= _kMaxPerYear) return false;

    // Enforce minimum interval between requests.
    if (datesInYear.isNotEmpty) {
      final lastRequest = datesInYear.last;
      final daysSinceLast = now.difference(lastRequest).inDays;
      if (daysSinceLast < _kMinIntervalDays) return false;
    }

    return true;
  }

  static List<DateTime> _loadDates(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_kDatesKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DateTime.tryParse(e as String))
          .whereType<DateTime>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveRequestDate(SharedPreferences prefs) async {
    final dates = _loadDates(prefs);
    dates.add(DateTime.now().toUtc());
    final encoded = jsonEncode(dates.map((d) => d.toIso8601String()).toList());
    await prefs.setString(_kDatesKey, encoded);
  }
}
