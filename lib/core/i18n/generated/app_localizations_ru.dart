// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Kayfit';

  @override
  String get nav_today => 'Сегодня';

  @override
  String get nav_journal => 'Журнал';

  @override
  String get nav_settings => 'Настройки';

  @override
  String get common_save => 'Сохранить';

  @override
  String get common_cancel => 'Отмена';

  @override
  String get common_delete => 'Удалить';

  @override
  String get common_edit => 'Редактировать';

  @override
  String get meal_details_full => 'Подробный состав';

  @override
  String get common_loading => 'Загрузка...';

  @override
  String get common_error => 'Ошибка';

  @override
  String get common_retry => 'Повторить';

  @override
  String get common_next => 'Далее';

  @override
  String get common_back => 'Назад';

  @override
  String get common_done => 'Готово';

  @override
  String get common_skip => 'Пропустить';

  @override
  String get common_stop => 'Стоп';

  @override
  String get macro_calories => 'Калории';

  @override
  String get macro_protein => 'Белки';

  @override
  String get macro_fat => 'Жиры';

  @override
  String get macro_carbs => 'Углеводы';

  @override
  String get macro_protein_abbr => 'Б';

  @override
  String get macro_fat_abbr => 'Ж';

  @override
  String get macro_carbs_abbr => 'У';

  @override
  String get macro_kcal => 'ккал';

  @override
  String get macro_g => 'г';

  @override
  String get recognition_save_to_journal => 'Сохранить в журнал';

  @override
  String get recognition_items_label => 'ИНГРЕДИЕНТЫ · НАЖМИТЕ ✏ ДЛЯ ПРАВКИ';

  @override
  String get macro_eaten => 'съедено';

  @override
  String get macro_remaining => 'осталось';

  @override
  String get macro_goal => 'цель';

  @override
  String get dashboard_title => 'Сегодня';

  @override
  String get dashboard_addMeal => 'Добавить приём пищи';

  @override
  String get dashboard_noMeals => 'Нет записей за сегодня';

  @override
  String get dashboard_personal_plan_title => 'Ваш персональный план';

  @override
  String dashboard_personal_plan_sub(int kcal) {
    return 'Цель: $kcal ккал/день · Нажмите для просмотра';
  }

  @override
  String dashboard_compulsive(int count) {
    return 'Компульсивных приёмов: $count';
  }

  @override
  String get journal_title => 'Журнал';

  @override
  String get journal_empty => 'История пуста';

  @override
  String get journal_ai_banner_title => 'ИИ-нутрициолог';

  @override
  String get journal_ai_banner_sub =>
      'Поможет с выбором блюд и расчётом КБЖУ на день';

  @override
  String get journal_ai_banner_btn => 'Спросить';

  @override
  String get settings_title => 'Настройки';

  @override
  String get settings_profile => 'Профиль';

  @override
  String get settings_language => 'Язык';

  @override
  String get settings_subscription => 'Подписка';

  @override
  String get settings_logout => 'Выйти';

  @override
  String get settings_langRu => 'Русский';

  @override
  String get settings_langEn => 'English';

  @override
  String get settings_goals => 'Цели КБЖУ';

  @override
  String get addMeal_title => 'Добавить блюдо';

  @override
  String get addMeal_text => 'Текстом';

  @override
  String get addMeal_voice => 'Голосом';

  @override
  String get addMeal_photo => 'Фото';

  @override
  String get addMeal_manual => 'Вручную';

  @override
  String get addMeal_emotionTitle => 'Как вы себя чувствуете?';

  @override
  String get addMeal_inputHint => 'Опишите что съели...';

  @override
  String get addMeal_parsing => 'Распознаём...';

  @override
  String get addMeal_selectItems => 'Выберите блюда';

  @override
  String get addMeal_add => 'Добавить';

  @override
  String get addMeal_recording => 'Идёт запись...';

  @override
  String get addMeal_stopRecording => 'Остановить';

  @override
  String get addMeal_transcribing => 'Распознаём речь...';

  @override
  String get addMeal_takePhoto => 'Сделать фото';

  @override
  String get addMeal_choosePhoto => 'Выбрать из галереи';

  @override
  String get addMeal_recognizing => 'Распознаём...';

  @override
  String meal_calories(double cal) {
    final intl.NumberFormat calNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String calString = calNumberFormat.format(cal);

    return '$calString ккал';
  }

  @override
  String meal_macros(double p, double f, double c) {
    return 'Б: $pг  Ж: $fг  У: $cг';
  }

  @override
  String get emotion_happy => 'Радость';

  @override
  String get emotion_calm => 'Спокойствие';

  @override
  String get emotion_sad => 'Грусть';

  @override
  String get emotion_anxious => 'Тревога';

  @override
  String get emotion_tired => 'Усталость';

  @override
  String get emotion_hungry => 'Голод';

  @override
  String get emotion_bored => 'Скука';

  @override
  String get emotion_angry => 'Злость';

  @override
  String get emotion_worried => 'Беспокойство';

  @override
  String get emotion_neutral => 'Нейтральность';

  @override
  String get emotion_other => 'Другое';

  @override
  String get ob_landing_title1 => 'Худей';

  @override
  String get ob_landing_title2 => 'просто';

  @override
  String get ob_landing_sub =>
      'Сфотографируй или опиши голосом еду — AI посчитает калории';

  @override
  String get ob_landing_cta => 'Попробовать сейчас';

  @override
  String get ob_landing_cta_sub1 => 'Персональный план';

  @override
  String get ob_landing_cta_sub2 => 'меньше минуты';

  @override
  String get ob_skip_btn => 'Пропустить';

  @override
  String get ob_skip_title => 'Пропустить шаг?';

  @override
  String get ob_skip_sub => 'Без этих данных расчёт будет менее точным.';

  @override
  String get ob_skip_continue => 'Продолжить без данных';

  @override
  String get ob_skip_back => 'Вернуться';

  @override
  String get ob_step_age_title => 'Ваш возраст?';

  @override
  String get ob_step_age_hint =>
      'Возраст влияет на расчёт базового обмена веществ';

  @override
  String get ob_step_height_title => 'Ваш рост?';

  @override
  String get ob_step_height_hint =>
      'Рост помогает рассчитать базовый обмен веществ';

  @override
  String get ob_step_height_unit => 'сантиметры';

  @override
  String get ob_step_gender_title => 'Ваш пол?';

  @override
  String get ob_step_gender_hint => 'Пол учитывается в формуле Миффлина';

  @override
  String get ob_step_gender_female => 'Женщина';

  @override
  String get ob_step_gender_male => 'Мужчина';

  @override
  String get ob_step_weight_title => 'Ваш вес?';

  @override
  String get ob_step_weight_hint =>
      'Текущий и желаемый вес для расчёта дефицита калорий';

  @override
  String get ob_step_weight_now => 'Сейчас';

  @override
  String get ob_step_weight_goal => 'Цель';

  @override
  String get ob_step_training_title => 'Сколько дней в неделю вы тренируетесь?';

  @override
  String get ob_step_training_sub =>
      'Это поможет точнее рассчитать суточную активность';

  @override
  String get ob_training_0 => 'Не тренируюсь';

  @override
  String get ob_training_1_2 => '1–2 дня';

  @override
  String get ob_training_3_4 => '3–4 дня';

  @override
  String get ob_training_daily => 'Каждый день';

  @override
  String get ob_method_title => 'Как добавить еду?';

  @override
  String get ob_method_sub => 'Выбери удобный способ — AI распознает КБЖУ';

  @override
  String get ob_method_photo_title => 'Фото еды';

  @override
  String get ob_method_photo_desc =>
      'Сфотографируй блюдо — AI определит состав за 5 сек';

  @override
  String get ob_method_voice_title => 'Голосом';

  @override
  String get ob_method_voice_desc => '«Съел борщ 300 мл» — просто скажи';

  @override
  String get ob_method_text_title => 'Текстом';

  @override
  String get ob_method_text_desc => 'Напиши что съел — AI посчитает калории';

  @override
  String get ob_method_note => 'Все способы работают быстро и точно';

  @override
  String get ob_demo_perks_title => 'Что ты получишь в Kayfit:';

  @override
  String get ob_demo_perk1 => 'Фото еды → AI распознает КБЖУ';

  @override
  String get ob_demo_perk2 => 'Голосом: «Съел борщ» — и готово';

  @override
  String get ob_demo_perk3 => 'История питания и прогресс';

  @override
  String get ob_demo_perk4 => 'Рекомендации по питанию от ИИ';

  @override
  String get ob_result_title => 'Ваш персональный план';

  @override
  String get ob_result_sub => 'Расчёт на основе вашего профиля';

  @override
  String get ob_result_kcalday => 'ккал/день';

  @override
  String get ob_result_accuracy => 'Оценка с помощью ИИ';

  @override
  String get ob_result_next_title => 'Следующий шаг';

  @override
  String get ob_result_next_text =>
      'Войдите, чтобы сохранить план и начать отслеживать питание.';

  @override
  String get ob_err_height => 'Введите корректный рост (100–250 см)';

  @override
  String get ob_err_weight => 'Введите корректный вес (30–300 кг)';

  @override
  String get ob_err_target_weight => 'Введите целевой вес (30–300 кг)';

  @override
  String get ob_err_training => 'Выберите хотя бы один вариант';

  @override
  String get ob_footer_saving => 'Сохранение...';

  @override
  String get ob_footer_calc => 'Рассчитать план';

  @override
  String get ob_footer_great => 'Отлично!';

  @override
  String get ob_footer_login => 'Войти и сохранить план';

  @override
  String get ob_continue => 'Продолжить';

  @override
  String get ob_getStarted => 'Начать';

  @override
  String get ob_already_account => 'Уже есть аккаунт? Войти';

  @override
  String get ob_weight_unit => 'кг';

  @override
  String get ob_method_recording =>
      'Идёт запись… Нажмите ещё раз чтобы остановить';

  @override
  String get ob_method_text_hint =>
      'Например: гречка 200г, куриная грудка 150г';

  @override
  String get ob_method_recognize => 'Распознать';

  @override
  String get ob_method_recognized => 'Распознано:';

  @override
  String get ob_method_reset => 'Сбросить';

  @override
  String get ob_method_mic_denied => 'Нет доступа к микрофону';

  @override
  String get ob_method_ai_success =>
      'ИИ всё распознал! Нажмите «Далее» чтобы продолжить.';

  @override
  String ob_method_kcal(String cal) {
    return '$cal ккал';
  }

  @override
  String ob_method_macros(String p, String f, String c) {
    return 'Б$p Ж$f У$c';
  }

  @override
  String get ob_recognizing_voice => 'Распознаём голос…';

  @override
  String get ob_recognizing_photo => 'Анализируем фото…';

  @override
  String get auth_title => 'Войти в Kayfit';

  @override
  String get auth_subtitle => 'Выберите способ входа';

  @override
  String get auth_google => 'Войти через Google';

  @override
  String get auth_apple => 'Войти через Apple';

  @override
  String get auth_telegram => 'Войти через Telegram';

  @override
  String get auth_email => 'Войти по email';

  @override
  String get auth_terms =>
      'Продолжая, вы соглашаетесь с условиями использования';

  @override
  String get tariffs_title => 'Тарифы';

  @override
  String get tariffs_subscribe => 'Оформить подписку';

  @override
  String get tariffs_current => 'Текущий тариф';

  @override
  String get tariffs_free => 'Бесплатно';

  @override
  String get tariffs_perMonth => '/ месяц';

  @override
  String get tariffs_cancel => 'Отменить автопродление';

  @override
  String get tariffs_cancelConfirm =>
      'Вы уверены, что хотите отменить автопродление?';

  @override
  String get wg_title => 'Рассчитаем ваш путь к цели';

  @override
  String get wg_sub => 'Введите данные для расчёта калорий и БЖУ';

  @override
  String get wg_age => 'Возраст (лет)';

  @override
  String get wg_weight => 'Текущий вес (кг)';

  @override
  String get wg_height => 'Рост (см)';

  @override
  String get wg_target_weight => 'Целевой вес (кг, опционально)';

  @override
  String get wg_deficit => 'Режим дефицита';

  @override
  String get wg_deficit_active => 'Активный (-600 ккал)';

  @override
  String get wg_deficit_gentle => 'Бережный (-300 ккал)';

  @override
  String get wg_btn_next => 'Далее';

  @override
  String get wg_btn_calculating => 'Расчёт...';

  @override
  String get wg_err_fill => 'Заполните возраст, вес и рост';

  @override
  String get wg_err_data => 'Проверьте корректность данных';

  @override
  String get wg_result_title => 'Ваш путь к цели';

  @override
  String get wg_result_reach => 'Вы достигнете цели';

  @override
  String get wg_result_target_weight => 'Целевой вес';

  @override
  String get wg_result_kg => 'кг';

  @override
  String get wg_result_bmr => 'BMR (базовый обмен):';

  @override
  String get wg_result_tdee => 'TDEE (суточный расход):';

  @override
  String get wg_result_days => 'Дней до цели:';

  @override
  String get wg_result_kcal_day => 'ккал/день';

  @override
  String get wg_btn_start => 'Начать отслеживать';

  @override
  String get error_network => 'Нет соединения с сервером';

  @override
  String get error_auth => 'Ошибка авторизации';

  @override
  String get error_unknown => 'Что-то пошло не так';

  @override
  String get subscription_title => 'Подписка';

  @override
  String get subscription_none => 'У вас нет активной подписки';

  @override
  String get subscription_view_tariffs => 'Посмотреть тарифы';

  @override
  String get subscription_active => 'Активная подписка';

  @override
  String get subscription_expires => 'Действует до';

  @override
  String get subscription_amount => 'Стоимость';

  @override
  String get subscription_auto_renew => 'Автопродление';

  @override
  String get subscription_auto_renew_on => 'Включено';

  @override
  String get subscription_auto_renew_off => 'Отключено';

  @override
  String get subscription_cancel_auto_renew => 'Отменить автопродление';

  @override
  String get subscription_cancel_auto_renew_title => 'Отмена автопродления';

  @override
  String get subscription_cancel_auto_renew_confirm =>
      'Вы уверены, что хотите отменить автопродление подписки?';

  @override
  String get subscription_cancel_auto_renew_action => 'Отменить';

  @override
  String get subscription_auto_renew_cancelled => 'Автопродление отменено';

  @override
  String get wg_plan_ready => 'Ваш план готов!';

  @override
  String get wg_personal_calc => 'Персональный расчёт на основе ваших данных';

  @override
  String get wg_kcal_day => 'ккал / день';

  @override
  String get wg_macronutrients => 'Макронутриенты';

  @override
  String wg_days_to_goal(int days) {
    return 'До цели: $days дней';
  }

  @override
  String wg_target_weight_val(String kg) {
    return 'Целевой вес: $kg кг';
  }

  @override
  String get wg_weight_forecast => 'Прогноз веса';

  @override
  String get wg_how_to_reach => 'Как достичь цели';

  @override
  String get wg_feature_photo_title => 'Фото блюда';

  @override
  String get wg_feature_photo_desc =>
      'Сфотографируйте еду — ИИ распознает калории за секунды';

  @override
  String get wg_feature_voice_title => 'Голосовой ввод';

  @override
  String get wg_feature_voice_desc =>
      'Продиктуйте, что съели — приложение запишет';

  @override
  String get wg_feature_track_title => 'Трекинг прогресса';

  @override
  String get wg_feature_track_desc =>
      'Следите за КБЖУ и видьте результат каждый день';

  @override
  String get wg_start_diary => 'Начать вести дневник';

  @override
  String get wg_now => 'сейчас';

  @override
  String get auth_email_login_title => 'Вход по email';

  @override
  String get auth_register_title => 'Регистрация';

  @override
  String get auth_login_subtitle => 'Войдите в свой аккаунт Kayfit';

  @override
  String get auth_register_subtitle => 'Создайте аккаунт, чтобы начать';

  @override
  String get auth_tab_login => 'Вход';

  @override
  String get auth_tab_register => 'Регистрация';

  @override
  String get auth_field_password => 'Пароль';

  @override
  String get auth_field_name => 'Имя (необязательно)';

  @override
  String get auth_field_confirm_password => 'Повторите пароль';

  @override
  String get auth_btn_login => 'Войти';

  @override
  String get auth_btn_register => 'Создать аккаунт';

  @override
  String get auth_err_enter_password => 'Введите пароль';

  @override
  String get auth_err_min_password => 'Минимум 8 символов';

  @override
  String get auth_err_confirm_password => 'Повторите пароль';

  @override
  String get auth_err_passwords_no_match => 'Пароли не совпадают';

  @override
  String get auth_err_enter_email => 'Введите email';

  @override
  String get auth_err_invalid_email => 'Некорректный email';

  @override
  String get auth_err_enter_value => 'Введите значение';

  @override
  String get goals_title => 'Цели КБЖУ';

  @override
  String get goals_saved => 'Сохранено';

  @override
  String goals_error(String msg) {
    return 'Ошибка: $msg';
  }

  @override
  String get goals_err_enter_value => 'Введите значение';

  @override
  String get goals_err_enter_int => 'Введите целое число';

  @override
  String get dashboard_details => 'Подробнее';

  @override
  String get dashboard_no_goals_title => 'Цели не настроены';

  @override
  String get dashboard_no_goals_sub =>
      'Пройдите «Путь к цели» чтобы получить персональный план питания';

  @override
  String get dashboard_remaining_title => 'Осталось на сегодня';

  @override
  String get dashboard_remaining_over => 'Превышение';

  @override
  String get edit_meal_title => 'Редактировать блюдо';

  @override
  String get edit_meal_name_label => 'Название';

  @override
  String get edit_meal_name_error => 'Введите название';

  @override
  String get edit_meal_saved => 'Сохранено';

  @override
  String edit_meal_error(String msg) {
    return 'Ошибка: $msg';
  }

  @override
  String get edit_meal_err_enter_value => 'Введите значение';

  @override
  String get edit_meal_err_invalid_number => 'Введите корректное число';

  @override
  String get edit_meal_weight_label => 'Вес (г)';

  @override
  String get edit_meal_section_details => 'Детали';

  @override
  String get edit_meal_section_portion => 'Порция';

  @override
  String get edit_meal_section_nutrition => 'Питательная ценность';

  @override
  String get addMeal_subscription_needed => 'Нужна подписка';

  @override
  String get addMeal_subscription_desc =>
      'Распознавание еды доступно на платном тарифе. Оформите подписку чтобы пользоваться ИИ-функциями.';

  @override
  String get addMeal_choose_tariff => 'Выбрать тариф';

  @override
  String get addMeal_close => 'Закрыть';

  @override
  String addMeal_kcal(String cal) {
    return '$cal ккал';
  }

  @override
  String get addMeal_subscription_snack => 'Для этой функции нужна подписка';

  @override
  String get addMeal_weight_hint => 'Вес (г)';

  @override
  String get addMeal_recognizing_voice => 'Распознаём голос...';

  @override
  String get addMeal_recognizing_photo => 'Анализируем фото...';

  @override
  String get addMeal_mic_denied => 'Нет доступа к микрофону';

  @override
  String get addMeal_open_settings => 'Настройки';

  @override
  String get addMeal_barcode => 'Штрихкод';

  @override
  String get addMeal_barcode_desc => 'Сканируй — найдём продукт мгновенно';

  @override
  String get addMeal_voice_tap_stop => 'Нажмите ещё раз чтобы остановить';

  @override
  String get addMeal_voice_tap_start => 'Нажмите чтобы начать запись';

  @override
  String get addMeal_recognize_ai => 'Распознать с помощью AI';

  @override
  String get addMeal_not_food_title => 'Еда не найдена';

  @override
  String get addMeal_not_food_message =>
      'На фото не удалось распознать еду. Поднесите камеру ближе к блюду и попробуйте ещё раз.';

  @override
  String get addMeal_not_food_retry => 'Попробовать ещё';

  @override
  String get addMeal_saving => 'Сохраняем...';

  @override
  String get addMeal_ai_analyzing => 'AI анализирует данные...';

  @override
  String get addMeal_parsing_title => 'Поиск в базе данных';

  @override
  String get addMeal_parsing_step1 => 'Ищем в базе данных...';

  @override
  String get addMeal_parsing_step2 => 'Анализируем ингредиенты...';

  @override
  String get addMeal_parsing_step3 => 'Рассчитываем КБЖУ...';

  @override
  String get addMeal_parsing_step4 => 'Подбираем витамины и минералы...';

  @override
  String get barcode_scan_hint => 'Наведите камеру на штрихкод';

  @override
  String get barcode_loading => 'Определяем продукт...';

  @override
  String get barcode_manual_btn => 'Ввести вручную';

  @override
  String get barcode_manual_title => 'Введите штрихкод';

  @override
  String get barcode_search_btn => 'Найти';

  @override
  String get barcode_not_found => 'Продукт не найден';

  @override
  String get addMeal_barcode_scanning => 'Сканирование штрихкода';

  @override
  String get addMeal_barcode_torch_off => 'Выключить фонарик';

  @override
  String get addMeal_barcode_torch_on => 'Включить фонарик';

  @override
  String get addMeal_barcode_detected => 'Штрихкод найден';

  @override
  String get addMeal_barcode_confirm => 'Добавить в журнал';

  @override
  String get settings_delete_account_title => 'Удалить аккаунт?';

  @override
  String get settings_delete_account_body =>
      'Все ваши данные будут удалены без возможности восстановления. Это действие необратимо.';

  @override
  String get settings_delete_account_btn => 'Удалить аккаунт';

  @override
  String get settings_ai_consent => 'Обработка данных ИИ';

  @override
  String get settings_privacy_policy => 'Политика конфиденциальности';

  @override
  String get settings_terms => 'Пользовательское соглашение';

  @override
  String get settings_subscription_terms => 'Условия подписки';

  @override
  String get settings_subscription_privacy => 'Обработка данных подписки';

  @override
  String get settings_sub_promo =>
      'Оформите подписку чтобы разблокировать ИИ-распознавание, голос и фото.';

  @override
  String get settings_sale_ends => 'Скидка заканчивается через:';

  @override
  String get settings_sub_active_badge => '✓ Активна';

  @override
  String get tariffs_title_full => 'Подпишись и открой\nполный доступ';

  @override
  String get tariffs_tag1 => '🥕 Рекомендации по питанию';

  @override
  String get tariffs_tag2 => '📋 Сканер калорий';

  @override
  String get tariffs_tag3 => '📋 Расчет нормы';

  @override
  String get tariffs_tag4 => '😀 Трекер эмоций';

  @override
  String get tariffs_trial => 'Пробный период';

  @override
  String get tariffs_monthly => 'Месяц';

  @override
  String get tariffs_yearly => 'Год';

  @override
  String get tariffs_quarterly => '3 месяца';

  @override
  String get tariffs_per_3days => '/ 3 дня';

  @override
  String get tariffs_per_day => '/ день';

  @override
  String get tariffs_per_3mo => '/ 3 мес';

  @override
  String get tariffs_trial_then => 'Затем 2 990 за год';

  @override
  String get tariffs_monthly_billing => 'Ежемесячная оплата';

  @override
  String get tariffs_yearly_save => '2 990 ₽ / Экономия 8 890 ₽';

  @override
  String get tariffs_best_value => 'Оптимальный выбор';

  @override
  String tariffs_no_discount(String price) {
    return 'Без скидки $price';
  }

  @override
  String get tariffs_no_plans => 'Тарифы пока не настроены';

  @override
  String get tariffs_cancel_anytime =>
      'Подписку можно отменить в любой удобный момент в Личном кабинете';

  @override
  String get tariffs_optimal_months =>
      'Оптимальный результат достигается через 3 месяца';

  @override
  String get tariffs_email_hint => 'Email для чека';

  @override
  String get tariffs_email_error => 'Введите корректный email';

  @override
  String get tariffs_pay_error =>
      'Не удалось создать платёж. Попробуйте ещё раз.';

  @override
  String get tariffs_get_plan => 'Получить мой план';

  @override
  String get tariffs_load_error => 'Не удалось загрузить тарифы';

  @override
  String get tariffs_sale_ends => 'СКИДКА ЗАКАНЧИВАЕТСЯ ЧЕРЕЗ';

  @override
  String get tariffs_benefit1 => '🥗 Консультация с нутрициологом';

  @override
  String get tariffs_benefit2 => '🎥 Видео рецепты';

  @override
  String get tariffs_benefit3 => '🍽️ План питания';

  @override
  String get tariffs_benefit4 => '📋 Гайд по питанию';

  @override
  String get tariffs_payment_title => 'Оплата';

  @override
  String get nav_chat => 'ИИ Чат';

  @override
  String get chat_title => 'ИИ Нутрициолог';

  @override
  String get chat_input_hint => 'Спросите о питании...';

  @override
  String get chat_clear => 'Очистить чат';

  @override
  String get chat_clear_confirm => 'Удалить всю историю чата?';

  @override
  String get chat_error => 'Не удалось отправить сообщение';

  @override
  String get chat_empty => 'Спросите меня о питании, диете или прогрессе!';

  @override
  String get chat_suggestion_1 => '🥗 Что съесть на обед при дефиците?';

  @override
  String get chat_suggestion_2 => '💪 Норма белка для похудения';

  @override
  String get chat_suggestion_3 => '🌙 Можно ли есть после 18:00?';

  @override
  String get recogV2_composition => 'СОСТАВ';

  @override
  String get recogV2_meal_type => 'ТИП ПРИЁМА ПИЩИ';

  @override
  String get recogV2_saving => 'Сохранение...';

  @override
  String get recogV2_add_breakfast => 'Добавить завтрак';

  @override
  String get recogV2_add_lunch => 'Добавить обед';

  @override
  String get recogV2_add_dinner => 'Добавить ужин';

  @override
  String get recogV2_add_snack => 'Добавить перекус';

  @override
  String get recogV2_add_meal => 'Добавить приём пищи';

  @override
  String get recogV2_macros => 'МАКРОНУТРИЕНТЫ';

  @override
  String get recogV2_carbs_detail => 'УГЛЕВОДЫ ДЕТАЛЬНО';

  @override
  String get recogV2_net_carbs => 'Чистые углеводы';

  @override
  String get recogV2_fiber => 'Клетчатка';

  @override
  String get recogV2_sugar_alcohols => 'Сахарные спирты';

  @override
  String get recogV2_fats_detail => 'ЖИРЫ ДЕТАЛЬНО';

  @override
  String get recogV2_sat_fat => 'Насыщенные';

  @override
  String get recogV2_mono_fat => 'Мононенасыщенные';

  @override
  String get recogV2_poly_fat => 'Полиненасыщенные';

  @override
  String get recogV2_micro => 'МИКРОНУТРИЕНТЫ';

  @override
  String get recogV2_sodium => 'Натрий';

  @override
  String get recogV2_cholesterol => 'Холестерин';

  @override
  String get recogV2_potassium => 'Калий';

  @override
  String get recogV2_mg => 'мг';

  @override
  String get recogV2_gi_low => 'низкий';

  @override
  String get recogV2_gi_medium => 'средний';

  @override
  String get recogV2_gi_high => 'высокий';

  @override
  String get recogV2_gi_label => 'ГИ';

  @override
  String get recogV2_search_ingredient => 'Поиск ингредиента';

  @override
  String get recogV2_search_hint => 'Например: куриная грудка';

  @override
  String get recogV2_correct_btn => 'Скорректировать';

  @override
  String get recogV2_correct_hint =>
      'Что изменить? Например: котлеты из индейки, а не курицы';

  @override
  String get recogV2_correct_title => 'Корректировка';

  @override
  String get recogV2_correct_send => 'Применить';

  @override
  String get recogV2_correct_loading => 'Обновляем состав...';

  @override
  String get nds_section_basic => 'Основные';

  @override
  String get nds_section_carbs_detail => 'Углеводы детально';

  @override
  String get nds_section_fats_detail => 'Жиры детально';

  @override
  String get nds_section_minerals => 'Минералы';

  @override
  String get nds_section_vitamins => 'Витамины';

  @override
  String get nds_nutrient_calories => 'Калории';

  @override
  String get nds_nutrient_protein => 'Белки';

  @override
  String get nds_nutrient_fat => 'Жиры';

  @override
  String get nds_nutrient_carbs => 'Углеводы';

  @override
  String get nds_nutrient_fiber => 'Клетчатка';

  @override
  String get nds_nutrient_sugar_alcohols => 'Сахарные спирты';

  @override
  String get nds_nutrient_net_carbs => 'Чистые углеводы';

  @override
  String get nds_nutrient_gi => 'Гликемич. индекс';

  @override
  String get nds_nutrient_sat_fat => 'Насыщенные';

  @override
  String get nds_nutrient_mono_fat => 'Мононенасыщенные';

  @override
  String get nds_nutrient_poly_fat => 'Полиненасыщенные';

  @override
  String get nds_nutrient_sodium => 'Натрий';

  @override
  String get nds_nutrient_cholesterol => 'Холестерин';

  @override
  String get nds_nutrient_potassium => 'Калий';

  @override
  String get nds_nutrient_calcium => 'Кальций';

  @override
  String get nds_nutrient_iron => 'Железо';

  @override
  String get nds_nutrient_vitamin_a => 'Витамин A';

  @override
  String get nds_nutrient_vitamin_c => 'Витамин C';

  @override
  String get nds_nutrient_vitamin_d => 'Витамин D';

  @override
  String get nds_gi_low => 'низкий';

  @override
  String get nds_gi_medium => 'средний';

  @override
  String get nds_gi_high => 'высокий';

  @override
  String get nds_source_cache => 'Кэш';

  @override
  String get nds_unit_kcal => 'ккал';

  @override
  String get nds_unit_g => 'г';

  @override
  String get nds_unit_mg => 'мг';

  @override
  String get nds_unit_mcg => 'мкг';

  @override
  String get nds_per100g => '/100г';

  @override
  String nds_weight_g(String w) {
    return '$w г';
  }

  @override
  String get nutrient_details_title => 'ПОДРОБНОСТИ';

  @override
  String get nutrient_weight => 'Вес';

  @override
  String get nutrient_net_carbs => 'Чистые углеводы';

  @override
  String get nutrient_fiber => 'Клетчатка';

  @override
  String get nutrient_sugar => 'Сахар';

  @override
  String get nutrient_sugar_alcohols => 'Сахарные спирты';

  @override
  String get nutrient_glycemic_index => 'Гликемический индекс';

  @override
  String get nutrient_saturated_fat => 'Насыщ. жиры';

  @override
  String get nutrient_unsaturated_fat => 'Ненасыщ. жиры';

  @override
  String get nutrient_cholesterol => 'Холестерин';

  @override
  String get nutrient_sodium => 'Натрий';

  @override
  String get nutrient_potassium => 'Калий';

  @override
  String get nutrient_calcium => 'Кальций';

  @override
  String get nutrient_iron => 'Железо';

  @override
  String get nutrient_vitamin_a => 'Витамин A';

  @override
  String get nutrient_vitamin_c => 'Витамин C';

  @override
  String get nutrient_vitamin_d => 'Витамин D';

  @override
  String get nutrient_vitamin_b12 => 'Витамин B12';

  @override
  String get nutrient_mg => 'мг';

  @override
  String get nutrient_mcg => 'мкг';

  @override
  String mealGroup_itemsCount(int count) {
    return '$count блюд';
  }

  @override
  String get paywall_headline => 'ИИ считает калории.\nТы просто ешь.';

  @override
  String get paywall_subtitle =>
      'Сфотографируй тарелку, скажи голосом или спроси нутрициолога — KayFit запишет всё сам.';

  @override
  String get paywall_feature_photo_title => 'Фото → КБЖУ за секунды';

  @override
  String get paywall_feature_photo_sub =>
      'ИИ определяет ингредиенты и вес порции';

  @override
  String get paywall_feature_voice_title => 'Скажи вслух';

  @override
  String get paywall_feature_voice_sub =>
      '«Съел куриный плов» → залогировано сразу';

  @override
  String get paywall_feature_chat_title => 'Нутрициолог в кармане';

  @override
  String get paywall_feature_chat_sub => 'Спроси о питании — ответит и запишет';

  @override
  String get paywall_plan_trial_title => 'СТАРТ\n7 дней 🆓';

  @override
  String get paywall_plan_monthly_title => 'Месяц';

  @override
  String get paywall_plan_quarterly_title => '3 месяца';

  @override
  String get paywall_plan_quarterly_badge => '★ ЛУЧШИЙ';

  @override
  String get paywall_plan_yearly_title => 'Год';

  @override
  String get paywall_plan_yearly_badge => '🔥 −40%';

  @override
  String get paywall_cta_trial => 'Начать 7 дней бесплатно';

  @override
  String get paywall_cta_buy => 'Подписаться';

  @override
  String get paywall_trial_note =>
      'Отменить до конца 7 дней — ничего не спишется';

  @override
  String get paywall_dismiss => 'Нет, буду вводить руками';

  @override
  String get paywall_restore => 'Восстановить';

  @override
  String get paywall_terms => 'Условия';

  @override
  String get paywall_privacy => 'Политика';

  @override
  String get paywall_pending_snack =>
      'Платёж обрабатывается. Попробуйте позже.';

  @override
  String get paywall_error_snack => 'Ошибка покупки. Попробуйте ещё раз.';

  @override
  String get paywall_restored_snack => 'Подписка восстановлена';

  @override
  String get paywall_no_restore_snack => 'Активная подписка не найдена';

  @override
  String get paywall_restore_error_snack =>
      'Ошибка восстановления. Попробуйте ещё раз.';

  @override
  String get item_enter_nutrition_manually => 'Введите КБЖУ вручную';

  @override
  String get mealType_breakfast => 'Завтрак';

  @override
  String get mealType_lunch => 'Обед';

  @override
  String get mealType_dinner => 'Ужин';

  @override
  String get mealType_snack => 'Перекус';

  @override
  String get mealType_other => 'Другое';

  @override
  String get macro_net_carbs_abbr => 'Чист.У';

  @override
  String get macro_sat_fat_short => 'Нас.ж';

  @override
  String get macro_good_fat_short => 'Ненас.ж';

  @override
  String get gi_low_badge => 'Низк. ГИ';

  @override
  String get gi_medium_badge => 'Сред. ГИ';

  @override
  String get gi_high_badge => 'Выс. ГИ';

  @override
  String get journal_meal_deleted => 'Приём пищи удалён';

  @override
  String get journal_could_not_delete => 'Не удалось удалить';

  @override
  String get journal_could_not_update_weight => 'Не удалось обновить вес';

  @override
  String get journal_meal_actions => 'Действия с приёмом пищи';

  @override
  String get journal_copy_date => 'Дата копии';

  @override
  String get journal_copy_btn => 'Копировать';

  @override
  String journal_copied_to(String date) {
    return 'Скопировано на $date';
  }

  @override
  String get journal_open_btn => 'Перейти';

  @override
  String get journal_could_not_copy => 'Не удалось скопировать';

  @override
  String get journal_copy_to_another_date => 'Копировать на другую дату';

  @override
  String get journal_disclaimer =>
      'Расчёты КБЖУ — ориентировочные. Не заменяют консультацию врача.';

  @override
  String get nav_add => 'Добавить';

  @override
  String get cal_on_track => 'в норме';

  @override
  String get cal_over_goal => 'превышение';

  @override
  String get cal_empty => 'нет данных';
}
