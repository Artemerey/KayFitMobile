import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/i18n/generated/app_localizations.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import 'payment_method_sheet.dart';

part 'tariffs_screen.g.dart';

// ─── Provider ──────────────────────────────────────────────────────────────────

@riverpod
Future<Map<String, dynamic>> tariffsData(TariffsDataRef ref) async {
  final resp = await apiDio.get('/api/payments/tariffs');
  return resp.data as Map<String, dynamic>;
}

// ─── Helpers (mirrors Tariffs.tsx logic exactly) ───────────────────────────────

bool _isTrial(Map<String, dynamic> t) =>
    (t['is_trial'] as bool? ?? false) || t['code'] == 'trial';

String _tariffLabel(Map<String, dynamic> t, AppLocalizations l10n) {
  if (_isTrial(t)) return l10n.tariffs_trial;
  final code = t['code'] as String? ?? '';
  if (code == 'monthly') return l10n.tariffs_monthly;
  if (code == 'yearly') return l10n.tariffs_yearly;
  if (code == 'quarterly') return l10n.tariffs_quarterly;
  return t['title'] as String? ?? code;
}

String _rub(num value) {
  final s = value
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '\u00a0');
  return '$s ₽';
}

String _formatPrice(Map<String, dynamic> t, AppLocalizations l10n) {
  final price = (t['price'] as num?)?.toDouble() ?? 0;
  final durationDays = ((t['duration_days'] as num?)?.toInt() ?? 0);
  final code = t['code'] as String? ?? '';
  if (_isTrial(t)) return '${_rub(price)} ${l10n.tariffs_per_3days}';
  if (durationDays > 0) return '${_rub(price / durationDays)} ${l10n.tariffs_per_day}';
  if (code == 'quarterly') return '${_rub(price)} ${l10n.tariffs_per_3mo}';
  return _rub(price);
}

String _secondaryLine(Map<String, dynamic> t, AppLocalizations l10n) {
  final code = t['code'] as String? ?? '';
  if (_isTrial(t)) return l10n.tariffs_trial_then;
  if (code == 'monthly') return l10n.tariffs_monthly_billing;
  if (code == 'yearly') return l10n.tariffs_yearly_save;
  if (code == 'quarterly') return l10n.tariffs_best_value;
  final price = (t['price'] as num?)?.toDouble() ?? 0;
  final fullPrice = (t['full_price'] as num?)?.toDouble() ?? price;
  if (fullPrice > price) {
    return l10n.tariffs_no_discount(_rub(fullPrice));
  }
  return l10n.tariffs_monthly_billing;
}

bool _showDiscountBadge(Map<String, dynamic> t) {
  final code = t['code'] as String? ?? '';
  if (code != 'yearly') return false;
  final price = (t['price'] as num?)?.toDouble() ?? 0;
  final fullPrice = (t['full_price'] as num?)?.toDouble() ?? price;
  return fullPrice > price;
}

int _order(Map<String, dynamic> t) {
  if (_isTrial(t)) return 0;
  final code = t['code'] as String? ?? '';
  if (code == 'monthly') return 1;
  if (code == 'yearly') return 2;
  if (code == 'quarterly') return 3;
  return 10;
}

// ─── Screen ────────────────────────────────────────────────────────────────────

// Background colour matching frontend #fff1ea
const _kBgColor = Color(0xFFFFF1EA);
const _kPink = Color(0xFFFF597D);
const _kCardBg = Colors.white;
const _kCardSelectedBg = Color(0x29FF597D); // rgba(255,89,125,0.16)
const _kChipBg = Color(0xFFFFF1EA);
const _kSubtitleColor = Color(0xFFAAB2BD);
const _kTextDark = Color(0xFF060606);

class TariffsScreen extends ConsumerStatefulWidget {
  const TariffsScreen({super.key});

  @override
  ConsumerState<TariffsScreen> createState() => _TariffsScreenState();
}

class _TariffsScreenState extends ConsumerState<TariffsScreen> {
  int? _selectedId;
  final _emailCtrl = TextEditingController();
  bool _paying = false;
  String? _payError;

  // Discount timer
  Timer? _timer;
  DateTime? _saleEndsAt;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    AnalyticsService.tariffsViewed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    super.dispose();
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
        .toList()
      ..sort((a, b) => _order(a).compareTo(_order(b)));
    return list;
  }

  void _onData(Map<String, dynamic> d) {
    final tariffs = _sorted(d);
    if (_selectedId == null && tariffs.isNotEmpty) {
      final def = tariffs.firstWhere(
        (t) => t['code'] == 'yearly',
        orElse: () => tariffs.firstWhere(
          (t) => t['code'] == 'monthly',
          orElse: () => tariffs.first,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (mounted) setState(() => _selectedId = def['id'] as int?);
        },
      );
    }
    final showTimer = d['show_discount_timer'] as bool? ?? false;
    final expiresStr = d['discount_timer_expires_at'] as String?;
    if (showTimer && expiresStr != null && _saleEndsAt == null) {
      final endsAt = DateTime.tryParse(expiresStr);
      if (endsAt != null && endsAt.isAfter(DateTime.now())) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            if (mounted) _startTimer(endsAt);
          },
        );
      }
    }
  }

  Future<void> _pay(BuildContext context, AppLocalizations l10n, {Map<String, dynamic>? tariff}) async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _payError = l10n.tariffs_email_error);
      return;
    }
    if (_selectedId == null) return;
    if (tariff != null) {
      AnalyticsService.subscriptionPurchaseStarted(
        tariff['code'] as String? ?? '',
        (tariff['price'] as num?)?.toDouble() ?? 0,
      );
    }
    if (!context.mounted) return;
    final selectedTariff = tariff;
    if (selectedTariff == null) return;

    await showPaymentMethodSheet(
      context,
      tariffTitle: _tariffLabel(selectedTariff, l10n),
      price: _formatPrice(selectedTariff, l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = ref.watch(tariffsDataProvider);

    return Scaffold(
      backgroundColor: _kBgColor,
      body: data.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (e, _) => Center(
          child: Text(
            l10n.tariffs_load_error,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        data: (d) {
          _onData(d);
          final tariffs = _sorted(d);
          final showTimer = _saleEndsAt != null && _timeLeft > Duration.zero;

          return Stack(
            children: [
              // Pink header background
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 104,
                  decoration: const BoxDecoration(
                    color: _kPink,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                  ),
                ),
              ),

              SafeArea(
                bottom: false,
                child: CustomScrollView(
                  slivers: [
                    // ── Close button ──────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 77,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(32),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '×',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  height: 1,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── Title ────────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 28, 22, 8),
                            child: Text(
                              l10n.tariffs_title_full,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: _kTextDark,
                                height: 1.25,
                              ),
                            ),
                          ),

                          // ── Feature tags ──────────────────────────────────
                          _FeatureTags(l10n: l10n),
                          const SizedBox(height: 12),

                          // ── Discount timer ────────────────────────────────
                          if (showTimer) ...[
                            _DiscountTimer(timeLeft: _timeLeft, l10n: l10n),
                            const SizedBox(height: 8),
                          ],

                          // ── Tariff cards ──────────────────────────────────
                          if (tariffs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                l10n.tariffs_no_plans,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                              ),
                            ),
                          ...tariffs.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TariffCard(
                              tariff: t,
                              l10n: l10n,
                              selected: t['id'] == _selectedId,
                              onTap: () {
                                setState(() => _selectedId = t['id'] as int?);
                                AnalyticsService.tariffSelected(
                                  t['code'] as String? ?? '',
                                  (t['price'] as num?)?.toDouble() ?? 0,
                                );
                              },
                            ),
                          )),

                          const SizedBox(height: 4),

                          // ── Hints ─────────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
                            child: Text(
                              l10n.tariffs_cancel_anytime,
                              style: const TextStyle(
                                color: _kTextDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                            child: Text(
                              l10n.tariffs_optimal_months,
                              style: const TextStyle(
                                color: _kTextDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          // ── Email ─────────────────────────────────────────
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 15, color: _kTextDark),
                            onChanged: (_) => setState(() => _payError = null),
                            decoration: InputDecoration(
                              hintText: l10n.tariffs_email_hint,
                              hintStyle: const TextStyle(color: _kSubtitleColor),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(32),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(32),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(32),
                                borderSide: const BorderSide(color: _kPink, width: 2),
                              ),
                            ),
                          ),

                          if (_payError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _payError!,
                              style: const TextStyle(
                                color: AppColors.accentOver, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],

                          const SizedBox(height: 12),

                          // ── Submit button ─────────────────────────────────
                          Center(
                            child: GestureDetector(
                              onTap: (_paying || _selectedId == null)
                                  ? null
                                  : () {
                                      final selectedTariff = tariffs.where((t) => t['id'] == _selectedId).firstOrNull;
                                      _pay(context, l10n, tariff: selectedTariff);
                                    },
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity:
                                    (_paying || _selectedId == null) ? 0.6 : 1.0,
                                child: Container(
                                  width: 232,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: _kPink,
                                    borderRadius: BorderRadius.circular(123),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x3DFF597D),
                                        blurRadius: 24,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: _paying
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          l10n.tariffs_get_plan,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Feature tags (2-column grid, first full-width) ────────────────────────────

class _FeatureTags extends StatelessWidget {
  final AppLocalizations l10n;
  const _FeatureTags({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final tags = [
      l10n.tariffs_tag1,
      l10n.tariffs_tag2,
      l10n.tariffs_tag3,
      l10n.tariffs_tag4,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        children: [
          // First tag — full width
          _Tag(text: tags[0], fullWidth: true),
          const SizedBox(height: 8),
          // Remaining tags in 2-column rows
          Row(
            children: [
              Expanded(child: _Tag(text: tags[1])),
              const SizedBox(width: 8),
              Expanded(child: _Tag(text: tags[2])),
            ],
          ),
          const SizedBox(height: 8),
          _Tag(text: tags[3], fullWidth: true),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final bool fullWidth;
  const _Tag({required this.text, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(512),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF362F41),
        ),
      ),
    );
  }
}

// ─── Discount timer ────────────────────────────────────────────────────────────

class _DiscountTimer extends StatelessWidget {
  final Duration timeLeft;
  final AppLocalizations l10n;
  const _DiscountTimer({required this.timeLeft, required this.l10n});

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = timeLeft.inHours;
    final m = timeLeft.inMinutes % 60;
    final s = timeLeft.inSeconds % 60;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _kPink, width: 2),
        borderRadius: BorderRadius.circular(24),
        color: _kPink.withValues(alpha: 0.16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: _kPink,
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            child: Text(
              l10n.tariffs_sale_ends,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.04 * 12,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimerBox(_pad(h)),
                const _TimerSep(),
                _TimerBox(_pad(m)),
                const _TimerSep(),
                _TimerBox(_pad(s)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerBox extends StatelessWidget {
  final String value;
  const _TimerBox(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.004),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _kTextDark,
        ),
      ),
    );
  }
}

class _TimerSep extends StatelessWidget {
  const _TimerSep();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w400,
          color: _kTextDark,
          fontStyle: FontStyle.normal,
        ),
      ),
    );
  }
}

// ─── Tariff card ───────────────────────────────────────────────────────────────

class _TariffCard extends StatelessWidget {
  final Map<String, dynamic> tariff;
  final AppLocalizations l10n;
  final bool selected;
  final VoidCallback onTap;

  const _TariffCard({
    required this.tariff,
    required this.l10n,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isYearly = (tariff['code'] as String? ?? '') == 'yearly';
    final showBadge = _showDiscountBadge(tariff);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        decoration: BoxDecoration(
          color: selected ? _kCardSelectedBg : _kCardBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: selected ? _kPink : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main row: title + price
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: label + secondary line
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tariffLabel(tariff, l10n),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _kTextDark,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _secondaryLine(tariff, l10n),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _kSubtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right: discount badge + price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showBadge) ...[
                      Container(
                        width: 32,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _kPink,
                          borderRadius: BorderRadius.circular(256),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '-50%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.02 * 9,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      _formatPrice(tariff, l10n),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: _kTextDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Yearly benefit chips
            if (isYearly) ...[
              const SizedBox(height: 12),
              _YearlyBenefits(l10n: l10n),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Yearly benefit chips (2×2 grid, first and last full-width) ───────────────

class _YearlyBenefits extends StatelessWidget {
  final AppLocalizations l10n;
  const _YearlyBenefits({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final chips = [
      l10n.tariffs_benefit1,
      l10n.tariffs_benefit2,
      l10n.tariffs_benefit3,
      l10n.tariffs_benefit4,
    ];

    return Column(
      children: [
        _Chip(text: chips[0], fullWidth: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Chip(text: chips[1])),
            const SizedBox(width: 8),
            Expanded(child: _Chip(text: chips[2])),
          ],
        ),
        const SizedBox(height: 8),
        _Chip(text: chips[3], fullWidth: true),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool fullWidth;
  const _Chip({required this.text, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kChipBg,
        borderRadius: BorderRadius.circular(512),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: _kTextDark,
        ),
      ),
    );
  }
}

