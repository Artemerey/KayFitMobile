import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  final path = 'assets/icon/app_icon_1024.png';
  final icon = img.decodePng(File(path).readAsBytesSync());
  if (icon == null || icon.width != 1024 || icon.height != 1024) {
    throw StateError('Expected an existing 1024x1024 PNG master');
  }

  final source = img.Image.from(icon);
  var corrected = 0;
  for (var y = 0; y < icon.height; y++) {
    for (var x = 0; x < icon.width; x++) {
      final dxFromCenter = x - (icon.width - 1) / 2;
      final dyFromCenter = y - (icon.height - 1) / 2;
      if (dxFromCenter * dxFromCenter + dyFromCenter * dyFromCenter <
          570 * 570) {
        continue;
      }
      final pixel = source.getPixel(x, y);
      final maxChannel = [
        pixel.r,
        pixel.g,
        pixel.b,
      ].reduce((a, b) => a > b ? a : b);
      final minChannel = [
        pixel.r,
        pixel.g,
        pixel.b,
      ].reduce((a, b) => a < b ? a : b);
      if (pixel.r < 115 ||
          pixel.g < 155 ||
          pixel.b < 85 ||
          maxChannel - minChannel > 145) {
        continue;
      }

      var red = 0.0;
      var green = 0.0;
      var blue = 0.0;
      var count = 0;
      for (var radius = 2; radius <= 8 && count == 0; radius += 2) {
        for (var dy = -radius; dy <= radius; dy++) {
          for (var dx = -radius; dx <= radius; dx++) {
            if (dx.abs() != radius && dy.abs() != radius) continue;
            final sx = x + dx;
            final sy = y + dy;
            if (sx < 0 || sy < 0 || sx >= source.width || sy >= source.height) {
              continue;
            }
            final neighbour = source.getPixel(sx, sy);
            final neighbourMax = [
              neighbour.r,
              neighbour.g,
              neighbour.b,
            ].reduce((a, b) => a > b ? a : b);
            final neighbourMin = [
              neighbour.r,
              neighbour.g,
              neighbour.b,
            ].reduce((a, b) => a < b ? a : b);
            if (neighbour.r >= 115 &&
                neighbour.g >= 155 &&
                neighbour.b >= 85 &&
                neighbourMax - neighbourMin <= 145) {
              continue;
            }
            red += neighbour.r;
            green += neighbour.g;
            blue += neighbour.b;
            count++;
          }
        }
      }
      if (count == 0)
        throw StateError('No green neighbour for seam pixel $x,$y');
      icon.setPixelRgba(x, y, red ~/ count, green ~/ count, blue ~/ count, 255);
      corrected++;
    }
  }

  // The source also contained a baked rounded-square boundary whose remaining
  // low-contrast pixels become two bright arcs after iOS applies its own mask.
  // Extend the unobstructed inner green background through the outer band with
  // a feathered radial sample. The apple artwork is well inside this radius.
  final backgroundSource = img.Image.from(icon);
  final centerX = (icon.width - 1) / 2;
  final centerY = (icon.height - 1) / 2;
  for (var y = 0; y < icon.height; y++) {
    for (var x = 0; x < icon.width; x++) {
      final dx = x - centerX;
      final dy = y - centerY;
      final radius = math.sqrt(dx * dx + dy * dy);
      if (radius <= 490) continue;
      final sampleScale = 470 / radius;
      final sample = backgroundSource.getPixel(
        (centerX + dx * sampleScale).round(),
        (centerY + dy * sampleScale).round(),
      );
      final current = backgroundSource.getPixel(x, y);
      final t = ((radius - 490) / 60).clamp(0.0, 1.0);
      final eased = t * t * (3 - 2 * t);
      icon.setPixelRgba(
        x,
        y,
        (current.r * (1 - eased) + sample.r * eased).round(),
        (current.g * (1 - eased) + sample.g * eased).round(),
        (current.b * (1 - eased) + sample.b * eased).round(),
        255,
      );
    }
  }

  File(path).writeAsBytesSync(img.encodePng(icon, level: 9));
  stdout.writeln('Repaired $corrected master-icon seam pixels');
}
