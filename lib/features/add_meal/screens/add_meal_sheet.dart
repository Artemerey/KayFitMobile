import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kayfit/core/analytics/analytics_service.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/utils/nutrient_parser.dart';
import '../../../shared/widgets/keyboard_dismisser.dart';
import 'package:dio/dio.dart';
import 'barcode_scanner_screen_v2.dart';
import 'kf2_capture_screen.dart';
import 'kf2_recognizing_screen.dart';
import 'recognition_result_sheet_kf2.dart';
import 'recognition_result_sheet_v2.dart';
import '../../../core/subscription/require_subscription.dart';

// KF2_PREVIEW: set to false via --dart-define=KF2_PREVIEW=false to fall back.
const _useKF2 =
    bool.fromEnvironment('KF2_PREVIEW', defaultValue: true);

// KF2_RECOG: when true the Photo method opens the KF2 full-screen capture flow.
// Activate with: flutter run --dart-define=KF2_RECOG=true
const _useKF2Recog = bool.fromEnvironment('KF2_RECOG', defaultValue: false);

enum _InputMode { choose, text, voice, photo }
enum _LoadingType { none, voice, photo, parsing }

// ─────────────────────────────────────────────────────────────────────────────
// AddMealSheet
// ─────────────────────────────────────────────────────────────────────────────

class AddMealSheet extends ConsumerStatefulWidget {
  final DateTime? mealDate;
  const AddMealSheet({super.key, this.mealDate});

  @override
  ConsumerState<AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<AddMealSheet>
    with TickerProviderStateMixin {
  _InputMode _mode = _InputMode.choose;
  _LoadingType _loadingType = _LoadingType.none;

  final _textController = TextEditingController();
  final _textFocus = FocusNode();

  String _lang = 'en';

  final _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordPath;
  DateTime? _recordStart;

  // Sheet entrance
  late final AnimationController _sheetCtrl;
  late final Animation<double> _sheetFade;
  late final Animation<Offset> _sheetSlide;

  // Mode transition
  late final AnimationController _modeCtrl;

  @override
  void initState() {
    super.initState();
    AnalyticsService.mealAddOpened();

    _sheetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _sheetFade = CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic);
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic));

    _modeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..value = 1.0;

    _sheetCtrl.forward();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocus.dispose();
    _recorder.dispose();
    _sheetCtrl.dispose();
    _modeCtrl.dispose();
    super.dispose();
  }

  Future<void> _switchMode(_InputMode mode) async {
    HapticFeedback.selectionClick();
    if (mode != _InputMode.choose) {
      AnalyticsService.addMealModeSelected(mode.name);
    }
    await _modeCtrl.reverse();
    setState(() => _mode = mode);
    _modeCtrl.forward();
    if (mode == _InputMode.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _textFocus.requestFocus());
    }
  }

  Future<void> _openBarcodeScanner() async {
    HapticFeedback.selectionClick();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreenV2()),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _parseText(String text, String lang,
      {bool manageLoading = true}) async {
    if (manageLoading) setState(() => _loadingType = _LoadingType.parsing);
    try {
      final resp = await apiDio.post(
        '/api/v2/parse_meal_suggestions',
        data: {'text': text, 'language': lang},
        options: Options(
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final rawItems = (resp.data['items'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];

      if (!mounted) return;

      if (rawItems.isNotEmpty) {
        final v2items = rawItems.map((raw) {
          final w = (raw['weight_grams'] as num?)?.toDouble() ?? 100.0;
          return ingredientV2FromSuggestion(raw, w);
        }).toList();

        AnalyticsService.mealParsed(v2items.length, _mode.name);

        if (manageLoading) setState(() => _loadingType = _LoadingType.none);

        final summaryName = v2items.map((i) => i.name).join(', ');

        final saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: true,
          enableDrag: true,
          showDragHandle: false,
          builder: (ctx) {
            final h = MediaQuery.of(ctx).size.height;
            return SizedBox(
              height: h * 0.92,
              child: _useKF2
                  ? RecognitionResultSheetKF2(
                      dishName: summaryName,
                      ingredients: v2items,
                      mealDate: widget.mealDate,
                      originalText: text,
                    )
                  : RecognitionResultSheetV2(
                      dishName: summaryName,
                      ingredients: v2items,
                      mealDate: widget.mealDate,
                      originalText: text,
                    ),
            );
          },
        );

        if (saved == true && mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
    } catch (e) {
      _handleError(e);
      if (manageLoading && mounted) setState(() => _loadingType = _LoadingType.none);
      return;
    }
    if (manageLoading && mounted) setState(() => _loadingType = _LoadingType.none);
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.addMeal_mic_denied),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accentOver,
        action: status.isPermanentlyDenied
            ? SnackBarAction(
                label: AppLocalizations.of(context)!.addMeal_open_settings,
                textColor: Colors.white,
                onPressed: openAppSettings)
            : null,
      ));
      _switchMode(_InputMode.choose);
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/meal_voice.m4a';
    await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordPath!);
    _recordStart = DateTime.now();
    AnalyticsService.mealVoiceRecordStarted();
    if (mounted) setState(() => _isRecording = true);
  }

  Future<void> _stopRecordingAndTranscribe() async {
    await _recorder.stop();
    final dur = _recordStart != null
        ? DateTime.now().difference(_recordStart!).inSeconds
        : 0;
    AnalyticsService.mealVoiceRecordStopped(dur);
    setState(() {
      _isRecording = false;
      _loadingType = _LoadingType.voice;
    });
    try {
      final form = FormData.fromMap({
        'audio': await MultipartFile.fromFile(_recordPath!,
            filename: 'voice.m4a'),
      });
      final resp =
          await apiDio.post('/api/transcribe?language=$_lang', data: form);
      // Handle both {text: "..."} and plain string responses
      final raw = resp.data;
      final text = raw is Map
          ? (raw['text'] as String? ?? '')
          : (raw?.toString() ?? '');
      if (text.isNotEmpty) {
        await _parseText(text, _lang, manageLoading: false);
      } else if (mounted) {
        _switchMode(_InputMode.choose);
      }
    } catch (e) {
      _handleError(e);
      if (mounted) _switchMode(_InputMode.choose);
    } finally {
      if (mounted) setState(() => _loadingType = _LoadingType.none);
    }
  }

  Future<void> _pickAndRecognizePhoto(ImageSource source) async {
    if (mounted) setState(() => _loadingType = _LoadingType.photo);
    final picker = ImagePicker();
    final lang = _lang;
    // No imageQuality — compressWithList below is the single compression step.
    final file = await picker.pickImage(source: source);
    if (file == null) {
      if (mounted) setState(() => _loadingType = _LoadingType.none);
      if (mounted) _switchMode(_InputMode.choose);
      return;
    }
    if (source == ImageSource.gallery) {
      AnalyticsService.addMealPhotoFromGallery();
    } else {
      AnalyticsService.addMealPhotoTaken();
    }
    if (!mounted) return;
    try {
      // Read bytes into memory — avoids the OS-level file-path cache that
      // image_picker may reuse between captures (same temp path, new content).
      final originalBytes = await file.readAsBytes();
      if (!mounted) return;
      debugPrint('📸 Original photo: ${file.path} (${originalBytes.length ~/ 1024} KB)');

      // Force-convert any source format (PNG/HEIC/JPEG) to a JPEG that's
      // small enough for fast upload + AI processing on the server.
      final compressed = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 1280,
        minHeight: 1280,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      late final MultipartFile multipart;
      if (compressed.isNotEmpty) {
        debugPrint('📸 Compressed to ${compressed.length ~/ 1024} KB');
        multipart = MultipartFile.fromBytes(
          compressed,
          filename: 'photo.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        );
      } else {
        debugPrint('📸 Compression empty, sending original');
        multipart = MultipartFile.fromBytes(
          originalBytes,
          filename: 'photo.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        );
      }

      final form = FormData.fromMap({'image': multipart});
      final resp = await apiDio.post(
        '/api/v2/recognize_photo?language=$lang',
        data: form,
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      if (!mounted) return;
      debugPrint('📸 Recognize response status=${resp.statusCode} '
          'data=${resp.data}');
      final error = resp.data['error'] as String?;
      final rawItems = resp.data['items'] as List<dynamic>?;
      final isFood = resp.data['is_food'] as bool?;
      final notFoodReason = resp.data['not_food_reason'] as String?;
      if (error != null && error.isNotEmpty) {
        setState(() => _loadingType = _LoadingType.none);
        _handleError(Exception(error));
        return;
      }
      final isNotFood = isFood == false || notFoodReason == 'not_food';
      if (isNotFood || rawItems == null || rawItems.isEmpty) {
        if (mounted) setState(() => _loadingType = _LoadingType.none);
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.addMeal_not_food_message),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: l10n.addMeal_not_food_retry,
                onPressed: () => _pickAndRecognizePhoto(source),
              ),
            ),
          );
        }
        return;
      }
      if (rawItems.isNotEmpty) {
        final items = rawItems.map((e) => e as Map<String, dynamic>).toList();
        final v2items = items.map(ingredientV2FromJson).toList();

        final dishName = resp.data['dish_name'] as String? ??
            items
                .map((e) => (e['name'] as String?) ?? '')
                .where((n) => n.isNotEmpty)
                .join(', ');

        setState(() => _loadingType = _LoadingType.none);

        final saved = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: true,
          enableDrag: true,
          showDragHandle: false,
          builder: (ctx) {
            final h = MediaQuery.of(ctx).size.height;
            return SizedBox(
              height: h * 0.92,
              child: _useKF2
                  ? RecognitionResultSheetKF2(
                      dishName: dishName,
                      ingredients: v2items,
                      mealDate: widget.mealDate,
                      originalText: null,
                    )
                  : RecognitionResultSheetV2(
                      dishName: dishName,
                      ingredients: v2items,
                      mealDate: widget.mealDate,
                      originalText: null,
                    ),
            );
          },
        );

        if (saved == true && mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _loadingType = _LoadingType.none);
    }
  }

  void _handleError(Object e) {
    if (!mounted) return;
    const msg = 'Something went wrong. Please try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accentOver,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _lang = Localizations.localeOf(context).languageCode;
    final isRu = _lang == 'ru';

    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return KeyboardDismisser(
      child: FadeTransition(
        opacity: _sheetFade,
        child: SlideTransition(
          position: _sheetSlide,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    _DragHandle(),

                    // Header
                    _SheetHeader(
                      mode: _mode,
                      l10n: l10n,
                      onBack: _mode != _InputMode.choose
                          ? () => _switchMode(_InputMode.choose)
                          : null,
                    ),

                  // Content
                  FadeTransition(
                    opacity: _modeCtrl,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 20),
                        child: _mode == _InputMode.choose
                                ? _ChooseView(
                                    l10n: l10n,
                                    isRu: isRu,
                                    onText: () => _switchMode(_InputMode.text),
                                    onVoice: () async {
                                      final ok = await requireSubscription(
                                          context, ref);
                                      if (!ok || !mounted) return;
                                      _switchMode(_InputMode.voice);
                                      Future.delayed(
                                          const Duration(milliseconds: 350),
                                          _startRecording);
                                    },
                                    onPhoto: () async {
                                      final ok = await requireSubscription(
                                          context, ref);
                                      if (!ok || !mounted) return;
                                      if (_useKF2Recog) {
                                        // KF2 full-screen capture flow.
                                        // Use plain Navigator so the bottom-sheet
                                        // context is preserved on the back stack.
                                        final file =
                                            await Navigator.of(context).push<XFile?>(
                                          MaterialPageRoute<XFile?>(
                                            fullscreenDialog: true,
                                            builder: (_) =>
                                                const Kf2CaptureScreen(),
                                          ),
                                        );
                                        if (file == null || !mounted) return;
                                        // Kf2RecognizingScreen handles its own
                                        // pushReplacement to RecognitionResultSheetKF2
                                        // and pops with true on save.
                                        final saved =
                                            await Navigator.of(context).push<bool>(
                                          MaterialPageRoute<bool>(
                                            fullscreenDialog: true,
                                            builder: (_) =>
                                                Kf2RecognizingScreen(photo: file),
                                          ),
                                        );
                                        if (saved == true && mounted) {
                                          Navigator.of(context).pop();
                                        }
                                        return;
                                      }
                                      // Legacy flow ─────────────────────────
                                      final source =
                                          await showModalBottomSheet<ImageSource>(
                                        context: context,
                                        backgroundColor: Colors.transparent,
                                        isDismissible: true,
                                        enableDrag: true,
                                        showDragHandle: false,
                                        builder: (_) =>
                                            _PhotoSourceSheet(l10n: l10n),
                                      );
                                      if (source == null) return;
                                      await _switchMode(_InputMode.photo);
                                      if (!mounted) return;
                                      await _pickAndRecognizePhoto(source);
                                    },
                                    onBarcode: _openBarcodeScanner,
                                  )
                                : _mode == _InputMode.text
                                    ? _TextView(
                                        controller: _textController,
                                        focus: _textFocus,
                                        l10n: l10n,
                                        isRu: isRu,
                                        onParse: () async {
                                          AnalyticsService.addMealTextSubmitted(_textController.text.length);
                                          _parseText(_textController.text, _lang);
                                        },
                                      )
                                    : _mode == _InputMode.photo
                                        ? const SizedBox.shrink()
                                        : _VoiceView(
                                            isRecording: _isRecording,
                                            recordStart: _recordStart,
                                            l10n: l10n,
                                            onToggle: _isRecording
                                                ? _stopRecordingAndTranscribe
                                                : _startRecording,
                                          ),
                      ),
                    ),
                  ),
                ],
              ),

              // Loading overlays
              if (_loadingType == _LoadingType.voice ||
                  _loadingType == _LoadingType.photo)
                _RecognizingOverlay(type: _loadingType, l10n: l10n),
              if (_loadingType == _LoadingType.parsing)
                const _ParsingOverlay(),

              // Close button (X) in top-right corner
              if (_loadingType == _LoadingType.none)
                Positioned(
                  top: 8,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    iconSize: 20,
                    color: AppColors.textMuted,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drag handle
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet header
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final _InputMode mode;
  final AppLocalizations l10n;
  final VoidCallback? onBack;

  const _SheetHeader(
      {required this.mode, required this.l10n, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              l10n.addMeal_title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choose view — 3 big animated method cards
// ─────────────────────────────────────────────────────────────────────────────

class _ChooseView extends StatefulWidget {
  final AppLocalizations l10n;
  final bool isRu;
  final VoidCallback onText;
  final VoidCallback onVoice;
  final VoidCallback onPhoto;
  final VoidCallback onBarcode;

  const _ChooseView({
    required this.l10n,
    required this.isRu,
    required this.onText,
    required this.onVoice,
    required this.onPhoto,
    required this.onBarcode,
  });

  @override
  State<_ChooseView> createState() => _ChooseViewState();
}

class _ChooseViewState extends State<_ChooseView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _stagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final ru = widget.isRu;

    const unifiedGradient = [Color(0xFF059669), Color(0xFF34D399)];
    const unifiedShadow = Color(0xFF059669);
    const unifiedBg = Color(0xFFECFDF5);

    final methods = [
      _MethodData(
        icon: Icons.camera_alt_rounded,
        gradient: unifiedGradient,
        shadowColor: unifiedShadow,
        bgColor: unifiedBg,
        title: '📸 ${l10n.addMeal_photo}',
        desc: ru
            ? 'Сфотографируй — AI распознает состав за 5 сек'
            : 'Take a photo — AI identifies macros in 5 sec',
        onTap: widget.onPhoto,
      ),
      _MethodData(
        icon: Icons.mic_rounded,
        gradient: unifiedGradient,
        shadowColor: unifiedShadow,
        bgColor: unifiedBg,
        title: '🎙️ ${l10n.addMeal_voice}',
        desc: ru
            ? '«Съел борщ 300 мл» — просто скажи'
            : 'Say "I ate soup 300ml" — that\'s it',
        onTap: widget.onVoice,
      ),
      _MethodData(
        icon: Icons.edit_rounded,
        gradient: unifiedGradient,
        shadowColor: unifiedShadow,
        bgColor: unifiedBg,
        title: '✏️ ${l10n.addMeal_text}',
        desc: ru
            ? 'Напиши что съел — AI посчитает КБЖУ'
            : 'Describe your meal — AI counts macros',
        onTap: widget.onText,
      ),
      _MethodData(
        icon: Icons.qr_code_scanner_rounded,
        gradient: unifiedGradient,
        shadowColor: unifiedShadow,
        bgColor: unifiedBg,
        title: '📱 ${l10n.addMeal_barcode}',
        desc: l10n.addMeal_barcode_desc,
        onTap: widget.onBarcode,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: methods.asMap().entries.map((e) {
        final delay = e.key * 0.15;
        final fade = CurvedAnimation(
          parent: _stagger,
          curve: Interval(delay, delay + 0.5, curve: Curves.easeOutCubic),
        );
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _stagger,
          curve: Interval(delay, delay + 0.5, curve: Curves.easeOutCubic),
        ));
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: _MethodCard(data: e.value),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MethodData {
  final IconData icon;
  final List<Color> gradient;
  final Color shadowColor;
  final Color bgColor;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _MethodData({
    required this.icon,
    required this.gradient,
    required this.shadowColor,
    required this.bgColor,
    required this.title,
    required this.desc,
    required this.onTap,
  });
}

class _MethodCard extends StatefulWidget {
  final _MethodData data;
  const _MethodCard({required this.data});

  @override
  State<_MethodCard> createState() => _MethodCardState();
}

class _MethodCardState extends State<_MethodCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return ScaleTransition(
      scale: _pressCtrl,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.reverse(),
        onTapUp: (_) {
          _pressCtrl.forward();
          d.onTap();
        },
        onTapCancel: () => _pressCtrl.forward(),
        child: Container(
          decoration: BoxDecoration(
            color: d.bgColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: d.shadowColor.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Gradient icon badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient:
                        LinearGradient(colors: d.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: d.shadowColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(d.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        d.desc,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: d.gradient.first,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Voice view — animated recording UI
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceView extends StatefulWidget {
  final bool isRecording;
  final DateTime? recordStart;
  final AppLocalizations l10n;
  final VoidCallback onToggle;

  const _VoiceView({
    required this.isRecording,
    required this.recordStart,
    required this.l10n,
    required this.onToggle,
  });

  @override
  State<_VoiceView> createState() => _VoiceViewState();
}

class _VoiceViewState extends State<_VoiceView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _waveCtrl;
  late final AnimationController _timerCtrl;
  int _elapsed = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(() {
        if (widget.isRecording && widget.recordStart != null) {
          setState(() {
            _elapsed =
                DateTime.now().difference(widget.recordStart!).inSeconds;
          });
        }
      })
      ..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _timerCtrl.dispose();
    super.dispose();
  }

  String _formatTime(int s) =>
      '${(s ~/ 60).toString().padLeft(1, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final recording = widget.isRecording;
    final l10n = widget.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              recording ? l10n.addMeal_recording : l10n.addMeal_voice,
              key: ValueKey(recording),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: recording ? AppColors.accentOver : AppColors.textMuted,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Central mic button with ripple rings
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple rings (only when recording)
                if (recording) ...[
                  _RippleRing(ctrl: _pulseCtrl, delay: 0.0, maxRadius: 90, color: AppColors.accentOver),
                  _RippleRing(ctrl: _pulseCtrl, delay: 0.4, maxRadius: 90, color: AppColors.accentOver),
                  _RippleRing(ctrl: _pulseCtrl, delay: 0.8, maxRadius: 90, color: AppColors.accentOver),
                ] else ...[
                  _RippleRing(ctrl: _pulseCtrl, delay: 0.0, maxRadius: 90, color: AppColors.accent),
                  _RippleRing(ctrl: _pulseCtrl, delay: 0.5, maxRadius: 90, color: AppColors.accent),
                ],

                // Main button
                GestureDetector(
                  onTap: widget.onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    width: recording ? 88 : 80,
                    height: recording ? 88 : 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: recording
                            ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                            : [const Color(0xFF059669), const Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (recording ? AppColors.accentOver : AppColors.accent)
                              .withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      recording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Timer
          AnimatedOpacity(
            opacity: recording ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Text(
              _formatTime(_elapsed),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
                letterSpacing: 2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Waveform (only when recording)
          if (recording)
            AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) => _WaveformBars(t: _waveCtrl.value),
            ),

          const SizedBox(height: 8),

          Text(
            recording
                ? l10n.addMeal_voice_tap_stop
                : l10n.addMeal_voice_tap_start,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RippleRing extends StatelessWidget {
  final AnimationController ctrl;
  final double delay;
  final double maxRadius;
  final Color color;

  const _RippleRing({
    required this.ctrl,
    required this.delay,
    required this.maxRadius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ((ctrl.value + delay) % 1.0);
        final radius = maxRadius * t;
        final opacity = (1.0 - t) * 0.35;
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withValues(alpha: opacity),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

class _WaveformBars extends StatelessWidget {
  final double t;
  const _WaveformBars({required this.t});

  @override
  Widget build(BuildContext context) {
    const count = 24;
    return SizedBox(
      width: 200,
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(count, (i) {
          final phase = (i / count) * 2 * math.pi;
          final height = 4.0 +
              22.0 *
                  (0.5 +
                      0.5 *
                          math.sin(t * 2 * math.pi + phase) *
                          math.sin(i * 0.4));
          return Container(
            width: 3,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: AppColors.accentOver.withValues(alpha: 0.7 + 0.3 * (height / 26)),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text view
// ─────────────────────────────────────────────────────────────────────────────

class _TextView extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final AppLocalizations l10n;
  final bool isRu;
  final VoidCallback onParse;

  const _TextView({
    required this.controller,
    required this.focus,
    required this.l10n,
    required this.isRu,
    required this.onParse,
  });

  @override
  State<_TextView> createState() => _TextViewState();
}

class _TextViewState extends State<_TextView> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final ru = widget.isRu;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hint chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            ru ? 'Гречка 200г, курица 150г' : 'Oatmeal 200g, chicken 150g',
            ru ? 'Борщ 300мл, хлеб 2 куска' : 'Soup 300ml, 2 bread slices',
          ].map((hint) => GestureDetector(
            onTap: () {
              widget.controller.text = hint;
              widget.focus.requestFocus();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 13, color: AppColors.accent),
                const SizedBox(width: 5),
                Text(hint,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          )).toList(),
        ),

        const SizedBox(height: 14),

        // Text input
        Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focus,
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.addMeal_inputHint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(
                fontSize: 15, color: AppColors.text, height: 1.5),
          ),
        ),

        const SizedBox(height: 14),

        // Recognize button
        AnimatedOpacity(
          opacity: _hasText ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _hasText
                    ? const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF16A34A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [AppColors.border, AppColors.border]),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: _hasText
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  onTap: _hasText ? widget.onParse : null,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          l10n.addMeal_recognize_ai,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recognizing overlay (voice / photo)
// ─────────────────────────────────────────────────────────────────────────────

class _RecognizingOverlay extends StatefulWidget {
  final _LoadingType type;
  final AppLocalizations l10n;
  const _RecognizingOverlay({required this.type, required this.l10n});

  @override
  State<_RecognizingOverlay> createState() => _RecognizingOverlayState();
}

class _RecognizingOverlayState extends State<_RecognizingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVoice = widget.type == _LoadingType.voice;
    final label = isVoice
        ? widget.l10n.addMeal_recognizing_voice
        : widget.l10n.addMeal_recognizing_photo;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated icon in gradient circle
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final scale =
                  1.0 + 0.08 * math.sin(_ctrl.value * 2 * math.pi);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isVoice
                          ? [const Color(0xFF059669), const Color(0xFF10B981)]
                          : [const Color(0xFF7C3AED), const Color(0xFFA855F7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isVoice
                                ? AppColors.accent
                                : const Color(0xFF7C3AED))
                            .withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isVoice
                        ? Icons.graphic_eq_rounded
                        : Icons.camera_enhance_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.addMeal_ai_analyzing,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          // Animated dots
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i / 3.0;
                  final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
                  final scale = 0.5 + 0.5 * math.sin(t * math.pi);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isVoice
                              ? AppColors.accent
                              : const Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parsing overlay — Perplexity-style animated search steps
// ─────────────────────────────────────────────────────────────────────────────

class _ParsingOverlay extends StatefulWidget {
  const _ParsingOverlay();

  @override
  State<_ParsingOverlay> createState() => _ParsingOverlayState();
}

class _ParsingOverlayState extends State<_ParsingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotCtrl;
  Timer? _stepTimer;
  int _visibleSteps = 1;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _stepTimer = Timer.periodic(const Duration(milliseconds: 1600), (t) {
      if (!mounted) return;
      setState(() {
        if (_visibleSteps < 4) _visibleSteps++;
      });
    });
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      l10n.addMeal_parsing_step1,
      l10n.addMeal_parsing_step2,
      l10n.addMeal_parsing_step3,
      l10n.addMeal_parsing_step4,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                AnimatedBuilder(
                  animation: _dotCtrl,
                  builder: (_, __) {
                    final scale = 1.0 + 0.07 * math.sin(_dotCtrl.value * 2 * math.pi);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.manage_search_rounded, color: Colors.white, size: 26),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.addMeal_parsing_title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.addMeal_ai_analyzing,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Steps ──────────────────────────────────────────────
            ...List.generate(steps.length, (i) {
              final isVisible = i < _visibleSteps;
              final isCurrent = i == _visibleSteps - 1;
              final isDone = i < _visibleSteps - 1;

              return AnimatedOpacity(
                opacity: isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 450),
                child: AnimatedSlide(
                  offset: isVisible ? Offset.zero : const Offset(0, 0.25),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        // Icon: spinner for current, checkmark for done
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: isCurrent
                              ? AnimatedBuilder(
                                  animation: _dotCtrl,
                                  builder: (_, __) =>
                                      const CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.accent,
                                  ),
                                )
                              : Icon(
                                  isDone
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 22,
                                  color: isDone
                                      ? AppColors.accent
                                      : AppColors.border,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          steps[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isCurrent
                                ? AppColors.text
                                : isDone
                                    ? AppColors.textMuted
                                    : AppColors.border,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo source bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoSourceSheet extends StatelessWidget {
  final AppLocalizations l10n;
  const _PhotoSourceSheet({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            l10n.addMeal_photo,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _PhotoSourceBtn(
            icon: Icons.camera_alt_rounded,
            gradient: const [Color(0xFF7C3AED), Color(0xFFA855F7)],
            label: l10n.addMeal_takePhoto,
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 10),
          _PhotoSourceBtn(
            icon: Icons.photo_library_rounded,
            gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
            label: l10n.addMeal_choosePhoto,
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.common_cancel,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

class _PhotoSourceBtn extends StatefulWidget {
  final IconData icon;
  final List<Color> gradient;
  final String label;
  final VoidCallback onTap;

  const _PhotoSourceBtn({
    required this.icon,
    required this.gradient,
    required this.label,
    required this.onTap,
  });

  @override
  State<_PhotoSourceBtn> createState() => _PhotoSourceBtnState();
}

class _PhotoSourceBtnState extends State<_PhotoSourceBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _press,
      child: GestureDetector(
        onTapDown: (_) => _press.reverse(),
        onTapUp: (_) {
          _press.forward();
          widget.onTap();
        },
        onTapCancel: () => _press.forward(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: Colors.white, size: 22),
              const SizedBox(width: 14),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

