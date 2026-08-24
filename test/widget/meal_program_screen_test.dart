import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/api/api_client.dart';
import 'package:kayfit/features/meal_program/screens/meal_program_screen.dart';

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? s,
    Future<void>? c,
  ) async {
    if (o.path.endsWith('/api/restriction-tags')) {
      return _json(
        '{"version":"v1","items":[{"id":"nuts","category":"allergen","name_ru":"Орехи","name_en":"Tree nuts","active":true}]}',
        200,
      );
    }
    if (o.path.endsWith('/api/profile/restriction-tags')) {
      return _json(
        '{"tag_ids":[],"source":"structured","legacy_unmapped":false}',
        200,
      );
    }
    return _json(
      '{"detail":{"code":"meal_program_entitlement_required"}}',
      402,
    );
  }

  ResponseBody _json(String body, int status) => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('shows searchable restriction selection and create state', (
    tester,
  ) async {
    apiDio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _Adapter();
    await tester.pumpWidget(
      const MaterialApp(locale: Locale('en'), home: MealProgramScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Search restrictions'), findsOneWidget);
    expect(find.text('Tree nuts'), findsOneWidget);
    expect(find.text('Create program'), findsOneWidget);
    await tester.tap(find.text('Tree nuts'));
    await tester.pump();
    expect(find.byType(Chip), findsWidgets);
  });
}
