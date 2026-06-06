// Regression test: BUG-2 / VOICE-PENDING — addPostFrameCallback restoration pattern
//
// The real ChatV2Screen uses native plugins (record, path_provider,
// permission_handler) that cannot run in the Flutter test harness.  These
// tests exercise the *pattern* used by ChatV2Screen.initState to restore a
// transcription result that landed while the screen was disposed.
//
// Pattern:
//   1. HTTP /api/transcribe completes while widget is !mounted.
//   2. Result is stored in transcriptionPendingProvider (not autoDispose).
//   3. On next mount, initState schedules an addPostFrameCallback.
//   4. Callback reads the provider, populates TextEditingController, clears provider.
//
// A regression here would mean the transcription text silently disappears
// every time the user navigates away from chat during a voice recording.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/chat/providers/transcription_pending_provider.dart';

// ── Minimal widget that mirrors ChatV2Screen.initState restoration ────────────

class _RestoreWidget extends ConsumerStatefulWidget {
  const _RestoreWidget({required this.controller});
  final TextEditingController controller;

  @override
  ConsumerState<_RestoreWidget> createState() => _RestoreWidgetState();
}

class _RestoreWidgetState extends ConsumerState<_RestoreWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = ref.read(transcriptionPendingProvider);
      if (pending != null && pending.isNotEmpty) {
        widget.controller.text = pending;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: pending.length),
        );
        ref.read(transcriptionPendingProvider.notifier).state = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      TextField(controller: widget.controller);
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('BUG-2 / VOICE-PENDING — addPostFrameCallback restoration', () {
    testWidgets(
      'text controller is populated from pending provider on mount',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Simulate: transcription completed while screen was unmounted.
        container.read(transcriptionPendingProvider.notifier).state =
            'добавь 200 граммов гречки';

        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: _RestoreWidget(controller: controller)),
            ),
          ),
        );
        await tester.pump(); // flush postFrameCallback

        expect(
          controller.text,
          equals('добавь 200 граммов гречки'),
          reason: 'pending transcription must fill the text field on mount',
        );
      },
    );

    testWidgets(
      'cursor is placed at end of restored text',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        const text = 'овсянка 150 грамм';
        container.read(transcriptionPendingProvider.notifier).state = text;

        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: _RestoreWidget(controller: controller)),
            ),
          ),
        );
        await tester.pump();

        expect(
          controller.selection.baseOffset,
          equals(text.length),
          reason: 'cursor must be at end so the user can immediately send',
        );
      },
    );

    testWidgets(
      'provider is cleared after restore (does not re-populate on rebuild)',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(transcriptionPendingProvider.notifier).state =
            'consumed text';

        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: _RestoreWidget(controller: controller)),
            ),
          ),
        );
        await tester.pump();

        // Provider must be null after consumption.
        expect(
          container.read(transcriptionPendingProvider),
          isNull,
          reason: 'provider must be cleared after restore to prevent '
              're-population on the next mount',
        );
      },
    );

    testWidgets(
      'nothing happens when provider is null (no overwrite of user-typed text)',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Provider is null (no pending transcription).
        final controller = TextEditingController(text: 'already typed');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: _RestoreWidget(controller: controller)),
            ),
          ),
        );
        await tester.pump();

        // Text must be unchanged.
        expect(
          controller.text,
          equals('already typed'),
          reason: 'restoration must not overwrite text when provider is null',
        );
      },
    );

    testWidgets(
      'empty string in provider does not overwrite existing text',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(transcriptionPendingProvider.notifier).state = '';

        final controller = TextEditingController(text: 'user text');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(body: _RestoreWidget(controller: controller)),
            ),
          ),
        );
        await tester.pump();

        expect(
          controller.text,
          equals('user text'),
          reason: 'empty transcription must be treated as no-op',
        );
      },
    );
  });
}
