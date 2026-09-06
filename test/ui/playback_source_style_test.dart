import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
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
import 'package:slovofon/ui/components/source_badge.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

const _sources = [
  'izib',
  'akniga',
  'yakniga',
  'knigavuhe',
  'knigoblud',
  'baza_knig',
];

enum _Surface {
  androidMini(
    TargetPlatform.android,
    390,
    false,
    false,
    'mobile-player-source',
  ),
  androidWideMini(
    TargetPlatform.android,
    1280,
    false,
    false,
    'wide-player-source',
  ),
  windowsDock(
    TargetPlatform.windows,
    1280,
    false,
    false,
    'windows-dock-source',
  ),
  androidFull(
    TargetPlatform.android,
    390,
    true,
    false,
    'mobile-full-player-source',
  ),
  androidWideFull(
    TargetPlatform.android,
    1280,
    true,
    false,
    'mobile-full-player-source',
  ),
  windowsFull(
    TargetPlatform.windows,
    1280,
    true,
    false,
    'windows-full-player-source',
  ),
  androidInfo(
    TargetPlatform.android,
    390,
    true,
    true,
    'full-player-info-source',
  ),
  androidWideInfo(
    TargetPlatform.android,
    1280,
    true,
    true,
    'full-player-info-source',
  ),
  windowsInfo(
    TargetPlatform.windows,
    1280,
    true,
    true,
    'full-player-info-source',
  );

  const _Surface(
    this.platform,
    this.width,
    this.full,
    this.info,
    this.labelKey,
  );
  final TargetPlatform platform;
  final double width;
  final bool full;
  final bool info;
  final String labelKey;
}

void main() {
  for (final surface in _Surface.values) {
    for (final dark in [false, true]) {
      testWidgets(
        'all playback source names use source colors on $surface dark=$dark systemText=200%',
        (tester) async {
          final controller = await _pumpPlayer(tester, surface, dark: dark);
          String? previousName;
          for (final sourceId in _sources) {
            // Replace the book while this exact player / tab remains mounted.
            // The stored name is deliberately stale: known IDs use localization.
            await controller.loadBook(_book(sourceId));
            await tester.pumpAndSettle();
            final label = find.byKey(ValueKey(surface.labelKey));
            expect(label, findsOneWidget);
            await tester.ensureVisible(label);
            await tester.pumpAndSettle();
            final name = AppStrings.of(
              tester.element(label),
            ).sourceDisplayName(sourceId);
            _expectSourceStyle(tester, label, sourceId, name);
            if (previousName != null) {
              expect(
                find.descendant(of: label, matching: find.text(previousName)),
                findsNothing,
              );
            }
            previousName = name;
            if (surface.info) {
              final tile = find.ancestor(
                of: label,
                matching: find.byType(ListTile),
              );
              expect(tile, findsOneWidget);
              expect(tester.widget<ListTile>(tile).leading, isNull);
            }
            // Also reject a source icon moved just outside the label itself.
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is AppIcon &&
                    widget.asset == AppIconAssets.bookSource,
              ),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'unknown source keeps its own name and fallback color in info dark=$dark',
      (tester) async {
        final controller = await _pumpPlayer(
          tester,
          _Surface.windowsInfo,
          dark: dark,
        );
        await controller.loadBook(
          _book('custom-source', sourceName: '  Personal library  '),
        );
        await tester.pumpAndSettle();
        final label = find.byKey(const ValueKey('full-player-info-source'));
        await tester.ensureVisible(label);
        await tester.pumpAndSettle();
        _expectSourceStyle(tester, label, 'custom-source', 'Personal library');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _expectSourceStyle(
  WidgetTester tester,
  Finder label,
  String sourceId,
  String name,
) {
  final text = find.descendant(of: label, matching: find.byType(Text));
  expect(text, findsOneWidget);
  final widget = tester.widget<Text>(text);
  expect(widget.data, name);
  final expectedColor = sourceColorForId(
    sourceId,
    Theme.of(tester.element(label)).colorScheme,
  );
  expect(widget.style!.color, expectedColor);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  expect(paragraph.text.style!.color, expectedColor);
  expect(paragraph.didExceedMaxLines, isFalse);
  final fontSize = widget.style!.fontSize!;
  expect(paragraph.textScaler.scale(fontSize), closeTo(fontSize * 2, .001));
  expect(
    find.descendant(of: label, matching: find.byType(AppIcon)),
    findsNothing,
  );
  expect(find.descendant(of: label, matching: find.byType(Icon)), findsNothing);
  expect(
    find.descendant(of: label, matching: find.textContaining('Источник:')),
    findsNothing,
  );
  expect(
    find.descendant(of: label, matching: find.textContaining('Source:')),
    findsNothing,
  );
}

Future<PlaybackController> _pumpPlayer(
  WidgetTester tester,
  _Surface surface, {
  required bool dark,
}) async {
  tester.view.physicalSize = Size(surface.width, 1000);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(controller.dispose);
  await controller.loadBook(_book('akniga'));
  final manager = DownloadManager(
    client: _NoNetworkClient(),
    storage: FileDownloadStorage(
      rootDirectory: Directory('unused-source-style-test-storage'),
    ),
    persistence: MemoryDownloadPersistenceStore(),
  );
  final router = GoRouter(
    initialLocation: surface.full ? '/player' : '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: surface.width < 900
              ? const MiniPlayerBar()
              : const DesktopMiniPlayerBar(),
        ),
      ),
      GoRoute(
        path: '/player',
        builder: (_, _) =>
            FullPlayerScreen(initialTabIndex: surface.info ? 3 : 0),
      ),
    ],
  );
  addTearDown(router.dispose);
  var theme = (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
    platform: surface.platform,
  );
  if (surface.platform == TargetPlatform.windows) {
    theme = WindowsTheme.from(theme);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith((ref) => controller),
        downloadManagerProvider.overrideWith((ref) => manager),
      ],
      child: MaterialApp.router(
        theme: theme,
        locale: const Locale('ru'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        // Do not substitute a synthetic text scaler: exercise system 200%.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

AudioPlaybackBook _book(
  String sourceId, {
  String sourceName = 'Outdated cached source name',
}) => AudioPlaybackBook(
  id: 'source-style-book-$sourceId',
  versionId: 'source-style-version-$sourceId',
  sourceId: sourceId,
  sourceName: sourceName,
  title: 'Тестовая книга',
  author: 'Автор',
  narrator: 'Чтец',
  description: 'Описание тестовой книги без сетевых запросов.',
  chapters: const [
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

class _NoNetworkClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('Source style tests must not download media');
}
