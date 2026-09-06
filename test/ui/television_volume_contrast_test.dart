import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/components/desktop_volume_control.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  for (final dark in [false, true]) {
    for (final accent in [
      const Color(0xFF7C3AED),
      AppColorTokens.defaultAccent,
    ]) {
      testWidgets('TV volume focus foreground dark=$dark accent=$accent', (
        tester,
      ) async {
        final theme = TelevisionTheme.from(
          (dark
                  ? AppTheme.dark(accent: accent)
                  : AppTheme.light(accent: accent))
              .copyWith(platform: TargetPlatform.android),
        );
        var muteCount = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => TelevisionLayout(
              enabled: true,
              child: TelevisionViewport(child: child!),
            ),
            home: Scaffold(
              body: Center(
                child: DesktopVolumeControl(
                  volume: .5,
                  onToggleMute: () => muteCount++,
                  onVolumeChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final anchor = find.byTooltip('Volume');
        final anchorButton = find.ancestor(
          of: anchor,
          matching: find.byType(IconButton),
        );
        _focus(tester, anchorButton);
        await tester.pumpAndSettle();
        _expectFocusedPair(tester, anchorButton, theme.colorScheme);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        final mute = find.byKey(const ValueKey('desktop-volume-mute-button'));
        _focus(tester, mute);
        await tester.pumpAndSettle();
        _expectFocusedPair(tester, mute, theme.colorScheme);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(muteCount, 1);
        final percentage = find.byKey(
          const ValueKey('desktop-volume-percentage'),
        );
        final textColor = tester.widget<Text>(percentage).style!.color!;
        expect(
          AppColorTokens.contrastRatio(
            textColor,
            theme.colorScheme.surfaceContainerHigh,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

void _focus(WidgetTester tester, Finder button) {
  final root = tester.element(button);
  final focus = FocusManager.instance.rootScope.descendants.firstWhere((node) {
    if (!node.canRequestFocus || node.context == null) return false;
    var inside = identical(node.context, root);
    node.context!.visitAncestorElements((element) {
      if (identical(element, root)) inside = true;
      return !inside;
    });
    return inside;
  });
  focus.requestFocus();
}

void _expectFocusedPair(
  WidgetTester tester,
  Finder button,
  ColorScheme colors,
) {
  final icon = find.descendant(of: button, matching: find.byType(AppIcon));
  final actualIcon = tester.widget<AppIcon>(icon);
  final foreground =
      actualIcon.color ?? IconTheme.of(tester.element(icon)).color!;
  final material = find.descendant(of: button, matching: find.byType(Material));
  final background = tester.widget<Material>(material.last).color!;
  expect(background, colors.primary);
  expect(foreground, colors.onPrimary);
  expect(
    AppColorTokens.contrastRatio(foreground, background),
    greaterThanOrEqualTo(3),
  );
}
