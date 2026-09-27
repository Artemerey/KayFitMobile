import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/shared/widgets/kayfit_brand_frame.dart';

void main() {
  testWidgets('global wordmark explicitly suppresses inherited decoration', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: KayfitBrandFrame(child: SizedBox())),
    );

    final wordmark = tester.widget<Text>(
      find.byKey(const Key('global_kayfit_wordmark')),
    );
    expect(wordmark.style?.decoration, TextDecoration.none);
    expect(wordmark.style?.decorationColor, Colors.transparent);
  });
}
