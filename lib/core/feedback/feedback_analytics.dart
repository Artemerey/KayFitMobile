import '../analytics/analytics_service.dart';
import 'feedback_models.dart';

abstract interface class FeedbackAnalytics {
  void promptShown(FeedbackTargetType target, FeedbackSource source);
  void submitted({
    required FeedbackTargetType target,
    required FeedbackSource source,
    required FeedbackRating rating,
    required bool hasReason,
    required bool hasComment,
    required String delivery,
  });
  void queueResult({
    required String result,
    required FeedbackTargetType target,
    required String httpClass,
  });
}

class FirebaseFeedbackAnalytics implements FeedbackAnalytics {
  const FirebaseFeedbackAnalytics();

  @override
  void promptShown(FeedbackTargetType target, FeedbackSource source) =>
      AnalyticsService.feedbackPromptShown(
        targetType: target.apiValue,
        source: source.apiValue,
      );

  @override
  void submitted({
    required FeedbackTargetType target,
    required FeedbackSource source,
    required FeedbackRating rating,
    required bool hasReason,
    required bool hasComment,
    required String delivery,
  }) => AnalyticsService.feedbackSubmitted(
    targetType: target.apiValue,
    source: source.apiValue,
    rating: rating.apiValue,
    hasReason: hasReason,
    hasComment: hasComment,
    delivery: delivery,
  );

  @override
  void queueResult({
    required String result,
    required FeedbackTargetType target,
    required String httpClass,
  }) => AnalyticsService.feedbackQueueResult(
    result: result,
    targetType: target.apiValue,
    httpClass: httpClass,
  );
}
