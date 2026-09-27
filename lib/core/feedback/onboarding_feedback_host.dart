import 'dart:async';

import 'package:flutter/material.dart';

import '../storage/onboarding_pending_storage.dart';
import 'feedback_analytics.dart';
import 'feedback_coordinator.dart';
import 'feedback_models.dart';
import 'feedback_metadata.dart';
import 'feedback_prompt.dart';
import 'feedback_repository.dart';

class OnboardingFeedbackHost extends StatefulWidget {
  const OnboardingFeedbackHost({super.key, this.userId});

  final int? userId;

  @override
  State<OnboardingFeedbackHost> createState() => _OnboardingFeedbackHostState();
}

class _OnboardingFeedbackHostState extends State<OnboardingFeedbackHost> {
  late final Future<FeedbackTargetRef?> _target = _loadTarget();
  bool _promptLogged = false;

  Future<FeedbackTargetRef?> _loadTarget() async {
    final pending = await OnboardingPendingStorage.read();
    final pendingId = pending?.submissionId;
    final coordinator = FeedbackRuntime.coordinator;
    if (widget.userId == null && pendingId != null && coordinator != null) {
      final existingTarget = pending?.feedbackTargetId;
      if (existingTarget != null) {
        final restored = await coordinator.restoreAnonymousOnboardingTarget(
          submissionId: pendingId,
          targetId: existingTarget,
        );
        if (restored != null) return restored;
      }
      try {
        final created = await coordinator.createAnonymousOnboardingTarget(
          pendingId,
        );
        await OnboardingPendingStorage.saveFeedbackTarget(created.serverId!);
        return created;
      } catch (_) {
        return null;
      }
    }
    final serverId = await OnboardingPendingStorage.readLastServerTarget();
    if (serverId == null) return null;
    return FeedbackTargetRef(
      type: FeedbackTargetType.onboardingPlan,
      serverId: serverId,
      pendingSubmissionId: pendingId,
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FeedbackTargetRef?>(
    future: _target,
    builder: (context, snapshot) {
      final target = snapshot.data;
      final coordinator = FeedbackRuntime.coordinator;
      if (target == null || coordinator == null) return const SizedBox.shrink();
      if (!_promptLogged) {
        _promptLogged = true;
        const FirebaseFeedbackAnalytics().promptShown(
          FeedbackTargetType.onboardingPlan,
          FeedbackSource.onboarding,
        );
      }
      return FeedbackPrompt(
        targetType: FeedbackTargetType.onboardingPlan,
        onSubmit: (rating, reasons, comment) async {
          final userId = widget.userId;
          final owner = userId == null
              ? null
              : FeedbackRuntime.ownerBindingForUser(userId);
          final request = FeedbackRequest(
            rating: rating,
            source: FeedbackSource.onboarding,
            reasons: reasons,
            comment: comment,
            locale: Localizations.localeOf(context).toLanguageTag(),
            appVersion: FeedbackMetadata.current?.appVersion,
            platform: FeedbackMetadata.current?.platform,
          );
          final delivery = owner == null
              ? await coordinator.enqueueAndFlushAnonymous(
                  target: target,
                  request: request,
                )
              : null;
          if (delivery == FeedbackDeliveryKind.permanent) {
            throw StateError('Anonymous feedback capability is invalid');
          }
          if (owner != null) {
            await coordinator.enqueue(
              target: target,
              request: request,
              ownerBinding: owner,
            );
          }
          const FirebaseFeedbackAnalytics().submitted(
            target: FeedbackTargetType.onboardingPlan,
            source: FeedbackSource.onboarding,
            rating: rating,
            hasReason: reasons.isNotEmpty,
            hasComment: comment != null,
            delivery: owner == null ? 'anonymous_queued' : 'queued',
          );
          if (owner != null && target.isResolved) {
            unawaited(coordinator.flush(owner));
          }
        },
      );
    },
  );
}
