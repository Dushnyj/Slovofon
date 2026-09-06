import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/ui/components/source_badge.dart';

void main() {
  test('readableOn selects contrasting text for orange gold and mid-grey', () {
    for (final color in [
      const Color(0xFFEA580C),
      const Color(0xFFCA8A04),
      const Color(0xFF767676),
    ]) {
      final foreground = AppColorTokens.readableOn(color);
      expect(
        AppColorTokens.contrastRatio(color, foreground),
        greaterThanOrEqualTo(4.5),
      );
    }
    expect(
      AppColorTokens.readableOn(const Color(0xFFEA580C)),
      const Color(0xFF111418),
    );
    expect(
      AppColorTokens.readableOn(const Color(0xFFCA8A04)),
      const Color(0xFF111418),
    );
    expect(
      AppColorTokens.readableOn(const Color(0xFF7C3AED)),
      const Color(0xFFF8FAFC),
    );
  });

  test(
    'custom HSV accents and complete greyscale never fall below normal-text contrast',
    () {
      final backgrounds = <Color>[
        for (var value = 0; value <= 255; value++)
          Color.fromARGB(255, value, value, value),
        for (var hue = 0.0; hue < 360; hue += 15)
          for (final saturation in [.25, .5, .75, 1.0])
            for (final value in [.25, .5, .75, 1.0])
              HSVColor.fromAHSV(1, hue, saturation, value).toColor(),
      ];
      for (final background in backgrounds) {
        expect(
          AppColorTokens.contrastRatio(
            background,
            AppColorTokens.readableOn(background),
          ),
          greaterThanOrEqualTo(4.5),
          reason: '$background',
        );
      }
    },
  );

  test(
    'light dark AMOLED and TV retain semantic pairs for all accent presets',
    () {
      const accents = [
        Color(0xFF516AA4),
        Color(0xFF1F7A4D),
        Color(0xFF0F766E),
        Color(0xFFB42318),
        Color(0xFF8A5B00),
        Color(0xFF2563EB),
        Color(0xFF15803D),
        Color(0xFF7C3AED),
        Color(0xFFDB2777),
        Color(0xFFDC2626),
        Color(0xFFEA580C),
        Color(0xFFCA8A04),
        Color(0xFF475569),
        Color(0xFF111827),
      ];
      for (final accent in accents) {
        for (final theme in [
          AppTheme.light(accent: accent),
          AppTheme.dark(accent: accent),
          AppTheme.dark(accent: accent, amoled: true),
        ]) {
          final colors = theme.colorScheme;
          for (final pair in [
            (colors.primary, colors.onPrimary),
            (colors.primaryContainer, colors.onPrimaryContainer),
            (colors.secondary, colors.onSecondary),
            (colors.secondaryContainer, colors.onSecondaryContainer),
          ]) {
            expect(
              AppColorTokens.contrastRatio(pair.$1, pair.$2),
              greaterThanOrEqualTo(4.5),
              reason: '$accent ${theme.brightness}',
            );
          }
          for (final source in [
            'izib',
            'akniga',
            'yakniga',
            'knigavuhe',
            'knigoblud',
            'baza_knig',
          ]) {
            expect(
              AppColorTokens.contrastRatio(
                sourceContainerColorForId(source, colors),
                sourceOnContainerColorForId(source, colors),
              ),
              greaterThanOrEqualTo(4.5),
            );
          }
          final tv = TelevisionTheme.from(theme);
          for (final style in [
            tv.filledButtonTheme.style!,
            tv.outlinedButtonTheme.style!,
            tv.textButtonTheme.style!,
            tv.iconButtonTheme.style!,
          ]) {
            final states = <WidgetState>{WidgetState.focused};
            expect(
              AppColorTokens.contrastRatio(
                style.foregroundColor!.resolve(states)!,
                style.backgroundColor!.resolve(states)!,
              ),
              greaterThanOrEqualTo(4.5),
            );
          }
        }
      }
    },
  );
}
