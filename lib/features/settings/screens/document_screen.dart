import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

enum DocumentType { privacyPolicy, termsOfService }

class DocumentScreen extends StatelessWidget {
  final DocumentType type;

  const DocumentScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final title = type == DocumentType.privacyPolicy
        ? (isRu ? 'Политика конфиденциальности' : 'Privacy Policy')
        : (isRu ? 'Пользовательское соглашение' : 'Terms of Service');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        child: type == DocumentType.privacyPolicy
            ? _PrivacyPolicy(isRu: isRu)
            : _TermsOfService(isRu: isRu),
      ),
    );
  }
}

// ─── Privacy Policy ──────────────────────────────────────────────────────────

class _PrivacyPolicy extends StatelessWidget {
  final bool isRu;
  const _PrivacyPolicy({required this.isRu});

  @override
  Widget build(BuildContext context) =>
      isRu ? const _PrivacyPolicyRu() : const _PrivacyPolicyEn();
}

class _PrivacyPolicyRu extends StatelessWidget {
  const _PrivacyPolicyRu();

  @override
  Widget build(BuildContext context) {
    return const _DocContent(sections: [
      _Section(
        title: 'Политика конфиденциальности — Kayfit',
        body: '',
        isHeadline: true,
      ),
      _Section(
        title: '1. Данные, которые мы собираем',
        body: '1.1 Данные аккаунта\n'
            '• Адрес электронной почты (для регистрации и входа)\n'
            '• Пароль (передаётся защищённо, на устройстве не хранится)\n\n'
            '1.2 Данные о здоровье и физической активности\n'
            '• Возраст, рост, вес, пол, уровень активности (указываются при первом запуске)\n'
            '• Целевой вес и цели снижения веса\n'
            '• Суточные цели по калориям и макронутриентам (рассчитываются по вашему профилю)\n\n'
            '1.3 Данные о питании\n'
            '• Текстовые описания блюд\n'
            '• Голосовые записи описаний блюд (передаются для распознавания, на устройстве не хранятся)\n'
            '• Фотографии блюд (передаются для ИИ-распознавания, на устройстве не хранятся)\n'
            '• Данные о питательной ценности: названия продуктов, граммовка, калории, белки, жиры, углеводы\n'
            '• Метки настроения, связанные с приёмами пищи\n'
            '• Временны́е метки приёмов пищи\n\n'
            '1.4 Данные ИИ-чата\n'
            '• Сообщения, отправленные ИИ-нутрициологу\n'
            '• Ответы ИИ (хранятся как история чата)\n\n'
            '1.5 Технические данные\n'
            '• Токен push-уведомлений (Firebase Cloud Messaging)\n'
            '• Платформа устройства (iOS)\n'
            '• События использования приложения (просмотренные экраны, используемые функции)\n'
            '• Отчёты об ошибках',
      ),
      _Section(
        title: '2. Как мы используем ваши данные',
        body: 'Данные аккаунта, здоровья и питания используются для предоставления основных функций приложения. '
            'Возраст, вес, рост, пол и активность используются для расчёта персональных целей питания. '
            'Тексты, голосовые записи, фото и сообщения в чате обрабатываются ИИ на основании вашего явного согласия. '
            'Токен push-уведомлений используется для отправки напоминаний (при вашем согласии). '
            'Отчёты об ошибках и события использования применяются для улучшения стабильности приложения.',
      ),
      _Section(
        title: '3. Сторонние сервисы',
        body: '3.1 Anthropic (Claude AI)\n'
            'Описания блюд (текст, расшифрованный голос, фото) и сообщения в чате обрабатываются моделью Claude от Anthropic '
            'для распознавания еды и ответов нутрициолога. Данные обрабатываются в США. '
            'Перед отправкой данных Anthropic запрашивается ваше явное согласие. '
            'Вы вправе отказаться — в этом случае функции ИИ будут недоступны. '
            'В соответствии с условиями API Anthropic, данные, передаваемые через API, не используются для обучения модели. '
            'Подробнее: anthropic.com/privacy\n\n'
            '3.2 Firebase (Google)\n'
            'Токен push-уведомлений, тип платформы, анонимизированные события использования и отчёты об ошибках передаются '
            'в Firebase для доставки уведомлений, аналитики и сбора отчётов о сбоях. '
            'Данные могут обрабатываться в США или ЕС. '
            'Подробнее: firebase.google.com/support/privacy',
      ),
      _Section(
        title: '4. Хранение и безопасность данных',
        body: '• Все данные передаются по HTTPS (шифрование TLS).\n'
            '• Аутентификация использует защищённые токены, хранящиеся на вашем устройстве. Токены удаляются при выходе из аккаунта.\n'
            '• Ваш пароль никогда не хранится на устройстве.\n'
            '• Данные о здоровье и питании хранятся на наших серверах и привязаны к вашему аккаунту.',
      ),
      _Section(
        title: '5. Сроки хранения данных',
        body: '• Данные аккаунта: хранятся, пока аккаунт активен; удаляются по запросу об удалении аккаунта.\n'
            '• Данные о питании: хранятся, пока аккаунт активен; отдельные приёмы пищи можно удалить в любое время.\n'
            '• История чата: вы можете очистить её в любое время прямо в приложении.\n'
            '• Голосовые записи и фотографии: передаются для обработки, постоянно на устройстве не хранятся.\n'
            '• Аналитические данные хранятся в анонимизированном/агрегированном виде.\n'
            '• Все персональные данные безвозвратно удаляются при удалении аккаунта.',
      ),
      _Section(
        title: '6. Ваши права',
        body: '• Просмотр персональных данных (доступно в настройках и профиле приложения)\n'
            '• Удаление аккаунта и всех связанных данных (Настройки → Удалить аккаунт)\n'
            '• Удаление отдельных приёмов пищи или истории чата в любое время\n'
            '• Отзыв согласия на обработку данных ИИ в любое время\n'
            '• Отказ от push-уведомлений через настройки устройства\n'
            '• Запрос копии данных или обращение к нам по любым вопросам\n\n'
            'Удаление аккаунта влечёт безвозвратное удаление всех ваших персональных данных, '
            'сведений о здоровье, истории питания и истории чата с наших серверов.',
      ),
      _Section(
        title: '7. Защита данных детей',
        body: 'Kayfit не предназначен для детей до 13 лет. Мы не собираем данные детей до 13 лет намеренно. '
            'Если вы считаете, что ребёнок передал нам персональные данные, свяжитесь с нами — мы их удалим.',
      ),
      _Section(
        title: '8. Международная передача данных',
        body: 'Ваши данные могут обрабатываться в странах, отличных от страны вашего проживания, '
            'в том числе в США (обработка ИИ Anthropic) и в стране расположения наших серверов. '
            'Мы обеспечиваем надлежащие гарантии при таких передачах.',
      ),
      _Section(
        title: '9. Изменения настоящей политики',
        body: 'Мы можем периодически обновлять настоящую Политику конфиденциальности. О существенных изменениях '
            'мы уведомим вас через приложение или иными способами. '
            'Продолжение использования приложения после изменений означает согласие с обновлённой политикой.',
      ),
      _Section(
        title: '10. Медицинский дисклеймер',
        body: 'Kayfit предоставляет общую информацию о питании и инструменты для её отслеживания. '
            'Приложение не оказывает медицинских услуг, не ставит диагнозов и не назначает лечения. '
            'Перед изменением рациона, особенно при наличии хронических заболеваний или расстройств пищевого поведения, '
            'проконсультируйтесь с квалифицированным специалистом.',
      ),
      _Section(
        title: '11. Контакты',
        body: 'Email: support@carbcounter.online\n'
            'ИП Игорь Зуев\n'
            'Рег. № 300411551\n'
            'Грузия, г. Тбилиси, р-н Самгори, пос. Варкетили, массив III, Земо-плато, д. N33а, этаж 1, кв. N3a\n\n'
            'Последнее обновление: 27 марта 2026 г.',
      ),
    ]);
  }
}

class _PrivacyPolicyEn extends StatelessWidget {
  const _PrivacyPolicyEn();

  @override
  Widget build(BuildContext context) {
    return const _DocContent(sections: [
      _Section(
        title: 'Privacy Policy — Kayfit',
        body: '',
        isHeadline: true,
      ),
      _Section(
        title: '1. Data We Collect',
        body: '1.1 Account Data\n'
            '• Email address (for registration and login)\n'
            '• Password (transmitted securely, never stored on device)\n\n'
            '1.2 Health & Fitness Data\n'
            '• Age, height, weight, gender, activity level (provided during onboarding)\n'
            '• Target weight and weight-loss goals\n'
            '• Daily calorie and macronutrient targets (calculated from your profile)\n\n'
            '1.3 Meal & Nutrition Data\n'
            '• Meal descriptions entered as text\n'
            '• Voice recordings of meal descriptions (transmitted for transcription, not stored on device)\n'
            '• Photos of meals (transmitted for AI recognition, not stored on device)\n'
            '• Parsed nutrition data: food names, weights, calories, protein, fat, carbohydrates\n'
            '• Mood/emotion tags associated with meals\n'
            '• Meal timestamps\n\n'
            '1.4 AI Chat Data\n'
            '• Messages you send to the AI nutritionist\n'
            '• AI responses (stored as chat history)\n\n'
            '1.5 Device & Technical Data\n'
            '• Push notification token (Firebase Cloud Messaging)\n'
            '• Device platform (iOS)\n'
            '• App usage events (screens viewed, features used)\n'
            '• Crash reports',
      ),
      _Section(
        title: '2. How We Use Your Data',
        body: 'Account, health, and meal data are used to provide the App\'s core features (contract performance). '
            'Age, weight, height, gender, and activity level are used to calculate personalized nutrition targets (contract performance). '
            'Meal text, voice, photos, and chat messages are processed by AI for meal recognition and nutritionist responses (explicit consent). '
            'Push notification token is used to send reminders and summaries (consent). '
            'Crash reports and usage events improve app stability (legitimate interest).',
      ),
      _Section(
        title: '3. Third-Party Services',
        body: '3.1 Anthropic (Claude AI)\n'
            'Meal descriptions (text, transcribed voice, photos) and chat messages are processed by Anthropic\'s Claude AI '
            'for food recognition and nutritionist responses. Data is processed in the United States. '
            'You are asked for explicit consent before any data is sent to Anthropic. '
            'You may decline, in which case AI-powered features will be unavailable. '
            'Per Anthropic\'s API terms, data sent via the API is not used for model training. '
            'More info: anthropic.com/privacy\n\n'
            '3.2 Firebase (Google)\n'
            'Device push notification token, platform type, anonymized usage events, and crash reports are shared with Firebase '
            'for delivering push notifications, analytics, and crash reporting. '
            'Data may be processed in the United States or EU. '
            'More info: firebase.google.com/support/privacy',
      ),
      _Section(
        title: '4. Data Storage & Security',
        body: '• All data is transmitted over HTTPS (TLS encryption).\n'
            '• Authentication uses secure tokens stored on your device. Tokens are cleared on logout.\n'
            '• Your password is never stored on the device.\n'
            '• Health and meal data is stored on our servers and associated with your account.',
      ),
      _Section(
        title: '5. Data Retention',
        body: '• Account data: Retained while your account is active. Deleted upon account deletion request.\n'
            '• Meal data: Retained while your account is active. Individual meals can be deleted at any time.\n'
            '• Chat history: You can clear your chat history at any time from within the App.\n'
            '• Voice recordings and photos: Transmitted for processing, not permanently stored on device.\n'
            '• Analytics data: Retained in anonymized/aggregated form.\n'
            '• All personal data is permanently deleted upon account deletion.',
      ),
      _Section(
        title: '6. Your Rights',
        body: '• Access your personal data (available in the App\'s settings and profile screens)\n'
            '• Delete your account and all associated data (Settings → Delete Account)\n'
            '• Delete individual meals or chat history at any time\n'
            '• Withdraw consent for AI data processing at any time\n'
            '• Opt out of push notifications via device settings\n'
            '• Request a copy of your data or raise concerns by contacting us\n\n'
            'Account deletion removes all your personal data, health information, meal history, and chat history from our servers.',
      ),
      _Section(
        title: '7. Children\'s Privacy',
        body: 'Kayfit is not intended for children under 13. We do not knowingly collect data from children under 13. '
            'If you believe a child has provided us with personal data, please contact us and we will delete it.',
      ),
      _Section(
        title: '8. International Data Transfers',
        body: 'Your data may be processed in countries outside your country of residence, including the United States '
            '(Anthropic AI processing) and the country where our servers are located. '
            'We ensure appropriate safeguards are in place for such transfers.',
      ),
      _Section(
        title: '9. Changes to This Policy',
        body: 'We may update this Privacy Policy from time to time. We will notify you of material changes through the App or by other means. '
            'Your continued use of the App after changes constitutes acceptance of the updated policy.',
      ),
      _Section(
        title: '10. Medical Disclaimer',
        body: 'Kayfit provides general nutritional information and tracking tools. '
            'It does not provide medical advice, diagnosis, or treatment. '
            'Always consult a qualified healthcare professional before making changes to your diet, '
            'especially if you have any medical conditions or eating disorders.',
      ),
      _Section(
        title: '11. Contact Us',
        body: 'Email: support@carbcounter.online\n'
            'Individual Entrepreneur Igor Zuev\n'
            'Registration No. 300411551\n'
            'Georgia, Tbilisi City, Samgori District, Varketili Settlement, Array III, Zemo Plateau N33a, Floor 1, Apartment N3a\n\n'
            'Last updated: March 27, 2026',
      ),
    ]);
  }
}

// ─── Terms of Service ────────────────────────────────────────────────────────

class _TermsOfService extends StatelessWidget {
  final bool isRu;
  const _TermsOfService({required this.isRu});

  @override
  Widget build(BuildContext context) =>
      isRu ? const _TermsRu() : const _TermsEn();
}

class _TermsRu extends StatelessWidget {
  const _TermsRu();

  @override
  Widget build(BuildContext context) {
    return const _DocContent(sections: [
      _Section(
        title: 'Пользовательское соглашение — Kayfit',
        body: '',
        isHeadline: true,
      ),
      _Section(
        title: '1. Сервис',
        body: 'Kayfit — дневник питания и трекер нутриентов, который позволяет:\n'
            '• Добавлять приёмы пищи через текст, голос или фото\n'
            '• Отслеживать калории и макронутриенты (белки, жиры, углеводы)\n'
            '• Получать персональные суточные цели по питанию\n'
            '• Общаться с ИИ-нутрициологом\n'
            '• Отслеживать паттерны эмоционального питания',
      ),
      _Section(
        title: '2. Аккаунт и допустимый возраст',
        body: '• Вам должно быть не менее 13 лет для использования приложения.\n'
            '• При создании аккаунта необходимо предоставлять достоверные данные.\n'
            '• Вы несёте ответственность за сохранность учётных данных вашего аккаунта.\n'
            '• Передача аккаунта третьим лицам запрещена.',
      ),
      _Section(
        title: '3. Функции на основе ИИ',
        body: '3.1 Согласие\n'
            'Приложение использует искусственный интеллект (Anthropic Claude) для распознавания блюд по тексту, '
            'голосу и фото, а также для ответов ИИ-нутрициолога. Перед использованием функций ИИ '
            'вам будет запрошено явное согласие на передачу данных в Anthropic для обработки.\n\n'
            '3.2 Ограничения\n'
            '• Распознавание блюд ИИ может быть неточным. Если точность важна, всегда проверяйте данные вручную.\n'
            '• Ответы ИИ-нутрициолога генерируются языковой моделью и не проверяются специалистами.\n'
            '• Функции ИИ могут быть недоступны из-за перебоев в работе сервиса.\n\n'
            '3.3 Отказ от согласия\n'
            'Если вы отказываетесь от обработки данных ИИ, вы по-прежнему можете пользоваться ручным вводом '
            'и отслеживанием питания. Функции ИИ (голосовое/фото-распознавание, ИИ-чат) будут недоступны.',
      ),
      _Section(
        title: '4. Медицинский дисклеймер',
        body: 'Kayfit не является медицинским устройством и не оказывает медицинских услуг.\n\n'
            '• Рекомендации по питанию, цели по калориям и анализ пищевых паттернов носят исключительно '
            'информационный характер.\n'
            '• Они не являются медицинскими консультациями, диагнозами или планами лечения.\n'
            '• При наличии хронических заболеваний, расстройств пищевого поведения или иных медицинских показаний '
            'проконсультируйтесь с квалифицированным специалистом перед использованием приложения '
            'или изменением рациона.\n'
            '• Вы несёте полную ответственность за любые диетические решения, принятые на основе информации из приложения.',
      ),
      _Section(
        title: '5. Подписки и оплата',
        body: '• Доступ к премиум-функциям может требовать платной подписки.\n'
            '• Планы подписки, цены и пробные периоды отображаются в приложении перед покупкой.\n'
            '• Все подписки оформляются через систему встроенных покупок Apple и регулируются условиями Apple.\n'
            '• Подписки продлеваются автоматически, если не отменены за 24 часа до окончания текущего периода.\n'
            '• Управлять подписками и отменять их можно в Настройках устройства → Apple ID → Подписки.\n'
            '• Возвраты средств осуществляются Apple в соответствии с их политикой возврата.',
      ),
      _Section(
        title: '6. Ваш контент',
        body: '• Описания блюд, фотографии, голосовые записи и сообщения в чате остаются вашим контентом.\n'
            '• Используя приложение, вы предоставляете нам ограниченную лицензию на обработку вашего контента '
            'в целях оказания услуги.\n'
            '• Мы не претендуем на право собственности на ваш контент.',
      ),
      _Section(
        title: '7. Допустимое использование',
        body: 'Вы соглашаетесь не:\n'
            '• Использовать приложение в незаконных целях\n'
            '• Предпринимать попытки реверс-инжиниринга или декомпиляции приложения\n'
            '• Нарушать работу инфраструктуры приложения\n'
            '• Создавать автоматизированные аккаунты или использовать ботов\n'
            '• Использовать функции ИИ в целях, не связанных с питанием',
      ),
      _Section(
        title: '8. Интеллектуальная собственность',
        body: 'Весь контент, дизайн, алгоритмы и методологии приложения являются интеллектуальной '
            'собственностью ИП Игоря Зуева, за исключением контента, созданного пользователями. '
            'Название и логотип Kayfit являются товарными знаками ИП Игоря Зуева.',
      ),
      _Section(
        title: '9. Удаление аккаунта',
        body: 'Вы можете удалить аккаунт в любое время через Настройки → Удалить аккаунт. При удалении:\n'
            '• Все ваши персональные данные, информация о здоровье, история питания и история чата '
            'будут безвозвратно удалены с наших серверов.\n'
            '• Это действие необратимо.\n'
            '• Активную подписку необходимо отменить отдельно через управление подписками Apple.',
      ),
      _Section(
        title: '10. Ограничение ответственности',
        body: '• Приложение предоставляется «как есть» без каких-либо гарантий.\n'
            '• Мы не несём ответственности за ущерб, возникший в результате использования приложения, '
            'включая последствия для здоровья, неточность данных о питании или рекомендации ИИ.\n'
            '• Наша совокупная ответственность не может превышать сумму, уплаченную вами за приложение '
            'в течение 12 месяцев, предшествующих предъявлению требования.',
      ),
      _Section(
        title: '11. Изменения условий',
        body: 'Мы можем периодически обновлять настоящее Соглашение. О существенных изменениях мы уведомим '
            'вас через приложение. Продолжение использования приложения после изменений означает их принятие. '
            'Если вы не согласны с обновлёнными условиями, прекратите использование приложения и удалите аккаунт.',
      ),
      _Section(
        title: '12. Применимое право',
        body: 'Настоящее Соглашение регулируется законодательством Грузии. '
            'Все споры подлежат разрешению в судах города Тбилиси, Грузия.',
      ),
      _Section(
        title: '13. Контакты',
        body: 'Email: support@carbcounter.online\n'
            'ИП Игорь Зуев\n'
            'Рег. № 300411551\n'
            'Грузия, г. Тбилиси, р-н Самгори, пос. Варкетили, массив III, Земо-плато, д. N33а, этаж 1, кв. N3a\n\n'
            'Последнее обновление: 27 марта 2026 г.',
      ),
    ]);
  }
}

class _TermsEn extends StatelessWidget {
  const _TermsEn();

  @override
  Widget build(BuildContext context) {
    return const _DocContent(sections: [
      _Section(
        title: 'Terms of Service — Kayfit',
        body: '',
        isHeadline: true,
      ),
      _Section(
        title: '1. The Service',
        body: 'Kayfit is a food diary and nutrition tracking application that helps you:\n'
            '• Log meals via text, voice, or photo\n'
            '• Track calories and macronutrients (protein, fat, carbohydrates)\n'
            '• Receive personalized daily nutrition targets\n'
            '• Chat with an AI nutritionist for guidance\n'
            '• Track emotional eating patterns',
      ),
      _Section(
        title: '2. Account & Eligibility',
        body: '• You must be at least 13 years old to use the App.\n'
            '• You must provide accurate information when creating your account.\n'
            '• You are responsible for maintaining the security of your account credentials.\n'
            '• You may not share your account with third parties.',
      ),
      _Section(
        title: '3. AI-Powered Features',
        body: '3.1 Consent\n'
            'The App uses artificial intelligence (Anthropic Claude) to recognize meals from text, voice, and photos, '
            'and to provide nutritionist chat responses. Before using AI features, you will be asked for explicit consent '
            'to send your data to Anthropic for processing.\n\n'
            '3.2 Limitations\n'
            '• AI meal recognition may be inaccurate. Always verify nutritional values if precision is important to you.\n'
            '• AI nutritionist responses are generated by an AI model and are not reviewed by a human professional.\n'
            '• AI features may be unavailable due to service interruptions.\n\n'
            '3.3 Declining Consent\n'
            'If you decline AI data processing consent, you may still use the App\'s manual meal logging and tracking features. '
            'AI-powered features (voice/photo meal recognition, AI chat) will be unavailable.',
      ),
      _Section(
        title: '4. Medical Disclaimer',
        body: 'Kayfit is not a medical device and does not provide medical advice.\n\n'
            '• Nutritional recommendations, calorie targets, and eating pattern analysis are for informational purposes only.\n'
            '• They do not constitute medical advice, diagnosis, or treatment plans.\n'
            '• If you have chronic health conditions, eating disorders, or any medical concerns, consult a qualified healthcare professional before using the App or making dietary changes.\n'
            '• You assume full responsibility for any dietary decisions made based on information from the App.',
      ),
      _Section(
        title: '5. Subscriptions & Payments',
        body: '• Access to premium features may require a paid subscription.\n'
            '• Subscription plans, pricing, and trial periods are displayed in the App before purchase.\n'
            '• All subscriptions are processed through Apple\'s In-App Purchase system and are subject to Apple\'s terms.\n'
            '• Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period.\n'
            '• You can manage and cancel subscriptions in your device\'s Settings → Apple ID → Subscriptions.\n'
            '• Refunds are handled by Apple in accordance with their refund policy.',
      ),
      _Section(
        title: '6. Your Content',
        body: '• Meal descriptions, photos, voice recordings, and chat messages you submit remain your content.\n'
            '• By using the App, you grant us a limited license to process your content for the purpose of providing the service.\n'
            '• We do not claim ownership of your content.',
      ),
      _Section(
        title: '7. Acceptable Use',
        body: 'You agree not to:\n'
            '• Use the App for any unlawful purpose\n'
            '• Attempt to reverse-engineer, decompile, or extract source code from the App\n'
            '• Interfere with or disrupt the App\'s infrastructure\n'
            '• Create automated accounts or use bots to interact with the App\n'
            '• Misuse the AI features for purposes unrelated to nutrition',
      ),
      _Section(
        title: '8. Intellectual Property',
        body: 'All content, design, algorithms, and methodologies in the App are the intellectual property of '
            'Individual Entrepreneur Igor Zuev, except for your user-generated content. '
            'The Kayfit name and logo are trademarks of Individual Entrepreneur Igor Zuev.',
      ),
      _Section(
        title: '9. Account Deletion',
        body: 'You may delete your account at any time from Settings → Delete Account. Upon deletion:\n'
            '• All your personal data, health information, meal history, and chat history will be permanently removed from our servers.\n'
            '• This action is irreversible.\n'
            '• Any active subscription should be cancelled separately through Apple\'s subscription management.',
      ),
      _Section(
        title: '10. Limitation of Liability',
        body: '• The App is provided "as is" without warranties of any kind.\n'
            '• We are not liable for any damages arising from your use of the App, including health outcomes, inaccurate nutritional data, or AI-generated recommendations.\n'
            '• Our total liability shall not exceed the amount you paid for the App in the 12 months preceding the claim.',
      ),
      _Section(
        title: '11. Changes to These Terms',
        body: 'We may update these Terms from time to time. We will notify you of material changes through the App. '
            'Your continued use after changes constitutes acceptance. '
            'If you disagree with updated Terms, you should stop using the App and delete your account.',
      ),
      _Section(
        title: '12. Governing Law',
        body: 'These Terms are governed by the laws of Georgia. Any disputes shall be resolved in the courts of Tbilisi, Georgia.',
      ),
      _Section(
        title: '13. Contact',
        body: 'Email: support@carbcounter.online\n'
            'Individual Entrepreneur Igor Zuev\n'
            'Registration No. 300411551\n'
            'Georgia, Tbilisi City, Samgori District, Varketili Settlement, Array III, Zemo Plateau N33a, Floor 1, Apartment N3a\n\n'
            'Last updated: March 27, 2026',
      ),
    ]);
  }
}

// ─── Shared document widgets ─────────────────────────────────────────────────

class _DocContent extends StatelessWidget {
  final List<_Section> sections;
  const _DocContent({required this.sections});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.map((s) => _SectionWidget(section: s)).toList(),
    );
  }
}

class _Section {
  final String title;
  final String body;
  final bool isHeadline;
  const _Section({required this.title, required this.body, this.isHeadline = false});
}

class _SectionWidget extends StatelessWidget {
  final _Section section;
  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    if (section.isHeadline) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Text(
          section.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
            height: 1.3,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          if (section.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              section.body,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.65,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
