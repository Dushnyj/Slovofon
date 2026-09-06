import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/ui/components/seek_interval_icon.dart';

void main() {
  // These inspect the real widget's painter, not a second implementation of
  // its artwork. Vector contracts complement the raster tests without font
  // loading or platform-dependent antialiasing at the numeral edges.
  for (final forward in [false, true]) {
    for (final size in [24.0, 48.0]) {
      testWidgets('seek vector geometry forward=$forward size=$size', (
        tester,
      ) async {
        const color = Color(0xff456789);
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SeekIntervalIcon(
                forward: forward,
                color: color,
                size: size,
              ),
            ),
          ),
        );
        final painted = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(SeekIntervalIcon),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(
          tester.getSize(find.byType(SeekIntervalIcon)),
          Size.square(size),
        );

        final canvas = TestRecordingCanvas();
        painted.painter!.paint(canvas, Size.square(size));
        final calls = [
          for (final recorded in canvas.invocations) recorded.invocation,
        ];

        // The reflection must be scoped to the arrow. A transform after
        // restore, a second paragraph or an unbalanced save cannot pass.
        expect(calls.map((call) => call.memberName), [
          #scale,
          #save,
          if (forward) ...[#translate, #scale],
          #drawArc,
          #drawPath,
          #restore,
          #drawParagraph,
        ]);
        expect(calls.first.positionalArguments, [size / 24, size / 24]);
        expect(canvas.getSaveCount(), 0);
        if (forward) {
          expect(calls[2].positionalArguments, [24, 0]);
          expect(calls[3].positionalArguments, [-1, 1]);
        }

        final arc = calls
            .singleWhere((call) => call.memberName == #drawArc)
            .positionalArguments;
        const rect = Rect.fromLTWH(4, 5, 16, 16);
        expect(arc[0], rect);
        expect(arc[1], math.pi);
        expect(arc[2], -math.pi * 1.5);
        expect(arc[3], isFalse);
        _expectStroke(arc[4] as Paint, color);

        final headCall = calls
            .singleWhere((call) => call.memberName == #drawPath)
            .positionalArguments;
        _expectStroke(headCall[1] as Paint, color);
        final head = headCall[0] as Path;
        expect(head.getBounds(), const Rect.fromLTRB(12, 2.25, 14.75, 7.75));
        final contours = head.computeMetrics().toList();
        expect(contours, hasLength(1));
        final contour = contours.single;
        expect(contour.isClosed, isFalse);
        final segmentLength = math.sqrt(2 * 2.75 * 2.75);
        expect(contour.length, closeTo(segmentLength * 2, 0.00001));

        // Three points and both straight-leg tangents describe the raised
        // chevron: top-right -> left-facing tip -> bottom-right. Checking
        // quarter points also rejects curved or additional head segments.
        const upper = Offset(14.75, 2.25);
        const tip = Offset(12, 5);
        const lower = Offset(14.75, 7.75);
        final points = <double, Offset>{
          0: upper,
          .25: const Offset(13.375, 3.625),
          .5: tip,
          .75: const Offset(13.375, 6.375),
          1: lower,
        };
        for (final point in points.entries) {
          final tangent = contour.getTangentForOffset(
            contour.length * point.key,
          );
          expect(tangent, isNotNull);
          _expectOffset(tangent!.position, point.value);
        }
        final diagonal = math.sqrt(.5);
        _expectOffset(
          contour.getTangentForOffset(contour.length * .25)!.vector,
          Offset(-diagonal, diagonal),
        );
        _expectOffset(
          contour.getTangentForOffset(contour.length * .75)!.vector,
          Offset(diagonal, diagonal),
        );

        final endAngle = (arc[1] as double) + (arc[2] as double);
        final arcEndpoint =
            rect.center +
            Offset(
              rect.width / 2 * math.cos(endAngle),
              rect.height / 2 * math.sin(endAngle),
            );
        _expectOffset(arcEndpoint, tip);
        // Negative sweep approaches the top endpoint from the right. The
        // head and endpoint tangent both face left, or right after mirroring.
        final endpointTangent = Offset(math.sin(endAngle), -math.cos(endAngle));
        _expectOffset(endpointTangent, const Offset(-1, 0));
        final mirrorX = forward ? -1.0 : 1.0;
        final visibleTangent = Offset(
          endpointTangent.dx * mirrorX,
          endpointTangent.dy,
        );
        _expectOffset(visibleTangent, Offset(forward ? 1 : -1, 0));
        final headDirection = tip - (upper + lower) / 2;
        expect(headDirection.dy, 0);
        expect(headDirection.dx * mirrorX * visibleTangent.dx, greaterThan(0));

        final paragraph = calls.last;
        expect(paragraph.memberName, #drawParagraph);
        expect(calls[calls.length - 2].memberName, #restore);
        final paragraphOffset = paragraph.positionalArguments[1] as Offset;
        expect(paragraphOffset.dx.isFinite, isTrue);
        expect(paragraphOffset.dy.isFinite, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

void _expectStroke(Paint paint, Color color) {
  expect(paint.color.toARGB32(), color.toARGB32());
  expect(paint.color.colorSpace, color.colorSpace);
  expect(paint.style, PaintingStyle.stroke);
  // Paint and path storage use float32 internally, unlike the Dart literals.
  expect(paint.strokeWidth, closeTo(1.8, 0.000001));
  expect(paint.strokeCap, StrokeCap.round);
  expect(paint.strokeJoin, StrokeJoin.round);
}

void _expectOffset(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 0.00001));
  expect(actual.dy, closeTo(expected.dy, 0.00001));
}
