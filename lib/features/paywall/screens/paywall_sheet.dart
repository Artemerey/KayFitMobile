import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/subscription/subscription_provider.dart';
import '../../../core/subscription/subscription_state.dart';
import '../../settings/screens/document_screen.dart';
import '../widgets/paywall_feature_row.dart';
import '../widgets/paywall_plan_card.dart';

const _kBg = Color(0xFFFFF1EA);
const _kAccent = Color(0xFFFF597D);
const _kDimText = Color(0xFFAAB2BD);

Future<PaywallResult> showPaywallSheet(BuildContext context) async {
  final result = await showModalBottomSheet<PaywallResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PaywallSheetContent(),
  );
  return result ?? PaywallResult.cancelled;
}

class _PaywallSheetContent extends ConsumerStatefulWidget {
  const _PaywallSheetContent();

  @override
  ConsumerState<_PaywallSheetContent> createState() =>
      _PaywallSheetContentState();
}

class _PaywallSheetContentState extends ConsumerState<_PaywallSheetContent> {
  // Indices: 0 = trial (monthly), 1 = monthly, 2 = quarterly, 3 = yearly
  int _selected = 2; // quarterly pre-selected
  bool _loading = false;
  List<Package> _packages = [];

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final offering = await ref.read(currentOfferingProvider.future);
    if (!mounted) return;
    setState(() => _packages = offering?.availablePackages ?? []);
  }

  Package? _packageForIndex(int index) {
    if (_packages.isEmpty) return null;
    final types = [
      PackageType.monthly,
      PackageType.monthly,
      PackageType.threeMonth,
      PackageType.annual,
    ];
    try {
      return _packages.firstWhere(
        (p) => p.packageType == types[index],
        orElse: () => _packages.first,
      );
    } catch (_) {
      return null;
    }
  }

  String _priceLabel(int index) {
    final pkg = _packageForIndex(index);
    if (pkg == null) {
      // Fallback labels while RC loads or in simulator
      return switch (index) {
        0 => 'затем месяц',
        1 => '— ₽/мес',
        2 => '— ₽/мес',
        3 => '— ₽/мес',
        _ => '',
      };
    }
    return pkg.storeProduct.priceString;
  }

  bool _isTrial(int index) => index == 0;

  Future<void> _onSubscribe() async {
    final pkg = _packageForIndex(_selected);
    if (pkg == null) return;
    setState(() => _loading = true);
    try {
      final result =
          await ref.read(subscriptionNotifierProvider.notifier).purchase(pkg);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка покупки. Попробуйте ещё раз.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRedeemCode() async {
    if (!Platform.isIOS) return;
    setState(() => _loading = true);
    try {
      await Purchases.presentCodeRedemptionSheet();
      if (!mounted) return;
      // Refresh subscription state after redemption
      ref.invalidate(subscriptionNotifierProvider);
      final state = ref.read(subscriptionNotifierProvider);
      if (state is SubscriptionActive || state is SubscriptionGracePeriod) {
        Navigator.of(context).pop(PaywallResult.subscribed);
      }
    } on Exception catch (_) {
      // Sheet dismissed or cancelled — not an error
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onRestore() async {
    setState(() => _loading = true);
    try {
      await ref.read(subscriptionNotifierProvider.notifier).restore();
      if (!mounted) return;
      final state = ref.read(subscriptionNotifierProvider);
      if (state is SubscriptionActive || state is SubscriptionGracePeriod) {
        Navigator.of(context).pop(PaywallResult.subscribed);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Активная подписка не найдена'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка восстановления. Попробуйте ещё раз.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCDD1D6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero placeholder (swap for real asset once received)
                  _HeroPlaceholder(),
                  const SizedBox(height: 20),

                  // Headline
                  const Text(
                    'ИИ считает калории.\nТы просто ешь.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Сфотографируй тарелку, скажи голосом или спроси нутрициолога — KayFit запишет всё сам.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Feature rows
                  const Divider(color: Color(0xFFE9D5CB)),
                  const SizedBox(height: 8),
                  const PaywallFeatureRow(
                    emoji: '📸',
                    title: 'Фото → КБЖУ за секунды',
                    subtitle: 'ИИ определяет ингредиенты и вес порции',
                  ),
                  const PaywallFeatureRow(
                    emoji: '🎙️',
                    title: 'Скажи вслух',
                    subtitle: '«Съел куриный плов» → залогировано сразу',
                  ),
                  const PaywallFeatureRow(
                    emoji: '💬',
                    title: 'Нутрициолог в кармане',
                    subtitle: 'Спроси о питании — ответит и запишет',
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFFE9D5CB)),
                  const SizedBox(height: 20),

                  // Plan cards — 2×2 grid
                  Row(
                    children: [
                      Expanded(
                        child: PaywallPlanCard(
                          title: 'СТАРТ\n7 дней 🆓',
                          priceLabel: _priceLabel(0),
                          selected: _selected == 0,
                          onTap: () => setState(() => _selected = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PaywallPlanCard(
                          title: 'Месяц',
                          priceLabel: _priceLabel(1),
                          selected: _selected == 1,
                          onTap: () => setState(() => _selected = 1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: PaywallPlanCard(
                          title: '3 месяца',
                          priceLabel: _priceLabel(2),
                          selected: _selected == 2,
                          badge: '★ ЛУЧШИЙ',
                          onTap: () => setState(() => _selected = 2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PaywallPlanCard(
                          title: 'Год',
                          priceLabel: _priceLabel(3),
                          selected: _selected == 3,
                          badge: '🔥 −40%',
                          onTap: () => setState(() => _selected = 3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // CTA button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _onSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _kAccent.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isTrial(_selected)
                                  ? 'Начать 7 дней бесплатно'
                                  : 'Подписаться',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Trial note
                  if (_isTrial(_selected))
                    const Text(
                      'Отменить до конца 7 дней — ничего не спишется',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _kDimText),
                    ),
                  const SizedBox(height: 16),

                  // Promo code (iOS only)
                  if (Platform.isIOS)
                    TextButton(
                      onPressed: _loading ? null : _onRedeemCode,
                      child: const Text(
                        'У меня есть промокод',
                        style: TextStyle(fontSize: 14, color: _kAccent),
                      ),
                    ),

                  // Dismiss
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(PaywallResult.cancelled),
                    child: const Text(
                      'Нет, буду вводить руками',
                      style: TextStyle(fontSize: 14, color: _kDimText),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Footer links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FooterLink('Восстановить', onTap: _loading ? null : _onRestore),
                      const Text(' · ',
                          style: TextStyle(fontSize: 11, color: _kDimText)),
                      _FooterLink('Условия подписки',
                          onTap: () => _openDoc(context, _DocType.subscriptionTerms)),
                      const Text(' · ',
                          style: TextStyle(fontSize: 11, color: _kDimText)),
                      _FooterLink('Условия',
                          onTap: () => _openDoc(context, _DocType.terms)),
                      const Text(' · ',
                          style: TextStyle(fontSize: 11, color: _kDimText)),
                      _FooterLink('Политика',
                          onTap: () => _openDoc(context, _DocType.privacy)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDoc(BuildContext context, _DocType type) {
    final docType = switch (type) {
      _DocType.terms => DocumentType.termsOfService,
      _DocType.privacy => DocumentType.privacyPolicy,
      _DocType.subscriptionTerms => DocumentType.subscriptionTerms,
    };
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DocumentScreen(type: docType),
      ),
    );
  }
}

enum _DocType { terms, privacy, subscriptionTerms }

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, {required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: _kDimText,
          decoration: TextDecoration.underline,
          decorationColor: _kDimText,
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Swap this widget for Image.asset('assets/paywall/hero.png') once the asset arrives
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4D6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Text('🍽️', style: TextStyle(fontSize: 64)),
      ),
    );
  }
}
