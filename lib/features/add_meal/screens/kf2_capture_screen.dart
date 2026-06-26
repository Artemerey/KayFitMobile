import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kayfit/shared/theme/kayfit2_theme.dart';
import 'package:permission_handler/permission_handler.dart';

/// KF2-RECOG: Capture screen.
///
/// Presents a full-screen camera UI following the KF2 design language:
/// monochrome chrome, accent #007AFF, hairline viewfinder corners. A **live**
/// camera preview runs behind the corner guides so it is obvious that the
/// camera is active and the white shutter just needs a tap.
///
/// The shutter captures the frame via [CameraController.takePicture]; the
/// gallery button still uses [ImagePicker] (source: gallery). Either path
/// returns an [XFile] via `context.pop(file)` (go_router) — `null` on cancel.
/// Downstream (`photoRecognitionProvider` → `/kf2/result`) only ever receives
/// an [XFile], so the contract is unchanged.
class Kf2CaptureScreen extends StatefulWidget {
  const Kf2CaptureScreen({super.key});

  @override
  State<Kf2CaptureScreen> createState() => _Kf2CaptureScreenState();
}

/// Lifecycle of the live preview, driving what the viewfinder area renders.
enum _CamState { initializing, ready, denied, error }

class _Kf2CaptureScreenState extends State<Kf2CaptureScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _theme = K2Theme.dark; // full-screen feels more native dark

  CameraController? _controller;
  _CamState _camState = _CamState.initializing;

  /// True while a capture / gallery pick / pop is in flight — locks the
  /// controls so a double tap can't fire two captures or two pops.
  bool _busy = false;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _setupCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    // Release the camera so the preview doesn't leak / stay locked for other
    // screens. `dispose` is sync-safe even if initialize never completed.
    _controller?.dispose();
    super.dispose();
  }

  // ── Lifecycle (background / resume) ─────────────────────────────────────────

  /// The platform camera is torn down whenever the app is backgrounded, so the
  /// controller must be disposed and rebuilt — otherwise the preview comes back
  /// frozen on resume. We act on `paused`/`resumed` only (not the transient
  /// `inactive` that fires when the gallery picker or a permission dialog is
  /// shown), so opening the picker doesn't kill a healthy preview.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final controller = _controller;
      _controller = null;
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Only re-acquire if we previously had (or were trying for) the camera.
      // If the user had denied access, leave the denied UI in place.
      if (_camState != _CamState.denied && _controller == null) {
        _setupCamera();
      }
    }
  }

  // ── Camera setup ────────────────────────────────────────────────────────────

  /// Requests camera permission (a single dialog) and brings up the controller.
  ///
  /// permission_handler triggers the one iOS prompt; once granted,
  /// [CameraController.initialize] reuses that grant without a second dialog.
  Future<void> _setupCamera() async {
    if (mounted) setState(() => _camState = _CamState.initializing);

    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _camState = _CamState.denied);
      return;
    }

    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _camState = _CamState.error);
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _camState = _CamState.ready;
      });
    } on CameraException catch (e) {
      debugPrint('KF2-CAPTURE: camera init failed ${e.code} ${e.description}');
      if (mounted) setState(() => _camState = _CamState.error);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Captures the current frame from the live preview.
  ///
  /// The shutter is only enabled once [_camState] is `ready`, so the controller
  /// is guaranteed initialized — the historical "first photo does nothing,
  /// second works" race (permission grant vs. picker) cannot happen here: by
  /// the time the button is tappable the camera is already streaming.
  Future<void> _shutter() async {
    final controller = _controller;
    if (_busy ||
        _camState != _CamState.ready ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    try {
      final file = await controller.takePicture();
      debugPrint('KF2-CAPTURE: takePicture path=${file.path}');
      if (!mounted) return;
      // `context.pop` (go_router), NOT `Navigator.pop` — with go_router 14
      // mixing the two pop APIs silently swallows the `Future<XFile>` result
      // awaited by `context.push<XFile>('/kf2/capture')`.
      context.pop(file);
    } on CameraException catch (e) {
      debugPrint('KF2-CAPTURE: takePicture failed ${e.code} ${e.description}');
      if (mounted) {
        setState(() => _busy = false);
        _showError('Could not take the photo. Please try again.');
      }
    }
  }

  /// Opens the system gallery picker. Independent of the live preview.
  Future<void> _gallery() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);

    try {
      // No imageQuality here — compressWithList in Kf2RecognizingScreen is the
      // single compression step (avoids double-JPEG generation loss).
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      debugPrint('KF2-CAPTURE: gallery returned path=${file?.path}');
      if (!mounted) return;
      if (file == null) {
        // User backed out of the picker — stay on the capture screen.
        setState(() => _busy = false);
        return;
      }
      context.pop(file);
    } on Exception catch (e) {
      debugPrint('KF2-CAPTURE: gallery threw $e');
      if (mounted) {
        setState(() => _busy = false);
        _showError('Could not open the photo library.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: K2Colors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _cancel() {
    HapticFeedback.selectionClick();
    context.pop(null);
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;
    final ready = _camState == _CamState.ready;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: t.bg,
        body: Stack(
          children: [
            // ── Viewfinder: live preview, placeholder, or denied/error ───────
            Positioned.fill(
              child: _Viewfinder(
                theme: t,
                camState: _camState,
                controller: _controller,
                pulseCtrl: _pulseCtrl,
                busy: _busy,
                onOpenSettings: _openSettings,
              ),
            ),

            // ── Top bar ──────────────────────────────────────────────────────
            Positioned(
              top: topPadding,
              left: 0,
              right: 0,
              child: _TopBar(theme: t, onCancel: _cancel),
            ),

            // ── Bottom controls ──────────────────────────────────────────────
            Positioned(
              bottom: bottomPadding + 24,
              left: 0,
              right: 0,
              child: _BottomControls(
                theme: t,
                busy: _busy,
                shutterEnabled: ready && !_busy,
                onShutter: _shutter,
                onGallery: _gallery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Viewfinder ────────────────────────────────────────────────────────────────

/// The full-bleed viewfinder. Renders the live [CameraPreview] (cover-fitted)
/// behind the corner guides when ready; otherwise a placeholder / denied state.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.theme,
    required this.camState,
    required this.controller,
    required this.pulseCtrl,
    required this.busy,
    required this.onOpenSettings,
  });

  final K2Theme theme;
  final _CamState camState;
  final CameraController? controller;
  final AnimationController pulseCtrl;
  final bool busy;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final size = MediaQuery.of(context).size;

    return Container(
      color: t.bg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Live preview as the background layer.
          if (camState == _CamState.ready && controller != null)
            Positioned.fill(child: _CoverPreview(controller: controller!)),

          // Corner frame guides — always visible to anchor the viewfinder.
          Positioned(
            top: size.height * 0.18,
            left: 32,
            child: _CornerGuide(theme: t, corner: _Corner.topLeft),
          ),
          Positioned(
            top: size.height * 0.18,
            right: 32,
            child: _CornerGuide(theme: t, corner: _Corner.topRight),
          ),
          Positioned(
            bottom: size.height * 0.25,
            left: 32,
            child: _CornerGuide(theme: t, corner: _Corner.bottomLeft),
          ),
          Positioned(
            bottom: size.height * 0.25,
            right: 32,
            child: _CornerGuide(theme: t, corner: _Corner.bottomRight),
          ),

          // State-specific center content.
          switch (camState) {
            _CamState.ready => const SizedBox.shrink(),
            _CamState.initializing => _CenterPulse(
              theme: t,
              pulseCtrl: pulseCtrl,
            ),
            _CamState.denied => _DeniedNotice(
              theme: t,
              onOpenSettings: onOpenSettings,
            ),
            _CamState.error => _ErrorNotice(theme: t),
          },

          // Capture-in-flight spinner (over the live preview).
          if (busy && camState == _CamState.ready)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: K2Colors.accent,
              ),
            ),

          // Hint text — only meaningful while we have a live preview.
          if (camState == _CamState.ready)
            Positioned(
              bottom: size.height * 0.25 + 48,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: busy ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: _HintText(theme: t),
              ),
            ),
        ],
      ),
    );
  }
}

/// Cover-fits the camera preview to fill the screen in portrait. The platform
/// reports `previewSize` in landscape coordinates, so width/height are swapped.
class _CoverPreview extends StatelessWidget {
  const _CoverPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;
    if (preview == null) {
      return CameraPreview(controller);
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: preview.height,
          height: preview.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// Pulsing camera glyph shown while the controller is coming up.
class _CenterPulse extends StatelessWidget {
  const _CenterPulse({required this.theme, required this.pulseCtrl});

  final K2Theme theme;
  final AnimationController pulseCtrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (context, child) {
        final alpha = 0.25 + 0.20 * pulseCtrl.value;
        return Icon(
          Icons.camera_alt_outlined,
          size: 56,
          color: theme.fgMute.withValues(alpha: alpha),
        );
      },
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
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
    );
  }
}

/// Shown when camera permission is denied. Gallery stays available in the
/// bottom bar, so this is informational + a shortcut into Settings.
class _DeniedNotice extends StatelessWidget {
  const _DeniedNotice({required this.theme, required this.onOpenSettings});

  final K2Theme theme;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined, size: 48, color: t.fgMute),
          const SizedBox(height: 16),
          Text(
            'Camera access is off',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: t.fg,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enable the camera to take a photo, or pick one from your gallery '
            'below.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 14,
              height: 1.4,
              color: t.fgDim,
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onOpenSettings,
            style: TextButton.styleFrom(
              foregroundColor: K2Colors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'Open Settings',
              style: TextStyle(
                fontFamily: K2Fonts.sans,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the camera hardware can't be brought up at all. Gallery remains.
class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.theme});

  final K2Theme theme;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: t.fgMute),
          const SizedBox(height: 16),
          Text(
            'Camera unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: t.fg,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a photo from your gallery below instead.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: K2Fonts.sans,
              fontSize: 14,
              height: 1.4,
              color: t.fgDim,
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
    required this.busy,
    required this.shutterEnabled,
    required this.onShutter,
    required this.onGallery,
  });

  final K2Theme theme;
  final bool busy;
  final bool shutterEnabled;
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
            onTap: busy ? null : onGallery,
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
                color: busy ? t.fgMute : t.fgDim,
              ),
            ),
          ),
        ),

        // Shutter button — iOS-style white circle with inner ring
        Semantics(
          label: 'Take photo',
          button: true,
          child: GestureDetector(
            onTap: shutterEnabled ? onShutter : null,
            child: AnimatedOpacity(
              opacity: shutterEnabled ? 1.0 : 0.4,
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
