// KF2-CHAT — Chat V2 screen (Kayfit 2.0 redesign).
//
// New AI-coach chat UI built on top of the existing chat infrastructure
// (same API endpoints: GET /api/chat/messages, POST /api/chat/send).
//
// Visual system from JSX prototype (kayfit-screens.jsx ChatScreen):
//   • Monochrome surface: K2Theme tokens (bg / surface / hairline)
//   • User bubble: solid fg background, white text, bottom-right corner flat
//   • AI message: surface background, fg text, bottom-left corner flat
//   • Thinking bubble: inline step list with spinner on last active step +
//     check icons on completed steps
//   • Attach toolbar: camera / mic / barcode circular buttons
//   • Input pill: rounded 22px border, borderless inner TextField, send circle
//
// Gated via --dart-define=KF2_CHAT=true in router.dart.
// The legacy ChatScreen remains untouched at /chat.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/ai_consent/ai_consent_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/subscription/require_subscription.dart';
import '../../../features/add_meal/screens/barcode_scanner_screen_v2.dart';
import '../../../features/add_meal/screens/recognition_result_sheet_kf2.dart';
import '../providers/photo_recognition_provider.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../../../features/journal/screens/journal_screen.dart'
    show journalDayMealsProvider;
import '../../../shared/models/ingredient_v2.dart';
import '../providers/pending_meal_provider.dart';
import '../providers/chat_history_provider.dart';
import '../../../shared/models/stats.dart';
import '../../../shared/theme/kayfit2_theme.dart';
import '../../../shared/utils/nutrient_parser.dart';
import '../../../shared/widgets/kayfit2_tab_bar.dart';
import '../../../core/i18n/generated/app_localizations.dart';
import '../models/chat_message.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Voice recorder state
// ─────────────────────────────────────────────────────────────────────────────

enum _VoiceState { idle, recording, transcribing }

// Role string for the in-chat photo-analyzing bubble. Used in multiple places;
// keeping it as a constant avoids silent typo bugs.
const _kPhotoAnalyzingRole = 'photo_analyzing';

// ─────────────────────────────────────────────────────────────────────────────
// Thinking-step model
// ─────────────────────────────────────────────────────────────────────────────

/// Represents one progress step shown in the thinking bubble.
@immutable
class _ThinkingState {
  const _ThinkingState({required this.steps, required this.done});

  final List<String> steps;
  final bool done;

  _ThinkingState withStep(String step) =>
      _ThinkingState(steps: [...steps, step], done: done);

  _ThinkingState markDone() =>
      _ThinkingState(steps: steps, done: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen widget
// ─────────────────────────────────────────────────────────────────────────────

class ChatV2Screen extends ConsumerStatefulWidget {
  const ChatV2Screen({super.key});

  @override
  ConsumerState<ChatV2Screen> createState() => _ChatV2ScreenState();
}

class _ChatV2ScreenState extends ConsumerState<ChatV2Screen>
    with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  /// Last seen bottom view inset (keyboard height in logical pixels).
  /// Used by [didChangeMetrics] to detect keyboard appearance and autoscroll
  /// so the latest message stays visible above the keyboard.
  double _lastBottomInset = 0;

  _ThinkingState? _thinking;

  // Pending "Add to journal" card state lives in `pendingMealProvider` so it
  // survives navigation away from chat (e.g. tab switch to journal).
  // Cleared on confirm/cancel/restart through the notifier API.

  /// Set when the assistant just asked the user to clarify a meal
  /// (type/portion). The next user message is then routed to the meal
  /// parser regardless of regex — we already know we're in a meal flow.
  /// Cleared as soon as the next message is processed.
  bool _awaitingMealClarification = false;

  /// Original user text that triggered the clarification. We re-parse
  /// `original + clarification` together so multi-item meals don't lose
  /// the items that already had weights specified.
  String? _pendingClarifyOriginal;

  bool _isLoading = false;
  bool _isSending = false;

  // Guard against _onPhotoRecognitionDone being called twice — once via
  // ref.listen and once via the initState post-frame check.
  bool _photoResultConsumed = false;

  // Voice recording
  final _recorder = AudioRecorder();
  _VoiceState _voiceState = _VoiceState.idle;
  String? _recordPath;

  // Thinking step labels — locale-aware, mirrors the JSX prototype sequence.
  List<String> get _kThinkingSteps {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    return isRu
        ? [
            'анализирую сообщение',
            'ищу в базе данных',
            'проверяю нутриенты',
            'формирую ответ',
          ]
        : [
            'parsing your message',
            'matching USDA database',
            'cross-checking nutrition data',
            'compiling nutrition data',
          ];
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      AnalyticsService.chatOpened();
    } catch (_) {}
    // If the provider already has messages (survived a tab switch), show them
    // immediately and refresh in the background. If empty, show loading state.
    final cached = ref.read(chatHistoryProvider);
    if (cached.isEmpty) {
      _loadHistory();
    } else {
      unawaited(_loadHistory());
    }
    // If the user navigated away during recognition and comes back, the
    // provider might already be in done state — show the result sheet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final recog = ref.read(photoRecognitionProvider);
      if (recog.isDone && recog.result != null) {
        _onPhotoRecognitionDone(recog.result!);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _textController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  /// Keep the latest message visible when the keyboard opens.
  ///
  /// `Scaffold.resizeToAvoidBottomInset` (default true) shrinks the body but
  /// doesn't move the list's scroll offset — so the bottom message slides under
  /// the keyboard. We watch for the bottom inset growing and scroll to the
  /// end. The postFrame inside `_scrollToBottom` covers the one-frame inset
  /// lag we see on Android.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottom = MediaQuery.of(context).viewInsets.bottom;
      if (bottom > _lastBottomInset + 1) {
        _scrollToBottom();
      }
      _lastBottomInset = bottom;
    });
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  /// SharedPreferences key for chat-local synthetic messages — clarify
  /// prompts, "✓ added" confirmations, cancel acks. These are not persisted
  /// on the backend (they're not real Claude turns), so we cache them
  /// client-side and merge with server history on every reload.
  static const _kLocalChatKey = 'kf2_chat_local_messages_v1';
  static const _kLocalChatLimit = 100;

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final resp = await apiDio.get(
        '/api/chat/messages',
        queryParameters: {'limit': 50},
      );
      final server = (resp.data['messages'] as List)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      final local = await _loadLocalMessages();
      // Deduplicate: drop local copies of messages already on the server
      // (a local message that was also POSTed to /api/chat/send would
      // otherwise show twice after the background refresh).
      final serverKeys =
          server.map((m) => '${m.role}:${m.content}').toSet();
      final dedupedLocal = local
          .where((m) => !serverKeys.contains('${m.role}:${m.content}'))
          .toList();
      final merged = [...server, ...dedupedLocal]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (!mounted) return;
      ref.read(chatHistoryProvider.notifier).setMessages(merged);
      _scrollToBottom();
    } on Exception {
      // Even if the server fetch fails, surface local-only messages so the
      // user keeps their meal-add receipts.
      final local = await _loadLocalMessages();
      if (mounted && local.isNotEmpty) {
        ref.read(chatHistoryProvider.notifier).setMessages(local);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<ChatMessage>> _loadLocalMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kLocalChatKey) ?? const [];
      return raw.map((s) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return ChatMessage(
          role: m['role'] as String,
          content: m['content'] as String,
          createdAt: DateTime.parse(m['createdAt'] as String),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistLocalMessage(ChatMessage msg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kLocalChatKey) ?? <String>[];
      raw.add(jsonEncode({
        'role': msg.role,
        'content': msg.content,
        'createdAt': msg.createdAt.toIso8601String(),
      }));
      // Trim to last N to bound storage.
      if (raw.length > _kLocalChatLimit) {
        raw.removeRange(0, raw.length - _kLocalChatLimit);
      }
      await prefs.setStringList(_kLocalChatKey, raw);
    } catch (_) {
      // Non-fatal — synthetic messages stay only in memory until next save.
    }
  }

  // ── Send flow ───────────────────────────────────────────────────────────────

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    // Subscription gate — block AI chat for free users.
    final ok = await requireSubscription(context, ref);
    if (!ok || !mounted) return;

    // Consent gate — block if consent declined.
    final consent = ref.read(aiConsentProvider);
    if (consent == false) {
      if (!mounted) return;
      final isRu = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRu
              ? 'ИИ-чат недоступен: согласие не предоставлено'
              : 'AI chat unavailable: consent was declined'),
          backgroundColor: K2Colors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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

    // Persist user message into the global provider immediately — this
    // survives navigation even if the send is still in flight.
    ref.read(chatHistoryProvider.notifier).add(userMsg);
    // Also persist locally so it appears in the local-merge path on reload.
    unawaited(_persistLocalMessage(userMsg));
    setState(() {
      _isSending = true;
      _thinking = _ThinkingState(steps: [_kThinkingSteps[0]], done: false);
    });
    _scrollToBottom();

    try {
      AnalyticsService.chatMessageSent(ref.read(chatHistoryProvider).length);
    } catch (_) {}

    // ── Router ───────────────────────────────────────────────────────────
    // Route to meal-add flow when:
    //   • the message contains a meal-intent keyword/grams token, OR
    //   • the previous assistant turn was our clarification request
    //     (the user is replying to "сколько грамм?" — treat as meal flow)
    final forceMealFlow = _awaitingMealClarification;
    final pendingOrig = _pendingClarifyOriginal;
    _awaitingMealClarification = false; // one-shot
    _pendingClarifyOriginal = null;
    // Try the food parser for ANY message that doesn't contain '?' —
    // covers verbs ("съел омлет"), plain nouns ("омлет"), voice-dictated
    // lists ("сосиска, бургер, роллы") and everything in between.
    // If the backend returns no items the call completes quickly and we
    // fall through to the consultant as usual.
    final mightBeFood = !text.contains('?');
    if (forceMealFlow || mightBeFood) {
      // Detect language from the user's message itself, not from app locale —
      // the user can write Russian inside an English app and vice versa.
      final msgLang = _detectMessageLang(text);
      // On follow-up turn after a clarification, combine the original meal
      // text with the user's clarifying reply so multi-item meals keep all
      // items (the original "soup 400g + bread" wouldn't otherwise survive
      // a reply like "tемный 100г" — soup would be dropped).
      final parseText = (forceMealFlow && pendingOrig != null)
          ? '$pendingOrig. ${text.trim()}'
          : text;
      // Only ever ask for clarification ONCE per meal session.
      final routed = await _tryParseAndOfferMeal(
        parseText,
        msgLang,
        skipClarify: forceMealFlow,
      );
      if (routed) {
        if (mounted) setState(() => _isSending = false);
        return;
      }
      // Parser returned nothing — fall through to consultant.
    }

    // Drip-feed step labels to simulate streaming progress.
    for (var i = 1; i < _kThinkingSteps.length; i++) {
      await Future<void>.delayed(
        Duration(milliseconds: 600 + i * 200),
      );
      if (!mounted) return;
      setState(() {
        _thinking = _thinking?.withStep(_kThinkingSteps[i]);
      });
    }

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
        // apiDio receiveTimeout (30 s) fires too early and the user sees
        // "Could not reach AI coach" even though the backend is working.
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      final reply = ChatMessage.fromJson(
        resp.data['message'] as Map<String, dynamic>,
      );
      if (!mounted) return;
      ref.read(chatHistoryProvider.notifier).add(reply);
      setState(() => _thinking = null);
      try {
        AnalyticsService.chatResponseReceived(
            ref.read(chatHistoryProvider).length);
      } catch (_) {}
      _scrollToBottom();
    } on Exception {
      if (!mounted) return;
      ref.read(chatHistoryProvider.notifier).removeLast();
      setState(() {
        _thinking = null;
        // optimistic user message already removed via notifier above
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not reach AI coach. Try again.'),
            backgroundColor: K2Colors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Calls /api/v2/parse_meal_suggestions and dispatches one of three
  /// outcomes:
  ///   • backend returned no items → return false (caller falls back to
  ///     the consultant)
  ///   • at least one item is missing `weight_grams` → push a synthetic
  ///     clarify message in chat asking for type/portion. No card yet.
  ///     Return true (routed).
  ///   • every item has a weight → render the pending-meal confirm card.
  ///     Return true.
  ///
  /// Note: `parse_meal_suggestions` returns a flat `items[]` shape and is
  /// the same endpoint used by AddMealSheet's text flow. The sister
  /// `parse_meal_variants` was empirically returning empty bodies in
  /// production (2026-05-06); avoid it here.
  Future<bool> _tryParseAndOfferMeal(
    String text,
    String lang, {
    bool skipClarify = false,
  }) async {
    try {
      final resp = await apiDio.post(
        '/api/v2/parse_meal_suggestions',
        data: {'text': text, 'language': lang},
        // Claude + FatSecret round-trip can take 40-60 s; global 30 s
        // receiveTimeout aborts too early on slow runs.
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      final rawItems = (resp.data['items'] as List<dynamic>?) ?? [];
      if (rawItems.isEmpty) return false;

      final missingWeight = <String>[];
      final items = <IngredientV2>[];
      for (final raw in rawItems) {
        final m = raw as Map<String, dynamic>;
        final wRaw = m['weight_grams'] as num?;
        if (wRaw == null) {
          missingWeight.add((m['name'] as String?) ?? '?');
        }
        final w = wRaw?.toDouble() ?? 100.0;
        items.add(ingredientV2FromSuggestion(m, w));
      }

      // Ask the user to clarify type + portion before locking in a card.
      // Single local message — no extra Claude round-trip.
      // Skipped on follow-up turns: if user already answered our previous
      // clarify, commit to the card even if weights are still missing.
      if (missingWeight.isNotEmpty && !skipClarify) {
        if (!mounted) return true;
        final isRu = lang == 'ru';
        final names = missingWeight.join(', ');
        final reply = isRu
            ? 'Уточни, пожалуйста:\n'
                '• какой именно $names (вид/сорт)?\n'
                '• сколько грамм или штук?'
            : 'Quick check before I log this:\n'
                '• which $names exactly (type/size)?\n'
                '• how many grams or pieces?';
        final clarifyMsg = ChatMessage(
          role: 'assistant',
          content: reply,
          createdAt: DateTime.now(),
        );
        ref.read(chatHistoryProvider.notifier).add(clarifyMsg);
        setState(() {
          _thinking = null;
          _awaitingMealClarification = true;
          // Remember the user's full original text so the next-turn parse
          // gets BOTH the already-resolved items (e.g. "soup 400g") and
          // the clarification reply (e.g. "тёмный, 100г"). Without this
          // the soup would silently disappear from the final card.
          _pendingClarifyOriginal = text;
        });
        unawaited(_persistLocalMessage(clarifyMsg));
        _scrollToBottom();
        return true;
      }

      if (!mounted) return false;
      setState(() => _thinking = null);
      ref
          .read(pendingMealProvider.notifier)
          .setMeal(items, _inferMealTypeForNow());
      _scrollToBottom();
      return true;
    } on Exception {
      return false;
    }
  }

  /// Infer breakfast/lunch/snack/dinner from current local time.
  String _inferMealTypeForNow() {
    final h = DateTime.now().hour;
    if (h < 11) return 'breakfast';
    if (h < 15) return 'lunch';
    if (h < 18) return 'snack';
    return 'dinner';
  }

  /// Detects the user message language from the content rather than the
  /// app locale. The user may keep the UI in English but write in Russian
  /// (or vice versa) — assistant should mirror their input.
  static final _kCyrillic = RegExp(r'[а-яё]', caseSensitive: false);
  String _detectMessageLang(String text) =>
      _kCyrillic.hasMatch(text) ? 'ru' : 'en';

  /// Translates English goal-type labels and formats raw floats coming from
  /// the backend `/api/coach/advice` response when the UI language is Russian.
  static String _localizeBackendAdvice(String text) {
    return text
        .replaceAll(RegExp(r'\blose weight\b', caseSensitive: false), 'похудеть')
        .replaceAll(RegExp(r'\bgain weight\b', caseSensitive: false), 'набрать вес')
        .replaceAll(
            RegExp(r'\bmaintain weight\b', caseSensitive: false), 'поддерживать вес')
        .replaceAllMapped(
          // "(target 69.40983581542969kg)" → "(цель: 69.4 кг)"
          RegExp(r'\(target\s+([\d.]+)\s*kg\)', caseSensitive: false),
          (m) {
            final raw = double.tryParse(m.group(1) ?? '');
            final nice = raw != null ? raw.toStringAsFixed(1) : m.group(1);
            return '(цель: $nice кг)';
          },
        )
        .replaceAllMapped(
          // standalone "target 69.4kg" without parens
          RegExp(r'\btarget\s+([\d.]+)\s*kg\b', caseSensitive: false),
          (m) {
            final raw = double.tryParse(m.group(1) ?? '');
            final nice = raw != null ? raw.toStringAsFixed(1) : m.group(1);
            return 'цель: $nice кг';
          },
        );
  }

  /// Builds the post-add coaching message using fresh daily stats.
  ///
  /// [addedKcal] may be null when the caller (photo flow) doesn't know the
  /// exact amount — the confirmation line is then shown without the kcal figure.
  String _buildCoachMessage({
    required MacroStats stats,
    required String dishLabel,
    required bool isRu,
    double? addedKcal,
  }) {
    final confirmLine = addedKcal != null
        ? (isRu
            ? '✓ Добавлено: $dishLabel — ${addedKcal.round()} ккал'
            : '✓ Added: $dishLabel — ${addedKcal.round()} kcal')
        : (isRu ? '✓ Добавлено: $dishLabel' : '✓ Added: $dishLabel');

    final cal = stats.caloriesEaten;
    final calGoal = stats.caloriesGoal;
    final pro = stats.proteinEaten;
    final proGoal = stats.proteinGoal;

    if (calGoal <= 0) return confirmLine;

    final calPct = cal / calGoal;
    final proPct = proGoal > 0 ? pro / proGoal : 1.0;

    final String advice;
    if (calPct > 1.10) {
      advice = isRu
          ? 'Сегодня перебор: ${cal.round()} из ${calGoal.round()} ккал.'
              ' По исследованиям, важна средняя калорийность за неделю — в следующие дни старайся есть чуть легче.'
          : 'You\'re over today: ${cal.round()} / ${calGoal.round()} kcal.'
              ' Research shows weekly average matters more — try to eat a little lighter over the next few days.';
    } else if (proPct < 0.5 && proGoal > 0) {
      advice = isRu
          ? 'Белка пока маловато — ${pro.round()} из ${proGoal.round()} г.'
              ' Следующий приём пищи сделай белковым.'
          : 'Protein is low — ${pro.round()} / ${proGoal.round()} g.'
              ' Make your next meal protein-rich.';
    } else if (calPct > 0.85 && proPct >= 0.9) {
      advice = isRu
          ? 'Отличный баланс! ${cal.round()} / ${calGoal.round()} ккал, белок в норме (${pro.round()} г).'
              ' Есть небольшой запас — можно позволить что-нибудь вкусненькое без чувства вины.'
          : 'Great balance! ${cal.round()} / ${calGoal.round()} kcal, protein on track (${pro.round()} g).'
              ' You have a little room — feel free to treat yourself.';
    } else if (calPct > 0.85) {
      advice = isRu
          ? 'Калории почти на норме: ${cal.round()} / ${calGoal.round()} ккал.'
              ' Белка не хватает: ${pro.round()} из ${proGoal.round()} г — добавь белковый перекус.'
          : 'Calories near goal: ${cal.round()} / ${calGoal.round()} kcal.'
              ' Protein is short: ${pro.round()} / ${proGoal.round()} g — grab a protein snack.';
    } else {
      final left = (calGoal - cal).round();
      advice = isRu
          ? 'Сегодня ${cal.round()} из ${calGoal.round()} ккал — ещё $left ккал до нормы.'
              ' Белок: ${pro.round()} / ${proGoal.round()} г.'
          : 'Today ${cal.round()} / ${calGoal.round()} kcal — $left kcal to goal.'
              ' Protein: ${pro.round()} / ${proGoal.round()} g.';
    }

    return '$confirmLine\n\n$advice';
  }

  /// Confirms the pending meal: posts to /api/meals/add_selected, invalidates
  /// dashboard/journal providers, replaces the preview with a synthetic
  /// "✓ added" assistant message (local-only, not persisted on backend).
  Future<void> _confirmAddPendingMeal() async {
    final pendingState = ref.read(pendingMealProvider);
    final pending = pendingState.items;
    if (pending == null || pending.isEmpty || pendingState.isAdding) return;
    ref.read(pendingMealProvider.notifier).setAdding(true);
    HapticFeedback.mediumImpact();

    try {
      final items = pending.map((item) {
        final n = item.nutrientsTotal;
        final mono = n.monounsaturatedFat ?? 0;
        final poly = n.polyunsaturatedFat ?? 0;
        return {
          'name': item.name,
          'calories': n.calories,
          'protein': n.protein,
          'fat': n.fat,
          'carbs': n.carbs,
          'weight': item.weightGrams,
          'fiber': n.fiber,
          'sugar': n.sugar,
          'net_carbs': n.netCarbs,
          'saturated_fat': n.saturatedFat,
          'unsaturated_fat': mono + poly > 0 ? mono + poly : null,
          'glycemic_index': item.nutrientsPer100g.glycemicIndex,
          'sodium_mg': n.sodiumMg,
          'cholesterol_mg': n.cholesterolMg,
          'potassium_mg': n.potassiumMg,
          'source': item.source,
          'source_url': item.sourceUrl,
        };
      }).toList();

      await apiDio.post('/api/meals/add_selected', data: {
        'items': items,
        'dish_name': pending.map((i) => i.name).join(', '),
        'meal_type': pendingState.mealType,
      });

      // Refresh everything that displays meal data.
      ref.invalidate(todayStatsProvider);
      ref.invalidate(todayMealsProvider);
      ref.invalidate(userGoalsProvider);
      ref.invalidate(dailyKcalHistoryProvider);
      final today = DateTime.now();
      final todayIso = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      ref.invalidate(journalDayMealsProvider(todayIso));

      final totalKcal = pending.fold<double>(
        0, (s, i) => s + i.nutrientsTotal.calories);
      final dishLabel = pending.map((i) => i.name).join(', ');
      // Mirror the language of the most recent user message.
      final msgs = ref.read(chatHistoryProvider);
      final lastUserMsg =
          msgs.lastWhere((m) => m.role == 'user', orElse: () => msgs.first);
      final isRu = _detectMessageLang(lastUserMsg.content) == 'ru';

      // Fetch fresh stats (already invalidated above) for coaching message.
      MacroStats freshStats;
      try {
        freshStats = await ref.read(todayStatsProvider.future);
      } catch (_) {
        freshStats = const MacroStats(
          caloriesEaten: 0, caloriesGoal: 0,
          proteinEaten: 0, proteinGoal: 0,
          fatEaten: 0, fatGoal: 0,
          carbsEaten: 0, carbsGoal: 0,
        );
      }

      // Ask the backend coach for a history-aware reply. The hardcoded
      // `_buildCoachMessage` template named specific foods like "fish" even
      // when the user had no fish in their history — see /api/coach/advice
      // which feeds `frequent_meals` (last 30 days) into the prompt.
      // Falls back to the local template on any network/Claude failure.
      String? backendAdvice;
      try {
        final advResp = await apiDio.post(
          '/api/coach/advice',
          data: {
            'meal_names': pending.map((i) => i.name).toList(),
            'total_calories': totalKcal,
          },
        );
        backendAdvice = (advResp.data['advice'] as String?)?.trim();
        if (backendAdvice != null && backendAdvice.isEmpty) {
          backendAdvice = null;
        }
        if (isRu && backendAdvice != null) {
          backendAdvice = _localizeBackendAdvice(backendAdvice);
        }
      } on Exception {
        // network/Claude timeout — fall back to client template below
        backendAdvice = null;
      }

      final confirmLine = isRu
          ? '✓ Добавлено: $dishLabel — ${totalKcal.round()} ккал'
          : '✓ Added: $dishLabel — ${totalKcal.round()} kcal';
      final reply = backendAdvice != null
          ? '$confirmLine\n\n$backendAdvice'
          : _buildCoachMessage(
              stats: freshStats,
              dishLabel: dishLabel,
              isRu: isRu,
              addedKcal: totalKcal,
            );

      if (!mounted) return;
      final addedMsg = ChatMessage(
        role: 'assistant',
        content: reply,
        createdAt: DateTime.now(),
      );
      ref.read(pendingMealProvider.notifier).clear();
      ref.read(chatHistoryProvider.notifier).add(addedMsg);
      unawaited(_persistLocalMessage(addedMsg));
      try {
        AnalyticsService.mealSaved(
          itemCount: pending.length,
          mode: 'chat_route',
          totalCalories: totalKcal.round(),
        );
      } catch (_) {}
      _scrollToBottom();
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not add to journal. Try again.'),
          backgroundColor: K2Colors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) ref.read(pendingMealProvider.notifier).setAdding(false);
    }
  }

  /// Per-item "Correct" handler. Opens a sheet so the user can fix a wrong
  /// name, weight, or KBJU on a single line of the pending meal card.
  ///
  /// Resolution order:
  ///   1. Name changed → re-search via /api/v2/parse_meal_suggestions; the
  ///      returned item replaces this slot. Other items stay.
  ///   2. Otherwise, if KBJU changed → derive a new `nutrientsPer100g` from
  ///      the user's totals and weight (so subsequent weight edits still
  ///      scale correctly).
  ///   3. Otherwise, if only weight changed → `item.withWeight(...)`.
  Future<void> _onEditPendingItem(int index) async {
    final items = ref.read(pendingMealProvider).items;
    if (items == null || index < 0 || index >= items.length) return;
    final original = items[index];

    final correction = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CorrectIngredientSheet(original: original),
    );
    if (correction == null || correction.isEmpty || !mounted) return;

    final lang = Localizations.localeOf(context).languageCode == 'ru'
        ? 'ru'
        : 'en';
    final isRu = lang == 'ru';
    final unit = isRu ? 'г' : 'g';
    final composed = isRu
        ? '${original.name}, ${original.weightGrams.toStringAsFixed(0)}$unit. '
            'Уточнение: $correction'
        : '${original.name}, ${original.weightGrams.toStringAsFixed(0)}$unit. '
            'Correction: $correction';

    ref.read(pendingMealProvider.notifier).setAdding(true);
    try {
      final resp = await apiDio.post(
        '/api/v2/parse_meal_suggestions',
        data: {'text': composed, 'language': lang},
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      );
      final raw = (resp.data['items'] as List?)?.cast<Map<String, dynamic>>();
      if (raw == null || raw.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isRu
              ? 'Не удалось найти подходящий вариант'
              : 'Could not find a matching item'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      // Carry the user's current weight forward unless the backend explicitly
      // overrides it (e.g. when correction itself implies a new portion).
      final first = raw.first;
      final suggestedW = (first['weight_grams'] as num?)?.toDouble();
      final useW = suggestedW ?? original.weightGrams;
      final updated = ingredientV2FromSuggestion(first, useW);
      ref.read(pendingMealProvider.notifier).replaceItem(index, updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isRu
            ? 'Обновлено: ${updated.name} '
                '${updated.weightGrams.toStringAsFixed(0)}$unit · '
                '${updated.nutrientsTotal.calories.round()} ккал'
            : 'Updated: ${updated.name} '
                '${updated.weightGrams.toStringAsFixed(0)}$unit · '
                '${updated.nutrientsTotal.calories.round()} kcal'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isRu
            ? 'Ошибка обновления — попробуй ещё раз'
            : 'Update failed — try again'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: K2Colors.error,
      ));
    } finally {
      if (mounted) ref.read(pendingMealProvider.notifier).setAdding(false);
    }
  }

  /// Inline weight change from a row's weight pill. Scales the item's macros
  /// proportionally via `withWeight` and replaces it in the provider.
  void _onPendingItemWeightChange(int index, double newWeight) {
    final items = ref.read(pendingMealProvider).items;
    if (items == null || index < 0 || index >= items.length) return;
    if (newWeight <= 0) return;
    final updated = items[index].withWeight(newWeight);
    ref.read(pendingMealProvider.notifier).replaceItem(index, updated);
  }

  void _cancelPendingMeal() {
    final msgs = ref.read(chatHistoryProvider);
    final lastUserMsg =
        msgs.lastWhere((m) => m.role == 'user', orElse: () => msgs.first);
    final isRu = _detectMessageLang(lastUserMsg.content) == 'ru';
    final cancelMsg = ChatMessage(
      role: 'assistant',
      content: isRu ? 'Окей, не добавляю.' : 'Okay, skipping.',
      createdAt: DateTime.now(),
    );
    ref.read(pendingMealProvider.notifier).clear();
    ref.read(chatHistoryProvider.notifier).add(cancelMsg);
    unawaited(_persistLocalMessage(cancelMsg));
    _scrollToBottom();
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

  // ── Attach toolbar handlers ─────────────────────────────────────────────────

  /// Opens the KF2 capture screen, adds a photo bubble to chat, and starts
  /// recognition in the background. The user can freely navigate the app while
  /// recognition runs. Result is delivered via [ref.listen] on
  /// [photoRecognitionProvider] and a push notification when done.
  Future<void> _handleCamera() async {
    debugPrint('KF2-CHAT: _handleCamera start');
    final photo = await context.push<XFile>('/kf2/capture');
    if (!mounted || photo == null) return;

    final lang = Localizations.localeOf(context).languageCode;

    // Ensure clean state before starting a new recognition. Even though
    // clear() is called when the result sheet is dismissed, call it again
    // here as a defensive measure — prevents stale results if the sheet was
    // dismissed without triggering the .then() callback.
    ref.read(photoRecognitionProvider.notifier).clear();
    _photoResultConsumed = false;

    // Immediately show the photo in chat with a loading indicator.
    final photoMsg = ChatMessage(
      role: _kPhotoAnalyzingRole,
      content: photo.path,
      createdAt: DateTime.now(),
    );
    ref.read(chatHistoryProvider.notifier).add(photoMsg);
    _scrollToBottom();

    // Fire recognition in the background — outcome handled by ref.listen.
    unawaited(
      ref.read(photoRecognitionProvider.notifier).startRecognition(photo, lang),
    );
  }

  // ── Photo recognition result handlers ────────────────────────────────────────

  void _onPhotoRecognitionDone(RecognitionResult result) {
    if (!mounted || _photoResultConsumed) return;
    _photoResultConsumed = true;

    ref.read(chatHistoryProvider.notifier)
        .removeWhere((m) => m.role == _kPhotoAnalyzingRole);
    _pushPhotoResult(result.dishName, result.items);
  }

  void _onPhotoRecognitionFailed(PhotoRecognitionState state) {
    if (!mounted) return;
    ref.read(chatHistoryProvider.notifier)
        .removeWhere((m) => m.role == _kPhotoAnalyzingRole);
    ref.read(photoRecognitionProvider.notifier).clear();
    _photoResultConsumed = false;

    final isRu = state.langCode == 'ru';
    // Surface the real backend error in debug/profile builds — the bare
    // "что-то пошло не так" message hides whether it was a 4xx, timeout,
    // connectivity issue, or Claude vision failure. Strip generic
    // "Exception:" prefix.
    String details = (state.errorMessage ?? '').trim();
    if (details.startsWith('Exception:')) {
      details = details.substring('Exception:'.length).trim();
    }
    final msg = state.isNotFood
        ? (isRu
            ? 'Это не похоже на еду. Попробуйте ещё раз.'
            : "That doesn't look like food. Please try again.")
        : (isRu
            ? 'Что-то пошло не так${details.isEmpty ? "" : ": $details"}. '
                'Попробуйте ещё раз.'
            : 'Something went wrong'
                '${details.isEmpty ? "" : ": $details"}. Please try again.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: state.isNotFood ? null : K2Colors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _pushPhotoResult(String dishName, List<IngredientV2> items) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 1.0,
            builder: (_, sc) => RecognitionResultSheetKF2(
              dishName: dishName,
              ingredients: items,
              mealDate: null,
              originalText: null,
              onSaved: (name) {
                ref.read(photoRecognitionProvider.notifier).clear();
                unawaited(_onPhotoSaved(name));
              },
            ),
          ),
        ),
      ),
    )
        .then((_) {
      // User dismissed the sheet without saving.
      ref.read(photoRecognitionProvider.notifier).clear();
      _photoResultConsumed = false;
    });
  }

  Future<void> _onPhotoSaved(String dishName) async {
    MacroStats freshStats;
    try {
      freshStats = await ref.read(todayStatsProvider.future);
    } catch (_) {
      freshStats = const MacroStats(
        caloriesEaten: 0,
        caloriesGoal: 0,
        proteinEaten: 0,
        proteinGoal: 0,
        fatEaten: 0,
        fatGoal: 0,
        carbsEaten: 0,
        carbsGoal: 0,
      );
    }
    if (!mounted) return;

    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final coachText = _buildCoachMessage(
      stats: freshStats,
      dishLabel: dishName,
      isRu: isRu,
    );
    final coachMsg = ChatMessage(
      role: 'assistant',
      content: coachText,
      createdAt: DateTime.now(),
    );
    ref.read(chatHistoryProvider.notifier).add(coachMsg);
    unawaited(_persistLocalMessage(coachMsg));
    _scrollToBottom();
  }

  /// Handles mic button tap: starts recording, or stops and transcribes.
  Future<void> _handleMic() async {
    debugPrint('[mic] tap state=$_voiceState');
    if (_voiceState == _VoiceState.transcribing) return;

    if (_voiceState == _VoiceState.recording) {
      await _stopAndTranscribe();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    debugPrint('[mic] requesting permission');
    final status = await Permission.microphone.request();
    debugPrint('[mic] permission=$status');
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status.isPermanentlyDenied
              ? 'Mic blocked. Open Settings → Kayfit → Microphone.'
              : 'Microphone permission denied'),
          backgroundColor: K2Colors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: status.isPermanentlyDenied
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
      return;
    }

    try {
      // Probe encoder support — surfaces a clear error if AAC is unsupported
      // on this device/simulator instead of silently never recording.
      final canRecord = await _recorder.hasPermission();
      debugPrint('[mic] hasPermission=$canRecord');
      if (!canRecord) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recorder cannot access microphone.'),
              backgroundColor: K2Colors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      _recordPath = '${dir.path}/chat_voice.m4a';
      debugPrint('[mic] starting recorder → $_recordPath');
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordPath!,
      );
      debugPrint('[mic] recorder started OK');
      HapticFeedback.lightImpact();
      if (mounted) setState(() => _voiceState = _VoiceState.recording);
    } on Exception catch (e, st) {
      debugPrint('[mic] start FAILED: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start recording: $e'),
            backgroundColor: K2Colors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _stopAndTranscribe() async {
    debugPrint('[mic] stopping recorder');
    final savedPath = await _recorder.stop();
    debugPrint('[mic] stopped, file=$savedPath');
    if (!mounted) return;
    setState(() => _voiceState = _VoiceState.transcribing);
    HapticFeedback.lightImpact();

    try {
      final lang = Localizations.localeOf(context).languageCode;
      final form = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          _recordPath!,
          filename: 'voice.m4a',
        ),
      });
      debugPrint('[mic] POST /api/transcribe?language=$lang');
      final resp =
          await apiDio.post('/api/transcribe?language=$lang', data: form);
      final raw = resp.data;
      final text = raw is Map
          ? (raw['text'] as String? ?? '')
          : (raw?.toString() ?? '');
      debugPrint('[mic] transcribe got text="${text.length > 50 ? '${text.substring(0, 50)}...' : text}"');

      if (!mounted) return;
      if (text.isNotEmpty) {
        // Drop the text into the input field so the user can review and edit
        // before sending. Auto-send is intentional NOT — user wants to verify
        // the transcription first.
        _textController.text = text;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not transcribe audio. Please try again.'),
            backgroundColor: K2Colors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } on Exception catch (e, st) {
      debugPrint('[mic] transcribe FAILED: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcription failed: $e'),
            backgroundColor: K2Colors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _voiceState = _VoiceState.idle);
    }
  }

  /// Opens the legacy barcode scanner via Navigator (no GoRouter route exists).
  Future<void> _handleBarcode() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const BarcodeScannerScreenV2(),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const t = K2Theme.light;
    final messages = ref.watch(chatHistoryProvider);
    final pendingMeal = ref.watch(pendingMealProvider);

    // Auto-show result sheet when background photo recognition completes.
    ref.listen<PhotoRecognitionState>(
      photoRecognitionProvider,
      (prev, next) {
        final wasAnalyzing = prev?.isAnalyzing ?? false;
        if (next.isDone && next.result != null && wasAnalyzing) {
          _onPhotoRecognitionDone(next.result!);
        }
        if ((next.isError || next.isNotFood) && wasAnalyzing) {
          _onPhotoRecognitionFailed(next);
        }
      },
    );

    return Scaffold(
      backgroundColor: t.bg,
      bottomNavigationBar: Kayfit2TabBar(
        theme: t,
        active: 'chat',
        onTab: (key) {
          if (key == 'journal') context.go('/journal-v2');
        },
        onAdd: () {
          // "+" from chat tab — focus the input field so the user can type.
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            _K2TopBar(
              theme: t,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/journal-v2');
                }
              },
            ),

            // ── Status strip (dot + label + "online") ─────────────────────
            _StatusStrip(theme: t),

            // ── Disclaimer / citation banner (Guideline 1.4.1) ────────────
            _ChatDisclaimerBanner(theme: t),

            // ── Message list ───────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: K2Colors.accent,
                        strokeWidth: 2,
                      ),
                    )
                  : messages.isEmpty && _thinking == null
                      ? _EmptyState(theme: t)
                      : _MessageList(
                          scrollController: _scrollController,
                          messages: messages,
                          thinking: _thinking,
                          theme: t,
                        ),
            ),

            // ── Pending meal confirm card ──────────────────────────────────
            if (pendingMeal.isActive)
              _PendingMealCard(
                items: pendingMeal.items!,
                mealType: pendingMeal.mealType,
                onMealTypeChanged:
                    ref.read(pendingMealProvider.notifier).setMealType,
                isAdding: pendingMeal.isAdding,
                onAdd: _confirmAddPendingMeal,
                onCancel: _cancelPendingMeal,
                onEditItem: _onEditPendingItem,
                onWeightChange: _onPendingItemWeightChange,
                theme: t,
              ),

            // ── Attach toolbar ─────────────────────────────────────────────
            _AttachToolbar(
              theme: t,
              onCamera: _handleCamera,
              onMic: _handleMic,
              onBarcode: _handleBarcode,
              voiceState: _voiceState,
            ),

            // ── Input row ──────────────────────────────────────────────────
            _InputPill(
              controller: _textController,
              isSending: _isSending,
              theme: t,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _K2TopBar extends StatelessWidget {
  const _K2TopBar({required this.theme, required this.onBack});

  final K2Theme theme;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(
          bottom: BorderSide(color: t.hairline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: t.fg, size: 18),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              'Coach',
              style: TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: t.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status strip — "ai nutritionist · online"
// ─────────────────────────────────────────────────────────────────────────────

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(
          bottom: BorderSide(color: t.hairline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.fg),
          ),
          const SizedBox(width: 8),
          Text(
            'ai nutritionist',
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 11,
              color: t.fgDim,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            'online',
            style: TextStyle(
              fontFamily: K2Fonts.mono,
              fontSize: 10,
              color: t.fgMute,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.border, width: 0.5),
                color: t.surface,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 24, color: t.fgMute),
            ),
            const SizedBox(height: 16),
            Text(
              isRu ? 'ещё ничего не записано' : 'nothing logged yet',
              style: TextStyle(
                fontFamily: K2Fonts.mono,
                fontSize: 13,
                color: t.fgDim,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isRu ? 'спросите или опишите что съели' : 'ask or describe what you ate',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 11,
                color: t.fgMute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message list
// ─────────────────────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.scrollController,
    required this.messages,
    required this.thinking,
    required this.theme,
  });

  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final _ThinkingState? thinking;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final itemCount = messages.length + (thinking != null ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < messages.length) {
          final msg = messages[index];
          if (msg.role == _kPhotoAnalyzingRole) {
            return _PhotoAnalyzingBubble(
              photoPath: msg.content,
              theme: theme,
            );
          }
          return _MessageBubble(
            message: msg,
            theme: theme,
            isNewest: index == messages.length - 1 && thinking == null,
          );
        }
        // Thinking bubble appended after all messages.
        return _ThinkingBubble(state: thinking!, theme: theme);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single message bubble (user right / AI left)
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    required this.message,
    required this.theme,
    required this.isNewest,
  });

  final ChatMessage message;
  final K2Theme theme;
  final bool isNewest;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
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
    final isUser = widget.message.role == 'user';
    final t = widget.theme;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: EdgeInsets.only(
            left: isUser ? 56 : 0,
            right: isUser ? 0 : 56,
            top: 3,
            bottom: 7,
          ),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser ? K2Colors.accent : t.surface,
                        border: Border.all(color: t.border, width: 0.5),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(isUser ? 14 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 14),
                        ),
                      ),
                      child: Text(
                        widget.message.content,
                        style: TextStyle(
                          fontFamily: K2Fonts.sans,
                          fontSize: 14,
                          height: 1.45,
                          color: isUser ? Colors.white : t.fg,
                        ),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 3, left: 4, right: 4),
                      child: Text(
                        _formatTime(widget.message.createdAt),
                        style: TextStyle(
                          fontFamily: K2Fonts.mono,
                          fontSize: 10,
                          color: t.fgMute,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Thinking bubble — step list with spinner on last active step
// ─────────────────────────────────────────────────────────────────────────────

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble({required this.state, required this.theme});

  final _ThinkingState state;
  final K2Theme theme;

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final steps = widget.state.steps;
    final isDone = widget.state.done;

    return Padding(
      padding: const EdgeInsets.only(right: 56, top: 3, bottom: 7),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.border, width: 0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Last active step — spinner; earlier steps — check.
                      if (i == steps.length - 1 && !isDone)
                        _SpinnerDot(controller: _spinCtrl, color: t.fgDim)
                      else
                        Icon(Icons.check_rounded,
                            size: 11, color: t.fgDim),
                      const SizedBox(width: 8),
                      Text(
                        steps[i],
                        style: TextStyle(
                          fontFamily: K2Fonts.mono,
                          fontSize: 11,
                          color: t.fgDim,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spinning ring dot that mirrors the JSX `kfSpin` CSS animation.
class _SpinnerDot extends StatelessWidget {
  const _SpinnerDot({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: controller.value * 2 * math.pi,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            // Clip the top-right arc so it appears as an open ring (the
            // "borderTopColor: transparent" equivalent from CSS).
            child: ClipPath(
              clipper: _ArcClipper(),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Clips away the top quadrant of a circle to mimic `border-top transparent`.
class _ArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height));
    return path;
  }

  @override
  bool shouldReclip(_ArcClipper oldClipper) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Attach toolbar — camera / mic / barcode
// ─────────────────────────────────────────────────────────────────────────────

class _AttachToolbar extends StatelessWidget {
  const _AttachToolbar({
    required this.theme,
    required this.onCamera,
    required this.onMic,
    required this.onBarcode,
    required this.voiceState,
  });

  final K2Theme theme;
  final VoidCallback onCamera;
  final Future<void> Function() onMic;
  final VoidCallback onBarcode;
  final _VoiceState voiceState;

  @override
  Widget build(BuildContext context) {
    final t = theme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: t.bg,
      child: Row(
        children: [
          // Camera button
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: onCamera,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border, width: 0.5),
                  color: t.surface,
                ),
                child: Icon(Icons.camera_alt_outlined, size: 15, color: t.fg),
              ),
            ),
          ),

          // Mic button — reflects voice state
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: voiceState == _VoiceState.transcribing ? null : onMic,
              child: _MicButton(theme: t, voiceState: voiceState),
            ),
          ),

          // Barcode button
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: onBarcode,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border, width: 0.5),
                  color: t.surface,
                ),
                child:
                    Icon(Icons.barcode_reader, size: 15, color: t.fg),
              ),
            ),
          ),

          // "Recording…" / "Transcribing…" label next to mic
          if (voiceState != _VoiceState.idle) ...[
            Text(
              voiceState == _VoiceState.recording
                  ? 'Recording…'
                  : 'Transcribing…',
              style: TextStyle(
                fontFamily: K2Fonts.mono,
                fontSize: 11,
                color: voiceState == _VoiceState.recording
                    ? K2Colors.error
                    : t.fgDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Animated mic button that pulses red while recording and shows a spinner
/// while transcribing.
class _MicButton extends StatefulWidget {
  const _MicButton({required this.theme, required this.voiceState});

  final K2Theme theme;
  final _VoiceState voiceState;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceState != widget.voiceState) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.voiceState == _VoiceState.recording) {
      _pulseCtrl.repeat(reverse: true);
    } else {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final isRecording = widget.voiceState == _VoiceState.recording;
    final isTranscribing = widget.voiceState == _VoiceState.transcribing;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final scale = isRecording ? (1.0 + 0.12 * _pulseCtrl.value) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isRecording
                    ? K2Colors.error
                    : isTranscribing
                        ? t.fgDim
                        : t.border,
                width: isRecording ? 1.5 : 0.5,
              ),
              color: isRecording
                  ? K2Colors.error.withValues(alpha: 0.12)
                  : t.surface,
            ),
            child: isTranscribing
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: t.fgDim,
                    ),
                  )
                : Icon(
                    isRecording
                        ? Icons.stop_rounded
                        : Icons.mic_none_rounded,
                    size: 15,
                    color: isRecording ? K2Colors.error : t.fg,
                  ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input pill
// ─────────────────────────────────────────────────────────────────────────────

class _InputPill extends StatefulWidget {
  const _InputPill({
    required this.controller,
    required this.isSending,
    required this.theme,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final K2Theme theme;
  final VoidCallback onSend;

  @override
  State<_InputPill> createState() => _InputPillState();
}

class _InputPillState extends State<_InputPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sendCtrl;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _sendCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
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
    if (has == _hasText) return;
    _hasText = has;
    if (has) {
      _sendCtrl.forward();
    } else {
      _sendCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      color: t.bg,
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Rounded pill text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: t.border, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  fontFamily: K2Fonts.sans,
                  fontSize: 14,
                  color: t.fg,
                ),
                decoration: InputDecoration(
                  hintText: isRu ? 'спросите или опишите что съели' : 'ask or describe what you ate',
                  hintStyle: TextStyle(
                    fontFamily: K2Fonts.sans,
                    fontSize: 14,
                    color: t.fgMute,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send circle — elastic scale in/out
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _sendCtrl,
              curve: Curves.elasticOut,
              reverseCurve: Curves.easeInCubic,
            ),
            child: GestureDetector(
              onTap: widget.isSending ? null : widget.onSend,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hasText ? t.fg : t.border,
                ),
                child: widget.isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        size: 16,
                        color: _hasText ? t.bg : t.fgMute,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending meal confirm card
// ─────────────────────────────────────────────────────────────────────────────

class _PendingMealCard extends StatelessWidget {
  const _PendingMealCard({
    required this.items,
    required this.mealType,
    required this.onMealTypeChanged,
    required this.isAdding,
    required this.onAdd,
    required this.onCancel,
    required this.onEditItem,
    required this.onWeightChange,
    required this.theme,
  });

  final List<IngredientV2> items;
  final String mealType;
  final ValueChanged<String> onMealTypeChanged;
  final bool isAdding;
  final VoidCallback onAdd;
  final VoidCallback onCancel;

  /// Triggered when the user taps the "correct" link on a row. Opens the
  /// AI-correction sheet — user types a free-form correction, backend
  /// re-parses through Claude + FatSecret and replaces the item.
  final void Function(int index) onEditItem;

  /// Inline weight edit — committed when the user finishes editing the
  /// weight pill on a row. Triggers a proportional macro recalculation via
  /// `IngredientV2.withWeight`.
  final void Function(int index, double newWeight) onWeightChange;

  final K2Theme theme;

  static const _kMealTypes = ['breakfast', 'lunch', 'snack', 'dinner'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    final totalKcal =
        items.fold<double>(0, (s, i) => s + i.nutrientsTotal.calories);
    final totalP =
        items.fold<double>(0, (s, i) => s + i.nutrientsTotal.protein);
    final totalF = items.fold<double>(0, (s, i) => s + i.nutrientsTotal.fat);
    final totalC = items.fold<double>(0, (s, i) => s + i.nutrientsTotal.carbs);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_rounded, size: 16, color: K2Colors.accent),
              const SizedBox(width: 6),
              Text(
                isRu ? 'Добавить в журнал?' : 'Add to journal?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.fg,
                  fontFamily: K2Fonts.sans,
                ),
              ),
              const Spacer(),
              Text(
                '${totalKcal.round()} ${l10n.macro_kcal}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.fg,
                  fontFamily: K2Fonts.mono,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isAdding)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: K2Colors.accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRu ? 'Перепроверяем через базу…' : 'Checking database…',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.fgDim,
                      fontFamily: K2Fonts.sans,
                    ),
                  ),
                ],
              ),
            ),
          // Cap items section so a long voice-parsed meal can't squeeze the
          // chat ListView to zero height. ~210 px shows about 3 ingredient
          // rows; longer lists scroll internally.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 210),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: theme.hairline,
              ),
              itemBuilder: (_, idx) => _PendingMealItemRow(
                item: items[idx],
                theme: theme,
                isAdding: isAdding,
                onCorrect: () => onEditItem(idx),
                onWeightChange: (newW) => onWeightChange(idx, newW),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isRu
              ? 'Б ${totalP.round()} · Ж ${totalF.round()} · У ${totalC.round()}'
              : 'P ${totalP.round()} · F ${totalF.round()} · C ${totalC.round()}',
            style: TextStyle(
              fontSize: 11,
              color: theme.fgMute,
              fontFamily: K2Fonts.mono,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 26,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kMealTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, idx) {
                final mt = _kMealTypes[idx];
                final selected = mt == mealType;
                return GestureDetector(
                  onTap: isAdding ? null : () => onMealTypeChanged(mt),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? theme.fg : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      border:
                          Border.all(color: selected ? theme.fg : theme.border),
                    ),
                    child: Center(
                      child: Text(
                        _localizedMealType(mt, isRu),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: selected ? theme.bg : theme.fgDim,
                          fontFamily: K2Fonts.sans,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isAdding ? null : onCancel,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.border),
                    ),
                    child: Center(
                      child: Text(
                        isRu ? 'Отмена' : 'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.fgDim,
                          fontFamily: K2Fonts.sans,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: isAdding ? null : onAdd,
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isAdding ? theme.fgMute : theme.fg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: isAdding
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.bg,
                              ),
                            )
                          : Text(
                              isRu ? 'Добавить' : 'Add',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.bg,
                                fontFamily: K2Fonts.sans,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _localizedMealType(String mt, bool isRu) {
    if (!isRu) return mt[0].toUpperCase() + mt.substring(1);
    return switch (mt) {
      'breakfast' => 'Завтрак',
      'lunch' => 'Обед',
      'snack' => 'Перекус',
      'dinner' => 'Ужин',
      _ => mt,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disclaimer / citation banner — Guideline 1.4.1
// ─────────────────────────────────────────────────────────────────────────────

class _ChatDisclaimerBanner extends StatelessWidget {
  const _ChatDisclaimerBanner({required this.theme});

  final K2Theme theme;

  static const _whoUrl =
      'https://www.who.int/news-room/fact-sheets/detail/healthy-diet';
  static const _usdaUrl =
      'https://odphp.health.gov/our-work/nutrition-physical-activity/dietary-guidelines';

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final disclaimerText = isRu
        ? 'Ответы ИИ носят информационный характер и не заменяют консультацию врача. Основано на: '
        : 'AI responses are for informational purposes only. Based on: ';
    final whoLabel = isRu ? 'Рекомендации ВОЗ' : 'WHO Guidelines';
    final usdaLabel = isRu ? 'Рекомендации USDA' : 'USDA Guidelines';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.hairline, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline, size: 13, color: theme.fgDim),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 11, color: theme.fgDim, height: 1.4),
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
// Pending meal item row — name + KBJU + inline-editable weight pill + "fix"
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a single ingredient inside the pending meal card.
///
/// Two-line layout, K2 design tokens:
///   1. Name (bold) ............................ "скорректировать" link
///   2. [weight pill] · K · B · F · C ............................ kcal
///
/// The weight pill toggles into an inline TextField on tap — committing on
/// submit or focus loss recalculates macros proportionally via
/// `IngredientV2.withWeight`. The "fix" link opens [_CorrectIngredientSheet]
/// for free-form AI corrections (re-parses through Claude + FatSecret).
class _PendingMealItemRow extends StatefulWidget {
  const _PendingMealItemRow({
    required this.item,
    required this.theme,
    required this.isAdding,
    required this.onCorrect,
    required this.onWeightChange,
  });

  final IngredientV2 item;
  final K2Theme theme;
  final bool isAdding;
  final VoidCallback onCorrect;
  final ValueChanged<double> onWeightChange;

  @override
  State<_PendingMealItemRow> createState() => _PendingMealItemRowState();
}

class _PendingMealItemRowState extends State<_PendingMealItemRow> {
  late final TextEditingController _weightCtrl;
  late final FocusNode _weightFocus;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.item.weightGrams.toStringAsFixed(0),
    );
    _weightFocus = FocusNode();
    _weightFocus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _PendingMealItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mirror provider-driven weight changes (e.g. AI correction) back into
    // the field — but only when not actively editing, to avoid clobbering
    // user keystrokes mid-typing.
    if (!_weightFocus.hasFocus &&
        oldWidget.item.weightGrams != widget.item.weightGrams) {
      _weightCtrl.text = widget.item.weightGrams.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _weightFocus.removeListener(_onFocusChange);
    _weightFocus.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_weightFocus.hasFocus) _commit();
  }

  void _commit() {
    final raw = _weightCtrl.text.trim();
    final v = double.tryParse(raw);
    if (v == null || v <= 0) {
      _weightCtrl.text = widget.item.weightGrams.toStringAsFixed(0);
    } else if ((v - widget.item.weightGrams).abs() > 0.5) {
      widget.onWeightChange(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = widget.theme;
    final i = widget.item;
    final n = i.nutrientsTotal;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final unit = isRu ? 'г' : 'g';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1 — name + correct link
          Row(
            children: [
              Expanded(
                child: Text(
                  i.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.fg,
                    fontFamily: K2Fonts.sans,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.isAdding ? null : widget.onCorrect,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    isRu ? 'скорректировать' : 'fix',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isAdding ? t.fgMute : K2Colors.accent,
                      fontFamily: K2Fonts.sans,
                      decoration: TextDecoration.underline,
                      decorationColor: K2Colors.accent.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Line 2 — weight pill + macros + kcal
          Row(
            children: [
              _WeightField(
                controller: _weightCtrl,
                focusNode: _weightFocus,
                unit: unit,
                onSubmitted: _commit,
                theme: t,
                readOnly: widget.isAdding,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroLine(
                  protein: n.protein,
                  fat: n.fat,
                  carbs: n.carbs,
                  isRu: isRu,
                  theme: t,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${n.calories.round()} ${l10n.macro_kcal}',
                style: TextStyle(
                  fontSize: 12,
                  color: t.fg,
                  fontFamily: K2Fonts.mono,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightField extends StatelessWidget {
  const _WeightField({
    required this.controller,
    required this.focusNode,
    required this.unit,
    required this.onSubmitted,
    required this.theme,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String unit;
  final VoidCallback onSubmitted;
  final K2Theme theme;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        readOnly ? theme.border : K2Colors.accent.withValues(alpha: 0.7);
    return SizedBox(
      width: 80,
      height: 26,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        textAlign: TextAlign.center,
        onSubmitted: (_) => onSubmitted(),
        style: TextStyle(
          fontSize: 12,
          color: readOnly ? theme.fgMute : theme.fg,
          fontFamily: K2Fonts.mono,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: K2Colors.accent, width: 1.5),
          ),
          suffixText: unit,
          suffixStyle: TextStyle(
            fontSize: 11,
            color: theme.fgMute,
            fontFamily: K2Fonts.mono,
          ),
        ),
      ),
    );
  }
}

class _MacroLine extends StatelessWidget {
  const _MacroLine({
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.isRu,
    required this.theme,
  });

  final double protein;
  final double fat;
  final double carbs;
  final bool isRu;
  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final dim = TextStyle(
      fontSize: 11,
      color: theme.fgDim,
      fontFamily: K2Fonts.mono,
    );
    final sep = dim.copyWith(color: theme.fgDim.withValues(alpha: 0.4));
    return Text.rich(
      TextSpan(
        style: dim,
        children: [
          TextSpan(text: isRu ? 'Б ' : 'P '),
          TextSpan(
            text: protein.round().toString(),
            style: dim.copyWith(color: theme.fg),
          ),
          TextSpan(text: '  ·  ', style: sep),
          TextSpan(text: isRu ? 'Ж ' : 'F '),
          TextSpan(
            text: fat.round().toString(),
            style: dim.copyWith(color: theme.fg),
          ),
          TextSpan(text: '  ·  ', style: sep),
          TextSpan(text: isRu ? 'У ' : 'C '),
          TextSpan(
            text: carbs.round().toString(),
            style: dim.copyWith(color: theme.fg),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI-correction sheet for a single ingredient
// ─────────────────────────────────────────────────────────────────────────────

/// Single free-form text input. Returns the user's correction string via
/// `Navigator.pop`; the chat handler concatenates it with the original
/// `(name, weight)` context and re-runs `/api/v2/parse_meal_suggestions` —
/// which goes through Claude identify → FatSecret enrichment, exactly the
/// same path as the initial voice/text parse. So whatever was wrong with
/// the LLM's first guess gets a fresh resolution.
class _CorrectIngredientSheet extends StatefulWidget {
  const _CorrectIngredientSheet({required this.original});

  final IngredientV2 original;

  @override
  State<_CorrectIngredientSheet> createState() =>
      _CorrectIngredientSheetState();
}

class _CorrectIngredientSheetState extends State<_CorrectIngredientSheet> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final txt = _textCtrl.text.trim();
    if (txt.isEmpty) return;
    Navigator.of(context).pop(txt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const t = K2Theme.light;
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final o = widget.original;
    final unit = isRu ? 'г' : 'g';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isRu ? 'Скорректировать ингредиент' : 'Correct ingredient',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.fg,
                  fontFamily: K2Fonts.sans,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.restaurant_rounded,
                      size: 14,
                      color: t.fgMute,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${o.name} · ${o.weightGrams.toStringAsFixed(0)}$unit · '
                        '${o.nutrientsTotal.calories.round()} ${l10n.macro_kcal}',
                        style: TextStyle(
                          fontSize: 12,
                          color: t.fgDim,
                          fontFamily: K2Fonts.sans,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isRu
                    ? 'Что не так? ИИ перепроверит блюдо через базу.'
                    : 'What\'s wrong? AI will re-check via the database.',
                style: TextStyle(
                  fontSize: 11,
                  color: t.fgMute,
                  fontFamily: K2Fonts.sans,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _textCtrl,
                autofocus: true,
                maxLines: 3,
                minLines: 2,
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.done,
                style: TextStyle(
                  fontSize: 14,
                  color: t.fg,
                  fontFamily: K2Fonts.sans,
                ),
                decoration: InputDecoration(
                  hintText: isRu
                      ? 'напр.: это с курицей, а не свининой'
                      : 'e.g. chicken, not pork',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: t.fgMute,
                    fontFamily: K2Fonts.sans,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: t.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: K2Colors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: t.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: t.border),
                        ),
                        child: Center(
                          child: Text(
                            isRu ? 'Отмена' : 'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: t.fgDim,
                              fontFamily: K2Fonts.sans,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _submit,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: t.fg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            isRu ? 'Применить' : 'Apply',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: t.bg,
                              fontFamily: K2Fonts.sans,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo analyzing bubble
// Shows the captured photo thumbnail + cycling recognition stage steps.
// Right-aligned (user side), replaces the old fullscreen Kf2RecognizingScreen.
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoAnalyzingBubble extends ConsumerStatefulWidget {
  const _PhotoAnalyzingBubble({
    required this.photoPath,
    required this.theme,
  });

  final String photoPath;
  final K2Theme theme;

  @override
  ConsumerState<_PhotoAnalyzingBubble> createState() =>
      _PhotoAnalyzingBubbleState();
}

class _PhotoAnalyzingBubbleState extends ConsumerState<_PhotoAnalyzingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    // Only watch the fields we actually render to minimise rebuilds.
    final (stageIndex, isDone, langCode) = ref.watch(
      photoRecognitionProvider
          .select((s) => (s.stageIndex, s.isDone, s.langCode)),
    );
    final stages = photoRecognitionStages(langCode);

    return Padding(
      padding: const EdgeInsets.only(left: 56, top: 3, bottom: 7),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          decoration: BoxDecoration(
            color: K2Colors.accent.withValues(alpha: 0.10),
            border: Border.all(
              color: K2Colors.accent.withValues(alpha: 0.22),
              width: 0.5,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                ),
                child: Image.file(
                  File(widget.photoPath),
                  width: 240,
                  height: 180,
                  fit: BoxFit.cover,
                  gaplessPlayback: false,
                  errorBuilder: (_, err, trace) => Container(
                    width: 240,
                    height: 180,
                    color: t.card,
                    child: Icon(
                      Icons.image_outlined,
                      color: t.fgMute,
                      size: 32,
                    ),
                  ),
                ),
              ),
              // Stage step list
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0;
                        i <= stageIndex && i < stages.length;
                        i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (i == stageIndex && !isDone)
                              _SpinnerDot(
                                controller: _spinCtrl,
                                color: K2Colors.accent.withValues(alpha: 0.8),
                              )
                            else
                              Icon(
                                Icons.check_rounded,
                                size: 11,
                                color: K2Colors.accent.withValues(alpha: 0.8),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              stages[i],
                              style: TextStyle(
                                fontFamily: K2Fonts.mono,
                                fontSize: 11,
                                color: t.fgDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
