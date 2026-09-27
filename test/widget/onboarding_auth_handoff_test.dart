import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/features/onboarding/widgets/onboarding_auth_handoff.dart';

void main() {
  testWidgets('shows the plan-ready registration handoff in Russian', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: OnboardingAuthHandoff()),
      ),
    );

    expect(
      find.text(
        'Отлично! План готов. Чтобы сохранить его и приступить к цели, зарегистрируйтесь или войдите',
      ),
      findsOneWidget,
    );
  });
}
