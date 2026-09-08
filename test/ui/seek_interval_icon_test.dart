import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/ui/components/seek_interval_icon.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  // Deliberately load no fonts: interval digits must be identical on every host,
  // including Flutter's Ahem test environment, RTL and enlarged user text.
  for (final dark in [true, false]) {
    for (final dpr in [1.0, 1.5, 2.0]) {
      testWidgets('seek vector raster dark=$dark dpr=$dpr', (tester) async {
        final theme = dark ? AppTheme.dark() : AppTheme.light();
        for (final size in [20.0, 24.0, 28.0, 32.0]) {
          final baseline = <bool, Uint8List>{};
          for (final textScale in [1.0, 3.0]) {
            final pair = <Uint8List>[];
            for (final forward in [false, true]) {
              await tester.pumpWidget(
                MaterialApp(
                  theme: theme,
                  home: MediaQuery(
                    data: MediaQueryData(
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: Center(
                      child: RepaintBoundary(
                        key: const ValueKey('seek-raster'),
                        child: SeekIntervalIcon(
                          forward: forward,
                          size: size,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('seek-raster')),
              );
              late Uint8List pixels;
              await tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: dpr);
                pixels = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!.buffer.asUint8List();
                image.dispose();
              });
              if (baseline.containsKey(forward)) {
                expect(pixels, orderedEquals(baseline[forward]!));
              } else {
                baseline[forward] = pixels;
              }
              pair.add(pixels);
              expect(tester.takeException(), isNull);
            }
            final width = (size * dpr).ceil();
            final factor = size / 24 * dpr;
            int regionInk(Uint8List bytes, Rect bounds) {
              var ink = 0;
              for (
                var y = (bounds.top * factor - .5).ceil();
                y < (bounds.bottom * factor - .5).ceil();
                y++
              ) {
                for (
                  var x = (bounds.left * factor - .5).ceil();
                  x < (bounds.right * factor - .5).ceil();
                  x++
                ) {
                  ink += bytes[(y * width + x) * 4 + 3];
                }
              }
              return ink;
            }

            // The filled wings protrude beyond the circle's outer radius
            // (9.2 + 1 stroke unit). Measure only that outer sector, comparing
            // directions to cancel the circular body's antialias fringe.
            // Rectangular head regions would also measure the internal arc.
            var leftWingInk = 0;
            var rightWingInk = 0;
            for (var y = 0; y < width; y++) {
              for (var x = 0; x < width; x++) {
                final point = Offset((x + .5) / factor, (y + .5) / factor);
                if (point.dy >= 7) continue;
                if ((point - const Offset(12, 12)).distance <= 10.2) {
                  continue;
                }
                final alpha = (y * width + x) * 4 + 3;
                if (point.dx < 8) {
                  leftWingInk += pair[0][alpha] - pair[1][alpha];
                } else if (point.dx > 16) {
                  rightWingInk += pair[1][alpha] - pair[0][alpha];
                }
              }
            }
            expect(leftWingInk, greaterThan(64));
            expect(rightWingInk, greaterThan(64));
            // Openings remain blank rather than becoming a closed reload ring.
            const leftGap = Rect.fromLTRB(1, 9, 5, 12);
            const rightGap = Rect.fromLTRB(19, 9, 23, 12);
            expect(regionInk(pair[0], leftGap), 0);
            expect(regionInk(pair[1], rightGap), 0);
            expect(regionInk(pair[0], rightGap), greaterThan(255));
            expect(regionInk(pair[1], leftGap), greaterThan(255));
            // The inner disk contains every numeral pixel, including its
            // antialias fringe; its upper cut excludes the arrowhead. Digits
            // are identical between directions, not mirrored with the arrow.
            for (var y = 0; y < width; y++) {
              for (var x = 0; x < width; x++) {
                final point = Offset((x + .5) / factor, (y + .5) / factor);
                if (point.dy < 7.2) continue;
                if ((point - const Offset(12, 12)).distance > 7.2) continue;
                final offset = (y * width + x) * 4;
                expect(
                  pair[0].sublist(offset, offset + 4),
                  pair[1].sublist(offset, offset + 4),
                  reason: 'entire interval size=$size dpr=$dpr x=$x y=$y',
                );
              }
            }
            expect(
              regionInk(pair[0], const Rect.fromLTRB(8, 10, 11, 17)),
              greaterThan(255),
            );
            expect(
              regionInk(pair[0], const Rect.fromLTRB(13, 10, 17, 17)),
              greaterThan(255),
            );
          }
          // Optional one-off integration proof against the actual user-approved
          // draft, before metadata-only additions to the checked-in assets.
          final approved = Platform.environment['SLOVOFON_SEEK_APPROVED_DIR'];
          if (size == 28 && approved != null && approved.isNotEmpty) {
            for (final forward in [false, true]) {
              final name = forward ? 'forward' : 'rewind';
              final draftPixels = await _approvedRaster(
                tester,
                theme,
                File('$approved/${name}_15.svg').readAsStringSync(),
                dpr,
              );
              expect(draftPixels, orderedEquals(baseline[forward]!));
            }
          }
        }
        await _renderProof(tester, theme, dark: dark, dpr: dpr);
      });
    }
  }
}

Future<Uint8List> _approvedRaster(
  WidgetTester tester,
  ThemeData theme,
  String source,
  double dpr,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey('approved-seek-raster'),
          child: SvgPicture.string(
            source,
            width: 28,
            height: 28,
            colorFilter: ColorFilter.mode(
              theme.colorScheme.onSurfaceVariant,
              BlendMode.srcIn,
            ),
            theme: SvgTheme(currentColor: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('approved-seek-raster')),
  );
  late Uint8List bytes;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: dpr);
    bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

Future<void> _renderProof(
  WidgetTester tester,
  ThemeData theme, {
  required bool dark,
  required double dpr,
}) async {
  final output = Platform.environment['SLOVOFON_SEEK_VISUAL_DIR'];
  if (output == null || output.isEmpty) return;
  expect(Directory(output).isAbsolute, isTrue);
  final colors = theme.colorScheme;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey('seek-proof'),
          child: ColoredBox(
            color: colors.surfaceContainerLow,
            child: SizedBox(
              width: 304,
              height: 320,
              child: Column(
                children: [
                  for (final size in [20.0, 24.0, 28.0, 32.0])
                    SizedBox(
                      height: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          AppIcon(
                            AppIconAssets.playerPreviousChapter,
                            size: 21,
                            color: colors.onSurfaceVariant,
                          ),
                          SeekIntervalIcon(
                            forward: false,
                            size: size,
                            color: colors.onSurfaceVariant,
                          ),
                          SizedBox.square(
                            dimension: 46,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: AppIcon(
                                  AppIconAssets.playerPlay,
                                  size: 28,
                                  color: colors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                          SeekIntervalIcon(
                            forward: true,
                            size: size,
                            color: colors.onSurfaceVariant,
                          ),
                          AppIcon(
                            AppIconAssets.playerNextChapter,
                            size: 21,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
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
    find.byKey(const ValueKey('seek-proof')),
  );
  await tester.runAsync(() async {
    await Directory(output).create(recursive: true);
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '$output/seek-${dark ? 'dark' : 'light'}-${dpr}x.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
