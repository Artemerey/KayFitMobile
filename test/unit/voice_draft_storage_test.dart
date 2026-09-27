import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/chat/voice/voice_draft_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'confirmed transcript and operation survive lifecycle recreation',
    () async {
      SharedPreferences.setMockInitialValues({});
      const draft = VoiceDraft(
        operationId: 'voice-operation-1',
        committedTranscript: 'каша двести грамм и яблоко',
        inputSource: 'voice',
      );
      await VoiceDraftStorage.save(draft);
      final restored = await VoiceDraftStorage.load();
      expect(restored?.operationId, draft.operationId);
      expect(restored?.committedTranscript, draft.committedTranscript);
      expect(restored?.inputSource, 'voice');
    },
  );

  test(
    'storage contains no raw audio, token, URL or stack trace fields',
    () async {
      SharedPreferences.setMockInitialValues({});
      await VoiceDraftStorage.save(
        const VoiceDraft(
          operationId: 'voice-operation-2',
          committedTranscript: 'рис и курица',
          inputSource: 'voice',
        ),
      );
      final raw = (await SharedPreferences.getInstance()).getString(
        voiceDraftStorageKey,
      )!;
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      expect(
        json.keys,
        unorderedEquals([
          'operation_id',
          'committed_transcript',
          'input_source',
        ]),
      );
      expect(
        raw.toLowerCase(),
        isNot(
          anyOf(
            contains('audio'),
            contains('token'),
            contains('http'),
            contains('stack_trace'),
          ),
        ),
      );
    },
  );
}
