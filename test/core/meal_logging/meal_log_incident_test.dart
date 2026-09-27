import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kayfit/core/meal_logging/meal_log_incident.dart';
import 'package:kayfit/core/meal_logging/meal_log_incident_reporter.dart';
import 'package:kayfit/core/meal_logging/meal_log_operation_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'KayFit',
      packageName: 'com.kayfit.app',
      version: '1.3.2',
      buildNumber: '16',
      buildSignature: '',
    );
  });

  test(
    'outbox survives recreation and offline incident sends after reconnect',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var online = false;
      final requests = <Map<String, dynamic>>[];
      final dio = Dio()
        ..httpClientAdapter = _Adapter((options) async {
          if (!online) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          requests.add(Map<String, dynamic>.from(options.data as Map));
          return ResponseBody.fromString(
            '{}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final reporter = MealLogIncidentReporter(
        MealLogIncidentStorage(prefs),
        dio,
      );
      await reporter.report(
        source: 'photo',
        stage: 'input_acquired',
        errorCode: MealLogIncidentCode.routeLifecycleLoss,
        clientOperationId: '77777777-7777-4777-8777-777777777777',
      );
      expect(MealLogIncidentStorage(prefs).readAll().single.sent, isFalse);

      online = true;
      final recreated = MealLogIncidentReporter(
        MealLogIncidentStorage(await SharedPreferences.getInstance()),
        dio,
      );
      await recreated.flush();
      expect(recreated.storage.readAll().single.sent, isTrue);
      expect(requests, hasLength(1));
    },
  );

  test(
    'stored payload is allowlisted and contains no raw media or secrets',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final dio = Dio()
        ..httpClientAdapter = _Adapter(
          (_) async => ResponseBody.fromString('{}', 503),
        );
      await MealLogIncidentReporter(MealLogIncidentStorage(prefs), dio).report(
        source: 'voice',
        stage: 'save_started',
        errorCode: MealLogIncidentCode.transportTimeout,
        clientOperationId: '77777777-7777-4777-8777-777777777777',
      );
      final raw = prefs.getString(mealLogIncidentOutboxKey)!;
      for (final forbidden in [
        'audio',
        'image',
        'photo.jpg',
        'raw_ocr',
        'label_values_raw',
        'token',
        'email',
        'secret_url',
        'https://',
        'stack_trace',
        'bearer ',
      ]) {
        expect(raw.toLowerCase(), isNot(contains(forbidden)));
      }
      final decoded = (jsonDecode(raw) as List).single as Map;
      expect(decoded.keys, isNot(contains('payload')));
    },
  );

  test('reporter failure is retained once and does not recurse', () async {
    final prefs = await SharedPreferences.getInstance();
    var calls = 0;
    final dio = Dio()
      ..httpClientAdapter = _Adapter((options) async {
        calls++;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
    await MealLogIncidentReporter(MealLogIncidentStorage(prefs), dio).report(
      source: 'text',
      stage: 'save_started',
      errorCode: MealLogIncidentCode.flutterException,
    );
    expect(calls, 1);
    expect(MealLogIncidentStorage(prefs).readAll(), hasLength(1));
  });

  test('422, 500, timeout and client/render failures remain distinct', () {
    DioException http(int status) => DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: RequestOptions(), statusCode: status),
    );
    expect(classifyMealSaveDioFailure(http(422)), MealLogIncidentCode.http4xx);
    expect(classifyMealSaveDioFailure(http(500)), MealLogIncidentCode.http5xx);
    expect(
      classifyMealSaveDioFailure(
        DioException(
          requestOptions: RequestOptions(),
          type: DioExceptionType.receiveTimeout,
        ),
      ),
      MealLogIncidentCode.transportTimeout,
    );
    expect({
      MealLogIncidentCode.invalidAcknowledgment,
      MealLogIncidentCode.addedZero,
      MealLogIncidentCode.responseNotRendered,
      MealLogIncidentCode.routeLifecycleLoss,
      MealLogIncidentCode.flutterException,
    }, hasLength(5));
  });

  test(
    'client-before-request lifecycle loss is delivered after restart',
    () async {
      final operationId = '77777777-7777-4777-8777-777777777777';
      SharedPreferences.setMockInitialValues({
        'meal_log_operations_v1': jsonEncode([
          {
            'id': operationId,
            'source': 'photo',
            'stage': 'inputAcquired',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
            'meal_ids': <int>[],
          },
        ]),
      });
      final requests = <Map<String, dynamic>>[];
      final dio = Dio()
        ..httpClientAdapter = _Adapter((options) async {
          requests.add(Map<String, dynamic>.from(options.data as Map));
          return ResponseBody.fromString(
            '{}',
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      await MealLogIncidentRuntime.initialize(
        await SharedPreferences.getInstance(),
        dio,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(mealLogOperationProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requests.single['error_code'], 'route_lifecycle_loss');
      expect(requests.single['reached_backend'], isFalse);
    },
  );
}
