import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/core/auth/onboarding_sync.dart';
import 'package:kayfit/core/storage/onboarding_pending_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'PUT sends only IDs and pending clears after both requests succeed',
    () async {
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
                  data: options.path.endsWith('/submit')
                      ? {'submission_id': 'server-id'}
                      : {
                          'tag_ids': ['gluten', 'nuts'],
                        },
                ),
              );
            },
          ),
        );
      await OnboardingPendingStorage.save(
        const OnboardingPendingData(
          age: 30,
          restrictionTagIds: ['gluten', 'nuts'],
        ),
      );

      await syncOnboardingPending(client: dio);

      expect(calls.map((call) => call.path), [
        '/api/onboarding/submit',
        '/api/profile/restriction-tags',
      ]);
      expect(calls.last.data, {
        'tag_ids': ['gluten', 'nuts'],
      });
      expect(await OnboardingPendingStorage.read(), isNull);
    },
  );

  test(
    'failed restriction PUT keeps the same IDs and stable submission ID',
    () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path.endsWith('/restriction-tags')) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 422,
                    ),
                  ),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {'submission_id': 'server-id'},
                  ),
                );
              }
            },
          ),
        );
      await OnboardingPendingStorage.save(
        const OnboardingPendingData(restrictionTagIds: ['dairy', 'soy']),
      );
      final before = await OnboardingPendingStorage.read();

      await syncOnboardingPending(client: dio);
      final after = await OnboardingPendingStorage.read();

      expect(after?.restrictionTagIds, ['dairy', 'soy']);
      expect(after?.submissionId, before?.submissionId);
    },
  );
}
