import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feedback_coordinator.dart';
import 'feedback_models.dart';
import 'feedback_metadata.dart';
import 'feedback_prompt.dart';
import '../i18n/generated/app_localizations.dart';

class RecognitionFeedbackBar extends StatefulWidget {
  const RecognitionFeedbackBar({
    super.key,
    required this.source,
    this.userId,
    this.contextData = const {},
    this.margin = const EdgeInsets.fromLTRB(20, 12, 20, 4),
  });

  final FeedbackSource source;
  final int? userId;
  final Map<String, Object> contextData;
  final EdgeInsetsGeometry margin;

  @override
  State<RecognitionFeedbackBar> createState() => _RecognitionFeedbackBarState();
}

class _RecognitionFeedbackBarState extends State<RecognitionFeedbackBar> {
  FeedbackRating? _selected;
  bool _sending = false;
  bool _acknowledged = false;

  Future<void> _rate(FeedbackRating rating) async {
    if (_sending || _selected != null) return;
    List<FeedbackReason> reasons = const [];
    String? comment;
    if (rating == FeedbackRating.dislike) {
      final details = await FeedbackReasonSheet.show(
        context,
        targetType: FeedbackTargetType.mealSave,
        rating: rating,
      );
      if (!mounted || details == null) return;
      reasons = details.reasons;
      comment = details.comment;
    }
    setState(() {
      _selected = rating;
      _sending = true;
    });
    final locale = Localizations.localeOf(context).toLanguageTag();
    HapticFeedback.selectionClick();
    try {
      final coordinator = FeedbackRuntime.coordinator;
      final userId = widget.userId;
      final owner = userId == null
          ? null
          : FeedbackRuntime.ownerBindingForUser(userId);
      if (coordinator == null || owner == null) {
        throw StateError('Feedback is unavailable');
      }
      final target = await coordinator.createMealRecognitionTarget(
        widget.source,
      );
      await coordinator.enqueue(
        target: target,
        request: FeedbackRequest(
          rating: rating,
          source: widget.source,
          reasons: reasons,
          comment: comment,
          context: widget.contextData,
          locale: locale,
          appVersion: FeedbackMetadata.current?.appVersion,
          platform: FeedbackMetadata.current?.platform,
        ),
        ownerBinding: owner,
      );
      unawaited(coordinator.flush(owner));
      if (mounted) setState(() => _acknowledged = true);
    } catch (_) {
      // Keep the user's choice visibly fixed and non-clickable. Production
      // runtime normally queues before flushing, so transient delivery errors
      // are retried without turning the compact control into an error banner.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final iconColor = color.onSurfaceVariant;
    return Padding(
      key: const Key('recognition_feedback_bar'),
      padding: widget.margin,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              key: const Key('recognition_feedback_dislike'),
              tooltip: l10n.feedback_recognition_dislike,
              onPressed: _selected == null
                  ? () => _rate(FeedbackRating.dislike)
                  : null,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size.square(30),
                maximumSize: const Size.square(30),
              ),
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              icon: Icon(
                _selected == FeedbackRating.dislike
                    ? Icons.thumb_down
                    : Icons.thumb_down_outlined,
                size: 18,
                color: _selected == FeedbackRating.dislike
                    ? color.primary
                    : iconColor,
              ),
            ),
            const SizedBox(width: 2),
            IconButton(
              key: const Key('recognition_feedback_like'),
              tooltip: l10n.feedback_recognition_like,
              onPressed: _selected == null
                  ? () => _rate(FeedbackRating.like)
                  : null,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size.square(30),
                maximumSize: const Size.square(30),
              ),
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              icon: Icon(
                _selected == FeedbackRating.like
                    ? Icons.thumb_up
                    : Icons.thumb_up_outlined,
                size: 18,
                color: _selected == FeedbackRating.like
                    ? color.primary
                    : iconColor,
              ),
            ),
          ],
          if (_acknowledged) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_rounded, color: color.primary, size: 16),
          ],
        ],
      ),
    );
  }
}
