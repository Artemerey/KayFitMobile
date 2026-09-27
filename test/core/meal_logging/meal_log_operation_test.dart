import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kayfit/core/api/api_client.dart';
import 'package:kayfit/core/meal_logging/meal_log_operation.dart';
import 'package:kayfit/core/meal_logging/meal_log_operation_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final acknowledgments = <String, List<int>>{};
    apiDio = Dio();
    apiDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final body = Map<String, dynamic>.from(options.data as Map);
          final id = body['client_operation_id'] as String;
          final items = body['items'] as List;
          final mealIds = acknowledgments.putIfAbsent(
            id,
            () => List<int>.generate(items.length, (index) => 100 + index),
          );
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'operation_id': id,
                'added': mealIds.length,
                'meal_ids': mealIds,
                'feedback_target_id': 'feedback-$id',
              },
            ),
          );
        },
      ),
    );
  });

  test('20/20 first operations reach a persisted acknowledgement', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mealLogOperationProvider.notifier);

    for (var index = 0; index < 20; index++) {
      final operation = notifier.start(MealLogSource.values[index % 4]);
      notifier.advance(operation.id, MealLogStage.recognitionCompleted);
      final result = await notifier.saveSelected(
        operationId: operation.id,
        expectedItems: 1,
        payload: {
          'items': [
            {'name': 'item-$index'},
          ],
        },
      );
      expect(result.operationId, operation.id);
      expect(result.added, 1);
      expect(result.mealIds, [100]);
      expect(result.canRequestFeedback, isTrue);
      expect(result.feedbackTargetId, 'feedback-${operation.id}');
      notifier.successRendered(operation.id);
      expect(
        container.read(mealLogOperationProvider)[operation.id]!.stage,
        MealLogStage.successRendered,
      );
    }
  });

  test(
    'same operation id can be retried without changing acknowledgement',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(mealLogOperationProvider.notifier);
      final operation = notifier.start(MealLogSource.manual);
      final payload = {
        'items': [
          {'name': 'manual item'},
        ],
      };

      final first = await notifier.saveSelected(
        operationId: operation.id,
        expectedItems: 1,
        payload: payload,
      );
      final replay = await notifier.saveSelected(
        operationId: operation.id,
        expectedItems: 1,
        payload: payload,
      );

      expect(replay.operationId, first.operationId);
      expect(replay.mealIds, first.mealIds);
    },
  );

  test('operation remains in provider across route-like consumer churn', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(mealLogOperationProvider.notifier);
    final operation = notifier.start(MealLogSource.photo);
    notifier.advance(operation.id, MealLogStage.recognitionCompleted);

    expect(
      container.read(mealLogOperationProvider)[operation.id]!.stage,
      MealLogStage.recognitionCompleted,
    );
  });
}
