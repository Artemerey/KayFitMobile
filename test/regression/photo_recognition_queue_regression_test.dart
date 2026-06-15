// Regression test for the multi-photo recognition queue.
//
// Bug: sending several photos one after another froze the first photo's result
// sheet — the "save to journal" and "close" buttons stopped responding. Root
// cause was the result sheet being pushed imperatively over a go_router route,
// desyncing the navigator. The recognition flow was reworked so the provider
// owns a FIFO queue of photos and emits ordered outcomes that the UI drains one
// at a time.
//
// These tests cover the provider-side contract the UI relies on:
//   - enqueue reflects the pending count immediately
//   - photos are processed in order and each yields exactly one outcome
//   - outcomes preserve photo identity and arrive in FIFO order
//   - consumeFirstOutcome drains the oldest outcome only
//   - clear() resets queue + outcomes and invalidates in-flight work
//
// Recognition is exercised against non-existent files, so each photo fails fast
// (no network, no platform channels) and produces a RecogFailure outcome — that
// is enough to assert ordering, identity, and draining.

import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/chat/providers/photo_recognition_provider.dart';

ProviderContainer _container() {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

Future<void> _waitForOutcomes(
  ProviderContainer c,
  int count, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (c.read(photoRecognitionProvider).outcomes.length < count) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $count outcomes '
          '(got ${c.read(photoRecognitionProvider).outcomes.length})');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoRecognitionNotifier queue', () {
    test('initial state is idle with no queue and no outcomes', () {
      final c = _container();
      final s = c.read(photoRecognitionProvider);
      expect(s.isAnalyzing, isFalse);
      expect(s.queuedCount, 0);
      expect(s.outcomes, isEmpty);
    });

    test('enqueue reflects pending photos immediately', () {
      final c = _container();
      final n = c.read(photoRecognitionProvider.notifier);
      n.enqueue(XFile('/nonexistent/a.jpg'), 'en');
      n.enqueue(XFile('/nonexistent/b.jpg'), 'en');
      // The first photo is pulled into flight synchronously; the rest queue.
      final s = c.read(photoRecognitionProvider);
      expect(s.queuedCount, 1);
      expect(s.isAnalyzing, isTrue);
    });

    test('photos yield one outcome each, in FIFO order, keyed by path',
        () async {
      final c = _container();
      final n = c.read(photoRecognitionProvider.notifier);
      n.enqueue(XFile('/nonexistent/first.jpg'), 'en');
      n.enqueue(XFile('/nonexistent/second.jpg'), 'ru');

      await _waitForOutcomes(c, 2);

      final outcomes = c.read(photoRecognitionProvider).outcomes;
      expect(outcomes.length, 2);
      expect(outcomes[0].photoPath, '/nonexistent/first.jpg');
      expect(outcomes[1].photoPath, '/nonexistent/second.jpg');
      expect(outcomes[1].langCode, 'ru');
      // No network / not real food → failure outcomes, never silently dropped.
      expect(outcomes.every((o) => o is RecogFailure), isTrue);
      // Queue drained, nothing left analyzing.
      expect(c.read(photoRecognitionProvider).isAnalyzing, isFalse);
      expect(c.read(photoRecognitionProvider).queuedCount, 0);
    });

    test('consumeFirstOutcome removes only the oldest outcome', () async {
      final c = _container();
      final n = c.read(photoRecognitionProvider.notifier);
      n.enqueue(XFile('/nonexistent/one.jpg'), 'en');
      n.enqueue(XFile('/nonexistent/two.jpg'), 'en');
      await _waitForOutcomes(c, 2);

      n.consumeFirstOutcome();
      final after = c.read(photoRecognitionProvider).outcomes;
      expect(after.length, 1);
      expect(after.single.photoPath, '/nonexistent/two.jpg');

      n.consumeFirstOutcome();
      expect(c.read(photoRecognitionProvider).outcomes, isEmpty);
      // Draining past empty is a safe no-op.
      n.consumeFirstOutcome();
      expect(c.read(photoRecognitionProvider).outcomes, isEmpty);
    });

    test('clear resets queue and outcomes', () async {
      final c = _container();
      final n = c.read(photoRecognitionProvider.notifier);
      n.enqueue(XFile('/nonexistent/x.jpg'), 'en');
      await _waitForOutcomes(c, 1);

      n.clear();
      final s = c.read(photoRecognitionProvider);
      expect(s.outcomes, isEmpty);
      expect(s.queuedCount, 0);
      expect(s.isAnalyzing, isFalse);
    });
  });
}
