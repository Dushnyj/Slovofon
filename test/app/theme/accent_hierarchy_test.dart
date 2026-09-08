import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/app_focus_tokens.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/ui/components/app_buttons.dart';
import 'package:slovofon/ui/components/source_badge.dart';
import 'package:slovofon/ui/components/state_placeholder.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  const accents = [
    Color(0xFF3969D8),
    Color(0xFF7C3AED),
    Color(0xFF1F7A4D),
    Color(0xFF0F766E),
    Color(0xFFB42318),
    Color(0xFF8A5B00),
    Color(0xFFFFEC00),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFF777777),
    Color(0xFF00FF7F),
    Color(0xFFFF00FF),
  ];
  const selected = {WidgetState.selected};
  const focused = {WidgetState.focused};
  const hovered = {WidgetState.hovered};
  const normal = <WidgetState>{};

  testWidgets(
    'error placeholder keeps semantic error color with a green accent',
    (tester) async {
      for (final theme in [
        AppTheme.light(accent: const Color(0xFF1F7A4D)),
        AppTheme.dark(accent: const Color(0xFF1F7A4D)),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(body: StatePlaceholder.error(title: 'Error')),
          ),
        );
        await tester.pumpAndSettle();
        final icon = tester.widget<AppIcon>(find.byType(AppIcon));
        expect(icon.asset, AppIconAssets.systemWarning);
        expect(icon.color, theme.colorScheme.error);
        expect(icon.color, isNot(theme.colorScheme.primary));
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final platform in ['phone', 'windows', 'tv']) {
    for (final mode in ['light', 'dark', 'amoled']) {
      for (final highContrast in [false, true]) {
        test('accent hierarchy $platform / $mode / HC=$highContrast', () {
          for (final accent in accents) {
            final base = mode == 'light'
                ? AppTheme.light(accent: accent, highContrast: highContrast)
                : AppTheme.dark(
                    accent: accent,
                    highContrast: highContrast,
                    amoled: mode == 'amoled',
                  );
            final theme = switch (platform) {
              'windows' => WindowsTheme.from(base),
              'tv' => TelevisionTheme.from(base),
              _ => base,
            };
            final colors = theme.colorScheme;
            final tokens = theme.extension<AppColorTokens>()!;
            final focus = theme.extension<AppFocusTokens>()!;
            expect(
              tokens.accent,
              accent,
              reason: 'Never modify the saved swatch',
            );
            expect(tokens.highContrast, highContrast);
            expect(tokens.primary, colors.primary);
            expect(tokens.primaryContainer, colors.primaryContainer);
            expect(tokens.selected, colors.secondaryContainer);
            expect(focus.color, colors.primary);
            expect(focus.selectedColor, colors.secondaryContainer);
            expect(theme.listTileTheme.iconColor, colors.primary);
            expect(
              theme.listTileTheme.selectedTileColor,
              colors.secondaryContainer,
            );
            expect(theme.tabBarTheme.labelColor, colors.primary);
            expect(theme.tabBarTheme.indicatorColor, colors.primary);
            expect(
              theme.navigationBarTheme.indicatorColor,
              colors.secondaryContainer,
            );
            expect(theme.progressIndicatorTheme.color, colors.primary);
            expect(theme.sliderTheme.activeTrackColor, colors.primary);
            expect(theme.sliderTheme.thumbColor, colors.primary);
            expect(theme.textSelectionTheme.cursorColor, colors.primary);
            expect(
              theme.checkboxTheme.fillColor!.resolve(selected),
              colors.primary,
            );
            expect(
              theme.radioTheme.fillColor!.resolve(selected),
              colors.primary,
            );
            expect(
              theme.switchTheme.trackColor!.resolve(selected),
              colors.primary,
            );
            expect(
              theme.switchTheme.thumbColor!.resolve(selected),
              colors.onPrimary,
            );
            for (final surface in [
              colors.surface,
              colors.surfaceBright,
              colors.surfaceDim,
              colors.surfaceContainerLowest,
              colors.surfaceContainerLow,
              colors.surfaceContainer,
              colors.surfaceContainerHigh,
              colors.surfaceContainerHighest,
              tokens.playerSurface,
            ]) {
              expect(
                AppColorTokens.contrastRatio(colors.primary, surface),
                greaterThanOrEqualTo(highContrast ? 7 : 4.5),
                reason: '$accent links and focus must read on $surface',
              );
            }
            for (final (background, foreground) in [
              (colors.primary, colors.onPrimary),
              (colors.primaryContainer, colors.onPrimaryContainer),
              (colors.secondaryContainer, colors.onSecondaryContainer),
              (colors.error, colors.onError),
              (colors.inverseSurface, colors.inversePrimary),
              (colors.secondaryContainer, colors.onSurface),
              (colors.secondaryContainer, colors.onSurfaceVariant),
            ]) {
              expect(
                AppColorTokens.contrastRatio(background, foreground),
                greaterThanOrEqualTo(4.5),
                reason: '$accent readable role pair',
              );
            }
            for (final style in [
              theme.outlinedButtonTheme.style!,
              theme.textButtonTheme.style!,
              theme.iconButtonTheme.style!,
            ]) {
              final foreground = style.foregroundColor!.resolve(focused)!;
              final background = style.backgroundColor!.resolve(focused)!;
              expect(
                AppColorTokens.contrastRatio(background, foreground),
                greaterThanOrEqualTo(4.5),
              );
            }
            if (platform == 'tv') {
              expect(
                theme.filledButtonTheme.style!.backgroundColor!.resolve(normal),
                colors.primary,
              );
              expect(
                theme.filledButtonTheme.style!.foregroundColor!.resolve(normal),
                colors.onPrimary,
              );
              expect(
                theme.filledButtonTheme.style!.side!.resolve(focused)!.color,
                colors.onPrimary,
              );
            } else {
              expect(
                theme.textButtonTheme.style!.backgroundColor!.resolve(hovered),
                colors.secondaryContainer,
              );
            }
          }
        });
      }
    }
  }

  test(
    'accent changes never recolor reading surfaces, errors or source identity',
    () {
      for (final mode in ['light', 'dark', 'amoled']) {
        for (final platform in ['phone', 'windows', 'tv']) {
          final themes = accents.take(6).map((accent) {
            final base = mode == 'light'
                ? AppTheme.light(accent: accent)
                : AppTheme.dark(accent: accent, amoled: mode == 'amoled');
            return switch (platform) {
              'windows' => WindowsTheme.from(base),
              'tv' => TelevisionTheme.from(base),
              _ => base,
            };
          }).toList();
          final first = themes.first;
          for (final theme in themes.skip(1)) {
            final a = first.colorScheme;
            final b = theme.colorScheme;
            expect(b.surface, a.surface);
            expect(b.surfaceContainerHighest, a.surfaceContainerHighest);
            expect(b.onSurface, a.onSurface);
            expect(b.error, a.error);
            expect(
              theme.extension<AppColorTokens>()!.playerSurface,
              first.extension<AppColorTokens>()!.playerSurface,
            );
            for (final source in [
              'izib',
              'akniga',
              'yakniga',
              'knigavuhe',
              'knigoblud',
              'baza_knig',
            ]) {
              expect(sourceColorForId(source, b), sourceColorForId(source, a));
            }
          }
        }
      }
    },
  );

  test(
    'grayscale accents stay grayscale instead of becoming saturated red',
    () {
      for (final seed in [
        const Color(0xFF000000),
        const Color(0xFF777777),
        const Color(0xFFFFFFFF),
      ]) {
        for (final theme in [
          AppTheme.light(accent: seed),
          AppTheme.dark(accent: seed),
        ]) {
          final tone = theme.colorScheme.primary;
          expect(tone.r, tone.g);
          expect(tone.g, tone.b);
        }
      }
    },
  );

  testWidgets('quiet action shows accent and visible keyboard/hover feedback', (
    tester,
  ) async {
    final theme = WindowsTheme.from(
      AppTheme.dark(accent: const Color(0xFF7C3AED)),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AppIconActionButton(
            tooltip: 'Action',
            iconAsset: AppIconAssets.systemMore,
            onPressed: () {},
          ),
        ),
      ),
    );
    final style = tester.widget<IconButton>(find.byType(IconButton)).style!;
    expect(style.foregroundColor!.resolve(normal), theme.colorScheme.primary);
    expect(
      style.backgroundColor!.resolve(hovered),
      theme.colorScheme.secondaryContainer,
    );
    expect(
      style.foregroundColor!.resolve(hovered),
      theme.colorScheme.onSecondaryContainer,
    );
    expect(style.backgroundColor!.resolve(focused), theme.colorScheme.primary);
    expect(
      style.foregroundColor!.resolve(focused),
      theme.colorScheme.onPrimary,
    );
    expect(
      style.foregroundColor!.resolve({WidgetState.disabled}),
      theme.colorScheme.onSurface.withValues(alpha: .38),
    );
    expect(tester.takeException(), isNull);
  });
}
