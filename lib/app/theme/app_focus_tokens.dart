import 'package:flutter/material.dart';

class AppFocusTokens extends ThemeExtension<AppFocusTokens> {
  const AppFocusTokens({
    required this.color,
    required this.hoverColor,
    required this.selectedColor,
    required this.outlineWidth,
    required this.outlineInset,
  });

  final Color color;
  final Color hoverColor;
  final Color selectedColor;
  final double outlineWidth;
  final double outlineInset;

  @override
  AppFocusTokens copyWith({
    Color? color,
    Color? hoverColor,
    Color? selectedColor,
    double? outlineWidth,
    double? outlineInset,
  }) {
    return AppFocusTokens(
      color: color ?? this.color,
      hoverColor: hoverColor ?? this.hoverColor,
      selectedColor: selectedColor ?? this.selectedColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      outlineInset: outlineInset ?? this.outlineInset,
    );
  }

  @override
  AppFocusTokens lerp(ThemeExtension<AppFocusTokens>? other, double t) {
    if (other is! AppFocusTokens) {
      return this;
    }

    return AppFocusTokens(
      color: Color.lerp(color, other.color, t)!,
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t)!,
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t)!,
      outlineWidth: _lerpDouble(outlineWidth, other.outlineWidth, t),
      outlineInset: _lerpDouble(outlineInset, other.outlineInset, t),
    );
  }

  static double _lerpDouble(double first, double second, double t) {
    return first + (second - first) * t;
  }
}
