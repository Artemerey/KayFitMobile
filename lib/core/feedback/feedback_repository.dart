import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'feedback_models.dart';

enum FeedbackDeliveryKind { success, unauthorized, retryable, permanent }

class FeedbackDeliveryResult {
  const FeedbackDeliveryResult(this.kind, {this.statusCode, this.retryAfter});
  final FeedbackDeliveryKind kind;
  final int? statusCode;
  final Duration? retryAfter;
}

class FeedbackRepository {
  const FeedbackRepository(this._dio);
  final Dio _dio;

  Future<FeedbackTargetRef> createMealRecognitionTarget(
    FeedbackSource source,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/feedback/meal-target',
      data: {'source': source.apiValue},
    );
    final targetId = response.data?['feedback_target_id'] as String?;
    if (targetId == null || targetId.isEmpty) {
      throw StateError('Meal feedback target response is incomplete');
    }
    return FeedbackTargetRef(
      type: FeedbackTargetType.mealSave,
      serverId: targetId,
    );
  }

  Future<FeedbackTargetRef> createAnonymousOnboardingTarget(
    String submissionId,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/onboarding/feedback-target',
      data: {'submission_id': submissionId},
    );
    final data = response.data;
    final targetId = data?['feedback_target_id'] as String?;
    final capability = data?['feedback_capability'] as String?;
    if (targetId == null || capability == null) {
      throw StateError('Anonymous feedback target response is incomplete');
    }
    return FeedbackTargetRef(
      type: FeedbackTargetType.onboardingPlan,
      serverId: targetId,
      pendingSubmissionId: submissionId,
      feedbackCapability: capability,
    );
  }

  Future<FeedbackDeliveryResult> submit(PendingFeedback item) async {
    final targetId = item.targetRef.serverId;
    if (targetId == null) {
      return const FeedbackDeliveryResult(FeedbackDeliveryKind.retryable);
    }
    try {
      final anonymous = item.targetRef.canSubmitAnonymously;
      final response = await _dio.post<Object?>(
        anonymous ? '/api/feedback/anonymous' : '/api/feedback',
        data: {
          'event_id': item.eventId,
          'target_type': item.targetRef.type.apiValue,
          'target_id': targetId,
          if (anonymous)
            'feedback_capability': item.targetRef.feedbackCapability,
          ...item.request.toJson(),
        },
      );
      final status = response.statusCode;
      if (status == 200 || status == 201) {
        return FeedbackDeliveryResult(
          FeedbackDeliveryKind.success,
          statusCode: status,
        );
      }
      return classify(status, response.headers, anonymous: anonymous);
    } on DioException catch (error) {
      return classify(
        error.response?.statusCode,
        error.response?.headers,
        anonymous: item.targetRef.canSubmitAnonymously,
      );
    } catch (_) {
      return const FeedbackDeliveryResult(FeedbackDeliveryKind.retryable);
    }
  }

  @visibleForTesting
  static FeedbackDeliveryResult classify(
    int? status,
    Headers? headers, {
    bool anonymous = false,
  }) {
    if (status == 401) {
      return FeedbackDeliveryResult(
        anonymous
            ? FeedbackDeliveryKind.permanent
            : FeedbackDeliveryKind.unauthorized,
        statusCode: status,
      );
    }
    if (status == null ||
        status == 408 ||
        status == 425 ||
        status == 429 ||
        status >= 500) {
      return FeedbackDeliveryResult(
        FeedbackDeliveryKind.retryable,
        statusCode: status,
        retryAfter: _retryAfter(headers),
      );
    }
    if (status >= 400 && status < 500) {
      return FeedbackDeliveryResult(
        FeedbackDeliveryKind.permanent,
        statusCode: status,
      );
    }
    return FeedbackDeliveryResult(
      FeedbackDeliveryKind.retryable,
      statusCode: status,
    );
  }

  static Duration? _retryAfter(Headers? headers) {
    final raw = headers?.value('retry-after');
    final seconds = raw == null ? null : int.tryParse(raw);
    return seconds == null ? null : Duration(seconds: seconds.clamp(1, 86400));
  }
}
