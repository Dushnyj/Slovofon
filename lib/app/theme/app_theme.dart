import 'package:flutter/material.dart';

import 'app_color_tokens.dart';

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
      tokens: AppColorTokens(
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

    return _buildTheme(
      colorScheme: colorScheme.copyWith(
        surface: amoled ? const Color(0xFF000000) : colorScheme.surface,
      ),
      tokens: AppColorTokens(
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
    required AppColorTokens tokens,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: [tokens],
    );

    return base.copyWith(
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
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        surfaceTintColor: colorScheme.surfaceTint,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.secondaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
        side: BorderSide(color: colorScheme.outlineVariant),
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
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
    );
  }
}

