// Regression test: BUG-R-VOICE — voice transcription result must survive
// ChatV2Screen dispose (user navigating away during HTTP /api/transcribe call).
//
// Previously: if the user navigated away while the transcription HTTP request
// was in-flight, the result was silently discarded behind a !mounted guard.
// Fix: result is stored in transcriptionPendingProvider (not autoDispose),
//      and ChatV2Screen reads it on mount to pre-fill the text input.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/chat/providers/transcription_pending_provider.dart';

void main() {
  group('BUG-R-VOICE — transcriptionPendingProvider', () {
    test('starts as null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(transcriptionPendingProvider), isNull);
    });

    test('stores transcription result when user navigates away', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate: HTTP call completed while screen was not mounted
      container.read(transcriptionPendingProvider.notifier).state =
          'Привет, добавь 100 граммов овсянки';

      expect(
        container.read(transcriptionPendingProvider),
        equals('Привет, добавь 100 граммов овсянки'),
      );
    });

    test('can be cleared after consumption on screen mount', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(transcriptionPendingProvider.notifier).state = 'test';

      // Simulate: ChatV2Screen.initState reads and clears the pending result
      final pending = container.read(transcriptionPendingProvider);
      expect(pending, equals('test'));
      container.read(transcriptionPendingProvider.notifier).state = null;

      expect(container.read(transcriptionPendingProvider), isNull);
    });

    test('survives provider re-reads (not autoDispose)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(transcriptionPendingProvider.notifier).state = 'kept';
      // Multiple reads — should not be cleared automatically
      container.read(transcriptionPendingProvider);
      container.read(transcriptionPendingProvider);

      expect(container.read(transcriptionPendingProvider), equals('kept'));
    });
  });
}
