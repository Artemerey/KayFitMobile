import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/feedback/feedback_models.dart';
import 'package:kayfit/core/feedback/recognition_feedback_bar.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';

void main() {
  testWidgets('recognition result exposes inline thumbs before save', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RecognitionFeedbackBar(
            source: FeedbackSource.photo,
            userId: 7,
            margin: EdgeInsets.zero,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('recognition_feedback_bar')), findsOneWidget);
    expect(
      find.byKey(const Key('recognition_feedback_dislike')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recognition_feedback_like')), findsOneWidget);
    expect(find.text('Was everything recognized correctly?'), findsNothing);

    final size = tester.getSize(
      find.byKey(const Key('recognition_feedback_bar')),
    );
    expect(size.width, lessThanOrEqualTo(70));
    expect(size.height, lessThanOrEqualTo(30));

    await tester.tap(find.byKey(const Key('recognition_feedback_like')));
    await tester.pumpAndSettle();

    final like = tester.widget<IconButton>(
      find.byKey(const Key('recognition_feedback_like')),
    );
    final dislike = tester.widget<IconButton>(
      find.byKey(const Key('recognition_feedback_dislike')),
    );
    expect(like.onPressed, isNull);
    expect(dislike.onPressed, isNull);
    expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });
}
