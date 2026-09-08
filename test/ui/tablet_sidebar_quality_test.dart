import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/adaptive/television_shell.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

// Real navigation shell and production theme; empty in-memory playback keeps
// these regressions independent of plugins, files, network and real app data.
const _purple = Color(0xFF7C3AED);
const _brandKey = ValueKey('wide-navigation-brand');
const _bodyKey = ValueKey('tablet-sidebar-probe');

void main() {
  for (final brightness in Brightness.values) {
    for (final direction in TextDirection.values) {
      for (final size in [const Size(1024, 768), const Size(1280, 800)]) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets('tablet brand stays whole and selected tab readable: '
              '$size $brightness $direction text=$textScale', (tester) async {
            await _pumpShell(
              tester,
              size: size,
              brightness: brightness,
              direction: direction,
              textScale: textScale,
            );
            _expectWholeBrand(tester, textScale: textScale);
            await _expectSelectedColors(tester, wide: true);
            final sidebar = tester.getRect(
              find.byKey(const ValueKey('desktop-navigation-sidebar')),
            );
            if (direction == TextDirection.rtl) {
              expect(sidebar.right, size.width);
            } else {
              expect(sidebar.left, 0);
            }
            expect(
              tester.getSize(find.byKey(_bodyKey)).width,
              greaterThan(500),
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('tablet brand respects system plus app text: $brightness', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        size: const Size(1280, 800),
        brightness: brightness,
        direction: TextDirection.rtl,
        textScale: 2,
        systemTextScale: 1.5,
      );
      _expectWholeBrand(tester, textScale: 3);
      expect(
        find.byKey(const ValueKey('wide-navigation-brand-stacked')),
        findsOneWidget,
      );
      await _expectSelectedColors(tester, wide: true);
      expect(tester.takeException(), isNull);
    });

    for (final width in [480.0, 800.0]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('narrow touch selected icon and label contrast: '
            'width=$width $brightness text=$textScale', (tester) async {
          await _pumpShell(
            tester,
            size: Size(width, 960),
            brightness: brightness,
            textScale: textScale,
          );
          expect(find.byKey(_brandKey), findsNothing);
          await _expectSelectedColors(tester, wide: false);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

void _expectWholeBrand(WidgetTester tester, {required double textScale}) {
  final brand = find.byKey(_brandKey);
  expect(brand, findsOneWidget);
  expect(tester.widget<Text>(brand).data, 'Словофон');
  expect(
    find.ancestor(of: brand, matching: find.byType(FittedBox)),
    findsNothing,
  );
  final paragraph = tester.renderObject<RenderParagraph>(brand);
  final context = tester.element(brand);
  final baseFont = Theme.of(context).textTheme.titleLarge!.fontSize!;
  expect(
    paragraph.textScaler.scale(baseFont),
    closeTo(baseFont * textScale, .01),
  );
  // Measure the complete word at the actual rendered scale, not a clipped or
  // ellipsized Text(maxLines: 1) which could falsely appear to be a single line.
  final painter = TextPainter(
    text: paragraph.text,
    textScaler: paragraph.textScaler,
    textDirection: paragraph.textDirection,
    locale: paragraph.locale,
  )..layout();
  expect(painter.width, lessThanOrEqualTo(paragraph.size.width + .01));
  painter.layout(maxWidth: paragraph.size.width);
  expect(painter.computeLineMetrics(), hasLength(1));
  painter.dispose();
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(paragraph.textDirection, Directionality.of(context));
  expect(DesktopLayout.isActive(context), isFalse);
  expect(TelevisionLayout.isActive(context), isFalse);
  expect(find.byType(TelevisionShell), findsNothing);
}

Future<void> _expectSelectedColors(
  WidgetTester tester, {
  required bool wide,
}) async {
  final selected = find.byKey(
    ValueKey('${wide ? 'wide' : 'mobile'}-navigation-item-4'),
  );
  expect(selected, findsOneWidget);
  // Large-font sidebar navigation remains reachable by touch scrolling.
  await tester.ensureVisible(selected);
  await tester.pumpAndSettle();
  expect(selected.hitTestable(), findsOneWidget);
  final selectedSize = tester.getSize(selected);
  expect(selectedSize.height, greaterThanOrEqualTo(48));
  final context = tester.element(selected);
  final colors = Theme.of(context).colorScheme;
  final container = tester.widget<AnimatedContainer>(
    find.descendant(of: selected, matching: find.byType(AnimatedContainer)),
  );
  final background = (container.decoration! as BoxDecoration).color!;
  final icon = tester.widget<AppIcon>(
    find.descendant(of: selected, matching: find.byType(AppIcon)),
  );
  expect(background, colors.secondaryContainer);
  expect(icon.color, colors.onSecondaryContainer);
  expect(
    AppColorTokens.contrastRatio(icon.color!, background),
    greaterThanOrEqualTo(4.5),
  );
  final inlineLabel = find.descendant(
    of: selected,
    matching: find.text('Настройки'),
  );
  final label = inlineLabel;
  expect(label, findsOneWidget);
  final foreground = tester.widget<Text>(label).style!.color!;
  expect(foreground, wide ? colors.onSecondaryContainer : colors.onSurface);
  expect(
    AppColorTokens.contrastRatio(
      foreground,
      wide ? background : colors.surface,
    ),
    greaterThanOrEqualTo(4.5),
  );
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  double systemTextScale = 1,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final playback = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(playback.dispose);
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            SlovofonShell(navigationShell: shell),
        branches: [
          for (final path in [
            '/',
            '/search',
            '/library',
            '/downloads',
            '/settings',
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) =>
                      const SizedBox.expand(key: _bodyKey),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  final theme = brightness == Brightness.dark
      ? AppTheme.dark(accent: _purple)
      : AppTheme.light(accent: _purple);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playbackControllerProvider.overrideWithValue(playback)],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: theme.copyWith(platform: TargetPlatform.android),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: AppTextScaler(
              TextScaler.linear(systemTextScale),
              textScale,
            ),
            disableAnimations: true,
          ),
          child: TelevisionLayout(
            enabled: false,
            child: Directionality(textDirection: direction, child: child!),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
