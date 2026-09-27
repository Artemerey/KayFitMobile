import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/chat/voice/voice_request.dart';

void main() {
  test('send before final callback still carries voice input source', () {
    final payload = mealParseRequestData(
      text: 'рис двести грамм',
      language: 'ru',
      voiceProvenance: true,
    );
    expect(payload['input_source'], 'voice');
    expect(payload['is_voice'], isTrue);
  });

  test('typed text remains explicitly text', () {
    final payload = mealParseRequestData(
      text: 'рис',
      language: 'ru',
      voiceProvenance: false,
    );
    expect(payload['input_source'], 'text');
    expect(payload['is_voice'], isFalse);
  });
}
