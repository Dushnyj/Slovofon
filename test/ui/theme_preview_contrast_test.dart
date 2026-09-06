import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/features/theme_preview/theme_preview_screen.dart';

void main() {
  testWidgets('preview Focus badge uses the readable semantic pair', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final mode in ['light', 'dark', 'amoled']) {
      final base = mode == 'light'
          ? AppTheme.light(accent: const Color(0xff516aa4))
          : AppTheme.dark(
              accent: const Color(0xff516aa4),
              amoled: mode == 'amoled',
            );
      final theme = WindowsTheme.from(
        base,
      ).copyWith(platform: TargetPlatform.windows);
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('$mode-$scale'),
            theme: theme,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(900, 600),
                textScaler: TextScaler.linear(scale),
              ),
              child: const ThemePreviewScreen(),
            ),
          ),
        );
        // The preview deliberately contains an indeterminate loading example.
        // Scroll with finite pumps rather than waiting for it to settle.
        await tester.scrollUntilVisible(
          find.text('Focus'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        final label = find.text('Focus');
        final text = tester.widget<Text>(label);
        final box = tester.widget<DecoratedBox>(
          find.ancestor(of: label, matching: find.byType(DecoratedBox)).first,
        );
        final background = (box.decoration as BoxDecoration).color!;
        final foreground = text.style!.color!;
        expect(background, theme.colorScheme.primary);
        expect(foreground, theme.colorScheme.onPrimary);
        expect(
          AppColorTokens.contrastRatio(background, foreground),
          greaterThanOrEqualTo(4.5),
          reason: '$mode at ${scale * 100}% must keep Focus text readable',
        );
        expect(tester.getRect(label).bottom, lessThanOrEqualTo(600));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
