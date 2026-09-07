import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/ui/components/seek_interval_icon.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  test('seek vectors keep upright digits and a single reflected arrow', () {
    final rewind = File(AppIconAssets.playerRewind15).readAsStringSync();
    final forward = File(AppIconAssets.playerForward15).readAsStringSync();
    String element(String source, String id) =>
        RegExp('<path id="$id"[^>]+>').firstMatch(source)!.group(0)!;
    String data(String element) =>
        RegExp(r' d="([^"]+)"').firstMatch(element)!.group(1)!;
    for (final source in [rewind, forward]) {
      expect(source, contains('viewBox="0 0 24 24"'));
      expect(source, contains('Source: Slovofon original seek artwork'));
      expect(source, contains('stroke="currentColor"'));
      expect(source, contains('stroke-linecap="round"'));
      expect(RegExp('<path ').allMatches(source), hasLength(2));
      expect(source, isNot(contains('<text')));
      expect(source, isNot(contains('<image')));
      expect(source, isNot(contains('font-')));
      expect(source, isNot(contains('<g')));
      expect(element(source, 'interval'), isNot(contains('transform')));
      expect(element(source, 'interval'), contains('stroke-width="1.4"'));
      expect(element(source, 'arrow'), contains('stroke-width="1.8"'));
    }
    expect(element(rewind, 'interval'), element(forward, 'interval'));
    final rewindArrow = element(rewind, 'arrow');
    final forwardArrow = element(forward, 'arrow');
    expect(data(rewindArrow), data(forwardArrow));
    expect(rewindArrow, isNot(contains('transform')));
    expect(forwardArrow, contains('transform="translate(24 0) scale(-1 1)"'));
    // A 300-degree counter-clockwise arc, with its opening on the left and a
    // tangential head pointing down-left. Reflect only this path for forward.
    expect(
      data(rewindArrow),
      'M3.1135 14.3811A9.2 9.2 0 1 0 5.4946 5.4946'
      'M6.2 2L5.4946 5.4946L9 4.8',
    );
    expect(
      data(element(rewind, 'interval')),
      'M8.5 11L9.8 9.5V16.5M8.7 16.5H10.9'
      'M16.2 9.5H12.8V12.5H14.2'
      'C17.4 12.5 17.4 16.5 14.2 16.5H12.8',
    );
    const tip = Offset(5.4946, 5.4946);
    const wingMiddle = Offset((6.2 + 9) / 2, (2 + 4.8) / 2);
    final heading = tip - wingMiddle;
    expect(heading.dx, isNegative);
    expect(heading.dy, isPositive);
    expect(heading.dx.abs(), closeTo(heading.dy.abs(), .02));
    // Numerals are 7 dp tall and centred at y=13. Test their full geometry,
    // including the curved bowl of 5, against the inner edge of the circle.
    // Subtract both stroke half-widths: centreline distance alone is not enough.
    const center = Offset(12, 12);
    const innerArcRadius = 9.2 - 1.8 / 2;
    const digitStrokeRadius = 1.4 / 2;
    final digitPoints = <Offset>[
      const Offset(8.5, 11),
      const Offset(9.8, 9.5),
      const Offset(9.8, 16.5),
      const Offset(8.7, 16.5),
      const Offset(10.9, 16.5),
      const Offset(16.2, 9.5),
      const Offset(12.8, 9.5),
      const Offset(12.8, 12.5),
      const Offset(14.2, 12.5),
      const Offset(14.2, 16.5),
      const Offset(12.8, 16.5),
      for (var index = 0; index <= 100; index++) _cubicPoint(index / 100),
    ];
    for (final point in digitPoints) {
      final clearance =
          innerArcRadius - (point - center).distance - digitStrokeRadius;
      expect(clearance, greaterThanOrEqualTo(2), reason: '$point');
    }
    expect(16.5 - 9.5, 7);
    expect((16.5 + 9.5) / 2, 13);
    expect(12 - 9.2 - 1.8 / 2, greaterThanOrEqualTo(1.8));
  });

  for (final forward in [false, true]) {
    for (final size in [24.0, 28.0, 32.0]) {
      testWidgets(
        'shared vector forward=$forward size=$size ignores RTL/text',
        (tester) async {
          const color = Color(0xff456789);
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(3)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Center(
                    child: SeekIntervalIcon(
                      forward: forward,
                      size: size,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final asset = tester.widget<AppIcon>(
            find.descendant(
              of: find.byType(SeekIntervalIcon),
              matching: find.byType(AppIcon),
            ),
          );
          expect(
            tester.getSize(find.byType(SeekIntervalIcon)),
            Size.square(size),
          );
          expect(
            asset.asset,
            forward
                ? AppIconAssets.playerForward15
                : AppIconAssets.playerRewind15,
          );
          expect(asset.color, color);
          expect(asset.matchTextDirection, isFalse);
          expect(
            find.descendant(
              of: find.byType(SeekIntervalIcon),
              matching: find.byType(Text),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Offset _cubicPoint(double t) {
  final u = 1 - t;
  return const Offset(14.2, 12.5) * (u * u * u) +
      const Offset(17.4, 12.5) * (3 * u * u * t) +
      const Offset(17.4, 16.5) * (3 * u * t * t) +
      const Offset(14.2, 16.5) * (t * t * t);
}
