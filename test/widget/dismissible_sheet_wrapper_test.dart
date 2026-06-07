import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/shared/widgets/dismissible_sheet_wrapper.dart';

void main() {
  group('DismissibleSheetWrapper', () {
    testWidgets('renders child', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DismissibleSheetWrapper(
              child: Text('content'),
            ),
          ),
        ),
      );

      // Assert
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('shows drag handle when draggable is true', (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DismissibleSheetWrapper(
              draggable: true,
              child: SizedBox(height: 50),
            ),
          ),
        ),
      );

      // Assert: drag handle container exists (36x4)
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dragHandle = containers.where((c) {
        // The drag handle is a Container with width 36 and height 4
        final decorated = c.decoration;
        return decorated != null &&
            c.margin == const EdgeInsets.only(top: 12, bottom: 4);
      });
      expect(dragHandle.isNotEmpty, isTrue);
    });

    testWidgets('does not show drag handle when draggable is false',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DismissibleSheetWrapper(
              draggable: false,
              showCloseButton: false,
              child: SizedBox(height: 50),
            ),
          ),
        ),
      );

      // Assert: no drag handle margin
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dragHandle = containers.where((c) {
        return c.margin == const EdgeInsets.only(top: 12, bottom: 4);
      });
      expect(dragHandle.isEmpty, isTrue);
    });

    testWidgets('shows close button when showCloseButton is true',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DismissibleSheetWrapper(
              showCloseButton: true,
              child: SizedBox(height: 50),
            ),
          ),
        ),
      );

      // Assert: close icon present
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('does not show close button when showCloseButton is false',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DismissibleSheetWrapper(
              showCloseButton: false,
              child: SizedBox(height: 50),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('calls onClose callback when X button tapped', (tester) async {
      // Arrange
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DismissibleSheetWrapper(
              showCloseButton: true,
              onClose: () => closed = true,
              child: const SizedBox(height: 50),
            ),
          ),
        ),
      );

      // Act
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      // Assert
      expect(closed, isTrue);
    });

    testWidgets('closes sheet via Navigator.pop when X tapped and onClose null',
        (tester) async {
      // Arrange
      var sheetVisible = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () {
                  sheetVisible = true;
                  showModalBottomSheet<void>(
                    context: context,
                    isDismissible: true,
                    enableDrag: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const DismissibleSheetWrapper(
                      child: SizedBox(height: 200),
                    ),
                  ).then((_) => sheetVisible = false);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Act: open the sheet
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.byType(DismissibleSheetWrapper), findsOneWidget);
      expect(sheetVisible, isTrue);

      // Act: tap X button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Assert: sheet closed
      expect(find.byType(DismissibleSheetWrapper), findsNothing);
    });

    testWidgets('sheet closes on barrier tap when isDismissible true',
        (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open'),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isDismissible: true,
                    enableDrag: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const DismissibleSheetWrapper(
                      child: SizedBox(height: 200),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Act: open sheet
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.byType(DismissibleSheetWrapper), findsOneWidget);

      // Act: tap barrier (top area outside sheet)
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();

      // Assert: sheet dismissed
      expect(find.byType(DismissibleSheetWrapper), findsNothing);
    });
  });
}
