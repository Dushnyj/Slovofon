import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/responsive_tile_grid.dart';

void main() {
  testWidgets(
    'full player chapter list fits combined large system and app font',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
      await settings.setTextScale(1.3);
      final fixture = await _Fixture.create();
      await fixture.controller.loadBook(
        fixture.book,
        position: const Duration(seconds: 60),
      );
      await fixture.pump(tester, settings: settings);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Open full player'));
      await _frames(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
      await _frames(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop shell fits its minimum desktop width with playback', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await fixture.controller.loadBook(fixture.book);
    await fixture.pump(tester, viewport: const Size(900, 820));
    expect(tester.takeException(), isNull);
  });
  testWidgets('seek slider does not trigger the player back gesture', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await fixture.controller.loadBook(fixture.book);
    await fixture.pump(tester);
    await tester.tap(find.byTooltip('Open full player'));
    await _frames(tester);
    final slider = tester.getRect(find.byType(Slider));
    await tester.dragFrom(
      Offset(slider.left + 35, slider.center.dy),
      const Offset(200, 0),
    );
    await _frames(tester);
    expect(appRouter.state.uri.path, '/player');
    expect(fixture.controller.state.position, greaterThan(Duration.zero));

    await tester.drag(find.byType(TabBarView), const Offset(200, 0));
    await _frames(tester);
    expect(appRouter.state.uri.path, '/');
  });

  testWidgets('downloads reacts to playback and pauses without source IO', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await fixture.controller.loadBook(fixture.book);
    await fixture.pump(tester);
    await tester.tap(find.byKey(const ValueKey('mobile-navigation-item-3')));
    await _frames(tester);
    final card = find.byType(ExpansionTile);
    expect(
      find.descendant(of: card, matching: find.byTooltip('Pause')),
      findsNothing,
    );
    await fixture.controller.togglePlayPause();
    await _frames(tester);
    final pause = find.descendant(of: card, matching: find.byTooltip('Pause'));
    expect(pause, findsOneWidget);
    await tester.tap(pause);
    await _frames(tester);
    expect(fixture.controller.state.isPlaying, isFalse);
    expect(fixture.catalog.loads, 0);
    expect(
      find.descendant(of: card, matching: find.byTooltip('Play')),
      findsOneWidget,
    );
  });

  testWidgets('completed downloaded book starts locally without source IO', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await fixture.pump(tester);
    await tester.tap(find.byKey(const ValueKey('mobile-navigation-item-3')));
    await _frames(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.byTooltip('Play'),
      ),
    );
    await _frames(tester);
    expect(fixture.catalog.loads, 0);
    expect(fixture.controller.state.isPlaying, isTrue);
    expect(
      fixture.engine.loadedChapter?.mediaSource?.type,
      AudioMediaSourceType.file,
    );
  });

  testWidgets('home observes persisted books started in the current session', (
    tester,
  ) async {
    final fixture = await _Fixture.create();
    await fixture.pump(tester);
    await fixture.controller.loadBook(
      fixture.book,
      position: const Duration(seconds: 60),
    );
    await _frames(tester);
    final second = _book('second');
    await fixture.controller.loadBook(
      second,
      position: const Duration(seconds: 60),
    );
    await _frames(tester);
    expect(fixture.persistence.progress, hasLength(2));
    expect(find.text(fixture.book.title), findsOneWidget);
    expect(find.text(second.title), findsWidgets);
  });

  for (final dark in [false, true]) {
    for (final width in [900.0, 1280.0]) {
      for (final scale in [1.0, 1.3, 2.6]) {
        testWidgets(
          'shared desktop cards fit $width / scale $scale / dark $dark',
          (tester) async {
            tester.view.physicalSize = Size(width, 1500);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1500),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Scaffold(
                    body: Row(
                      children: [
                        const SizedBox(width: 237),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              ResponsiveTileGrid(
                                children: [
                                  for (var index = 0; index < 3; index++)
                                    BookCard(
                                      book: _cardBook,
                                      onTap: () {},
                                      onPlay: () {},
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              find.byKey(const ValueKey('book-card-desktop-tile')),
              findsNWidgets(3),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final width in [430.0, 900.0]) {
    testWidgets('sample badge remains visible on card at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: BookCard(
                book: _cardBook.copyWith(isFragment: true),
                onPlay: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Sample'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

const _cardBook = AudioBook(
  id: 'card',
  title: 'Очень длинное название аудиокниги для плитки',
  author: 'Первый Автор, Второй Автор, Третий Автор',
  narrator: 'Первый Чтец, Второй Чтец',
  sourceId: 'akniga',
  sourceName: 'Akniga',
  durationLabel: '11 ч 49 мин',
  chapterCount: 100,
  progress: .42,
  access: BookAccess.free,
  seriesTitle: 'Очень длинное название серии',
  ratingValue: 4.6,
  year: 2020,
);

AudioPlaybackBook _book(String id) => AudioPlaybackBook(
  id: id,
  versionId: 'version-$id',
  sourceId: 'izib',
  sourceBookId: id,
  title: 'Review book $id',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Izib',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-$id',
      index: 1,
      title: 'Chapter 1',
      duration: const Duration(minutes: 10),
      isDownloaded: true,
      mediaSource: AudioMediaSource.file('C:/slovofon-test-fixture/$id.mp3'),
    ),
  ],
);

class _Fixture {
  _Fixture(
    this.book,
    this.storage,
    this.persistence,
    this.engine,
    this.controller,
    this.manager,
  );
  final AudioPlaybackBook book;
  final _MemoryStorage storage;
  final _ProgressStore persistence;
  final InMemoryAudioEngine engine;
  final PlaybackController controller;
  final DownloadManager manager;
  final catalog = _NoNetworkCatalog();

  static Future<_Fixture> create() async {
    final book = _book('first');
    final storage = _MemoryStorage();
    await storage.saveBook(book);
    final persistence = _ProgressStore();
    final engine = InMemoryAudioEngine();
    final controller = PlaybackController(
      engine: engine,
      persistence: persistence,
      bookMetadataStore: storage,
    );
    final downloads = MemoryDownloadPersistenceStore();
    final now = DateTime(2026, 1, 1);
    await downloads.saveTask(
      DownloadTask(
        id: 'chapter:${book.versionId}:${book.chapters.first.id}',
        bookId: book.id,
        bookVersionId: book.versionId,
        chapterId: book.chapters.first.id,
        sourceId: book.sourceId,
        type: DownloadTaskType.chapter,
        status: DownloadTaskStatus.completed,
        progress: 1,
        downloadedBytes: 1,
        totalBytes: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final manager = DownloadManager(
      client: _NoNetworkClient(),
      storage: storage,
      persistence: downloads,
    );
    await manager.loadPersistedTasks();
    return _Fixture(book, storage, persistence, engine, controller, manager);
  }

  Future<void> pump(
    WidgetTester tester, {
    Size viewport = const Size(430, 932),
    AppSettingsStore? settings,
  }) async {
    appRouter.go('/');
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackControllerProvider.overrideWith((ref) {
            ref.onDispose(controller.dispose);
            return controller;
          }),
          playbackPersistenceStoreProvider.overrideWithValue(persistence),
          downloadStorageProvider.overrideWithValue(storage),
          downloadManagerProvider.overrideWith((ref) {
            ref.onDispose(manager.dispose);
            return manager;
          }),
          sourceCatalogServiceProvider.overrideWithValue(catalog),
          if (settings != null)
            appSettingsStoreProvider.overrideWith((ref) => settings),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _frames(tester);
  }
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(
        rootDirectory: Directory(
          '${Directory.systemTemp.path}/slovofon-ui-memory-only',
        ),
      );
  final books = <String, AudioPlaybackBook>{};
  @override
  Future<void> saveBook(AudioPlaybackBook book) async {
    books[book.versionId] = book;
  }

  @override
  Future<void> writeMetadata(AudioPlaybackBook book) => saveBook(book);
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async =>
      books.values.toList();
  @override
  Future<AudioPlaybackBook?> readMetadataForIds(
    String sourceId,
    String versionId,
  ) async => books[versionId];
  @override
  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async =>
      books[book.versionId] ?? book;
}

class _ProgressStore implements PlaybackPersistenceStore {
  final progress = <String, PlaybackProgressSnapshot>{};
  PlaybackSession? session;
  @override
  Future<PlaybackSession?> loadSession({String id = 'active'}) async => session;
  @override
  Future<List<PlaybackProgressSnapshot>> loadProgress() async =>
      progress.values.toList();
  @override
  Future<void> saveSession(PlaybackSession session) async {
    this.session = session;
  }

  @override
  Future<void> saveProgress(PlaybackProgressSnapshot progress) async {
    this.progress[progress.bookVersionId] = progress;
  }
}

class _NoNetworkCatalog extends SourceCatalogService {
  _NoNetworkCatalog() : super(registry: SourceRegistry([]));
  int loads = 0;
  @override
  Future<SourceBookSnapshot> loadBook(
    SourceBookRef ref, {
    bool forceRefresh = false,
    MediaResolvePurpose purpose = MediaResolvePurpose.playback,
  }) async {
    loads++;
    throw StateError('Playback controls must not wait for the source');
  }
}

class _NoNetworkClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => throw StateError('No download request expected');
}
