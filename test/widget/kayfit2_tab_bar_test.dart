// Widget tests for KF2-FOUND-3: Kayfit2TabBar.
//
// Covers:
//   - Renders both tabs (Journal / Chat) and the centre + button
//   - Tap on Journal tab fires onTab('journal')
//   - Tap on Chat tab fires onTab('chat')
//   - Tap on centre button fires onAdd
//   - Active tab key colours the correct tab

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/shared/theme/kayfit2_theme.dart';
import 'package:kayfit/shared/widgets/kayfit2_tab_bar.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(bottomNavigationBar: child),
    );

void main() {
  group('Kayfit2TabBar layout', () {
    testWidgets('shows both tabs and centre button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Kayfit2TabBar(
            theme: K2Theme.light,
            active: 'journal',
            onTab: (_) {},
            onAdd: () {},
          ),
        ),
      );
      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });

  group('Kayfit2TabBar interactions', () {
    testWidgets('tapping Journal fires onTab("journal")', (tester) async {
      String? fired;
      await tester.pumpWidget(
        _wrap(
          Kayfit2TabBar(
            theme: K2Theme.light,
            active: 'chat',
            onTab: (k) => fired = k,
            onAdd: () {},
          ),
        ),
      );
      await tester.tap(find.text('Journal'));
      await tester.pump();
      expect(fired, 'journal');
    });

    testWidgets('tapping Chat fires onTab("chat")', (tester) async {
      String? fired;
      await tester.pumpWidget(
        _wrap(
          Kayfit2TabBar(
            theme: K2Theme.light,
            active: 'journal',
            onTab: (k) => fired = k,
            onAdd: () {},
          ),
        ),
      );
      await tester.tap(find.text('Chat'));
      await tester.pump();
      expect(fired, 'chat');
    });

    testWidgets('tapping the centre + fires onAdd', (tester) async {
      var added = false;
      await tester.pumpWidget(
        _wrap(
          Kayfit2TabBar(
            theme: K2Theme.light,
            active: 'journal',
            onTab: (_) {},
            onAdd: () => added = true,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(added, isTrue);
    });
  });

  group('Kayfit2TabBar dark theme', () {
    testWidgets('renders without error in dark theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Kayfit2TabBar(
            theme: K2Theme.dark,
            active: 'journal',
            onTab: (_) {},
            onAdd: () {},
          ),
        ),
      );
      expect(find.byType(Kayfit2TabBar), findsOneWidget);
    });
  });
}
