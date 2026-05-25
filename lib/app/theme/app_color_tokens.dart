import 'package:flutter/material.dart';

class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceElevated,
    required this.primary,
    required this.primaryContainer,
    required this.accent,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
    required this.error,
    required this.onError,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.disabled,
    required this.overlay,
    required this.focus,
    required this.hover,
    required this.selected,
    required this.playerSurface,
    required this.onPlayerSurface,
  });

  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceVariant;
  final Color surfaceElevated;
  final Color primary;
  final Color primaryContainer;
  final Color accent;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;
  final Color error;
  final Color onError;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color disabled;
  final Color overlay;
  final Color focus;
  final Color hover;
  final Color selected;
  final Color playerSurface;
  final Color onPlayerSurface;

  static const Color defaultAccent = Color(0xFF3969D8);

  static Color readableOn(Color background) {
    return background.computeLuminance() > 0.48
        ? const Color(0xFF111418)
        : const Color(0xFFF8FAFC);
  }

  static double contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance() + 0.05;
    final secondLuminance = second.computeLuminance() + 0.05;
    final lighter = firstLuminance > secondLuminance
        ? firstLuminance
        : secondLuminance;
    final darker = firstLuminance > secondLuminance
        ? secondLuminance
        : firstLuminance;

    return lighter / darker;
  }

  @override
  AppColorTokens copyWith({
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? surfaceVariant,
    Color? surfaceElevated,
    Color? primary,
    Color? primaryContainer,
    Color? accent,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
    Color? error,
    Color? onError,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? disabled,
    Color? overlay,
    Color? focus,
    Color? hover,
    Color? selected,
    Color? playerSurface,
    Color? onPlayerSurface,
  }) {
    return AppColorTokens(
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      primary: primary ?? this.primary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      disabled: disabled ?? this.disabled,
      overlay: overlay ?? this.overlay,
      focus: focus ?? this.focus,
      hover: hover ?? this.hover,
      selected: selected ?? this.selected,
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
      background: Color.lerp(background, other.background, t)!,
      backgroundAlt: Color.lerp(backgroundAlt, other.backgroundAlt, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      playerSurface: Color.lerp(playerSurface, other.playerSurface, t)!,
      onPlayerSurface: Color.lerp(onPlayerSurface, other.onPlayerSurface, t)!,
    );
  }
}
