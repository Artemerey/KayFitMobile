import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// XFile is re-exported by flutter_image_compress, no separate import needed.

import 'package:kayfit/core/api/api_client.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:kayfit/shared/models/ingredient_v2.dart';
import 'package:kayfit/shared/theme/kayfit2_theme.dart';
import 'package:kayfit/shared/utils/nutrient_parser.dart';
import 'recognition_result_sheet_kf2.dart';

/// KF2-RECOG: Full-screen recognizing screen.
///
/// Accepts the [XFile] captured by [Kf2CaptureScreen], uploads it to
/// `/api/v2/recognize_photo`, then:
/// - On success → [Navigator.pushReplacement] to [RecognitionResultSheetKF2]
///   as a full-screen modal (so the back stack remains clean).
/// - On error   → shows a [SnackBar] and pops back to the capture screen.
class Kf2RecognizingScreen extends ConsumerStatefulWidget {
  const Kf2RecognizingScreen({
    super.key,
    required this.photo,
    this.onSaved,
  });

  final XFile photo;
  /// Optional callback fired with the dish name when the user confirms saving.
  /// Use this to inject a coaching message in the chat without depending on
  /// the Navigator return type.
  final void Function(String dishName)? onSaved;

  @override
  ConsumerState<Kf2RecognizingScreen> createState() =>
      _Kf2RecognizingScreenState();
}

class _Kf2RecognizingScreenState extends ConsumerState<Kf2RecognizingScreen>
    with TickerProviderStateMixin {
  static const _theme = K2Theme.dark;

  late final AnimationController _dotCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Evict any cached version of this path so Image.file always shows
    // the freshly taken photo rather than a stale cached frame.
    PaintingBinding.instance.imageCache
        .evict(FileImage(File(widget.photo.path)));

    WidgetsBinding.instance.addPostFrameCallback((_) => _recognize());
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Recognition logic ──────────────────────────────────────────────────────

  Future<void> _recognize() async {
    final lang = Localizations.localeOf(context).languageCode;

    try {
      // Read bytes once for upload. Display uses Image.file directly,
      // with cache eviction in initState ensuring the fresh photo is shown.
      final originalBytes = await widget.photo.readAsBytes();
      if (!mounted) return;
      debugPrint('KF2-RECOG: original ${originalBytes.length ~/ 1024} KB  path=${widget.photo.path}');

      final compressed = await FlutterImageCompress.compressWithList(
        originalBytes,
        minWidth: 1280,
        minHeight: 1280,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      late final MultipartFile multipart;
      if (compressed.isNotEmpty) {
        debugPrint('KF2-RECOG: compressed to ${compressed.length ~/ 1024} KB');
        multipart = MultipartFile.fromBytes(
          compressed,
          filename: 'photo.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        );
      } else {
        debugPrint('KF2-RECOG: compression returned empty, sending original');
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

      final error = resp.data['error'] as String?;
      final rawItems = resp.data['items'] as List<dynamic>?;
      final isFood = resp.data['is_food'] as bool?;
      final notFoodReason = resp.data['not_food_reason'] as String?;

      if (error != null && error.isNotEmpty) {
        _handleError(error);
        return;
      }

      final isNotFood = isFood == false || notFoodReason == 'not_food';
      if (isNotFood || rawItems == null || rawItems.isEmpty) {
        _handleNotFood();
        return;
      }

      final items = rawItems.map((e) => e as Map<String, dynamic>).toList();
      final v2items = items.map(ingredientV2FromJson).toList();
      final dishName = resp.data['dish_name'] as String? ??
          items
              .map((e) => (e['name'] as String?) ?? '')
              .where((n) => n.isNotEmpty)
              .join(', ');

      if (!mounted) return;
      _pushResult(dishName, v2items);
    } on Exception catch (e) {
      _handleError(e.toString());
    }
  }

  void _pushResult(String dishName, List<IngredientV2> items) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    // Replace the recognizing screen so back-stack is:
    //   AddMealSheet (bottom sheet) → RecognitionResultSheetKF2
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.transparent,
          body: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 1.0,
            builder: (context, scrollController) => RecognitionResultSheetKF2(
              dishName: dishName,
              ingredients: items,
              mealDate: null,
              originalText: null,
              onSaved: widget.onSaved,
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotFood() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.addMeal_not_food_message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: AppLocalizations.of(context)!.addMeal_not_food_retry,
          onPressed: () {
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  void _handleError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Something went wrong. Please try again.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: K2Colors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.of(context).pop();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          children: [
            // ── Photo fills most of the screen ──────────────────────────────
            Expanded(
              child: _PhotoDisplay(
                photoPath: widget.photo.path,
                theme: t,
                pulseCtrl: _pulseCtrl,
                topPad: topPad,
              ),
            ),

            // ── Overlay status bar ────────────────────────────────────────
            _StatusBar(
              theme: t,
              dotCtrl: _dotCtrl,
              bottomPad: bottomPad,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo display ─────────────────────────────────────────────────────────────

class _PhotoDisplay extends StatelessWidget {
  const _PhotoDisplay({
    required this.photoPath,
    required this.theme,
    required this.pulseCtrl,
    required this.topPad,
  });

  final String photoPath;
  final K2Theme theme;
  final AnimationController pulseCtrl;
  final double topPad;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image.file renders immediately from the temp path.
        // Cache eviction in initState ensures the freshly taken photo is shown
        // rather than any stale frame from a previous capture at the same path.
        Image.file(
          File(photoPath),
          fit: BoxFit.cover,
          gaplessPlayback: false,
          errorBuilder: (context, error, stackTrace) => Container(
            color: theme.card,
            child: Icon(Icons.broken_image_outlined, color: theme.fgMute, size: 48),
          ),
        ),

        // Subtle dark overlay so UI elements read clearly
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.30),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),

        // Top label
        Positioned(
          top: topPad + 16,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'ANALYZING',
              style: TextStyle(
                fontFamily: K2Fonts.mono,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.4,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),

        // Pulsing scan line
        Positioned.fill(
          child: AnimatedBuilder(
            animation: pulseCtrl,
            builder: (context, child) {
              final y = 0.15 + 0.70 * pulseCtrl.value;
              return CustomPaint(
                painter: _ScanLinePainter(
                  y: y,
                  color: K2Colors.accent.withValues(alpha: 0.55),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter({required this.y, required this.color});

  final double y;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final dy = size.height * y;
    canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.y != y || old.color != color;
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.theme,
    required this.dotCtrl,
    required this.bottomPad,
  });

  final K2Theme theme;
  final AnimationController dotCtrl;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: t.surface,
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 20),
      child: Row(
        children: [
          // Animated accent dot ring
          _PulsingDot(ctrl: dotCtrl),
          const SizedBox(width: 16),

          // Text stack
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Analyzing your meal…',
                  style: TextStyle(
                    fontFamily: K2Fonts.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AI is identifying items',
                  style: TextStyle(
                    fontFamily: K2Fonts.mono,
                    fontSize: 11,
                    color: t.fgDim,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // Three-dot progress
          _ThreeDots(ctrl: dotCtrl),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.ctrl});

  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        final scale = 0.85 + 0.30 * math.sin(ctrl.value * 2 * math.pi);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: K2Colors.accent,
            ),
          ),
        );
      },
    );
  }
}

class _ThreeDots extends StatelessWidget {
  const _ThreeDots({required this.ctrl});

  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3.0;
            final t = ((ctrl.value - delay) % 1.0 + 1.0) % 1.0;
            final scale = 0.5 + 0.5 * math.sin(t * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: K2Colors.accent,
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
