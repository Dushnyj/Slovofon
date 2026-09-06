import 'dart:math' as math;

import 'package:flutter/material.dart';

/// AppBar caps its inherited title scaler at 1.34. Restore only the actual
/// system + app scaler captured outside the toolbar, including for async titles.
Widget preserveAppBarTextScale(BuildContext context, Widget child) {
  final textScaler = MediaQuery.textScalerOf(context);
  return Builder(
    builder: (titleContext) => MediaQuery(
      data: MediaQuery.of(titleContext).copyWith(textScaler: textScaler),
      child: child,
    ),
  );
}

/// Grow the text area without enlarging toolbar icons or reducing touch targets.
/// Keep the normal toolbar height for small text; measure real font metrics so
/// nonlinear accessibility scaling is not approximated with scale(1).
double appBarToolbarHeight(BuildContext context) {
  final theme = Theme.of(context);
  final appBarTheme = AppBarTheme.of(context);
  final titleStyle = appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge!;
  final painter = TextPainter(
    text: TextSpan(text: 'AgЙ', style: titleStyle),
    textScaler: MediaQuery.textScalerOf(context),
    textDirection: Directionality.of(context),
    locale: Localizations.maybeLocaleOf(context),
    maxLines: 1,
  )..layout();
  final lineHeight = painter.height.ceilToDouble();
  painter.dispose();
  return math.max(appBarTheme.toolbarHeight ?? kToolbarHeight, lineHeight + 16);
}
