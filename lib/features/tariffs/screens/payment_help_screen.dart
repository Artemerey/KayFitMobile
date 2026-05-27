import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';

Future<String?> requestPaymentSession() async {
  try {
    final response = await apiDio.post<Map<String, dynamic>>(
      '/api/payments/request-session',
    );
    return response.data?['session_token'] as String?;
  } catch (_) {
    return null;
  }
}

Future<void> openPaymentPage() async {
  final session = await requestPaymentSession();
  const base = 'https://app.carbcounter.online/tariffs';
  final url = session != null ? '$base?session=$session' : base;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

const _kPageBg = Color(0xFFF9FAFB);
const _kCardBg = Colors.white;
const _kDark = Color(0xFF111827);
const _kMuted = Color(0xFF6B7280);
const _kPink = Color(0xFFFF597D);
const _kGreen = Color(0xFF16A34A);
const _kGreenLight = Color(0xFFDCFCE7);
const _kOrange = Color(0xFFEA580C);
const _kOrangeLight = Color(0xFFFFF7ED);
const _kBlueLight = Color(0xFFEFF6FF);
const _kBlueMuted = Color(0xFF2563EB);
const _kDivider = Color(0xFFE5E7EB);
const _kInfoBg = Color(0xFFF3F4F6);

class PaymentHelpScreen extends StatelessWidget {
  const PaymentHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kCardBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _kDivider,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _kDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _kPink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'KayFit',
              style: TextStyle(
                color: _kDark,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 56),
        children: [
          // ── Hero ──────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3 способа оплатить\nподписку в App Store',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _kDark,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Российские карты и мобильные платежи временно не работают в App Store. Вот проверенные способы:',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kMuted,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Method 1: Site (card / SBP) ───────────────────────────
          _MethodCard(
            iconWidget: const Icon(
              Icons.credit_card_rounded,
              color: _kGreen,
              size: 22,
            ),
            iconBg: _kGreenLight,
            badge: 'Быстро и просто',
            badgeColor: _kGreen,
            badgeBg: _kGreenLight,
            title: 'Оплата KayFit на сайте картой или СБП',
            description:
                'Оплатите на нашем сайте российской картой или через СБП — без App Store.',
            extra: Column(
              children: [
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: openPaymentPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Оформить подписку',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Method 2: Apple Gift Card ─────────────────────────────
          _MethodCard(
            iconWidget: const Text('🎁', style: TextStyle(fontSize: 20)),
            iconBg: _kOrangeLight,
            badge: 'Проще всего',
            badgeColor: _kOrange,
            badgeBg: _kOrangeLight,
            title: 'Подарочная карта Apple',
            description:
                'Пополните баланс Apple ID подарочной картой и оплатите подписку прямо в приложении.',
            extra: Column(
              children: [
                const SizedBox(height: 16),
                const _NumberedSteps(
                  steps: [
                    'Купите подарочную карту Apple (App Store & iTunes Gift Card)',
                    'App Store → профиль → «Погасить подарочную карту или код»',
                    'Введите код — баланс пополнится мгновенно',
                    'Вернитесь в KayFit и оформите подписку',
                  ],
                ),
                const SizedBox(height: 12),
                const _InfoNote(
                  text:
                      'Где купить: Ozon, Wildberries, Яндекс Маркет (поиск «подарочная карта Apple»), КупиКод, Plati.Market, GGsel, gift-code.ru. Оплата картой или СБП. Карта должна быть для региона вашего Apple ID.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Method 3: Apple ID region change ─────────────────────
          _MethodCard(
            iconWidget: const Text('🌏', style: TextStyle(fontSize: 20)),
            iconBg: _kBlueLight,
            badge: 'Автопродление',
            badgeColor: _kGreen,
            badgeBg: _kGreenLight,
            title: 'Смена региона Apple ID',
            description:
                'Переключите Apple ID на другую страну (Турция, Казахстан, США) и оплатите иностранной картой или через сервисы виртуальных карт.',
            extra: Column(
              children: [
                const SizedBox(height: 16),
                const _NumberedSteps(
                  steps: [
                    'Настройки iPhone → Apple ID → Медиаматериалы и покупки → Страна/регион',
                    'Выберите новый регион (например, Казахстан или Турцию)',
                    'Привяжите способ оплаты (карта или виртуальная карта через «Плати.ру» и подобные)',
                    'Оформите подписку KayFit — автопродление будет работать',
                  ],
                ),
                const SizedBox(height: 12),
                const _InfoNote(
                  text:
                      'Все данные приложений и покупки сохранятся. Подписки продолжат работать.',
                  isAccent: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── FAQ ───────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Частые вопросы',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _FaqSection(),
          const SizedBox(height: 32),

          // ── Footer ────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                const Text(
                  'Нужна помощь? Напишите нам',
                  style: TextStyle(fontSize: 13, color: _kMuted),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () =>
                      launchUrl(Uri.parse('mailto:artemeree@gmail.com')), // TODO: real email
                  child: const Text(
                    'artemeree@gmail.com', // TODO: replace with real support email
                    style: TextStyle(
                      fontSize: 14,
                      color: _kPink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    _FooterLink(label: 'Условия использования'),
                    Text('·', style: TextStyle(color: _kMuted, fontSize: 12)),
                    _FooterLink(label: 'Политика конфиденциальности'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Method card ───────────────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.iconWidget,
    required this.iconBg,
    required this.badge,
    required this.badgeColor,
    required this.badgeBg,
    required this.title,
    required this.description,
    required this.extra,
  });

  final Widget iconWidget;
  final Color iconBg;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final String title;
  final String description;
  final Widget extra;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + title + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: iconWidget,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kDark,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: _kMuted,
              height: 1.5,
            ),
          ),
          extra,
        ],
      ),
    );
  }
}

// ─── Numbered steps ────────────────────────────────────────────────────────────

class _NumberedSteps extends StatelessWidget {
  const _NumberedSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 10 : 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  steps[i],
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kDark,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Info note ─────────────────────────────────────────────────────────────────

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text, this.isAccent = false});

  final String text;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAccent ? const Color(0xFFEFF6FF) : _kInfoBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isAccent ? _kBlueMuted : _kMuted,
          height: 1.6,
        ),
      ),
    );
  }
}

// ─── FAQ section ───────────────────────────────────────────────────────────────

class _FaqSection extends StatelessWidget {
  const _FaqSection();

  static const _items = [
    (
      q: 'Почему не работает оплата в App Store?',
      a: 'Из-за ограничений Apple российские карты временно недоступны для оплаты в App Store. Используйте один из трёх способов выше.',
    ),
    (
      q: 'Подарочная карта какой страны нужна?',
      a: 'Карта должна соответствовать региону вашего Apple ID. Для российского аккаунта подойдут карты с пометкой «Россия» или «RU».',
    ),
    (
      q: 'Что будет с моими данными при смене региона?',
      a: 'Все данные, дневники питания и история в KayFit сохранятся. Приложения и покупки в App Store тоже не пропадут.',
    ),
    (
      q: 'Могу ли я перейти с App Store на веб-оплату?',
      a: 'Да. На экране тарифов нажмите «Оформить подписку» и выберите оплату через сайт. Восстановить веб-подписку в приложении можно кнопкой «Восстановить».',
    ),
    (
      q: 'Как отменить веб-подписку?',
      a: 'Войдите в личный кабинет на сайте KayFit → Настройки → Подписка → Отменить. Или напишите нам на artemeree@gmail.com.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(_items.length, (i) {
          return Column(
            children: [
              if (i > 0)
                const Divider(height: 1, thickness: 1, color: _kDivider),
              _FaqItem(question: _items[i].q, answer: _items[i].a),
            ],
          );
        }),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kDark,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: _kMuted,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.answer,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kMuted,
                    height: 1.6,
                  ),
                ),
              ),
              crossFadeState:
                  _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Footer link ───────────────────────────────────────────────────────────────

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        color: _kMuted,
        decoration: TextDecoration.underline,
        decorationColor: _kMuted,
      ),
    );
  }
}
