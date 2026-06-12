import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/navigation/navigation_providers.dart';
import '../../../core/review/app_review_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../paywall/widgets/paywall_feature_row.dart';

/// Minimum star rating that triggers the App Store review compose page.
/// Tapping 1–[_kStoreThreshold-1]★ thanks the user without opening the Store.
const _kStoreThreshold = 4;

/// How long the "month free" offer is framed as lasting. Drives the countdown
/// timer — pure urgency framing, the reward itself is not actually revoked.
const _kOfferWindow = Duration(hours: 1);

/// Post-onboarding "Get 1 month free" screen, styled as a limited-time gift
/// offer (GIFT badge + 1-hour countdown) to lift review conversion.
///
/// Shows a five-star rating UI. On 4–5★ the user is sent directly to the
/// App Store write-review form. On 1–3★ they are thanked locally. Either
/// way the screen persists a [SharedPreferences] flag so it shows exactly once.
class ReviewPromptScreen extends ConsumerStatefulWidget {
  const ReviewPromptScreen({super.key});

  @override
  ConsumerState<ReviewPromptScreen> createState() => _ReviewPromptScreenState();
}

class _ReviewPromptScreenState extends ConsumerState<ReviewPromptScreen>
    with SingleTickerProviderStateMixin {
  /// Currently highlighted star count (0 = nothing selected yet).
  int _rating = 0;

  /// True while the async finish sequence is running (opens store + persists flag).
  bool _isProcessing = false;

  /// Shown after a low-rating tap instead of the stars row.
  bool _showThanks = false;

  /// Time left on the framed limited offer; ticks down to zero.
  Duration _offerLeft = _kOfferWindow;
  Timer? _offerTimer;

  late final AnimationController _starsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    lowerBound: 0.85,
    upperBound: 1.0,
  )..value = 1.0;

  @override
  void initState() {
    super.initState();
    try {
      AnalyticsService.reviewPromptShown();
    } catch (_) {
      // Analytics is best-effort; never block the screen.
    }
    _offerTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_offerLeft.inSeconds <= 0) {
        t.cancel();
        return;
      }
      setState(() => _offerLeft -= const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    _starsController.dispose();
    super.dispose();
  }

  // ── Handlers ────────────────────────────────────────────────────────────────

  Future<void> _onStarTap(int rating) async {
    if (_isProcessing) return;
    HapticFeedback.lightImpact();
    setState(() => _rating = rating);

    try {
      AnalyticsService.reviewPromptStarsSelected(rating);
    } catch (_) {}

    // Brief pause so the user sees the star fill before we act.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    if (rating >= _kStoreThreshold) {
      setState(() => _isProcessing = true);
      await AppReviewService.openStoreReview();
      await _finish();
    } else {
      // Low rating — show thank-you message, then auto-dismiss.
      setState(() => _showThanks = true);
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      await _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('review_prompt_shown', true);
    ref.read(showReviewPromptProvider.notifier).state = false;
    // GoRouter redirect re-evaluates and sends the user to /journal-v2.
    if (mounted) context.go('/');
  }

  /// Formats the remaining offer time as HH:MM:SS for the countdown chip.
  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isRu = ref.watch(localeProvider).languageCode == 'ru';

    final title = isRu ? 'Месяц Premium в подарок' : '1 month of Premium, free';
    final subtitle = isRu
        ? 'Оцените приложение — и мы откроем полный доступ на 30 дней'
        : 'Rate the app and we’ll unlock full access for 30 days';
    final offerLabel = isRu ? 'Предложение сгорает через' : 'Offer ends in';
    final thanksText = isRu
        ? 'Спасибо за честный отзыв!\nМы пришлём вам бесплатный доступ.'
        : 'Thanks for your feedback!\nWe’ll send you free access.';
    final laterLabel = isRu ? 'Позже' : 'Maybe later';
    final tapPrompt = isRu
        ? 'Нажмите на звёзды, чтобы оценить'
        : 'Tap the stars to rate';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            children: [
              // Scrollable body so the perks list never clips on shorter devices.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 14),

                      // ── GIFT badge ───────────────────────────────────────
                      const _GiftBadge(),

                      const SizedBox(height: 20),

                      // ── Hero icon ────────────────────────────────────────
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B6B)
                                  .withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: Colors.white,
                          size: 46,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── Title ────────────────────────────────────────────
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 10),

                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // ── Countdown timer ──────────────────────────────────
                      _CountdownChip(
                        label: offerLabel,
                        time: _formatCountdown(_offerLeft),
                        expired: _offerLeft.inSeconds <= 0,
                      ),

                      const SizedBox(height: 24),

                      // ── What Premium unlocks (mirrors the tariffs screen) ─
                      _PremiumPerks(isRu: isRu),

                      const SizedBox(height: 28),

                      // ── Stars / Thank-you ────────────────────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _showThanks
                            ? _ThanksMessage(text: thanksText)
                            : _StarsRow(
                                rating: _rating,
                                onTap: _isProcessing ? null : _onStarTap,
                                tapPrompt: tapPrompt,
                              ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ── Later link (pinned) ──────────────────────────────────────
              TextButton(
                onPressed: _isProcessing ? null : _finish,
                child: Text(
                  laterLabel,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────────

/// "What Premium unlocks" card. Reuses [PaywallFeatureRow] and mirrors the
/// exact three perks listed on the tariffs/paywall screen so the gift offer and
/// the paid plan never drift apart.
class _PremiumPerks extends StatelessWidget {
  const _PremiumPerks({required this.isRu});

  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final header = isRu ? 'Что входит в Premium' : 'What you unlock';
    final perks = isRu
        ? const [
            ('📸', 'Фото → КБЖУ за секунды',
                'ИИ определяет ингредиенты и вес порции'),
            ('🎙️', 'Скажи вслух', '«Съел куриный плов» → залогировано сразу'),
            ('💬', 'Нутрициолог в кармане', 'Спроси о питании — ответит и запишет'),
          ]
        : const [
            ('📸', 'Photo → calories in seconds',
                'AI detects ingredients and portion size'),
            ('🎙️', 'Just say it', '“Had chicken pilaf” → logged instantly'),
            ('💬', 'Nutritionist in your pocket',
                'Ask about food — it answers and logs'),
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8E53).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF8E53).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: Color(0xFFE8552E),
            ),
          ),
          const SizedBox(height: 4),
          for (final (emoji, title, subtitle) in perks)
            PaywallFeatureRow(emoji: emoji, title: title, subtitle: subtitle),
        ],
      ),
    );
  }
}

/// Eye-catching "🎁 GIFT" pill at the top of the offer.
class _GiftBadge extends StatelessWidget {
  const _GiftBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎁', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Text(
            'GIFT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Warm urgency chip showing the live countdown for the limited offer.
class _CountdownChip extends StatelessWidget {
  const _CountdownChip({
    required this.label,
    required this.time,
    required this.expired,
  });

  final String label;
  final String time;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE8552E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8E53).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF8E53).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            expired ? Icons.timer_off_rounded : Icons.timer_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            time,
            style: const TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({
    required this.rating,
    required this.onTap,
    required this.tapPrompt,
  });

  final int rating;
  final void Function(int)? onTap;
  final String tapPrompt;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('stars'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final starIndex = i + 1;
            final filled = starIndex <= rating;
            return GestureDetector(
              onTap: onTap != null ? () => onTap!(starIndex) : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: child,
                  ),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    key: ValueKey('$starIndex-$filled'),
                    size: 52,
                    color: filled
                        ? const Color(0xFFFFC107)
                        : AppColors.textMuted.withValues(alpha: 0.45),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        Text(
          tapPrompt,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ThanksMessage extends StatelessWidget {
  const _ThanksMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('thanks'),
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF16A34A),
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
