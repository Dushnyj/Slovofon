import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';
import 'package:slovofon/ui/components/source_badge.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final width in [310.0, 390.0, 430.0]) {
      for (final scale in [0.75, 1.0, 2.0, 3.0]) {
        testWidgets(
          'mobile chrome $platform width=$width actual text scale=$scale',
          (tester) async {
            final scaler = scale == 3
                ? const AppTextScaler(TextScaler.linear(1.5), 2)
                : AppTextScaler(TextScaler.noScaling, scale);
            final controller = await _pumpChrome(
              tester,
              width: width,
              platform: platform,
              scaler: scaler,
            );
            expect(tester.takeException(), isNull);
            _expectActualScale(tester, scaler);
            final title = tester.renderObject<RenderParagraph>(
              find.byKey(const ValueKey('mobile-player-title')),
            );
            final fontSize = title.text.style!.fontSize!;
            expect(
              title.textScaler.scale(fontSize),
              closeTo(fontSize * scale, .001),
            );
            final bar = tester.getRect(find.byType(MiniPlayerBar));
            expect(bar.height, greaterThanOrEqualTo(50));
            expect(bar.height, lessThanOrEqualTo(240));
            final navigation = tester.getRect(
              find.byKey(const ValueKey('mobile-navigation-bar')),
            );
            expect(navigation.top, closeTo(bar.bottom, .01));
            expect(navigation.bottom, lessThanOrEqualTo(700));
            for (var index = 0; index < 5; index++) {
              final item = tester.getSize(
                find.byKey(ValueKey('mobile-navigation-item-$index')),
              );
              expect(item.width, greaterThanOrEqualTo(48));
              expect(item.height, greaterThanOrEqualTo(48));
            }
            for (final button in tester.widgetList<IconButton>(
              find.byType(IconButton),
            )) {
              final size = tester.getSize(find.byWidget(button));
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
            }
            final source = find.descendant(
              of: find.byType(SourceBadge),
              matching: find.byType(Text),
            );
            expect(
              tester.renderObject<RenderParagraph>(source).didExceedMaxLines,
              isFalse,
            );
            await tester.tap(
              find.byKey(const ValueKey('mobile-navigation-item-4')),
            );
            await tester.pumpAndSettle();
            expect(find.text('Настройки'), findsOneWidget);
            expect(
              find.byKey(const ValueKey('mobile-navigation-active-label')),
              findsNothing,
            );
            for (var index = 0; index < 5; index++) {
              expect(
                find.descendant(
                  of: find.byKey(ValueKey('mobile-navigation-item-$index')),
                  matching: find.byKey(
                    ValueKey('mobile-navigation-label-$index'),
                  ),
                ),
                findsOneWidget,
              );
            }
            await tester.tap(find.byTooltip('Следующая глава'));
            await tester.pumpAndSettle();
            expect(controller.state.chapterIndex, 1);
            await tester.tap(find.byTooltip('Слушать'));
            await tester.pumpAndSettle();
            expect(controller.state.isPlaying, isTrue);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final width in [900.0, 1920.0]) {
    for (final scale in [.75, 1.0, 2.0, 3.0]) {
      testWidgets(
        'wide Android chrome width=$width scale=$scale reflows without clipping',
        (tester) async {
          final scaler = scale == 3
              ? const AppTextScaler(TextScaler.linear(1.5), 2)
              : AppTextScaler(TextScaler.noScaling, scale);
          final router = await _pumpWideAndroid(
            tester,
            width: width,
            scaler: scaler,
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('windows-playback-dock')),
            findsNothing,
          );
          final player = find.byKey(const ValueKey('desktop-mini-player-bar'));
          final title = tester.renderObject<RenderParagraph>(
            find.byKey(const ValueKey('wide-player-title')),
          );
          expect(title.textScaler, scaler);
          for (final text in tester.renderObjectList<RenderParagraph>(
            find.descendant(of: player, matching: find.byType(RichText)),
          )) {
            expect(text.textScaler, scaler);
          }
          final source = find.descendant(
            of: find.byType(SourceBadge),
            matching: find.byType(Text),
          );
          expect(
            tester.renderObject<RenderParagraph>(source).didExceedMaxLines,
            isFalse,
          );
          for (var index = 0; index < 5; index++) {
            final item = find.byKey(ValueKey('wide-navigation-item-$index'));
            await tester.ensureVisible(item);
            await tester.pumpAndSettle();
            final text = find.descendant(of: item, matching: find.byType(Text));
            final paragraph = tester.renderObject<RenderParagraph>(text);
            expect(paragraph.textScaler, scaler);
            expect(paragraph.didExceedMaxLines, isFalse);
            expect(
              tester.getSize(item).height,
              greaterThanOrEqualTo(paragraph.size.height + 16),
            );
            expect(tester.getSize(item).height, greaterThanOrEqualTo(48));
          }
          await tester.tap(
            find.byKey(const ValueKey('wide-navigation-item-4')),
          );
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/settings');
          expect(tester.getSize(player).height, lessThan(350));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('wide Android navigation supports keyboard directional focus', (
    tester,
  ) async {
    final router = await _pumpWideAndroid(
      tester,
      scaler: const AppTextScaler(TextScaler.noScaling, 2),
    );
    final homeLabel = find.descendant(
      of: find.byKey(const ValueKey('wide-navigation-item-0')),
      matching: find.byType(Text),
    );
    final homeFocus = Focus.of(tester.element(homeLabel));
    homeFocus.requestFocus();
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, homeFocus);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final searchLabel = find.descendant(
      of: find.byKey(const ValueKey('wide-navigation-item-1')),
      matching: find.byType(Text),
    );
    expect(
      FocusManager.instance.primaryFocus,
      Focus.of(tester.element(searchLabel)),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/search');
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final scale in [2.0, 3.0]) {
      testWidgets(
        'volume popover preserves full percentage at $platform scale=$scale',
        (tester) async {
          final scaler = scale == 3
              ? const AppTextScaler(TextScaler.linear(1.5), 2)
              : const AppTextScaler(TextScaler.noScaling, 2);
          await _pumpWideAndroid(
            tester,
            width: 900,
            scaler: scaler,
            platform: platform,
          );
          await tester.tap(find.byTooltip('Громкость'));
          await tester.pumpAndSettle();
          final percentage = find.byKey(
            const ValueKey('desktop-volume-percentage'),
          );
          expect(tester.widget<Text>(percentage).data, '100%');
          final paragraph = tester.renderObject<RenderParagraph>(percentage);
          expect(paragraph.textScaler, scaler);
          expect(paragraph.didExceedMaxLines, isFalse);
          final panel = tester.getRect(
            find.byKey(const ValueKey('desktop-volume-popover')),
          );
          final text = tester.getRect(percentage);
          expect(panel.contains(text.topLeft), isTrue);
          expect(panel.contains(text.bottomRight), isTrue);
          final slider = find.byKey(const ValueKey('desktop-volume-slider'));
          final sliderRect = tester.getRect(slider);
          expect(sliderRect.width, greaterThanOrEqualTo(111));
          expect(sliderRect.right, lessThanOrEqualTo(text.left - 7));
          await tester.tapAt(sliderRect.center);
          await tester.pumpAndSettle();
          final changedVolume = _readSlider(tester, slider).value;
          expect(changedVolume, greaterThan(0));
          expect(changedVolume, lessThan(1));
          expect(
            tester.renderObject<RenderParagraph>(percentage).didExceedMaxLines,
            isFalse,
          );
          await tester.tap(
            find.byKey(const ValueKey('desktop-volume-mute-button')),
          );
          await tester.pumpAndSettle();
          expect(tester.widget<Text>(percentage).data, '0%');
          expect(
            tester.renderObject<RenderParagraph>(percentage).didExceedMaxLines,
            isFalse,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final selectedIndex in [-1, 5]) {
    for (final scale in [2.0, 3.0]) {
      testWidgets(
        'mobile navigation keeps all destinations without active tab index=$selectedIndex scale=$scale',
        (tester) async {
          await _pumpChrome(
            tester,
            scaler: AppTextScaler(TextScaler.noScaling, scale),
            initialSelectedIndex: selectedIndex,
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey('mobile-navigation-active-label')),
            findsNothing,
          );
          for (var index = 0; index < 5; index++) {
            expect(
              find.byKey(ValueKey('mobile-navigation-item-$index')),
              findsOneWidget,
            );
          }
          await tester.tap(
            find.byKey(const ValueKey('mobile-navigation-item-4')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Настройки'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('mobile chrome preserves a nonlinear composite text scaler', (
    tester,
  ) async {
    const scaler = AppTextScaler(_NonlinearTestScaler(), 2);
    await _pumpChrome(tester, scaler: scaler);
    _expectActualScale(tester, scaler);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text resizes live without shrinking icons or touch targets', (
    tester,
  ) async {
    final controller = PlaybackController(engine: InMemoryAudioEngine());
    addTearDown(controller.dispose);
    await controller.loadBook(_book);
    final scale = ValueNotifier<double>(1);
    addTearDown(scale.dispose);
    await _pumpChrome(tester, controller: controller, liveScale: scale);
    final title = find.byKey(const ValueKey('mobile-player-title'));
    final defaultHeight = tester.getSize(title).height;
    scale.value = 2;
    await tester.pumpAndSettle();
    expect(tester.getSize(title).height, closeTo(defaultHeight * 2, 1));
    scale.value = .75;
    await tester.pumpAndSettle();
    expect(tester.getSize(title).height, closeTo(defaultHeight * .75, 1));
    final playButton = tester.getSize(find.byType(IconButton).first);
    expect(playButton, const Size(48, 48));
    expect(tester.takeException(), isNull);
  });
}

void _expectActualScale(WidgetTester tester, TextScaler scaler) {
  final paragraphs = find.descendant(
    of: find.byType(MiniPlayerBar),
    matching: find.byType(RichText),
  );
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    paragraphs,
  )) {
    expect(paragraph.textScaler, scaler);
    expect(paragraph.textScaler.scale(12), scaler.scale(12));
    expect(paragraph.textScaler.scale(18), scaler.scale(18));
  }
  final navigationText = find.descendant(
    of: find.byKey(const ValueKey('mobile-navigation-bar')),
    matching: find.byType(RichText),
  );
  expect(navigationText, findsWidgets);
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    navigationText,
  )) {
    expect(paragraph.textScaler, scaler);
  }
}

Future<PlaybackController> _pumpChrome(
  WidgetTester tester, {
  double width = 390,
  int initialSelectedIndex = 0,
  TargetPlatform platform = TargetPlatform.android,
  TextScaler scaler = TextScaler.noScaling,
  PlaybackController? controller,
  ValueNotifier<double>? liveScale,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final playback =
      controller ?? PlaybackController(engine: InMemoryAudioEngine());
  if (controller == null) {
    addTearDown(playback.dispose);
    await playback.loadBook(_book);
  }
  var selectedIndex = initialSelectedIndex;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playbackControllerProvider.overrideWith((ref) => playback)],
      child: MaterialApp(
        theme: AppTheme.dark().copyWith(platform: platform),
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) {
          Widget apply(TextScaler textScaler) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          );
          if (liveScale == null) return apply(scaler);
          return ValueListenableBuilder<double>(
            valueListenable: liveScale,
            builder: (context, value, _) =>
                apply(AppTextScaler(TextScaler.noScaling, value)),
          );
        },
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayerBar(),
                SlovofonBottomNavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) =>
                      setState(() => selectedIndex = index),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return playback;
}

Future<GoRouter> _pumpWideAndroid(
  WidgetTester tester, {
  double width = 1920,
  TargetPlatform platform = TargetPlatform.android,
  TextScaler scaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = Size(width, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final playback = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(playback.dispose);
  await playback.loadBook(_book);
  final router = GoRouter(
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
                GoRoute(path: path, builder: (_, _) => const SizedBox.expand()),
              ],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playbackControllerProvider.overrideWith((ref) => playback)],
      child: MaterialApp.router(
        routerConfig: router,
        theme: platform == TargetPlatform.windows
            ? WindowsTheme.from(AppTheme.dark().copyWith(platform: platform))
            : AppTheme.dark().copyWith(platform: platform),
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _NonlinearTestScaler extends TextScaler {
  const _NonlinearTestScaler();
  @override
  double scale(double fontSize) => fontSize * (fontSize <= 14 ? 1.5 : 1.2);
  @override
  double get textScaleFactor => 1.5;
}

const _book = AudioPlaybackBook(
  id: 'text-scale-book',
  versionId: 'text-scale-book-version',
  sourceId: 'knigavuhe',
  sourceName: 'Книга в ухе',
  title: 'Учебная книга',
  author: 'Автор',
  narrator: 'Чтец',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-1',
      index: 1,
      title: 'Начало',
      duration: Duration(minutes: 20),
    ),
    AudioPlaybackChapter(
      id: 'chapter-2',
      index: 2,
      title: 'Продолжение',
      duration: Duration(minutes: 24),
    ),
  ],
);
Slider _readSlider(WidgetTester tester, Finder root) {
  final widget = tester.widget(root);
  if (widget is Slider) return widget;
  return tester.widget<Slider>(
    find.descendant(of: root, matching: find.byType(Slider)),
  );
}
