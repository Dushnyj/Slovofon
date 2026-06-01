import 'package:flutter/material.dart';

import 'app_color_tokens.dart';
import 'app_focus_tokens.dart';
import 'app_radii_tokens.dart';
import 'app_spacing_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light({
    Color accent = AppColorTokens.defaultAccent,
    bool highContrast = false,
  }) {
    final colorScheme = _accentedScheme(
      seed: accent,
      brightness: Brightness.light,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      colorTokens: _tokensFor(colorScheme, accent).copyWith(
        success: const Color(0xFF1F7A4D),
        onSuccess: const Color(0xFFF8FAFC),
        warning: const Color(0xFF8A5B00),
        onWarning: const Color(0xFFF8FAFC),
        info: const Color(0xFF275EA8),
        onInfo: const Color(0xFFF8FAFC),
        playerSurface: highContrast
            ? const Color(0xFFE8EDF5)
            : const Color(0xFFEFF3FA),
        onPlayerSurface: const Color(0xFF182233),
      ),
    );
  }

  static ThemeData dark({
    Color accent = AppColorTokens.defaultAccent,
    bool highContrast = false,
    bool amoled = false,
  }) {
    final colorScheme = _accentedScheme(
      seed: accent,
      brightness: Brightness.dark,
    );

    final effectiveScheme = colorScheme.copyWith(
      surface: amoled ? const Color(0xFF000000) : colorScheme.surface,
    );

    return _buildTheme(
      colorScheme: effectiveScheme,
      colorTokens: _tokensFor(effectiveScheme, accent).copyWith(
        background: amoled ? const Color(0xFF000000) : effectiveScheme.surface,
        backgroundAlt: amoled
            ? const Color(0xFF070707)
            : effectiveScheme.surfaceContainerLow,
        surface: amoled ? const Color(0xFF000000) : colorScheme.surface,
        success: const Color(0xFF64C795),
        onSuccess: const Color(0xFF062817),
        warning: const Color(0xFFF0BF4D),
        onWarning: const Color(0xFF281B00),
        info: const Color(0xFF8CB9FF),
        onInfo: const Color(0xFF061A3D),
        playerSurface: highContrast
            ? const Color(0xFF202733)
            : const Color(0xFF171D26),
        onPlayerSurface: const Color(0xFFEAF0F8),
      ),
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required AppColorTokens colorTokens,
  }) {
    const spacing = AppSpacingTokens.compact;
    const radii = AppRadiiTokens.standard;
    final focusTokens = AppFocusTokens(
      color: colorTokens.focus,
      hoverColor: colorTokens.hover,
      selectedColor: colorTokens.selected,
      outlineWidth: 2,
      outlineInset: 2,
    );
    final minimumInteractiveSize = Size(
      spacing.touchTarget,
      spacing.touchTarget,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radii.md),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      focusColor: focusTokens.color.withValues(alpha: 0.18),
      hoverColor: focusTokens.hoverColor,
      extensions: [colorTokens, spacing, radii, focusTokens],
    );
    final textTheme = base.textTheme.apply(
      bodyColor: colorTokens.textPrimary,
      displayColor: colorTokens.textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorTokens.selected,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant;
          return textTheme.labelMedium?.copyWith(color: color);
        }),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.md),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.secondaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.pill),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minimumInteractiveSize,
          padding: EdgeInsets.symmetric(horizontal: spacing.lg),
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minimumInteractiveSize,
          padding: EdgeInsets.symmetric(horizontal: spacing.lg),
          shape: controlShape,
          side: BorderSide(color: colorTokens.border),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minimumInteractiveSize,
          padding: EdgeInsets.symmetric(horizontal: spacing.md),
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: minimumInteractiveSize,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.md),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        actionTextColor: colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surfaceContainerHigh,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.md),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.md),
          borderSide: BorderSide(color: focusTokens.color, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
        selectedColor: colorScheme.onSecondaryContainer,
        selectedTileColor: colorTokens.selected,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(radii.sm),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
    );
  }

  static AppColorTokens _tokensFor(ColorScheme colorScheme, Color accent) {
    return AppColorTokens(
      background: colorScheme.surface,
      backgroundAlt: colorScheme.surfaceContainerLow,
      surface: colorScheme.surface,
      surfaceVariant: colorScheme.surfaceContainerHighest,
      surfaceElevated: colorScheme.surfaceContainerHigh,
      primary: colorScheme.primary,
      primaryContainer: colorScheme.primaryContainer,
      accent: accent,
      success: colorScheme.primary,
      onSuccess: colorScheme.onPrimary,
      warning: colorScheme.tertiary,
      onWarning: colorScheme.onTertiary,
      info: colorScheme.secondary,
      onInfo: colorScheme.onSecondary,
      error: colorScheme.error,
      onError: colorScheme.onError,
      textPrimary: colorScheme.onSurface,
      textSecondary: colorScheme.onSurfaceVariant,
      textMuted: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
      border: colorScheme.outlineVariant,
      disabled: colorScheme.onSurface.withValues(alpha: 0.38),
      overlay: colorScheme.scrim.withValues(alpha: 0.12),
      focus: colorScheme.primary,
      hover: colorScheme.primary.withValues(alpha: 0.08),
      selected: colorScheme.primaryContainer,
      playerSurface: colorScheme.surfaceContainerHigh,
      onPlayerSurface: colorScheme.onSurface,
    );
  }

  static ColorScheme _accentedScheme({
    required Color seed,
    required Brightness brightness,
  }) {
    final accent = _accentForBrightness(seed, brightness);
    final neutral = _withNeutralSurfaces(
      ColorScheme.fromSeed(seedColor: accent, brightness: brightness),
    );
    final primaryContainer = _accentContainer(
      accent: accent,
      surface: neutral.surfaceContainerHigh,
      brightness: brightness,
    );
    final secondaryContainer = _accentContainer(
      accent: accent,
      surface: neutral.surfaceContainerHighest,
      brightness: brightness,
      darkAlpha: 0.18,
      lightAlpha: 0.12,
    );

    return neutral.copyWith(
      primary: accent,
      onPrimary: AppColorTokens.readableOn(accent),
      primaryContainer: primaryContainer,
      onPrimaryContainer: AppColorTokens.readableOn(primaryContainer),
      secondary: accent,
      onSecondary: AppColorTokens.readableOn(accent),
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: AppColorTokens.readableOn(secondaryContainer),
      error: brightness == Brightness.dark
          ? const Color(0xFFFF5A52)
          : const Color(0xFFC81E1E),
      onError: brightness == Brightness.dark
          ? const Color(0xFF2B0504)
          : const Color(0xFFFFFFFF),
      errorContainer: brightness == Brightness.dark
          ? const Color(0xFF5A1411)
          : const Color(0xFFFFE3E0),
      onErrorContainer: brightness == Brightness.dark
          ? const Color(0xFFFFDAD6)
          : const Color(0xFF5F0B08),
      surfaceTint: accent,
      inversePrimary: _accentForBrightness(
        seed,
        brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  static Color _accentForBrightness(Color seed, Brightness brightness) {
    if (brightness == Brightness.light) {
      return seed;
    }

    final hsv = HSVColor.fromColor(seed);
    return hsv
        .withSaturation(hsv.saturation.clamp(0.68, 1).toDouble())
        .withValue(hsv.value.clamp(0.78, 1).toDouble())
        .toColor();
  }

  static Color _accentContainer({
    required Color accent,
    required Color surface,
    required Brightness brightness,
    double darkAlpha = 0.12,
    double lightAlpha = 0.14,
  }) {
    return Color.alphaBlend(
      accent.withValues(
        alpha: brightness == Brightness.dark ? darkAlpha : lightAlpha,
      ),
      surface,
    );
  }

  static ColorScheme _withNeutralSurfaces(ColorScheme scheme) {
    if (scheme.brightness == Brightness.dark) {
      return scheme.copyWith(
        surface: const Color(0xFF131318),
        surfaceDim: const Color(0xFF131318),
        surfaceBright: const Color(0xFF39383F),
        surfaceContainerLowest: const Color(0xFF0E0E13),
        surfaceContainerLow: const Color(0xFF1B1B20),
        surfaceContainer: const Color(0xFF211F26),
        surfaceContainerHigh: const Color(0xFF2B2930),
        surfaceContainerHighest: const Color(0xFF36343B),
        onSurface: const Color(0xFFE6E1E9),
        onSurfaceVariant: const Color(0xFFC9C5D0),
        outline: const Color(0xFF938F99),
        outlineVariant: const Color(0xFF49454F),
      );
    }

    return scheme.copyWith(
      surface: const Color(0xFFFFFBFF),
      surfaceDim: const Color(0xFFDED8E1),
      surfaceBright: const Color(0xFFFFFBFF),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF7F2FA),
      surfaceContainer: const Color(0xFFF1ECF4),
      surfaceContainerHigh: const Color(0xFFECE6EF),
      surfaceContainerHighest: const Color(0xFFE6E0E9),
      onSurface: const Color(0xFF1D1B20),
      onSurfaceVariant: const Color(0xFF49454F),
      outline: const Color(0xFF79747E),
      outlineVariant: const Color(0xFFCAC4D0),
    );
  }
}
