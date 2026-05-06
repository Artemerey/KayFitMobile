// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Kayfit';

  @override
  String get nav_today => 'Today';

  @override
  String get nav_journal => 'Journal';

  @override
  String get nav_settings => 'Settings';

  @override
  String get common_save => 'Save';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_edit => 'Edit';

  @override
  String get meal_details_full => 'Full Details';

  @override
  String get common_loading => 'Loading...';

  @override
  String get common_error => 'Error';

  @override
  String get common_retry => 'Retry';

  @override
  String get common_next => 'Next';

  @override
  String get common_back => 'Back';

  @override
  String get common_done => 'Done';

  @override
  String get common_skip => 'Skip';

  @override
  String get common_stop => 'Stop';

  @override
  String get macro_calories => 'Calories';

  @override
  String get macro_protein => 'Protein';

  @override
  String get macro_fat => 'Fat';

  @override
  String get macro_carbs => 'Carbs';

  @override
  String get macro_kcal => 'kcal';

  @override
  String get macro_g => 'g';

  @override
  String get macro_eaten => 'eaten';

  @override
  String get macro_remaining => 'remaining';

  @override
  String get macro_goal => 'goal';

  @override
  String get dashboard_title => 'Today';

  @override
  String get dashboard_addMeal => 'Add meal';

  @override
  String get dashboard_noMeals => 'No entries for today';

  @override
  String get dashboard_personal_plan_title => 'Your personal plan';

  @override
  String dashboard_personal_plan_sub(int kcal) {
    return 'Goal: $kcal kcal/day · Tap to view';
  }

  @override
  String dashboard_compulsive(int count) {
    return 'Compulsive meals: $count';
  }

  @override
  String get journal_title => 'Journal';

  @override
  String get journal_empty => 'History is empty';

  @override
  String get journal_ai_banner_title => 'AI Nutritionist';

  @override
  String get journal_ai_banner_sub =>
      'Will help choose meals and calculate daily macros';

  @override
  String get journal_ai_banner_btn => 'Ask';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_profile => 'Profile';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_subscription => 'Subscription';

  @override
  String get settings_logout => 'Log out';

  @override
  String get settings_langRu => 'Russian';

  @override
  String get settings_langEn => 'English';

  @override
  String get settings_goals => 'Macro goals';

  @override
  String get addMeal_title => 'Add meal';

  @override
  String get addMeal_text => 'Text';

  @override
  String get addMeal_voice => 'Voice';

  @override
  String get addMeal_photo => 'Photo';

  @override
  String get addMeal_manual => 'Manual';

  @override
  String get addMeal_emotionTitle => 'How do you feel?';

  @override
  String get addMeal_inputHint => 'Describe what you ate...';

  @override
  String get addMeal_parsing => 'Recognizing...';

  @override
  String get addMeal_selectItems => 'Select items';

  @override
  String get addMeal_add => 'Add';

  @override
  String get addMeal_recording => 'Recording...';

  @override
  String get addMeal_stopRecording => 'Stop';

  @override
  String get addMeal_transcribing => 'Transcribing...';

  @override
  String get addMeal_takePhoto => 'Take photo';

  @override
  String get addMeal_choosePhoto => 'Choose from gallery';

  @override
  String get addMeal_recognizing => 'Recognizing...';

  @override
  String meal_calories(double cal) {
    final intl.NumberFormat calNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String calString = calNumberFormat.format(cal);

    return '$calString kcal';
  }

  @override
  String meal_macros(double p, double f, double c) {
    return 'P: ${p}g  F: ${f}g  C: ${c}g';
  }

  @override
  String get emotion_happy => 'Happy';

  @override
  String get emotion_calm => 'Calm';

  @override
  String get emotion_sad => 'Sad';

  @override
  String get emotion_anxious => 'Anxious';

  @override
  String get emotion_tired => 'Tired';

  @override
  String get emotion_hungry => 'Hungry';

  @override
  String get emotion_bored => 'Bored';

  @override
  String get emotion_angry => 'Angry';

  @override
  String get emotion_worried => 'Worried';

  @override
  String get emotion_neutral => 'Neutral';

  @override
  String get emotion_other => 'Other';

  @override
  String get ob_landing_title1 => 'Lose weight';

  @override
  String get ob_landing_title2 => 'easily';

  @override
  String get ob_landing_sub => 'Photo or voice — AI counts your calories';

  @override
  String get ob_landing_cta => 'Try now';

  @override
  String get ob_landing_cta_sub1 => 'Personal plan';

  @override
  String get ob_landing_cta_sub2 => 'in under a minute';

  @override
  String get ob_skip_btn => 'Skip';

  @override
  String get ob_skip_title => 'Skip this step?';

  @override
  String get ob_skip_sub =>
      'Without this data the calculation will be less precise.';

  @override
  String get ob_skip_continue => 'Continue without data';

  @override
  String get ob_skip_back => 'Go back';

  @override
  String get ob_step_age_title => 'Your age?';

  @override
  String get ob_step_age_hint =>
      'Age affects your basal metabolic rate calculation';

  @override
  String get ob_step_height_title => 'Your height?';

  @override
  String get ob_step_height_hint =>
      'Height helps calculate your basal metabolic rate';

  @override
  String get ob_step_height_unit => 'centimeters';

  @override
  String get ob_step_gender_title => 'Your gender?';

  @override
  String get ob_step_gender_hint => 'Used in the Mifflin calorie formula';

  @override
  String get ob_step_gender_female => 'Female';

  @override
  String get ob_step_gender_male => 'Male';

  @override
  String get ob_step_weight_title => 'Your weight?';

  @override
  String get ob_step_weight_hint =>
      'Current and target weight for calorie deficit calculation';

  @override
  String get ob_step_weight_now => 'Current';

  @override
  String get ob_step_weight_goal => 'Goal';

  @override
  String get ob_step_training_title => 'How many days a week do you train?';

  @override
  String get ob_step_training_sub =>
      'This helps calculate your daily activity more precisely';

  @override
  String get ob_training_0 => 'I don\'t train';

  @override
  String get ob_training_1_2 => '1–2 days';

  @override
  String get ob_training_3_4 => '3–4 days';

  @override
  String get ob_training_daily => 'Every day';

  @override
  String get ob_method_title => 'How to add food?';

  @override
  String get ob_method_sub =>
      'Choose your preferred way — AI recognizes macros';

  @override
  String get ob_method_photo_title => 'Food photo';

  @override
  String get ob_method_photo_desc =>
      'Snap a photo — AI identifies nutrients in 5 sec';

  @override
  String get ob_method_voice_title => 'Voice';

  @override
  String get ob_method_voice_desc => 'Say \'I ate soup 300ml\' — done';

  @override
  String get ob_method_text_title => 'Text';

  @override
  String get ob_method_text_desc =>
      'Write what you ate — AI calculates calories';

  @override
  String get ob_method_note => 'All methods work fast and accurately';

  @override
  String get ob_demo_perks_title => 'What you get with Kayfit:';

  @override
  String get ob_demo_perk1 => 'Food photo → AI recognizes macros';

  @override
  String get ob_demo_perk2 => 'Voice: \'Ate soup\' — that\'s it';

  @override
  String get ob_demo_perk3 => 'Nutrition history and progress';

  @override
  String get ob_demo_perk4 => 'AI nutrition recommendations';

  @override
  String get ob_result_title => 'Your personal plan';

  @override
  String get ob_result_sub => 'Calculated based on your profile';

  @override
  String get ob_result_kcalday => 'kcal/day';

  @override
  String get ob_result_accuracy => 'AI-assisted estimation';

  @override
  String get ob_result_next_title => 'Next step';

  @override
  String get ob_result_next_text =>
      'Sign in to save your plan and start tracking nutrition.';

  @override
  String get ob_err_height => 'Enter a valid height (100–250 cm)';

  @override
  String get ob_err_weight => 'Enter a valid weight (30–300 kg)';

  @override
  String get ob_err_target_weight => 'Enter target weight (30–300 kg)';

  @override
  String get ob_err_training => 'Select at least one option';

  @override
  String get ob_footer_saving => 'Saving...';

  @override
  String get ob_footer_calc => 'Calculate plan';

  @override
  String get ob_footer_great => 'Great!';

  @override
  String get ob_footer_login => 'Sign in and save plan';

  @override
  String get ob_continue => 'Continue';

  @override
  String get ob_getStarted => 'Get started';

  @override
  String get ob_already_account => 'Already have an account? Sign in';

  @override
  String get ob_weight_unit => 'kg';

  @override
  String get ob_method_recording => 'Recording… Tap again to stop';

  @override
  String get ob_method_text_hint => 'E.g.: oatmeal 200g, chicken breast 150g';

  @override
  String get ob_method_recognize => 'Recognize';

  @override
  String get ob_method_recognized => 'Recognized:';

  @override
  String get ob_method_reset => 'Reset';

  @override
  String get ob_method_mic_denied => 'Microphone access denied';

  @override
  String get ob_method_ai_success =>
      'AI recognized everything! Tap \"Next\" to continue.';

  @override
  String ob_method_kcal(String cal) {
    return '$cal kcal';
  }

  @override
  String ob_method_macros(String p, String f, String c) {
    return 'P$p F$f C$c';
  }

  @override
  String get ob_recognizing_voice => 'Recognizing voice…';

  @override
  String get ob_recognizing_photo => 'Analyzing photo…';

  @override
  String get auth_title => 'Sign in to Kayfit';

  @override
  String get auth_subtitle => 'Choose a sign-in method';

  @override
  String get auth_google => 'Sign in with Google';

  @override
  String get auth_apple => 'Sign in with Apple';

  @override
  String get auth_telegram => 'Sign in with Telegram';

  @override
  String get auth_email => 'Sign in with Email';

  @override
  String get auth_terms => 'By continuing you agree to the terms of service';

  @override
  String get tariffs_title => 'Plans';

  @override
  String get tariffs_subscribe => 'Subscribe';

  @override
  String get tariffs_current => 'Current plan';

  @override
  String get tariffs_free => 'Free';

  @override
  String get tariffs_perMonth => '/ month';

  @override
  String get tariffs_cancel => 'Cancel auto-renewal';

  @override
  String get tariffs_cancelConfirm =>
      'Are you sure you want to cancel auto-renewal?';

  @override
  String get wg_title => 'Calculate your path to goal';

  @override
  String get wg_sub => 'Enter your data to calculate calories and macros';

  @override
  String get wg_age => 'Age (years)';

  @override
  String get wg_weight => 'Current weight (kg)';

  @override
  String get wg_height => 'Height (cm)';

  @override
  String get wg_target_weight => 'Target weight (kg, optional)';

  @override
  String get wg_deficit => 'Deficit mode';

  @override
  String get wg_deficit_active => 'Active (-600 kcal)';

  @override
  String get wg_deficit_gentle => 'Gentle (-300 kcal)';

  @override
  String get wg_btn_next => 'Next';

  @override
  String get wg_btn_calculating => 'Calculating...';

  @override
  String get wg_err_fill => 'Fill in age, weight and height';

  @override
  String get wg_err_data => 'Check your data for correctness';

  @override
  String get wg_result_title => 'Your path to goal';

  @override
  String get wg_result_reach => 'You will reach your goal by';

  @override
  String get wg_result_target_weight => 'Target weight';

  @override
  String get wg_result_kg => 'kg';

  @override
  String get wg_result_bmr => 'BMR (basal metabolic rate):';

  @override
  String get wg_result_tdee => 'TDEE (total daily energy expenditure):';

  @override
  String get wg_result_days => 'Days to goal:';

  @override
  String get wg_result_kcal_day => 'kcal/day';

  @override
  String get wg_btn_start => 'Start tracking';

  @override
  String get error_network => 'No server connection';

  @override
  String get error_auth => 'Authentication error';

  @override
  String get error_unknown => 'Something went wrong';

  @override
  String get subscription_title => 'Subscription';

  @override
  String get subscription_none => 'You have no active subscription';

  @override
  String get subscription_view_tariffs => 'View plans';

  @override
  String get subscription_active => 'Active subscription';

  @override
  String get subscription_expires => 'Valid until';

  @override
  String get subscription_amount => 'Amount';

  @override
  String get subscription_auto_renew => 'Auto-renewal';

  @override
  String get subscription_auto_renew_on => 'Enabled';

  @override
  String get subscription_auto_renew_off => 'Disabled';

  @override
  String get subscription_cancel_auto_renew => 'Cancel auto-renewal';

  @override
  String get subscription_cancel_auto_renew_title => 'Cancel auto-renewal';

  @override
  String get subscription_cancel_auto_renew_confirm =>
      'Are you sure you want to cancel subscription auto-renewal?';

  @override
  String get subscription_cancel_auto_renew_action => 'Cancel';

  @override
  String get subscription_auto_renew_cancelled => 'Auto-renewal cancelled';

  @override
  String get wg_plan_ready => 'Your plan is ready!';

  @override
  String get wg_personal_calc => 'Personal calculation based on your data';

  @override
  String get wg_kcal_day => 'kcal / day';

  @override
  String get wg_macronutrients => 'Macronutrients';

  @override
  String wg_days_to_goal(int days) {
    return 'Days to goal: $days';
  }

  @override
  String wg_target_weight_val(String kg) {
    return 'Target weight: $kg kg';
  }

  @override
  String get wg_weight_forecast => 'Weight forecast';

  @override
  String get wg_how_to_reach => 'How to reach your goal';

  @override
  String get wg_feature_photo_title => 'Food photo';

  @override
  String get wg_feature_photo_desc =>
      'Take a photo — AI recognizes calories in seconds';

  @override
  String get wg_feature_voice_title => 'Voice input';

  @override
  String get wg_feature_voice_desc =>
      'Dictate what you ate — the app will record it';

  @override
  String get wg_feature_track_title => 'Progress tracking';

  @override
  String get wg_feature_track_desc =>
      'Track your macros and see results every day';

  @override
  String get wg_start_diary => 'Start your food diary';

  @override
  String get wg_now => 'now';

  @override
  String get auth_email_login_title => 'Email login';

  @override
  String get auth_register_title => 'Registration';

  @override
  String get auth_login_subtitle => 'Sign in to your Kayfit account';

  @override
  String get auth_register_subtitle => 'Create an account to get started';

  @override
  String get auth_tab_login => 'Login';

  @override
  String get auth_tab_register => 'Register';

  @override
  String get auth_field_password => 'Password';

  @override
  String get auth_field_name => 'Name (optional)';

  @override
  String get auth_field_confirm_password => 'Confirm password';

  @override
  String get auth_btn_login => 'Sign in';

  @override
  String get auth_btn_register => 'Create account';

  @override
  String get auth_err_enter_password => 'Enter password';

  @override
  String get auth_err_min_password => 'Minimum 8 characters';

  @override
  String get auth_err_confirm_password => 'Confirm your password';

  @override
  String get auth_err_passwords_no_match => 'Passwords do not match';

  @override
  String get auth_err_enter_email => 'Enter email';

  @override
  String get auth_err_invalid_email => 'Invalid email';

  @override
  String get auth_err_enter_value => 'Enter a value';

  @override
  String get goals_title => 'Macro goals';

  @override
  String get goals_saved => 'Saved';

  @override
  String goals_error(String msg) {
    return 'Error: $msg';
  }

  @override
  String get goals_err_enter_value => 'Enter a value';

  @override
  String get goals_err_enter_int => 'Enter a whole number';

  @override
  String get dashboard_details => 'Details';

  @override
  String get dashboard_no_goals_title => 'Goals not set';

  @override
  String get dashboard_no_goals_sub =>
      'Complete \"Path to Goal\" to get a personalized nutrition plan';

  @override
  String get dashboard_remaining_title => 'Remaining today';

  @override
  String get dashboard_remaining_over => 'Over limit';

  @override
  String get edit_meal_title => 'Edit meal';

  @override
  String get edit_meal_name_label => 'Name';

  @override
  String get edit_meal_name_error => 'Enter a name';

  @override
  String get edit_meal_saved => 'Saved';

  @override
  String edit_meal_error(String msg) {
    return 'Error: $msg';
  }

  @override
  String get edit_meal_err_enter_value => 'Enter a value';

  @override
  String get edit_meal_err_invalid_number => 'Enter a valid number';

  @override
  String get edit_meal_weight_label => 'Weight (g)';

  @override
  String get edit_meal_section_details => 'Details';

  @override
  String get edit_meal_section_portion => 'Portion';

  @override
  String get edit_meal_section_nutrition => 'Nutrition';

  @override
  String get addMeal_subscription_needed => 'Subscription required';

  @override
  String get addMeal_subscription_desc =>
      'Food recognition is available on a paid plan. Subscribe to use AI features.';

  @override
  String get addMeal_choose_tariff => 'Choose a plan';

  @override
  String get addMeal_close => 'Close';

  @override
  String addMeal_kcal(String cal) {
    return '$cal kcal';
  }

  @override
  String get addMeal_subscription_snack =>
      'A subscription is required for this feature';

  @override
  String get addMeal_weight_hint => 'Weight (g)';

  @override
  String get addMeal_recognizing_voice => 'Recognizing voice...';

  @override
  String get addMeal_recognizing_photo => 'Analyzing photo...';

  @override
  String get addMeal_mic_denied => 'Microphone access denied';

  @override
  String get addMeal_open_settings => 'Settings';

  @override
  String get addMeal_barcode => 'Barcode';

  @override
  String get addMeal_barcode_desc => 'Scan — find product instantly';

  @override
  String get addMeal_voice_tap_stop => 'Tap again to stop';

  @override
  String get addMeal_voice_tap_start => 'Tap to start recording';

  @override
  String get addMeal_recognize_ai => 'Recognize with AI';

  @override
  String get addMeal_not_food_title => 'No food detected';

  @override
  String get addMeal_not_food_message =>
      'We couldn\'t find food in this photo. Move the camera closer to the dish and try again.';

  @override
  String get addMeal_not_food_retry => 'Try again';

  @override
  String get addMeal_saving => 'Saving...';

  @override
  String get addMeal_ai_analyzing => 'AI is analyzing...';

  @override
  String get addMeal_parsing_title => 'Searching database';

  @override
  String get addMeal_parsing_step1 => 'Searching in database...';

  @override
  String get addMeal_parsing_step2 => 'Analyzing ingredients...';

  @override
  String get addMeal_parsing_step3 => 'Calculating nutrition...';

  @override
  String get addMeal_parsing_step4 => 'Finding vitamins & minerals...';

  @override
  String get barcode_scan_hint => 'Point the camera at a barcode';

  @override
  String get barcode_loading => 'Looking up product...';

  @override
  String get barcode_manual_btn => 'Enter manually';

  @override
  String get barcode_manual_title => 'Enter barcode';

  @override
  String get barcode_search_btn => 'Search';

  @override
  String get barcode_not_found => 'Product not found';

  @override
  String get addMeal_barcode_scanning => 'Barcode scanning';

  @override
  String get addMeal_barcode_torch_off => 'Turn off flashlight';

  @override
  String get addMeal_barcode_torch_on => 'Turn on flashlight';

  @override
  String get addMeal_barcode_detected => 'Barcode detected';

  @override
  String get addMeal_barcode_confirm => 'Add to journal';

  @override
  String get settings_delete_account_title => 'Delete account?';

  @override
  String get settings_delete_account_body =>
      'All your data will be permanently deleted. This action cannot be undone.';

  @override
  String get settings_delete_account_btn => 'Delete account';

  @override
  String get settings_ai_consent => 'AI Data Processing';

  @override
  String get settings_privacy_policy => 'Privacy Policy';

  @override
  String get settings_terms => 'Terms of Service';

  @override
  String get settings_sub_promo =>
      'Subscribe to unlock AI recognition, voice and photo.';

  @override
  String get settings_sale_ends => 'Sale ends in:';

  @override
  String get settings_sub_active_badge => '✓ Active';

  @override
  String get tariffs_title_full => 'Subscribe and unlock\nfull access';

  @override
  String get tariffs_tag1 => '🥕 Nutrition recommendations';

  @override
  String get tariffs_tag2 => '📋 Calorie scanner';

  @override
  String get tariffs_tag3 => '📋 Macro calculation';

  @override
  String get tariffs_tag4 => '😀 Emotion tracker';

  @override
  String get tariffs_trial => 'Free trial';

  @override
  String get tariffs_monthly => 'Monthly';

  @override
  String get tariffs_yearly => 'Yearly';

  @override
  String get tariffs_quarterly => '3 months';

  @override
  String get tariffs_per_3days => '/ 3 days';

  @override
  String get tariffs_per_day => '/ day';

  @override
  String get tariffs_per_3mo => '/ 3 mo';

  @override
  String get tariffs_trial_then => 'Then 2,990 ₽/year';

  @override
  String get tariffs_monthly_billing => 'Monthly billing';

  @override
  String get tariffs_yearly_save => '2,990 ₽ / Save 8,890 ₽';

  @override
  String get tariffs_best_value => 'Best value';

  @override
  String tariffs_no_discount(String price) {
    return 'Without discount $price';
  }

  @override
  String get tariffs_no_plans => 'No plans available';

  @override
  String get tariffs_cancel_anytime =>
      'Cancel anytime in your account settings';

  @override
  String get tariffs_optimal_months =>
      'Optimal results are achieved after 3 months';

  @override
  String get tariffs_email_hint => 'Email for receipt';

  @override
  String get tariffs_email_error => 'Enter a valid email';

  @override
  String get tariffs_pay_error => 'Payment failed. Please try again.';

  @override
  String get tariffs_get_plan => 'Get my plan';

  @override
  String get tariffs_load_error => 'Failed to load tariffs';

  @override
  String get tariffs_sale_ends => 'SALE ENDS IN';

  @override
  String get tariffs_benefit1 => '🥗 Nutritionist consultation';

  @override
  String get tariffs_benefit2 => '🎥 Video recipes';

  @override
  String get tariffs_benefit3 => '🍽️ Meal plan';

  @override
  String get tariffs_benefit4 => '📋 Nutrition guide';

  @override
  String get tariffs_payment_title => 'Payment';

  @override
  String get nav_chat => 'AI Chat';

  @override
  String get chat_title => 'AI Nutritionist';

  @override
  String get chat_input_hint => 'Ask about nutrition...';

  @override
  String get chat_clear => 'Clear chat';

  @override
  String get chat_clear_confirm => 'Delete all chat history?';

  @override
  String get chat_error => 'Failed to send message';

  @override
  String get chat_empty =>
      'Ask me anything about nutrition, your diet, or progress!';

  @override
  String get chat_suggestion_1 => '🥗 What to eat for lunch on a deficit?';

  @override
  String get chat_suggestion_2 => '💪 Daily protein norm for weight loss';

  @override
  String get chat_suggestion_3 => '🌙 Is it okay to eat after 6 PM?';

  @override
  String get recogV2_composition => 'COMPOSITION';

  @override
  String get recogV2_meal_type => 'MEAL TYPE';

  @override
  String get recogV2_saving => 'Saving...';

  @override
  String get recogV2_add_breakfast => 'Add breakfast';

  @override
  String get recogV2_add_lunch => 'Add lunch';

  @override
  String get recogV2_add_dinner => 'Add dinner';

  @override
  String get recogV2_add_snack => 'Add snack';

  @override
  String get recogV2_add_meal => 'Add meal';

  @override
  String get recogV2_macros => 'MACRONUTRIENTS';

  @override
  String get recogV2_carbs_detail => 'CARBS DETAIL';

  @override
  String get recogV2_net_carbs => 'Net carbs';

  @override
  String get recogV2_fiber => 'Fiber';

  @override
  String get recogV2_sugar_alcohols => 'Sugar alcohols';

  @override
  String get recogV2_fats_detail => 'FATS DETAIL';

  @override
  String get recogV2_sat_fat => 'Saturated';

  @override
  String get recogV2_mono_fat => 'Monounsaturated';

  @override
  String get recogV2_poly_fat => 'Polyunsaturated';

  @override
  String get recogV2_micro => 'MICRONUTRIENTS';

  @override
  String get recogV2_sodium => 'Sodium';

  @override
  String get recogV2_cholesterol => 'Cholesterol';

  @override
  String get recogV2_potassium => 'Potassium';

  @override
  String get recogV2_mg => 'mg';

  @override
  String get recogV2_gi_low => 'low';

  @override
  String get recogV2_gi_medium => 'medium';

  @override
  String get recogV2_gi_high => 'high';

  @override
  String get recogV2_gi_label => 'GI';

  @override
  String get recogV2_search_ingredient => 'Search ingredient';

  @override
  String get recogV2_search_hint => 'E.g.: chicken breast';

  @override
  String get recogV2_correct_btn => 'Correct';

  @override
  String get recogV2_correct_hint =>
      'What to change? E.g.: turkey patties, not chicken';

  @override
  String get recogV2_correct_title => 'Correction';

  @override
  String get recogV2_correct_send => 'Apply';

  @override
  String get recogV2_correct_loading => 'Updating...';

  @override
  String get nds_section_basic => 'Basic';

  @override
  String get nds_section_carbs_detail => 'Carbs detail';

  @override
  String get nds_section_fats_detail => 'Fats detail';

  @override
  String get nds_section_minerals => 'Minerals';

  @override
  String get nds_section_vitamins => 'Vitamins';

  @override
  String get nds_nutrient_calories => 'Calories';

  @override
  String get nds_nutrient_protein => 'Protein';

  @override
  String get nds_nutrient_fat => 'Fat';

  @override
  String get nds_nutrient_carbs => 'Carbs';

  @override
  String get nds_nutrient_fiber => 'Fiber';

  @override
  String get nds_nutrient_sugar_alcohols => 'Sugar alcohols';

  @override
  String get nds_nutrient_net_carbs => 'Net carbs';

  @override
  String get nds_nutrient_gi => 'Glycemic index';

  @override
  String get nds_nutrient_sat_fat => 'Saturated';

  @override
  String get nds_nutrient_mono_fat => 'Monounsaturated';

  @override
  String get nds_nutrient_poly_fat => 'Polyunsaturated';

  @override
  String get nds_nutrient_sodium => 'Sodium';

  @override
  String get nds_nutrient_cholesterol => 'Cholesterol';

  @override
  String get nds_nutrient_potassium => 'Potassium';

  @override
  String get nds_nutrient_calcium => 'Calcium';

  @override
  String get nds_nutrient_iron => 'Iron';

  @override
  String get nds_nutrient_vitamin_a => 'Vitamin A';

  @override
  String get nds_nutrient_vitamin_c => 'Vitamin C';

  @override
  String get nds_nutrient_vitamin_d => 'Vitamin D';

  @override
  String get nds_gi_low => 'low';

  @override
  String get nds_gi_medium => 'medium';

  @override
  String get nds_gi_high => 'high';

  @override
  String get nds_source_cache => 'Cache';

  @override
  String get nds_unit_kcal => 'kcal';

  @override
  String get nds_unit_g => 'g';

  @override
  String get nds_unit_mg => 'mg';

  @override
  String get nds_unit_mcg => 'mcg';

  @override
  String get nds_per100g => '/100g';

  @override
  String nds_weight_g(String w) {
    return '$w g';
  }

  @override
  String get nutrient_details_title => 'DETAILS';

  @override
  String get nutrient_weight => 'Weight';

  @override
  String get nutrient_net_carbs => 'Net Carbs';

  @override
  String get nutrient_fiber => 'Fiber';

  @override
  String get nutrient_sugar => 'Sugar';

  @override
  String get nutrient_sugar_alcohols => 'Sugar Alcohols';

  @override
  String get nutrient_glycemic_index => 'Glycemic Index';

  @override
  String get nutrient_saturated_fat => 'Saturated Fat';

  @override
  String get nutrient_unsaturated_fat => 'Unsaturated Fat';

  @override
  String get nutrient_cholesterol => 'Cholesterol';

  @override
  String get nutrient_sodium => 'Sodium';

  @override
  String get nutrient_potassium => 'Potassium';

  @override
  String get nutrient_calcium => 'Calcium';

  @override
  String get nutrient_iron => 'Iron';

  @override
  String get nutrient_vitamin_a => 'Vitamin A';

  @override
  String get nutrient_vitamin_c => 'Vitamin C';

  @override
  String get nutrient_vitamin_d => 'Vitamin D';

  @override
  String get nutrient_vitamin_b12 => 'Vitamin B12';

  @override
  String get nutrient_mg => 'mg';

  @override
  String get nutrient_mcg => 'mcg';

  @override
  String mealGroup_itemsCount(int count) {
    return '$count items';
  }
}
