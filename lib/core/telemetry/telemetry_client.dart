import 'dart:async';

import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../feedback/feedback_metadata.dart';
import 'recognition_flow.dart';

void submitRecognitionTelemetry(
  RecognitionOperation operation, {
  String eventType = 'client_completed',
}) {
  final metadata = FeedbackMetadata.current;
  final payload = <String, Object?>{
    ...operation.safePayload(eventType: eventType),
    'release_version': metadata?.releaseVersion,
    'build_number': metadata?.buildNumber,
    'platform': metadata?.platform,
  }..removeWhere((_, value) => value == null);
  unawaited(
    apiDio
        .post<Object?>(
          '/api/v2/telemetry',
          data: payload,
          options: Options(extra: {'skip_recognition_telemetry': true}),
        )
        .catchError(
          (Object _) => Response<Object?>(
            requestOptions: RequestOptions(path: '/api/v2/telemetry'),
          ),
        ),
  );
}
