import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/journal/screens/journal_screen.dart';

void main() {
  test('existing program day is synchronized before journal history', () async {
    final calls = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: options.path.endsWith('/current')
                    ? {'id': 'program-1'}
                    : {'days': []},
              ),
            );
          },
        ),
      );

    final outcome = await syncMealProgramDay(date: '2026-08-28', client: dio);

    expect(outcome, MealProgramSyncOutcome.synced);
    expect(calls.map((request) => request.path), [
      '/api/meal-programs/current',
      '/api/meal-programs/program-1/days',
    ]);
    expect(calls.last.queryParameters, {
      'from': '2026-08-28',
      'to': '2026-08-28',
    });
  });

  test('missing program is created and its day is synchronized', () async {
    final calls = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options.path);
            if (options.path.endsWith('/current')) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(requestOptions: options, statusCode: 404),
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: options.method == 'POST'
                      ? {'id': 'created-program'}
                      : {'days': []},
                ),
              );
            }
          },
        ),
      );

    final outcome = await syncMealProgramDay(date: '2026-08-28', client: dio);

    expect(outcome, MealProgramSyncOutcome.synced);
    expect(calls, [
      '/api/meal-programs/current',
      '/api/meal-programs',
      '/api/meal-programs/created-program/days',
    ]);
  });

  test('entitlement response leaves the normal journal usable', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 402),
            ),
          ),
        ),
      );

    expect(
      await syncMealProgramDay(date: '2026-08-28', client: dio),
      MealProgramSyncOutcome.unavailable,
    );
  });
}
