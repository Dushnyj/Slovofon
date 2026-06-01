import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/app_focus_tokens.dart';
import 'package:slovofon/app/theme/app_radii_tokens.dart';
import 'package:slovofon/app/theme/app_spacing_tokens.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/ui/components/source_badge.dart';

void main() {
  test('themes expose Stage 2 token extensions', () {
    final themes = [
      AppTheme.light(),
      AppTheme.dark(),
      AppTheme.dark(amoled: true),
    ];

    for (final theme in themes) {
      expect(theme.extension<AppColorTokens>(), isNotNull);
      expect(theme.extension<AppSpacingTokens>(), isNotNull);
      expect(theme.extension<AppRadiiTokens>(), isNotNull);
      expect(theme.extension<AppFocusTokens>(), isNotNull);
    }
  });

  test('semantic state colors use readable foreground pairs', () {
    final tokens = AppTheme.light().extension<AppColorTokens>()!;

    final pairs = [
      (tokens.success, tokens.onSuccess),
      (tokens.warning, tokens.onWarning),
      (tokens.info, tokens.onInfo),
      (tokens.error, tokens.onError),
      (tokens.playerSurface, tokens.onPlayerSurface),
    ];

    for (final (background, foreground) in pairs) {
      expect(
        AppColorTokens.contrastRatio(background, foreground),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('accent colors do not tint neutral surfaces', () {
    final blue = AppTheme.light(accent: const Color(0xFF2563EB)).colorScheme;
    final red = AppTheme.light(accent: const Color(0xFFDC2626)).colorScheme;
    final darkBlue = AppTheme.dark(accent: const Color(0xFF2563EB)).colorScheme;
    final darkRed = AppTheme.dark(accent: const Color(0xFFDC2626)).colorScheme;

    expect(blue.primary, isNot(red.primary));
    expect(blue.surface, red.surface);
    expect(blue.surfaceContainerHigh, red.surfaceContainerHigh);
    expect(blue.onSurface, red.onSurface);
    expect(darkBlue.primary, isNot(darkRed.primary));
    expect(darkBlue.surface, darkRed.surface);
    expect(darkBlue.surfaceContainerHigh, darkRed.surfaceContainerHigh);
    expect(darkBlue.onSurface, darkRed.onSurface);
  });

  test('dark red accent stays saturated and readable', () {
    final scheme = AppTheme.dark(accent: const Color(0xFFB42318)).colorScheme;

    expect(scheme.primary.r, greaterThan(scheme.primary.g));
    expect(scheme.primary.r, greaterThan(scheme.primary.b));
    expect(
      AppColorTokens.contrastRatio(scheme.primary, scheme.surface),
      greaterThanOrEqualTo(3),
    );
    expect(
      AppColorTokens.contrastRatio(scheme.primary, scheme.primaryContainer),
      greaterThanOrEqualTo(2.4),
    );
  });

  test('player surface stays neutral while controls use accent', () {
    final blue = AppTheme.light(
      accent: const Color(0xFF2563EB),
    ).extension<AppColorTokens>()!;
    final red = AppTheme.light(
      accent: const Color(0xFFDC2626),
    ).extension<AppColorTokens>()!;
    final dark = AppTheme.dark(
      accent: const Color(0xFFDC2626),
    ).extension<AppColorTokens>()!;

    expect(blue.playerSurface, red.playerSurface);
    expect(
      AppColorTokens.contrastRatio(blue.playerSurface, blue.onPlayerSurface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      AppColorTokens.contrastRatio(dark.playerSurface, dark.onPlayerSurface),
      greaterThanOrEqualTo(4.5),
    );
  });

  test(
    'source colors remain distinct and readable in light and dark themes',
    () {
      const sourceIds = [
        'izib',
        'akniga',
        'yakniga',
        'knigavuhe',
        'knigoblud',
        'baza_knig',
      ];
      final schemes = [
        AppTheme.light().colorScheme,
        AppTheme.dark().colorScheme,
      ];

      for (final scheme in schemes) {
        final colors = {
          for (final sourceId in sourceIds) sourceColorForId(sourceId, scheme),
        };
        expect(colors.length, sourceIds.length);
        for (final sourceId in sourceIds) {
          expect(
            AppColorTokens.contrastRatio(
              sourceColorForId(sourceId, scheme),
              scheme.surfaceContainer,
            ),
            greaterThanOrEqualTo(3.2),
            reason: '$sourceId should read on ${scheme.brightness.name} cards',
          );
        }
      }
    },
  );

  test('interactive controls keep minimum touch target size', () {
    final theme = AppTheme.light();
    final states = <WidgetState>{};

    final filledSize = theme.filledButtonTheme.style?.minimumSize?.resolve(
      states,
    );
    final outlinedSize = theme.outlinedButtonTheme.style?.minimumSize?.resolve(
      states,
    );
    final iconSize = theme.iconButtonTheme.style?.minimumSize?.resolve(states);

    expect(filledSize, isNotNull);
    expect(outlinedSize, isNotNull);
    expect(iconSize, isNotNull);
    expect(filledSize!.width, greaterThanOrEqualTo(48));
    expect(filledSize.height, greaterThanOrEqualTo(48));
    expect(outlinedSize!.width, greaterThanOrEqualTo(48));
    expect(outlinedSize.height, greaterThanOrEqualTo(48));
    expect(iconSize!.width, greaterThanOrEqualTo(48));
    expect(iconSize.height, greaterThanOrEqualTo(48));
  });
}
