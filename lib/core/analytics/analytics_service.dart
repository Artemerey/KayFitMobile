import 'package:firebase_analytics/firebase_analytics.dart';

/// Central Firebase Analytics service.
/// Tracks every user interaction in the app.
class AnalyticsService {
  AnalyticsService._();

  static final _fa = FirebaseAnalytics.instance;

  // ─── Init ─────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    await _fa.setAnalyticsCollectionEnabled(true);
  }

  static FirebaseAnalyticsObserver get routeObserver =>
      FirebaseAnalyticsObserver(analytics: _fa);

  // ─── User identity ────────────────────────────────────────────────────────

  static Future<void> setUserId(String userId) async {
    await _fa.setUserId(id: userId);
  }

  static Future<void> setUserProfile({
    String? name,
    String? email,
    String? language,
    int? age,
    String? gender,
    bool? hasSubscription,
  }) async {
    if (language != null) await _fa.setUserProperty(name: 'language', value: language);
    if (gender != null) await _fa.setUserProperty(name: 'gender', value: gender.toLowerCase());
    if (age != null) await _fa.setUserProperty(name: 'age_group', value: _ageGroup(age));
    if (hasSubscription != null) {
      await _fa.setUserProperty(name: 'has_subscription', value: hasSubscription ? 'true' : 'false');
    }
  }

  // ─── Generic tap tracker ──────────────────────────────────────────────────

  /// Universal button/tap tracker. Use this for every interactive element.
  static void tap(String screen, String element, [Map<String, Object>? params]) {
    _event('tap', {'screen': screen, 'element': element, ...?params});
  }

  /// Track screen view manually (supplement to automatic observer)
  static void screenView(String screenName) {
    _fa.logScreenView(screenName: screenName);
  }

  // ─── Navigation ──────────────────────────────────────────────────────────

  static void navTab(String tab) => _event('nav_tab', {'tab': tab});

  // ─── Auth ─────────────────────────────────────────────────────────────────

  static void loginPageOpened() => _event('login_page_opened');
  static void loginMethodSelected(String method) => _event('login_method_selected', {'method': method});
  static void loginAttempted(String method) => _event('login_attempted', {'method': method});
  static void loginSuccess(String method) => _fa.logLogin(loginMethod: method);
  static void loginFailed(String method, String reason) => _event('login_failed', {'method': method, 'reason': reason});

  static void registerPageOpened() => _event('register_page_opened');
  static void registerAttempted() => _event('register_attempted');
  static void registerSuccess() => _fa.logSignUp(signUpMethod: 'email');
  static void registerFailed(String reason) => _event('register_failed', {'reason': reason});

  static void authTabSwitched(String tab) => _event('auth_tab_switched', {'tab': tab}); // login/register
  static void passwordVisibilityToggled() => _event('password_visibility_toggled');
  static void loggedOut() => _event('logged_out');
  static void deleteAccountTapped() => _event('delete_account_tapped');
  static void deleteAccountConfirmed() => _event('delete_account_confirmed');
  static void deleteAccountCancelled() => _event('delete_account_cancelled');

  static void langSelected(String lang, String source) =>
      _event('lang_selected', {'lang': lang, 'source': source});

  // ─── Onboarding ──────────────────────────────────────────────────────────

  static void onboardingStarted() => _event('onboarding_started');
  static void onboardingStepViewed(String step, [int stepNumber = 0]) =>
      _event('onboarding_step_viewed', {'step': step, 'step_number': stepNumber});
  static void onboardingStepCompleted(String step, [Map<String, Object>? params]) =>
      _event('onboarding_step_completed', {'step': step, ...?params});
  static void onboardingStepCompletedWithData(String step, Map<String, Object> data) =>
      _event('onboarding_step_completed', {'step': step, ...data});
  static void onboardingCompleted() => _fa.logTutorialComplete();
  static void onboardingBackTapped(String step) => _event('onboarding_back', {'step': step});
  static void onboardingAgeSelected(int age) => _event('onboarding_age_selected', {'age': age});
  static void onboardingHeightEntered(int height) => _event('onboarding_height_entered', {'height': height});
  static void onboardingGenderSelected(String gender) => _event('onboarding_gender_selected', {'gender': gender});
  static void onboardingWeightEntered(int current, int target) =>
      _event('onboarding_weight_entered', {'current': current, 'target': target});
  static void onboardingTrainingDaysSelected(int days) =>
      _event('onboarding_training_days', {'days': days});
  static void onboardingMethodSelected(String method) =>
      _event('onboarding_method_selected', {'method': method}); // photo/voice/text
  static void onboardingGoToLogin() => _event('onboarding_go_to_login');

  // ─── Dashboard ────────────────────────────────────────────────────────────

  static void dashboardOpened() => _event('dashboard_opened');
  static void dashboardRefreshed() => _event('dashboard_refreshed');
  static void dashboardPersonalPlanTapped() => _event('dashboard_personal_plan_tapped');
  static void dashboardAddMealTapped() => _event('dashboard_add_meal_tapped');

  // ─── Journal ──────────────────────────────────────────────────────────────

  static void journalOpened() => _event('journal_opened');
  static void journalDateChanged(String direction) => _event('journal_date_changed', {'direction': direction}); // prev/next
  static void journalDaySelected(String date) => _event('journal_day_selected', {'date': date});
  static void journalAddMealTapped() => _event('journal_add_meal_tapped');
  static void journalAiBannerTapped() => _event('journal_ai_banner_tapped');
  static void journalMealEditTapped(int mealId) => _event('journal_meal_edit_tapped', {'meal_id': mealId});
  static void journalMealDeleteTapped(int mealId) => _event('journal_meal_delete_tapped', {'meal_id': mealId});
  static void journalMealDeleteConfirmed(int mealId) => _event('journal_meal_delete_confirmed', {'meal_id': mealId});

  // ─── Edit Meal ────────────────────────────────────────────────────────────

  static void editMealOpened(int mealId) => _event('edit_meal_opened', {'meal_id': mealId});
  static void editMealSaved(int mealId) => _event('edit_meal_saved', {'meal_id': mealId});

  // ─── Add Meal Sheet ───────────────────────────────────────────────────────

  static void addMealSheetOpened(String source) => _event('add_meal_sheet_opened', {'source': source}); // dashboard/journal
  static void addMealSheetClosed() => _event('add_meal_sheet_closed');
  static void addMealModeSelected(String mode) => _event('add_meal_mode_selected', {'mode': mode}); // text/voice/photo
  static void addMealTextSubmitted(int charCount) => _event('add_meal_text_submitted', {'char_count': charCount});
  static void addMealVoiceStarted() => _event('add_meal_voice_started');
  static void addMealVoiceStopped(int durationSeconds) => _event('add_meal_voice_stopped', {'duration_s': durationSeconds});
  static void addMealVoiceUploaded() => _event('add_meal_voice_uploaded');
  static void addMealPhotoTaken() => _event('add_meal_photo_taken');
  static void addMealPhotoFromGallery() => _event('add_meal_photo_from_gallery');
  static void addMealPhotoUploaded() => _event('add_meal_photo_uploaded');
  static void addMealSuggestionsReceived(int itemCount, String mode) =>
      _event('add_meal_suggestions_received', {'item_count': itemCount, 'mode': mode});
  static void addMealItemToggled(String itemName, bool selected) =>
      _event('add_meal_item_toggled', {'item_name': itemName, 'selected': selected});
  static void addMealWeightChanged(String itemName, int grams) =>
      _event('add_meal_weight_changed', {'item_name': itemName, 'grams': grams});
  static void addMealEmotionSelected(String emotion) =>
      _event('emotion_selected', {'emotion': emotion});
  static void addMealConfirmed(int itemCount, String mode, int? totalCalories) =>
      _event('meal_saved', {'item_count': itemCount, 'mode': mode, 'total_calories': totalCalories ?? 0});
  static void addMealFailed(String reason) => _event('meal_save_failed', {'reason': reason});

  // ─── Chat ─────────────────────────────────────────────────────────────────

  static void chatOpened() => _event('chat_opened');
  static void chatMessageSent(int messageIndex) => _event('chat_message_sent', {'message_index': messageIndex});
  static void chatResponseReceived(int responseIndex) => _event('chat_response_received', {'response_index': responseIndex});

  // ─── Settings ─────────────────────────────────────────────────────────────

  static void settingsOpened() => _event('settings_opened');
  static void settingsGoalsTapped() => _event('settings_goals_tapped');
  static void settingsLanguageTapped() => _event('settings_language_tapped');
  static void settingsPrivacyTapped() => _event('settings_privacy_tapped');
  static void settingsTermsTapped() => _event('settings_terms_tapped');
  static void settingsLogoutTapped() => _event('settings_logout_tapped');
  static void settingsDeleteAccountTapped() => _event('settings_delete_account_tapped');
  static void languageChanged(String languageCode) {
    _event('language_changed', {'language': languageCode});
    _fa.setUserProperty(name: 'language', value: languageCode);
  }

  // ─── Goals ────────────────────────────────────────────────────────────────

  static void goalsScreenOpened() => _event('goals_screen_opened');
  static void goalsSaved() => _event('goals_saved');

  // ─── Way to Goal ──────────────────────────────────────────────────────────

  static void wayToGoalOpened() => _event('way_to_goal_opened');
  static void wayToGoalStartDiaryTapped() => _event('way_to_goal_start_diary_tapped');

  // ─── AI Consent ───────────────────────────────────────────────────────────

  static void aiConsentScreenOpened() => _event('ai_consent_screen_opened');
  static void aiConsentCheckboxToggled(bool checked) => _event('ai_consent_checkbox_toggled', {'checked': checked ? 1 : 0});
  static void aiConsentAccepted() => _event('ai_consent_accepted');
  static void aiConsentDeclined() => _event('ai_consent_declined');
  static void aiConsentDeclineConfirmed() => _event('ai_consent_decline_confirmed');

  // ─── Notifications ────────────────────────────────────────────────────────

  static void notificationPromoShown() => _event('notification_promo_shown');
  static void notificationPromoAccepted() => _event('notification_promo_accepted');
  static void notificationPromoDismissed() => _event('notification_promo_dismissed');

  // ─── Tariffs / Payments ───────────────────────────────────────────────────

  static void tariffsViewed() => _event('tariffs_viewed');
  static void tariffSelected(String tariffCode, double price) =>
      _event('tariff_selected', {'tariff_code': tariffCode, 'price': price});
  static void subscriptionPurchaseStarted(String tariffCode, double price) {
    _fa.logPurchase(
      currency: 'USD',
      value: price,
      transactionId: '${tariffCode}_${DateTime.now().millisecondsSinceEpoch}',
      items: [AnalyticsEventItem(itemId: tariffCode, itemName: tariffCode, price: price, quantity: 1)],
    );
  }

  // ─── Legacy compat aliases ────────────────────────────────────────────────

  static void mealAddOpened() => addMealSheetOpened('unknown');
  static void mealInputModeSelected(String mode) => addMealModeSelected(mode);
  static void mealVoiceRecordStarted() => addMealVoiceStarted();
  static void mealVoiceRecordStopped(int durationSeconds) => addMealVoiceStopped(durationSeconds);
  static void mealPhotoTaken() => addMealPhotoTaken();
  static void mealParsed(int itemCount, String mode) => addMealSuggestionsReceived(itemCount, mode);
  static void mealSaved({required int itemCount, required String mode, String? emotion, int? totalCalories}) =>
      addMealConfirmed(itemCount, mode, totalCalories);
  static void mealSaveFailed(String reason) => addMealFailed(reason);
  static void emotionSelected(String emotion) => addMealEmotionSelected(emotion);

  // ─── Private ──────────────────────────────────────────────────────────────

  static void _event(String name, [Map<String, Object>? params]) {
    _fa.logEvent(name: name, parameters: params);
  }

  static String _ageGroup(int age) {
    if (age < 18) return '<18';
    if (age < 25) return '18-24';
    if (age < 35) return '25-34';
    if (age < 45) return '35-44';
    if (age < 55) return '45-54';
    return '55+';
  }
}
