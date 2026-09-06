import 'package:flutter/material.dart';

/// Ten-foot presentation, preserving the chosen theme/accent and text scaler.
/// Focus, not hover, is the primary interaction signal on a television.
abstract final class TelevisionTheme {
  static ThemeData from(ThemeData base) {
    final colors = base.colorScheme;
    final text = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 26,
        height: 1.15,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 24,
        height: 1.2,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 22,
        height: 1.2,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 22,
        height: 1.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 18,
        height: 1.25,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontSize: 16,
        height: 1.25,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.3),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 16,
        height: 1.3,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 14, height: 1.3),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 15,
        height: 1.2,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontSize: 14,
        height: 1.2,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontSize: 14,
        height: 1.2,
      ),
    );
    ButtonStyle control({bool filled = false}) => ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          width: states.contains(WidgetState.focused) ? 2 : 1,
          color: states.contains(WidgetState.focused)
              ? colors.primary
              : colors.outlineVariant,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? colors.primary
            : filled
            ? colors.secondaryContainer
            : colors.surfaceContainerLow,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.onSurface.withValues(alpha: .38)
            : states.contains(WidgetState.focused)
            ? colors.onPrimary
            : filled
            ? colors.onSecondaryContainer
            : colors.onSurface,
      ),
      overlayColor: WidgetStatePropertyAll(
        colors.primary.withValues(alpha: .12),
      ),
    );
    return base.copyWith(
      textTheme: text,
      visualDensity: VisualDensity.standard,
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: 48,
        titleTextStyle: text.titleLarge,
      ),
      focusColor: colors.primary.withValues(alpha: .3),
      iconTheme: base.iconTheme.copyWith(size: 22),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: text.labelLarge?.copyWith(color: colors.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: colors.onSecondaryContainer,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(style: control(filled: true)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: control()),
      textButtonTheme: TextButtonThemeData(style: control()),
      iconButtonTheme: IconButtonThemeData(
        style: control().copyWith(
          padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        minTileHeight: 52,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
    );
  }
}
