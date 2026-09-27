import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/shared/widgets/first_meal_celebration.dart';
import 'package:kayfit/shared/widgets/kayfit_brand_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('brand frame keeps the Kayfit wordmark visible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KayfitBrandFrame(child: ColoredBox(color: Colors.white)),
      ),
    );

    expect(find.byKey(const Key('global_kayfit_wordmark')), findsOneWidget);
    expect(find.text('KAYFIT'), findsOneWidget);
  });

  testWidgets('first meal celebration is shown once', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cached_user': '{"id":1,"is_active":true}',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showFirstMealCelebrationIfNeeded(context, eligible: true),
            child: const Text('save'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('save'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('First entry, locked in!'), findsOneWidget);
    expect(find.byKey(const Key('first_meal_confetti')), findsOneWidget);

    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();

    expect(find.text('First entry, locked in!'), findsNothing);
  });

  testWidgets('celebration state is isolated between accounts', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cached_user': '{"id":1,"is_active":true}',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showFirstMealCelebrationIfNeeded(context, eligible: true),
            child: const Text('save'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('save'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', '{"id":2,"is_active":true}');
    await tester.tap(find.text('save'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('First entry, locked in!'), findsOneWidget);
  });
}
