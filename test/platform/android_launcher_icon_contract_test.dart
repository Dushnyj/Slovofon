import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

String _resource(String path) => File('$_res/$path').readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('API 26+ resolves real adaptive layers, not a wrapped legacy bitmap', () {
    final adaptive = _resource('mipmap-anydpi-v26/ic_launcher.xml');
    expect(adaptive, contains('<adaptive-icon'));
    expect(
      adaptive,
      contains(
        '<background android:drawable="@drawable/ic_launcher_background"',
      ),
    );
    expect(
      adaptive,
      contains(
        '<foreground android:drawable="@drawable/ic_launcher_foreground"',
      ),
    );
    // An opaque circular bitmap used for monochrome would become a blank disc.
    expect(adaptive, isNot(contains('<monochrome')));
    final background = _resource('drawable/ic_launcher_background.xml');
    expect(background, contains('android:width="108dp"'));
    expect(background, contains('android:height="108dp"'));
    expect(background, contains('android:shape="rectangle"'));
    expect(background, contains('android:color="#071F32"'));
    expect(background, isNot(contains('@android:color/white')));
    final foreground = _resource('drawable/ic_launcher_foreground.xml');
    expect(foreground, contains('android:width="108dp"'));
    expect(foreground, contains('android:height="108dp"'));
    for (final side in ['Left', 'Top', 'Right', 'Bottom']) {
      expect(foreground, contains('android:inset$side="15%"'));
    }
    expect(foreground, contains('android:gravity="fill"'));
    expect(foreground, contains('android:src="@drawable/ic_launcher_emblem"'));
    expect(foreground, isNot(contains('@mipmap/ic_launcher')));
  });

  test('Android reuses approved full-resolution emblem without editing', () {
    final master = File('assets/app/slovofon_icon.png').readAsBytesSync();
    final emblem = File(
      '$_res/drawable-nodpi/ic_launcher_emblem.png',
    ).readAsBytesSync();
    expect(emblem, orderedEquals(master));
    // PNG IHDR is big endian and independent of platform image decoders.
    final header = emblem.buffer.asByteData();
    expect(header.getUint32(16), 1254);
    expect(header.getUint32(20), 1254);
  });

  test(
    'approved alpha geometry fits adaptive safe area without excess padding',
    () async {
      final codec = await ui.instantiateImageCodec(
        File('$_res/drawable-nodpi/ic_launcher_emblem.png').readAsBytesSync(),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var left = image.width;
        var right = -1;
        var top = image.height;
        var bottom = -1;
        var visibleGreenPixels = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final offset = (y * image.width + x) * 4;
            if (rgba.getUint8(offset + 3) <= 16) {
              continue;
            }
            if (x < left) {
              left = x;
            }
            if (x > right) {
              right = x;
            }
            if (y < top) {
              top = y;
            }
            if (y > bottom) {
              bottom = y;
            }
            // Transparent master RGB must not leak visible chroma-key green.
            final red = rgba.getUint8(offset);
            final green = rgba.getUint8(offset + 1);
            final blue = rgba.getUint8(offset + 2);
            if (green > 150 && green > red * 2 && green > blue * 2) {
              visibleGreenPixels++;
            }
          }
        }
        final scale = 108 * .70 / image.width;
        expect(visibleGreenPixels, 0);
        expect((right - left + 1) * scale, inInclusiveRange(64, 66));
        expect((bottom - top + 1) * scale, inInclusiveRange(64, 66));
        expect(16.2 + left * scale, greaterThanOrEqualTo(21));
        expect(16.2 + top * scale, greaterThanOrEqualTo(21));
        expect(16.2 + (right + 1) * scale, lessThanOrEqualTo(87));
        expect(16.2 + (bottom + 1) * scale, lessThanOrEqualTo(87));
      } finally {
        image.dispose();
        codec.dispose();
      }
    },
  );

  test('API 24-25 retain all existing legacy-density launcher fallbacks', () {
    for (final (density, size) in [
      ('mdpi', 48),
      ('hdpi', 72),
      ('xhdpi', 96),
      ('xxhdpi', 144),
      ('xxxhdpi', 192),
    ]) {
      final bytes = File(
        '$_res/mipmap-$density/ic_launcher.png',
      ).readAsBytesSync();
      final header = bytes.buffer.asByteData();
      expect(header.getUint32(16), size, reason: density);
      expect(header.getUint32(20), size, reason: density);
    }
  });
}
