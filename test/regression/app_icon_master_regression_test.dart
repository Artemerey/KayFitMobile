import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('1024 app-icon master has no pale seam around its perimeter', () {
    final bytes = File('assets/icon/app_icon_1024.png').readAsBytesSync();
    final icon = img.decodePng(Uint8List.fromList(bytes));
    expect(icon, isNotNull);

    var brightPixels = 0;
    for (var y = 0; y < icon!.height; y++) {
      for (var x = 0; x < icon!.width; x++) {
        final dx = x - (icon.width - 1) / 2;
        final dy = y - (icon.height - 1) / 2;
        if (dx * dx + dy * dy < 570 * 570) continue;
        final pixel = icon.getPixel(x, y);
        final channels = [pixel.r, pixel.g, pixel.b];
        final spread =
            channels.reduce((a, b) => a > b ? a : b) -
            channels.reduce((a, b) => a < b ? a : b);
        if (pixel.r >= 115 &&
            pixel.g >= 155 &&
            pixel.b >= 85 &&
            spread <= 145) {
          brightPixels++;
        }
      }
    }

    expect(
      brightPixels,
      0,
      reason: 'iOS masks the master itself; baked seams become visible lines',
    );
  });
}
