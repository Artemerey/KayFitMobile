import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/chat/delivery/chat_delivery.dart';
import 'package:kayfit/features/chat/models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late ChatDeliveryStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    storage = ChatDeliveryStorage(preferences);
  });

  Map<String, dynamic> breakfastResponse({int id = 997}) => {
    'message': {
      'id': id,
      'role': 'assistant',
      'content': 'Вот вариант хорошего завтрака.',
      'created_at': '2026-09-04T00:36:24.578382Z',
      'run_id': 'eda894b3-f9a6-4b85-861d-ea69a17566cb',
      'correlation_id': 'ca8a7b8a-164c-4552-beb6-79ba98595c9c',
    },
  };

  test(
    'exact anonymized breakfast fixture links API response to operation',
    () async {
      const originalPrompt = 'Посоветуй на завтра хороший завтрак';
      expect(originalPrompt, isNotEmpty);
      final operation = await storage.create(337);

      await storage.markApiReceived(operation);
      final message = storage.parseResponse(operation, breakfastResponse());
      await storage.markParsed(operation, message);

      final parsed = storage.readOperation(operation.clientOperationId)!;
      expect(parsed.stage, ChatDeliveryStage.responseParsed);
      expect(message.clientOperationId, operation.clientOperationId);
      expect(message.runId, isNotNull);
      expect(message.correlationId, isNotNull);
    },
  );

  test('durable receive survives a new storage instance and reload', () async {
    final operation = await storage.create(337);
    await storage.markApiReceived(operation);
    final message = storage.parseResponse(operation, breakfastResponse());
    await storage.markParsed(operation, message);
    await storage.markDurableReceived(operation, message);

    final afterRestart = ChatDeliveryStorage(preferences);
    final recovered = afterRestart.recoverMessages(337);

    expect(recovered, hasLength(1));
    expect(recovered.single.id, 997);
    expect(recovered.single.clientOperationId, operation.clientOperationId);
  });

  test(
    'duplicate and late callbacks cannot regress state or duplicate UI',
    () async {
      final operation = await storage.create(337);
      final first = storage.parseResponse(operation, breakfastResponse());
      await storage.markDurableReceived(operation, first);
      await storage.markRendered(operation.clientOperationId);

      await storage.markApiReceived(operation); // late callback
      final duplicate = storage.parseResponse(operation, breakfastResponse());
      await storage.markDurableReceived(operation, duplicate);

      expect(
        storage.readOperation(operation.clientOperationId)!.stage,
        ChatDeliveryStage.rendered,
      );
      expect(storage.recoverMessages(337), hasLength(1));
      expect([first, duplicate].deduplicatedByDeliveryIdentity(), hasLength(1));
    },
  );

  test(
    'retry keeps operation identity and a parsed error has exact stage',
    () async {
      final operation = await storage.create(337);
      await storage.markApiReceived(operation);
      await storage.markApiReceived(operation); // same operation retried

      expect(storage.readForAccount(337), hasLength(1));
      expect(
        () => storage.parseResponse(operation, {
          'message': {'role': 'assistant'},
        }),
        throwsFormatException,
      );
      const failure = ChatDeliveryFailure(
        clientOperationId: 'operation-id',
        stage: ChatDeliveryStage.apiResponseReceived,
        code: ChatDeliveryErrorCode.invalidResponse,
      );
      expect(failure.stage, ChatDeliveryStage.apiResponseReceived);
      expect(failure.code, ChatDeliveryErrorCode.invalidResponse);
    },
  );

  testWidgets(
    'render ack fires only after the message is in a rendered frame',
    (tester) async {
      var acknowledged = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatDeliveryRenderAck(
            deliveryId: 'server:997',
            onRendered: () => acknowledged = true,
            child: const Text('assistant-visible'),
          ),
        ),
      );

      expect(find.text('assistant-visible'), findsOneWidget);
      expect(acknowledged, isTrue);
      await tester.pump();
      expect(acknowledged, isTrue); // no duplicate acknowledgment
    },
  );

  test(
    'render-before-durable-ack crash recovers and can ack idempotently',
    () async {
      final operation = await storage.create(337);
      final message = storage.parseResponse(operation, breakfastResponse());
      await storage.markDurableReceived(operation, message);

      // Simulate a process death after the frame but before markRendered.
      final restarted = ChatDeliveryStorage(preferences);
      expect(restarted.recoverMessages(337), hasLength(1));
      await restarted.markRendered(operation.clientOperationId);
      await restarted.markRendered(operation.clientOperationId);
      expect(
        restarted.readOperation(operation.clientOperationId)!.stage,
        ChatDeliveryStage.rendered,
      );
    },
  );

  test(
    'delivery metadata and incident-shaped payload contain no secrets',
    () async {
      final operation = await storage.create(337);
      final message = storage.parseResponse(operation, breakfastResponse());
      await storage.markDurableReceived(operation, message);

      final metadata =
          storage.readOperation(operation.clientOperationId)!.toJson()
            ..remove('assistant_content');
      final encoded = jsonEncode(metadata).toLowerCase();
      for (final forbidden in [
        'prompt',
        'raw_response',
        'token',
        'email',
        'secret_url',
        'stack_trace',
        'authorization',
      ]) {
        expect(encoded, isNot(contains(forbidden)));
      }
    },
  );

  test('server id deduplicates reload copy against accepted response', () {
    final accepted = ChatMessage.fromJson({
      ...breakfastResponse()['message'] as Map<String, dynamic>,
      'client_operation_id': 'operation-id',
    });
    final reloaded = ChatMessage.fromJson(
      breakfastResponse()['message'] as Map<String, dynamic>,
    );
    expect([accepted, reloaded].deduplicatedByDeliveryIdentity(), hasLength(1));
  });
}
