import 'dart:math' as math;

import 'package:dio/dio.dart' show Options;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kayfit/core/analytics/analytics_service.dart';
import 'package:kayfit/core/api/api_client.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/core/ai_consent/ai_consent_provider.dart';
import 'package:kayfit/shared/theme/app_theme.dart';
import 'package:kayfit/shared/widgets/keyboard_dismisser.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;

  // Header shimmer animation
  late final AnimationController _headerCtrl;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    // Guard against Firebase not being initialized (e.g. in widget tests).
    try {
      AnalyticsService.chatOpened();
    } catch (_) {}
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _inputFocusNode.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final resp = await apiDio.get(
        '/api/chat/messages',
        queryParameters: {'limit': 50},
      );
      final list = (resp.data['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
      });
      _scrollToBottom();
    } catch (_) {
      // Show empty state on load errors
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Block if AI consent was declined
    final consent = ref.read(aiConsentProvider);
    if (consent == false) {
      final isRu = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isRu
            ? 'Чат с ИИ недоступен: вы отклонили использование ИИ'
            : 'AI chat is unavailable: AI consent was declined'),
        backgroundColor: AppColors.accentOver,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ));
      return;
    }

    final lang = Localizations.localeOf(context).languageCode;
    _textController.clear();
    HapticFeedback.lightImpact();

    final userMsg = ChatMessage(
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );
    final typingMsg = ChatMessage(
      role: 'assistant',
      content: '...',
      createdAt: DateTime.now(),
      isLoading: true,
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(typingMsg);
      _isSending = true;
    });
    _scrollToBottom();
    try {
      AnalyticsService.chatMessageSent(_messages.length);
    } catch (_) {}

    try {
      final utcOffsetHours = DateTime.now().timeZoneOffset.inHours;
      final resp = await apiDio.post(
        '/api/chat/send',
        data: {
          'text': text,
          'language': lang,
          'utc_offset_hours': utcOffsetHours,
        },
        // Claude responses regularly take 40–60 s on slow LTE; the default
        // apiDio receiveTimeout (30 s) fires too early.
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      final reply = ChatMessage.fromJson(
        resp.data['message'] as Map<String, dynamic>,
      );
      setState(() {
        _messages.removeLast();
        _messages.add(reply);
      });
      try {
        AnalyticsService.chatResponseReceived(_messages.length);
      } catch (_) {}
      _scrollToBottom();
    } catch (_) {
      setState(() {
        _messages.removeLast();
        _messages.removeLast();
      });
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chat_error),
            backgroundColor: AppColors.accentOver,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _sendSuggestion(String text) {
    _textController.text = text;
    _sendMessage();
  }

  bool _isFoodConfirmation(String content) {
    final lower = content.toLowerCase();
    return lower.contains('ккал') || lower.contains('kcal');
  }

  String? _precedingUserMessage(int assistantIndex) {
    for (var i = assistantIndex - 1; i >= 0; i--) {
      if (_messages[i].role == 'user') return _messages[i].content;
    }
    return null;
  }

  void _correctMessage(String text) {
    _textController.text = text;
    _inputFocusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(l10n.chat_clear),
        content: Text(l10n.chat_clear_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.common_delete,
                style: const TextStyle(color: AppColors.accentOver)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await apiDio.delete('/api/chat/messages');
      setState(() => _messages.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return KeyboardDismisser(
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(
          children: [
            // ── Beautiful gradient header ────────────────────────────────
            _ChatHeader(
              l10n: l10n,
              animCtrl: _headerCtrl,
              hasMessages: _messages.isNotEmpty,
              onClear: _clearHistory,
              onBack: () => context.go('/'),
            ),

            // ── Citation / disclaimer banner ───────────────────────────
            _ChatDisclaimerBanner(),

            // ── Messages ────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2.5),
                    )
                  : _messages.isEmpty
                      ? _EmptyState(l10n: l10n, onSend: _sendSuggestion)
                      : ListView.builder(
                          controller: _scrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final bubble = _AnimatedBubble(
                              message: msg,
                              isNewest: index == _messages.length - 1,
                            );
                            if (msg.role == 'assistant' && !msg.isLoading) {
                              if (msg.mealAdded != null) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    bubble,
                                    _MealAddedBadge(meal: msg.mealAdded!),
                                  ],
                                );
                              }
                              if (_isFoodConfirmation(msg.content)) {
                                final userMsg = _precedingUserMessage(index);
                                if (userMsg != null) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      bubble,
                                      _CorrectionChip(
                                        onTap: () => _correctMessage(userMsg),
                                      ),
                                    ],
                                  );
                                }
                              }
                            }
                            return bubble;
                          },
                        ),
            ),

            // ── Input row ───────────────────────────────────────────────
            _InputRow(
              controller: _textController,
              focusNode: _inputFocusNode,
              isSending: _isSending,
              hint: l10n.chat_input_hint,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient header
// ─────────────────────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final AppLocalizations l10n;
  final AnimationController animCtrl;
  final bool hasMessages;
  final VoidCallback onClear;
  final VoidCallback onBack;

  const _ChatHeader({
    required this.l10n,
    required this.animCtrl,
    required this.hasMessages,
    required this.onClear,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 4, 8, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF064E1F), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Back',
            onPressed: onBack,
          ),
          // Animated AI avatar
          AnimatedBuilder(
            animation: animCtrl,
            builder: (context, child) {
              final t = animCtrl.value;
              final glow = 0.15 + 0.1 * math.sin(t * 2 * math.pi);
              return Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: glow),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 26),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chat_title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasMessages)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 22),
              tooltip: l10n.chat_clear,
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  final AppLocalizations l10n;
  final void Function(String) onSend;
  const _EmptyState({required this.l10n, required this.onSend});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suggestions = [
      l10n.chat_suggestion_1,
      l10n.chat_suggestion_2,
      l10n.chat_suggestion_3,
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          children: [
            // Pulsing avatar
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final scale =
                    1.0 + 0.06 * math.sin(_pulseCtrl.value * math.pi);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF064E1F), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.l10n.chat_title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.l10n.chat_empty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            // Suggestion chips
            ...suggestions.map((s) => _SuggestionChip(
                  text: s,
                  onTap: () => widget.onSend(s),
                )),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionChip({required this.text, required this.onTap});

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.accentSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
          boxShadow: _pressed ? [] : AppShadow.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.text,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.text,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated message bubble
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isNewest;

  const _AnimatedBubble({required this.message, required this.isNewest});

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.isNewest) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _MessageBubble(message: widget.message),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 56 : 0,
        right: isUser ? 0 : 56,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF064E1F), Color(0xFF16A34A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser ? null : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: isUser
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : AppShadow.sm,
                  ),
                  child: message.isLoading
                      ? const _TypingIndicator()
                      : isUser
                          ? Text(
                              message.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            )
                          : MarkdownBody(
                              data: message.content,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 15,
                                    height: 1.45),
                                strong: const TextStyle(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w700),
                                pPadding: EdgeInsets.zero,
                              ),
                              shrinkWrap: true,
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    _fmt(message.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator — scale-wave dots
// ─────────────────────────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3.0;
            final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
            final scale = 0.6 + 0.4 * math.sin(t * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input row
// ─────────────────────────────────────────────────────────────────────────────

class _InputRow extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final String hint;
  final VoidCallback onSend;

  const _InputRow({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.hint,
    required this.onSend,
  });

  @override
  State<_InputRow> createState() => _InputRowState();
}

class _InputRowState extends State<_InputRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sendCtrl;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _sendCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _sendCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) {
      _hasText = has;
      if (has) {
        _sendCtrl.forward();
      } else {
        _sendCtrl.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field with rounded border
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                style: const TextStyle(fontSize: 15, color: AppColors.text),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button with elastic appear
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _sendCtrl,
              curve: Curves.elasticOut,
              reverseCurve: Curves.easeInCubic,
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: widget.isSending ? null : widget.onSend,
                icon: widget.isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Citation / disclaimer banner
// ─────────────────────────────────────────────────────────────────────────────

class _ChatDisclaimerBanner extends StatelessWidget {
  const _ChatDisclaimerBanner();

  static const _whoUrl =
      'https://www.who.int/news-room/fact-sheets/detail/healthy-diet';
  static const _usdaUrl =
      'https://odphp.health.gov/our-work/nutrition-physical-activity/dietary-guidelines';

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    final disclaimerText = isRu
        ? 'Ответы ИИ носят информационный характер и не заменяют консультацию врача. Основано на: '
        : 'AI-generated responses are for informational purposes only and do not replace professional medical advice. Based on: ';

    final whoLabel = isRu ? 'Рекомендации ВОЗ/ФАО' : 'WHO/FAO Dietary Guidelines';
    final usdaLabel = isRu ? 'Рекомендации USDA' : 'USDA Dietary Guidelines';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: const Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
                children: [
                  TextSpan(text: disclaimerText),
                  TextSpan(
                    text: whoLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF3B82F6),
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                            Uri.parse(_whoUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                  ),
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: usdaLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF3B82F6),
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                            Uri.parse(_usdaUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meal added badge — shown when AI auto-logged a meal to journal
// ─────────────────────────────────────────────────────────────────────────────

class _MealAddedBadge extends StatelessWidget {
  final MealAdded meal;
  const _MealAddedBadge({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, top: 2, bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
            const SizedBox(width: 5),
            Text(
              'Добавлено: ${meal.name} — ${meal.calories.toStringAsFixed(0)} ккал',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF15803D),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Correction chip — shown after food-confirmation AI messages
// ─────────────────────────────────────────────────────────────────────────────

class _CorrectionChip extends StatefulWidget {
  final VoidCallback onTap;
  const _CorrectionChip({required this.onTap});

  @override
  State<_CorrectionChip> createState() => _CorrectionChipState();
}

class _CorrectionChipState extends State<_CorrectionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 44, top: 2, bottom: 8),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.accentSoft : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.edit_outlined, size: 12, color: AppColors.textMuted),
              SizedBox(width: 4),
              Text(
                'Скорректировать',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
