import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'feedback_analytics.dart';
import 'feedback_models.dart';
import 'feedback_repository.dart';
import 'feedback_storage.dart';
import 'secure_uuid.dart';

class FeedbackCoordinator {
  FeedbackCoordinator({
    required FeedbackQueueStorage storage,
    required FeedbackRepository repository,
    required FeedbackAnalytics analytics,
    DateTime Function()? clock,
    Random? random,
  }) : _storage = storage,
       _repository = repository,
       _analytics = analytics,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  static const batchSize = 20;
  final FeedbackQueueStorage _storage;
  final FeedbackRepository _repository;
  final FeedbackAnalytics _analytics;
  final DateTime Function() _clock;
  final Random _random;
  Future<void>? _activeFlush;
  final Map<String, FeedbackDeliveryKind> _lastResults = {};

  Future<String> enqueue({
    required FeedbackTargetRef target,
    required FeedbackRequest request,
    String? ownerBinding,
    String? eventId,
  }) async {
    final now = _clock().toUtc();
    final id = eventId ?? SecureUuid.v4(random: _random);
    final queueResult = await _storage.enqueue(
      PendingFeedback(
        eventId: id,
        targetRef: target,
        request: request,
        createdAt: now,
        nextAttemptAt: now,
        ownerBinding: ownerBinding,
      ),
      now,
    );
    for (final expiredTarget in queueResult.expiredTargets) {
      _analytics.queueResult(
        result: 'expired',
        target: expiredTarget,
        httpClass: 'network',
      );
    }
    if (queueResult.overflowed) {
      _analytics.queueResult(
        result: 'overflow',
        target: target.type,
        httpClass: 'network',
      );
    }
    return id;
  }

  Future<FeedbackDeliveryKind> enqueueAndFlushAnonymous({
    required FeedbackTargetRef target,
    required FeedbackRequest request,
  }) async {
    final eventId = await enqueue(target: target, request: request);
    await flushAnonymous();
    return _lastResults.remove(eventId) ?? FeedbackDeliveryKind.retryable;
  }

  Future<FeedbackTargetRef> createAnonymousOnboardingTarget(
    String submissionId,
  ) async {
    final target = await _repository.createAnonymousOnboardingTarget(
      submissionId,
    );
    await _storage.rememberCapability(target);
    return target;
  }

  Future<FeedbackTargetRef> createMealRecognitionTarget(
    FeedbackSource source,
  ) => _repository.createMealRecognitionTarget(source);

  Future<FeedbackTargetRef?> restoreAnonymousOnboardingTarget({
    required String submissionId,
    required String targetId,
  }) async {
    final capability = await _storage.readCapability(targetId);
    if (capability == null) return null;
    return FeedbackTargetRef(
      type: FeedbackTargetType.onboardingPlan,
      serverId: targetId,
      pendingSubmissionId: submissionId,
      feedbackCapability: capability,
    );
  }

  Future<void> resolveOnboardingTarget({
    required String pendingSubmissionId,
    required String serverId,
    required String ownerBinding,
  }) async {
    final items = await _storage.read();
    final resolved = items.map((item) {
      if (item.targetRef.type == FeedbackTargetType.onboardingPlan &&
          item.targetRef.pendingSubmissionId == pendingSubmissionId) {
        return item.copyWith(
          targetRef: item.targetRef.resolve(serverId),
          ownerBinding: ownerBinding,
        );
      }
      return item;
    }).toList();
    await _storage.write(resolved);
  }

  Future<void> flush(String ownerBinding) {
    return _flush(ownerBinding: ownerBinding, anonymous: false);
  }

  Future<void> flushAnonymous() {
    return _flush(ownerBinding: null, anonymous: true);
  }

  Future<void> flushAll({String? ownerBinding}) async {
    await flushAnonymous();
    if (ownerBinding != null) await flush(ownerBinding);
  }

  Future<void> _flush({
    required String? ownerBinding,
    required bool anonymous,
  }) {
    final current = _activeFlush;
    if (current != null) return current;
    final completer = Completer<void>();
    _activeFlush = completer.future;
    _flushCycle(ownerBinding, anonymous: anonymous)
        .then(completer.complete, onError: completer.completeError)
        .whenComplete(() => _activeFlush = null);
    return completer.future;
  }

  Future<void> _flushCycle(
    String? ownerBinding, {
    required bool anonymous,
  }) async {
    final now = _clock().toUtc();
    var items = await _storage.read();
    final expired = items
        .where(
          (item) => now.difference(item.createdAt) >= FeedbackQueueStorage.ttl,
        )
        .toList();
    items.removeWhere((item) => expired.contains(item));
    for (final item in expired) {
      _analytics.queueResult(
        result: 'expired',
        target: item.targetRef.type,
        httpClass: 'network',
      );
    }
    await _storage.write(items);

    final due = items
        .where(
          (item) =>
              (anonymous
                  ? item.ownerBinding == null &&
                        item.targetRef.canSubmitAnonymously
                  : item.ownerBinding == ownerBinding) &&
              item.targetRef.isResolved &&
              !item.nextAttemptAt.isAfter(now),
        )
        .take(batchSize)
        .map((item) => item.eventId)
        .toList(growable: false);
    for (final eventId in due) {
      items = await _storage.read();
      final index = items.indexWhere((item) => item.eventId == eventId);
      if (index < 0) continue;
      final item = items[index];
      final result = await _repository.submit(item);
      _lastResults[item.eventId] = result.kind;
      final httpClass = _httpClass(result.statusCode);
      final analyticsResultPrefix = item.targetRef.canSubmitAnonymously
          ? 'anonymous_'
          : '';
      switch (result.kind) {
        case FeedbackDeliveryKind.success:
          items.removeAt(index);
          _analytics.queueResult(
            result: '${analyticsResultPrefix}sent',
            target: item.targetRef.type,
            httpClass: httpClass,
          );
        case FeedbackDeliveryKind.permanent:
          items.removeAt(index);
          _analytics.queueResult(
            result: '${analyticsResultPrefix}permanent',
            target: item.targetRef.type,
            httpClass: httpClass,
          );
        case FeedbackDeliveryKind.unauthorized:
          await _storage.write(items);
          return;
        case FeedbackDeliveryKind.retryable:
          final attempt = item.attemptCount + 1;
          final exponent = min(attempt - 1, 10);
          final baseSeconds = min(3600, 5 * (1 << exponent));
          final jitter = _random.nextInt(max(1, baseSeconds ~/ 4 + 1));
          var delay = Duration(seconds: baseSeconds + jitter);
          if (result.retryAfter != null && result.retryAfter! > delay) {
            delay = result.retryAfter!;
          }
          items[index] = item.copyWith(
            attemptCount: attempt,
            nextAttemptAt: now.add(delay),
            lastErrorCode: _safeErrorCode(result.statusCode),
          );
          _analytics.queueResult(
            result: '${analyticsResultPrefix}retryable',
            target: item.targetRef.type,
            httpClass: httpClass,
          );
      }
      await _storage.write(items);
    }
  }

  static String _httpClass(int? status) {
    if (status == null) return 'network';
    if (status >= 500) return '5xx';
    if (status >= 400) return '4xx';
    return '2xx';
  }

  static String _safeErrorCode(int? status) =>
      status == null ? 'network' : 'http_$status';

  static String ownerBindingFor(int userId, String installationSecret) {
    // A local opaque binding: no raw account ID is persisted in the queue.
    final bytes = utf8.encode('$installationSecret:$userId');
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

class FeedbackRuntime {
  FeedbackRuntime._();
  static FeedbackCoordinator? coordinator;
  static String? _installationSecret;

  static Future<void> initialize({
    required SharedPreferences preferences,
    required FeedbackRepository repository,
    FeedbackAnalytics analytics = const FirebaseFeedbackAnalytics(),
  }) async {
    const secretKey = 'feedback_installation_secret_v1';
    _installationSecret = preferences.getString(secretKey);
    if (_installationSecret == null) {
      _installationSecret = SecureUuid.v4();
      await preferences.setString(secretKey, _installationSecret!);
    }
    coordinator = FeedbackCoordinator(
      storage: FeedbackQueueStorage(preferences),
      repository: repository,
      analytics: analytics,
    );
  }

  static String? ownerBindingForUser(int userId) {
    final secret = _installationSecret;
    return secret == null
        ? null
        : FeedbackCoordinator.ownerBindingFor(userId, secret);
  }
}
