import 'package:flutter/material.dart';

import 'app_color_tokens.dart';
import 'app_focus_tokens.dart';
import 'app_theme.dart';

/// A local presentation layer: does not change saved theme or accent settings.
abstract final class WindowsTheme {
  static ThemeData from(ThemeData base) {
    final dark = base.brightness == Brightness.dark;
    final amoled = dark && base.colorScheme.surface.toARGB32() == 0xff000000;
    var scheme = base.colorScheme.copyWith(
      surface: amoled
          ? const Color(0xff000000)
          : dark
          ? const Color(0xff151b26)
          : const Color(0xfff5f7fa),
      surfaceContainerLowest: dark
          ? const Color(0xff101620)
          : const Color(0xffffffff),
      surfaceContainerLow: dark
          ? const Color(0xff1a2230)
          : const Color(0xfff0f3f8),
      surfaceContainer: dark
          ? const Color(0xff202a39)
          : const Color(0xffeaf0f6),
      surfaceContainerHigh: dark
          ? const Color(0xff263244)
          : const Color(0xffe3eaf2),
      surfaceContainerHighest: dark
          ? const Color(0xff2e3c50)
          : const Color(0xffdce5ef),
      onSurface: dark ? const Color(0xffe8eef7) : const Color(0xff192539),
      onSurfaceVariant: dark
          ? const Color(0xffb2bfd2)
          : const Color(0xff536176),
      outline: dark ? const Color(0xff75869e) : const Color(0xff78869a),
      outlineVariant: dark ? const Color(0xff344257) : const Color(0xffd2dce8),
    );
    final original = base.extension<AppColorTokens>()!;
    scheme = AppTheme.accentedSchemeFor(
      scheme,
      accent: original.accent,
      highContrast: original.highContrast,
    );
    final primary = scheme.primary;
    final colors = original.copyWith(
      background: scheme.surface,
      backgroundAlt: scheme.surfaceContainerLow,
      surface: scheme.surface,
      surfaceVariant: scheme.surfaceContainer,
      surfaceElevated: scheme.surfaceContainerLowest,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      textMuted: scheme.onSurfaceVariant,
      border: scheme.outlineVariant,
      primary: primary,
      primaryContainer: scheme.primaryContainer,
      focus: primary,
      hover: primary.withValues(alpha: 0.08),
      selected: scheme.secondaryContainer,
      playerSurface: scheme.surfaceContainerLowest,
      onPlayerSurface: scheme.onSurface,
    );
    final type = base.textTheme.apply(
      fontFamily: 'Segoe UI',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final text = type.copyWith(
      headlineSmall: type.headlineSmall?.copyWith(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
      ),
      titleLarge: type.titleLarge?.copyWith(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleMedium: type.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: type.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      labelLarge: type.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return AppTheme.withAccentComponents(
      base.copyWith(
        colorScheme: scheme,
        scaffoldBackgroundColor: scheme.surface,
        textTheme: text,
        extensions: [
          for (final extension in base.extensions.values)
            if (extension is! AppColorTokens && extension is! AppFocusTokens)
              extension,
          colors,
          base.extension<AppFocusTokens>()!.copyWith(
            color: primary,
            hoverColor: colors.hover,
            selectedColor: colors.selected,
          ),
        ],
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          titleTextStyle: text.titleLarge,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: base.cardTheme.copyWith(
          color: scheme.surfaceContainerLowest,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          fillColor: scheme.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
          hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        listTileTheme: base.listTileTheme.copyWith(
          textColor: scheme.onSurface,
          iconColor: scheme.primary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: scheme.surfaceContainerLowest,
          side: BorderSide(color: scheme.outlineVariant),
          labelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
        ),
        tooltipTheme: base.tooltipTheme.copyWith(
          waitDuration: const Duration(milliseconds: 450),
        ),
        dividerTheme: base.dividerTheme.copyWith(color: scheme.outlineVariant),
        dialogTheme: base.dialogTheme.copyWith(
          backgroundColor: scheme.surfaceContainerLow,
          titleTextStyle: text.titleLarge,
          contentTextStyle: text.bodyMedium,
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: scheme.surfaceContainerLow,
          modalBackgroundColor: scheme.surfaceContainerLow,
        ),
        popupMenuTheme: base.popupMenuTheme.copyWith(
          color: scheme.surfaceContainerLow,
          textStyle: text.bodyMedium,
        ),
        progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
          linearTrackColor: scheme.surfaceContainerHighest,
          circularTrackColor: scheme.surfaceContainerHighest,
        ),
        scrollbarTheme: base.scrollbarTheme.copyWith(
          thickness: const WidgetStatePropertyAll(6),
          radius: const Radius.circular(8),
        ),
      ),
    );
  }
}
