import 'dart:async';

import 'package:flutter/material.dart';

import 'feedback_analytics.dart';
import 'feedback_coordinator.dart';
import 'feedback_models.dart';
import 'feedback_metadata.dart';
import 'feedback_prompt.dart';

Future<void> showMealFeedbackPrompt({
  required BuildContext context,
  required String targetId,
  required FeedbackSource source,
  required int userId,
  String? subjectLabel,
  Map<String, Object> aggregateContext = const {},
}) async {
  final coordinator = FeedbackRuntime.coordinator;
  final owner = FeedbackRuntime.ownerBindingForUser(userId);
  if (coordinator == null || owner == null || !context.mounted) return;

  const analytics = FirebaseFeedbackAnalytics();
  analytics.promptShown(FeedbackTargetType.mealSave, source);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(20),
      child: FeedbackPrompt(
        targetType: FeedbackTargetType.mealSave,
        subjectLabel: subjectLabel,
        onDismiss: () => Navigator.of(sheetContext).pop(),
        onSubmit: (rating, reasons, comment) async {
          await coordinator.enqueue(
            target: FeedbackTargetRef(
              type: FeedbackTargetType.mealSave,
              serverId: targetId,
            ),
            request: FeedbackRequest(
              rating: rating,
              source: source,
              reasons: reasons,
              comment: comment,
              context: aggregateContext,
              locale: Localizations.localeOf(sheetContext).toLanguageTag(),
              appVersion: FeedbackMetadata.current?.appVersion,
              platform: FeedbackMetadata.current?.platform,
            ),
            ownerBinding: owner,
          );
          analytics.submitted(
            target: FeedbackTargetType.mealSave,
            source: source,
            rating: rating,
            hasReason: reasons.isNotEmpty,
            hasComment: comment != null,
            delivery: 'queued',
          );
          unawaited(coordinator.flush(owner));
        },
      ),
    ),
  );
}

void popThenShowMealFeedbackPrompt({
  required BuildContext context,
  required String targetId,
  required FeedbackSource source,
  required int userId,
  String? subjectLabel,
  Map<String, Object> aggregateContext = const {},
  Object? popResult = true,
}) {
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  Navigator.of(context).pop(popResult);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      showMealFeedbackPrompt(
        context: rootNavigator.context,
        targetId: targetId,
        source: source,
        userId: userId,
        subjectLabel: subjectLabel,
        aggregateContext: aggregateContext,
      ),
    );
  });
}
