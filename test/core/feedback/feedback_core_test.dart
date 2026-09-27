import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/feedback/feedback_analytics.dart';
import 'package:kayfit/core/feedback/feedback_coordinator.dart';
import 'package:kayfit/core/feedback/feedback_capability_storage.dart';
import 'package:kayfit/core/feedback/feedback_models.dart';
import 'package:kayfit/core/feedback/feedback_repository.dart';
import 'package:kayfit/core/feedback/feedback_storage.dart';
import 'package:kayfit/core/feedback/secure_uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepository extends FeedbackRepository {
  _FakeRepository(this.results) : super(Dio());
  final List<FeedbackDeliveryResult> results;
  final List<String> eventIds = [];
  int calls = 0;

  @override
  Future<FeedbackDeliveryResult> submit(PendingFeedback item) async {
    calls++;
    eventIds.add(item.eventId);
    await Future<void>.delayed(Duration.zero);
    return results.removeAt(0);
  }
}

class _Analytics implements FeedbackAnalytics {
  final events = <Map<String, String>>[];
  @override
  void promptShown(FeedbackTargetType target, FeedbackSource source) {}
  @override
  void submitted({
    required FeedbackTargetType target,
    required FeedbackSource source,
    required FeedbackRating rating,
    required bool hasReason,
    required bool hasComment,
    required String delivery,
  }) {}
  @override
  void queueResult({
    required String result,
    required FeedbackTargetType target,
    required String httpClass,
  }) => events.add({
    'result': result,
    'target_type': target.apiValue,
    'http_class': httpClass,
  });
}

class _MemoryCapabilities implements FeedbackCapabilityStorage {
  final values = <String, String>{};
  @override
  Future<void> delete(String targetId) async => values.remove(targetId);
  @override
  Future<String?> read(String targetId) async => values[targetId];
  @override
  Future<void> write(String targetId, String capability) async =>
      values[targetId] = capability;
}

PendingFeedback _item({
  required String id,
  required DateTime now,
  String owner = 'owner-a',
  String? serverId = '11111111-1111-4111-8111-111111111111',
  String? pendingId,
}) => PendingFeedback(
  eventId: id,
  targetRef: FeedbackTargetRef(
    type: pendingId == null
        ? FeedbackTargetType.mealSave
        : FeedbackTargetType.onboardingPlan,
    serverId: serverId,
    pendingSubmissionId: pendingId,
  ),
  request: FeedbackRequest(
    rating: FeedbackRating.like,
    source: pendingId == null
        ? FeedbackSource.photo
        : FeedbackSource.onboarding,
  ),
  createdAt: now,
  nextAttemptAt: now,
  ownerBinding: owner,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 8, 6, 12);
  });

  test('secure UUID is canonical v4 with RFC 4122 variant', () {
    final id = SecureUuid.v4(random: Random(7));
    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('feedback request carries automatic diagnostics through queue JSON', () {
    const request = FeedbackRequest(
      rating: FeedbackRating.dislike,
      source: FeedbackSource.photo,
      reasons: [FeedbackReason.recognitionTooSlow],
      appVersion: '1.3.2+16',
      platform: 'ios',
      context: {'recognition_mode': 'kf2', 'recognition_duration_ms': 4321},
    );
    final restored = FeedbackRequest.fromJson(
      request.toJson(),
      FeedbackTargetType.mealSave,
    );
    expect(restored.appVersion, '1.3.2+16');
    expect(restored.platform, 'ios');
    expect(restored.context['recognition_mode'], 'kf2');
    expect(restored.context['recognition_duration_ms'], 4321);
  });

  test('versioned queue survives a storage recreation', () async {
    final first = FeedbackQueueStorage(prefs);
    await first.enqueue(_item(id: 'event-1', now: now), now);
    final afterRestart = FeedbackQueueStorage(
      await SharedPreferences.getInstance(),
    );
    final restored = await afterRestart.read();
    expect(restored.single.eventId, 'event-1');
    expect(restored.single.targetRef.serverId, isNotNull);
  });

  test('TTL prunes items at 30 days and max size retains newest 100', () async {
    final storage = FeedbackQueueStorage(prefs);
    await storage.enqueue(
      _item(id: 'expired', now: now.subtract(const Duration(days: 30))),
      now.subtract(const Duration(days: 30)),
    );
    for (var i = 0; i < 101; i++) {
      await storage.enqueue(_item(id: 'event-$i', now: now), now);
    }
    final items = await storage.read();
    expect(items, hasLength(100));
    expect(items.any((item) => item.eventId == 'expired'), isFalse);
    expect(items.any((item) => item.eventId == 'event-0'), isFalse);
    expect(items.last.eventId, 'event-100');
  });

  test('retry preserves event_id across restart and schedules later', () async {
    final storage = FeedbackQueueStorage(prefs);
    await storage.enqueue(_item(id: 'stable-id', now: now), now);
    final repository = _FakeRepository([
      const FeedbackDeliveryResult(FeedbackDeliveryKind.retryable),
    ]);
    final coordinator = FeedbackCoordinator(
      storage: storage,
      repository: repository,
      analytics: _Analytics(),
      clock: () => now,
      random: Random(1),
    );
    await coordinator.flush('owner-a');
    final restored = await FeedbackQueueStorage(
      await SharedPreferences.getInstance(),
    ).read();
    expect(repository.eventIds, ['stable-id']);
    expect(restored.single.eventId, 'stable-id');
    expect(restored.single.attemptCount, 1);
    expect(restored.single.nextAttemptAt.isAfter(now), isTrue);
  });

  test('parallel flush triggers share one in-flight cycle', () async {
    final storage = FeedbackQueueStorage(prefs);
    await storage.enqueue(_item(id: 'one', now: now), now);
    final repository = _FakeRepository([
      const FeedbackDeliveryResult(FeedbackDeliveryKind.success),
    ]);
    final coordinator = FeedbackCoordinator(
      storage: storage,
      repository: repository,
      analytics: _Analytics(),
      clock: () => now,
    );
    final first = coordinator.flush('owner-a');
    final second = coordinator.flush('owner-a');
    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    expect(repository.calls, 1);
  });

  test('FIFO due batch is capped at 20', () async {
    final storage = FeedbackQueueStorage(prefs);
    for (var i = 0; i < 25; i++) {
      await storage.enqueue(_item(id: 'event-$i', now: now), now);
    }
    final repository = _FakeRepository(
      List.generate(
        20,
        (_) => const FeedbackDeliveryResult(FeedbackDeliveryKind.success),
      ),
    );
    final coordinator = FeedbackCoordinator(
      storage: storage,
      repository: repository,
      analytics: _Analytics(),
      clock: () => now,
    );
    await coordinator.flush('owner-a');
    expect(repository.eventIds, List.generate(20, (i) => 'event-$i'));
    expect(await storage.read(), hasLength(5));
  });

  test('account mismatch quarantines without sending', () async {
    final storage = FeedbackQueueStorage(prefs);
    await storage.enqueue(_item(id: 'private', now: now), now);
    final repository = _FakeRepository([]);
    final coordinator = FeedbackCoordinator(
      storage: storage,
      repository: repository,
      analytics: _Analytics(),
      clock: () => now,
    );
    await coordinator.flush('owner-b');
    expect(repository.calls, 0);
    expect(await storage.read(), hasLength(1));
  });

  test(
    'pre-auth onboarding resolution binds owner then flushes after restart',
    () async {
      final storage = FeedbackQueueStorage(
        prefs,
        capabilityStorage: _MemoryCapabilities(),
      );
      await storage.enqueue(
        _item(
          id: 'pre-auth-event',
          now: now,
          owner: '',
          serverId: null,
          pendingId: 'pending-submission',
        ).copyWith(ownerBinding: ''),
        now,
      );
      final firstRepository = _FakeRepository([]);
      final first = FeedbackCoordinator(
        storage: storage,
        repository: firstRepository,
        analytics: _Analytics(),
        clock: () => now,
      );
      await first.resolveOnboardingTarget(
        pendingSubmissionId: 'pending-submission',
        serverId: '22222222-2222-4222-8222-222222222222',
        ownerBinding: 'bound-owner',
      );

      final repository = _FakeRepository([
        const FeedbackDeliveryResult(FeedbackDeliveryKind.success),
      ]);
      final afterRestart = FeedbackCoordinator(
        storage: FeedbackQueueStorage(await SharedPreferences.getInstance()),
        repository: repository,
        analytics: _Analytics(),
        clock: () => now,
      );
      await afterRestart.flush('bound-owner');
      expect(repository.eventIds, ['pre-auth-event']);
      expect(await storage.read(), isEmpty);
    },
  );

  test(
    'anonymous onboarding capability is delivered before authentication',
    () async {
      final storage = FeedbackQueueStorage(
        prefs,
        capabilityStorage: _MemoryCapabilities(),
      );
      await storage.enqueue(
        PendingFeedback(
          eventId: 'anonymous-event',
          targetRef: const FeedbackTargetRef(
            type: FeedbackTargetType.onboardingPlan,
            serverId: '22222222-2222-4222-8222-222222222222',
            feedbackCapability: 'opaque-capability',
          ),
          request: const FeedbackRequest(
            rating: FeedbackRating.like,
            source: FeedbackSource.onboarding,
          ),
          createdAt: now,
          nextAttemptAt: now,
        ),
        now,
      );
      final repository = _FakeRepository([
        const FeedbackDeliveryResult(FeedbackDeliveryKind.success),
      ]);
      final coordinator = FeedbackCoordinator(
        storage: storage,
        repository: repository,
        analytics: _Analytics(),
        clock: () => now,
      );

      await coordinator.flushAnonymous();

      expect(repository.eventIds, ['anonymous-event']);
      expect(await storage.read(), isEmpty);
    },
  );

  test(
    'analytics queue payload contains only the exact safe allowlist',
    () async {
      final storage = FeedbackQueueStorage(prefs);
      await storage.enqueue(_item(id: 'secret-event-id', now: now), now);
      final analytics = _Analytics();
      final coordinator = FeedbackCoordinator(
        storage: storage,
        repository: _FakeRepository([
          const FeedbackDeliveryResult(
            FeedbackDeliveryKind.permanent,
            statusCode: 422,
          ),
        ]),
        analytics: analytics,
        clock: () => now,
      );
      await coordinator.flush('owner-a');
      expect(
        analytics.events.single.keys,
        unorderedEquals(['result', 'target_type', 'http_class']),
      );
      final encoded = analytics.events.single.toString();
      expect(encoded, isNot(contains('secret-event-id')));
      expect(encoded, isNot(contains('comment')));
      expect(encoded, isNot(contains('reason')));
    },
  );

  test('repository classifies every backend response family', () {
    expect(
      FeedbackRepository.classify(401, null).kind,
      FeedbackDeliveryKind.unauthorized,
    );
    for (final status in [400, 404, 409, 413, 422]) {
      expect(
        FeedbackRepository.classify(status, null).kind,
        FeedbackDeliveryKind.permanent,
      );
    }
    for (final status in <int?>[null, 408, 425, 429, 500, 503]) {
      expect(
        FeedbackRepository.classify(status, null).kind,
        FeedbackDeliveryKind.retryable,
      );
    }
    final limited = FeedbackRepository.classify(
      429,
      Headers.fromMap({
        'retry-after': ['90'],
      }),
    );
    expect(limited.retryAfter, const Duration(seconds: 90));
  });

  test('401 retains current and later items and stops the cycle', () async {
    final storage = FeedbackQueueStorage(prefs);
    await storage.enqueue(_item(id: 'first', now: now), now);
    await storage.enqueue(_item(id: 'second', now: now), now);
    final repository = _FakeRepository([
      const FeedbackDeliveryResult(FeedbackDeliveryKind.unauthorized),
    ]);
    final coordinator = FeedbackCoordinator(
      storage: storage,
      repository: repository,
      analytics: _Analytics(),
      clock: () => now,
    );
    await coordinator.flush('owner-a');
    expect(repository.eventIds, ['first']);
    expect(await storage.read(), hasLength(2));
  });
}
