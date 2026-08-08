import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final path = 'assets/icon/app_icon_1024.png';
  final icon = img.decodePng(File(path).readAsBytesSync());
  if (icon == null || icon.width != 1024 || icon.height != 1024) {
    throw StateError('Expected an existing 1024x1024 PNG master');
  }

  final source = img.Image.from(icon);
  var corrected = 0;
  for (var y = 0; y < 180; y++) {
    for (var x = 0; x < icon.width; x++) {
      final pixel = source.getPixel(x, y);
      if (pixel.r <= 220 || pixel.g <= 220 || pixel.b <= 180) continue;

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
            if (sx < 0 || sy < 0 || sx >= source.width || sy >= 180) continue;
            final neighbour = source.getPixel(sx, sy);
            if (neighbour.r > 220 && neighbour.g > 220 && neighbour.b > 180) {
              continue;
            }
            red += neighbour.r;
            green += neighbour.g;
            blue += neighbour.b;
            count++;
          }
        }
      }
      if (count == 0) throw StateError('No green neighbour for seam pixel $x,$y');
      icon.setPixelRgba(x, y, red ~/ count, green ~/ count, blue ~/ count, 255);
      corrected++;
    }
  }

  if (corrected != 91) {
    throw StateError('Expected to repair 91 seam pixels, found $corrected');
  }
  File(path).writeAsBytesSync(img.encodePng(icon, level: 9));
  stdout.writeln('Repaired $corrected master-icon seam pixels');
}
