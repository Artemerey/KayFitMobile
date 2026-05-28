import 'package:flutter/material.dart';
import '../../../shared/theme/app_theme.dart';

enum DocumentType {
  privacyPolicy,
  termsOfService,
  subscriptionTerms,
  subscriptionPrivacy,
}

class DocumentScreen extends StatelessWidget {
  final DocumentType type;

  const DocumentScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final title = switch (type) {
      DocumentType.privacyPolicy =>
        isRu ? 'Политика конфиденциальности' : 'Privacy Policy',
      DocumentType.termsOfService =>
        isRu ? 'Пользовательское соглашение' : 'Terms of Service',
      DocumentType.subscriptionTerms =>
        isRu ? 'Условия подписки' : 'Subscription Terms',
      DocumentType.subscriptionPrivacy =>
        isRu ? 'Обработка данных подписки' : 'Subscription Data Policy',
    };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
        child: switch (type) {
          DocumentType.privacyPolicy => _PrivacyPolicy(isRu: isRu),
          DocumentType.termsOfService => _TermsOfService(isRu: isRu),
          DocumentType.subscriptionTerms => _SubscriptionTerms(isRu: isRu),
          DocumentType.subscriptionPrivacy => _SubscriptionPrivacy(isRu: isRu),
        },
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
        body: 'Данные аккаунта, здоровья и питания используются для предоставления основных функций '
            'приложения (основание — исполнение договора, ст. 6 ч. 1 п. 5 ФЗ-152). '
            'Возраст, вес, рост, пол и активность используются для расчёта персональных целей питания '
            '(исполнение договора). '
            'Тексты, голосовые записи, фото и сообщения в чате обрабатываются ИИ на основании вашего '
            'явного согласия (ст. 6 ч. 1 п. 1 ФЗ-152). '
            'Токен push-уведомлений используется для отправки напоминаний (при вашем согласии). '
            'Отчёты об ошибках и события использования применяются для улучшения стабильности '
            'приложения (законный интерес оператора).',
      ),
      _Section(
        title: '3. Сторонние сервисы',
        body: '3.1 Anthropic (Claude AI)\n'
            'Описания блюд (текст, расшифрованный голос, фото) и сообщения в чате обрабатываются '
            'моделью Claude от Anthropic для распознавания еды и ответов нутрициолога. '
            'Данные обрабатываются в США. '
            'Перед отправкой данных Anthropic запрашивается ваше явное согласие. '
            'Вы вправе отказаться — в этом случае функции ИИ будут недоступны. '
            'В соответствии с условиями API Anthropic, данные, передаваемые через API, '
            'не используются для обучения модели. '
            'Подробнее: anthropic.com/privacy\n\n'
            '3.2 Firebase (Google)\n'
            'Токен push-уведомлений, тип платформы, анонимизированные события использования и '
            'отчёты об ошибках передаются в Firebase для доставки уведомлений, аналитики и '
            'сбора отчётов о сбоях. Данные могут обрабатываться в США или ЕС. '
            'Подробнее: firebase.google.com/support/privacy',
      ),
      _Section(
        title: '4. Хранение и безопасность данных',
        body: '• Все данные передаются по HTTPS (шифрование TLS).\n'
            '• Аутентификация использует защищённые токены, хранящиеся на вашем устройстве. '
            'Токены удаляются при выходе из аккаунта.\n'
            '• Ваш пароль никогда не хранится на устройстве.\n'
            '• Данные о здоровье и питании хранятся на серверах, расположенных на территории '
            'Российской Федерации, что соответствует требованиям ст. 18.1 ФЗ-152 о локализации '
            'персональных данных граждан РФ.',
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
        body: 'Первичное хранение персональных данных осуществляется на серверах, расположенных '
            'на территории Российской Федерации. '
            'Отдельные данные могут дополнительно обрабатываться за рубежом: в США — '
            'при использовании функций ИИ (Anthropic); в США или ЕС — через Firebase (Google). '
            'Трансграничная передача осуществляется на основании вашего согласия (ст. 12 ФЗ-152).',
      ),
      _Section(
        title: '9. Изменения настоящей политики',
        body: 'Мы можем периодически обновлять настоящую Политику конфиденциальности. '
            'О существенных изменениях мы уведомим вас через приложение или иными способами. '
            'Продолжение использования приложения после изменений означает согласие с обновлённой политикой.',
      ),
      _Section(
        title: '10. Медицинский дисклеймер',
        body: 'Kayfit предоставляет общую информацию о питании и инструменты для её отслеживания. '
            'Приложение не оказывает медицинских услуг, не ставит диагнозов и не назначает лечения. '
            'Перед изменением рациона, особенно при наличии хронических заболеваний или расстройств '
            'пищевого поведения, проконсультируйтесь с квалифицированным специалистом.',
      ),
      _Section(
        title: '11. Контакты',
        body: 'Email: artemeree@gmail.com\n'
            'ИП Игорь Зуев\n'
            'Рег. № 300411551\n'
            'Грузия, г. Тбилиси, р-н Самгори, пос. Варкетили, массив III, '
            'Земо-плато, д. N33а, этаж 1, кв. N3a\n\n'
            'Последнее обновление: 28 мая 2026 г.',
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
        body: 'Account, health, and meal data are used to provide the App\'s core features '
            '(legal basis: contract performance). '
            'Age, weight, height, gender, and activity level are used to calculate personalized '
            'nutrition targets (contract performance). '
            'Meal text, voice, photos, and chat messages are processed by AI for meal recognition '
            'and nutritionist responses (explicit consent). '
            'Push notification token is used to send reminders and summaries (consent). '
            'Crash reports and usage events improve app stability (legitimate interest).',
      ),
      _Section(
        title: '3. Third-Party Services',
        body: '3.1 Anthropic (Claude AI)\n'
            'Meal descriptions (text, transcribed voice, photos) and chat messages are processed '
            'by Anthropic\'s Claude AI for food recognition and nutritionist responses. '
            'Data is processed in the United States. '
            'You are asked for explicit consent before any data is sent to Anthropic. '
            'You may decline, in which case AI-powered features will be unavailable. '
            'Per Anthropic\'s API terms, data sent via the API is not used for model training. '
            'More info: anthropic.com/privacy\n\n'
            '3.2 Firebase (Google)\n'
            'Device push notification token, platform type, anonymized usage events, and crash '
            'reports are shared with Firebase for delivering push notifications, analytics, and '
            'crash reporting. Data may be processed in the United States or EU. '
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
            'Account deletion removes all your personal data, health information, meal history, '
            'and chat history from our servers.',
      ),
      _Section(
        title: '7. Children\'s Privacy',
        body: 'Kayfit is not intended for children under 13. We do not knowingly collect data '
            'from children under 13. If you believe a child has provided us with personal data, '
            'please contact us and we will delete it.',
      ),
      _Section(
        title: '8. International Data Transfers',
        body: 'Your data may be processed in countries outside your country of residence, '
            'including the United States (Anthropic AI processing) and the country where our '
            'servers are located. We ensure appropriate safeguards are in place for such transfers.',
      ),
      _Section(
        title: '9. Changes to This Policy',
        body: 'We may update this Privacy Policy from time to time. We will notify you of '
            'material changes through the App or by other means. Your continued use of the App '
            'after changes constitutes acceptance of the updated policy.',
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
        body: 'Email: artemeree@gmail.com\n'
            'Individual Entrepreneur Igor Zuev\n'
            'Registration No. 300411551\n'
            'Georgia, Tbilisi City, Samgori District, Varketili Settlement, '
            'Array III, Zemo Plateau N33a, Floor 1, Apartment N3a\n\n'
            'Last updated: May 28, 2026',
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
            'Приложение использует искусственный интеллект (Anthropic Claude) для распознавания '
            'блюд по тексту, голосу и фото, а также для ответов ИИ-нутрициолога. '
            'Перед использованием функций ИИ вам будет запрошено явное согласие на передачу '
            'данных в Anthropic для обработки.\n\n'
            '3.2 Ограничения\n'
            '• Распознавание блюд ИИ может быть неточным. Если точность важна, всегда проверяйте данные вручную.\n'
            '• Ответы ИИ-нутрициолога генерируются языковой моделью и не проверяются специалистами.\n'
            '• Функции ИИ могут быть недоступны из-за перебоев в работе сервиса.\n\n'
            '3.3 Отказ от согласия\n'
            'Если вы отказываетесь от обработки данных ИИ, вы по-прежнему можете пользоваться '
            'ручным вводом и отслеживанием питания. Функции ИИ (голосовое/фото-распознавание, '
            'ИИ-чат) будут недоступны.',
      ),
      _Section(
        title: '4. Медицинский дисклеймер',
        body: 'Kayfit не является медицинским устройством и не оказывает медицинских услуг.\n\n'
            '• Рекомендации по питанию, цели по калориям и анализ пищевых паттернов носят '
            'исключительно информационный характер.\n'
            '• Они не являются медицинскими консультациями, диагнозами или планами лечения.\n'
            '• При наличии хронических заболеваний, расстройств пищевого поведения или иных '
            'медицинских показаний проконсультируйтесь с квалифицированным специалистом '
            'перед использованием приложения или изменением рациона.\n'
            '• Вы несёте полную ответственность за любые диетические решения, принятые на '
            'основе информации из приложения.',
      ),
      _Section(
        title: '5. Подписки и оплата',
        body: '• Доступ к премиум-функциям может требовать платной подписки.\n'
            '• Планы подписки, цены и пробные периоды отображаются в приложении перед покупкой.\n'
            '• Все подписки оформляются через систему встроенных покупок Apple и регулируются '
            'условиями Apple. Для российских пользователей продажу подписки осуществляет '
            'ИП Чистяков Артём Михайлович (подробнее — в разделе «Условия подписки»).\n'
            '• Подписки продлеваются автоматически, если не отменены за 24 часа до окончания '
            'текущего периода.\n'
            '• Управлять подписками и отменять их можно в Настройках устройства → Apple ID → Подписки.\n'
            '• Возвраты средств осуществляются Apple в соответствии с их политикой возврата.',
      ),
      _Section(
        title: '6. Ваш контент',
        body: '• Описания блюд, фотографии, голосовые записи и сообщения в чате остаются вашим контентом.\n'
            '• Используя приложение, вы предоставляете нам ограниченную лицензию на обработку '
            'вашего контента в целях оказания услуги.\n'
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
            '• Мы не несём ответственности за ущерб, возникший в результате использования '
            'приложения, включая последствия для здоровья, неточность данных о питании или '
            'рекомендации ИИ.\n'
            '• Наша совокупная ответственность не может превышать сумму, уплаченную вами за '
            'приложение в течение 12 месяцев, предшествующих предъявлению требования.',
      ),
      _Section(
        title: '11. Изменения условий',
        body: 'Мы можем периодически обновлять настоящее Соглашение. О существенных изменениях '
            'мы уведомим вас через приложение. Продолжение использования приложения после '
            'изменений означает их принятие. Если вы не согласны с обновлёнными условиями, '
            'прекратите использование приложения и удалите аккаунт.',
      ),
      _Section(
        title: '12. Применимое право',
        body: 'Настоящее Соглашение регулируется законодательством Российской Федерации. '
            'Споры подлежат рассмотрению в суде по месту жительства потребителя '
            'либо по месту нахождения продавца (г. Саратов) — по выбору потребителя. '
            'Настоящее Соглашение не ограничивает права потребителей, предусмотренные '
            'Законом РФ «О защите прав потребителей».',
      ),
      _Section(
        title: '13. Контакты',
        body: 'Email: artemeree@gmail.com\n'
            'ИП Игорь Зуев\n'
            'Рег. № 300411551\n'
            'Грузия, г. Тбилиси, р-н Самгори, пос. Варкетили, массив III, '
            'Земо-плато, д. N33а, этаж 1, кв. N3a\n\n'
            'Последнее обновление: 28 мая 2026 г.',
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
            'The App uses artificial intelligence (Anthropic Claude) to recognize meals from text, '
            'voice, and photos, and to provide nutritionist chat responses. Before using AI features, '
            'you will be asked for explicit consent to send your data to Anthropic for processing.\n\n'
            '3.2 Limitations\n'
            '• AI meal recognition may be inaccurate. Always verify nutritional values if precision is important to you.\n'
            '• AI nutritionist responses are generated by an AI model and are not reviewed by a human professional.\n'
            '• AI features may be unavailable due to service interruptions.\n\n'
            '3.3 Declining Consent\n'
            'If you decline AI data processing consent, you may still use the App\'s manual meal '
            'logging and tracking features. AI-powered features (voice/photo meal recognition, '
            'AI chat) will be unavailable.',
      ),
      _Section(
        title: '4. Medical Disclaimer',
        body: 'Kayfit is not a medical device and does not provide medical advice.\n\n'
            '• Nutritional recommendations, calorie targets, and eating pattern analysis are for informational purposes only.\n'
            '• They do not constitute medical advice, diagnosis, or treatment plans.\n'
            '• If you have chronic health conditions, eating disorders, or any medical concerns, '
            'consult a qualified healthcare professional before using the App or making dietary changes.\n'
            '• You assume full responsibility for any dietary decisions made based on information from the App.',
      ),
      _Section(
        title: '5. Subscriptions & Payments',
        body: '• Access to premium features may require a paid subscription.\n'
            '• Subscription plans, pricing, and trial periods are displayed in the App before purchase.\n'
            '• All subscriptions are processed through Apple\'s In-App Purchase system and are '
            'subject to Apple\'s terms. See "Subscription Terms" for full billing details.\n'
            '• Subscriptions renew automatically unless cancelled at least 24 hours before the end '
            'of the current period.\n'
            '• You can manage and cancel subscriptions in your device\'s Settings → Apple ID → Subscriptions.\n'
            '• Refunds are handled by Apple in accordance with their refund policy.',
      ),
      _Section(
        title: '6. Your Content',
        body: '• Meal descriptions, photos, voice recordings, and chat messages you submit remain your content.\n'
            '• By using the App, you grant us a limited license to process your content for the '
            'purpose of providing the service.\n'
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
        body: 'All content, design, algorithms, and methodologies in the App are the intellectual '
            'property of Individual Entrepreneur Igor Zuev, except for your user-generated content. '
            'The Kayfit name and logo are trademarks of Individual Entrepreneur Igor Zuev.',
      ),
      _Section(
        title: '9. Account Deletion',
        body: 'You may delete your account at any time from Settings → Delete Account. Upon deletion:\n'
            '• All your personal data, health information, meal history, and chat history will be '
            'permanently removed from our servers.\n'
            '• This action is irreversible.\n'
            '• Any active subscription should be cancelled separately through Apple\'s subscription management.',
      ),
      _Section(
        title: '10. Limitation of Liability',
        body: '• The App is provided "as is" without warranties of any kind.\n'
            '• We are not liable for any damages arising from your use of the App, including health '
            'outcomes, inaccurate nutritional data, or AI-generated recommendations.\n'
            '• Our total liability shall not exceed the amount you paid for the App in the 12 months '
            'preceding the claim.',
      ),
      _Section(
        title: '11. Changes to These Terms',
        body: 'We may update these Terms from time to time. We will notify you of material changes '
            'through the App. Your continued use after changes constitutes acceptance. '
            'If you disagree with updated Terms, you should stop using the App and delete your account.',
      ),
      _Section(
        title: '12. Governing Law',
        body: 'These Terms are governed by the laws of Georgia. Any disputes shall be resolved '
            'in the courts of Tbilisi, Georgia.',
      ),
      _Section(
        title: '13. Contact',
        body: 'Email: artemeree@gmail.com\n'
            'Individual Entrepreneur Igor Zuev\n'
            'Registration No. 300411551\n'
            'Georgia, Tbilisi City, Samgori District, Varketili Settlement, '
            'Array III, Zemo Plateau N33a, Floor 1, Apartment N3a\n\n'
            'Last updated: May 28, 2026',
      ),
    ]);
  }
}

// ─── Subscription Terms ──────────────────────────────────────────────────────

class _SubscriptionTerms extends StatelessWidget {
  final bool isRu;
  const _SubscriptionTerms({required this.isRu});

  @override
  Widget build(BuildContext context) =>
      isRu ? const _SubscriptionTermsRu() : const _SubscriptionTermsEn();
}

class _SubscriptionTermsRu extends StatelessWidget {
  const _SubscriptionTermsRu();

  @override
  Widget build(BuildContext context) {
    return const _DocContent(sections: [
      _Section(
        title: 'Условия подписки Kayfit',
        body: '',
        isHeadline: true,
      ),
      _Section(
        title: '1. Стороны',
        body: 'Настоящие Условия регулируют отношения между пользователем и Индивидуальным '
            'предпринимателем Чистяковым Артёмом Михайловичем (далее — Продавец), '
            'осуществляющим продажу подписки Kayfit Premium на территории Российской Федерации.\n\n'
            'ИП Чистяков Артём Михайлович\n'
            'ИНН: 645006236405\n'
            'ОГРНИП: 323645700098707\n'
            'Адрес: 410031, Российская Федерация, Саратовская обл., '
            'г. Саратов, наб. Космонавтов, д. 8, кв. 58\n'
            'Email: artemeree@gmail.com',
      ),
      _Section(
        title: '2. Предмет подписки',
        body: 'Kayfit Premium — платная подписка, открывающая полный доступ к функциям приложения:\n'
            '• Распознавание блюд по фотографии (ИИ)\n'
            '• Голосовой ввод приёмов пищи\n'
            '• Расчёт КБЖУ с детализацией по ингредиентам\n'
            '• ИИ-нутрициолог в чате\n'
            '• Персональный план суточных целей по питанию\n\n'
            'Без подписки доступен только ручной ввод продуктов.\n'
            'Подписка действует на одном Apple ID. Семейный доступ не предусмотрен.',
      ),
      _Section(
        title: '3. Тарифные планы и стоимость',
        body: 'Доступны три плана подписки:\n'
            '• 1 месяц\n'
            '• 3 месяца\n'
            '• 1 год\n\n'
            'Актуальная стоимость каждого плана отображается в приложении непосредственно перед '
            'подтверждением покупки. Цены устанавливаются через Apple App Store и могут различаться '
            'в зависимости от страны и валюты, определяемых вашим Apple ID.\n\n'
            'Продавец не обрабатывает платёжные данные (номер карты, данные Apple Pay) — '
            'они остаются исключительно у Apple.',
      ),
      _Section(
        title: '4. Бесплатный пробный период',
        body: 'При первом оформлении подписки предоставляется 7-дневный бесплатный пробный период. '
            'Во время пробного периода полный доступ к Premium открыт без списания средств.\n\n'
            'По окончании пробного периода автоматически списывается стоимость выбранного плана, '
            'если подписка не была отменена заблаговременно.\n\n'
            'Пробный период предоставляется один раз на Apple ID. При смене плана или повторной '
            'подписке пробный период не применяется.\n\n'
            'Чтобы избежать списания: отмените подписку через App Store не менее чем за 24 часа '
            'до окончания пробного периода.',
      ),
      _Section(
        title: '5. Автоматическое продление',
        body: 'Подписка возобновляется автоматически на тот же срок по истечении каждого '
            'расчётного периода, если не была отменена.\n\n'
            'Условия автопродления:\n'
            '• Оплата списывается в течение 24 часов до окончания текущего периода\n'
            '• Размер списания — стоимость плана, действующая на момент продления\n'
            '• Подтверждение продления приходит от Apple\n\n'
            'Apple может приостановить продление при наличии проблем с платёжными данными.',
      ),
      _Section(
        title: '6. Льготный период (Billing Grace Period)',
        body: 'В случае временных проблем с платёжными данными Apple может предоставить льготный '
            'период (Billing Grace Period) продолжительностью до 16 дней. В течение льготного '
            'периода доступ к Premium сохраняется, пока Apple повторно обрабатывает платёж.\n\n'
            'Если оплата так и не прошла — по истечении льготного периода подписка переходит '
            'в статус «Истекшая» и Premium-функции блокируются.\n\n'
            'Для обновления платёжных данных: '
            'Настройки iPhone → ваш Apple ID → Оплата и доставка.',
      ),
      _Section(
        title: '7. Отмена подписки',
        body: 'Отменить подписку можно в любое время:\n\n'
            'Настройки iPhone → ваш Apple ID → Подписки → Kayfit → Отменить подписку\n\n'
            'После отмены:\n'
            '• Подписка остаётся активной до конца оплаченного периода\n'
            '• Средства за неиспользованный период не возвращаются\n'
            '• По истечении периода Premium-функции блокируются\n'
            '• Все данные сохраняются — их можно просмотреть после окончания подписки\n\n'
            'Отмена подписки не удаляет аккаунт. '
            'Для удаления аккаунта перейдите в Настройки → Удалить аккаунт.',
      ),
      _Section(
        title: '8. Восстановление покупок',
        body: 'Если Premium-доступ не восстановился после переустановки приложения или смены '
            'устройства — нажмите кнопку «Восстановить покупки» в разделе Настройки → Подписка. '
            'Функция работает при условии, что активная подписка привязана к вашему Apple ID.',
      ),
      _Section(
        title: '9. Возврат средств',
        body: 'Все платежи через Apple In-App Purchase регулируются политикой возвратов Apple. '
            'Продавец не осуществляет возвраты самостоятельно.\n\n'
            'Для запроса возврата:\n'
            '1. Перейдите на reportaproblem.apple.com\n'
            '2. Выберите транзакцию Kayfit\n'
            '3. Выберите причину и отправьте запрос\n\n'
            'Или обратитесь в поддержку Apple: support.apple.com/ru-ru/billing\n\n'
            'По вопросам, не связанным с платёжными операциями: artemeree@gmail.com',
      ),
      _Section(
        title: '10. Изменение условий и цен',
        body: 'Продавец вправе изменять стоимость подписки и условия пробного периода. '
            'О существенных изменениях мы уведомим вас через приложение или по электронной почте '
            'не менее чем за 30 дней до вступления изменений в силу.\n\n'
            'Apple также может уведомлять вас об изменении цен через App Store '
            'в соответствии со своими правилами.\n\n'
            'Продолжение использования подписки после вступления изменений в силу '
            'означает согласие с новыми условиями.',
      ),
      _Section(
        title: '11. Ограничение ответственности',
        body: 'Продавец не несёт ответственности за:\n'
            '• Технические сбои на стороне Apple (платежи, уведомления о продлении)\n'
            '• Прерывания доступа к Premium из-за проблем с платёжными данными\n'
            '• Неточности в результатах ИИ-распознавания питания\n\n'
            'Максимальная ответственность Продавца ограничена суммой, фактически уплаченной '
            'пользователем в течение 12 месяцев, предшествующих предъявлению претензии.',
      ),
      _Section(
        title: '12. Применимое право',
        body: 'Настоящие Условия регулируются законодательством Российской Федерации. '
            'Споры подлежат рассмотрению в суде по месту жительства потребителя либо '
            'по месту нахождения Продавца (г. Саратов) — по выбору потребителя.\n\n'
            'Настоящие Условия не ограничивают права потребителей, предусмотренные '
            'Законом РФ «О защите прав потребителей».',
      ),
      _Section(
        title: '13. Контакты',
        body: 'Email: artemeree@gmail.com\n'
            'ИП Чистяков Артём Михайлович\n'
            'ИНН: 645006236405\n'
            'ОГРНИП: 323645700098707\n'
            '410031, Российская Федерация, Саратовская обл., '
            'г. Саратов, наб. Космонавтов, д. 8, кв. 58\n\n'
            'Последнее обновление: 28 мая 2026 г.',
      ),
    ]);
  }
}

class _SubscriptionTermsEn extends StatelessWidget {
  const _SubscriptionTermsEn();

  @override
  Widget build(BuildContext context) {
    return const _DocContent(sections: [
      _Section(
        title: 'Kayfit Subscription Terms',
        body: '',
        isHeadline: true,
      ),
      _Section(
        title: '1. Parties',
        body: 'These Terms govern the relationship between you and Individual Entrepreneur '
            'Igor Zuev (hereinafter "Seller"), who sells Kayfit Premium subscriptions '
            'to users outside the Russian Federation.\n\n'
            'Individual Entrepreneur Igor Zuev\n'
            'Registration No. 300411551\n'
            'Georgia, Tbilisi City, Samgori District, Varketili Settlement, '
            'Array III, Zemo Plateau N33a, Floor 1, Apartment N3a\n'
            'Email: artemeree@gmail.com',
      ),
      _Section(
        title: '2. What You Get',
        body: 'Kayfit Premium unlocks full access to AI-powered features:\n'
            '• Photo meal recognition (AI)\n'
            '• Voice meal logging\n'
            '• Detailed calorie & macro breakdown\n'
            '• AI nutritionist chat\n'
            '• Personalized daily nutrition plan\n\n'
            'Without a subscription, only manual food entry is available.\n'
            'Subscription is tied to one Apple ID. Family Sharing is not supported.',
      ),
      _Section(
        title: '3. Plans & Pricing',
        body: 'Three subscription plans are available:\n'
            '• 1 month\n'
            '• 3 months\n'
            '• 1 year\n\n'
            'Current pricing for each plan is displayed in the App immediately before purchase '
            'confirmation. Prices are set via Apple App Store and may vary by country and '
            'currency based on your Apple ID.\n\n'
            'The Seller does not process your payment details (card number, Apple Pay data) — '
            'these remain exclusively with Apple.',
      ),
      _Section(
        title: '4. Free Trial',
        body: 'A 7-day free trial is offered when you first subscribe. During the trial, '
            'full Premium access is available at no charge.\n\n'
            'When the trial ends, the cost of your selected plan is automatically charged '
            'unless you cancel beforehand.\n\n'
            'The trial is available once per Apple ID. It does not apply when switching plans '
            'or resubscribing.\n\n'
            'To avoid being charged: cancel at least 24 hours before the trial ends via App Store.',
      ),
      _Section(
        title: '5. Auto-Renewal',
        body: 'Your subscription renews automatically for the same period unless cancelled.\n\n'
            'Auto-renewal terms:\n'
            '• Payment is charged within 24 hours before the end of the current period\n'
            '• The charge equals the plan price at the time of renewal\n'
            '• Renewal confirmation is sent by Apple\n\n'
            'Apple may pause renewal if there are issues with your payment method.',
      ),
      _Section(
        title: '6. Billing Grace Period',
        body: 'If there are temporary issues with your payment method, Apple may grant a '
            'Billing Grace Period of up to 16 days. During this period, Premium access '
            'is maintained while Apple retries the payment.\n\n'
            'If payment ultimately fails, the subscription moves to Expired status '
            'and Premium features are blocked.\n\n'
            'To update your payment method: '
            'iPhone Settings → your Apple ID → Payment & Shipping.',
      ),
      _Section(
        title: '7. Cancellation',
        body: 'You can cancel at any time:\n\n'
            'iPhone Settings → your Apple ID → Subscriptions → Kayfit → Cancel Subscription\n\n'
            'After cancellation:\n'
            '• Subscription remains active until the end of the paid period\n'
            '• No refund is issued for the unused portion\n'
            '• Premium features are blocked when the period expires\n'
            '• Your data is retained — you can view it after the subscription ends\n\n'
            'Cancelling a subscription does not delete your account. '
            'To delete your account go to Settings → Delete Account.',
      ),
      _Section(
        title: '8. Restore Purchases',
        body: 'If Premium access is not restored after reinstalling the App or switching devices, '
            'tap "Restore Purchases" in Settings → Subscription. This works as long as an active '
            'subscription is linked to your Apple ID.',
      ),
      _Section(
        title: '9. Refunds',
        body: 'All payments via Apple In-App Purchase are governed by Apple\'s refund policy. '
            'The Seller does not process refunds directly.\n\n'
            'To request a refund:\n'
            '1. Go to reportaproblem.apple.com\n'
            '2. Select your Kayfit transaction\n'
            '3. Choose a reason and submit\n\n'
            'Or contact Apple Support: support.apple.com/billing\n\n'
            'For non-payment questions: artemeree@gmail.com',
      ),
      _Section(
        title: '10. Price & Term Changes',
        body: 'The Seller may change subscription pricing and trial terms. We will notify you '
            'through the App or by email at least 30 days before changes take effect.\n\n'
            'Apple may also notify you of price changes via App Store per its own policies.\n\n'
            'Continued use of the subscription after changes take effect constitutes acceptance.',
      ),
      _Section(
        title: '11. Limitation of Liability',
        body: 'The Seller is not liable for:\n'
            '• Technical failures on Apple\'s side (payments, renewal notifications)\n'
            '• Premium access interruptions due to payment issues\n'
            '• Inaccuracies in AI-powered meal recognition results\n\n'
            'The Seller\'s maximum liability is limited to the amount actually paid by you '
            'in the 12 months preceding the claim.',
      ),
      _Section(
        title: '12. Governing Law',
        body: 'These Terms are governed by the laws of Georgia. Any disputes shall be resolved '
            'in the courts of Tbilisi, Georgia.\n\n'
            'These Terms do not limit any consumer rights available under applicable law.',
      ),
      _Section(
        title: '13. Contact',
        body: 'Email: artemeree@gmail.com\n'
            'Individual Entrepreneur Igor Zuev\n'
            'Registration No. 300411551\n'
            'Georgia, Tbilisi City, Samgori District, Varketili Settlement, '
            'Array III, Zemo Plateau N33a, Floor 1, Apartment N3a\n\n'
            'Last updated: May 28, 2026',
      ),
    ]);
  }
}

// ─── Subscription Data Policy ────────────────────────────────────────────────

class _SubscriptionPrivacy extends StatelessWidget {
  final bool isRu;
  const _SubscriptionPrivacy({required this.isRu});

  @override
  Widget build(BuildContext context) =>
      isRu ? const _SubscriptionPrivacyRu() : const _SubscriptionPrivacyEn();
}

class _SubscriptionPrivacyRu extends StatelessWidget {
  const _SubscriptionPrivacyRu();

  @override
  Widget build(BuildContext context) {
    return const _DocContent(sections: [
      _Section(
        title: 'Обработка данных подписки — Kayfit',
        body: '',
        isHeadline: true,
      ),
      _Section(
        title: '1. Кто обрабатывает данные',
        body: 'Обработку данных, связанных с подпиской Kayfit Premium, осуществляют:\n\n'
            '• Apple Inc. — как оператор платёжной системы Apple In-App Purchase. '
            'Apple обрабатывает все платёжные данные и хранит историю транзакций '
            'в соответствии с собственной политикой конфиденциальности: apple.com/legal/privacy\n\n'
            '• ИП Чистяков Артём Михайлович (ИНН 645006236405) — Продавец для российских '
            'пользователей. Продавец получает от Apple только обезличенные сведения о статусе '
            'подписки через RevenueCat SDK (активна / истекла / льготный период) и не имеет '
            'доступа к вашим платёжным реквизитам.',
      ),
      _Section(
        title: '2. Какие данные собираются',
        body: '• Статус подписки (активна, истекла, льготный период, отменена)\n'
            '• Идентификатор продукта выбранного плана (1 мес / 3 мес / 1 год)\n'
            '• Дата начала и окончания расчётного периода\n'
            '• Факт использования бесплатного пробного периода\n\n'
            'Номер карты, данные Apple Pay и иные платёжные реквизиты Продавцу '
            'не передаются и не хранятся на наших серверах.',
      ),
      _Section(
        title: '3. Цель обработки',
        body: 'Данные о статусе подписки используются исключительно для:\n'
            '• Разблокировки Premium-функций при активной подписке\n'
            '• Блокировки Premium-функций при истечении или отмене подписки\n'
            '• Отображения статуса подписки в настройках приложения\n\n'
            'Основание обработки — исполнение договора (ст. 6 ч. 1 п. 5 ФЗ-152).',
      ),
      _Section(
        title: '4. Хранение и удаление',
        body: 'Данные о статусе подписки хранятся на серверах в России в период действия '
            'вашего аккаунта. При удалении аккаунта все связанные данные о подписке '
            'безвозвратно удаляются.\n\n'
            'История транзакций хранится Apple в соответствии с её политикой — '
            'Продавец не может управлять этими данными.',
      ),
      _Section(
        title: '5. Контакты',
        body: 'Email: artemeree@gmail.com\n'
            'ИП Чистяков Артём Михайлович\n'
            'ИНН: 645006236405\n'
            'ОГРНИП: 323645700098707\n'
            '410031, Российская Федерация, Саратовская обл., '
            'г. Саратов, наб. Космонавтов, д. 8, кв. 58\n\n'
            'Последнее обновление: 28 мая 2026 г.',
      ),
    ]);
  }
}

class _SubscriptionPrivacyEn extends StatelessWidget {
  const _SubscriptionPrivacyEn();

  @override
  Widget build(BuildContext context) {
    return const _DocContent(sections: [
      _Section(
        title: 'Subscription Data Policy — Kayfit',
        body: '',
        isHeadline: true,
      ),
      _Section(
        title: '1. Who Processes Your Data',
        body: 'Subscription-related data for Kayfit Premium is processed by:\n\n'
            '• Apple Inc. — as the operator of the Apple In-App Purchase payment system. '
            'Apple processes all payment information and retains transaction history per its '
            'own Privacy Policy: apple.com/legal/privacy\n\n'
            '• Individual Entrepreneur Igor Zuev (Reg. No. 300411551) — the Seller for users '
            'outside Russia. The Seller receives only anonymized subscription status information '
            'from Apple via the RevenueCat SDK (active / expired / grace period) and has no '
            'access to your payment details.',
      ),
      _Section(
        title: '2. Data Collected',
        body: '• Subscription status (active, expired, grace period, cancelled)\n'
            '• Product identifier of your selected plan (1 month / 3 months / 1 year)\n'
            '• Billing period start and end dates\n'
            '• Whether the free trial has been used\n\n'
            'Card numbers, Apple Pay credentials, and other payment details are never '
            'transmitted to or stored by the Seller.',
      ),
      _Section(
        title: '3. Purpose of Processing',
        body: 'Subscription status data is used solely to:\n'
            '• Unlock Premium features when the subscription is active\n'
            '• Block Premium features when the subscription expires or is cancelled\n'
            '• Display subscription status in the App settings\n\n'
            'Legal basis: contract performance.',
      ),
      _Section(
        title: '4. Retention & Deletion',
        body: 'Subscription status data is retained on our servers for the duration of your '
            'account. Upon account deletion, all subscription-related data is permanently removed.\n\n'
            'Transaction history is retained by Apple per its own policy — '
            'the Seller has no control over that data.',
      ),
      _Section(
        title: '5. Contact',
        body: 'Email: artemeree@gmail.com\n'
            'Individual Entrepreneur Igor Zuev\n'
            'Registration No. 300411551\n'
            'Georgia, Tbilisi City, Samgori District, Varketili Settlement, '
            'Array III, Zemo Plateau N33a, Floor 1, Apartment N3a\n\n'
            'Last updated: May 28, 2026',
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
