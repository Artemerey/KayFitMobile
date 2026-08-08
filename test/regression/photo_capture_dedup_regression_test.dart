import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/chat/providers/photo_recognition_provider.dart';

void main() {
  test('the same captured file is enqueued at most once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(photoRecognitionProvider.notifier);

    notifier.enqueue(XFile('/tmp/capture-first.jpg'), 'ru');
    notifier.enqueue(XFile('/tmp/capture-first.jpg'), 'ru');

    final state = container.read(photoRecognitionProvider);
    expect(state.queuedCount + (state.isAnalyzing ? 1 : 0), 1);
  });
}
