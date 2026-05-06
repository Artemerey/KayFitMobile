// KF2-FOUND-4 — Meal photo placeholder widget for Kayfit 2.0.
//
// Renders a deterministic striped greyscale tile that represents a real food
// photo before one has been taken/loaded. The stripe pattern is keyed to a
// numeric seed so every meal entry keeps a stable appearance across rebuilds.
//
// Three stripe variants (seed % 3):
//   0 — 135° dark charcoal
//   1 — 45°  warm brown-grey
//   2 — 90°  neutral grey

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kayfit2_theme.dart';

/// Meal photo widget used in [Kayfit2MealRow].
///
/// When [photoUrl] is provided, renders a network image with a skeleton
/// loading state and a graceful fallback to the striped placeholder on error.
/// When [photoUrl] is null, renders the deterministic striped placeholder
/// keyed to [seed].
///
/// The stripe pattern is stable across list rebuilds and hot reloads.
class Kayfit2MealPhoto extends StatelessWidget {
  const Kayfit2MealPhoto({
    super.key,
    this.seed,
    required this.theme,
    this.photoUrl,
    this.size = 56,
  });

  /// Integer seed that drives the stripe variant. Used only when [photoUrl]
  /// is null. Required when there is no real image to fall back on.
  final int? seed;

  /// Real network photo URL. When provided, renders [Image.network] with a
  /// graceful fallback to the striped placeholder on error.
  final String? photoUrl;

  /// Kayfit 2.0 design token bundle.
  final K2Theme theme;

  /// Width and height of the square thumbnail. Defaults to 56 pt (spec).
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: photoUrl != null
            ? Image.network(
                photoUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return _buildPlaceholder();
                },
                errorBuilder: (ctx, error, stack) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final variant = (seed ?? 0) % 3;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _stripeGradient(variant),
        border: Border.all(
          color: theme.border,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Icon(
          Icons.camera_alt_outlined,
          size: 14,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Returns the deterministic stripe gradient for [variant] in [0, 2].
  static LinearGradient _stripeGradient(int variant) {
    // Each stripe is 6 pt wide, alternating two shades, tiled via stops.
    // Flutter LinearGradient doesn't support CSS `repeating-linear-gradient`
    // natively, so we approximate with eight stops covering 0..1 at a
    // normalised tile size that matches a 56 pt canvas (12 pt tile → ~21%).
    //
    // The gradient is defined relative to the widget size; the visual stripe
    // width will shift with [size] but the design intent (a textured surface
    // distinguishable from a solid background) is preserved at any size.

    return switch (variant) {
      0 => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight, // 135°
          colors: [
            Color(0xFF4A4A4A), Color(0xFF4A4A4A),
            Color(0xFF5E5E5E), Color(0xFF5E5E5E),
            Color(0xFF4A4A4A), Color(0xFF4A4A4A),
            Color(0xFF5E5E5E), Color(0xFF5E5E5E),
          ],
          stops: [0.0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1.0],
        ),
      1 => const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight, // 45°
          colors: [
            Color(0xFF6B6258), Color(0xFF6B6258),
            Color(0xFF7D7368), Color(0xFF7D7368),
            Color(0xFF6B6258), Color(0xFF6B6258),
            Color(0xFF7D7368), Color(0xFF7D7368),
          ],
          stops: [0.0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1.0],
        ),
      _ => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight, // 90°
          colors: [
            Color(0xFF5A5550), Color(0xFF5A5550),
            Color(0xFF6B655E), Color(0xFF6B655E),
            Color(0xFF5A5550), Color(0xFF5A5550),
            Color(0xFF6B655E), Color(0xFF6B655E),
          ],
          stops: [0.0, 0.25, 0.25, 0.5, 0.5, 0.75, 0.75, 1.0],
        ),
    };
  }
}

/// Custom-paint version of the striped gradient — renders true hairline-sharp
/// diagonal stripes via [Canvas.drawLine] for the 135° and 45° variants.
///
/// Used internally; prefer [Kayfit2MealPhoto] for the full widget.
class MealPhotoStripePainter extends CustomPainter {
  const MealPhotoStripePainter({required this.variant});

  /// 0 = 135°, 1 = 45°, 2 = 90°
  final int variant;

  static const _stripeWidth = 6.0;

  static const _pairs = [
    [Color(0xFF4A4A4A), Color(0xFF5E5E5E)], // variant 0
    [Color(0xFF6B6258), Color(0xFF7D7368)], // variant 1
    [Color(0xFF5A5550), Color(0xFF6B655E)], // variant 2
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _pairs[variant % 3];
    final paint0 = Paint()..color = colors[0];
    final paint1 = Paint()..color = colors[1];

    if (variant % 3 == 2) {
      // 90° — vertical stripes
      var x = 0.0;
      var toggle = false;
      while (x < size.width) {
        final rect = Rect.fromLTWH(x, 0, _stripeWidth, size.height);
        canvas.drawRect(rect, toggle ? paint1 : paint0);
        x += _stripeWidth;
        toggle = !toggle;
      }
    } else {
      // diagonal stripes (135° or 45°)
      final angle = variant % 3 == 0
          ? (3 * math.pi / 4) // 135°
          : math.pi / 4; // 45°
      final diag = math.sqrt(size.width * size.width + size.height * size.height);
      final dx = math.cos(angle) * _stripeWidth;
      final dy = math.sin(angle) * _stripeWidth;
      final perpX = -dy;
      final perpY = dx;

      var i = -diag ~/ _stripeWidth;
      while (i * _stripeWidth < diag * 2) {
        final off = i * _stripeWidth;
        final cx = size.width / 2 + perpX * off / _stripeWidth;
        final cy = size.height / 2 + perpY * off / _stripeWidth;
        final paint = i.isEven ? paint0 : paint1;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: diag * 2,
            height: _stripeWidth,
          ),
          paint,
        );
        i++;
      }
    }
  }

  @override
  bool shouldRepaint(MealPhotoStripePainter old) => old.variant != variant;
}
