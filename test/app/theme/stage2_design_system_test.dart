import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/app_focus_tokens.dart';
import 'package:slovofon/app/theme/app_radii_tokens.dart';
import 'package:slovofon/app/theme/app_spacing_tokens.dart';
import 'package:slovofon/app/theme/app_theme.dart';

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
