import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('1024 app-icon master has no bright seams above the artwork', () {
    final bytes = File('assets/icon/app_icon_1024.png').readAsBytesSync();
    final icon = img.decodePng(Uint8List.fromList(bytes));
    expect(icon, isNotNull);

    var brightPixels = 0;
    for (var y = 0; y < 180; y++) {
      for (var x = 0; x < icon!.width; x++) {
        final pixel = icon.getPixel(x, y);
        if (pixel.r > 220 && pixel.g > 220 && pixel.b > 180) {
          brightPixels++;
        }
      }
    }

    expect(brightPixels, 0, reason: 'iOS masks the master itself; baked seams become visible lines');
  });
}
