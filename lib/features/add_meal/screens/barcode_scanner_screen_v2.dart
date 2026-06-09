import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kayfit/core/i18n/generated/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/models/ingredient_v2.dart';
import '../../../shared/models/nutrients_v2.dart';
import '../../../shared/theme/app_theme.dart';
import 'recognition_result_sheet_kf2.dart';

// ── State machine ─────────────────────────────────────────────────────────────

enum _ScanState { scanning, loading, error }

// ── Main screen ───────────────────────────────────────────────────────────────

class BarcodeScannerScreenV2 extends StatefulWidget {
  const BarcodeScannerScreenV2({super.key});

  @override
  State<BarcodeScannerScreenV2> createState() => _BarcodeScannerScreenV2State();
}

class _BarcodeScannerScreenV2State extends State<BarcodeScannerScreenV2>
    with TickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _laserCtrl;
  late final Animation<double> _laserAnim;

  _ScanState _state = _ScanState.scanning;
  String _errorText = '';
  bool _torchOn = false;

  static const double _frameSize = 260.0;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );

    _laserCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnim = CurvedAnimation(
      parent: _laserCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _laserCtrl.dispose();
    super.dispose();
  }

  // ── Barcode handling ───────────────────────────────────────────────────────

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_state != _ScanState.scanning) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    HapticFeedback.mediumImpact();
    await _lookupBarcode(code);
  }

  Future<void> _lookupBarcode(String code) async {
    setState(() => _state = _ScanState.loading);

    try {
      final lang = mounted
          ? Localizations.localeOf(context).languageCode
          : 'ru';
      final resp = await apiDio.get<Map<String, dynamic>>(
        '/api/barcode/$code',
        queryParameters: {'language': lang},
      );
      final data = resp.data;
      if (data == null) {
        throw Exception(mounted
            ? (Localizations.localeOf(context).languageCode == 'ru'
                ? 'Пустой ответ сервера'
                : 'Empty server response')
            : 'Empty server response');
      }

      if (data['error'] != null) {
        if (!mounted) return;
        setState(() {
          _state = _ScanState.error;
          _errorText = data['error'] as String;
        });
        return;
      }

      if (data['found'] != true) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _state = _ScanState.error;
          _errorText = l10n.barcode_not_found;
        });
        return;
      }

      // Parse barcode response — all values are per 100g
      double _d(String key) => (data[key] as num?)?.toDouble() ?? 0.0;
      double? _dn(String key) => (data[key] as num?)?.toDouble();

      final nutrients = NutrientsV2(
        calories: _d('calories'),
        protein: _d('protein'),
        fat: _d('fat'),
        carbs: _d('carbs'),
        fiber: _dn('fiber'),
        saturatedFat: _dn('saturated_fat'),
        sodiumMg: _dn('sodium'),
        potassiumMg: _dn('potassium'),
        cholesterolMg: _dn('cholesterol'),
        ironMg: _dn('iron'),
        calciumMg: _dn('calcium'),
        vitaminCMg: _dn('vitamin_c'),
        vitaminDMcg: _dn('vitamin_d'),
      );
      final productName = (data['name'] as String?)?.isNotEmpty == true
          ? data['name'] as String
          : (data['brand_name'] as String? ?? 'Product');
      final servingGrams = (data['serving_size'] as num?)?.toDouble() ?? 100.0;
      // Build a 100g base first, then scale to the actual serving size so that
      // nutrientsTotal reflects the real portion (not the per-100g values).
      final ingV2 = IngredientV2(
        name: productName,
        weightGrams: 100.0,
        nutrientsPer100g: nutrients,
        nutrientsTotal: nutrients,
        source: data['source'] as String? ?? 'barcode',
      ).withWeight(servingGrams);

      if (!mounted) return;

      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => RecognitionResultSheetKF2(
            dishName: productName,
            ingredients: [ingV2],
          ),
        ),
      );

      if (!mounted) return;
      if (saved == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _state = _ScanState.scanning);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final notFound = l10n.barcode_not_found;
      final msg = (e.response?.data is Map)
          ? ((e.response?.data as Map)['detail'] as String? ?? notFound)
          : notFound;
      setState(() {
        _state = _ScanState.error;
        _errorText = msg;
      });
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _state = _ScanState.error;
        _errorText = '${l10n.common_error}: $e';
      });
    }
  }

  // ── Manual entry ───────────────────────────────────────────────────────────

  Future<void> _showManualEntry() async {
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: _ManualEntrySheet(
          controller: ctrl,
          onSearch: (code) {
            Navigator.of(sheetCtx).pop();
            _lookupBarcode(code);
          },
        ),
      ),
    );
  }

  // ── Torch ──────────────────────────────────────────────────────────────────

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameCenterY = size.height / 2 - 40; // slightly above center

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera ─────────────────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),

          // ── Overlay ────────────────────────────────────────────────────────
          CustomPaint(
            painter: _OverlayPainter(
              frameSize: _frameSize,
              centerY: frameCenterY,
            ),
          ),

          // ── Corner brackets + laser ────────────────────────────────────────
          _ScanFrameDecor(
            frameSize: _frameSize,
            centerY: frameCenterY,
            showLaser: _state == _ScanState.scanning,
            laserAnim: _laserAnim,
          ),

          // ── Loading indicator inside frame ─────────────────────────────────
          if (_state == _ScanState.loading)
            Positioned(
              left: (size.width - _frameSize) / 2,
              top: frameCenterY - _frameSize / 2,
              width: _frameSize,
              height: _frameSize,
              child: const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    color: Color(0xFF38BDF8),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),

          // ── Top bar ────────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              torchOn: _torchOn,
              onBack: () => Navigator.of(context).pop(),
              onTorch: _toggleTorch,
            ),
          ),

          // ── Status text ────────────────────────────────────────────────────
          Positioned(
            top: frameCenterY + _frameSize / 2 + 24,
            left: 32,
            right: 32,
            child: _StatusText(
              state: _state,
              errorText: _errorText,
              onRetry: () => setState(() => _state = _ScanState.scanning),
            ),
          ),

          // ── Manual entry button ─────────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 32,
            left: 40,
            right: 40,
            child: _ManualEntryButton(onTap: _showManualEntry),
          ),
        ],
      ),
    );
  }
}

// ── Overlay painter ───────────────────────────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  final double frameSize;
  final double centerY;

  const _OverlayPainter({required this.frameSize, required this.centerY});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());

    // Dark fill
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xCC000000),
    );

    // Cut out the scan window
    final left = (size.width - frameSize) / 2;
    final top = centerY - frameSize / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, frameSize, frameSize),
        const Radius.circular(16),
      ),
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.frameSize != frameSize || old.centerY != centerY;
}

// ── Scan frame decoration (corners + laser) ───────────────────────────────────

class _ScanFrameDecor extends StatelessWidget {
  final double frameSize;
  final double centerY;
  final bool showLaser;
  final Animation<double> laserAnim;

  const _ScanFrameDecor({
    required this.frameSize,
    required this.centerY,
    required this.showLaser,
    required this.laserAnim,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final left = (screenWidth - frameSize) / 2;
    final top = centerY - frameSize / 2;

    return Stack(
      children: [
        // Corner brackets
        Positioned(
          left: left,
          top: top,
          child: CustomPaint(
            size: Size(frameSize, frameSize),
            painter: _CornerBracketsPainter(),
          ),
        ),

        // Laser line
        if (showLaser)
          AnimatedBuilder(
            animation: laserAnim,
            builder: (_, __) {
              final laserY = top + laserAnim.value * (frameSize - 2);
              return Positioned(
                left: left + 12,
                top: laserY,
                width: frameSize - 24,
                height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF38BDF8).withValues(alpha: 0.9),
                        const Color(0xFF38BDF8),
                        const Color(0xFF38BDF8).withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── Corner brackets painter ───────────────────────────────────────────────────

class _CornerBracketsPainter extends CustomPainter {
  static const double _len = 28.0;
  static const double _radius = 16.0;
  static const Color _color = Color(0xFF38BDF8);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(
        Offset(_radius, 0), Offset(_radius + _len, 0), paint);
    canvas.drawLine(
        Offset(0, _radius), Offset(0, _radius + _len), paint);
    canvas.drawArc(
        Rect.fromLTWH(0, 0, _radius * 2, _radius * 2),
        pi,
        pi / 2,
        false,
        paint);

    // Top-right
    canvas.drawLine(
        Offset(w - _radius - _len, 0), Offset(w - _radius, 0), paint);
    canvas.drawLine(
        Offset(w, _radius), Offset(w, _radius + _len), paint);
    canvas.drawArc(
        Rect.fromLTWH(w - _radius * 2, 0, _radius * 2, _radius * 2),
        pi * 1.5,
        pi / 2,
        false,
        paint);

    // Bottom-left
    canvas.drawLine(
        Offset(_radius, h), Offset(_radius + _len, h), paint);
    canvas.drawLine(
        Offset(0, h - _radius - _len), Offset(0, h - _radius), paint);
    canvas.drawArc(
        Rect.fromLTWH(0, h - _radius * 2, _radius * 2, _radius * 2),
        pi / 2,
        pi / 2,
        false,
        paint);

    // Bottom-right
    canvas.drawLine(
        Offset(w - _radius - _len, h), Offset(w - _radius, h), paint);
    canvas.drawLine(
        Offset(w, h - _radius - _len), Offset(w, h - _radius), paint);
    canvas.drawArc(
        Rect.fromLTWH(w - _radius * 2, h - _radius * 2, _radius * 2,
            _radius * 2),
        0,
        pi / 2,
        false,
        paint);
  }

  @override
  bool shouldRepaint(_CornerBracketsPainter old) => false;
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool torchOn;
  final VoidCallback onBack;
  final VoidCallback onTorch;

  const _TopBar({
    required this.torchOn,
    required this.onBack,
    required this.onTorch,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(8, topPad + 4, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.addMeal_barcode,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            onPressed: onTorch,
            icon: Icon(
              torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
              color: torchOn ? const Color(0xFF38BDF8) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status text ───────────────────────────────────────────────────────────────

class _StatusText extends StatelessWidget {
  final _ScanState state;
  final String errorText;
  final VoidCallback onRetry;

  const _StatusText({
    required this.state,
    required this.errorText,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (state) {
      _ScanState.scanning => Text(
          l10n.barcode_scan_hint,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      _ScanState.loading => Text(
          l10n.barcode_loading,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      _ScanState.error => Column(
          children: [
            Text(
              errorText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  l10n.common_retry,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
    };
  }
}

// ── Manual entry button ───────────────────────────────────────────────────────

class _ManualEntryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ManualEntryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: Text(
              AppLocalizations.of(context)!.barcode_manual_btn,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Manual entry sheet ────────────────────────────────────────────────────────

class _ManualEntrySheet extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String code) onSearch;

  const _ManualEntrySheet({
    required this.controller,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.barcode_manual_title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'EAN-8, EAN-13, UPC-A and other formats',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 20,
            decoration: InputDecoration(
              hintText: 'Example: 4607086562619',
              prefixIcon: const Icon(
                Icons.qr_code_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(
                    color: Color(0xFF0284C7), width: 2),
              ),
              filled: true,
              fillColor: AppColors.bg,
            ),
            onSubmitted: (v) {
              final trimmed = v.trim();
              if (trimmed.isNotEmpty) onSearch(trimmed);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                elevation: 0,
              ),
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) onSearch(trimmed);
              },
              child: Text(
                AppLocalizations.of(context)!.barcode_search_btn,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Math constant ─────────────────────────────────────────────────────────────

const double pi = 3.141592653589793;
