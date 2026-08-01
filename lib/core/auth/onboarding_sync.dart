import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../storage/onboarding_pending_storage.dart';

/// Syncs locally stored onboarding data to the backend after login.
///
/// Uses a single atomic endpoint [POST /api/onboarding/submit].
/// Pending storage is cleared ONLY after a confirmed successful response.
/// This means calling this function multiple times is safe — it will retry
/// until data is confirmed saved (idempotent on the server).
///
/// Call this:
///   1. Right after any successful login/register (before refreshUser).
///   2. On app start if the user is already authenticated (to handle
///      cases where sync failed last time due to network issues).
Future<bool> syncOnboardingPending() async {
  final pending = await OnboardingPendingStorage.read();
  if (pending == null) {
    debugPrint(
      '[onboarding_sync] No pending data — triggering answer backfill',
    );
    // Still call answers endpoint so the backend backfills missing answers from profile
    try {
      await apiDio.get('/api/onboarding/answers');
    } catch (_) {}
    return false;
  }

  debugPrint(
    '[onboarding_sync] Syncing pending onboarding data: '
    'age=${pending.age} height=${pending.height} weight=${pending.weight} '
    'targetWeight=${pending.targetWeight} gender=${pending.gender} '
    'trainingDays=${pending.trainingDays} '
    'healthConditions=${pending.healthConditions} '
    'dietType=${pending.dietType} goals=${pending.goals}',
  );

  final body = pending.toRequestBody();

  try {
    await apiDio.post('/api/onboarding/submit', data: body);
    // Only clear AFTER confirmed success — so failed syncs are retried next session
    await OnboardingPendingStorage.clear();
    debugPrint('[onboarding_sync] Sync complete — pending data cleared');
  } on DioException catch (e) {
    // Network error or server error: keep pending data so next app start retries
    debugPrint('[onboarding_sync] Sync failed (will retry on next start): $e');
    // 4xx means bad data — no point retrying; clear to avoid blocking the user
    final status = e.response?.statusCode;
    if (status != null && status >= 400 && status < 500) {
      debugPrint(
        '[onboarding_sync] 4xx error — clearing pending to avoid infinite retry',
      );
      await OnboardingPendingStorage.clear();
    }
  } catch (e) {
    debugPrint(
      '[onboarding_sync] Unexpected sync error (will retry on next start): $e',
    );
  }
  return true;
}
