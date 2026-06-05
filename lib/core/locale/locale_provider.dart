import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<Locale> {
  static const _key = 'app_locale';
  static const _explicitKey = 'app_locale_user_set';
  static const _supportedCodes = {'ru', 'en'};

  static Locale _deviceLocale() {
    final lang = PlatformDispatcher.instance.locale.languageCode;
    return _supportedCodes.contains(lang) ? Locale(lang) : const Locale('en');
  }

  LocaleNotifier() : super(_deviceLocale()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userSet = prefs.getBool(_explicitKey) ?? false;
    final code = prefs.getString(_key);

    if (userSet && code != null && _supportedCodes.contains(code)) {
      state = Locale(code);
    }
    // else: keep device locale default
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    await prefs.setBool(_explicitKey, true);
  }
}
