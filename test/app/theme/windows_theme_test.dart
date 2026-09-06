import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/windows_theme.dart';

void main() {
  for (final accent in [
    const Color(0xff516aa4),
    const Color(0xff0f766e),
    const Color(0xff1f7a4d),
    const Color(0xff8a5b00),
    const Color(0xffb42318),
    const Color(0xffffffff),
    const Color(0xff000000),
  ]) {
    for (final mode in ['light', 'dark', 'amoled']) {
      test('Windows readable surfaces and unchanged accent $mode $accent', () {
        final base = mode == 'light'
            ? AppTheme.light(accent: accent)
            : AppTheme.dark(accent: accent, amoled: mode == 'amoled');
        final theme = WindowsTheme.from(base);
        final scheme = theme.colorScheme;
        expect(
          theme.extension<AppColorTokens>()!.accent,
          base.extension<AppColorTokens>()!.accent,
        );
        expect(
          AppColorTokens.contrastRatio(
            scheme.primary,
            scheme.surfaceContainerHighest,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(theme.textTheme.bodyMedium!.fontFamily, 'Segoe UI');
        for (final surface in [
          scheme.surface,
          scheme.surfaceContainerLowest,
          scheme.surfaceContainerLow,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        ]) {
          for (final foreground in [
            scheme.onSurface,
            scheme.onSurfaceVariant,
          ]) {
            expect(
              AppColorTokens.contrastRatio(surface, foreground),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
        expect(
          AppColorTokens.contrastRatio(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
        );
        final tokens = theme.extension<AppColorTokens>()!;
        expect(tokens.playerSurface, scheme.surfaceContainerLowest);
        expect(
          AppColorTokens.contrastRatio(
            tokens.playerSurface,
            tokens.onPlayerSurface,
          ),
          greaterThanOrEqualTo(4.5),
        );
        if (mode == 'amoled') expect(scheme.surface.toARGB32(), 0xff000000);
        // Local transformation must not mutate the original mobile ThemeData.
        expect(base.textTheme.bodyMedium!.fontFamily, isNot('Segoe UI'));
      });
    }
  }
}
