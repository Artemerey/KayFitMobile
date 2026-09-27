import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feedback/secure_uuid.dart';
import 'meal_log_incident.dart';

const mealLogIncidentOutboxKey = 'meal_log_incident_outbox_v1';
const _mealLogIncidentAckKey = 'meal_log_incident_outbox_acks_v1';

class MealLogIncidentEnvelope {
  const MealLogIncidentEnvelope(this.incident, {this.sent = false});
  final MealLogIncident incident;
  final bool sent;
  Map<String, Object?> toJson() => {...incident.toJson(), '_sent': sent};
  factory MealLogIncidentEnvelope.fromJson(Map<String, dynamic> json) =>
      MealLogIncidentEnvelope(
        MealLogIncident.fromJson(json),
        sent: json['_sent'] as bool? ?? false,
      );
}

class MealLogIncidentStorage {
  MealLogIncidentStorage(this.preferences);
  final SharedPreferences preferences;

  List<MealLogIncidentEnvelope> readAll() {
    final raw = preferences.getString(mealLogIncidentOutboxKey);
    if (raw == null) return const [];
    try {
      final acknowledgments =
          preferences.getStringList(_mealLogIncidentAckKey)?.toSet() ??
          const <String>{};
      return (jsonDecode(raw) as List).whereType<Map>().map((value) {
        final envelope = MealLogIncidentEnvelope.fromJson(
          Map<String, dynamic>.from(value),
        );
        return MealLogIncidentEnvelope(
          envelope.incident,
          sent:
              envelope.sent ||
              acknowledgments.contains(envelope.incident.eventId),
        );
      }).toList();
    } on Object {
      return const [];
    }
  }

  Future<void> append(MealLogIncident incident) async {
    final values = readAll();
    if (values.any((value) => value.incident.eventId == incident.eventId)) {
      return;
    }
    await preferences.setString(
      mealLogIncidentOutboxKey,
      jsonEncode(
        [
          ...values,
          MealLogIncidentEnvelope(incident),
        ].map((e) => e.toJson()).toList(),
      ),
    );
  }

  Future<void> markSent(String eventId) async {
    final values =
        preferences.getStringList(_mealLogIncidentAckKey)?.toSet() ??
        <String>{};
    values.add(eventId);
    await preferences.setStringList(
      _mealLogIncidentAckKey,
      values.toList(growable: false),
    );
  }
}

class MealLogIncidentReporter {
  MealLogIncidentReporter(
    this.storage,
    this.dio, {
    this.scheduleRetries = false,
  });
  final MealLogIncidentStorage storage;
  final Dio dio;
  final bool scheduleRetries;
  bool _reporting = false;
  Timer? _retryTimer;
  int _retryDelaySeconds = 5;

  Future<void> report({
    required String source,
    required String stage,
    required MealLogIncidentCode errorCode,
    String? clientOperationId,
    String? correlationId,
    String? runId,
    String? saveOperationId,
    int? httpStatus,
    int? durationMs,
    bool reachedBackend = false,
    int attemptNumber = 1,
  }) async {
    if (_reporting) return; // Reporter failures must never report themselves.
    final now = DateTime.now();
    final eventId = SecureUuid.v4();
    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } on Object {
      // Optional metadata must never prevent durable incident persistence.
    }
    final event = MealLogIncident(
      eventId: eventId,
      source: source,
      stage: stage,
      errorCode: errorCode,
      occurredAt: now.toUtc(),
      localOffsetMinutes: now.timeZoneOffset.inMinutes,
      reachedBackend: reachedBackend,
      attemptNumber: attemptNumber,
      httpStatus: httpStatus,
      durationMs: durationMs,
      platform: Platform.operatingSystem,
      appVersion: appVersion,
      clientOperationId: clientOperationId,
      correlationId: correlationId,
      runId: runId,
      saveOperationId: saveOperationId,
    );
    await storage.append(event); // Durable before the first network attempt.
    await flush();
  }

  Future<void> flush() async {
    if (_reporting) return;
    _reporting = true;
    try {
      for (final envelope in storage.readAll().where((value) => !value.sent)) {
        try {
          final response = await dio.post(
            '/api/meal-log-incidents',
            data: envelope.incident.toJson(),
          );
          if (response.statusCode == 200) {
            await storage.markSent(envelope.incident.eventId);
          }
        } on Object {
          // Remains durable for app restart, foreground resume, or explicit retry.
          _scheduleRetry();
        }
      }
    } finally {
      _reporting = false;
    }
  }

  void _scheduleRetry() {
    if (!scheduleRetries || _retryTimer?.isActive == true) return;
    final delay = _retryDelaySeconds;
    _retryDelaySeconds = (_retryDelaySeconds * 2).clamp(5, 300);
    _retryTimer = Timer(Duration(seconds: delay), () => unawaited(flush()));
  }
}

class MealLogIncidentRuntime {
  static MealLogIncidentReporter? reporter;
  static Future<void> initialize(SharedPreferences preferences, Dio dio) async {
    reporter = MealLogIncidentReporter(
      MealLogIncidentStorage(preferences),
      dio,
      scheduleRetries: true,
    );
    await reporter!.flush();
  }
}
