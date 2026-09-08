import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/ui/components/seek_interval_icon.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  test(
    'approved seek geometry is centred, spaced and mirrors only the arrow',
    () {
      final rewind = File(AppIconAssets.playerRewind15).readAsStringSync();
      final forward = File(AppIconAssets.playerForward15).readAsStringSync();
      String element(String source, String id) =>
          RegExp('<path id="$id"[^>]+>').firstMatch(source)!.group(0)!;
      String data(String element) =>
          RegExp(r' d="([^"]+)"').firstMatch(element)!.group(1)!;
      const arc = 'M3.1135 14.3811A9.2 9.2 0 1 0 5.4946 5.4946';
      const head =
          'M4.13 6.93Q3.86 6.98 3.91 6.71L4.52 3.22'
          'Q4.58 2.87 4.83 3.12L7.88 6.17Q8.13 6.42 7.78 6.48Z';
      const digits =
          'M7.4 9.7L8.9 8H10.2V16H8.8V10L8.3 10.5Z '
          'M15.7 8H11.7V12.4H12.9C13.18 12.16 13.5 12.03 13.86 12.03'
          'C14.7 12.03 15.2 12.5 15.2 13.3C15.2 14.16 14.62 14.67 13.79 14.67'
          'C13.16 14.67 12.57 14.44 12.06 14.04L11.44 15.21'
          'C12.08 15.75 12.95 16 13.85 16C15.59 16 16.6 14.98 16.6 13.25'
          'C16.6 11.73 15.69 10.76 14.25 10.76'
          'C13.85 10.76 13.47 10.83 13.1 10.97V9.32H15.7Z';
      for (final source in [rewind, forward]) {
        expect(source, contains('viewBox="0 0 24 24"'));
        expect(source, contains('Source: Slovofon original seek artwork'));
        expect(source, contains('License: Apache-2.0'));
        expect(source, contains('<title>'));
        expect(source, contains('stroke="currentColor"'));
        expect(source, contains('stroke-linecap="round"'));
        expect(RegExp('<path ').allMatches(source), hasLength(3));
        expect(source, isNot(contains('<text')));
        expect(source, isNot(contains('<image')));
        expect(source, isNot(contains('font-')));
        expect(element(source, 'interval'), isNot(contains('transform')));
        expect(element(source, 'interval'), contains('fill="currentColor"'));
        expect(element(source, 'interval'), contains('stroke="none"'));
        expect(element(source, 'arrowhead'), contains('stroke="none"'));
        expect(element(source, 'arrow'), contains('stroke-width="2"'));
        expect(data(element(source, 'arrow')), arc);
        expect(data(element(source, 'arrowhead')), head);
        expect(data(element(source, 'interval')), digits);
      }
      expect(element(rewind, 'interval'), element(forward, 'interval'));
      expect(rewind, isNot(contains('transform=')));
      final reflected = RegExp(
        r'<g transform="translate\(24 0\) scale\(-1 1\)">([\s\S]*?)</g>',
      ).firstMatch(forward)!;
      expect(RegExp('transform=').allMatches(forward), hasLength(1));
      expect(reflected.group(1), contains('id="arrow"'));
      expect(reflected.group(1), contains('id="arrowhead"'));
      expect(reflected.group(1), isNot(contains('id="interval"')));
      // Font-free filled glyphs share cap height/baseline and the circle's centre.
      final digitPath = _filledPath(digits);
      final bounds = digitPath.getBounds();
      expect(bounds.left, closeTo(7.4, .00001));
      expect(bounds.right, closeTo(16.6, .00001));
      expect(bounds.top, 8);
      expect(bounds.bottom, 16);
      expect(bounds.center.dx, closeTo(12, .00001));
      expect(bounds.center.dy, 12);
      expect(digitPath.computeMetrics().length, 2);
      final headPath = _filledPath(head);
      expect(bounds.top - headPath.getBounds().bottom, greaterThan(1));
      expect(headPath.contains(const Offset(5.4946, 5.4946)), isTrue);
      final heading =
          const Offset(4.13, 6.93) -
          const Offset((4.83 + 7.88) / 2, (3.12 + 6.17) / 2);
      expect(heading.dx, isNegative);
      expect(heading.dy, isPositive);
      expect(heading.dx.abs(), closeTo(heading.dy.abs(), .07));
      // Test actual contours (including the five's cubic bowl), not just a
      // hardcoded bounding rectangle. Ring's inner radius is 9.2 - stroke2/2.
      for (final contour in digitPath.computeMetrics()) {
        for (var distance = 0.0; distance < contour.length; distance += .02) {
          final point = contour.getTangentForOffset(distance)!.position;
          final clearance = 8.2 - (point - const Offset(12, 12)).distance;
          expect(clearance, greaterThan(2.5), reason: '$point');
          expect(headPath.contains(point), isFalse);
        }
      }
      expect(const SeekIntervalIcon(forward: false).size, 28);
    },
  );
  for (final forward in [false, true]) {
    for (final size in [20.0, 24.0, 28.0, 32.0]) {
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

// Small absolute-command parser for the approved original paths. This tests
// the geometry from SVG data without importing a font or a new SVG dependency.
Path _filledPath(String data) {
  final tokens = RegExp(
    r'[MLHVQCZ]|-?(?:\d*\.)?\d+',
  ).allMatches(data).map((match) => match.group(0)!).toList();
  final path = Path();
  var index = 0;
  var x = 0.0;
  var y = 0.0;
  double number() => double.parse(tokens[index++]);
  while (index < tokens.length) {
    switch (tokens[index++]) {
      case 'M':
        x = number();
        y = number();
        path.moveTo(x, y);
      case 'L':
        x = number();
        y = number();
        path.lineTo(x, y);
      case 'H':
        x = number();
        path.lineTo(x, y);
      case 'V':
        y = number();
        path.lineTo(x, y);
      case 'Q':
        final cx = number(), cy = number();
        x = number();
        y = number();
        path.quadraticBezierTo(cx, cy, x, y);
      case 'C':
        final c1x = number(), c1y = number(), c2x = number(), c2y = number();
        x = number();
        y = number();
        path.cubicTo(c1x, c1y, c2x, c2y, x, y);
      case 'Z':
        path.close();
      default:
        throw const FormatException('Unsupported approved path command');
    }
  }
  return path;
}
