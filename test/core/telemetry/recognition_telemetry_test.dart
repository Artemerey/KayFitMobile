import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/telemetry/recognition_flow.dart';
import 'package:kayfit/core/telemetry/meaningful_frame_ack.dart';

void main() {
  test(
    'one flow uses distinct operation ids and privacy-safe wire payloads',
    () {
      final flow = RecognitionFlow.start(mode: RecognitionMode.text);
      final parse = flow.startOperation(RecognitionEndpoint.parse);
      final chat = flow.startOperation(RecognitionEndpoint.chat);
      final save = flow.startOperation(RecognitionEndpoint.save);
      final display = flow.startOperation(RecognitionEndpoint.displayAck);
      final feedback = flow.startOperation(RecognitionEndpoint.feedback);

      expect(
        {
          parse.flowId,
          chat.flowId,
          save.flowId,
          display.flowId,
          feedback.flowId,
        },
        {flow.id},
      );
      expect({parse.id, chat.id, save.id, display.id, feedback.id}.length, 5);
      for (final operation in [parse, chat, save, display, feedback]) {
        final payload = operation.safePayload();
        expect(
          payload.keys,
          everyElement(isIn(RecognitionTelemetry.allowedKeys)),
        );
        expect(payload.toString(), isNot(contains('fixture meal')));
      }
    },
  );

  test('monotonic boundaries include auth refresh and retry counts', () async {
    final flow = RecognitionFlow.start(mode: RecognitionMode.text);
    final operation = flow.startOperation(RecognitionEndpoint.parse);
    operation.markRequestStarted();
    operation.markAuthRefresh();
    operation.markRetry(backoff: const Duration(milliseconds: 25));
    await Future<void>.delayed(const Duration(milliseconds: 1));
    operation.markResponseReceived(cacheOutcome: CacheOutcome.miss);
    operation.markDecoded();

    final payload = operation.safePayload();
    expect(payload['attempt_count'], 2);
    expect(payload['auth_refresh_count'], 1);
    expect(payload['retry_backoff_ms'], 25);
    expect(payload['wire_ms'], isA<int>());
    expect(payload['decode_ms'], isA<int>());
  });

  testWidgets(
    'display acknowledgement fires only after meaningful post-frame render',
    (tester) async {
      var acknowledgements = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MeaningfulFrameAck(
            identity: 'flow-1',
            meaningful: false,
            onRendered: () => acknowledgements++,
            child: const Text('loading'),
          ),
        ),
      );
      await tester.pump();
      expect(acknowledgements, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: MeaningfulFrameAck(
            identity: 'flow-1',
            meaningful: true,
            onRendered: () => acknowledgements++,
            child: const Text('result'),
          ),
        ),
      );
    expect(acknowledgements, 1);
      await tester.pump();
      expect(acknowledgements, 1);
    },
  );

  test('fallback sequence is aggregated without payload', () {
    final flow = RecognitionFlow.start(mode: RecognitionMode.text)
      ..recordEndpoint(RecognitionEndpoint.parse)
      ..recordEndpoint(RecognitionEndpoint.chat);
    expect(flow.feedbackContext()['endpoint_sequence'], 'parse_chat');
    expect(
      flow.feedbackContext().keys,
      everyElement(isIn(RecognitionTelemetry.feedbackContextKeys)),
    );
  });
}
