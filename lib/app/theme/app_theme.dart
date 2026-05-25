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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
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
            ? const Color(0xFF172033)
            : const Color(0xFFEAF0FF),
        onPlayerSurface: highContrast
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF172033),
      ),
    );
  }

  static ThemeData dark({
    Color accent = AppColorTokens.defaultAccent,
    bool highContrast = false,
    bool amoled = false,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
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
            ? const Color(0xFFF1F5FF)
            : const Color(0xFF172033),
        onPlayerSurface: highContrast
            ? const Color(0xFF172033)
            : const Color(0xFFF1F5FF),
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
        surfaceTintColor: colorScheme.surfaceTint,
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
        surfaceTintColor: colorScheme.surfaceTint,
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
        surfaceTintColor: colorScheme.surfaceTint,
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
        color: colorTokens.accent,
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
      focus: accent,
      hover: colorScheme.primary.withValues(alpha: 0.08),
      selected: colorScheme.secondaryContainer,
      playerSurface: colorScheme.surfaceContainerHigh,
      onPlayerSurface: colorScheme.onSurface,
    );
  }
}
