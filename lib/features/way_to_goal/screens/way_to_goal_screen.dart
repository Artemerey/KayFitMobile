import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/generated/app_localizations.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/feedback/onboarding_feedback_host.dart';
import '../../../router.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/way_to_goal_provider.dart';
import '../widgets/plan_result_view.dart';

class WayToGoalScreen extends ConsumerWidget {
  const WayToGoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(showWayToGoalProvider)) {
        ref.read(showWayToGoalProvider.notifier).state = false;
      }
    });
    AnalyticsService.wayToGoalOpened();

    final result = ref.watch(calculationResultProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: OBColors.bg,
      body: result.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(calculationResultProvider),
          l10n: l10n,
        ),
        data: (calc) => SafeArea(
          bottom: false,
          child: PlanResultView(
            calc: calc,
            l10n: l10n,
            feedbackPrompt: OnboardingFeedbackHost(
              userId: ref.read(authNotifierProvider).valueOrNull?.id,
            ),
            // Reserve room so the last card isn't hidden under the sticky CTA.
            bottomPadding: 96,
          ),
        ),
      ),
      bottomNavigationBar: result.maybeWhen(
        data: (_) => _StickyStartButton(l10n: l10n),
        orElse: () => null,
      ),
    );
  }
}

class _StickyStartButton extends StatelessWidget {
  final AppLocalizations l10n;
  const _StickyStartButton({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        // Soft fade so cards behind the bar do not look abruptly cropped.
        decoration: BoxDecoration(
          color: OBColors.bg,
          boxShadow: [
            BoxShadow(
              color: OBColors.bg.withValues(alpha: 0),
              blurRadius: 0,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: GestureDetector(
          onTap: () {
            AnalyticsService.wayToGoalStartDiaryTapped();
            context.go('/');
          },
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: OBColors.gradient,
              borderRadius: BorderRadius.circular(999),
              boxShadow: OBColors.buttonShadow,
            ),
            alignment: Alignment.center,
            child: Text(
              l10n.wg_start_diary,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final AppLocalizations l10n;
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.accentOver,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: OBColors.gradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.common_retry,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
