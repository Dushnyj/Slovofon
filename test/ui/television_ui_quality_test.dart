import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/core/platform/app_device_profile.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/adaptive/television_metrics.dart';
import 'package:slovofon/ui/adaptive/television_shell.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/playback_source_label.dart';
import 'package:slovofon/ui/components/television_book_card.dart';

import 'test_search_history_store.dart';

const _playbackBook = AudioPlaybackBook(
  id: 'tv-book',
  versionId: 'tv-version',
  sourceId: 'izib',
  sourceBookId: 'tv-book',
  sourceName: 'Izib',
  title: 'A journey',
  author: 'Author',
  narrator: 'Narrator',
  chapters: [
    AudioPlaybackChapter(
      id: 'tv-chapter',
      index: 0,
      title: 'Chapter one',
      duration: Duration(minutes: 100),
    ),
  ],
);
const _cardBook = AudioBook(
  id: 'tv-book',
  sourceId: 'izib',
  sourceBookId: 'tv-book',
  title: 'A journey',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Izib',
  durationLabel: '1 h 40 min',
  chapterCount: 1,
  progress: .25,
  access: BookAccess.free,
);
final _strings = AppStrings.forLocale(const Locale('en'));
final _android = TargetPlatformVariant.only(TargetPlatform.android);

void main() {
  for (final profile in [(false, 390.0), (false, 1280.0), (true, 960.0)]) {
    testWidgets(
      'TV capability not screen width enabled=${profile.$1} width=${profile.$2}',
      (tester) async {
        await _realApp(
          tester,
          size: Size(profile.$2, 720),
          television: profile.$1,
        );
        expect(
          find.byType(TelevisionShell),
          profile.$1 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(TelevisionBookCard),
          profile.$1 ? findsWidgets : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('television-shell')),
          profile.$1 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
      variant: _android,
    );
  }

  for (final size in [const Size(960, 540), const Size(1280, 720)]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('TV real app viewport $size scale=$scale dark=$dark', (
          tester,
        ) async {
          await _realApp(tester, size: size, scale: scale, dark: dark);
          final safe = TelevisionMetrics.safeInsetsFor(
            size,
          ).deflateRect(Offset.zero & size);
          final shellBounds = tester.getRect(
            find.byKey(const ValueKey('television-shell')),
          );
          _inside(shellBounds, safe);
          expect(shellBounds.width, closeTo(safe.width, .01));
          expect(shellBounds.height, closeTo(safe.height, .01));
          for (var index = 0; index < 5; index++) {
            final control = find.byKey(ValueKey('tv-nav-$index'));
            // Large user text may require horizontal navigation scrolling.
            // Every focused tab must be fully revealed, without shrinking text.
            if (index > 0) {
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
              await tester.pumpAndSettle();
            }
            expect(_focusedWithin(control), isTrue);
            _inside(tester.getRect(control), safe);
            expect(tester.getSize(control).height, greaterThanOrEqualTo(40));
          }
          _inside(tester.getRect(find.byType(TelevisionTransport)), safe);
          final card = find.byType(TelevisionBookCard).first;
          final cardBounds = tester.getRect(card);
          expect(cardBounds.left, greaterThanOrEqualTo(safe.left));
          expect(cardBounds.right, lessThanOrEqualTo(safe.right));
          final sources = find.descendant(
            of: card,
            matching: find.byType(PlaybackSourceLabel),
          );
          expect(sources, findsOneWidget);
          final sourceText = find.descendant(
            of: sources,
            matching: find.byType(Text),
          );
          final paragraph = tester.renderObject<RenderParagraph>(sourceText);
          expect(paragraph.textScaler.scale(14), closeTo(scale * 14, .01));
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.takeException(), isNull);
        }, variant: _android);
      }
    }
  }

  testWidgets(
    'TV D-pad Select navigates all five real branches and Back returns home',
    (tester) async {
      await _realApp(tester, size: const Size(1280, 720));
      expect(_focusedWithin(find.byKey(const ValueKey('tv-nav-0'))), isTrue);
      final routes = ['/', '/search', '/library', '/downloads', '/settings'];
      for (var index = 1; index < 5; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(_focusedWithin(find.byKey(ValueKey('tv-nav-$index'))), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(appRouter.state.uri.path, routes[index]);
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(appRouter.state.uri.path, '/');
      expect(tester.takeException(), isNull);
    },
    variant: _android,
  );

  for (final dark in [false, true]) {
    testWidgets(
      'TV D-pad card details and actions are keyboard reachable dark=$dark',
      (tester) async {
        final fixture = await _isolated(tester, dark: dark);
        expect(_focusedWithin(find.byKey(const ValueKey('tv-nav-0'))), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        final frame = find.byType(TelevisionFocusFrame);
        expect(_focusedWithin(frame), isTrue);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: frame,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        final colors = Theme.of(tester.element(frame)).colorScheme;
        expect((decoration.border! as Border).top.color, colors.primary);
        expect((decoration.border! as Border).top.width, equals(2));
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(fixture.actions, ['details']);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        final play = find.descendant(
          of: find.byType(TelevisionBookCard),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        );
        expect(_focusedWithin(play), isTrue);
        for (final action in ['play', 'favorite', 'later', 'download']) {
          await tester.sendKeyEvent(LogicalKeyboardKey.select);
          await tester.pumpAndSettle();
          expect(fixture.actions.last, action);
          if (action != 'download') {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
            await tester.pumpAndSettle();
          }
        }
        expect(fixture.actions, [
          'details',
          'play',
          'favorite',
          'later',
          'download',
        ]);
        final style = Theme.of(tester.element(play)).filledButtonTheme.style!;
        final background = style.backgroundColor!.resolve({
          WidgetState.focused,
        })!;
        final foreground = style.foregroundColor!.resolve({
          WidgetState.focused,
        })!;
        final a = background.computeLuminance(),
            b = foreground.computeLuminance();
        expect(
          (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05)),
          greaterThanOrEqualTo(4.5),
        );
        expect(tester.takeException(), isNull);
      },
      variant: _android,
    );
  }

  testWidgets(
    'TV transport keyboard actions use controller and preserve source',
    (tester) async {
      final fixture = await _isolated(tester);
      final transport = find.byType(TelevisionTransport);
      final rewind = find.descendant(
        of: transport,
        matching: find.byTooltip(_strings.rewind15),
      );
      await _tabTo(tester, rewind);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(fixture.playback.state.position, const Duration(seconds: 45));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        _focusedWithin(find.byKey(const ValueKey('tv-play-pause'))),
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(fixture.playback.state.isPlaying, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(fixture.playback.state.isPlaying, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(fixture.playback.state.position, const Duration(seconds: 60));
      expect(
        find.descendant(
          of: transport,
          matching: find.text(_strings.sourceDisplayName('izib')),
        ),
        findsOneWidget,
      );
      await _tabTo(tester, find.byKey(const ValueKey('tv-open-player')));
      final openPlayer = tester.widget<TextButton>(
        find.byKey(const ValueKey('tv-open-player')),
      );
      final transportColors = Theme.of(
        tester.element(find.byKey(const ValueKey('tv-open-player'))),
      ).colorScheme;
      expect(
        openPlayer.style!.backgroundColor!.resolve({WidgetState.focused}),
        transportColors.surfaceContainer,
        reason:
            'Focus must not put source-owned text colors on the accent fill',
      );
      for (final state in [
        WidgetState.focused,
        WidgetState.hovered,
        WidgetState.pressed,
      ]) {
        expect(openPlayer.style!.overlayColor!.resolve({state})!.a, 0);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(fixture.router.state.uri.path, '/player');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.router.state.uri.path, '/');
      expect(tester.takeException(), isNull);
    },
    variant: _android,
  );
}

void _inside(Rect actual, Rect bounds) {
  expect(actual.left, greaterThanOrEqualTo(bounds.left - .01));
  expect(actual.top, greaterThanOrEqualTo(bounds.top - .01));
  expect(actual.right, lessThanOrEqualTo(bounds.right + .01));
  expect(actual.bottom, lessThanOrEqualTo(bounds.bottom + .01));
}

bool _focusedWithin(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused is! Element || finder.evaluate().length != 1) return false;
  final target = finder.evaluate().single;
  var found = identical(focused, target);
  focused.visitAncestorElements((element) {
    if (identical(element, target)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

Future<void> _tabTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 24 && !_focusedWithin(finder); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  expect(
    _focusedWithin(finder),
    isTrue,
    reason: 'Remote control must remain keyboard reachable',
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _realApp(
  WidgetTester tester, {
  required Size size,
  bool television = true,
  double scale = 1,
  bool dark = true,
}) async {
  _size(tester, size);
  final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
  await settings.load();
  await settings.setLanguageCode('en');
  await settings.setTextScale(scale);
  await settings.setThemeMode(dark ? AppThemeMode.dark : AppThemeMode.light);
  final playback = PlaybackController(engine: InMemoryAudioEngine());
  await playback.loadBook(_playbackBook, position: const Duration(minutes: 1));
  appRouter.go('/');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDeviceProfileProvider.overrideWithValue(
          AppDeviceProfile(
            isTelevision: television,
            hasTouchscreen: !television,
          ),
        ),
        appSettingsStoreProvider.overrideWith((ref) => settings),
        playbackControllerProvider.overrideWith((ref) => playback),
        playbackProgressSnapshotsProvider.overrideWith((ref) async => []),
        libraryPlaybackBooksProvider.overrideWith(
          (ref) async => [_playbackBook],
        ),
        downloadManagerProvider.overrideWith((ref) => _EmptyDownloads()),
        downloadStorageProvider.overrideWith((ref) => _MemoryStorage()),
        searchHistoryStoreProvider.overrideWith(
          (ref) => MemorySearchHistoryStore(),
        ),
        sourceRegistryProvider.overrideWith((ref) => SourceRegistry([])),
        updateServiceProvider.overrideWithValue(
          UpdateService(
            client: const UpdateClient(),
            installer: PlatformUpdateInstaller(),
            runtimePlatform: UpdateRuntimePlatform.unsupported,
          ),
        ),
      ],
      child: const SlovofonApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<({List<String> actions, PlaybackController playback, GoRouter router})>
_isolated(WidgetTester tester, {bool dark = true}) async {
  _size(tester, const Size(1280, 720));
  final playback = PlaybackController(engine: InMemoryAudioEngine());
  await playback.loadBook(_playbackBook, position: const Duration(minutes: 1));
  final actions = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TelevisionShell(
          selectedIndex: 0,
          onSelected: (_) {},
          child: ListView(
            children: [
              BookCard(
                book: _cardBook,
                onTap: () => actions.add('details'),
                onPlay: () => actions.add('play'),
                onFavoritePressed: () => actions.add('favorite'),
                onLaterPressed: () => actions.add('later'),
                onDownloadPressed: () => actions.add('download'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) =>
            const Scaffold(body: Text('Player destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playbackControllerProvider.overrideWith((ref) => playback)],
      child: MaterialApp.router(
        routerConfig: router,
        theme: TelevisionTheme.from(
          (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
            platform: TargetPlatform.android,
          ),
        ),
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) => TelevisionLayout(
          enabled: true,
          child: TelevisionViewport(child: child!),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (actions: actions, playback: playback, router: router);
}

class _EmptyDownloads extends ChangeNotifier implements DownloadManager {
  @override
  List<DownloadTask> get tasks => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('unused-tv-ui-quality-memory'));
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => [_playbackBook];
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);
}
