import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
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
  List<Package> _discountPackages = [];
  bool _discountActive = false;

  static const _kTypes = [
    PackageType.monthly,
    PackageType.monthly,
    PackageType.threeMonth,
    PackageType.annual,
  ];

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _checkDiscountAndLoadPackages();
  }

  Future<void> _loadPackages() async {
    final offering = await ref.read(currentOfferingProvider.future);
    if (!mounted) return;
    setState(() => _packages = offering?.availablePackages ?? []);
  }

  Future<void> _checkDiscountAndLoadPackages() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final storedMs = prefs.getInt('paywall_discount_start_ms');
    if (storedMs == null) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - storedMs;
    if (elapsed >= 3600000) return;

    // Try dedicated RC "discount" offering first.
    final discountOff = await ref.read(discountOfferingProvider.future);
    if (!mounted) return;
    if (discountOff != null && discountOff.availablePackages.isNotEmpty) {
      setState(() {
        _discountActive = true;
        _discountPackages = discountOff.availablePackages;
      });
      return;
    }

    // Fallback: activate discount UI only when regular packages have Apple
    // intro pricing — that way prices actually change and the UI is honest.
    final offering = await ref.read(currentOfferingProvider.future);
    if (!mounted) return;
    final hasIntro = offering?.availablePackages
            .any((p) => p.storeProduct.introductoryPrice != null) ??
        false;
    if (hasIntro) {
      setState(() => _discountActive = true);
    }
  }

  // Returns the package used for purchase (discount if available, else regular).
  Package? _packageForIndex(int index) {
    final pkgs = (_discountActive && _discountPackages.isNotEmpty)
        ? _discountPackages
        : _packages;
    if (pkgs.isEmpty) return null;
    try {
      return pkgs.firstWhere(
        (p) => p.packageType == _kTypes[index],
        orElse: () => pkgs.first,
      );
    } catch (_) {
      return null;
    }
  }

  // Returns the original (full-price) package from the default offering.
  Package? _originalPackageForIndex(int index) {
    if (_packages.isEmpty) return null;
    try {
      return _packages.firstWhere(
        (p) => p.packageType == _kTypes[index],
        orElse: () => _packages.first,
      );
    } catch (_) {
      return null;
    }
  }

  String _priceLabel(int index) {
    final pkg = _packageForIndex(index);
    if (pkg == null) {
      return switch (index) {
        0 => 'затем месяц',
        1 => '— ₽/мес',
        2 => '— ₽/мес',
        3 => '— ₽/мес',
        _ => '',
      };
    }
    // Discount via intro pricing (no separate RC offering configured yet)
    if (_discountActive && _discountPackages.isEmpty) {
      final intro = pkg.storeProduct.introductoryPrice;
      if (intro != null) return intro.priceString;
    }
    return pkg.storeProduct.priceString;
  }

  // Returns the original price string for strikethrough display, or null if
  // no real discount is available for this index.
  String? _originalPriceLabel(int index) {
    if (!_discountActive) return null;
    if (_discountPackages.isNotEmpty) {
      // Discount comes from a separate RC offering — show regular price as strikethrough
      return _originalPackageForIndex(index)?.storeProduct.priceString;
    }
    // Discount comes from Apple intro pricing — show original price only if intro exists
    final pkg = _originalPackageForIndex(index);
    if (pkg?.storeProduct.introductoryPrice != null) {
      return pkg!.storeProduct.priceString;
    }
    return null;
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
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = safeBottom > keyboardBottom ? safeBottom : keyboardBottom;

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
                          originalPriceLabel: _originalPriceLabel(0),
                          selected: _selected == 0,
                          onTap: () => setState(() => _selected = 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PaywallPlanCard(
                          title: 'Месяц',
                          priceLabel: _priceLabel(1),
                          originalPriceLabel: _originalPriceLabel(1),
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
                          originalPriceLabel: _originalPriceLabel(2),
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
                          originalPriceLabel: _originalPriceLabel(3),
                          selected: _selected == 3,
                          badge: '🔥 −40%',
                          onTap: () => setState(() => _selected = 3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _DiscountTimerBanner(discountActive: _discountActive),
                  const SizedBox(height: 12),

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
                                  : _discountActive
                                      ? 'Подписаться со скидкой 20%'
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

                  _PromoCodeField(),
                  const SizedBox(height: 8),

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
    };
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DocumentScreen(type: docType),
      ),
    );
  }
}

enum _DocType { terms, privacy }

class _DiscountTimerBanner extends StatefulWidget {
  const _DiscountTimerBanner({required this.discountActive});
  final bool discountActive;

  @override
  State<_DiscountTimerBanner> createState() => _DiscountTimerBannerState();
}

class _DiscountTimerBannerState extends State<_DiscountTimerBanner> {
  Timer? _timer;
  int _remainingSecs = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMs = prefs.getInt('paywall_discount_start_ms');
    if (!mounted) return;
    if (storedMs == null) {
      setState(() => _loaded = true);
      return;
    }
    final remaining =
        3600 - ((DateTime.now().millisecondsSinceEpoch - storedMs) / 1000).round();
    if (remaining <= 0) {
      setState(() => _loaded = true);
      return;
    }
    setState(() {
      _remainingSecs = remaining;
      _loaded = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSecs <= 1) {
        _timer?.cancel();
        setState(() => _remainingSecs = 0);
      } else {
        setState(() => _remainingSecs--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _remainingSecs <= 0 || !widget.discountActive) return const SizedBox.shrink();
    final mins = (_remainingSecs ~/ 60).toString().padLeft(2, '0');
    final secs = (_remainingSecs % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4D6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '🔥 Скидка сгорает через  $mins:$secs',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kAccent,
        ),
      ),
    );
  }
}

class _PromoCodeField extends StatefulWidget {
  @override
  State<_PromoCodeField> createState() => _PromoCodeFieldState();
}

class _PromoCodeFieldState extends State<_PromoCodeField> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final response = await apiDio.post(
        '/api/promo/apply',
        data: {'code': code},
      );
      if (!mounted) return;
      final data = response.data;
      if (data is Map && data['already_applied'] == true) {
        setState(() {
          _isSuccess = true;
          _message = '✓ Промокод уже применён';
        });
      } else {
        setState(() {
          _isSuccess = true;
          _message = '✓ Промокод принят';
        });
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _message = e.toString().contains('404')
            ? 'Промокод не найден'
            : 'Ошибка. Попробуйте ещё раз.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Промокод от блогера',
                  hintStyle: const TextStyle(fontSize: 14, color: _kDimText),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE9D5CB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE9D5CB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kAccent),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, _) {
                final enabled = value.text.trim().isNotEmpty && !_loading;
                return TextButton(
                  onPressed: enabled ? _apply : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: enabled ? _kAccent : _kAccent.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Применить',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                );
              },
            ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: 6),
          Text(
            _message!,
            style: TextStyle(
              fontSize: 12,
              color: _isSuccess ? const Color(0xFF34A853) : const Color(0xFFE53935),
            ),
          ),
        ],
      ],
    );
  }
}

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
