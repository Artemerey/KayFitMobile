import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kayfit/shared/theme/kayfit2_theme.dart';

/// KF2-RECOG: Capture screen.
///
/// Presents a minimal full-screen camera UI following the KF2 design language:
/// monochrome background, accent #007AFF, hairline borders.
///
/// Rather than a live camera preview (which would require the `camera` package),
/// tapping the shutter button triggers [ImagePicker] — the same approach used
/// by the legacy [AddMealSheet]. This keeps the permission surface small and
/// avoids adding new dependencies.
///
/// Returns an [XFile] via [Navigator.pop] on success, or [null] on cancel.
class Kf2CaptureScreen extends StatefulWidget {
  const Kf2CaptureScreen({super.key});

  @override
  State<Kf2CaptureScreen> createState() => _Kf2CaptureScreenState();
}

class _Kf2CaptureScreenState extends State<Kf2CaptureScreen>
    with SingleTickerProviderStateMixin {
  static const _theme = K2Theme.dark; // full-screen feels more native dark

  bool _picking = false;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Auto-trigger camera so the user doesn't need to tap the shutter.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _pick(ImageSource.camera),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    HapticFeedback.mediumImpact();
    setState(() => _picking = true);

    try {
      // No imageQuality here — compressWithList in Kf2RecognizingScreen is the
      // single compression step (avoids double-JPEG generation loss).
      final file = await ImagePicker().pickImage(source: source);
      debugPrint('KF2-CAPTURE: pickImage returned path=${file?.path}');
      if (!mounted) return;
      // Use `context.pop` (go_router) instead of `Navigator.of(context).pop`
      // so the value reliably propagates back to the `Future<XFile>` returned
      // by `context.push<XFile>('/kf2/capture')`. With go_router 14, mixing
      // the two `pop` APIs can silently swallow the result.
      context.pop(file);
    } on Exception catch (e) {
      debugPrint('KF2-CAPTURE: pickImage threw $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not access the camera. Please check permissions.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: K2Colors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        setState(() => _picking = false);
      }
    }
  }

  void _cancel() {
    HapticFeedback.selectionClick();
    context.pop(null);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: t.bg,
        body: Stack(
          children: [
            // ── Viewfinder area ──────────────────────────────────────────────
            Positioned.fill(
              child: _ViewfinderPlaceholder(
                theme: t,
                pulseCtrl: _pulseCtrl,
                picking: _picking,
              ),
            ),

            // ── Top bar ──────────────────────────────────────────────────────
            Positioned(
              top: topPadding,
              left: 0,
              right: 0,
              child: _TopBar(theme: t, onCancel: _cancel),
            ),

            // ── Bottom controls ───────────────────────────────────────────────
            Positioned(
              bottom: bottomPadding + 24,
              left: 0,
              right: 0,
              child: _BottomControls(
                theme: t,
                picking: _picking,
                onShutter: () => _pick(ImageSource.camera),
                onGallery: () => _pick(ImageSource.gallery),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Viewfinder placeholder ────────────────────────────────────────────────────

class _ViewfinderPlaceholder extends StatelessWidget {
  const _ViewfinderPlaceholder({
    required this.theme,
    required this.pulseCtrl,
    required this.picking,
  });

  final K2Theme theme;
  final AnimationController pulseCtrl;
  final bool picking;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: t.bg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Corner frame guides — top-left
          Positioned(
            top: MediaQuery.of(context).size.height * 0.18,
            left: 32,
            child: _CornerGuide(theme: t, corner: _Corner.topLeft),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.18,
            right: 32,
            child: _CornerGuide(theme: t, corner: _Corner.topRight),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25,
            left: 32,
            child: _CornerGuide(theme: t, corner: _Corner.bottomLeft),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25,
            right: 32,
            child: _CornerGuide(theme: t, corner: _Corner.bottomRight),
          ),

          // Center camera icon / loading
          if (picking)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: K2Colors.accent,
              ),
            )
          else
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (context, child) {
                final alpha = 0.25 + 0.20 * pulseCtrl.value;
                return Icon(
                  Icons.camera_alt_outlined,
                  size: 56,
                  color: t.fgMute.withValues(alpha: alpha),
                );
              },
            ),

          // Hint text
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25 + 48,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: picking ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'aim at your plate',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: K2Fonts.sans,
                      fontSize: 15,
                      color: t.fgDim,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TAP TO CAPTURE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: K2Fonts.mono,
                      fontSize: 11,
                      letterSpacing: 1.0,
                      color: t.fgMute,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Corner guide marks ────────────────────────────────────────────────────────

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerGuide extends StatelessWidget {
  const _CornerGuide({required this.theme, required this.corner});

  final K2Theme theme;
  final _Corner corner;

  @override
  Widget build(BuildContext context) {
    const len = 20.0;
    const thick = 2.0;
    final c = theme.fgMute;

    final flipH = corner == _Corner.topRight || corner == _Corner.bottomRight;
    final flipV = corner == _Corner.bottomLeft || corner == _Corner.bottomRight;

    return Transform.flip(
      flipX: flipH,
      flipY: flipV,
      child: SizedBox(
        width: len,
        height: len,
        child: CustomPaint(
          painter: _CornerPainter(color: c, length: len, thickness: thick),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.color,
    required this.length,
    required this.thickness,
  });

  final Color color;
  final double length;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    // Horizontal arm
    canvas.drawLine(Offset.zero, Offset(length, 0), paint);
    // Vertical arm
    canvas.drawLine(Offset.zero, Offset(0, length), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) =>
      old.color != color || old.length != length || old.thickness != thickness;
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.theme, required this.onCancel});

  final K2Theme theme;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // X button
          _IconCircleBtn(
            icon: Icons.close,
            theme: t,
            onTap: onCancel,
            semanticLabel: 'Cancel',
          ),

          // Label
          Text(
            'PHOTO',
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: t.fgDim,
            ),
          ),

          // Spacer to balance the X button
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ── Bottom controls ───────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.theme,
    required this.picking,
    required this.onShutter,
    required this.onGallery,
  });

  final K2Theme theme;
  final bool picking;
  final VoidCallback onShutter;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Gallery button
        Semantics(
          label: 'Choose from gallery',
          button: true,
          child: GestureDetector(
            onTap: picking ? null : onGallery,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: t.borderStrong, width: 1),
                borderRadius: BorderRadius.circular(12),
                color: t.card.withValues(alpha: 0.8),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: 20,
                color: picking ? t.fgMute : t.fgDim,
              ),
            ),
          ),
        ),

        // Shutter button — iOS-style white circle with inner ring
        Semantics(
          label: 'Take photo',
          button: true,
          child: GestureDetector(
            onTap: picking ? null : onShutter,
            child: AnimatedOpacity(
              opacity: picking ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: _ShutterButton(theme: t),
            ),
          ),
        ),

        // Placeholder to keep shutter centred
        const SizedBox(width: 44),
      ],
    );
  }
}

/// iOS-style shutter: outer white ring + inner filled circle.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    // In KF2 dark theme the camera shutter stays white (matches iOS camera)
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        color: Colors.transparent,
      ),
      padding: const EdgeInsets.all(5),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Reusable circle icon button ───────────────────────────────────────────────

class _IconCircleBtn extends StatelessWidget {
  const _IconCircleBtn({
    required this.icon,
    required this.theme,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final K2Theme theme;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.card.withValues(alpha: 0.7),
            border: Border.all(color: t.hairline, width: 0.5),
          ),
          child: Icon(icon, size: 18, color: t.fg),
        ),
      ),
    );
  }
}
