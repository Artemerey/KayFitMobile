import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/subscription/subscription_provider.dart';
import 'payment_help_screen.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../settings/screens/document_screen.dart';

part 'tariffs_screen.g.dart';

// ─── Provider ──────────────────────────────────────────────────────────────────

@riverpod
Future<Map<String, dynamic>> tariffsData(TariffsDataRef ref) async {
  final resp = await apiDio.get('/api/payments/tariffs');
  return resp.data as Map<String, dynamic>;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

bool _isTrial(Map<String, dynamic> t) =>
    (t['is_trial'] as bool? ?? false) || t['code'] == 'trial';

String _tariffLabel(Map<String, dynamic> t, {bool isRu = true}) {
  final code = t['code'] as String? ?? '';
  if (isRu) {
    if (code == 'monthly') return '1 месяц';
    if (code == 'biannual') return '6 месяцев';
    if (code == 'quarterly') return '3 месяца';
    if (code == 'yearly') return '1 год';
    return t['title'] as String? ?? code;
  } else {
    if (code == 'monthly') return '1 month';
    if (code == 'biannual') return '6 months';
    if (code == 'quarterly') return '3 months';
    if (code == 'yearly') return '1 year';
    return t['title'] as String? ?? code;
  }
}

String _rubFormatted(num value) {
  final s = value
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '$s ₽';
}

String _usdFormatted(num rubles) {
  final dollars = (rubles / 90).round();
  return '\$$dollars';
}

String _totalPrice(Map<String, dynamic> t, {bool isRu = true}) {
  final price = (t['price'] as num?) ?? 0;
  return isRu ? _rubFormatted(price) : _usdFormatted(price);
}

String? _perMonthPrice(Map<String, dynamic> t, {bool isRu = true}) {
  final price = (t['price'] as num?)?.toDouble() ?? 0;
  final code = t['code'] as String? ?? '';
  if (isRu) {
    if (code == 'yearly') return '${_rubFormatted(price / 12)}/мес';
    if (code == 'biannual') return '${_rubFormatted(price / 6)}/мес';
    if (code == 'quarterly') return '${_rubFormatted(price / 3)}/мес';
    return null;
  } else {
    if (code == 'yearly') return '${_usdFormatted(price / 12)}/mo';
    if (code == 'biannual') return '${_usdFormatted(price / 6)}/mo';
    if (code == 'quarterly') return '${_usdFormatted(price / 3)}/mo';
    return null;
  }
}

String _billedAfterTrial(Map<String, dynamic> t, {bool isRu = true}) {
  final code = t['code'] as String? ?? '';
  if (isRu) {
    if (code == 'monthly') return 'Списание ежемесячно после 7-дневного триала';
    if (code == 'biannual') {
      return 'Списание каждые 6 мес. после 7-дневного триала';
    }
    if (code == 'quarterly') {
      return 'Списание ежеквартально после 7-дневного триала';
    }
    if (code == 'yearly') return 'Списание ежегодно после 7-дневного триала';
    return 'После 7-дневного пробного периода';
  } else {
    if (code == 'monthly') return 'Billed monthly after 7-day trial';
    if (code == 'biannual') return 'Billed every 6 months after 7-day trial';
    if (code == 'quarterly') return 'Billed every 3 months after 7-day trial';
    if (code == 'yearly') return 'Billed yearly after 7-day trial';
    return 'After 7-day trial period';
  }
}

String? _savingsBadge(Map<String, dynamic> t, {bool isRu = true}) {
  final price = (t['price'] as num?)?.toDouble() ?? 0;
  final full = (t['full_price'] as num?)?.toDouble() ?? 0;
  if (full <= price || full == 0) return null;
  final pct = ((1 - price / full) * 100).round();
  return isRu ? 'Экономия $pct%' : 'Save $pct%';
}

bool _isPopular(Map<String, dynamic> t) =>
    (t['code'] as String? ?? '') == 'yearly';

int _order(Map<String, dynamic> t) {
  final code = t['code'] as String? ?? '';
  if (code == 'monthly') return 1;
  if (code == 'biannual') return 2;
  if (code == 'quarterly') return 2;
  if (code == 'yearly') return 3;
  return 10;
}

// ─── Design tokens ─────────────────────────────────────────────────────────────

const _kDark = Color(0xFF1C1C1E);
const _kMuted = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);

// ─── Screen ────────────────────────────────────────────────────────────────────

class TariffsScreen extends ConsumerStatefulWidget {
  const TariffsScreen({super.key});

  @override
  ConsumerState<TariffsScreen> createState() => _TariffsScreenState();
}

class _TariffsScreenState extends ConsumerState<TariffsScreen>
    with WidgetsBindingObserver {
  int? _selectedId;
  bool _paying = false;

  Timer? _timer;
  DateTime? _saleEndsAt;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    AnalyticsService.tariffsViewed();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(backendSubscriptionProvider);
    }
  }

  void _startTimer(DateTime endsAt) {
    _saleEndsAt = endsAt;
    _timeLeft = endsAt.difference(DateTime.now());
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = endsAt.difference(DateTime.now());
      if (!mounted) return;
      setState(() => _timeLeft = left.isNegative ? Duration.zero : left);
      if (left.isNegative) _timer?.cancel();
    });
  }

  List<Map<String, dynamic>> _sorted(Map<String, dynamic> d) {
    final list = ((d['tariffs'] as List<dynamic>?) ?? [])
        .map((e) => e as Map<String, dynamic>)
        .where((t) => !_isTrial(t))
        .toList()
      ..sort((a, b) => _order(a).compareTo(_order(b)));
    return list;
  }

  void _onData(Map<String, dynamic> d) {
    final tariffs = _sorted(d);
    if (_selectedId == null && tariffs.isNotEmpty) {
      final def = tariffs.firstWhere(
        (t) => t['code'] == 'yearly',
        orElse: () => tariffs.first,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedId = def['id'] as int?);
      });
    }
    final showTimer = d['show_discount_timer'] as bool? ?? false;
    final expiresStr = d['discount_timer_expires_at'] as String?;
    if (showTimer && expiresStr != null && _saleEndsAt == null) {
      final endsAt = DateTime.tryParse(expiresStr);
      if (endsAt != null && endsAt.isAfter(DateTime.now())) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startTimer(endsAt);
        });
      }
    }
  }

  Future<void> _pay(Map<String, dynamic>? tariff) async {
    if (_selectedId == null) return;
    if (tariff != null) {
      AnalyticsService.subscriptionPurchaseStarted(
        tariff['code'] as String? ?? '',
        (tariff['price'] as num?)?.toDouble() ?? 0,
      );
    }
    setState(() => _paying = true);
    try {
      await openPaymentPage();
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isRu = locale.languageCode == 'ru';

    final data = ref.watch(tariffsDataProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: data.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (e, _) => Center(
          child: Text(
            isRu ? 'Не удалось загрузить тарифы' : 'Failed to load plans',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        data: (d) {
          _onData(d);
          final tariffs = _sorted(d);
          final showTimer = _saleEndsAt != null && _timeLeft > Duration.zero;
          final selectedTariff =
              tariffs.where((t) => t['id'] == _selectedId).firstOrNull;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, top + 56, 20, bottom + 148),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── Header ──────────────────────────────────────────
                        const Text(
                          'Kayfit Premium',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _kDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isRu
                              ? 'Распознавание блюд с помощью ИИ,\nанализ КБЖУ и персональный план.'
                              : 'AI-powered food recognition,\nnutrition tracking and personal plan.',
                          style: const TextStyle(
                            fontSize: 15,
                            color: _kMuted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        if (showTimer) ...[
                          _DiscountTimer(timeLeft: _timeLeft, isRu: isRu),
                          const SizedBox(height: 20),
                        ],

                        // ── Plan cards ──────────────────────────────────────
                        ...tariffs.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PlanCard(
                              tariff: t,
                              selected: t['id'] == _selectedId,
                              isRu: isRu,
                              onTap: () {
                                setState(() => _selectedId = t['id'] as int?);
                                AnalyticsService.tariffSelected(
                                  t['code'] as String? ?? '',
                                  (t['price'] as num?)?.toDouble() ?? 0,
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ── Russia payment banner (Russian only) ─────────────
                        if (isRu)
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const PaymentHelpScreen(),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _kBorder),
                              ),
                              child: Row(
                                children: const [
                                  Text('💳', style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Оплата в России. Узнайте как',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _kDark,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 13,
                                    color: _kMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
              ),

              // ── Fixed bottom bar ────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: _kBorder, width: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed:
                                  (_paying || _selectedId == null)
                                      ? null
                                      : () => _pay(selectedTariff),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.accent.withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _paying
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isRu
                                          ? 'Подписаться и начать 7-дневный триал'
                                          : 'Subscribe and start 7-day trial',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRu
                                ? 'Отмена через App Store в любое время'
                                : 'Cancel in App Store anytime',
                            style:
                                const TextStyle(fontSize: 12, color: _kMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          _FooterLinks(isRu: isRu),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Close button ────────────────────────────────────────────
              Positioned(
                top: top + 12,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close,
                      size: 17,
                      color: _kDark,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> tariff;
  final bool selected;
  final VoidCallback onTap;
  final bool isRu;

  const _PlanCard({
    required this.tariff,
    required this.selected,
    required this.onTap,
    this.isRu = true,
  });

  @override
  Widget build(BuildContext context) {
    final popular = _isPopular(tariff);
    final savings = _savingsBadge(tariff, isRu: isRu);
    final perMonth = _perMonthPrice(tariff, isRu: isRu);
    final billedNote = _billedAfterTrial(tariff, isRu: isRu);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentSoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : _kBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badges
            if (popular || savings != null) ...[
              Row(
                children: [
                  if (popular)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _kDark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isRu ? 'ПОПУЛЯРНОЕ' : 'POPULAR',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  if (popular && savings != null) const SizedBox(width: 6),
                  if (savings != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        savings,
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Plan name
            Text(
              _tariffLabel(tariff, isRu: isRu),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _kDark,
              ),
            ),
            const SizedBox(height: 6),

            // Price row: total LEFT, per-month RIGHT
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _totalPrice(tariff, isRu: isRu),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _kDark,
                  ),
                ),
                if (perMonth != null) ...[
                  const Spacer(),
                  Text(
                    perMonth,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),

            // Billed-after-trial note (only when selected)
            if (selected) ...[
              const SizedBox(height: 8),
              Text(
                billedNote,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.accent.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Discount timer ────────────────────────────────────────────────────────────

class _DiscountTimer extends StatelessWidget {
  final Duration timeLeft;
  final bool isRu;
  const _DiscountTimer({required this.timeLeft, this.isRu = true});

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = timeLeft.inHours;
    final m = timeLeft.inMinutes % 60;
    final s = timeLeft.inSeconds % 60;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isRu ? '🔥 Скидка заканчивается через' : '🔥 Discount ends in',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kDark,
            ),
          ),
          Text(
            '${_pad(h)}:${_pad(m)}:${_pad(s)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Footer links ──────────────────────────────────────────────────────────────

class _FooterLinks extends StatelessWidget {
  final bool isRu;
  const _FooterLinks({this.isRu = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Link(
          isRu ? 'Условия подписки' : 'Terms',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const DocumentScreen(
                type: DocumentType.subscriptionTerms,
              ),
            ),
          ),
        ),
        const _Dot(),
        _Link(
          isRu ? 'Политика' : 'Privacy',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const DocumentScreen(
                type: DocumentType.subscriptionPrivacy,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Link(this.label, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: _kMuted,
          decoration: TextDecoration.underline,
          decorationColor: _kMuted,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(' · ', style: TextStyle(fontSize: 12, color: _kMuted)),
    );
  }
}
