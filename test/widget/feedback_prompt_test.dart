import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/feedback/feedback_models.dart';
import 'package:kayfit/core/feedback/feedback_prompt.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('like submits explicitly once and shows success', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        FeedbackPrompt(
          targetType: FeedbackTargetType.mealSave,
          onSubmit: (rating, reasons, comment) async {
            calls++;
            expect(rating, FeedbackRating.like);
            expect(reasons, isEmpty);
          },
        ),
      ),
    );
    expect(find.text('Was everything recognized correctly?'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.byTooltip('Yes, correct'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Thank you for your feedback!'), findsOneWidget);
  });

  testWidgets('dismiss does not submit and removes prompt', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        FeedbackPrompt(
          targetType: FeedbackTargetType.mealSave,
          onSubmit: (rating, reasons, comment) async => calls++,
        ),
      ),
    );
    await tester.tap(find.text('Not now'));
    await tester.pump();
    expect(calls, 0);
    expect(find.byKey(const Key('feedback_like')), findsNothing);
  });

  testWidgets('text recognition names the saved chocolate result', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FeedbackPrompt(
          targetType: FeedbackTargetType.mealSave,
          subjectLabel: 'шоколад',
          onSubmit: (rating, reasons, comment) async {},
        ),
        locale: const Locale('ru'),
      ),
    );

    expect(find.text('Правильно распознали шоколад?'), findsOneWidget);
    expect(find.byKey(const Key('feedback_like')), findsOneWidget);
    expect(find.byKey(const Key('feedback_dislike')), findsOneWidget);
  });

  testWidgets('dislike requires a reason and supports RU localization', (
    tester,
  ) async {
    FeedbackReason? submitted;
    await tester.pumpWidget(
      _app(
        FeedbackPrompt(
          targetType: FeedbackTargetType.mealSave,
          onSubmit: (rating, reasons, comment) async =>
              submitted = reasons.single,
        ),
        locale: const Locale('ru'),
      ),
    );
    expect(find.text('Всё распознано верно?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('feedback_dislike')));
    await tester.pumpAndSettle();
    final send = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Отправить отзыв'),
    );
    expect(send.onPressed, isNull);
    await tester.tap(find.byKey(const Key('feedback_reason_wrong_weight')));
    await tester.pump();
    await tester.ensureVisible(find.text('Отправить отзыв'));
    await tester.tap(find.text('Отправить отзыв'));
    await tester.pumpAndSettle();
    expect(submitted, FeedbackReason.wrongWeight);
  });

  testWidgets('rating controls meet 48px touch target and expose tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FeedbackPrompt(
          targetType: FeedbackTargetType.onboardingPlan,
          onSubmit: (rating, reasons, comment) async {},
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('feedback_like'))),
      const Size(48, 48),
    );
    expect(find.byTooltip('Yes, correct'), findsOneWidget);
    expect(find.byTooltip('No, improve it'), findsOneWidget);
  });

  testWidgets(
    'other requires a short explanation and warns against personal data',
    (tester) async {
      String? submittedComment;
      await tester.pumpWidget(
        _app(
          FeedbackPrompt(
            targetType: FeedbackTargetType.onboardingPlan,
            onSubmit: (rating, reasons, comment) async {
              submittedComment = comment;
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('feedback_dislike')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('feedback_reason_other')));
      await tester.pump();

      expect(find.textContaining('personal data'), findsOneWidget);
      final send = find.widgetWithText(FilledButton, 'Send feedback');
      expect(tester.widget<FilledButton>(send).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Wrong meal timing');
      await tester.pump();
      expect(tester.widget<FilledButton>(send).onPressed, isNotNull);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(submittedComment, 'Wrong meal timing');
    },
  );
}
