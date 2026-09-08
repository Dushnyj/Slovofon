import 'package:flutter/material.dart';

/// Layout values are logical pixels, never physical panel resolution.
/// Full HD at DPR 2 and 4K at DPR 4 intentionally use the same composition.
abstract final class TelevisionMetrics {
  static const controlExtent = 36.0;
  static const transportMinHeight = 64.0;
  static const wideContentBreakpoint = 1024.0;

  /// Content owns its spacing; the viewport/Navigator stays full-screen.
  /// A percentage inset around every route created an empty frame, reduced the
  /// working area and pulled the mini-player away from the display edges.
  static const contentInset = 16.0;
  static const contentInsets = EdgeInsets.all(contentInset);
}
