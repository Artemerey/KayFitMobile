import 'package:flutter/foundation.dart';

enum MealLogIncidentCode {
  transportTimeout,
  http4xx,
  http5xx,
  invalidAcknowledgment,
  addedZero,
  responseNotRendered,
  routeLifecycleLoss,
  flutterException,
}

@immutable
class MealLogIncident {
  const MealLogIncident({
    required this.eventId,
    required this.source,
    required this.stage,
    required this.errorCode,
    required this.occurredAt,
    required this.localOffsetMinutes,
    required this.reachedBackend,
    required this.attemptNumber,
    this.httpStatus,
    this.platform,
    this.appVersion,
    this.durationMs,
    this.clientOperationId,
    this.correlationId,
    this.runId,
    this.saveOperationId,
    this.retrySucceeded = false,
  });

  final String eventId;
  final String source;
  final String stage;
  final MealLogIncidentCode errorCode;
  final DateTime occurredAt;
  final int localOffsetMinutes;
  final bool reachedBackend;
  final int attemptNumber;
  final int? httpStatus;
  final String? platform,
      appVersion,
      clientOperationId,
      correlationId,
      runId,
      saveOperationId;
  final int? durationMs;
  final bool retrySucceeded;

  String get wireErrorCode => switch (errorCode) {
    MealLogIncidentCode.transportTimeout => 'transport_timeout',
    MealLogIncidentCode.http4xx => 'http_4xx',
    MealLogIncidentCode.http5xx => 'http_5xx',
    MealLogIncidentCode.invalidAcknowledgment => 'invalid_acknowledgment',
    MealLogIncidentCode.addedZero => 'added_zero',
    MealLogIncidentCode.responseNotRendered => 'response_not_rendered',
    MealLogIncidentCode.routeLifecycleLoss => 'route_lifecycle_loss',
    MealLogIncidentCode.flutterException => 'flutter_exception',
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'event_id': eventId,
    'source': source,
    'stage': stage,
    'error_code': wireErrorCode,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'local_offset_minutes': localOffsetMinutes,
    'reached_backend': reachedBackend,
    'attempt_number': attemptNumber,
    'retry_succeeded': retrySucceeded,
    if (httpStatus != null) 'http_status': httpStatus,
    if (platform != null) 'platform': platform,
    if (appVersion != null) 'app_version': appVersion,
    if (durationMs != null) 'duration_ms': durationMs,
    if (clientOperationId != null) 'client_operation_id': clientOperationId,
    if (correlationId != null) 'correlation_id': correlationId,
    if (runId != null) 'run_id': runId,
    if (saveOperationId != null) 'save_operation_id': saveOperationId,
  };

  factory MealLogIncident.fromJson(Map<String, dynamic> json) =>
      MealLogIncident(
        eventId: json['event_id'] as String,
        source: json['source'] as String,
        stage: json['stage'] as String,
        errorCode: MealLogIncidentCode.values.firstWhere(
          (value) => _wire(value) == json['error_code'],
          orElse: () => MealLogIncidentCode.flutterException,
        ),
        occurredAt: DateTime.parse(json['occurred_at'] as String),
        localOffsetMinutes: (json['local_offset_minutes'] as num).toInt(),
        reachedBackend: json['reached_backend'] as bool? ?? false,
        attemptNumber: (json['attempt_number'] as num?)?.toInt() ?? 1,
        retrySucceeded: json['retry_succeeded'] as bool? ?? false,
        httpStatus: (json['http_status'] as num?)?.toInt(),
        platform: json['platform'] as String?,
        appVersion: json['app_version'] as String?,
        durationMs: (json['duration_ms'] as num?)?.toInt(),
        clientOperationId: json['client_operation_id'] as String?,
        correlationId: json['correlation_id'] as String?,
        runId: json['run_id'] as String?,
        saveOperationId: json['save_operation_id'] as String?,
      );

  static String _wire(MealLogIncidentCode value) => MealLogIncident(
    eventId: '',
    source: '',
    stage: '',
    errorCode: value,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(0),
    localOffsetMinutes: 0,
    reachedBackend: false,
    attemptNumber: 1,
  ).wireErrorCode;
}
