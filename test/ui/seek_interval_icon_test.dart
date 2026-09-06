import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/ui/components/seek_interval_icon.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  setUpAll(() async {
    // Real installed Windows glyphs for optional 1:1 render inspection.
    final file = File(r'C:\Windows\Fonts\seguisb.ttf');
    if (await file.exists()) {
      final loader = FontLoader('Segoe UI');
      loader.addFont(file.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });

  for (final dark in [true, false]) {
    for (final dpr in [1.0, 1.5, 2.0]) {
      testWidgets('seek artwork dark=$dark dpr=$dpr', (tester) async {
        final theme = WindowsTheme.from(
          dark
              ? AppTheme.dark(accent: const Color(0xff9c27b0))
              : AppTheme.light(accent: const Color(0xff9c27b0)),
        ).copyWith(platform: TargetPlatform.windows);
        final schemes = theme.colorScheme;
        final baseline = <bool, List<int>>{};
        for (final scale in [.75, 1.0, 2.0, 3.0]) {
          final bitmaps = <ByteData>[];
          for (final forward in [false, true]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: IconTheme(
                    data: IconThemeData(color: schemes.onSurfaceVariant),
                    child: Center(
                      child: RepaintBoundary(
                        key: const ValueKey('artwork'),
                        child: SeekIntervalIcon(forward: forward),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.getSize(find.byType(SeekIntervalIcon)),
              const Size(24, 24),
            );
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('artwork')),
            );
            await tester.runAsync(() async {
              final rendered = await boundary.toImage(pixelRatio: dpr);
              bitmaps.add(
                (await rendered.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!,
              );
              rendered.dispose();
            });
            final pixels = bitmaps.last.buffer.asUint8List();
            if (baseline.containsKey(forward)) {
              expect(pixels, orderedEquals(baseline[forward]!));
            } else {
              baseline[forward] = pixels.toList();
            }
            expect(tester.takeException(), isNull);
          }
          // Only the arrow changes direction. The numeral area stays identical,
          // contains actual ink, and is not mirrored or crossed by the arrow.
          var ink = 0;
          final width = (24 * dpr).ceil();
          for (var y = (10 * dpr).ceil(); y < (17 * dpr).floor(); y++) {
            for (var x = (7 * dpr).ceil(); x < (17 * dpr).floor(); x++) {
              final offset = (y * width + x) * 4;
              expect(
                bitmaps[0].getUint32(offset),
                bitmaps[1].getUint32(offset),
              );
              if (bitmaps[0].getUint8(offset + 3) > 0) ink++;
            }
          }
          expect(ink, greaterThan(10));
          // The rewind body must approach its left-pointing head from the
          // RIGHT. Reversing this arc puts the body in front of the tip and
          // makes the head look detached / point back into its own curve.
          int regionInk(
            ByteData bitmap,
            int left,
            int top,
            int right,
            int bottom,
          ) {
            var alpha = 0;
            for (var y = (top * dpr).ceil(); y < (bottom * dpr).floor(); y++) {
              for (
                var x = (left * dpr).ceil();
                x < (right * dpr).floor();
                x++
              ) {
                alpha += bitmap.getUint8((y * width + x) * 4 + 3);
              }
            }
            return alpha;
          }

          expect(regionInk(bitmaps[0], 4, 7, 7, 10), 0);
          expect(regionInk(bitmaps[0], 17, 7, 20, 10), greaterThan(0));
          expect(regionInk(bitmaps[1], 4, 7, 7, 10), greaterThan(0));
          expect(regionInk(bitmaps[1], 17, 7, 20, 10), 0);
          // The head faces along the endpoint tangent: left for rewind,
          // right for forward, not merely a reflected curved body.
          expect(regionInk(bitmaps[0], 14, 2, 16, 4), greaterThan(0));
          expect(regionInk(bitmaps[0], 8, 2, 10, 4), 0);
          expect(regionInk(bitmaps[1], 14, 2, 16, 4), 0);
          expect(regionInk(bitmaps[1], 8, 2, 10, 4), greaterThan(0));
        }

        final output = Platform.environment['SLOVOFON_SEEK_VISUAL_DIR'];
        if (output == null || output.isEmpty) return;
        expect(Directory(output).isAbsolute, isTrue);
        await tester.runAsync(() => Directory(output).create(recursive: true));
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Center(
              child: RepaintBoundary(
                key: const ValueKey('strip'),
                child: ColoredBox(
                  color: schemes.surfaceContainerLow,
                  child: SizedBox(
                    width: 240,
                    height: 72,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          child: AppIcon(
                            AppIconAssets.playerPreviousChapter,
                            size: 21,
                            color: schemes.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: SeekIntervalIcon(
                              forward: false,
                              color: schemes.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox.square(
                          dimension: 46,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: schemes.primary,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: AppIcon(
                                AppIconAssets.playerPlay,
                                size: 28,
                                color: schemes.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Center(
                            child: SeekIntervalIcon(
                              forward: true,
                              color: schemes.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: AppIcon(
                            AppIconAssets.playerNextChapter,
                            size: 21,
                            color: schemes.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('strip')),
        );
        await tester.runAsync(() async {
          for (final ratio in [dpr, if (dpr == 1) 4.0]) {
            final rendered = await boundary.toImage(pixelRatio: ratio);
            final bytes = (await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File(
              '$output/seek-${dark ? 'dark' : 'light'}-${ratio}x.png',
            ).writeAsBytes(bytes.buffer.asUint8List());
            rendered.dispose();
          }
        });
      });
    }
  }

  testWidgets('seek painter repaints direction and color only', (tester) async {
    Future<CustomPainter> painter(bool forward, Color color) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SeekIntervalIcon(forward: forward, color: color),
          ),
        ),
      );
      return tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byType(SeekIntervalIcon),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
    }

    final first = await painter(false, const Color(0xff112233));
    final same = await painter(false, const Color(0xff112233));
    expect(same.shouldRepaint(first), isFalse);
    expect(
      (await painter(true, const Color(0xff112233))).shouldRepaint(first),
      isTrue,
    );
    expect(
      (await painter(false, const Color(0xffaabbcc))).shouldRepaint(first),
      isTrue,
    );
  });
}
