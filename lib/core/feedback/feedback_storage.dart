import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'feedback_models.dart';
import 'feedback_capability_storage.dart';

class FeedbackQueueStorage {
  FeedbackQueueStorage(
    this._preferences, {
    FeedbackCapabilityStorage? capabilityStorage,
  }) : _capabilityStorage =
           capabilityStorage ?? SecureFeedbackCapabilityStorage();

  static const key = 'feedback_queue_v1';
  static const schemaVersion = 1;
  static const maxItems = 100;
  static const ttl = Duration(days: 30);

  final SharedPreferences _preferences;
  final FeedbackCapabilityStorage _capabilityStorage;

  Future<void> rememberCapability(FeedbackTargetRef target) async {
    final id = target.serverId;
    final capability = target.feedbackCapability;
    if (id != null && capability != null) {
      await _capabilityStorage.write(id, capability);
    }
  }

  Future<String?> readCapability(String targetId) =>
      _capabilityStorage.read(targetId);

  Future<List<PendingFeedback>> read() async {
    final raw = _preferences.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['schema_version'] != schemaVersion) return [];
      final items = (decoded['items'] as List<dynamic>)
          .map((item) => PendingFeedback.fromJson(item as Map<String, dynamic>))
          .toList(growable: true);
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final targetId = item.targetRef.serverId;
        if (targetId != null &&
            item.targetRef.type == FeedbackTargetType.onboardingPlan) {
          String? capability;
          try {
            capability = await _capabilityStorage.read(targetId);
          } catch (_) {
            capability = null;
          }
          if (capability != null) {
            items[index] = item.copyWith(
              targetRef: FeedbackTargetRef(
                type: item.targetRef.type,
                serverId: targetId,
                pendingSubmissionId: item.targetRef.pendingSubmissionId,
                feedbackCapability: capability,
              ),
            );
          }
        }
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> write(List<PendingFeedback> items) => _preferences.setString(
    key,
    jsonEncode({
      'schema_version': schemaVersion,
      'items': items.map((item) => item.toJson()).toList(),
    }),
  );

  Future<FeedbackEnqueueResult> enqueue(
    PendingFeedback item,
    DateTime now,
  ) async {
    final targetId = item.targetRef.serverId;
    final capability = item.targetRef.feedbackCapability;
    if (targetId != null && capability != null) {
      await _capabilityStorage.write(targetId, capability);
    }
    final items = await read();
    final expiredTargets = items
        .where((value) => now.difference(value.createdAt) >= ttl)
        .map((value) => value.targetRef.type)
        .toList(growable: false);
    items.removeWhere((value) => now.difference(value.createdAt) >= ttl);
    if (items.any((value) => value.eventId == item.eventId)) {
      await write(items);
      return FeedbackEnqueueResult(expiredTargets: expiredTargets);
    }
    var overflowed = false;
    while (items.length >= maxItems) {
      items.removeAt(0);
      overflowed = true;
    }
    items.add(item);
    await write(items);
    return FeedbackEnqueueResult(
      expiredTargets: expiredTargets,
      overflowed: overflowed,
    );
  }
}

class FeedbackEnqueueResult {
  const FeedbackEnqueueResult({
    this.expiredTargets = const [],
    this.overflowed = false,
  });
  final List<FeedbackTargetType> expiredTargets;
  final bool overflowed;
}
