import 'package:flutter/material.dart';

class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
    required this.playerSurface,
    required this.onPlayerSurface,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;
  final Color playerSurface;
  final Color onPlayerSurface;

  static const Color defaultAccent = Color(0xFF3969D8);

  static Color readableOn(Color background) {
    return background.computeLuminance() > 0.48
        ? const Color(0xFF111418)
        : const Color(0xFFF8FAFC);
  }

  @override
  AppColorTokens copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? playerSurface,
    Color? onPlayerSurface,
  }) {
    return AppColorTokens(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      playerSurface: playerSurface ?? this.playerSurface,
      onPlayerSurface: onPlayerSurface ?? this.onPlayerSurface,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }

    return AppColorTokens(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      playerSurface: Color.lerp(playerSurface, other.playerSurface, t)!,
      onPlayerSurface: Color.lerp(onPlayerSurface, other.onPlayerSurface, t)!,
    );
  }
}

