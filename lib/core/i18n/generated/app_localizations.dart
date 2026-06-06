import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In ru, this message translates to:
  /// **'Kayfit'**
  String get appName;

  /// No description provided for @nav_today.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get nav_today;

  /// No description provided for @nav_journal.
  ///
  /// In ru, this message translates to:
  /// **'Журнал'**
  String get nav_journal;

  /// No description provided for @nav_settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get nav_settings;

  /// No description provided for @common_save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get common_save;

  /// No description provided for @common_cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get common_cancel;

  /// No description provided for @common_delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get common_delete;

  /// No description provided for @common_edit.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get common_edit;

  /// No description provided for @meal_details_full.
  ///
  /// In ru, this message translates to:
  /// **'Подробный состав'**
  String get meal_details_full;

  /// No description provided for @common_loading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка...'**
  String get common_loading;

  /// No description provided for @common_error.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка'**
  String get common_error;

  /// No description provided for @common_retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get common_retry;

  /// No description provided for @common_next.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get common_next;

  /// No description provided for @common_back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get common_back;

  /// No description provided for @common_done.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get common_done;

  /// No description provided for @common_skip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get common_skip;

  /// No description provided for @common_stop.
  ///
  /// In ru, this message translates to:
  /// **'Стоп'**
  String get common_stop;

  /// No description provided for @macro_calories.
  ///
  /// In ru, this message translates to:
  /// **'Калории'**
  String get macro_calories;

  /// No description provided for @macro_protein.
  ///
  /// In ru, this message translates to:
  /// **'Белки'**
  String get macro_protein;

  /// No description provided for @macro_fat.
  ///
  /// In ru, this message translates to:
  /// **'Жиры'**
  String get macro_fat;

  /// No description provided for @macro_carbs.
  ///
  /// In ru, this message translates to:
  /// **'Углеводы'**
  String get macro_carbs;

  /// No description provided for @macro_protein_abbr.
  ///
  /// In ru, this message translates to:
  /// **'Б'**
  String get macro_protein_abbr;

  /// No description provided for @macro_fat_abbr.
  ///
  /// In ru, this message translates to:
  /// **'Ж'**
  String get macro_fat_abbr;

  /// No description provided for @macro_carbs_abbr.
  ///
  /// In ru, this message translates to:
  /// **'У'**
  String get macro_carbs_abbr;

  /// No description provided for @macro_kcal.
  ///
  /// In ru, this message translates to:
  /// **'ккал'**
  String get macro_kcal;

  /// No description provided for @macro_g.
  ///
  /// In ru, this message translates to:
  /// **'г'**
  String get macro_g;

  /// No description provided for @recognition_save_to_journal.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить в журнал'**
  String get recognition_save_to_journal;

  /// No description provided for @recognition_items_label.
  ///
  /// In ru, this message translates to:
  /// **'ИНГРЕДИЕНТЫ · НАЖМИТЕ ✏ ДЛЯ ПРАВКИ'**
  String get recognition_items_label;

  /// No description provided for @macro_eaten.
  ///
  /// In ru, this message translates to:
  /// **'съедено'**
  String get macro_eaten;

  /// No description provided for @macro_remaining.
  ///
  /// In ru, this message translates to:
  /// **'осталось'**
  String get macro_remaining;

  /// No description provided for @macro_goal.
  ///
  /// In ru, this message translates to:
  /// **'цель'**
  String get macro_goal;

  /// No description provided for @dashboard_title.
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get dashboard_title;

  /// No description provided for @dashboard_addMeal.
  ///
  /// In ru, this message translates to:
  /// **'Добавить приём пищи'**
  String get dashboard_addMeal;

  /// No description provided for @dashboard_noMeals.
  ///
  /// In ru, this message translates to:
  /// **'Нет записей за сегодня'**
  String get dashboard_noMeals;

  /// No description provided for @dashboard_personal_plan_title.
  ///
  /// In ru, this message translates to:
  /// **'Ваш персональный план'**
  String get dashboard_personal_plan_title;

  /// No description provided for @dashboard_personal_plan_sub.
  ///
  /// In ru, this message translates to:
  /// **'Цель: {kcal} ккал/день · Нажмите для просмотра'**
  String dashboard_personal_plan_sub(int kcal);

  /// No description provided for @dashboard_compulsive.
  ///
  /// In ru, this message translates to:
  /// **'Компульсивных приёмов: {count}'**
  String dashboard_compulsive(int count);

  /// No description provided for @journal_title.
  ///
  /// In ru, this message translates to:
  /// **'Журнал'**
  String get journal_title;

  /// No description provided for @journal_empty.
  ///
  /// In ru, this message translates to:
  /// **'История пуста'**
  String get journal_empty;

  /// No description provided for @journal_no_meals_today.
  ///
  /// In ru, this message translates to:
  /// **'Блюд за сегодня нет'**
  String get journal_no_meals_today;

  /// No description provided for @journal_tap_plus_to_log.
  ///
  /// In ru, this message translates to:
  /// **'Нажми + чтобы добавить первое блюдо'**
  String get journal_tap_plus_to_log;

  /// No description provided for @journal_ai_banner_title.
  ///
  /// In ru, this message translates to:
  /// **'ИИ-нутрициолог'**
  String get journal_ai_banner_title;

  /// No description provided for @journal_ai_banner_sub.
  ///
  /// In ru, this message translates to:
  /// **'Поможет с выбором блюд и расчётом КБЖУ на день'**
  String get journal_ai_banner_sub;

  /// No description provided for @journal_ai_banner_btn.
  ///
  /// In ru, this message translates to:
  /// **'Спросить'**
  String get journal_ai_banner_btn;

  /// No description provided for @settings_title.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings_title;

  /// No description provided for @settings_profile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get settings_profile;

  /// No description provided for @settings_language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get settings_language;

  /// No description provided for @settings_subscription.
  ///
  /// In ru, this message translates to:
  /// **'Подписка'**
  String get settings_subscription;

  /// No description provided for @settings_logout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get settings_logout;

  /// No description provided for @settings_langRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get settings_langRu;

  /// No description provided for @settings_langEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get settings_langEn;

  /// No description provided for @settings_goals.
  ///
  /// In ru, this message translates to:
  /// **'Цели КБЖУ'**
  String get settings_goals;

  /// No description provided for @addMeal_title.
  ///
  /// In ru, this message translates to:
  /// **'Добавить блюдо'**
  String get addMeal_title;

  /// No description provided for @addMeal_text.
  ///
  /// In ru, this message translates to:
  /// **'Текстом'**
  String get addMeal_text;

  /// No description provided for @addMeal_voice.
  ///
  /// In ru, this message translates to:
  /// **'Голосом'**
  String get addMeal_voice;

  /// No description provided for @addMeal_photo.
  ///
  /// In ru, this message translates to:
  /// **'Фото'**
  String get addMeal_photo;

  /// No description provided for @addMeal_manual.
  ///
  /// In ru, this message translates to:
  /// **'Вручную'**
  String get addMeal_manual;

  /// No description provided for @addMeal_emotionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как вы себя чувствуете?'**
  String get addMeal_emotionTitle;

  /// No description provided for @addMeal_inputHint.
  ///
  /// In ru, this message translates to:
  /// **'Опишите что съели...'**
  String get addMeal_inputHint;

  /// No description provided for @addMeal_parsing.
  ///
  /// In ru, this message translates to:
  /// **'Распознаём...'**
  String get addMeal_parsing;

  /// No description provided for @addMeal_selectItems.
  ///
  /// In ru, this message translates to:
  /// **'Выберите блюда'**
  String get addMeal_selectItems;

  /// No description provided for @addMeal_add.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get addMeal_add;

  /// No description provided for @addMeal_recording.
  ///
  /// In ru, this message translates to:
  /// **'Идёт запись...'**
  String get addMeal_recording;

  /// No description provided for @addMeal_stopRecording.
  ///
  /// In ru, this message translates to:
  /// **'Остановить'**
  String get addMeal_stopRecording;

  /// No description provided for @addMeal_transcribing.
  ///
  /// In ru, this message translates to:
  /// **'Распознаём речь...'**
  String get addMeal_transcribing;

  /// No description provided for @addMeal_takePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Сделать фото'**
  String get addMeal_takePhoto;

  /// No description provided for @addMeal_choosePhoto.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать из галереи'**
  String get addMeal_choosePhoto;

  /// No description provided for @addMeal_recognizing.
  ///
  /// In ru, this message translates to:
  /// **'Распознаём...'**
  String get addMeal_recognizing;

  /// No description provided for @meal_calories.
  ///
  /// In ru, this message translates to:
  /// **'{cal} ккал'**
  String meal_calories(double cal);

  /// No description provided for @meal_macros.
  ///
  /// In ru, this message translates to:
  /// **'Б: {p}г  Ж: {f}г  У: {c}г'**
  String meal_macros(double p, double f, double c);

  /// No description provided for @emotion_happy.
  ///
  /// In ru, this message translates to:
  /// **'Радость'**
  String get emotion_happy;

  /// No description provided for @emotion_calm.
  ///
  /// In ru, this message translates to:
  /// **'Спокойствие'**
  String get emotion_calm;

  /// No description provided for @emotion_sad.
  ///
  /// In ru, this message translates to:
  /// **'Грусть'**
  String get emotion_sad;

  /// No description provided for @emotion_anxious.
  ///
  /// In ru, this message translates to:
  /// **'Тревога'**
  String get emotion_anxious;

  /// No description provided for @emotion_tired.
  ///
  /// In ru, this message translates to:
  /// **'Усталость'**
  String get emotion_tired;

  /// No description provided for @emotion_hungry.
  ///
  /// In ru, this message translates to:
  /// **'Голод'**
  String get emotion_hungry;

  /// No description provided for @emotion_bored.
  ///
  /// In ru, this message translates to:
  /// **'Скука'**
  String get emotion_bored;

  /// No description provided for @emotion_angry.
  ///
  /// In ru, this message translates to:
  /// **'Злость'**
  String get emotion_angry;

  /// No description provided for @emotion_worried.
  ///
  /// In ru, this message translates to:
  /// **'Беспокойство'**
  String get emotion_worried;

  /// No description provided for @emotion_neutral.
  ///
  /// In ru, this message translates to:
  /// **'Нейтральность'**
  String get emotion_neutral;

  /// No description provided for @emotion_other.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get emotion_other;

  /// No description provided for @ob_landing_title1.
  ///
  /// In ru, this message translates to:
  /// **'Худей'**
  String get ob_landing_title1;

  /// No description provided for @ob_landing_title2.
  ///
  /// In ru, this message translates to:
  /// **'просто'**
  String get ob_landing_title2;

  /// No description provided for @ob_landing_sub.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируй или опиши голосом еду — AI посчитает калории'**
  String get ob_landing_sub;

  /// No description provided for @ob_landing_cta.
  ///
  /// In ru, this message translates to:
  /// **'Попробовать сейчас'**
  String get ob_landing_cta;

  /// No description provided for @ob_landing_cta_sub1.
  ///
  /// In ru, this message translates to:
  /// **'Персональный план'**
  String get ob_landing_cta_sub1;

  /// No description provided for @ob_landing_cta_sub2.
  ///
  /// In ru, this message translates to:
  /// **'меньше минуты'**
  String get ob_landing_cta_sub2;

  /// No description provided for @ob_skip_btn.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить'**
  String get ob_skip_btn;

  /// No description provided for @ob_skip_title.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить шаг?'**
  String get ob_skip_title;

  /// No description provided for @ob_skip_sub.
  ///
  /// In ru, this message translates to:
  /// **'Без этих данных расчёт будет менее точным.'**
  String get ob_skip_sub;

  /// No description provided for @ob_skip_continue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить без данных'**
  String get ob_skip_continue;

  /// No description provided for @ob_skip_back.
  ///
  /// In ru, this message translates to:
  /// **'Вернуться'**
  String get ob_skip_back;

  /// No description provided for @ob_step_age_title.
  ///
  /// In ru, this message translates to:
  /// **'Ваш возраст?'**
  String get ob_step_age_title;

  /// No description provided for @ob_step_age_hint.
  ///
  /// In ru, this message translates to:
  /// **'Возраст влияет на расчёт базового обмена веществ'**
  String get ob_step_age_hint;

  /// No description provided for @ob_step_height_title.
  ///
  /// In ru, this message translates to:
  /// **'Ваш рост?'**
  String get ob_step_height_title;

  /// No description provided for @ob_step_height_hint.
  ///
  /// In ru, this message translates to:
  /// **'Рост помогает рассчитать базовый обмен веществ'**
  String get ob_step_height_hint;

  /// No description provided for @ob_step_height_unit.
  ///
  /// In ru, this message translates to:
  /// **'сантиметры'**
  String get ob_step_height_unit;

  /// No description provided for @ob_step_gender_title.
  ///
  /// In ru, this message translates to:
  /// **'Ваш пол?'**
  String get ob_step_gender_title;

  /// No description provided for @ob_step_gender_hint.
  ///
  /// In ru, this message translates to:
  /// **'Пол учитывается в формуле Миффлина'**
  String get ob_step_gender_hint;

  /// No description provided for @ob_step_gender_female.
  ///
  /// In ru, this message translates to:
  /// **'Женщина'**
  String get ob_step_gender_female;

  /// No description provided for @ob_step_gender_male.
  ///
  /// In ru, this message translates to:
  /// **'Мужчина'**
  String get ob_step_gender_male;

  /// No description provided for @ob_step_weight_title.
  ///
  /// In ru, this message translates to:
  /// **'Ваш вес?'**
  String get ob_step_weight_title;

  /// No description provided for @ob_step_weight_hint.
  ///
  /// In ru, this message translates to:
  /// **'Текущий и желаемый вес для расчёта дефицита калорий'**
  String get ob_step_weight_hint;

  /// No description provided for @ob_step_weight_now.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас'**
  String get ob_step_weight_now;

  /// No description provided for @ob_step_weight_goal.
  ///
  /// In ru, this message translates to:
  /// **'Цель'**
  String get ob_step_weight_goal;

  /// No description provided for @ob_step_training_title.
  ///
  /// In ru, this message translates to:
  /// **'Сколько дней в неделю вы тренируетесь?'**
  String get ob_step_training_title;

  /// No description provided for @ob_step_training_sub.
  ///
  /// In ru, this message translates to:
  /// **'Это поможет точнее рассчитать суточную активность'**
  String get ob_step_training_sub;

  /// No description provided for @ob_training_0.
  ///
  /// In ru, this message translates to:
  /// **'Не тренируюсь'**
  String get ob_training_0;

  /// No description provided for @ob_training_1_2.
  ///
  /// In ru, this message translates to:
  /// **'1–2 дня'**
  String get ob_training_1_2;

  /// No description provided for @ob_training_3_4.
  ///
  /// In ru, this message translates to:
  /// **'3–4 дня'**
  String get ob_training_3_4;

  /// No description provided for @ob_training_daily.
  ///
  /// In ru, this message translates to:
  /// **'Каждый день'**
  String get ob_training_daily;

  /// No description provided for @ob_method_title.
  ///
  /// In ru, this message translates to:
  /// **'Как добавить еду?'**
  String get ob_method_title;

  /// No description provided for @ob_method_sub.
  ///
  /// In ru, this message translates to:
  /// **'Выбери удобный способ — AI распознает КБЖУ'**
  String get ob_method_sub;

  /// No description provided for @ob_method_photo_title.
  ///
  /// In ru, this message translates to:
  /// **'Фото еды'**
  String get ob_method_photo_title;

  /// No description provided for @ob_method_photo_desc.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируй блюдо — AI определит состав за 5 сек'**
  String get ob_method_photo_desc;

  /// No description provided for @ob_method_voice_title.
  ///
  /// In ru, this message translates to:
  /// **'Голосом'**
  String get ob_method_voice_title;

  /// No description provided for @ob_method_voice_desc.
  ///
  /// In ru, this message translates to:
  /// **'«Съел борщ 300 мл» — просто скажи'**
  String get ob_method_voice_desc;

  /// No description provided for @ob_method_text_title.
  ///
  /// In ru, this message translates to:
  /// **'Текстом'**
  String get ob_method_text_title;

  /// No description provided for @ob_method_text_desc.
  ///
  /// In ru, this message translates to:
  /// **'Напиши что съел — AI посчитает калории'**
  String get ob_method_text_desc;

  /// No description provided for @ob_method_note.
  ///
  /// In ru, this message translates to:
  /// **'Все способы работают быстро и точно'**
  String get ob_method_note;

  /// No description provided for @ob_demo_perks_title.
  ///
  /// In ru, this message translates to:
  /// **'Что ты получишь в Kayfit:'**
  String get ob_demo_perks_title;

  /// No description provided for @ob_demo_perk1.
  ///
  /// In ru, this message translates to:
  /// **'Фото еды → AI распознает КБЖУ'**
  String get ob_demo_perk1;

  /// No description provided for @ob_demo_perk2.
  ///
  /// In ru, this message translates to:
  /// **'Голосом: «Съел борщ» — и готово'**
  String get ob_demo_perk2;

  /// No description provided for @ob_demo_perk3.
  ///
  /// In ru, this message translates to:
  /// **'История питания и прогресс'**
  String get ob_demo_perk3;

  /// No description provided for @ob_demo_perk4.
  ///
  /// In ru, this message translates to:
  /// **'Рекомендации по питанию от ИИ'**
  String get ob_demo_perk4;

  /// No description provided for @ob_result_title.
  ///
  /// In ru, this message translates to:
  /// **'Ваш персональный план'**
  String get ob_result_title;

  /// No description provided for @ob_result_sub.
  ///
  /// In ru, this message translates to:
  /// **'Расчёт на основе вашего профиля'**
  String get ob_result_sub;

  /// No description provided for @ob_result_kcalday.
  ///
  /// In ru, this message translates to:
  /// **'ккал/день'**
  String get ob_result_kcalday;

  /// No description provided for @ob_result_accuracy.
  ///
  /// In ru, this message translates to:
  /// **'Оценка с помощью ИИ'**
  String get ob_result_accuracy;

  /// No description provided for @ob_result_next_title.
  ///
  /// In ru, this message translates to:
  /// **'Следующий шаг'**
  String get ob_result_next_title;

  /// No description provided for @ob_result_next_text.
  ///
  /// In ru, this message translates to:
  /// **'Войдите, чтобы сохранить план и начать отслеживать питание.'**
  String get ob_result_next_text;

  /// No description provided for @ob_err_height.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный рост (100–250 см)'**
  String get ob_err_height;

  /// No description provided for @ob_err_weight.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный вес (30–300 кг)'**
  String get ob_err_weight;

  /// No description provided for @ob_err_target_weight.
  ///
  /// In ru, this message translates to:
  /// **'Введите целевой вес (30–300 кг)'**
  String get ob_err_target_weight;

  /// No description provided for @ob_err_training.
  ///
  /// In ru, this message translates to:
  /// **'Выберите хотя бы один вариант'**
  String get ob_err_training;

  /// No description provided for @ob_footer_saving.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение...'**
  String get ob_footer_saving;

  /// No description provided for @ob_footer_calc.
  ///
  /// In ru, this message translates to:
  /// **'Рассчитать план'**
  String get ob_footer_calc;

  /// No description provided for @ob_footer_great.
  ///
  /// In ru, this message translates to:
  /// **'Отлично!'**
  String get ob_footer_great;

  /// No description provided for @ob_footer_login.
  ///
  /// In ru, this message translates to:
  /// **'Войти и сохранить план'**
  String get ob_footer_login;

  /// No description provided for @ob_continue.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить'**
  String get ob_continue;

  /// No description provided for @ob_getStarted.
  ///
  /// In ru, this message translates to:
  /// **'Начать'**
  String get ob_getStarted;

  /// No description provided for @ob_already_account.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт? Войти'**
  String get ob_already_account;

  /// No description provided for @ob_weight_unit.
  ///
  /// In ru, this message translates to:
  /// **'кг'**
  String get ob_weight_unit;

  /// No description provided for @ob_method_recording.
  ///
  /// In ru, this message translates to:
  /// **'Идёт запись… Нажмите ещё раз чтобы остановить'**
  String get ob_method_recording;

  /// No description provided for @ob_method_text_hint.
  ///
  /// In ru, this message translates to:
  /// **'Например: гречка 200г, куриная грудка 150г'**
  String get ob_method_text_hint;

  /// No description provided for @ob_method_recognize.
  ///
  /// In ru, this message translates to:
  /// **'Распознать'**
  String get ob_method_recognize;

  /// No description provided for @ob_method_recognized.
  ///
  /// In ru, this message translates to:
  /// **'Распознано:'**
  String get ob_method_recognized;

  /// No description provided for @ob_method_reset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get ob_method_reset;

  /// No description provided for @ob_method_mic_denied.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к микрофону'**
  String get ob_method_mic_denied;

  /// No description provided for @ob_method_ai_success.
  ///
  /// In ru, this message translates to:
  /// **'ИИ всё распознал! Нажмите «Далее» чтобы продолжить.'**
  String get ob_method_ai_success;

  /// No description provided for @ob_method_kcal.
  ///
  /// In ru, this message translates to:
  /// **'{cal} ккал'**
  String ob_method_kcal(String cal);

  /// No description provided for @ob_method_macros.
  ///
  /// In ru, this message translates to:
  /// **'Б{p} Ж{f} У{c}'**
  String ob_method_macros(String p, String f, String c);

  /// No description provided for @ob_recognizing_voice.
  ///
  /// In ru, this message translates to:
  /// **'Распознаём голос…'**
  String get ob_recognizing_voice;

  /// No description provided for @ob_recognizing_photo.
  ///
  /// In ru, this message translates to:
  /// **'Анализируем фото…'**
  String get ob_recognizing_photo;

  /// No description provided for @auth_title.
  ///
  /// In ru, this message translates to:
  /// **'Войти в Kayfit'**
  String get auth_title;

  /// No description provided for @auth_subtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите способ входа'**
  String get auth_subtitle;

  /// No description provided for @auth_google.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Google'**
  String get auth_google;

  /// No description provided for @auth_apple.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Apple'**
  String get auth_apple;

  /// No description provided for @auth_telegram.
  ///
  /// In ru, this message translates to:
  /// **'Войти через Telegram'**
  String get auth_telegram;

  /// No description provided for @auth_email.
  ///
  /// In ru, this message translates to:
  /// **'Войти по email'**
  String get auth_email;

  /// No description provided for @auth_terms.
  ///
  /// In ru, this message translates to:
  /// **'Продолжая, вы соглашаетесь с условиями использования'**
  String get auth_terms;

  /// No description provided for @tariffs_title.
  ///
  /// In ru, this message translates to:
  /// **'Тарифы'**
  String get tariffs_title;

  /// No description provided for @tariffs_subscribe.
  ///
  /// In ru, this message translates to:
  /// **'Оформить подписку'**
  String get tariffs_subscribe;

  /// No description provided for @tariffs_current.
  ///
  /// In ru, this message translates to:
  /// **'Текущий тариф'**
  String get tariffs_current;

  /// No description provided for @tariffs_free.
  ///
  /// In ru, this message translates to:
  /// **'Бесплатно'**
  String get tariffs_free;

  /// No description provided for @tariffs_perMonth.
  ///
  /// In ru, this message translates to:
  /// **'/ месяц'**
  String get tariffs_perMonth;

  /// No description provided for @tariffs_cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отменить автопродление'**
  String get tariffs_cancel;

  /// No description provided for @tariffs_cancelConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите отменить автопродление?'**
  String get tariffs_cancelConfirm;

  /// No description provided for @wg_title.
  ///
  /// In ru, this message translates to:
  /// **'Рассчитаем ваш путь к цели'**
  String get wg_title;

  /// No description provided for @wg_sub.
  ///
  /// In ru, this message translates to:
  /// **'Введите данные для расчёта калорий и БЖУ'**
  String get wg_sub;

  /// No description provided for @wg_age.
  ///
  /// In ru, this message translates to:
  /// **'Возраст (лет)'**
  String get wg_age;

  /// No description provided for @wg_weight.
  ///
  /// In ru, this message translates to:
  /// **'Текущий вес (кг)'**
  String get wg_weight;

  /// No description provided for @wg_height.
  ///
  /// In ru, this message translates to:
  /// **'Рост (см)'**
  String get wg_height;

  /// No description provided for @wg_target_weight.
  ///
  /// In ru, this message translates to:
  /// **'Целевой вес (кг, опционально)'**
  String get wg_target_weight;

  /// No description provided for @wg_deficit.
  ///
  /// In ru, this message translates to:
  /// **'Режим дефицита'**
  String get wg_deficit;

  /// No description provided for @wg_deficit_active.
  ///
  /// In ru, this message translates to:
  /// **'Активный (-600 ккал)'**
  String get wg_deficit_active;

  /// No description provided for @wg_deficit_gentle.
  ///
  /// In ru, this message translates to:
  /// **'Бережный (-300 ккал)'**
  String get wg_deficit_gentle;

  /// No description provided for @wg_btn_next.
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get wg_btn_next;

  /// No description provided for @wg_btn_calculating.
  ///
  /// In ru, this message translates to:
  /// **'Расчёт...'**
  String get wg_btn_calculating;

  /// No description provided for @wg_err_fill.
  ///
  /// In ru, this message translates to:
  /// **'Заполните возраст, вес и рост'**
  String get wg_err_fill;

  /// No description provided for @wg_err_data.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте корректность данных'**
  String get wg_err_data;

  /// No description provided for @wg_result_title.
  ///
  /// In ru, this message translates to:
  /// **'Ваш путь к цели'**
  String get wg_result_title;

  /// No description provided for @wg_result_reach.
  ///
  /// In ru, this message translates to:
  /// **'Вы достигнете цели'**
  String get wg_result_reach;

  /// No description provided for @wg_result_target_weight.
  ///
  /// In ru, this message translates to:
  /// **'Целевой вес'**
  String get wg_result_target_weight;

  /// No description provided for @wg_result_kg.
  ///
  /// In ru, this message translates to:
  /// **'кг'**
  String get wg_result_kg;

  /// No description provided for @wg_result_bmr.
  ///
  /// In ru, this message translates to:
  /// **'BMR (базовый обмен):'**
  String get wg_result_bmr;

  /// No description provided for @wg_result_tdee.
  ///
  /// In ru, this message translates to:
  /// **'TDEE (суточный расход):'**
  String get wg_result_tdee;

  /// No description provided for @wg_result_days.
  ///
  /// In ru, this message translates to:
  /// **'Дней до цели:'**
  String get wg_result_days;

  /// No description provided for @wg_result_kcal_day.
  ///
  /// In ru, this message translates to:
  /// **'ккал/день'**
  String get wg_result_kcal_day;

  /// No description provided for @wg_btn_start.
  ///
  /// In ru, this message translates to:
  /// **'Начать отслеживать'**
  String get wg_btn_start;

  /// No description provided for @error_network.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сервером'**
  String get error_network;

  /// No description provided for @error_auth.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка авторизации'**
  String get error_auth;

  /// No description provided for @error_unknown.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get error_unknown;

  /// No description provided for @subscription_title.
  ///
  /// In ru, this message translates to:
  /// **'Подписка'**
  String get subscription_title;

  /// No description provided for @subscription_none.
  ///
  /// In ru, this message translates to:
  /// **'У вас нет активной подписки'**
  String get subscription_none;

  /// No description provided for @subscription_view_tariffs.
  ///
  /// In ru, this message translates to:
  /// **'Посмотреть тарифы'**
  String get subscription_view_tariffs;

  /// No description provided for @subscription_active.
  ///
  /// In ru, this message translates to:
  /// **'Активная подписка'**
  String get subscription_active;

  /// No description provided for @subscription_expires.
  ///
  /// In ru, this message translates to:
  /// **'Действует до'**
  String get subscription_expires;

  /// No description provided for @subscription_amount.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость'**
  String get subscription_amount;

  /// No description provided for @subscription_auto_renew.
  ///
  /// In ru, this message translates to:
  /// **'Автопродление'**
  String get subscription_auto_renew;

  /// No description provided for @subscription_auto_renew_on.
  ///
  /// In ru, this message translates to:
  /// **'Включено'**
  String get subscription_auto_renew_on;

  /// No description provided for @subscription_auto_renew_off.
  ///
  /// In ru, this message translates to:
  /// **'Отключено'**
  String get subscription_auto_renew_off;

  /// No description provided for @subscription_cancel_auto_renew.
  ///
  /// In ru, this message translates to:
  /// **'Отменить автопродление'**
  String get subscription_cancel_auto_renew;

  /// No description provided for @subscription_cancel_auto_renew_title.
  ///
  /// In ru, this message translates to:
  /// **'Отмена автопродления'**
  String get subscription_cancel_auto_renew_title;

  /// No description provided for @subscription_cancel_auto_renew_confirm.
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите отменить автопродление подписки?'**
  String get subscription_cancel_auto_renew_confirm;

  /// No description provided for @subscription_cancel_auto_renew_action.
  ///
  /// In ru, this message translates to:
  /// **'Отменить'**
  String get subscription_cancel_auto_renew_action;

  /// No description provided for @subscription_auto_renew_cancelled.
  ///
  /// In ru, this message translates to:
  /// **'Автопродление отменено'**
  String get subscription_auto_renew_cancelled;

  /// No description provided for @wg_plan_ready.
  ///
  /// In ru, this message translates to:
  /// **'Ваш план готов!'**
  String get wg_plan_ready;

  /// No description provided for @wg_personal_calc.
  ///
  /// In ru, this message translates to:
  /// **'Персональный расчёт на основе ваших данных'**
  String get wg_personal_calc;

  /// No description provided for @wg_kcal_day.
  ///
  /// In ru, this message translates to:
  /// **'ккал / день'**
  String get wg_kcal_day;

  /// No description provided for @wg_macronutrients.
  ///
  /// In ru, this message translates to:
  /// **'Макронутриенты'**
  String get wg_macronutrients;

  /// No description provided for @wg_days_to_goal.
  ///
  /// In ru, this message translates to:
  /// **'До цели: {days} дней'**
  String wg_days_to_goal(int days);

  /// No description provided for @wg_target_weight_val.
  ///
  /// In ru, this message translates to:
  /// **'Целевой вес: {kg} кг'**
  String wg_target_weight_val(String kg);

  /// No description provided for @wg_weight_forecast.
  ///
  /// In ru, this message translates to:
  /// **'Прогноз веса'**
  String get wg_weight_forecast;

  /// No description provided for @wg_how_to_reach.
  ///
  /// In ru, this message translates to:
  /// **'Как достичь цели'**
  String get wg_how_to_reach;

  /// No description provided for @wg_feature_photo_title.
  ///
  /// In ru, this message translates to:
  /// **'Фото блюда'**
  String get wg_feature_photo_title;

  /// No description provided for @wg_feature_photo_desc.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируйте еду — ИИ распознает калории за секунды'**
  String get wg_feature_photo_desc;

  /// No description provided for @wg_feature_voice_title.
  ///
  /// In ru, this message translates to:
  /// **'Голосовой ввод'**
  String get wg_feature_voice_title;

  /// No description provided for @wg_feature_voice_desc.
  ///
  /// In ru, this message translates to:
  /// **'Продиктуйте, что съели — приложение запишет'**
  String get wg_feature_voice_desc;

  /// No description provided for @wg_feature_track_title.
  ///
  /// In ru, this message translates to:
  /// **'Трекинг прогресса'**
  String get wg_feature_track_title;

  /// No description provided for @wg_feature_track_desc.
  ///
  /// In ru, this message translates to:
  /// **'Следите за КБЖУ и видьте результат каждый день'**
  String get wg_feature_track_desc;

  /// No description provided for @wg_start_diary.
  ///
  /// In ru, this message translates to:
  /// **'Начать вести дневник'**
  String get wg_start_diary;

  /// No description provided for @wg_now.
  ///
  /// In ru, this message translates to:
  /// **'сейчас'**
  String get wg_now;

  /// No description provided for @auth_email_login_title.
  ///
  /// In ru, this message translates to:
  /// **'Вход по email'**
  String get auth_email_login_title;

  /// No description provided for @auth_register_title.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get auth_register_title;

  /// No description provided for @auth_login_subtitle.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в свой аккаунт Kayfit'**
  String get auth_login_subtitle;

  /// No description provided for @auth_register_subtitle.
  ///
  /// In ru, this message translates to:
  /// **'Создайте аккаунт, чтобы начать'**
  String get auth_register_subtitle;

  /// No description provided for @auth_tab_login.
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get auth_tab_login;

  /// No description provided for @auth_tab_register.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get auth_tab_register;

  /// No description provided for @auth_field_password.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get auth_field_password;

  /// No description provided for @auth_field_name.
  ///
  /// In ru, this message translates to:
  /// **'Имя (необязательно)'**
  String get auth_field_name;

  /// No description provided for @auth_field_confirm_password.
  ///
  /// In ru, this message translates to:
  /// **'Повторите пароль'**
  String get auth_field_confirm_password;

  /// No description provided for @auth_btn_login.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get auth_btn_login;

  /// No description provided for @auth_btn_register.
  ///
  /// In ru, this message translates to:
  /// **'Создать аккаунт'**
  String get auth_btn_register;

  /// No description provided for @auth_err_enter_password.
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get auth_err_enter_password;

  /// No description provided for @auth_err_min_password.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 8 символов'**
  String get auth_err_min_password;

  /// No description provided for @auth_err_confirm_password.
  ///
  /// In ru, this message translates to:
  /// **'Повторите пароль'**
  String get auth_err_confirm_password;

  /// No description provided for @auth_err_passwords_no_match.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get auth_err_passwords_no_match;

  /// No description provided for @auth_err_enter_email.
  ///
  /// In ru, this message translates to:
  /// **'Введите email'**
  String get auth_err_enter_email;

  /// No description provided for @auth_err_invalid_email.
  ///
  /// In ru, this message translates to:
  /// **'Некорректный email'**
  String get auth_err_invalid_email;

  /// No description provided for @auth_err_enter_value.
  ///
  /// In ru, this message translates to:
  /// **'Введите значение'**
  String get auth_err_enter_value;

  /// No description provided for @goals_title.
  ///
  /// In ru, this message translates to:
  /// **'Цели КБЖУ'**
  String get goals_title;

  /// No description provided for @goals_saved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get goals_saved;

  /// No description provided for @goals_error.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {msg}'**
  String goals_error(String msg);

  /// No description provided for @goals_err_enter_value.
  ///
  /// In ru, this message translates to:
  /// **'Введите значение'**
  String get goals_err_enter_value;

  /// No description provided for @goals_err_enter_int.
  ///
  /// In ru, this message translates to:
  /// **'Введите целое число'**
  String get goals_err_enter_int;

  /// No description provided for @dashboard_details.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее'**
  String get dashboard_details;

  /// No description provided for @dashboard_no_goals_title.
  ///
  /// In ru, this message translates to:
  /// **'Цели не настроены'**
  String get dashboard_no_goals_title;

  /// No description provided for @dashboard_no_goals_sub.
  ///
  /// In ru, this message translates to:
  /// **'Пройдите «Путь к цели» чтобы получить персональный план питания'**
  String get dashboard_no_goals_sub;

  /// No description provided for @dashboard_remaining_title.
  ///
  /// In ru, this message translates to:
  /// **'Осталось на сегодня'**
  String get dashboard_remaining_title;

  /// No description provided for @dashboard_remaining_over.
  ///
  /// In ru, this message translates to:
  /// **'Превышение'**
  String get dashboard_remaining_over;

  /// No description provided for @edit_meal_title.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать блюдо'**
  String get edit_meal_title;

  /// No description provided for @edit_meal_name_label.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get edit_meal_name_label;

  /// No description provided for @edit_meal_name_error.
  ///
  /// In ru, this message translates to:
  /// **'Введите название'**
  String get edit_meal_name_error;

  /// No description provided for @edit_meal_saved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get edit_meal_saved;

  /// No description provided for @edit_meal_error.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка: {msg}'**
  String edit_meal_error(String msg);

  /// No description provided for @edit_meal_err_enter_value.
  ///
  /// In ru, this message translates to:
  /// **'Введите значение'**
  String get edit_meal_err_enter_value;

  /// No description provided for @edit_meal_err_invalid_number.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректное число'**
  String get edit_meal_err_invalid_number;

  /// No description provided for @edit_meal_weight_label.
  ///
  /// In ru, this message translates to:
  /// **'Вес (г)'**
  String get edit_meal_weight_label;

  /// No description provided for @edit_meal_section_details.
  ///
  /// In ru, this message translates to:
  /// **'Детали'**
  String get edit_meal_section_details;

  /// No description provided for @edit_meal_section_portion.
  ///
  /// In ru, this message translates to:
  /// **'Порция'**
  String get edit_meal_section_portion;

  /// No description provided for @edit_meal_section_nutrition.
  ///
  /// In ru, this message translates to:
  /// **'Питательная ценность'**
  String get edit_meal_section_nutrition;

  /// No description provided for @addMeal_subscription_needed.
  ///
  /// In ru, this message translates to:
  /// **'Нужна подписка'**
  String get addMeal_subscription_needed;

  /// No description provided for @addMeal_subscription_desc.
  ///
  /// In ru, this message translates to:
  /// **'Распознавание еды доступно на платном тарифе. Оформите подписку чтобы пользоваться ИИ-функциями.'**
  String get addMeal_subscription_desc;

  /// No description provided for @addMeal_choose_tariff.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать тариф'**
  String get addMeal_choose_tariff;

  /// No description provided for @addMeal_close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get addMeal_close;

  /// No description provided for @addMeal_kcal.
  ///
  /// In ru, this message translates to:
  /// **'{cal} ккал'**
  String addMeal_kcal(String cal);

  /// No description provided for @addMeal_subscription_snack.
  ///
  /// In ru, this message translates to:
  /// **'Для этой функции нужна подписка'**
  String get addMeal_subscription_snack;

  /// No description provided for @addMeal_weight_hint.
  ///
  /// In ru, this message translates to:
  /// **'Вес (г)'**
  String get addMeal_weight_hint;

  /// No description provided for @addMeal_recognizing_voice.
  ///
  /// In ru, this message translates to:
  /// **'Распознаём голос...'**
  String get addMeal_recognizing_voice;

  /// No description provided for @addMeal_recognizing_photo.
  ///
  /// In ru, this message translates to:
  /// **'Анализируем фото...'**
  String get addMeal_recognizing_photo;

  /// No description provided for @addMeal_mic_denied.
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к микрофону'**
  String get addMeal_mic_denied;

  /// No description provided for @addMeal_open_settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get addMeal_open_settings;

  /// No description provided for @addMeal_barcode.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод'**
  String get addMeal_barcode;

  /// No description provided for @addMeal_barcode_desc.
  ///
  /// In ru, this message translates to:
  /// **'Сканируй — найдём продукт мгновенно'**
  String get addMeal_barcode_desc;

  /// No description provided for @addMeal_voice_tap_stop.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите ещё раз чтобы остановить'**
  String get addMeal_voice_tap_stop;

  /// No description provided for @addMeal_voice_tap_start.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите чтобы начать запись'**
  String get addMeal_voice_tap_start;

  /// No description provided for @addMeal_recognize_ai.
  ///
  /// In ru, this message translates to:
  /// **'Распознать с помощью AI'**
  String get addMeal_recognize_ai;

  /// No description provided for @addMeal_not_food_title.
  ///
  /// In ru, this message translates to:
  /// **'Еда не найдена'**
  String get addMeal_not_food_title;

  /// No description provided for @addMeal_not_food_message.
  ///
  /// In ru, this message translates to:
  /// **'На фото не удалось распознать еду. Поднесите камеру ближе к блюду и попробуйте ещё раз.'**
  String get addMeal_not_food_message;

  /// No description provided for @addMeal_not_food_retry.
  ///
  /// In ru, this message translates to:
  /// **'Попробовать ещё'**
  String get addMeal_not_food_retry;

  /// No description provided for @addMeal_saving.
  ///
  /// In ru, this message translates to:
  /// **'Сохраняем...'**
  String get addMeal_saving;

  /// No description provided for @addMeal_ai_analyzing.
  ///
  /// In ru, this message translates to:
  /// **'AI анализирует данные...'**
  String get addMeal_ai_analyzing;

  /// No description provided for @addMeal_parsing_title.
  ///
  /// In ru, this message translates to:
  /// **'Поиск в базе данных'**
  String get addMeal_parsing_title;

  /// No description provided for @addMeal_parsing_step1.
  ///
  /// In ru, this message translates to:
  /// **'Ищем в базе данных...'**
  String get addMeal_parsing_step1;

  /// No description provided for @addMeal_parsing_step2.
  ///
  /// In ru, this message translates to:
  /// **'Анализируем ингредиенты...'**
  String get addMeal_parsing_step2;

  /// No description provided for @addMeal_parsing_step3.
  ///
  /// In ru, this message translates to:
  /// **'Рассчитываем КБЖУ...'**
  String get addMeal_parsing_step3;

  /// No description provided for @addMeal_parsing_step4.
  ///
  /// In ru, this message translates to:
  /// **'Подбираем витамины и минералы...'**
  String get addMeal_parsing_step4;

  /// No description provided for @barcode_scan_hint.
  ///
  /// In ru, this message translates to:
  /// **'Наведите камеру на штрихкод'**
  String get barcode_scan_hint;

  /// No description provided for @barcode_loading.
  ///
  /// In ru, this message translates to:
  /// **'Определяем продукт...'**
  String get barcode_loading;

  /// No description provided for @barcode_manual_btn.
  ///
  /// In ru, this message translates to:
  /// **'Ввести вручную'**
  String get barcode_manual_btn;

  /// No description provided for @barcode_manual_title.
  ///
  /// In ru, this message translates to:
  /// **'Введите штрихкод'**
  String get barcode_manual_title;

  /// No description provided for @barcode_search_btn.
  ///
  /// In ru, this message translates to:
  /// **'Найти'**
  String get barcode_search_btn;

  /// No description provided for @barcode_not_found.
  ///
  /// In ru, this message translates to:
  /// **'Продукт не найден'**
  String get barcode_not_found;

  /// No description provided for @addMeal_barcode_scanning.
  ///
  /// In ru, this message translates to:
  /// **'Сканирование штрихкода'**
  String get addMeal_barcode_scanning;

  /// No description provided for @addMeal_barcode_torch_off.
  ///
  /// In ru, this message translates to:
  /// **'Выключить фонарик'**
  String get addMeal_barcode_torch_off;

  /// No description provided for @addMeal_barcode_torch_on.
  ///
  /// In ru, this message translates to:
  /// **'Включить фонарик'**
  String get addMeal_barcode_torch_on;

  /// No description provided for @addMeal_barcode_detected.
  ///
  /// In ru, this message translates to:
  /// **'Штрихкод найден'**
  String get addMeal_barcode_detected;

  /// No description provided for @addMeal_barcode_confirm.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в журнал'**
  String get addMeal_barcode_confirm;

  /// No description provided for @settings_delete_account_title.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт?'**
  String get settings_delete_account_title;

  /// No description provided for @settings_delete_account_body.
  ///
  /// In ru, this message translates to:
  /// **'Все ваши данные будут удалены без возможности восстановления. Это действие необратимо.'**
  String get settings_delete_account_body;

  /// No description provided for @settings_delete_account_btn.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт'**
  String get settings_delete_account_btn;

  /// No description provided for @settings_ai_consent.
  ///
  /// In ru, this message translates to:
  /// **'Обработка данных ИИ'**
  String get settings_ai_consent;

  /// No description provided for @settings_privacy_policy.
  ///
  /// In ru, this message translates to:
  /// **'Политика конфиденциальности'**
  String get settings_privacy_policy;

  /// No description provided for @settings_terms.
  ///
  /// In ru, this message translates to:
  /// **'Пользовательское соглашение'**
  String get settings_terms;

  /// No description provided for @settings_subscription_terms.
  ///
  /// In ru, this message translates to:
  /// **'Условия подписки'**
  String get settings_subscription_terms;

  /// No description provided for @settings_subscription_privacy.
  ///
  /// In ru, this message translates to:
  /// **'Обработка данных подписки'**
  String get settings_subscription_privacy;

  /// No description provided for @settings_sub_promo.
  ///
  /// In ru, this message translates to:
  /// **'Оформите подписку чтобы разблокировать ИИ-распознавание, голос и фото.'**
  String get settings_sub_promo;

  /// No description provided for @settings_sale_ends.
  ///
  /// In ru, this message translates to:
  /// **'Скидка заканчивается через:'**
  String get settings_sale_ends;

  /// No description provided for @settings_sub_active_badge.
  ///
  /// In ru, this message translates to:
  /// **'✓ Активна'**
  String get settings_sub_active_badge;

  /// No description provided for @tariffs_title_full.
  ///
  /// In ru, this message translates to:
  /// **'Подпишись и открой\nполный доступ'**
  String get tariffs_title_full;

  /// No description provided for @tariffs_tag1.
  ///
  /// In ru, this message translates to:
  /// **'🥕 Рекомендации по питанию'**
  String get tariffs_tag1;

  /// No description provided for @tariffs_tag2.
  ///
  /// In ru, this message translates to:
  /// **'📋 Сканер калорий'**
  String get tariffs_tag2;

  /// No description provided for @tariffs_tag3.
  ///
  /// In ru, this message translates to:
  /// **'📋 Расчет нормы'**
  String get tariffs_tag3;

  /// No description provided for @tariffs_tag4.
  ///
  /// In ru, this message translates to:
  /// **'😀 Трекер эмоций'**
  String get tariffs_tag4;

  /// No description provided for @tariffs_trial.
  ///
  /// In ru, this message translates to:
  /// **'Пробный период'**
  String get tariffs_trial;

  /// No description provided for @tariffs_monthly.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get tariffs_monthly;

  /// No description provided for @tariffs_yearly.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get tariffs_yearly;

  /// No description provided for @tariffs_quarterly.
  ///
  /// In ru, this message translates to:
  /// **'3 месяца'**
  String get tariffs_quarterly;

  /// No description provided for @tariffs_per_3days.
  ///
  /// In ru, this message translates to:
  /// **'/ 3 дня'**
  String get tariffs_per_3days;

  /// No description provided for @tariffs_per_day.
  ///
  /// In ru, this message translates to:
  /// **'/ день'**
  String get tariffs_per_day;

  /// No description provided for @tariffs_per_3mo.
  ///
  /// In ru, this message translates to:
  /// **'/ 3 мес'**
  String get tariffs_per_3mo;

  /// No description provided for @tariffs_trial_then.
  ///
  /// In ru, this message translates to:
  /// **'Затем 2 990 за год'**
  String get tariffs_trial_then;

  /// No description provided for @tariffs_monthly_billing.
  ///
  /// In ru, this message translates to:
  /// **'Ежемесячная оплата'**
  String get tariffs_monthly_billing;

  /// No description provided for @tariffs_yearly_save.
  ///
  /// In ru, this message translates to:
  /// **'2 990 ₽ / Экономия 8 890 ₽'**
  String get tariffs_yearly_save;

  /// No description provided for @tariffs_best_value.
  ///
  /// In ru, this message translates to:
  /// **'Оптимальный выбор'**
  String get tariffs_best_value;

  /// No description provided for @tariffs_no_discount.
  ///
  /// In ru, this message translates to:
  /// **'Без скидки {price}'**
  String tariffs_no_discount(String price);

  /// No description provided for @tariffs_no_plans.
  ///
  /// In ru, this message translates to:
  /// **'Тарифы пока не настроены'**
  String get tariffs_no_plans;

  /// No description provided for @tariffs_cancel_anytime.
  ///
  /// In ru, this message translates to:
  /// **'Подписку можно отменить в любой удобный момент в Личном кабинете'**
  String get tariffs_cancel_anytime;

  /// No description provided for @tariffs_optimal_months.
  ///
  /// In ru, this message translates to:
  /// **'Оптимальный результат достигается через 3 месяца'**
  String get tariffs_optimal_months;

  /// No description provided for @tariffs_email_hint.
  ///
  /// In ru, this message translates to:
  /// **'Email для чека'**
  String get tariffs_email_hint;

  /// No description provided for @tariffs_email_error.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный email'**
  String get tariffs_email_error;

  /// No description provided for @tariffs_pay_error.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось создать платёж. Попробуйте ещё раз.'**
  String get tariffs_pay_error;

  /// No description provided for @tariffs_get_plan.
  ///
  /// In ru, this message translates to:
  /// **'Получить мой план'**
  String get tariffs_get_plan;

  /// No description provided for @tariffs_load_error.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить тарифы'**
  String get tariffs_load_error;

  /// No description provided for @tariffs_sale_ends.
  ///
  /// In ru, this message translates to:
  /// **'СКИДКА ЗАКАНЧИВАЕТСЯ ЧЕРЕЗ'**
  String get tariffs_sale_ends;

  /// No description provided for @tariffs_benefit1.
  ///
  /// In ru, this message translates to:
  /// **'🥗 Консультация с нутрициологом'**
  String get tariffs_benefit1;

  /// No description provided for @tariffs_benefit2.
  ///
  /// In ru, this message translates to:
  /// **'🎥 Видео рецепты'**
  String get tariffs_benefit2;

  /// No description provided for @tariffs_benefit3.
  ///
  /// In ru, this message translates to:
  /// **'🍽️ План питания'**
  String get tariffs_benefit3;

  /// No description provided for @tariffs_benefit4.
  ///
  /// In ru, this message translates to:
  /// **'📋 Гайд по питанию'**
  String get tariffs_benefit4;

  /// No description provided for @tariffs_payment_title.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get tariffs_payment_title;

  /// No description provided for @nav_chat.
  ///
  /// In ru, this message translates to:
  /// **'ИИ Чат'**
  String get nav_chat;

  /// No description provided for @chat_title.
  ///
  /// In ru, this message translates to:
  /// **'ИИ Нутрициолог'**
  String get chat_title;

  /// No description provided for @chat_input_hint.
  ///
  /// In ru, this message translates to:
  /// **'Спросите о питании...'**
  String get chat_input_hint;

  /// No description provided for @chat_clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить чат'**
  String get chat_clear;

  /// No description provided for @chat_clear_confirm.
  ///
  /// In ru, this message translates to:
  /// **'Удалить всю историю чата?'**
  String get chat_clear_confirm;

  /// No description provided for @chat_error.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить сообщение'**
  String get chat_error;

  /// No description provided for @chat_empty.
  ///
  /// In ru, this message translates to:
  /// **'Спросите меня о питании, диете или прогрессе!'**
  String get chat_empty;

  /// No description provided for @chat_suggestion_1.
  ///
  /// In ru, this message translates to:
  /// **'🥗 Что съесть на обед при дефиците?'**
  String get chat_suggestion_1;

  /// No description provided for @chat_suggestion_2.
  ///
  /// In ru, this message translates to:
  /// **'💪 Норма белка для похудения'**
  String get chat_suggestion_2;

  /// No description provided for @chat_suggestion_3.
  ///
  /// In ru, this message translates to:
  /// **'🌙 Можно ли есть после 18:00?'**
  String get chat_suggestion_3;

  /// No description provided for @recogV2_composition.
  ///
  /// In ru, this message translates to:
  /// **'СОСТАВ'**
  String get recogV2_composition;

  /// No description provided for @recogV2_meal_type.
  ///
  /// In ru, this message translates to:
  /// **'ТИП ПРИЁМА ПИЩИ'**
  String get recogV2_meal_type;

  /// No description provided for @recogV2_saving.
  ///
  /// In ru, this message translates to:
  /// **'Сохранение...'**
  String get recogV2_saving;

  /// No description provided for @recogV2_add_breakfast.
  ///
  /// In ru, this message translates to:
  /// **'Добавить завтрак'**
  String get recogV2_add_breakfast;

  /// No description provided for @recogV2_add_lunch.
  ///
  /// In ru, this message translates to:
  /// **'Добавить обед'**
  String get recogV2_add_lunch;

  /// No description provided for @recogV2_add_dinner.
  ///
  /// In ru, this message translates to:
  /// **'Добавить ужин'**
  String get recogV2_add_dinner;

  /// No description provided for @recogV2_add_snack.
  ///
  /// In ru, this message translates to:
  /// **'Добавить перекус'**
  String get recogV2_add_snack;

  /// No description provided for @recogV2_add_meal.
  ///
  /// In ru, this message translates to:
  /// **'Добавить приём пищи'**
  String get recogV2_add_meal;

  /// No description provided for @recogV2_macros.
  ///
  /// In ru, this message translates to:
  /// **'МАКРОНУТРИЕНТЫ'**
  String get recogV2_macros;

  /// No description provided for @recogV2_carbs_detail.
  ///
  /// In ru, this message translates to:
  /// **'УГЛЕВОДЫ ДЕТАЛЬНО'**
  String get recogV2_carbs_detail;

  /// No description provided for @recogV2_net_carbs.
  ///
  /// In ru, this message translates to:
  /// **'Чистые углеводы'**
  String get recogV2_net_carbs;

  /// No description provided for @recogV2_fiber.
  ///
  /// In ru, this message translates to:
  /// **'Клетчатка'**
  String get recogV2_fiber;

  /// No description provided for @recogV2_sugar_alcohols.
  ///
  /// In ru, this message translates to:
  /// **'Сахарные спирты'**
  String get recogV2_sugar_alcohols;

  /// No description provided for @recogV2_fats_detail.
  ///
  /// In ru, this message translates to:
  /// **'ЖИРЫ ДЕТАЛЬНО'**
  String get recogV2_fats_detail;

  /// No description provided for @recogV2_sat_fat.
  ///
  /// In ru, this message translates to:
  /// **'Насыщенные'**
  String get recogV2_sat_fat;

  /// No description provided for @recogV2_mono_fat.
  ///
  /// In ru, this message translates to:
  /// **'Мононенасыщенные'**
  String get recogV2_mono_fat;

  /// No description provided for @recogV2_poly_fat.
  ///
  /// In ru, this message translates to:
  /// **'Полиненасыщенные'**
  String get recogV2_poly_fat;

  /// No description provided for @recogV2_micro.
  ///
  /// In ru, this message translates to:
  /// **'МИКРОНУТРИЕНТЫ'**
  String get recogV2_micro;

  /// No description provided for @recogV2_sodium.
  ///
  /// In ru, this message translates to:
  /// **'Натрий'**
  String get recogV2_sodium;

  /// No description provided for @recogV2_cholesterol.
  ///
  /// In ru, this message translates to:
  /// **'Холестерин'**
  String get recogV2_cholesterol;

  /// No description provided for @recogV2_potassium.
  ///
  /// In ru, this message translates to:
  /// **'Калий'**
  String get recogV2_potassium;

  /// No description provided for @recogV2_mg.
  ///
  /// In ru, this message translates to:
  /// **'мг'**
  String get recogV2_mg;

  /// No description provided for @recogV2_gi_low.
  ///
  /// In ru, this message translates to:
  /// **'низкий'**
  String get recogV2_gi_low;

  /// No description provided for @recogV2_gi_medium.
  ///
  /// In ru, this message translates to:
  /// **'средний'**
  String get recogV2_gi_medium;

  /// No description provided for @recogV2_gi_high.
  ///
  /// In ru, this message translates to:
  /// **'высокий'**
  String get recogV2_gi_high;

  /// No description provided for @recogV2_gi_label.
  ///
  /// In ru, this message translates to:
  /// **'ГИ'**
  String get recogV2_gi_label;

  /// No description provided for @recogV2_search_ingredient.
  ///
  /// In ru, this message translates to:
  /// **'Поиск ингредиента'**
  String get recogV2_search_ingredient;

  /// No description provided for @recogV2_search_hint.
  ///
  /// In ru, this message translates to:
  /// **'Например: куриная грудка'**
  String get recogV2_search_hint;

  /// No description provided for @recogV2_correct_btn.
  ///
  /// In ru, this message translates to:
  /// **'Скорректировать'**
  String get recogV2_correct_btn;

  /// No description provided for @recogV2_correct_hint.
  ///
  /// In ru, this message translates to:
  /// **'Что изменить? Например: котлеты из индейки, а не курицы'**
  String get recogV2_correct_hint;

  /// No description provided for @recogV2_correct_title.
  ///
  /// In ru, this message translates to:
  /// **'Корректировка'**
  String get recogV2_correct_title;

  /// No description provided for @recogV2_correct_send.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get recogV2_correct_send;

  /// No description provided for @recogV2_correct_loading.
  ///
  /// In ru, this message translates to:
  /// **'Обновляем состав...'**
  String get recogV2_correct_loading;

  /// No description provided for @nds_section_basic.
  ///
  /// In ru, this message translates to:
  /// **'Основные'**
  String get nds_section_basic;

  /// No description provided for @nds_section_carbs_detail.
  ///
  /// In ru, this message translates to:
  /// **'Углеводы детально'**
  String get nds_section_carbs_detail;

  /// No description provided for @nds_section_fats_detail.
  ///
  /// In ru, this message translates to:
  /// **'Жиры детально'**
  String get nds_section_fats_detail;

  /// No description provided for @nds_section_minerals.
  ///
  /// In ru, this message translates to:
  /// **'Минералы'**
  String get nds_section_minerals;

  /// No description provided for @nds_section_vitamins.
  ///
  /// In ru, this message translates to:
  /// **'Витамины'**
  String get nds_section_vitamins;

  /// No description provided for @nds_nutrient_calories.
  ///
  /// In ru, this message translates to:
  /// **'Калории'**
  String get nds_nutrient_calories;

  /// No description provided for @nds_nutrient_protein.
  ///
  /// In ru, this message translates to:
  /// **'Белки'**
  String get nds_nutrient_protein;

  /// No description provided for @nds_nutrient_fat.
  ///
  /// In ru, this message translates to:
  /// **'Жиры'**
  String get nds_nutrient_fat;

  /// No description provided for @nds_nutrient_carbs.
  ///
  /// In ru, this message translates to:
  /// **'Углеводы'**
  String get nds_nutrient_carbs;

  /// No description provided for @nds_nutrient_fiber.
  ///
  /// In ru, this message translates to:
  /// **'Клетчатка'**
  String get nds_nutrient_fiber;

  /// No description provided for @nds_nutrient_sugar_alcohols.
  ///
  /// In ru, this message translates to:
  /// **'Сахарные спирты'**
  String get nds_nutrient_sugar_alcohols;

  /// No description provided for @nds_nutrient_net_carbs.
  ///
  /// In ru, this message translates to:
  /// **'Чистые углеводы'**
  String get nds_nutrient_net_carbs;

  /// No description provided for @nds_nutrient_gi.
  ///
  /// In ru, this message translates to:
  /// **'Гликемич. индекс'**
  String get nds_nutrient_gi;

  /// No description provided for @nds_nutrient_sat_fat.
  ///
  /// In ru, this message translates to:
  /// **'Насыщенные'**
  String get nds_nutrient_sat_fat;

  /// No description provided for @nds_nutrient_mono_fat.
  ///
  /// In ru, this message translates to:
  /// **'Мононенасыщенные'**
  String get nds_nutrient_mono_fat;

  /// No description provided for @nds_nutrient_poly_fat.
  ///
  /// In ru, this message translates to:
  /// **'Полиненасыщенные'**
  String get nds_nutrient_poly_fat;

  /// No description provided for @nds_nutrient_sodium.
  ///
  /// In ru, this message translates to:
  /// **'Натрий'**
  String get nds_nutrient_sodium;

  /// No description provided for @nds_nutrient_cholesterol.
  ///
  /// In ru, this message translates to:
  /// **'Холестерин'**
  String get nds_nutrient_cholesterol;

  /// No description provided for @nds_nutrient_potassium.
  ///
  /// In ru, this message translates to:
  /// **'Калий'**
  String get nds_nutrient_potassium;

  /// No description provided for @nds_nutrient_calcium.
  ///
  /// In ru, this message translates to:
  /// **'Кальций'**
  String get nds_nutrient_calcium;

  /// No description provided for @nds_nutrient_iron.
  ///
  /// In ru, this message translates to:
  /// **'Железо'**
  String get nds_nutrient_iron;

  /// No description provided for @nds_nutrient_vitamin_a.
  ///
  /// In ru, this message translates to:
  /// **'Витамин A'**
  String get nds_nutrient_vitamin_a;

  /// No description provided for @nds_nutrient_vitamin_c.
  ///
  /// In ru, this message translates to:
  /// **'Витамин C'**
  String get nds_nutrient_vitamin_c;

  /// No description provided for @nds_nutrient_vitamin_d.
  ///
  /// In ru, this message translates to:
  /// **'Витамин D'**
  String get nds_nutrient_vitamin_d;

  /// No description provided for @nds_gi_low.
  ///
  /// In ru, this message translates to:
  /// **'низкий'**
  String get nds_gi_low;

  /// No description provided for @nds_gi_medium.
  ///
  /// In ru, this message translates to:
  /// **'средний'**
  String get nds_gi_medium;

  /// No description provided for @nds_gi_high.
  ///
  /// In ru, this message translates to:
  /// **'высокий'**
  String get nds_gi_high;

  /// No description provided for @nds_source_cache.
  ///
  /// In ru, this message translates to:
  /// **'Кэш'**
  String get nds_source_cache;

  /// No description provided for @nds_unit_kcal.
  ///
  /// In ru, this message translates to:
  /// **'ккал'**
  String get nds_unit_kcal;

  /// No description provided for @nds_unit_g.
  ///
  /// In ru, this message translates to:
  /// **'г'**
  String get nds_unit_g;

  /// No description provided for @nds_unit_mg.
  ///
  /// In ru, this message translates to:
  /// **'мг'**
  String get nds_unit_mg;

  /// No description provided for @nds_unit_mcg.
  ///
  /// In ru, this message translates to:
  /// **'мкг'**
  String get nds_unit_mcg;

  /// No description provided for @nds_per100g.
  ///
  /// In ru, this message translates to:
  /// **'/100г'**
  String get nds_per100g;

  /// No description provided for @nds_weight_g.
  ///
  /// In ru, this message translates to:
  /// **'{w} г'**
  String nds_weight_g(String w);

  /// No description provided for @nutrient_details_title.
  ///
  /// In ru, this message translates to:
  /// **'ПОДРОБНОСТИ'**
  String get nutrient_details_title;

  /// No description provided for @nutrient_weight.
  ///
  /// In ru, this message translates to:
  /// **'Вес'**
  String get nutrient_weight;

  /// No description provided for @nutrient_net_carbs.
  ///
  /// In ru, this message translates to:
  /// **'Чистые углеводы'**
  String get nutrient_net_carbs;

  /// No description provided for @nutrient_fiber.
  ///
  /// In ru, this message translates to:
  /// **'Клетчатка'**
  String get nutrient_fiber;

  /// No description provided for @nutrient_sugar.
  ///
  /// In ru, this message translates to:
  /// **'Сахар'**
  String get nutrient_sugar;

  /// No description provided for @nutrient_sugar_alcohols.
  ///
  /// In ru, this message translates to:
  /// **'Сахарные спирты'**
  String get nutrient_sugar_alcohols;

  /// No description provided for @nutrient_glycemic_index.
  ///
  /// In ru, this message translates to:
  /// **'Гликемический индекс'**
  String get nutrient_glycemic_index;

  /// No description provided for @nutrient_saturated_fat.
  ///
  /// In ru, this message translates to:
  /// **'Насыщ. жиры'**
  String get nutrient_saturated_fat;

  /// No description provided for @nutrient_unsaturated_fat.
  ///
  /// In ru, this message translates to:
  /// **'Ненасыщ. жиры'**
  String get nutrient_unsaturated_fat;

  /// No description provided for @nutrient_cholesterol.
  ///
  /// In ru, this message translates to:
  /// **'Холестерин'**
  String get nutrient_cholesterol;

  /// No description provided for @nutrient_sodium.
  ///
  /// In ru, this message translates to:
  /// **'Натрий'**
  String get nutrient_sodium;

  /// No description provided for @nutrient_potassium.
  ///
  /// In ru, this message translates to:
  /// **'Калий'**
  String get nutrient_potassium;

  /// No description provided for @nutrient_calcium.
  ///
  /// In ru, this message translates to:
  /// **'Кальций'**
  String get nutrient_calcium;

  /// No description provided for @nutrient_iron.
  ///
  /// In ru, this message translates to:
  /// **'Железо'**
  String get nutrient_iron;

  /// No description provided for @nutrient_vitamin_a.
  ///
  /// In ru, this message translates to:
  /// **'Витамин A'**
  String get nutrient_vitamin_a;

  /// No description provided for @nutrient_vitamin_c.
  ///
  /// In ru, this message translates to:
  /// **'Витамин C'**
  String get nutrient_vitamin_c;

  /// No description provided for @nutrient_vitamin_d.
  ///
  /// In ru, this message translates to:
  /// **'Витамин D'**
  String get nutrient_vitamin_d;

  /// No description provided for @nutrient_vitamin_b12.
  ///
  /// In ru, this message translates to:
  /// **'Витамин B12'**
  String get nutrient_vitamin_b12;

  /// No description provided for @nutrient_mg.
  ///
  /// In ru, this message translates to:
  /// **'мг'**
  String get nutrient_mg;

  /// No description provided for @nutrient_mcg.
  ///
  /// In ru, this message translates to:
  /// **'мкг'**
  String get nutrient_mcg;

  /// No description provided for @mealGroup_itemsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count} блюд'**
  String mealGroup_itemsCount(int count);

  /// No description provided for @paywall_headline.
  ///
  /// In ru, this message translates to:
  /// **'ИИ считает калории.\nТы просто ешь.'**
  String get paywall_headline;

  /// No description provided for @paywall_subtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сфотографируй тарелку, скажи голосом или спроси нутрициолога — KayFit запишет всё сам.'**
  String get paywall_subtitle;

  /// No description provided for @paywall_feature_photo_title.
  ///
  /// In ru, this message translates to:
  /// **'Фото → КБЖУ за секунды'**
  String get paywall_feature_photo_title;

  /// No description provided for @paywall_feature_photo_sub.
  ///
  /// In ru, this message translates to:
  /// **'ИИ определяет ингредиенты и вес порции'**
  String get paywall_feature_photo_sub;

  /// No description provided for @paywall_feature_voice_title.
  ///
  /// In ru, this message translates to:
  /// **'Скажи вслух'**
  String get paywall_feature_voice_title;

  /// No description provided for @paywall_feature_voice_sub.
  ///
  /// In ru, this message translates to:
  /// **'«Съел куриный плов» → залогировано сразу'**
  String get paywall_feature_voice_sub;

  /// No description provided for @paywall_feature_chat_title.
  ///
  /// In ru, this message translates to:
  /// **'Нутрициолог в кармане'**
  String get paywall_feature_chat_title;

  /// No description provided for @paywall_feature_chat_sub.
  ///
  /// In ru, this message translates to:
  /// **'Спроси о питании — ответит и запишет'**
  String get paywall_feature_chat_sub;

  /// No description provided for @paywall_plan_trial_title.
  ///
  /// In ru, this message translates to:
  /// **'СТАРТ\n7 дней 🆓'**
  String get paywall_plan_trial_title;

  /// No description provided for @paywall_plan_monthly_title.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get paywall_plan_monthly_title;

  /// No description provided for @paywall_plan_quarterly_title.
  ///
  /// In ru, this message translates to:
  /// **'3 месяца'**
  String get paywall_plan_quarterly_title;

  /// No description provided for @paywall_plan_quarterly_badge.
  ///
  /// In ru, this message translates to:
  /// **'★ ЛУЧШИЙ'**
  String get paywall_plan_quarterly_badge;

  /// No description provided for @paywall_plan_yearly_title.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get paywall_plan_yearly_title;

  /// No description provided for @paywall_plan_yearly_badge.
  ///
  /// In ru, this message translates to:
  /// **'🔥 −40%'**
  String get paywall_plan_yearly_badge;

  /// No description provided for @paywall_cta_trial.
  ///
  /// In ru, this message translates to:
  /// **'Начать 7 дней бесплатно'**
  String get paywall_cta_trial;

  /// No description provided for @paywall_cta_buy.
  ///
  /// In ru, this message translates to:
  /// **'Подписаться'**
  String get paywall_cta_buy;

  /// No description provided for @paywall_trial_note.
  ///
  /// In ru, this message translates to:
  /// **'Отменить до конца 7 дней — ничего не спишется'**
  String get paywall_trial_note;

  /// No description provided for @paywall_dismiss.
  ///
  /// In ru, this message translates to:
  /// **'Нет, буду вводить руками'**
  String get paywall_dismiss;

  /// No description provided for @paywall_restore.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get paywall_restore;

  /// No description provided for @paywall_terms.
  ///
  /// In ru, this message translates to:
  /// **'Условия'**
  String get paywall_terms;

  /// No description provided for @paywall_privacy.
  ///
  /// In ru, this message translates to:
  /// **'Политика'**
  String get paywall_privacy;

  /// No description provided for @paywall_pending_snack.
  ///
  /// In ru, this message translates to:
  /// **'Платёж обрабатывается. Попробуйте позже.'**
  String get paywall_pending_snack;

  /// No description provided for @paywall_error_snack.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка покупки. Попробуйте ещё раз.'**
  String get paywall_error_snack;

  /// No description provided for @paywall_restored_snack.
  ///
  /// In ru, this message translates to:
  /// **'Подписка восстановлена'**
  String get paywall_restored_snack;

  /// No description provided for @paywall_no_restore_snack.
  ///
  /// In ru, this message translates to:
  /// **'Активная подписка не найдена'**
  String get paywall_no_restore_snack;

  /// No description provided for @paywall_restore_error_snack.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка восстановления. Попробуйте ещё раз.'**
  String get paywall_restore_error_snack;

  /// No description provided for @item_enter_nutrition_manually.
  ///
  /// In ru, this message translates to:
  /// **'Введите КБЖУ вручную'**
  String get item_enter_nutrition_manually;

  /// No description provided for @mealType_breakfast.
  ///
  /// In ru, this message translates to:
  /// **'Завтрак'**
  String get mealType_breakfast;

  /// No description provided for @mealType_lunch.
  ///
  /// In ru, this message translates to:
  /// **'Обед'**
  String get mealType_lunch;

  /// No description provided for @mealType_dinner.
  ///
  /// In ru, this message translates to:
  /// **'Ужин'**
  String get mealType_dinner;

  /// No description provided for @mealType_snack.
  ///
  /// In ru, this message translates to:
  /// **'Перекус'**
  String get mealType_snack;

  /// No description provided for @mealType_other.
  ///
  /// In ru, this message translates to:
  /// **'Другое'**
  String get mealType_other;

  /// No description provided for @macro_net_carbs_abbr.
  ///
  /// In ru, this message translates to:
  /// **'Чист.У'**
  String get macro_net_carbs_abbr;

  /// No description provided for @macro_sat_fat_short.
  ///
  /// In ru, this message translates to:
  /// **'Нас.ж'**
  String get macro_sat_fat_short;

  /// No description provided for @macro_good_fat_short.
  ///
  /// In ru, this message translates to:
  /// **'Ненас.ж'**
  String get macro_good_fat_short;

  /// No description provided for @gi_low_badge.
  ///
  /// In ru, this message translates to:
  /// **'Низк. ГИ'**
  String get gi_low_badge;

  /// No description provided for @gi_medium_badge.
  ///
  /// In ru, this message translates to:
  /// **'Сред. ГИ'**
  String get gi_medium_badge;

  /// No description provided for @gi_high_badge.
  ///
  /// In ru, this message translates to:
  /// **'Выс. ГИ'**
  String get gi_high_badge;

  /// No description provided for @journal_day_total.
  ///
  /// In ru, this message translates to:
  /// **'ИТОГО'**
  String get journal_day_total;

  /// No description provided for @journal_more_nutrients.
  ///
  /// In ru, this message translates to:
  /// **'Ещё нутриенты'**
  String get journal_more_nutrients;

  /// No description provided for @journal_hide_nutrients.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть'**
  String get journal_hide_nutrients;

  /// No description provided for @meal_group_extended.
  ///
  /// In ru, this message translates to:
  /// **'СОСТАВ'**
  String get meal_group_extended;

  /// No description provided for @dashboard_kcal_left.
  ///
  /// In ru, this message translates to:
  /// **'ккал до цели'**
  String get dashboard_kcal_left;

  /// No description provided for @dashboard_kcal_over.
  ///
  /// In ru, this message translates to:
  /// **'ккал сверх нормы'**
  String get dashboard_kcal_over;

  /// No description provided for @stats_fiber.
  ///
  /// In ru, this message translates to:
  /// **'Клетчатка'**
  String get stats_fiber;

  /// No description provided for @stats_sodium.
  ///
  /// In ru, this message translates to:
  /// **'Натрий'**
  String get stats_sodium;

  /// No description provided for @stats_hide_details.
  ///
  /// In ru, this message translates to:
  /// **'Скрыть детали'**
  String get stats_hide_details;

  /// No description provided for @stats_show_details.
  ///
  /// In ru, this message translates to:
  /// **'Подробнее'**
  String get stats_show_details;

  /// No description provided for @stats_mifflin_disclaimer.
  ///
  /// In ru, this message translates to:
  /// **'На основе формулы Mifflin-St Jeor. Не является медицинской рекомендацией.'**
  String get stats_mifflin_disclaimer;

  /// No description provided for @edit_meal_macros_label.
  ///
  /// In ru, this message translates to:
  /// **'КБЖУ'**
  String get edit_meal_macros_label;

  /// No description provided for @edit_meal_weight_short.
  ///
  /// In ru, this message translates to:
  /// **'Вес'**
  String get edit_meal_weight_short;

  /// No description provided for @nds_nutrient_vit_c_short.
  ///
  /// In ru, this message translates to:
  /// **'Вит. C'**
  String get nds_nutrient_vit_c_short;

  /// No description provided for @nds_nutrient_vit_d_short.
  ///
  /// In ru, this message translates to:
  /// **'Вит. D'**
  String get nds_nutrient_vit_d_short;

  /// No description provided for @journal_meal_deleted.
  ///
  /// In ru, this message translates to:
  /// **'Приём пищи удалён'**
  String get journal_meal_deleted;

  /// No description provided for @journal_could_not_delete.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось удалить'**
  String get journal_could_not_delete;

  /// No description provided for @journal_could_not_update_weight.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обновить вес'**
  String get journal_could_not_update_weight;

  /// No description provided for @journal_meal_actions.
  ///
  /// In ru, this message translates to:
  /// **'Действия с приёмом пищи'**
  String get journal_meal_actions;

  /// No description provided for @journal_copy_date.
  ///
  /// In ru, this message translates to:
  /// **'Дата копии'**
  String get journal_copy_date;

  /// No description provided for @journal_copy_btn.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get journal_copy_btn;

  /// No description provided for @journal_copied_to.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано на {date}'**
  String journal_copied_to(String date);

  /// No description provided for @journal_open_btn.
  ///
  /// In ru, this message translates to:
  /// **'Перейти'**
  String get journal_open_btn;

  /// No description provided for @journal_could_not_copy.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось скопировать'**
  String get journal_could_not_copy;

  /// No description provided for @journal_copy_to_another_date.
  ///
  /// In ru, this message translates to:
  /// **'Копировать на другую дату'**
  String get journal_copy_to_another_date;

  /// No description provided for @journal_disclaimer.
  ///
  /// In ru, this message translates to:
  /// **'Расчёты КБЖУ — ориентировочные. Не заменяют консультацию врача.'**
  String get journal_disclaimer;

  /// No description provided for @nav_add.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get nav_add;

  /// No description provided for @cal_on_track.
  ///
  /// In ru, this message translates to:
  /// **'в норме'**
  String get cal_on_track;

  /// No description provided for @cal_over_goal.
  ///
  /// In ru, this message translates to:
  /// **'превышение'**
  String get cal_over_goal;

  /// No description provided for @cal_empty.
  ///
  /// In ru, this message translates to:
  /// **'нет данных'**
  String get cal_empty;

  /// No description provided for @session_expired.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Войдите снова.'**
  String get session_expired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
