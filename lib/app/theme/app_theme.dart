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
      highContrast: highContrast,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      colorTokens: _tokensFor(colorScheme, accent).copyWith(
        highContrast: highContrast,
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
      highContrast: highContrast,
    );

    final effectiveScheme = colorScheme.copyWith(
      surface: amoled ? const Color(0xFF000000) : colorScheme.surface,
    );

    return _buildTheme(
      colorScheme: effectiveScheme,
      colorTokens: _tokensFor(effectiveScheme, accent).copyWith(
        highContrast: highContrast,
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

    return withAccentComponents(
      base.copyWith(
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
          labelStyle: base.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurface,
          ),
          secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(
            color: colorScheme.onSecondaryContainer,
          ),
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
      ),
    );
  }

  /// Color-only component layer. Platform geometry/typography is preserved.
  /// Primary = action; secondaryContainer = selection; surfaces stay neutral.
  static ThemeData withAccentComponents(ThemeData base) {
    final colors = base.colorScheme;
    final disabled = colors.onSurface.withValues(alpha: 0.38);
    final transparent = colors.surface.withValues(alpha: 0);
    Color? interactionBackground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return null;
      if (states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed)) {
        return colors.primary;
      }
      if (states.contains(WidgetState.hovered)) {
        return colors.secondaryContainer;
      }
      return null;
    }

    Color? interactionForeground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return disabled;
      if (states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed)) {
        return colors.onPrimary;
      }
      if (states.contains(WidgetState.hovered)) {
        return colors.onSecondaryContainer;
      }
      return null;
    }

    final quietInteraction = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(interactionBackground),
      foregroundColor: WidgetStateProperty.resolveWith(interactionForeground),
      // A second tinted overlay must not compromise the resolved color pair.
      overlayColor: WidgetStatePropertyAll(transparent),
    );
    final iconInteraction = quietInteraction.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.disabled) &&
            states.contains(WidgetState.selected)) {
          return colors.primary;
        }
        return interactionBackground(states);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.disabled) &&
            states.contains(WidgetState.selected)) {
          return colors.onPrimary;
        }
        return interactionForeground(states);
      }),
    );
    Color selectionControl(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return disabled;
      return states.contains(WidgetState.selected)
          ? colors.primary
          : colors.onSurfaceVariant;
    }

    return base.copyWith(
      focusColor: colors.primary.withValues(alpha: 0.16),
      hoverColor: colors.primary.withValues(alpha: 0.08),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        indicatorColor: colors.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
        // Labels sit on the neutral bar, outside the colored indicator.
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: base.navigationRailTheme.copyWith(
        backgroundColor: colors.surface,
        indicatorColor: colors.secondaryContainer,
        selectedIconTheme: IconThemeData(color: colors.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
        selectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          color: colors.primary,
        ),
        unselectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        indicatorColor: colors.primary,
        dividerColor: colors.outlineVariant,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        iconColor: colors.primary,
        selectedColor: colors.onSecondaryContainer,
        selectedTileColor: colors.secondaryContainer,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: quietInteraction.merge(base.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: quietInteraction.merge(base.textButtonTheme.style),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: iconInteraction.merge(base.iconButtonTheme.style),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: colors.secondaryContainer,
        checkmarkColor: colors.onSecondaryContainer,
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(
          color: colors.onSecondaryContainer,
        ),
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return states.contains(WidgetState.selected)
                ? disabled
                : transparent;
          }
          return states.contains(WidgetState.selected)
              ? colors.primary
              : transparent;
        }),
        checkColor: WidgetStatePropertyAll(colors.onPrimary),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: selectionControl(states),
            width: states.contains(WidgetState.focused) ? 2.5 : 2,
          ),
        ),
      ),
      radioTheme: base.radioTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith(selectionControl),
      ),
      switchTheme: base.switchTheme.copyWith(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.surfaceContainerHighest;
          }
          return states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceContainerHighest;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return disabled;
          return states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.onSurfaceVariant;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) &&
                  !states.contains(WidgetState.disabled)
              ? transparent
              : selectionControl(states),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.secondaryContainer,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.12),
        activeTickMarkColor: colors.onPrimary,
        inactiveTickMarkColor: colors.onSecondaryContainer,
        valueIndicatorColor: colors.primary,
        valueIndicatorTextStyle: base.textTheme.labelLarge?.copyWith(
          color: colors.onPrimary,
        ),
      ),
      textSelectionTheme: base.textSelectionTheme.copyWith(
        cursorColor: colors.primary,
        selectionHandleColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.22),
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: colors.primary,
        circularTrackColor: colors.surfaceContainerHighest,
        linearTrackColor: colors.surfaceContainerHighest,
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      scrollbarTheme: base.scrollbarTheme.copyWith(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.hovered)) {
            return colors.primary;
          }
          return colors.onSurfaceVariant.withValues(alpha: 0.45);
        }),
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
      selected: colorScheme.secondaryContainer,
      playerSurface: colorScheme.surfaceContainerHigh,
      onPlayerSurface: colorScheme.onSurface,
    );
  }

  static ColorScheme _accentedScheme({
    required Color seed,
    required Brightness brightness,
    required bool highContrast,
  }) {
    final neutral = _withNeutralSurfaces(
      ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    );
    return accentedSchemeFor(neutral, accent: seed, highContrast: highContrast);
  }

  /// Re-derive accent roles after a platform changes its neutral surfaces.
  /// Windows must not retain the mobile tone in component themes/extensions.
  static ColorScheme accentedSchemeFor(
    ColorScheme neutral, {
    required Color accent,
    bool highContrast = false,
  }) {
    final brightness = neutral.brightness;
    final surfaces = [
      neutral.surface,
      neutral.surfaceBright,
      neutral.surfaceDim,
      neutral.surfaceContainerLowest,
      neutral.surfaceContainerLow,
      neutral.surfaceContainer,
      neutral.surfaceContainerHigh,
      neutral.surfaceContainerHighest,
    ];
    final tone = AppColorTokens.accessibleAccent(
      accent,
      surfaces,
      minimumContrast: highContrast ? 7 : 4.5,
    );
    final primaryContainer = _accentContainer(
      accent: tone,
      surface: neutral.surfaceContainerLow,
      brightness: brightness,
    );
    final secondaryContainer = _accentContainer(
      accent: tone,
      surface: neutral.surfaceContainerLow,
      brightness: brightness,
      darkAlpha: 0.18,
      lightAlpha: 0.10,
    );

    return neutral.copyWith(
      onSurface: highContrast
          ? AppColorTokens.accessibleAccent(
              neutral.onSurface,
              surfaces,
              minimumContrast: 7,
            )
          : neutral.onSurface,
      onSurfaceVariant: highContrast
          ? AppColorTokens.accessibleAccent(
              neutral.onSurfaceVariant,
              surfaces,
              minimumContrast: 7,
            )
          : neutral.onSurfaceVariant,
      outlineVariant: highContrast ? neutral.outline : neutral.outlineVariant,
      primary: tone,
      onPrimary: AppColorTokens.readableOn(tone),
      primaryContainer: primaryContainer,
      onPrimaryContainer: AppColorTokens.readableOn(primaryContainer),
      secondary: tone,
      onSecondary: AppColorTokens.readableOn(tone),
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
      surfaceTint: tone,
      inversePrimary: AppColorTokens.accessibleAccent(accent, [
        neutral.inverseSurface,
      ], minimumContrast: highContrast ? 7 : 4.5),
    );
  }

  static Color _accentContainer({
    required Color accent,
    required Color surface,
    required Brightness brightness,
    double darkAlpha = 0.26,
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
