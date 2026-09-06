import 'package:flutter/material.dart';

/// Layout values are logical pixels, never physical panel resolution.
/// Full HD at DPR 2 and 4K at DPR 4 intentionally use the same composition.
abstract final class TelevisionMetrics {
  static const controlExtent = 40.0;
  static const transportMinHeight = 56.0;
  static const wideContentBreakpoint = 1024.0;

  /// Overscan space grows with the viewport, but does not waste huge gutters
  /// on displays which actually provide more logical working space.
  static EdgeInsets safeInsetsFor(Size logicalSize) => EdgeInsets.symmetric(
    horizontal: (logicalSize.width * .04).clamp(24.0, 64.0),
    vertical: (logicalSize.height * .04).clamp(16.0, 40.0),
  );
}
