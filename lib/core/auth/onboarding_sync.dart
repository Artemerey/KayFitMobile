import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../storage/onboarding_pending_storage.dart';
import '../feedback/feedback_coordinator.dart';

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
Future<bool> syncOnboardingPending({
  int? userId,
  Dio? client,
  bool throwOnFailure = false,
}) async {
  final dio = client ?? apiDio;
  final pending = await OnboardingPendingStorage.read();
  if (pending == null) {
    debugPrint(
      '[onboarding_sync] No pending data — triggering answer backfill',
    );
    // Still call answers endpoint so the backend backfills missing answers from profile
    try {
      await dio.get('/api/onboarding/answers');
    } catch (_) {}
    return false;
  }

  debugPrint('[onboarding_sync] Syncing pending onboarding data');

  final body = pending.toRequestBody();

  try {
    final response = await dio.post<Map<String, dynamic>>(
      '/api/onboarding/submit',
      data: body,
    );
    final pendingId = pending.submissionId;
    final serverId = response.data?['submission_id'] as String?;
    if (serverId != null) {
      await OnboardingPendingStorage.saveLastServerTarget(serverId);
    }
    if (userId != null && pendingId != null && serverId != null) {
      final owner = FeedbackRuntime.ownerBindingForUser(userId);
      if (owner != null) {
        await FeedbackRuntime.coordinator?.resolveOnboardingTarget(
          pendingSubmissionId: pendingId,
          serverId: serverId,
          ownerBinding: owner,
        );
      }
    }
    // The pre-auth onboarding step stores server catalog IDs locally. Once an
    // authenticated session exists, persist the structured selection; legacy
    // free text is never interpreted as a restriction.
    await dio.put(
      '/api/profile/restriction-tags',
      data: {'tag_ids': pending.restrictionTagIds},
    );
    // Only clear AFTER confirmed success — so failed syncs are retried next session
    await OnboardingPendingStorage.clear();
    debugPrint('[onboarding_sync] Sync complete — pending data cleared');
  } on DioException catch (e) {
    // Network error or server error: keep pending data so next app start retries
    debugPrint('[onboarding_sync] Sync failed (will retry on next start): $e');
    // Keep the complete pending payload for every failure, including 4xx from
    // the structured restriction PUT. Catalog state can change between the
    // pre-auth selection and login, and retry must never silently discard IDs.
    if (throwOnFailure) rethrow;
  } catch (e) {
    debugPrint(
      '[onboarding_sync] Unexpected sync error (will retry on next start): $e',
    );
    if (throwOnFailure) rethrow;
  }
  return true;
}
