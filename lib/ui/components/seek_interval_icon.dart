import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A pictogram, including its interval digits, rather than scaled UI text.
/// The surrounding button supplies the localized action/interval semantics.
class SeekIntervalIcon extends StatelessWidget {
  const SeekIntervalIcon({
    required this.forward,
    this.color,
    this.size = 24,
    super.key,
  });

  final bool forward;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SeekIntervalPainter(
          forward: forward,
          color:
              color ??
              IconTheme.of(context).color ??
              Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  );
}

class _SeekIntervalPainter extends CustomPainter {
  const _SeekIntervalPainter({required this.forward, required this.color});
  final bool forward;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    if (forward) {
      canvas.translate(24, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawArc(
      const Rect.fromLTWH(4, 5, 16, 16),
      // The rewind arc ends at the top, arriving from the right. Its tangent
      // then points left, along the arrowhead (not away from the arrowhead).
      math.pi,
      -math.pi * 1.5,
      false,
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(14.75, 2.25)
        ..lineTo(12, 5)
        ..lineTo(14.75, 7.75),
      stroke,
    );
    canvas.restore();
    // Use properly shaped numerals, not tiny stroked paths. The upper-left
    // opening and raised arrowhead leave clear space around the digits.
    // Only the arrow is mirrored: the interval always reads "15" left to right.
    final interval = TextPainter(
      text: TextSpan(
        text: '15',
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    interval.paint(
      canvas,
      Offset((24 - interval.width) / 2, 13.5 - interval.height / 2),
    );
    interval.dispose();
  }

  @override
  bool shouldRepaint(_SeekIntervalPainter oldDelegate) =>
      forward != oldDelegate.forward || color != oldDelegate.color;
}
