import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../feedback/meal_save_result.dart';
import '../feedback/secure_uuid.dart';
import 'meal_log_operation.dart';
import 'meal_log_incident.dart';
import 'meal_log_incident_reporter.dart';
import '../telemetry/recognition_flow.dart';
import '../telemetry/telemetry_client.dart';

const _storageKey = 'meal_log_operations_v1';

MealLogIncidentCode classifyMealSaveDioFailure(DioException error) {
  final status = error.response?.statusCode;
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => MealLogIncidentCode.transportTimeout,
    _ when status != null && status >= 500 => MealLogIncidentCode.http5xx,
    _ when status != null && status >= 400 => MealLogIncidentCode.http4xx,
    _ => MealLogIncidentCode.flutterException,
  };
}

class MealLogOperationNotifier extends Notifier<Map<String, MealLogOperation>> {
  @override
  Map<String, MealLogOperation> build() {
    unawaited(_restore());
    return const {};
  }

  Future<void> _restore() async {
    final raw = (await SharedPreferences.getInstance()).getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List;
      final restored = <String, MealLogOperation>{};
      for (final value in decoded.whereType<Map>()) {
        final operation = MealLogOperation.fromJson(
          Map<String, dynamic>.from(value),
        );
        restored[operation.id] = operation;
      }
      state = {...restored, ...state};
      for (final operation in restored.values.where(
        (value) => !value.isTerminal,
      )) {
        if (operation.stage == MealLogStage.savePersisted) {
          await reportResponseNotRendered(operation.id);
        } else {
          await reportLifecycleLoss(operation.id);
        }
      }
    } on Object {
      // Invalid local metadata must not prevent a new meal from being saved.
    }
  }

  MealLogOperation start(MealLogSource source) {
    final operation = MealLogOperation(
      id: SecureUuid.v4(),
      source: source,
      stage: MealLogStage.inputStarted,
      updatedAt: DateTime.now().toUtc(),
    );
    _put(operation);
    return operation;
  }

  MealLogOperation resumeOrCreate(String id, MealLogSource source) {
    final existing = state[id];
    if (existing != null) return existing;
    final operation = MealLogOperation(
      id: id,
      source: source,
      stage: MealLogStage.inputAcquired,
      updatedAt: DateTime.now().toUtc(),
    );
    _put(operation);
    return operation;
  }

  void advance(String id, MealLogStage stage) {
    final current = state[id];
    if (current != null) _put(current.advance(stage));
  }

  Future<MealSaveResult> saveSelected({
    required String operationId,
    required Map<String, Object?> payload,
    required int expectedItems,
  }) async {
    final current = state[operationId];
    if (current == null) {
      throw StateError('Unknown meal log operation');
    }
    _put(current.advance(MealLogStage.saveStarted));
    final startedAt = DateTime.now();
    final flowId = payload['client_flow_id'] as String?;
    final telemetryOperation = flowId == null
        ? null
        : RecognitionOperation.forExisting(
            flowId: flowId,
            operationId: operationId,
            endpoint: RecognitionEndpoint.save,
          );
    telemetryOperation?.markRequestStarted();
    try {
      final response = await apiDio.post(
        '/api/meals/add_selected',
        data: {
          ...payload,
          'source': current.source.name,
          'client_operation_id': operationId,
        },
      );
      _put(state[operationId]!.advance(MealLogStage.saveResponseReceived));
      final result = MealSaveResult.fromJson(response.data);
      telemetryOperation?.markResponseReceived();
      telemetryOperation?.markDecoded();
      if (telemetryOperation != null) {
        submitRecognitionTelemetry(telemetryOperation);
      }
      if (expectedItems > 0 && result.added == 0) {
        await _reportFailure(
          current,
          MealLogIncidentCode.addedZero,
          stage: 'save_response_received',
          reachedBackend: true,
          httpStatus: response.statusCode,
          durationMs: DateTime.now().difference(startedAt).inMilliseconds,
          saveOperationId: result.operationId,
        );
        throw const FormatException('Meal save acknowledgment added=0');
      }
      if (result.operationId != operationId ||
          result.added != expectedItems ||
          result.mealIds.length != expectedItems) {
        await _reportFailure(
          current,
          MealLogIncidentCode.invalidAcknowledgment,
          stage: 'save_response_received',
          reachedBackend: true,
          httpStatus: response.statusCode,
          durationMs: DateTime.now().difference(startedAt).inMilliseconds,
          saveOperationId: result.operationId,
        );
        throw const FormatException('Incomplete meal save acknowledgment');
      }
      _put(
        state[operationId]!.advance(
          MealLogStage.savePersisted,
          added: result.added,
          mealIds: result.mealIds,
        ),
      );
      return result;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final code = classifyMealSaveDioFailure(error);
      await _reportFailure(
        current,
        code,
        stage: 'save_started',
        reachedBackend: status != null,
        httpStatus: status,
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
      _put(
        state[operationId]!.advance(MealLogStage.failed, errorCode: code.name),
      );
      rethrow;
    } on FormatException catch (error) {
      // The precise acknowledgment incident was persisted above.
      _put(
        state[operationId]!.advance(
          MealLogStage.failed,
          errorCode: error.runtimeType.toString(),
        ),
      );
      rethrow;
    } on Object catch (error) {
      await _reportFailure(
        current,
        MealLogIncidentCode.flutterException,
        stage: 'save_started',
        durationMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
      _put(
        state[operationId]!.advance(
          MealLogStage.failed,
          errorCode: error.runtimeType.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> _reportFailure(
    MealLogOperation operation,
    MealLogIncidentCode code, {
    required String stage,
    bool reachedBackend = false,
    int? httpStatus,
    int? durationMs,
    String? saveOperationId,
  }) async {
    await MealLogIncidentRuntime.reporter?.report(
      source: operation.source.name,
      stage: stage,
      errorCode: code,
      clientOperationId: operation.id,
      saveOperationId: saveOperationId,
      reachedBackend: reachedBackend,
      httpStatus: httpStatus,
      durationMs: durationMs,
    );
  }

  Future<void> reportResponseNotRendered(String id) async {
    final operation = state[id];
    if (operation == null || operation.stage != MealLogStage.savePersisted) {
      return;
    }
    await _reportFailure(
      operation,
      MealLogIncidentCode.responseNotRendered,
      stage: 'save_persisted',
      reachedBackend: true,
      saveOperationId: operation.id,
    );
    _put(
      operation.advance(
        MealLogStage.failed,
        errorCode: 'response_not_rendered',
      ),
    );
  }

  Future<void> reportLifecycleLoss(String id) async {
    final operation = state[id];
    if (operation == null || operation.isTerminal) return;
    await _reportFailure(
      operation,
      MealLogIncidentCode.routeLifecycleLoss,
      stage: operation.stage.name,
      reachedBackend:
          operation.stage.index >= MealLogStage.saveResponseReceived.index,
    );
    _put(
      operation.advance(MealLogStage.failed, errorCode: 'route_lifecycle_loss'),
    );
  }

  void successRendered(String id) => advance(id, MealLogStage.successRendered);

  void _put(MealLogOperation operation) {
    state = {...state, operation.id: operation};
    unawaited(_persist());
  }

  Future<void> _persist() async {
    final values = state.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final retained = values.take(50).map((value) => value.toJson()).toList();
    await (await SharedPreferences.getInstance()).setString(
      _storageKey,
      jsonEncode(retained),
    );
  }
}

final mealLogOperationProvider =
    NotifierProvider<MealLogOperationNotifier, Map<String, MealLogOperation>>(
      MealLogOperationNotifier.new,
    );
