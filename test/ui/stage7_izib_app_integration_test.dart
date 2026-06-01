import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/domain/models/audio_track.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/deep_links/app_deep_links.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/features/shared/download_ui_state.dart';
import 'package:slovofon/features/source_books/source_book_details_screen.dart';
import 'package:slovofon/services/library/library_store.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/izib/izib_graphql_client.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/components/download_action_button.dart';

import 'test_search_history_store.dart';

void main() {
  test('book download state matches persisted tasks by book id fallback', () {
    final manager = _MemoryDownloadManager();
    addTearDown(manager.dispose);
    const book = AudioPlaybackBook(
      id: 'izib-book-7098',
      versionId: 'izib-canonical-7098',
      sourceId: 'izib',
      sourceBookId: 'canonical-7098',
      title: 'S.T.A.L.K.E.R. Полураспад',
      author: 'Александр Зорич',
      narrator: 'Чайцын Александр',
      sourceName: 'Izib',
      chapters: [
        AudioPlaybackChapter(
          id: 'chapter-1',
          index: 0,
          title: 'Глава 00. 000-01',
          duration: Duration(minutes: 10),
        ),
      ],
    );
    manager.seedTask(
      DownloadTask(
        id: 'chapter:izib-search-7098:chapter-1',
        bookId: book.id,
        bookVersionId: 'izib-search-7098',
        chapterId: 'chapter-1',
        sourceId: 'izib',
        type: DownloadTaskType.chapter,
        status: DownloadTaskStatus.completed,
        progress: 1,
        downloadedBytes: 10,
        totalBytes: 10,
        createdAt: DateTime(2026, 5, 26),
        updatedAt: DateTime(2026, 5, 26),
      ),
    );

    expect(
      downloadStateForBook(manager, book),
      BookCardDownloadState.downloaded,
    );
  });

  test('book download state treats partial completed tasks as resumable', () {
    final manager = _MemoryDownloadManager();
    addTearDown(manager.dispose);
    const book = AudioPlaybackBook(
      id: 'izib-book-7098',
      versionId: 'izib-7098',
      sourceId: 'izib',
      sourceBookId: '7098',
      title: 'S.T.A.L.K.E.R. Полураспад',
      author: 'Александр Зорич',
      narrator: 'Чайцын Александр',
      sourceName: 'Izib',
      chapters: [
        AudioPlaybackChapter(
          id: 'chapter-1',
          index: 0,
          title: 'Глава 00. 000-01',
          duration: Duration(minutes: 10),
        ),
        AudioPlaybackChapter(
          id: 'chapter-2',
          index: 1,
          title: 'Глава 01. 001-01',
          duration: Duration(minutes: 10),
        ),
      ],
    );
    manager.seedTask(
      DownloadTask(
        id: 'chapter:izib-7098:chapter-1',
        bookId: book.id,
        bookVersionId: book.versionId,
        chapterId: 'chapter-1',
        sourceId: 'izib',
        type: DownloadTaskType.chapter,
        status: DownloadTaskStatus.completed,
        progress: 1,
        downloadedBytes: 10,
        totalBytes: 10,
        createdAt: DateTime(2026, 5, 26),
        updatedAt: DateTime(2026, 5, 26),
      ),
    );

    expect(downloadStateForBook(manager, book), BookCardDownloadState.paused);
    expect(downloadProgressForBook(manager, book), 0.5);
  });

  testWidgets('search opens an Izib book and starts playback with chapters', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final transport = QueueIzibTransport([
      _fixtureText('izib_search_response.json'),
      _fixtureText('izib_book_response.json'),
      _fixtureText('izib_book_response.json'),
    ]);
    final sourceRegistry = SourceRegistry([
      IzibSourceConnector(client: IzibGraphQlClient(transport: transport)),
    ]);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(playbackController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Search'), findsWidgets);
    expect(find.textContaining('mock results'), findsNothing);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'метро');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 40);

    expect(find.text('Метро 2033'), findsOneWidget);
    expect(find.text('Izib'), findsWidgets);

    await tester.tap(find.text('Метро 2033').first);
    await _pumpFrames(tester, frames: 60);

    expect(find.text('Book details'), findsOneWidget);
    expect(find.text('Дмитрий Глуховский'), findsWidgets);
    expect(find.textContaining('Петр Иващенко'), findsWidgets);
    expect(find.text('Фантастика'), findsOneWidget);
    expect(find.text('Глава 01. Артем'), findsOneWidget);
    expect(find.text('002'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('source-details-play')));
    await _pumpFrames(tester, frames: 40);

    expect(playbackController.state.book?.sourceId, 'izib');
    expect(playbackController.state.book?.sourceBookId, '2033');
    expect(playbackController.state.book?.chapters.length, 2);
    expect(
      playbackController.state.currentChapter?.mediaSource?.uri.toString(),
      'https://audio.izib.uk/books/2033/001.mp3',
    );
    expect(find.text('Метро 2033'), findsWidgets);
    expect(find.byTooltip('Pause'), findsWidgets);
    expect(find.text('Izib'), findsWidgets);
    expect(find.text('Михаил Булгаков'), findsNothing);
  });

  testWidgets('downloads screen shows Izib task metadata after enqueue', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final snapshot = await SourceCatalogService(
      registry: SourceRegistry([
        IzibSourceConnector(
          client: IzibGraphQlClient(
            transport: QueueIzibTransport([
              _fixtureText('izib_book_response.json'),
              _fixtureText('izib_book_response.json'),
            ]),
          ),
        ),
      ]),
    ).loadBook(const SourceBookRef(sourceId: 'izib', sourceBookId: '2033'));
    final downloadDirectory = Directory(
      '${Directory.systemTemp.path}/slovofon-stage7-downloads-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    final now = DateTime(2026, 5, 26, 16);
    final persistence = MemoryDownloadPersistenceStore();
    for (final chapter in snapshot.playbackBook.chapters) {
      await persistence.saveTask(
        DownloadTask(
          id: 'chapter:${snapshot.playbackBook.versionId}:${chapter.id}',
          bookId: snapshot.playbackBook.id,
          bookVersionId: snapshot.playbackBook.versionId,
          chapterId: chapter.id,
          sourceId: snapshot.playbackBook.sourceId,
          type: DownloadTaskType.chapter,
          status: DownloadTaskStatus.queued,
          progress: 0,
          downloadedBytes: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final seededDownloadManager = DownloadManager(
      client: _NoopDownloadClient(),
      storage: FileDownloadStorage(rootDirectory: downloadDirectory),
      persistence: persistence,
    );
    await seededDownloadManager.loadPersistedTasks(recoverInterrupted: false);
    seededDownloadManager.attachBookContext(snapshot.playbackBook);
    final sourceRegistry = SourceRegistry([
      IzibSourceConnector(
        client: IzibGraphQlClient(transport: QueueIzibTransport([])),
      ),
    ]);
    addTearDown(() {
      if (downloadDirectory.existsSync()) {
        downloadDirectory.deleteSync(recursive: true);
      }
    });
    addTearDown(seededDownloadManager.dispose);

    appRouter.go('/downloads');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(playbackController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          downloadManagerProvider.overrideWith((ref) => seededDownloadManager),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester, frames: 40);

    expect(find.text('Метро 2033'), findsWidgets);
    expect(find.text('Дмитрий Глуховский'), findsWidgets);
    expect(find.text('Петр Иващенко'), findsWidgets);
    expect(find.text('Метро'), findsWidgets);
    expect(find.text('4.5 из 5'), findsOneWidget);
    expect(find.text('2020'), findsWidgets);
    expect(find.text('Izib'), findsWidgets);
    expect(find.textContaining('size is being calculated'), findsOneWidget);
    expect(find.text('Глава 01. Артем'), findsNothing);
    expect(find.text('002'), findsNothing);

    await tester.tap(find.text('Метро 2033').first);
    await _pumpFrames(tester, frames: 20);

    expect(find.text('Глава 01. Артем'), findsOneWidget);
    expect(find.text('002'), findsOneWidget);
    expect(find.text('Мастер и Маргарита'), findsNothing);
  });

  testWidgets(
    'search result card buttons favorite download and play from Izib',
    (tester) async {
      final playbackController = PlaybackController(
        engine: InMemoryAudioEngine(),
      );
      final transport = QueueIzibTransport([
        _fixtureText('izib_search_response.json'),
        _fixtureText('izib_book_response.json'),
        _fixtureText('izib_book_response.json'),
        _fixtureText('izib_book_response.json'),
        _fixtureText('izib_book_response.json'),
      ]);
      final sourceRegistry = SourceRegistry([
        IzibSourceConnector(client: IzibGraphQlClient(transport: transport)),
      ]);
      final downloadManager = _MemoryDownloadManager();
      addTearDown(downloadManager.dispose);
      addTearDown(playbackController.dispose);

      appRouter.go('/search');
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
            playbackControllerProvider.overrideWith((ref) {
              return playbackController;
            }),
            downloadManagerProvider.overrideWith((ref) => downloadManager),
            searchHistoryStoreProvider.overrideWith(
              (ref) => MemorySearchHistoryStore(),
            ),
          ],
          child: const SlovofonApp(),
        ),
      );
      await _pumpFrames(tester);

      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'метро');
      await _pumpFrames(tester, frames: 6);

      expect(transport.responses, hasLength(5));
      expect(find.text('Метро 2033'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('search-submit')));
      await _pumpFrames(tester, frames: 40);

      expect(find.text('Метро 2033'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('book-card-favorite-izib-2033')),
      );
      await _pumpFrames(tester, frames: 6);
      expect(find.text('Added to favorites'), findsOneWidget);
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);

      await tester.tap(find.text('Library'));
      await _pumpFrames(tester, frames: 20);
      expect(find.text('Метро 2033'), findsOneWidget);
      expect(find.text('1 books'), findsOneWidget);

      await tester.tap(find.text('Search'));
      await _pumpFrames(tester, frames: 12);

      await tester.tap(
        find.byKey(const ValueKey('book-card-download-izib-2033')),
      );
      await _pumpFrames(tester, frames: 120);
      expect(downloadManager.tasks, hasLength(2));
      expect(find.text('Book added to downloads'), findsOneWidget);
      expect(find.byTooltip('Cancel download'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('book-card-play-izib-2033')));
      await _pumpFrames(tester, frames: 60);

      expect(playbackController.state.book?.sourceId, 'izib');
      expect(playbackController.state.book?.sourceBookId, '2033');
      expect(playbackController.state.currentChapter?.title, 'Глава 01. Артем');
      expect(find.text('Search'), findsWidgets);
      expect(find.byTooltip('Pause'), findsWidgets);

      await tester.tap(find.text('Home'));
      await _pumpFrames(tester, frames: 20);
      expect(find.text('Continue listening'), findsOneWidget);
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    },
  );

  testWidgets('search submit opens a clean result view with back navigation', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_TwoChapterIzibSearchConnector()]);
    addTearDown(playbackController.dispose);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'метро');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 100);

    expect(find.text('1 results'), findsOneWidget);
    expect(find.text('Метро 2033'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Title'), findsNothing);
    expect(find.text('Sort: relevance'), findsNothing);

    await tester.binding.handlePopRoute();
    await _pumpFrames(tester, frames: 12);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Title'), findsWidgets);
    expect(find.text('Метро 2033'), findsNothing);
  });

  testWidgets('search result play button shows loading while Izib book loads', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final transport = QueueIzibTransport([
      _fixtureText('izib_search_response.json'),
      _fixtureText('izib_book_response.json'),
      _fixtureText('izib_book_response.json'),
    ], responseDelay: const Duration(milliseconds: 350));
    final sourceRegistry = SourceRegistry([
      IzibSourceConnector(client: IzibGraphQlClient(transport: transport)),
    ]);
    addTearDown(playbackController.dispose);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'метро');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 20);

    await tester.tap(find.byKey(const ValueKey('book-card-play-izib-2033')));
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byKey(const ValueKey('book-card-play-loading')),
      findsOneWidget,
    );
    expect(playbackController.state.book, isNull);

    await _pumpFrames(tester, frames: 100);

    expect(playbackController.state.book?.sourceId, 'izib');
    expect(find.byKey(const ValueKey('book-card-play-loading')), findsNothing);
    expect(find.text('Search'), findsWidgets);
    expect(find.byTooltip('Pause'), findsWidgets);
  });

  testWidgets('search result card follows playback when details id differs', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_MismatchedIdIzibConnector()]);
    addTearDown(playbackController.dispose);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'полураспад');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 30);

    expect(find.text('Полураспад'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('book-card-play-izib-search-id')),
    );
    await _pumpFrames(tester, frames: 40);

    expect(playbackController.state.book?.sourceBookId, 'search-id');
    expect(find.byKey(const ValueKey('book-card-play-loading')), findsNothing);
    expect(find.byTooltip('Pause'), findsNWidgets(2));
  });

  testWidgets(
    'search result playback state only marks the exact duplicate result active',
    (tester) async {
      final playbackController = PlaybackController(
        engine: InMemoryAudioEngine(),
      );
      final sourceRegistry = SourceRegistry([_DuplicateTitleIzibConnector()]);
      addTearDown(playbackController.dispose);

      appRouter.go('/search');
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
            playbackControllerProvider.overrideWith(
              (ref) => playbackController,
            ),
            searchHistoryStoreProvider.overrideWith(
              (ref) => MemorySearchHistoryStore(),
            ),
          ],
          child: const SlovofonApp(),
        ),
      );
      await _pumpFrames(tester);

      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'дубликат');
      await tester.tap(find.byKey(const ValueKey('search-submit')));
      await _pumpFrames(tester, frames: 30);

      expect(find.text('Дубликат'), findsNWidgets(2));
      await tester.tap(
        find.byKey(const ValueKey('book-card-play-izib-second-id')),
      );
      await _pumpFrames(tester, frames: 40);

      expect(playbackController.state.book?.sourceBookId, 'second-id');
      expect(find.byTooltip('Pause'), findsNWidgets(2));
    },
  );

  testWidgets('search result play resumes saved chapter position', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_TwoChapterResumeConnector()]);
    final progressStore = _StaticPlaybackPersistenceStore([
      PlaybackProgressSnapshot(
        bookId: 'izib-book-resume-id',
        bookVersionId: 'izib-resume-id',
        currentChapterId: 'resume-chapter-2',
        currentPositionMs: 120000,
        maxReachedGlobalPositionMs: 720000,
        totalDurationMs: 1200000,
        listenedDurationMs: 720000,
        percent: 60,
        isFinished: false,
        lastPlayedAt: DateTime(2026, 5, 29),
      ),
    ]);
    addTearDown(playbackController.dispose);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          playbackPersistenceStoreProvider.overrideWith((ref) => progressStore),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'продолжить');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 30);
    await tester.tap(
      find.byKey(const ValueKey('book-card-play-izib-resume-id')),
    );
    await _pumpFrames(tester, frames: 40);

    expect(playbackController.state.chapterIndex, 1);
    expect(playbackController.state.position, const Duration(minutes: 2));
    expect(playbackController.state.bookProgress, closeTo(0.6, 0.001));
  });

  testWidgets('search result card updates to play after pausing playback', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_MismatchedIdIzibConnector()]);
    addTearDown(playbackController.dispose);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'полураспад');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 30);

    await tester.tap(
      find.byKey(const ValueKey('book-card-play-izib-search-id')),
    );
    await _pumpFrames(tester, frames: 40);
    expect(playbackController.state.isPlaying, isTrue);
    expect(find.byTooltip('Pause'), findsNWidgets(2));

    await tester.tap(
      find.byKey(const ValueKey('book-card-play-izib-search-id')),
    );
    await _pumpFrames(tester, frames: 12);

    expect(playbackController.state.isPlaying, isFalse);
    expect(find.byTooltip('Pause'), findsNothing);
    expect(find.byTooltip('Play'), findsWidgets);
  });

  testWidgets('library favorite card can start source playback', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_MismatchedIdIzibConnector()]);
    final libraryStore = LibraryStore(MemoryLibraryPersistenceStore());
    await libraryStore.toggleFavorite(
      const AudioBook(
        id: 'search-id',
        sourceBookId: 'search-id',
        title: 'Полураспад',
        author: 'Александр Зорич',
        narrator: 'Чайцын Александр',
        sourceId: 'izib',
        sourceName: 'Izib',
        durationLabel: '11 ч 49 мин',
        chapterCount: 1,
        progress: 0,
        access: BookAccess.free,
      ),
    );
    addTearDown(playbackController.dispose);

    appRouter.go('/library');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          libraryStoreProvider.overrideWith((ref) => libraryStore),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Полураспад'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('book-card-play-izib-search-id')),
    );
    await _pumpFrames(tester, frames: 40);

    expect(playbackController.state.book?.sourceId, 'izib');
    expect(playbackController.state.book?.sourceBookId, 'search-id');
    expect(playbackController.state.isPlaying, isTrue);
    expect(find.byTooltip('Pause'), findsWidgets);
  });

  testWidgets('library favorite cover shows saved listening progress', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_TwoChapterResumeConnector()]);
    final progressStore = _StaticPlaybackPersistenceStore([
      PlaybackProgressSnapshot(
        bookId: 'izib-book-resume-id',
        bookVersionId: 'izib-resume-id',
        currentChapterId: 'resume-chapter-2',
        currentPositionMs: 120000,
        maxReachedGlobalPositionMs: 720000,
        totalDurationMs: 1200000,
        listenedDurationMs: 720000,
        percent: 60,
        isFinished: false,
        lastPlayedAt: DateTime(2026, 5, 29),
      ),
    ]);
    final libraryStore = LibraryStore(MemoryLibraryPersistenceStore());
    await libraryStore.toggleFavorite(
      const AudioBook(
        id: 'izib-book-resume-id',
        sourceBookId: 'resume-id',
        title: 'Продолжить',
        author: 'Автор',
        narrator: 'Чтец',
        sourceId: 'izib',
        sourceName: 'Izib',
        durationLabel: '20 мин',
        chapterCount: 2,
        progress: 0,
        access: BookAccess.free,
      ),
    );
    addTearDown(playbackController.dispose);

    appRouter.go('/library');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          playbackPersistenceStoreProvider.overrideWith((ref) => progressStore),
          libraryStoreProvider.overrideWith((ref) => libraryStore),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Продолжить'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('library favorite cover shows live player progress', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    await playbackController.loadBook(
      const AudioPlaybackBook(
        id: 'izib-book-live-id',
        versionId: 'izib-live-id',
        sourceId: 'izib',
        sourceBookId: 'live-id',
        title: 'Живой прогресс',
        author: 'Автор',
        narrator: 'Чтец',
        sourceName: 'Izib',
        chapters: [
          AudioPlaybackChapter(
            id: 'live-chapter-1',
            index: 0,
            title: 'Глава 1',
            duration: Duration(minutes: 10),
          ),
          AudioPlaybackChapter(
            id: 'live-chapter-2',
            index: 1,
            title: 'Глава 2',
            duration: Duration(minutes: 10),
          ),
        ],
      ),
      chapterIndex: 1,
      position: const Duration(minutes: 2),
    );
    final libraryStore = LibraryStore(MemoryLibraryPersistenceStore());
    await libraryStore.toggleFavorite(
      const AudioBook(
        id: 'izib-book-live-id',
        sourceBookId: 'live-id',
        title: 'Живой прогресс',
        author: 'Автор',
        narrator: 'Чтец',
        sourceId: 'izib',
        sourceName: 'Izib',
        durationLabel: '20 мин',
        chapterCount: 2,
        progress: 0,
        access: BookAccess.free,
      ),
    );
    addTearDown(playbackController.dispose);

    appRouter.go('/library');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackControllerProvider.overrideWith((ref) => playbackController),
          libraryStoreProvider.overrideWith((ref) => libraryStore),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Живой прогресс'), findsWidgets);
    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('search result treats partial completed downloads as resumable', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_TwoChapterIzibSearchConnector()]);
    final downloadManager = _MemoryDownloadManager()
      ..seedTask(
        DownloadTask(
          id: 'chapter:izib-2033:izib-2033-001',
          bookId: 'izib-book-2033',
          bookVersionId: 'izib-2033',
          chapterId: 'izib-2033-001',
          sourceId: 'izib',
          type: DownloadTaskType.chapter,
          status: DownloadTaskStatus.completed,
          progress: 1,
          downloadedBytes: 10,
          totalBytes: 10,
          createdAt: DateTime(2026, 5, 26),
          updatedAt: DateTime(2026, 5, 26),
        ),
      );
    addTearDown(playbackController.dispose);
    addTearDown(downloadManager.dispose);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          downloadManagerProvider.overrideWith((ref) => downloadManager),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'метро');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 40);

    expect(find.text('Метро 2033'), findsOneWidget);
    expect(find.byTooltip('Resume download'), findsOneWidget);
    expect(find.byTooltip('Delete downloaded'), findsNothing);
  });

  testWidgets('search result cover shows saved listening progress', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_TwoChapterIzibSearchConnector()]);
    final progressStore = _StaticPlaybackPersistenceStore([
      PlaybackProgressSnapshot(
        bookId: 'izib-book-2033',
        bookVersionId: 'izib-2033',
        currentChapterId: 'izib-2033-001',
        currentPositionMs: 120000,
        maxReachedGlobalPositionMs: 120000,
        totalDurationMs: 600000,
        listenedDurationMs: 120000,
        percent: 20,
        isFinished: false,
        lastPlayedAt: DateTime(2026, 5, 29),
      ),
    ]);
    addTearDown(playbackController.dispose);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          playbackPersistenceStoreProvider.overrideWith((ref) => progressStore),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'метро');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 40);

    expect(find.text('20%'), findsOneWidget);
  });

  testWidgets('search result matches Akniga download state by version id', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_SingleAknigaSearchConnector()]);
    final downloadManager = _MemoryDownloadManager()
      ..seedTask(
        DownloadTask(
          id: 'chapter:akniga-aleksandr-zorich-poluraspad-stalker-2010:chapter-1',
          bookId: 'akniga-book-aleksandr-zorich-poluraspad-stalker-2010',
          bookVersionId: 'akniga-aleksandr-zorich-poluraspad-stalker-2010',
          chapterId: 'chapter-1',
          sourceId: 'akniga',
          type: DownloadTaskType.chapter,
          status: DownloadTaskStatus.completed,
          progress: 1,
          downloadedBytes: 10,
          totalBytes: 10,
          createdAt: DateTime(2026, 5, 26),
          updatedAt: DateTime(2026, 5, 26),
        ),
      );
    addTearDown(playbackController.dispose);
    addTearDown(downloadManager.dispose);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          downloadManagerProvider.overrideWith((ref) => downloadManager),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'полураспад');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 40);

    expect(find.text('Полураспад'), findsOneWidget);
    expect(find.text('Зорич Александр'), findsOneWidget);
    expect(find.text('Чайцын Александр'), findsOneWidget);
    expect(find.text('S.T.A.L.K.E.R.'), findsOneWidget);
    expect(find.text('4.6 из 5'), findsOneWidget);
    expect(find.text('2010'), findsOneWidget);
    expect(find.byTooltip('Delete downloaded'), findsOneWidget);
    expect(find.byTooltip('Download'), findsNothing);
  });

  testWidgets('source book details keeps chapters collapsed after first five', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final sourceRegistry = SourceRegistry([_ManyChaptersSourceConnector()]);
    addTearDown(playbackController.dispose);

    appRouter.go('/source-book/many/many-book');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester, frames: 20);

    expect(find.text('Chapter 001'), findsOneWidget);
    expect(find.text('Chapter 005'), findsOneWidget);
    expect(find.text('Chapter 006'), findsNothing);
    expect(find.text('Chapter 007'), findsNothing);

    await tester.tap(find.text('Show 2 more chapters'));
    await _pumpFrames(tester);

    expect(find.text('Chapter 006'), findsOneWidget);
    expect(find.text('Chapter 007'), findsOneWidget);
    expect(find.text('Collapse chapters'), findsOneWidget);
  });

  testWidgets(
    'source book details syncs actions and exposes source facts plus share links',
    (tester) async {
      final playbackController = PlaybackController(
        engine: InMemoryAudioEngine(),
      );
      final sourceRegistry = SourceRegistry([_DetailedBookConnector()]);
      final tempDir = Directory(
        '${Directory.systemTemp.path}/slovofon-details-cache-${DateTime.now().microsecondsSinceEpoch}',
      );
      tempDir.createSync(recursive: true);
      final downloadStorage = FileDownloadStorage(rootDirectory: tempDir);
      final downloadManager = _MemoryDownloadManager(storage: downloadStorage);
      final libraryStore = LibraryStore(MemoryLibraryPersistenceStore());
      addTearDown(playbackController.dispose);
      addTearDown(downloadManager.dispose);
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      appRouter.go('/source-book/izib/2033');
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
            playbackControllerProvider.overrideWith((ref) {
              return playbackController;
            }),
            downloadManagerProvider.overrideWith((ref) => downloadManager),
            downloadStorageProvider.overrideWith((ref) => downloadStorage),
            libraryStoreProvider.overrideWith((ref) => libraryStore),
          ],
          child: const SlovofonApp(),
        ),
      );
      await _pumpFrames(tester, frames: 30);

      expect(
        find.byKey(const ValueKey('mobile-navigation-bar')),
        findsOneWidget,
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('S.T.A.L.K.E.R. Дыхание зоны'), findsOneWidget);
      expect(find.text('Николай Грошев'), findsOneWidget);
      expect(find.text('Соавтор Второй'), findsOneWidget);
      expect(find.text('Олег Шубин'), findsOneWidget);
      expect(find.text('Тимофей Зобнин'), findsOneWidget);
      expect(find.text('Велес #1'), findsOneWidget);
      expect(find.text('4.3 из 5'), findsOneWidget);
      expect(find.text('Source page'), findsOneWidget);
      expect(find.text('https://izib.uk/art2033'), findsOneWidget);
      expect(find.text('Genre'), findsOneWidget);
      expect(find.text('Фантастика, S.T.A.L.K.E.R.'), findsOneWidget);
      expect(find.text('Source stats'), findsOneWidget);
      expect(find.text('12 843'), findsOneWidget);
      expect(find.text('412'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('Availability'), findsNothing);
      expect(find.text('Progress'), findsNothing);

      expect(find.textContaining('финальная часть описания'), findsNothing);
      await tester.tap(find.text('Show full description'));
      await _pumpFrames(tester, frames: 4);
      expect(find.textContaining('финальная часть описания'), findsOneWidget);
      expect(find.text('Hide description'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('source-details-favorite')));
      await _pumpFrames(tester, frames: 8);
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
      expect(libraryStore.favorites.single.book.sourceBookId, '2033');

      await tester.tap(find.byKey(const ValueKey('source-details-download')));
      await _pumpFrames(tester, frames: 20);
      expect(downloadManager.tasks, hasLength(6));
      expect(find.byTooltip('Cancel download'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('source-details-share')));
      await _pumpFrames(tester, frames: 4);
      expect(find.text('Slovofon link'), findsOneWidget);
      expect(find.text('Source link'), findsOneWidget);
      expect(
        find.text('slovofon://book?source=izib&book=2033'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(12, 120));
      await _pumpFrames(tester, frames: 8);
      expect(find.text('Source link'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('source-details-play')));
      await _pumpFrames(tester, frames: 20);
      expect(playbackController.state.status, AudioPlaybackStatus.playing);
      expect(playbackController.state.book?.sourceBookId, '2033');
      expect(find.byTooltip('Pause'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('source-details-play')));
      await _pumpFrames(tester, frames: 8);
      expect(playbackController.state.status, AudioPlaybackStatus.paused);
      expect(find.byTooltip('Play'), findsWidgets);

      await tester.tap(find.text('Николай Грошев'));
      await _pumpFrames(tester, frames: 30);
      expect(appRouter.state.uri.path, '/scoped-search');
      expect(appRouter.state.uri.queryParameters['q'], 'Николай Грошев');
      expect(appRouter.state.uri.queryParameters['kind'], 'author');
      expect(appRouter.state.uri.queryParameters['run'], '1');

      await tester.binding.handlePopRoute();
      await _pumpFrames(tester, frames: 12);
      expect(find.text('Book details'), findsOneWidget);
      expect(find.text('S.T.A.L.K.E.R. Дыхание зоны'), findsWidgets);
    },
  );

  testWidgets('runtime Slovofon link opens source book details', (
    tester,
  ) async {
    final deepLinks = _TestDeepLinkSource();
    final sourceRegistry = SourceRegistry([_DetailedBookConnector()]);

    appRouter.go('/');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(deepLinks.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
        ],
        child: SlovofonApp(deepLinks: deepLinks),
      ),
    );
    await _pumpFrames(tester, frames: 8);

    deepLinks.open(Uri.parse('slovofon://book?source=izib&book=2033'));
    await _pumpFrames(tester, frames: 30);

    expect(appRouter.state.uri.path, '/source-book/izib/2033');
    expect(find.text('S.T.A.L.K.E.R. Дыхание зоны'), findsOneWidget);
  });

  testWidgets('source book details returns to search with back and swipe', (
    tester,
  ) async {
    final playbackController = PlaybackController(
      engine: InMemoryAudioEngine(),
    );
    final transport = QueueIzibTransport([
      _fixtureText('izib_search_response.json'),
      _fixtureText('izib_book_response.json'),
      _fixtureText('izib_book_response.json'),
      _fixtureText('izib_book_response.json'),
      _fixtureText('izib_book_response.json'),
    ]);
    final sourceRegistry = SourceRegistry([
      IzibSourceConnector(client: IzibGraphQlClient(transport: transport)),
    ]);
    addTearDown(playbackController.dispose);

    appRouter.go('/search');
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
          playbackControllerProvider.overrideWith((ref) => playbackController),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    await tester.showKeyboard(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'метро');
    await tester.tap(find.byKey(const ValueKey('search-submit')));
    await _pumpFrames(tester, frames: 40);

    await tester.tap(find.text('Метро 2033').first);
    await _pumpFrames(tester, frames: 60);
    expect(find.text('Book details'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _pumpFrames(tester, frames: 20);
    expect(find.text('1 results'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Метро 2033'), findsOneWidget);

    await tester.tap(find.text('Метро 2033').first);
    await _pumpFrames(tester, frames: 60);
    expect(find.byType(SourceBookDetailsScreen), findsOneWidget);

    await tester.fling(
      find.byType(SourceBookDetailsScreen),
      const Offset(360, 0),
      1200,
    );
    await _pumpFrames(tester, frames: 20);

    expect(find.text('Search'), findsWidgets);
    expect(find.text('Book details'), findsNothing);
  });
}

class _MismatchedIdIzibConnector implements SourceConnector {
  @override
  String get id => 'izib';

  @override
  String get name => 'Izib';

  @override
  String get host => 'https://izib.uk';

  @override
  String get color => '#2F6FED';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsSearchByTitle: true,
    supportsDetails: true,
    supportsChapters: true,
    supportsDirectAudio: true,
    supportsDownload: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'audio.izib.uk'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return [
      BookSearchResult(
        ref: SourceBookRef(
          sourceId: id,
          sourceBookId: 'search-id',
          sourceUri: Uri.parse('https://izib.uk/book/search-id'),
        ),
        sourceName: name,
        title: 'Полураспад',
        author: 'Александр Зорич',
        narrator: 'Чайцын Александр',
        duration: const Duration(hours: 11, minutes: 49),
        year: 2019,
        chapterCount: 1,
        accessType: AccessType.free,
      ),
    ];
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 26);
    return BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: 'izib-details-id',
        bookId: 'izib-book-details-id',
        sourceId: id,
        sourceBookId: 'details-id',
        sourceUrl: 'https://izib.uk/book/details-id',
        title: 'Полураспад',
        normalizedTitle: 'полураспад',
        authors: const ['Александр Зорич'],
        narrators: const ['Чайцын Александр'],
        durationText: '11 ч 49 мин',
        publishedYear: 2019,
        accessType: AccessType.free,
        playbackAccess: PlaybackAccess.streamAndDownload,
        canStream: true,
        canDownload: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 26);
    return [
      Chapter(
        id: 'details-chapter-1',
        bookVersionId: 'izib-details-id',
        sourceId: id,
        sourceBookId: 'details-id',
        sourceChapterId: '1',
        index: 0,
        title: 'Глава 00. 000-01',
        normalizedTitle: 'глава 00 000 01',
        durationMs: 10 * 60 * 1000,
        streamRef: 'https://audio.izib.uk/books/details-id/001.mp3',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    return const [];
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async {
    return ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(Uri.parse(chapter.streamRef!)),
      originalUri: Uri.parse(chapter.streamRef!),
      resolvedAt: DateTime(2026, 5, 26),
      supportsRange: true,
    );
  }

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }
}

class _TwoChapterIzibSearchConnector implements SourceConnector {
  @override
  String get id => 'izib';

  @override
  String get name => 'Izib';

  @override
  String get host => 'https://izib.uk';

  @override
  String get color => '#2F6FED';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsSearchByTitle: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'audio.izib.uk'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return [
      BookSearchResult(
        ref: SourceBookRef(sourceId: id, sourceBookId: '2033'),
        sourceName: name,
        title: 'Метро 2033',
        author: 'Дмитрий Глуховский',
        narrator: 'Петр Иващенко',
        duration: const Duration(hours: 13, minutes: 6),
        year: 2019,
        chapterCount: 2,
        accessType: AccessType.free,
      ),
    ];
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) {
    throw UnimplementedError();
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) {
    throw UnimplementedError();
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    return const [];
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }
}

class _DuplicateTitleIzibConnector implements SourceConnector {
  @override
  String get id => 'izib';

  @override
  String get name => 'Izib';

  @override
  String get host => 'https://izib.uk';

  @override
  String get color => '#2F6FED';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsSearchByTitle: true,
    supportsDetails: true,
    supportsChapters: true,
    supportsDirectAudio: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'audio.izib.uk'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return [_duplicateResult('first-id'), _duplicateResult('second-id')];
  }

  BookSearchResult _duplicateResult(String sourceBookId) {
    return BookSearchResult(
      ref: SourceBookRef(sourceId: id, sourceBookId: sourceBookId),
      sourceName: name,
      title: 'Дубликат',
      author: 'Николай Грошев',
      narrator: 'Олег Шубин',
      duration: const Duration(minutes: 10),
      chapterCount: 1,
      accessType: AccessType.free,
    );
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 26);
    return BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: 'izib-${ref.sourceBookId}',
        bookId: 'izib-book-${ref.sourceBookId}',
        sourceId: id,
        sourceBookId: ref.sourceBookId,
        title: 'Дубликат',
        normalizedTitle: 'дубликат',
        authors: const ['Николай Грошев'],
        narrators: const ['Олег Шубин'],
        durationText: '10 мин',
        accessType: AccessType.free,
        playbackAccess: PlaybackAccess.streamAndDownload,
        canStream: true,
        canDownload: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 26);
    return [
      Chapter(
        id: '${ref.sourceBookId}-chapter-1',
        bookVersionId: 'izib-${ref.sourceBookId}',
        sourceId: id,
        sourceBookId: ref.sourceBookId,
        index: 0,
        title: 'Глава 1',
        normalizedTitle: 'глава 1',
        durationMs: 10 * 60 * 1000,
        streamRef: 'https://audio.izib.uk/books/${ref.sourceBookId}/001.mp3',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    return const [];
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async {
    return ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(Uri.parse(chapter.streamRef!)),
      originalUri: Uri.parse(chapter.streamRef!),
      resolvedAt: DateTime(2026, 5, 26),
      supportsRange: true,
    );
  }

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }
}

class _TwoChapterResumeConnector implements SourceConnector {
  @override
  String get id => 'izib';

  @override
  String get name => 'Izib';

  @override
  String get host => 'https://izib.uk';

  @override
  String get color => '#2F6FED';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsSearchByTitle: true,
    supportsDetails: true,
    supportsChapters: true,
    supportsDirectAudio: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'audio.izib.uk'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return [
      BookSearchResult(
        ref: const SourceBookRef(sourceId: 'izib', sourceBookId: 'resume-id'),
        sourceName: name,
        title: 'Продолжить',
        author: 'Автор',
        narrator: 'Чтец',
        duration: const Duration(minutes: 20),
        chapterCount: 2,
        accessType: AccessType.free,
      ),
    ];
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 26);
    return BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: 'izib-resume-id',
        bookId: 'izib-book-resume-id',
        sourceId: id,
        sourceBookId: ref.sourceBookId,
        title: 'Продолжить',
        normalizedTitle: 'продолжить',
        authors: const ['Автор'],
        narrators: const ['Чтец'],
        durationText: '20 мин',
        accessType: AccessType.free,
        playbackAccess: PlaybackAccess.streamAndDownload,
        canStream: true,
        canDownload: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 26);
    return [
      Chapter(
        id: 'resume-chapter-1',
        bookVersionId: 'izib-resume-id',
        sourceId: id,
        sourceBookId: ref.sourceBookId,
        index: 0,
        title: 'Глава 1',
        normalizedTitle: 'глава 1',
        durationMs: 10 * 60 * 1000,
        streamRef: 'https://audio.izib.uk/books/resume/001.mp3',
        createdAt: now,
        updatedAt: now,
      ),
      Chapter(
        id: 'resume-chapter-2',
        bookVersionId: 'izib-resume-id',
        sourceId: id,
        sourceBookId: ref.sourceBookId,
        index: 1,
        title: 'Глава 2',
        normalizedTitle: 'глава 2',
        durationMs: 10 * 60 * 1000,
        streamRef: 'https://audio.izib.uk/books/resume/002.mp3',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    return const [];
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async {
    return ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(Uri.parse(chapter.streamRef!)),
      originalUri: Uri.parse(chapter.streamRef!),
      resolvedAt: DateTime(2026, 5, 26),
      supportsRange: true,
    );
  }

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }
}

class QueueIzibTransport implements IzibGraphQlTransport {
  QueueIzibTransport(this.responses, {this.responseDelay = Duration.zero});

  final List<String> responses;
  final Duration responseDelay;

  @override
  Future<IzibGraphQlTransportResponse> post(
    Uri uri, {
    required String body,
    required Map<String, String> headers,
  }) async {
    if (responses.isEmpty) {
      throw StateError('No queued Izib response for $uri');
    }
    if (responseDelay > Duration.zero && responses.length < 3) {
      await Future<void>.delayed(responseDelay);
    }
    return IzibGraphQlTransportResponse(
      statusCode: 200,
      body: responses.removeAt(0),
    );
  }
}

class _SingleAknigaSearchConnector implements SourceConnector {
  @override
  String get id => 'akniga';

  @override
  String get name => 'Akniga';

  @override
  String get host => 'https://akniga.org';

  @override
  String get color => '#247a4d';

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(supportsSearch: true);

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'akniga.club'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return [
      BookSearchResult(
        ref: SourceBookRef(
          sourceId: id,
          sourceBookId: 'aleksandr-zorich-poluraspad-stalker-2010',
          sourceUri: Uri.parse(
            'https://akniga.org/aleksandr-zorich-poluraspad-stalker-2010',
          ),
        ),
        sourceName: name,
        title: 'Полураспад',
        author: 'Зорич Александр',
        narrator: 'Чайцын Александр',
        series: 'S.T.A.L.K.E.R.',
        duration: const Duration(hours: 11, minutes: 49),
        year: 2010,
        ratingValue: 4.6,
        ratingCount: 62,
        chapterCount: 1,
        accessType: AccessType.free,
      ),
    ];
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) {
    throw UnimplementedError();
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) {
    throw UnimplementedError();
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    return const [];
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }
}

class _ManyChaptersSourceConnector implements SourceConnector {
  @override
  String get id => 'many';

  @override
  String get name => 'Many';

  @override
  String get host => 'https://many.example';

  @override
  String get color => '#2F6FED';

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(supportsDetails: true, supportsChapters: true);

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'many.example'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return const [];
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 26);
    return BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: 'many-version',
        bookId: 'many-book',
        sourceId: 'many',
        sourceBookId: 'many-book',
        title: 'Many Chapters',
        normalizedTitle: 'many chapters',
        authors: const ['Author'],
        narrators: const ['Narrator'],
        durationText: '70 мин',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 26);
    return [
      for (var index = 1; index <= 7; index++)
        Chapter(
          id: 'chapter-$index',
          bookVersionId: 'many-version',
          sourceId: 'many',
          sourceBookId: 'many-book',
          sourceChapterId: '$index',
          index: index,
          title: 'Chapter ${index.toString().padLeft(3, '0')}',
          normalizedTitle: 'chapter $index',
          durationMs: 10 * 60 * 1000,
          streamRef: 'https://many.example/$index.mp3',
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    return const [];
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async {
    return ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(Uri.parse(chapter.streamRef!)),
      resolvedAt: DateTime(2026, 5, 26),
    );
  }

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }
}

class _DetailedBookConnector implements SourceConnector {
  @override
  String get id => 'izib';

  @override
  String get name => 'Izib';

  @override
  String get host => 'https://izib.uk';

  @override
  String get color => '#2F6FED';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsDetails: true,
    supportsChapters: true,
    supportsDirectAudio: true,
    supportsDownload: true,
    supportsDescription: true,
    supportsRating: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'audio.izib.uk'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return const [];
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 29);
    return BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: 'izib-2033',
        bookId: 'izib-book-2033',
        sourceId: id,
        sourceBookId: '2033',
        sourceUrl: 'https://izib.uk/art2033',
        title: 'S.T.A.L.K.E.R. Дыхание зоны',
        normalizedTitle: 'stalker дыхание зоны',
        authors: const ['Николай Грошев', 'Соавтор Второй'],
        narrators: const ['Олег Шубин', 'Тимофей Зобнин'],
        seriesTitle: 'Велес',
        seriesNumber: 1,
        genres: const ['Фантастика', 'S.T.A.L.K.E.R.'],
        description:
            'Сталкеры возвращаются в Зону, где старые маршруты уже не работают. '
            'Эта финальная часть описания должна быть скрыта до раскрытия.',
        coverUrl: 'https://izib.uk/covers/zone.jpg',
        durationMs: const Duration(hours: 18, minutes: 1).inMilliseconds,
        durationText: '18 ч 1 мин',
        publishedYear: 2019,
        ratingValue: 4.3,
        ratingCount: 433,
        accessType: AccessType.free,
        playbackAccess: PlaybackAccess.streamAndDownload,
        isFull: true,
        isAccessibleForFree: true,
        canStream: true,
        canDownload: true,
        rawSourceDataJson: jsonEncode({
          'views': 12843,
          'likes': 412,
          'dislikes': 21,
        }),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    final now = DateTime(2026, 5, 29);
    return [
      for (var index = 1; index <= 6; index++)
        Chapter(
          id: 'izib-2033-chapter-$index',
          bookVersionId: 'izib-2033',
          sourceId: id,
          sourceBookId: '2033',
          sourceChapterId: '$index',
          index: index,
          title: 'Глава ${index.toString().padLeft(2, '0')}',
          normalizedTitle: 'глава $index',
          durationMs: const Duration(minutes: 10).inMilliseconds,
          streamRef: 'https://audio.izib.uk/books/2033/$index.mp3',
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    return const [];
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async {
    return ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(Uri.parse(chapter.streamRef!)),
      originalUri: Uri.parse(chapter.streamRef!),
      resolvedAt: DateTime(2026, 5, 29),
      supportsRange: true,
    );
  }

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }
}

class _TestDeepLinkSource implements AppDeepLinkSource {
  final _controller = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async {
    return null;
  }

  @override
  Stream<Uri> get links => _controller.stream;

  void open(Uri uri) {
    _controller.add(uri);
  }

  void dispose() {
    _controller.close();
  }
}

class _NoopDownloadClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    return const DownloadClientResponse(
      bytes: Stream.empty(),
      totalBytes: 0,
      contentLength: 0,
      supportsResume: true,
      shouldAppend: false,
      fileExtension: 'mp3',
    );
  }
}

class _MemoryDownloadManager extends DownloadManager {
  _MemoryDownloadManager({FileDownloadStorage? storage})
    : super(
        client: _NoopDownloadClient(),
        storage:
            storage ??
            FileDownloadStorage(
              rootDirectory: Directory(
                '${Directory.systemTemp.path}/slovofon-stage7-memory-downloads',
              ),
            ),
        persistence: MemoryDownloadPersistenceStore(),
      );

  final _memoryTasks = <String, DownloadTask>{};
  final _memoryBooks = <String, AudioPlaybackBook>{};

  void seedTask(DownloadTask task) {
    _memoryTasks[task.id] = task;
    notifyListeners();
  }

  @override
  List<DownloadTask> get tasks => _memoryTasks.values.toList();

  @override
  DownloadTask? taskForChapter(String chapterId) {
    for (final task in _memoryTasks.values) {
      if (task.chapterId == chapterId) {
        return task;
      }
    }
    return null;
  }

  @override
  AudioPlaybackBook? bookForTask(String taskId) {
    return _memoryBooks[taskId] ?? super.bookForTask(taskId);
  }

  @override
  Future<List<DownloadTask>> enqueueMissingChapters(
    AudioPlaybackBook book,
  ) async {
    final now = DateTime(2026, 5, 26, 17);
    final queued = <DownloadTask>[];
    for (final chapter in book.chapters) {
      final id = 'chapter:${book.versionId}:${chapter.id}';
      final task = DownloadTask(
        id: id,
        bookId: book.id,
        bookVersionId: book.versionId,
        chapterId: chapter.id,
        sourceId: book.sourceId,
        type: DownloadTaskType.chapter,
        status: DownloadTaskStatus.queued,
        progress: 0,
        downloadedBytes: 0,
        createdAt: now,
        updatedAt: now,
      );
      _memoryTasks[id] = task;
      _memoryBooks[id] = book;
      queued.add(task);
    }
    notifyListeners();
    return queued;
  }

  @override
  Future<void> pause(String taskId) async {
    final task = _memoryTasks[taskId];
    if (task == null) {
      return;
    }
    _memoryTasks[taskId] = DownloadTask(
      id: task.id,
      bookId: task.bookId,
      bookVersionId: task.bookVersionId,
      chapterId: task.chapterId,
      sourceId: task.sourceId,
      type: task.type,
      status: DownloadTaskStatus.paused,
      priority: task.priority,
      progress: task.progress,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
      speedBytesPerSecond: 0,
      errorCode: task.errorCode,
      errorMessage: task.errorMessage,
      retryCount: task.retryCount,
      createdAt: task.createdAt,
      updatedAt: DateTime(2026, 5, 26, 17, 1),
    );
    notifyListeners();
  }

  @override
  Future<void> deleteBook(AudioPlaybackBook book) async {
    _memoryTasks.removeWhere((_, task) => task.bookVersionId == book.versionId);
    _memoryBooks.removeWhere((_, value) => value.versionId == book.versionId);
    notifyListeners();
  }

  @override
  Future<void> cancelAndDeleteBook(AudioPlaybackBook book) async {
    _memoryTasks.removeWhere((_, task) => task.bookVersionId == book.versionId);
    _memoryBooks.removeWhere((_, value) => value.versionId == book.versionId);
    notifyListeners();
  }
}

Future<void> _pumpFrames(
  WidgetTester tester, {
  int frames = 20,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var index = 0; index < frames; index++) {
    final exception = tester.takeException();
    if (exception != null) {
      fail('Unexpected widget exception: $exception');
    }
    await tester.pump(step);
  }
}

String _fixtureText(String name) {
  return File('test/sources/izib/fixtures/$name').readAsStringSync();
}

class _StaticPlaybackPersistenceStore implements PlaybackPersistenceStore {
  _StaticPlaybackPersistenceStore(this.progress);

  final List<PlaybackProgressSnapshot> progress;
  final savedSessions = <PlaybackSession>[];

  @override
  Future<PlaybackSession?> loadSession({String id = 'active'}) async {
    return savedSessions.where((session) => session.id == id).lastOrNull;
  }

  @override
  Future<List<PlaybackProgressSnapshot>> loadProgress() async {
    return progress;
  }

  @override
  Future<void> saveProgress(PlaybackProgressSnapshot progress) async {}

  @override
  Future<void> saveSession(PlaybackSession session) async {
    savedSessions.add(session);
  }
}
