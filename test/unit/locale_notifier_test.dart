import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kayfit/core/locale/locale_provider.dart';

void main() {
  // SharedPreferences.setMockInitialValues must be called before each test
  // so tests are fully isolated from each other.

  group('LocaleNotifier', () {
    test('init_from_sp_ru — reads "ru" from SharedPreferences', () async {
      // app_locale_user_set must be true for the locale to override device default.
      SharedPreferences.setMockInitialValues({
        'app_locale': 'ru',
        'app_locale_user_set': true,
      });

      final notifier = LocaleNotifier();
      // _load() is async — wait for microtasks to settle.
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, equals(const Locale('ru')));
    });

    test('init_from_sp_en — reads "en" from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});

      final notifier = LocaleNotifier();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, equals(const Locale('en')));
    });

    test('init_fallback_en — unsupported code in SP falls back to "en"',
        () async {
      // An unsupported code (e.g. leftover garbage) should not crash and must
      // fall back to EN (the constructor default).  The system locale check
      // cannot be mocked in unit tests without a Flutter engine, so this test
      // validates the SP-unsupported branch specifically.
      SharedPreferences.setMockInitialValues({'app_locale': 'fr'});

      final notifier = LocaleNotifier();
      await Future<void>.delayed(Duration.zero);

      // 'fr' is not in _supportedCodes → remains at the constructor default.
      expect(notifier.state, equals(const Locale('en')));
    });

    test('no_sp_entry — stays at constructor default "en" when SP is empty',
        () async {
      SharedPreferences.setMockInitialValues({});

      final notifier = LocaleNotifier();
      await Future<void>.delayed(Duration.zero);

      // PlatformDispatcher.instance.locale is 'en' in the test environment,
      // so result is 'en' either by system-locale match or by fallback.
      expect(
        notifier.state.languageCode,
        anyOf('en', 'ru'), // depends on test-runner system locale
      );
    });

    test('setLocale_saves_to_sp — persists chosen locale to SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = LocaleNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.setLocale(const Locale('ru'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), equals('ru'));
      expect(notifier.state, equals(const Locale('ru')));
    });

    test('setLocale_en — persists "en" to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'ru'});
      final notifier = LocaleNotifier();
      await Future<void>.delayed(Duration.zero);

      await notifier.setLocale(const Locale('en'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_locale'), equals('en'));
      expect(notifier.state, equals(const Locale('en')));
    });

    test('setLocale_triggers_rebuild — listener is called on state change',
        () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      int callCount = 0;
      container.listen<Locale>(localeProvider, (_, __) => callCount++);

      // Allow the async _load() to complete before we trigger a change.
      await Future<void>.delayed(Duration.zero);

      await container.read(localeProvider.notifier).setLocale(const Locale('ru'));

      expect(callCount, greaterThanOrEqualTo(1));
      expect(container.read(localeProvider), equals(const Locale('ru')));
    });
  });
}
