import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<Locale> {
  static const _key = 'app_locale';
  static const _explicitKey = 'app_locale_user_set';
  static const _supportedCodes = {'ru', 'en'};

  // Product default: every fresh install starts in English. The device locale
  // must not silently switch onboarding to Russian; RU is applied only after
  // an explicit user choice persisted under [_explicitKey].
  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userSet = prefs.getBool(_explicitKey) ?? false;
    final code = prefs.getString(_key);

    if (userSet && code != null && _supportedCodes.contains(code)) {
      state = Locale(code);
    }
    // Otherwise keep the product default (English).
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
    await prefs.setBool(_explicitKey, true);
  }
}
