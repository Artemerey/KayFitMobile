import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/generated/app_localizations.dart';
import 'feedback_models.dart';

typedef FeedbackSubmitCallback =
    Future<void> Function(
      FeedbackRating rating,
      List<FeedbackReason> reasons,
      String? comment,
    );

class FeedbackPrompt extends StatefulWidget {
  const FeedbackPrompt({
    super.key,
    required this.targetType,
    required this.onSubmit,
    this.onDismiss,
    this.subjectLabel,
  });

  final FeedbackTargetType targetType;
  final FeedbackSubmitCallback onSubmit;
  final VoidCallback? onDismiss;
  final String? subjectLabel;

  @override
  State<FeedbackPrompt> createState() => _FeedbackPromptState();
}

class _FeedbackPromptState extends State<FeedbackPrompt> {
  FeedbackSubmissionState _state = FeedbackSubmissionState.idle;

  Future<void> _rate(FeedbackRating rating) async {
    if (_state != FeedbackSubmissionState.idle &&
        _state != FeedbackSubmissionState.error) {
      return;
    }
    List<FeedbackReason> reasons = const [];
    String? comment;
    final result = await FeedbackReasonSheet.show(
      context,
      targetType: widget.targetType,
      rating: rating,
    );
    if (!mounted || result == null) {
      return;
    }
    reasons = result.reasons;
    comment = result.comment;
    setState(() => _state = FeedbackSubmissionState.submitting);
    HapticFeedback.selectionClick();
    try {
      await widget.onSubmit(rating, reasons, comment);
      if (!mounted) return;
      setState(() => _state = FeedbackSubmissionState.success);
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = FeedbackSubmissionState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_state == FeedbackSubmissionState.dismissed) {
      return const SizedBox.shrink();
    }
    if (_state == FeedbackSubmissionState.success) {
      return Semantics(liveRegion: true, child: Text(l10n.feedback_thanks));
    }
    return Semantics(
      container: true,
      label: l10n.feedback_semantics_prompt,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.targetType == FeedbackTargetType.onboardingPlan
                ? l10n.feedback_onboarding_question
                : (widget.subjectLabel?.trim().isNotEmpty ?? false)
                ? l10n.feedback_meal_subject_question(
                    widget.subjectLabel!.trim(),
                  )
                : l10n.feedback_meal_question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RatingButton(
                key: const Key('feedback_like'),
                label: l10n.feedback_like,
                icon: Icons.thumb_up_outlined,
                enabled: _state != FeedbackSubmissionState.submitting,
                onPressed: () => _rate(FeedbackRating.like),
              ),
              const SizedBox(width: 12),
              _RatingButton(
                key: const Key('feedback_dislike'),
                label: l10n.feedback_dislike,
                icon: Icons.thumb_down_outlined,
                enabled: _state != FeedbackSubmissionState.submitting,
                onPressed: () => _rate(FeedbackRating.dislike),
              ),
            ],
          ),
          if (_state == FeedbackSubmissionState.error)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.feedback_error),
            ),
          TextButton(
            onPressed: _state == FeedbackSubmissionState.submitting
                ? null
                : () {
                    setState(() => _state = FeedbackSubmissionState.dismissed);
                    widget.onDismiss?.call();
                  },
            child: Text(l10n.feedback_dismiss),
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 48,
    child: IconButton(
      tooltip: label,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
    ),
  );
}

class FeedbackReasonResult {
  const FeedbackReasonResult(this.reasons, this.comment);
  final List<FeedbackReason> reasons;
  final String? comment;
}

class FeedbackReasonSheet extends StatefulWidget {
  const FeedbackReasonSheet({
    super.key,
    required this.targetType,
    required this.rating,
  });
  final FeedbackTargetType targetType;
  final FeedbackRating rating;

  static Future<FeedbackReasonResult?> show(
    BuildContext context, {
    required FeedbackTargetType targetType,
    required FeedbackRating rating,
  }) => showModalBottomSheet<FeedbackReasonResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => FeedbackReasonSheet(targetType: targetType, rating: rating),
  );

  @override
  State<FeedbackReasonSheet> createState() => _FeedbackReasonSheetState();
}

class _FeedbackReasonSheetState extends State<FeedbackReasonSheet> {
  final _selected = <FeedbackReason>{};
  final _comment = TextEditingController();

  bool get _otherSelected => _selected.any(
    (reason) =>
        reason == FeedbackReason.otherMeal ||
        reason == FeedbackReason.otherOnboarding,
  );

  bool get _hasValidOtherExplanation {
    final length = _comment.text.trim().length;
    return !_otherSelected || (length >= 3 && length <= 300);
  }

  bool get _containsPrivateData {
    final value = _comment.text;
    return RegExp(
          r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
          caseSensitive: false,
        ).hasMatch(value) ||
        RegExp(r'(?:\+?\d[\s().-]*){10,15}').hasMatch(value) ||
        RegExp(
          r'\b(?:bearer|token|api[_-]?key|password|secret)\s*[:=]?\s*\S+',
          caseSensitive: false,
        ).hasMatch(value);
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reasons = FeedbackReason.values.where(
      (reason) => reason.targetType == widget.targetType,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.feedback_improve,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (widget.rating == FeedbackRating.dislike)
                ...reasons.map(
                  (reason) => CheckboxListTile(
                    key: Key('feedback_reason_${reason.apiValue}'),
                    value: _selected.contains(reason),
                    onChanged: (checked) => setState(() {
                      checked == true
                          ? _selected.add(reason)
                          : _selected.remove(reason);
                    }),
                    title: Text(_reasonLabel(l10n, reason)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              TextField(
                controller: _comment,
                maxLength: 1000,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _otherSelected
                      ? l10n.feedback_other_explanation
                      : l10n.feedback_comment,
                  helperText: l10n.feedback_privacy_hint,
                  errorText: _containsPrivateData
                      ? l10n.feedback_privacy_error
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed:
                    (widget.rating == FeedbackRating.dislike &&
                            _selected.isEmpty) ||
                        !_hasValidOtherExplanation ||
                        _containsPrivateData
                    ? null
                    : () => Navigator.of(context).pop(
                        FeedbackReasonResult(
                          _selected.toList(growable: false),
                          _comment.text.trim().isEmpty
                              ? null
                              : _comment.text.trim(),
                        ),
                      ),
                child: Text(l10n.feedback_send),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _reasonLabel(AppLocalizations l10n, FeedbackReason reason) =>
      switch (reason) {
        FeedbackReason.tooFewCalories => l10n.feedback_reason_too_few_calories,
        FeedbackReason.tooManyCalories =>
          l10n.feedback_reason_too_many_calories,
        FeedbackReason.wrongGoal => l10n.feedback_reason_wrong_goal,
        FeedbackReason.wrongMacrosOnboarding ||
        FeedbackReason.wrongMacrosMeal => l10n.feedback_reason_wrong_macros,
        FeedbackReason.answersNotConsidered =>
          l10n.feedback_reason_answers_not_considered,
        FeedbackReason.otherOnboarding ||
        FeedbackReason.otherMeal => l10n.feedback_reason_other,
        FeedbackReason.wrongFood => l10n.feedback_reason_wrong_food,
        FeedbackReason.missingItem => l10n.feedback_reason_missing_item,
        FeedbackReason.extraItem => l10n.feedback_reason_extra_item,
        FeedbackReason.wrongWeight => l10n.feedback_reason_wrong_weight,
        FeedbackReason.wrongCalories => l10n.feedback_reason_wrong_calories,
        FeedbackReason.recognitionTooSlow =>
          l10n.feedback_reason_recognition_too_slow,
      };
}
