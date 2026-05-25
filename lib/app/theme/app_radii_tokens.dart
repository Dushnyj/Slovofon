import 'package:flutter/material.dart';

class AppRadiiTokens extends ThemeExtension<AppRadiiTokens> {
  const AppRadiiTokens({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.pill,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double pill;

  static const standard = AppRadiiTokens(
    xs: 4,
    sm: 6,
    md: 8,
    lg: 12,
    pill: 999,
  );

  @override
  AppRadiiTokens copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? pill,
  }) {
    return AppRadiiTokens(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      pill: pill ?? this.pill,
    );
  }

  @override
  AppRadiiTokens lerp(ThemeExtension<AppRadiiTokens>? other, double t) {
    if (other is! AppRadiiTokens) {
      return this;
    }

    return AppRadiiTokens(
      xs: _lerpDouble(xs, other.xs, t),
      sm: _lerpDouble(sm, other.sm, t),
      md: _lerpDouble(md, other.md, t),
      lg: _lerpDouble(lg, other.lg, t),
      pill: _lerpDouble(pill, other.pill, t),
    );
  }

  static double _lerpDouble(double first, double second, double t) {
    return first + (second - first) * t;
  }
}
