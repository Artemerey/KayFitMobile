// Widget smoke tests for KF2-RECOG:
//   - Kf2CaptureScreen
//   - Kf2RecognizingScreen
//
// Strategy: Both screens use ImagePicker / Dio at runtime.  Tests do NOT
// exercise the network or camera — they verify that the widget tree renders
// the expected structural elements (X button, shutter button, gallery icon,
// photo display, progress text) without crashing.
//
// Kf2RecognizingScreen starts a Dio call immediately in initState.  We allow
// it to throw (no server in tests) and drain the exception; the test then
// asserts on the widgets that were rendered before the async failure.
//
// Firebase / Analytics errors are suppressed via FlutterError.onError.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kayfit/features/add_meal/screens/kf2_capture_screen.dart';
import 'package:kayfit/features/add_meal/screens/kf2_recognizing_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Error suppression helpers
// ─────────────────────────────────────────────────────────────────────────────

void Function(FlutterErrorDetails)? _savedHandler;

void _suppressNetworkErrors() {
  _savedHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    // Suppress expected test-environment errors so tests stay green.
    if (msg.contains('Firebase') ||
        msg.contains('firebase') ||
        msg.contains('No Firebase App') ||
        msg.contains('FirebaseException') ||
        msg.contains('DioException') ||
        msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('FlutterImageCompress') ||
        msg.contains('PathNotFoundException') ||
        msg.contains('No such file')) {
      return;
    }
    _savedHandler?.call(details);
  };
}

void _restoreHandler() => FlutterError.onError = _savedHandler;

/// Drain all pending async work and swallow test-environment exceptions.
Future<void> _pumpAndSettle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 60));
  tester.takeException(); // drain any Dio / network exception
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal XFile stand-in (no real file on disk; tests don't need the bytes)
// ─────────────────────────────────────────────────────────────────────────────

XFile _fakeXFile() => XFile('/tmp/kf2_test_photo.jpg');

// ─────────────────────────────────────────────────────────────────────────────
// App wrappers
// ─────────────────────────────────────────────────────────────────────────────

Widget _captureApp() => const ProviderScope(
      child: MaterialApp(home: Kf2CaptureScreen()),
    );

Widget _recognizingApp(XFile photo) => ProviderScope(
      child: MaterialApp(
        home: Kf2RecognizingScreen(photo: photo),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUp(_suppressNetworkErrors);
  tearDown(_restoreHandler);

  // ── 1. Kf2CaptureScreen renders cancel (X) button ──────────────────────────

  group('Kf2CaptureScreen — structure', () {
    testWidgets('renders X (cancel) button', (tester) async {
      await tester.pumpWidget(_captureApp());
      await _pumpAndSettle(tester);

      // The close icon is used for cancel in the top bar.
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    // ── 2. Shutter button ─────────────────────────────────────────────────────

    testWidgets('renders shutter button (white circle)', (tester) async {
      await tester.pumpWidget(_captureApp());
      await _pumpAndSettle(tester);

      // The shutter is a _ShutterButton — a Container with a circle border.
      // We verify at least one Semantics node with label "Take photo" exists.
      final semantics = find.bySemanticsLabel('Take photo');
      expect(semantics, findsOneWidget);
    });

    // ── 3. Gallery icon ───────────────────────────────────────────────────────

    testWidgets('renders gallery icon button', (tester) async {
      await tester.pumpWidget(_captureApp());
      await _pumpAndSettle(tester);

      expect(
        find.byIcon(Icons.photo_library_outlined),
        findsOneWidget,
      );
    });

    // ── 4. PHOTO label shown in top bar ───────────────────────────────────────

    testWidgets('shows PHOTO label in top bar', (tester) async {
      await tester.pumpWidget(_captureApp());
      await _pumpAndSettle(tester);

      expect(find.text('PHOTO'), findsOneWidget);
    });

    // ── 5. Cancel pops navigator ──────────────────────────────────────────────

    testWidgets('tapping X pops the navigator', (tester) async {
      bool popped = false;
      final app = MaterialApp(
        home: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).push(
                      MaterialPageRoute<XFile?>(
                        builder: (_) => const Kf2CaptureScreen(),
                      ),
                    ).then((_) => popped = true);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(ProviderScope(child: app));
      await _pumpAndSettle(tester);

      // Open Kf2CaptureScreen.
      await tester.tap(find.text('open'));
      // Use pump + duration instead of pumpAndSettle: the screen has a
      // repeating AnimationController that would cause pumpAndSettle to
      // time out.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      tester.takeException();

      // Tap X.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      tester.takeException();

      expect(popped, isTrue);
    });
  });

  // ── 6. Kf2RecognizingScreen renders photo + progress text ─────────────────

  group('Kf2RecognizingScreen — structure', () {
    testWidgets('renders "Analyzing your meal" text', (tester) async {
      final photo = _fakeXFile();

      await tester.pumpWidget(_recognizingApp(photo));
      // Single pump only — before the async Dio call can complete.
      await tester.pump();
      tester.takeException();

      expect(find.text('Analyzing your meal…'), findsOneWidget);
    });

    testWidgets('renders "AI is identifying items" subtitle', (tester) async {
      final photo = _fakeXFile();

      await tester.pumpWidget(_recognizingApp(photo));
      await tester.pump();
      tester.takeException();

      expect(find.text('AI is identifying items'), findsOneWidget);
    });

    testWidgets('renders ANALYZING label over the photo area', (tester) async {
      final photo = _fakeXFile();

      await tester.pumpWidget(_recognizingApp(photo));
      await tester.pump();
      tester.takeException();

      expect(find.text('ANALYZING'), findsOneWidget);
    });
  });
}
