import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/ai_consent/ai_consent_provider.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/locale/locale_provider.dart';
import '../../../core/navigation/navigation_providers.dart';

class AiConsentScreen extends ConsumerStatefulWidget {
  const AiConsentScreen({super.key});

  @override
  ConsumerState<AiConsentScreen> createState() => _AiConsentScreenState();
}

class _AiConsentScreenState extends ConsumerState<AiConsentScreen>
    with SingleTickerProviderStateMixin {
  bool _checked = false;

  /// True while [_onAccept] is running — disables button and shows loader.
  bool _isProcessing = false;

  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _shakeAnim =
      Tween<double>(begin: 0, end: 1).animate(_shakeController);

  /// True after the 300 ms grace period — only then is the linear loader shown.
  /// Prevents a flicker for fast (<300 ms) network responses, per spec §1.5.
  bool _showLoader = false;
  Timer? _loaderTimer;

  /// True when the server call exceeded [_kConsentTimeout] — shows retry UI.
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill checkbox from current consent state so users entering this
    // screen from Settings (re-consent / revocation) see their own choice.
    _checked = ref.read(aiConsentProvider) ?? false;
    try {
      AnalyticsService.aiConsentScreenOpened();
    } catch (_) {
      // Analytics is best-effort; never block the screen from mounting.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRu = ref.watch(localeProvider).languageCode == 'ru';

    final title = isRu ? 'Обработка данных ИИ' : 'AI Data Processing';
    final subtitle = isRu
        ? 'Для работы функций распознавания еды'
        : 'Required for food recognition features';
    final row1 = isRu ? 'Текстовые описания блюд' : 'Text descriptions of meals';
    final row1b =
        isRu ? 'Голосовые записи (аудиофайлы)' : 'Voice recordings (audio files)';
    final row1c = isRu ? 'Фотографии еды' : 'Food photos';
    final row1d = isRu ? 'Сообщения в AI-чате' : 'AI chat messages';
    final row2 = isRu
        ? 'Данные отправляются в Anthropic, Inc. (США) и обрабатываются на их серверах'
        : 'Data is sent to Anthropic, Inc. (USA) and processed on their servers';
    final row3 =
        isRu ? 'Не используются для обучения модели' : 'Never used for model training';
    final checkboxLabel =
        isRu ? 'Я согласен(а) с передачей данных' : 'I agree to the data transfer';
    final acceptLabel = isRu ? 'Принять и продолжить' : 'Accept & Continue';
    final declineLabel = isRu
        ? 'Отклонить'
        : 'Decline';

    final errorText = isRu
        ? 'Не удалось подключиться. Попробуйте ещё раз.'
        : 'Could not connect. Please try again.';
    final retryLabel = isRu ? 'Повторить' : 'Retry';

    return Scaffold(
      backgroundColor: AppColors.bg,
      // ── LinearProgressIndicator while processing ──────────────────────────
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Hero icon ────────────────────────────────────────────────
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Title & subtitle ─────────────────────────────────────────
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // ── Info card ────────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppShadow.sm,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRu ? 'Данные, которые передаются:' : 'Data that is shared:',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BenefitRow(
                          icon: Icons.text_snippet_outlined,
                          color: const Color(0xFF7C3AED),
                          text: row1,
                        ),
                        const SizedBox(height: 12),
                        _BenefitRow(
                          icon: Icons.mic_rounded,
                          color: const Color(0xFF7C3AED),
                          text: row1b,
                        ),
                        const SizedBox(height: 12),
                        _BenefitRow(
                          icon: Icons.camera_alt_outlined,
                          color: const Color(0xFF7C3AED),
                          text: row1c,
                        ),
                        const SizedBox(height: 12),
                        _BenefitRow(
                          icon: Icons.chat_outlined,
                          color: const Color(0xFF7C3AED),
                          text: row1d,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        _BenefitRow(
                          icon: Icons.send_rounded,
                          color: const Color(0xFF3B82F6),
                          text: row2,
                        ),
                        const SizedBox(height: 12),
                        _BenefitRow(
                          icon: Icons.shield_rounded,
                          color: const Color(0xFF16A34A),
                          text: row3,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Checkbox row ─────────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (context, child) {
                      final dx = math.sin(_shakeAnim.value * math.pi * 5) *
                          8 *
                          (1 - _shakeAnim.value);
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: GestureDetector(
                    key: const Key('consent_checkbox'),
                    onTap: _isProcessing
                        ? null
                        : () {
                            final next = !_checked;
                            try {
                              AnalyticsService.aiConsentCheckboxToggled(next);
                            } catch (_) {
                              // Analytics is best-effort.
                            }
                            setState(() {
                              _checked = next;
                              _hasError = false;
                            });
                          },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _checked
                                ? const Color(0xFF7C3AED)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _checked
                                  ? const Color(0xFF7C3AED)
                                  : AppColors.textMuted,
                              width: 1.5,
                            ),
                          ),
                          child: _checked
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            checkboxLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.text,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),

                  const SizedBox(height: 24),

                  // ── Error banner ─────────────────────────────────────────────
                  if (_hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.accentOver, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.accentOver,
                                height: 1.4,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('retry_button'),
                            onPressed: _onAccept,
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              retryLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Accept button ────────────────────────────────────────────
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: (_checked && !_isProcessing) ? 1.0 : 0.4,
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: (_checked && !_isProcessing)
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: InkWell(
                            key: const Key('accept_inkwell'),
                            onTap: _isProcessing ? null : _onAccept,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Center(
                              child: _isProcessing
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      acceptLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Decline button ───────────────────────────────────────────
                  TextButton(
                    onPressed: _isProcessing ? null : _onDecline,
                    child: Text(
                      declineLabel,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Top LinearProgressIndicator after 300ms grace period ──────────
          if (_showLoader)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  void _navigateAfterConsent() {
    final fromOnboarding = ref.read(consentFromOnboardingProvider);
    if (fromOnboarding) {
      ref.read(consentFromOnboardingProvider.notifier).state = false;
      context.go('/onboarding');
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _loaderTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _onAccept() async {
    if (_isProcessing) return;

    // Checkbox not checked — shake it and give haptic feedback.
    if (!_checked) {
      HapticFeedback.lightImpact();
      _shakeController.forward(from: 0);
      return;
    }

    // ── Immediate visual feedback — well within 100 ms ────────────────────
    setState(() {
      _isProcessing = true;
      _hasError = false;
      _showLoader = false;
    });
    // Spec §1.5: linear progress indicator appears only if the call takes
    // longer than 300 ms — fast responses don't flicker.
    _loaderTimer?.cancel();
    _loaderTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _isProcessing) {
        setState(() => _showLoader = true);
      }
    });

    try {
      AnalyticsService.aiConsentAccepted();
    } catch (_) {
      // Analytics is best-effort.
    }

    try {
      await ref.read(aiConsentProvider.notifier).setConsent(true);
    } on TimeoutException {
      if (!mounted) return;
      _loaderTimer?.cancel();
      setState(() {
        _isProcessing = false;
        _showLoader = false;
        _hasError = true;
      });
      return;
    } on DioException catch (e) {
      if (!mounted) return;
      // Stale session: refresh chain failed, server says 401. Don't trap
      // the user in an infinite "Could not connect / Retry" loop — sign
      // them out so they can re-authenticate with fresh tokens.
      if (e.response?.statusCode == 401) {
        await _handleSessionExpired();
        return;
      }
      _loaderTimer?.cancel();
      setState(() {
        _isProcessing = false;
        _showLoader = false;
        _hasError = true;
      });
      return;
    }
    // setConsent succeeded — navigate forward.
    _loaderTimer?.cancel();
    if (mounted) _navigateAfterConsent();
  }

  Future<void> _handleSessionExpired() async {
    if (!mounted) return;
    _loaderTimer?.cancel();
    final isRu = ref.read(localeProvider).languageCode == 'ru';
    final msg = isRu
        ? 'Сессия истекла. Войдите снова.'
        : 'Session expired. Please sign in again.';
    setState(() {
      _isProcessing = false;
      _showLoader = false;
      _hasError = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
    // Logout clears tokens and updates auth state — router redirects to /login.
    await ref.read(authNotifierProvider.notifier).logout();
  }

  Future<void> _onDecline() async {
    try {
      AnalyticsService.aiConsentDeclined();
    } catch (_) {
      // Analytics is best-effort.
    }
    final isRu = ref.read(localeProvider).languageCode == 'ru';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(isRu ? 'Отключить AI-функции?' : 'Disable AI features?'),
        content: Text(
          isRu
              ? 'Без согласия функции распознавания, голосового ввода и AI-чата будут недоступны. Ручной ввод еды останется доступным.'
              : 'Without consent, photo recognition, voice input and AI chat will be unavailable. Manual food logging will still work.',
          style: const TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isRu ? 'Отмена' : 'Cancel',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isRu ? 'Отключить' : 'Decline',
              style: const TextStyle(color: AppColors.accentOver),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        AnalyticsService.aiConsentDeclineConfirmed();
      } catch (_) {
        // Analytics is best-effort.
      }
      // Persist decline — AI features will be individually disabled.
      // User stays logged in and can use manual food logging.
      try {
        await ref.read(aiConsentProvider.notifier).setConsent(false);
      } on TimeoutException {
        // ignore — local state already records the decline
      } on DioException {
        // ignore — local state already records the decline
      }
      if (mounted) context.go('/');
    }
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _BenefitRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.text,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
