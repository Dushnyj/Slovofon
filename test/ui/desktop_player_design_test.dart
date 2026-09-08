import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:slovofon/ui/motion/motion_tooltip.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/features/player/full_player_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';
import 'package:slovofon/ui/components/playback_source_label.dart';
import 'package:slovofon/ui/components/source_badge.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  for (final width in [1267.0, 1920.0]) {
    for (final scale in [0.9, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Windows book panel balances $width at text $scale dark=$dark',
          (tester) async {
            final fixture = await _Fixture.create(
              author: 'Alexandra Catherine North of the Northern Library',
              narrator: 'Michael Alexander Rivers of the Royal Theatre',
            );
            await fixture.pump(
              tester,
              width: width,
              height: 1200,
              textScale: scale,
              dark: dark,
              fullPlayer: true,
            );
            final panel = find.byKey(
              const ValueKey('windows-player-book-panel'),
            );
            final panelRect = tester.getRect(panel);
            expect(panelRect.width, inInclusiveRange(300, 440));
            if (width == 1920 || scale == 2) {
              expect(panelRect.width, 440);
            }
            for (final name in [
              fixture.controller.state.book!.author,
              fixture.controller.state.book!.narrator,
            ]) {
              final label = find.descendant(
                of: panel,
                matching: find.text(name),
              );
              expect(label, findsOneWidget);
              expect(tester.widget<Text>(label).maxLines, isNull);
              expect(
                tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
                isFalse,
              );
              final labelRect = tester.getRect(label);
              expect(labelRect.left, greaterThanOrEqualTo(panelRect.left));
              expect(labelRect.right, lessThanOrEqualTo(panelRect.right));
            }
            _expectSource(tester, 'windows-full-player-source', 'Akniga');

            final summaryColumns = find.byKey(
              const ValueKey('windows-player-summary-columns'),
            );
            if (width == 1920 && scale == 0.9) {
              expect(summaryColumns, findsOneWidget);
              final overview = tester.getRect(
                find.byKey(const ValueKey('windows-player-overview')),
              );
              final description = tester.getRect(
                find.byKey(const ValueKey('windows-player-description')),
              );
              expect(description.left, greaterThan(overview.right));
              expect(description.top, overview.top);
            } else {
              expect(summaryColumns, findsNothing);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('Windows wider book panel leaves narrow layout usable', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await fixture.pump(tester, width: 900, fullPlayer: true, textScale: 2);
    expect(
      find.byKey(const ValueKey('windows-player-book-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('windows-compact-full-player-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('windows-compact-player-book-details')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('windows-player-summary-columns')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('windows-player-tab-1')));
    await tester.pumpAndSettle();
    final chapter = find.byKey(const ValueKey('full-player-chapter-chapter-2'));
    await tester.ensureVisible(chapter);
    await tester.tap(chapter);
    await tester.pumpAndSettle();
    expect(fixture.controller.state.chapterIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows summary does not invent a description column', (
    tester,
  ) async {
    final fixture = await _Fixture.create(description: null);
    await fixture.pump(tester, width: 1920, fullPlayer: true, textScale: 0.9);
    expect(
      find.byKey(const ValueKey('windows-player-summary-columns')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('windows-player-description')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('windows-nearby-chapter-chapter-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    for (final width in [900.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Windows player fits $width dark=$dark text=$scale', (
          tester,
        ) async {
          final fixture = await _Fixture.create();
          await fixture.pump(
            tester,
            width: width,
            dark: dark,
            textScale: scale,
          );
          expect(
            find.byKey(const ValueKey('windows-playback-dock')),
            findsOneWidget,
          );
          _expectSource(tester, 'windows-dock-source', 'Akniga');
          expect(tester.takeException(), isNull);
          if (width == 1280 && scale == 1) {
            await _capture(tester, 'dock-${dark ? 'dark' : 'light'}.png');
          }
          await tester.tap(
            find.byKey(const ValueKey('desktop-player-book-link')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('windows-full-player')),
            findsOneWidget,
          );
          _expectSource(tester, 'windows-full-player-source', 'Akniga');
          expect(tester.takeException(), isNull);
          if (width == 1280 && scale == 1) {
            await _capture(
              tester,
              'full-player-${dark ? 'dark' : 'light'}.png',
            );
          }
          fixture.controller.setSleepTimer(const Duration(minutes: 30));
          await tester.pump();
          expect(
            find.byKey(const ValueKey('sleep-timer-pill')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('windows-player-tab-1')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text('The road beyond the old observatory'),
            findsWidgets,
          );
          await tester.tap(find.byTooltip('Sleep timer'));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('windows-player-options')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final locale in [const Locale('ru'), const Locale('en')]) {
    for (final width in [900.0, 1920.0]) {
      testWidgets('Windows playback source follows book at $width $locale', (
        tester,
      ) async {
        final fixture = await _Fixture.create();
        await fixture.pump(
          tester,
          width: width,
          locale: locale,
          textScale: 1.5,
        );
        final strings = AppStrings.forLocale(locale);
        for (final sourceId in [
          'akniga',
          'izib',
          'knigavuhe',
          'baza_knig',
          'knigoblud',
          'yakniga',
        ]) {
          final previous = fixture.controller.state.book!;
          await fixture.controller.loadBook(
            AudioPlaybackBook(
              id: 'book-$sourceId',
              versionId: 'version-$sourceId',
              sourceId: sourceId,
              // Display uses the existing localized registry, not stored text.
              sourceName: 'Stored source name',
              title: previous.title,
              author: previous.author,
              narrator: previous.narrator,
              chapters: previous.chapters,
            ),
          );
          await tester.pumpAndSettle();
          final label = strings.sourceDisplayName(sourceId);
          _expectSource(tester, 'windows-dock-source', label);
          await tester.tap(
            find.byKey(const ValueKey('desktop-player-book-link')),
          );
          await tester.pumpAndSettle();
          _expectSource(tester, 'windows-full-player-source', label);
          fixture.router.pop();
          await tester.pumpAndSettle();
          _expectSource(tester, 'windows-dock-source', label);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('Windows playback source preserves an unknown source name', (
    tester,
  ) async {
    final fixture = await _Fixture.create(
      sourceId: 'custom-source',
      sourceName: 'Personal audio library',
    );
    await fixture.pump(tester);
    _expectSource(tester, 'windows-dock-source', 'Personal audio library');
    await tester.tap(find.byKey(const ValueKey('desktop-player-book-link')));
    await tester.pumpAndSettle();
    _expectSource(
      tester,
      'windows-full-player-source',
      'Personal audio library',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows full player refreshes its source while already open', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await fixture.pump(tester, fullPlayer: true);
    _expectSource(tester, 'windows-full-player-source', 'Akniga');
    final previous = fixture.controller.state.book!;
    await fixture.controller.loadBook(
      AudioPlaybackBook(
        id: 'replacement-book',
        versionId: 'replacement-version',
        sourceId: 'izib',
        sourceName: 'Izib',
        title: previous.title,
        author: previous.author,
        narrator: previous.narrator,
        chapters: previous.chapters,
      ),
    );
    await tester.pumpAndSettle();
    _expectSource(tester, 'windows-full-player-source', 'Izib');
    expect(find.text('Akniga'), findsNothing);
    fixture.router.go('/');
    await tester.pumpAndSettle();
    _expectSource(tester, 'windows-dock-source', 'Izib');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows source label is absent without a loaded book', (
    tester,
  ) async {
    final fixture = await _Fixture.create(loadBook: false);
    await fixture.pump(tester);
    expect(find.byKey(const ValueKey('windows-dock-source')), findsNothing);
    expect(find.byKey(const ValueKey('windows-playback-dock')), findsNothing);
    fixture.router.go('/player');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('windows-full-player-source')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows narrow dock keeps full timestamps and seek at 260%', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await fixture.controller.seek(const Duration(minutes: 10));
    await fixture.pump(tester, width: 900, textScale: 2.6);
    final seek = find.byKey(const ValueKey('desktop-player-seek'));
    expect(tester.getSize(seek).width, greaterThanOrEqualTo(120));
    for (final timestamp in ['10:00', '20:00']) {
      final text = find.text(timestamp);
      expect(text, findsOneWidget);
      expect(
        tester.getTopLeft(text).dy,
        greaterThan(tester.getTopLeft(seek).dy),
      );
    }
    _readSlider(tester, seek).onChangeEnd!(0.75);
    await tester.pumpAndSettle();
    expect(fixture.controller.state.position, const Duration(minutes: 15));
    expect(find.text('15:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop dock keeps transport, volume and route controls usable',
    (tester) async {
      final fixture = await _Fixture.create();
      await fixture.pump(tester);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(fixture.controller.state.isPlaying, isTrue);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(fixture.controller.state.isPlaying, isFalse);
      await tester.tap(find.byTooltip('Next chapter'));
      await tester.pumpAndSettle();
      expect(fixture.controller.state.chapterIndex, 1);
      await tester.tap(find.byTooltip('Previous chapter'));
      await tester.pumpAndSettle();
      expect(fixture.controller.state.chapterIndex, 0);
      final seek = _readSlider(
        tester,
        find.byKey(const ValueKey('desktop-player-seek')),
      );
      seek.onChanged!(0.5);
      await tester.pump();
      expect(fixture.controller.state.position, Duration.zero);
      seek.onChangeEnd!(0.5);
      await tester.pumpAndSettle();
      expect(fixture.controller.state.position, const Duration(minutes: 10));
      await tester.tap(find.byTooltip('Volume'));
      await tester.pumpAndSettle();
      final volume = _readSlider(
        tester,
        find.byKey(const ValueKey('desktop-volume-slider')),
      );
      volume.onChanged!(0.35);
      await tester.pumpAndSettle();
      expect(fixture.controller.state.volume, 0.35);
      await tester.tap(
        find.byKey(const ValueKey('desktop-volume-mute-button')),
      );
      await tester.pumpAndSettle();
      expect(fixture.controller.state.volume, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chapters'));
      await tester.pumpAndSettle();
      expect(fixture.router.state.uri.toString(), '/player?tab=chapters');
      final tabs = tester.widget<TabBarView>(find.byType(TabBarView));
      expect(tabs.controller!.index, 1);
      expect(tabs.physics, isA<NeverScrollableScrollPhysics>());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Windows full player uses dialogs, labeled tabs and non-dismissable seek',
    (tester) async {
      final fixture = await _Fixture.create();
      await fixture.pump(tester, fullPlayer: true);
      final slider = tester.getRect(
        find.byKey(const ValueKey('windows-full-player-seek')),
      );
      await tester.dragFrom(
        Offset(slider.left + 30, slider.center.dy),
        const Offset(240, 0),
      );
      await tester.pumpAndSettle();
      expect(fixture.router.state.uri.path, '/player');
      expect(fixture.controller.state.position, greaterThan(Duration.zero));
      await tester.tap(find.byKey(const ValueKey('windows-player-speed')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.byKey(const ValueKey('windows-player-options')),
        findsOneWidget,
      );
      await tester.tap(find.text('1.50x'));
      await tester.pumpAndSettle();
      expect(fixture.controller.state.speed, 1.5);
      await tester.tap(find.byTooltip('Sleep timer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Until chapter ends'));
      await tester.pump();
      expect(
        fixture.controller.state.sleepTimerMode,
        SleepTimerMode.stopAtChapterEnd,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Windows overview shows real book progress and playable nearby chapters',
    (tester) async {
      final fixture = await _Fixture.create();
      await fixture.controller.seek(const Duration(minutes: 10));
      await fixture.pump(tester, fullPlayer: true);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('windows-player-book-progress')),
      );
      expect(progress.value, closeTo(10 / 44, 0.0001));
      expect(find.text('10:00 / 44:00'), findsOneWidget);
      final next = find.byKey(
        const ValueKey('windows-nearby-chapter-chapter-2'),
      );
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(fixture.controller.state.chapterIndex, 1);
      expect(fixture.controller.state.isPlaying, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final configuration in [
    (TargetPlatform.android, 1280.0),
    (TargetPlatform.android, 430.0),
  ]) {
    testWidgets('keeps original full player for $configuration', (
      tester,
    ) async {
      final fixture = await _Fixture.create();
      await fixture.pump(
        tester,
        platform: configuration.$1,
        width: configuration.$2,
        fullPlayer: true,
      );
      expect(find.byKey(const ValueKey('windows-full-player')), findsNothing);
      expect(
        find.byKey(const ValueKey('windows-full-player-source')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('windows-full-player-controls')),
        findsNothing,
      );
      expect(find.byType(TabBarView), findsOneWidget);
      await tester.tap(find.byTooltip('Sleep timer'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.byKey(const ValueKey('windows-player-options')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'desktop control focus is visible and reduced motion is honored',
    (tester) async {
      final fixture = await _Fixture.create();
      await fixture.pump(tester);
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Next chapter',
        ),
      );
      final colors = Theme.of(
        tester.element(find.byTooltip('Next chapter')),
      ).colorScheme;
      // System reduced motion permits a short colour fade, never movement.
      expect(button.style!.animationDuration, const Duration(milliseconds: 80));
      expect(
        button.style!.side!.resolve({WidgetState.focused})!.color,
        colors.primary,
      );
      expect(
        button.style!.foregroundColor!.resolve({}),
        colors.onSurfaceVariant,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      fixture.router.go('/player');
      await tester.pumpAndSettle();
      final tab = tester.widget<TextButton>(
        find.byKey(const ValueKey('windows-player-tab-1')),
      );
      // The selected tab colour may fade briefly in Reduced; the page itself
      // must still switch without horizontal movement.
      expect(tab.style!.animationDuration, const Duration(milliseconds: 80));
      expect(
        tester
            .widget<TabBarView>(find.byType(TabBarView))
            .controller!
            .animationDuration,
        Duration.zero,
      );
      await tester.tap(find.byKey(const ValueKey('windows-player-tab-1')));
      await tester.pump();
      expect(
        tester
            .widget<TabBarView>(find.byType(TabBarView))
            .controller!
            .indexIsChanging,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

void _expectSource(WidgetTester tester, String key, String label) {
  final source = find.byKey(ValueKey(key));
  expect(source, findsOneWidget);
  final text = find.descendant(of: source, matching: find.text(label));
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  expect(paragraph.didExceedMaxLines, isFalse);
  final sourceId = tester.widget<PlaybackSourceLabel>(source).sourceId;
  final expectedColor = sourceColorForId(
    sourceId,
    Theme.of(tester.element(source)).colorScheme,
  );
  expect(tester.widget<Text>(text).style!.color, expectedColor);
  expect(paragraph.text.style!.color, expectedColor);
  expect(
    find.descendant(of: source, matching: find.byType(AppIcon)),
    findsNothing,
  );
  expect(
    find.descendant(of: source, matching: find.byType(Icon)),
    findsNothing,
  );
  expect(
    find.descendant(
      of: source,
      matching: find.byWidgetPredicate(
        (widget) => widget is AppTooltip && widget.message == label,
      ),
    ),
    findsOneWidget,
  );
}

class _Fixture {
  _Fixture(this.controller, this.manager);

  final PlaybackController controller;
  final DownloadManager manager;
  late GoRouter router;

  static Future<_Fixture> create({
    bool loadBook = true,
    String sourceId = 'akniga',
    String sourceName = 'Akniga',
    String author = 'Alexandra North',
    String narrator = 'Michael Rivers',
    String? description =
        'A quiet journey through forgotten cities, old maps and the '
        'stories that bring us home. An audiobook to return to, one chapter at a time.',
  }) async {
    final controller = PlaybackController(engine: InMemoryAudioEngine());
    final book = AudioPlaybackBook(
      id: 'desktop-design-book',
      versionId: 'desktop-design-version',
      sourceId: sourceId,
      sourceName: sourceName,
      title: 'The Library at the Edge of the World',
      author: author,
      narrator: narrator,
      description: description,
      chapters: const [
        AudioPlaybackChapter(
          id: 'chapter-1',
          index: 1,
          title: 'The road beyond the old observatory',
          duration: Duration(minutes: 20),
        ),
        AudioPlaybackChapter(
          id: 'chapter-2',
          index: 2,
          title: 'The letter and the map',
          duration: Duration(minutes: 24),
        ),
      ],
    );
    if (loadBook) {
      await controller.loadBook(book);
    }
    final manager = DownloadManager(
      client: _NoNetworkClient(),
      storage: FileDownloadStorage(
        rootDirectory: Directory(
          '${Directory.systemTemp.path}/slovofon-desktop-design-no-io',
        ),
      ),
      persistence: MemoryDownloadPersistenceStore(),
    );
    return _Fixture(controller, manager);
  }

  Future<void> pump(
    WidgetTester tester, {
    double width = 1280,
    double height = 820,
    bool dark = false,
    double textScale = 1,
    TargetPlatform platform = TargetPlatform.windows,
    bool fullPlayer = false,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    router = GoRouter(
      initialLocation: fullPlayer ? '/player' : '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Column(
              children: [
                Expanded(child: SizedBox()),
                DesktopMiniPlayerBar(),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/player',
          builder: (context, state) => FullPlayerScreen(
            initialTabIndex: state.uri.queryParameters['tab'] == 'chapters'
                ? 1
                : 0,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackControllerProvider.overrideWith((ref) {
            ref.onDispose(controller.dispose);
            return controller;
          }),
          downloadManagerProvider.overrideWith((ref) {
            ref.onDispose(manager.dispose);
            return manager;
          }),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: platform == TargetPlatform.windows && width >= 900
              ? WindowsTheme.from(
                  (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                    platform: platform,
                  ),
                )
              : (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                  platform: platform,
                ),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: const ValueKey('desktop-player-capture'),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _NoNetworkClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('Desktop visual tests must not download media');
}

Future<void> _capture(WidgetTester tester, String filename) async {
  final directory = Platform.environment['SLOVOFON_PLAYER_CAPTURE_DIR'];
  if (directory == null) {
    return;
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('desktop-player-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$filename').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Slider _readSlider(WidgetTester tester, Finder root) {
  final widget = tester.widget(root);
  if (widget is Slider) return widget;
  return tester.widget<Slider>(
    find.descendant(of: root, matching: find.byType(Slider)),
  );
}
