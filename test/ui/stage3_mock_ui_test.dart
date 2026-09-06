import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/data/mock/mock_audio_playback.dart';
import 'package:slovofon/data/mock/stage3_mock_data.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';

import 'test_search_history_store.dart';

void main() {
  testWidgets(
    'home starts from real-source search and does not seed mock data',
    (tester) async {
      await _pumpApp(tester, seedPlayback: false);

      expect(find.text('Find a book'), findsOneWidget);
      expect(find.text('Open search'), findsOneWidget);
      expect(find.text('Мастер и Маргарита'), findsNothing);
      expect(find.text('Mock recommendations'), findsNothing);
      expect(find.textContaining('mock data'), findsNothing);

      await tester.tap(find.text('Open search'));
      await _pumpFrames(tester);

      expect(find.text('Search'), findsWidgets);
      expect(find.text('Enter a search query'), findsOneWidget);
    },
  );

  testWidgets('home hides source search prompt when playback is active', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Continue listening'), findsOneWidget);
    expect(find.text('Мастер и Маргарита'), findsWidgets);
    expect(find.text('Find a book'), findsNothing);
    expect(find.text('Open search'), findsNothing);
  });

  testWidgets(
    'home shows saved listening history sorted and swipe hides only home card',
    (tester) async {
      final directory = Directory(
        '${Directory.systemTemp.path}/slovofon-home-history-${DateTime.now().microsecondsSinceEpoch}',
      )..createSync(recursive: true);
      addTearDown(() {
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      });
      final storage = FileDownloadStorage(rootDirectory: directory);
      final olderBook = _historyPlaybackBook(
        id: 'older-book',
        versionId: 'izib-older-book',
        title: 'Старая книга',
      );
      final newerBook = _historyPlaybackBook(
        id: 'newer-book',
        versionId: 'izib-newer-book',
        title: 'Новая книга',
      );
      _writeHistoryMetadata(storage, olderBook);
      _writeHistoryMetadata(storage, newerBook);
      final progressStore = _StaticPlaybackPersistenceStore([
        PlaybackProgressSnapshot(
          bookId: olderBook.id,
          bookVersionId: olderBook.versionId,
          currentChapterId: olderBook.chapters.first.id,
          currentPositionMs: 60000,
          maxReachedGlobalPositionMs: 60000,
          totalDurationMs: olderBook.totalDuration.inMilliseconds,
          listenedDurationMs: 60000,
          percent: 10,
          isFinished: false,
          lastPlayedAt: DateTime(2026, 5, 28, 12),
        ),
        PlaybackProgressSnapshot(
          bookId: newerBook.id,
          bookVersionId: newerBook.versionId,
          currentChapterId: newerBook.chapters.first.id,
          currentPositionMs: 180000,
          maxReachedGlobalPositionMs: 180000,
          totalDurationMs: newerBook.totalDuration.inMilliseconds,
          listenedDurationMs: 180000,
          percent: 30,
          isFinished: false,
          lastPlayedAt: DateTime(2026, 5, 29, 12),
        ),
      ]);
      final controller = PlaybackController(engine: InMemoryAudioEngine());

      appRouter.go('/');
      tester.view.physicalSize = const Size(430, 932);
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
            playbackPersistenceStoreProvider.overrideWith((ref) {
              return progressStore;
            }),
            downloadStorageProvider.overrideWith((ref) => storage),
            searchHistoryStoreProvider.overrideWith(
              (ref) => MemorySearchHistoryStore(),
            ),
          ],
          child: const SlovofonApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await _pumpFrames(tester);

      // Metadata is read asynchronously; fake frame time alone does not let
      // filesystem callbacks finish after startup.
      await _pumpUntilFound(
        tester,
        find.text('Continue listening'),
        allowIo: true,
      );

      expect(find.text('Continue listening'), findsOneWidget);
      expect(find.text('Новая книга'), findsOneWidget);
      expect(find.text('Старая книга'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Новая книга')).dy,
        lessThan(tester.getTopLeft(find.text('Старая книга')).dy),
      );

      await tester.drag(find.text('Новая книга'), const Offset(-520, 0));
      await _pumpFrames(tester);

      expect(find.text('Новая книга'), findsNothing);
      expect(find.text('Старая книга'), findsOneWidget);
      expect((await progressStore.loadProgress()).length, 2);
    },
  );

  testWidgets('mini player opens full player mock pages', (tester) async {
    await _pumpApp(tester);
    await _pumpUntilFound(tester, find.byTooltip('Open full player'));

    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);

    expect(find.text('Мастер и Маргарита'), findsWidgets);
    expect(find.text('1:30:00'), findsOneWidget);
    expect(find.text('24:00'), findsOneWidget);
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
    expect(find.byTooltip('Rewind 15 seconds'), findsOneWidget);

    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await _pumpFrames(tester);

    expect(find.text('Chapters'), findsOneWidget);
    expect(find.byTooltip('Download'), findsWidgets);
  });

  testWidgets('desktop shell uses sidebar and bottom now playing bar', (
    tester,
  ) async {
    final playbackController = await _testPlaybackController();
    appRouter.go('/');
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackControllerProvider.overrideWith((ref) {
            ref.onDispose(playbackController.dispose);
            return playbackController;
          }),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);

    expect(
      find.byKey(const ValueKey('desktop-navigation-sidebar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('desktop-content-frame')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-mini-player-bar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobile-navigation-bar')), findsNothing);

    await tester.tap(find.byTooltip('Chapters'));
    await _pumpFrames(tester);

    expect(find.text('Chapters'), findsOneWidget);
    expect(find.byTooltip('Download'), findsWidgets);
  });

  testWidgets('desktop mini player volume button opens volume controls', (
    tester,
  ) async {
    final playbackController = await _testPlaybackController();
    appRouter.go('/');
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackControllerProvider.overrideWith((ref) {
            ref.onDispose(playbackController.dispose);
            return playbackController;
          }),
          searchHistoryStoreProvider.overrideWith(
            (ref) => MemorySearchHistoryStore(),
          ),
        ],
        child: const SlovofonApp(),
      ),
    );
    await _pumpFrames(tester);
    await playbackController.setVolume(0.55);
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('desktop-volume-popover')), findsNothing);

    await tester.tap(find.byTooltip('Volume'));
    await _pumpFrames(tester);

    expect(
      find.byKey(const ValueKey('desktop-volume-popover')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('desktop-volume-slider')), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('desktop-volume-mute-button')));
    await _pumpFrames(tester);

    expect(playbackController.state.volume, 0);

    await tester.tap(find.byKey(const ValueKey('desktop-volume-mute-button')));
    await _pumpFrames(tester);

    expect(playbackController.state.volume, closeTo(0.55, 0.001));
    expect(find.text('55%'), findsOneWidget);
  });

  testWidgets('full player chapter tap starts selected chapter', (
    tester,
  ) async {
    final playbackController = await _testPlaybackController();
    await _pumpApp(tester, playbackController: playbackController);

    await _pumpUntilFound(tester, find.byTooltip('Open full player'));
    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);
    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await _pumpFrames(tester);

    await tester.tap(find.text('Понтий Пилат'));
    await _pumpFrames(tester, frames: 8);

    expect(playbackController.state.currentChapter?.title, 'Понтий Пилат');
    expect(playbackController.state.isPlaying, isTrue);
  });

  testWidgets('full player hides inactive sleep timer pill', (tester) async {
    final playbackController = await _testPlaybackController(
      enableSleepTimer: false,
    );
    await _pumpApp(tester, playbackController: playbackController);

    await _pumpUntilFound(tester, find.byTooltip('Open full player'));
    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('sleep-timer-pill')), findsNothing);
    expect(find.text('24:00'), findsOneWidget);
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
  });

  testWidgets('full player sleep timer can target chapter end', (tester) async {
    final playbackController = await _testPlaybackController(
      enableSleepTimer: false,
    );
    await _pumpApp(tester, playbackController: playbackController);

    await _pumpUntilFound(tester, find.byTooltip('Open full player'));
    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);
    await tester.tap(find.byTooltip('Sleep timer'));
    await _pumpFrames(tester);

    expect(find.text('Until chapter ends'), findsOneWidget);

    await tester.tap(find.text('Until chapter ends'));
    await _pumpFrames(tester);

    expect(
      playbackController.state.sleepTimerRemaining,
      playbackController.state.chapterDuration -
          playbackController.state.position,
    );
    expect(find.byKey(const ValueKey('sleep-timer-pill')), findsOneWidget);
  });

  testWidgets('full player uses shared book download progress action', (
    tester,
  ) async {
    final manager = await _seededDownloadManager(tester);
    await _pumpAppWithDownloadManager(tester, manager);

    await _pumpUntilFound(tester, find.byTooltip('Open full player'));
    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);

    expect(
      find.byKey(const ValueKey('download-action-progress')),
      findsOneWidget,
    );
    expect(find.byTooltip('Cancel download'), findsOneWidget);
  });

  testWidgets('full player chapter list exposes chapter download progress', (
    tester,
  ) async {
    final manager = await _seededDownloadManager(tester);
    await _pumpAppWithDownloadManager(tester, manager);

    await _pumpUntilFound(tester, find.byTooltip('Open full player'));
    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);
    await tester.drag(find.byType(TabBarView), const Offset(-420, 0));
    await _pumpFrames(tester);

    expect(find.text('Chapters'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('download-action-progress')),
      findsWidgets,
    );
  });

  testWidgets('full player chapter list opens with active chapter first', (
    tester,
  ) async {
    final playbackController = await _longPlaybackController(chapterIndex: 29);
    await _pumpApp(tester, playbackController: playbackController);

    await _pumpUntilFound(tester, find.byTooltip('Open full player'));
    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);
    await tester.drag(find.byType(TabBarView), const Offset(-420, 0));
    await _pumpFrames(tester);

    expect(find.text('Chapters'), findsOneWidget);
    expect(
      find
          .byKey(const ValueKey('full-player-chapter-long-chapter-30'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey('full-player-chapter-long-chapter-29'))
          .hitTestable(),
      findsNothing,
    );
  });

  testWidgets('full player chapter list offers return to current chapter', (
    tester,
  ) async {
    final playbackController = await _longPlaybackController(chapterIndex: 29);
    await _pumpApp(tester, playbackController: playbackController);

    await _pumpUntilFound(tester, find.byTooltip('Open full player'));
    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);
    await tester.drag(find.byType(TabBarView), const Offset(-420, 0));
    await _pumpFrames(tester);

    expect(
      find.byKey(const ValueKey('full-player-current-chapter-button')),
      findsNothing,
    );

    await tester.drag(find.byType(ListView).last, const Offset(0, -540));
    await _pumpFrames(tester);

    expect(
      find.byKey(const ValueKey('full-player-current-chapter-button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('full-player-current-chapter-button')),
    );
    await _pumpFrames(tester);

    expect(
      find
          .byKey(const ValueKey('full-player-chapter-long-chapter-30'))
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('full player metadata links open scoped search', (tester) async {
    final playbackController = await _metadataPlaybackController();
    await _pumpApp(
      tester,
      playbackController: playbackController,
      sourceRegistry: SourceRegistry([MockSourceConnector.yakniga()]),
    );

    await _pumpUntilFound(tester, find.byTooltip('Open full player'));
    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);

    expect(
      find.text('Очень длинное название книги, которое занимает две строки'),
      findsOneWidget,
    );
    expect(find.text('Автор Один'), findsOneWidget);
    expect(find.text('Автор Два'), findsOneWidget);
    expect(find.text('Чтец Один'), findsOneWidget);
    expect(find.text('Чтец Два'), findsOneWidget);
    expect(find.text('Велес (1)'), findsOneWidget);
    expect(find.text('2015'), findsOneWidget);

    await tester.tap(find.text('Автор Один'));
    await _pumpFrames(tester);

    await _pumpUntilFound(tester, find.byTooltip('Back'));
    await tester.tap(find.byTooltip('Back'));
    await _pumpFrames(tester);

    expect(
      find.text('Очень длинное название книги, которое занимает две строки'),
      findsOneWidget,
    );
    expect(find.text('Автор Один'), findsOneWidget);
  });

  testWidgets('search shows filters and real-source ready state', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('mobile-navigation-item-1')));
    await _pumpFrames(tester);

    expect(find.text('Search in: Title'), findsOneWidget);
    expect(find.text('Sources: All sources'), findsNothing);
    expect(find.text('Sort: relevance'), findsOneWidget);
    expect(find.text('Enter a search query'), findsOneWidget);
    expect(find.textContaining('mock results'), findsNothing);
  });

  testWidgets('desktop search results render as a tiled grid', (tester) async {
    await _pumpApp(
      tester,
      viewportSize: const Size(1280, 820),
      sourceRegistry: SourceRegistry([
        MockSourceConnector(
          id: 'yakniga',
          name: 'Yakniga',
          host: 'mock.yakniga.local',
          color: '#2E7D63',
          books: [
            _gridTestBook(
              id: 'tile-book-1',
              title: 'Плитка первая',
              progress: 0.2,
            ),
            _gridTestBook(
              id: 'tile-book-2',
              title: 'Плитка вторая',
              progress: 0.4,
            ),
          ],
        ),
      ]),
    );

    await tester.tap(find.byKey(const ValueKey('wide-navigation-item-1')));
    await _pumpFrames(tester);
    await tester.enterText(find.byType(TextField).first, 'плитка');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _pumpFrames(tester, frames: 40);

    expect(find.byType(BookCard), findsAtLeastNWidgets(2));

    final first = tester.getTopLeft(find.byType(BookCard).at(0));
    final second = tester.getTopLeft(find.byType(BookCard).at(1));
    expect((second.dy - first.dy).abs(), lessThan(120));
  });

  testWidgets('search history entries can be deleted one by one', (
    tester,
  ) async {
    final historyStore = MemorySearchHistoryStore();
    await historyStore.record('полураспад', SearchKind.title);
    await historyStore.record('метро', SearchKind.author);
    await _pumpApp(
      tester,
      seedPlayback: false,
      searchHistoryStore: historyStore,
    );

    await tester.tap(find.byKey(const ValueKey('mobile-navigation-item-1')));
    await _pumpFrames(tester);

    expect(find.text('полураспад'), findsOneWidget);
    expect(find.text('метро'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete from history').first);
    await _pumpFrames(tester);

    expect(find.byTooltip('Delete from history'), findsOneWidget);
    expect(
      find.text('полураспад').evaluate().length +
          find.text('метро').evaluate().length,
      1,
    );
  });

  testWidgets('search sort sheet fits above mini player without overflow', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('mobile-navigation-item-1')));
    await _pumpFrames(tester);
    await tester.tap(find.text('Sort: relevance'));
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('relevance'), findsWidgets);
    expect(find.text('rating'), findsWidgets);
    expect(find.text('year'), findsWidgets);
    expect(find.text('duration'), findsWidgets);
    expect(find.text('title'), findsWidgets);
    expect(find.text('Done'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('relevance').first).dy,
      greaterThan(260),
    );
  });

  testWidgets('library is empty until real source books are saved', (
    tester,
  ) async {
    await _pumpApp(tester, seedPlayback: false);

    await tester.tap(find.byKey(const ValueKey('mobile-navigation-item-2')));
    await _pumpFrames(tester);

    expect(find.text('Filter: All'), findsOneWidget);
    expect(find.text('Listening'), findsNothing);
    await tester.tap(find.text('Filter: All'));
    await _pumpFrames(tester);
    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await _pumpFrames(tester);
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.text('Open search'), findsOneWidget);
    expect(find.text('Мастер и Маргарита'), findsNothing);
  });

  testWidgets('downloads and settings expose Stage 3 sections', (tester) async {
    final manager = await _seededDownloadManager(tester);
    await _pumpAppWithDownloadManager(tester, manager);

    await tester.tap(find.byKey(const ValueKey('mobile-navigation-item-3')));
    await _pumpFrames(tester);

    expect(find.text('Метро 2033'), findsOneWidget);
    expect(find.text('Мастер и Маргарита'), findsWidgets);
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -700),
      warnIfMissed: false,
    );
    await _pumpFrames(tester);
    expect(find.text('451 градус по Фаренгейту'), findsOneWidget);
    expect(find.text('Библиотека'), findsNothing);

    await tester.ensureVisible(find.text('Метро 2033'));
    await _pumpFrames(tester);
    await tester.tap(find.text('Метро 2033'));
    await _pumpFrames(tester);
    expect(find.text('Библиотека'), findsOneWidget);
    expect(find.byTooltip('Delete downloaded'), findsWidgets);

    await tester.ensureVisible(find.text('Мастер и Маргарита').first);
    await _pumpFrames(tester);
    await tester.tap(find.text('Мастер и Маргарита').first);
    await _pumpFrames(tester);
    expect(
      find.text('Никогда не разговаривайте с неизвестными'),
      findsOneWidget,
    );
    expect(find.byTooltip('Cancel download'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('mobile-navigation-item-4')));
    await _pumpFrames(tester);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Player'), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-navigation-item-3')),
      findsOneWidget,
    );
    expect(find.text('Compact cards'), findsNothing);
    expect(find.text('Theme preview'), findsNothing);
    expect(find.text('Izib'), findsNothing);
    expect(find.text('Sources'), findsWidgets);
    await tester.tap(find.text('Sources').last);
    await _pumpFrames(tester);
    expect(find.text('Izib'), findsOneWidget);
    expect(find.text('Akniga'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await _pumpFrames(tester);
  });

  testWidgets('settings expose real appearance language and source controls', (
    tester,
  ) async {
    await _pumpApp(tester, seedPlayback: false);

    await tester.tap(find.byKey(const ValueKey('mobile-navigation-item-4')));
    await _pumpFrames(tester);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Player'), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-navigation-item-3')),
      findsOneWidget,
    );
    expect(find.text('Compact cards'), findsNothing);
    expect(find.text('Source name on cards'), findsNothing);
    expect(find.text('Progress percent on covers'), findsNothing);
    expect(find.text('Theme preview'), findsNothing);
    expect(find.text('Card cache'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    await tester.tap(find.text('Card cache'));
    await _pumpFrames(tester);
    expect(find.text('Downloaded books are preserved'), findsOneWidget);
    expect(find.text('Clear card cache'), findsOneWidget);
    Navigator.of(tester.element(find.text('Card cache').last)).pop();
    await _pumpFrames(tester);

    await tester.tap(find.text('About'));
    await _pumpFrames(tester);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Build number'), findsOneWidget);
    expect(find.text('Application GitHub'), findsOneWidget);
    expect(find.text('Project website'), findsNothing);
    expect(find.text('Telegram support bot'), findsNothing);
    expect(find.text('Telegram channel'), findsNothing);
    expect(find.text('Telegram chat'), findsNothing);
    expect(find.text('Update channel'), findsNothing);
    Navigator.of(tester.element(find.text('About').last)).pop();
    await _pumpFrames(tester);

    await tester.tap(find.text('Appearance'));
    await _pumpFrames(tester);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('AMOLED'), findsNothing);
    expect(find.text('Accent color'), findsOneWidget);
    expect(find.text('Custom color'), findsOneWidget);
    await tester.tap(find.text('Custom color').last);
    await _pumpFrames(tester, frames: 8);
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.text('Done').last);
    await _pumpFrames(tester, frames: 8);
    expect(find.text('Text size: 100%'), findsOneWidget);
    expect(find.text('Animations'), findsOneWidget);
    await tester.ensureVisible(find.byType(Slider).first);
    await tester.drag(find.byType(Slider).first, const Offset(420, 0));
    await _pumpFrames(tester);
    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await _pumpFrames(tester);
    expect(find.textContaining('Text size: 200%'), findsOneWidget);

    await tester.ensureVisible(find.text('Language'));
    await tester.tap(find.text('Language'));
    await _pumpFrames(tester);
    expect(find.text('System language'), findsWidgets);
    expect(find.text('Русский'), findsOneWidget);
    await tester.tap(find.text('Русский'));
    await _pumpFrames(tester, frames: 8);
    expect(find.text('Настройки'), findsWidgets);

    expect(find.text('Источники'), findsWidgets);
    await tester.ensureVisible(find.text('Источники').last);
    await tester.tap(find.text('Источники').last);
    await _pumpFrames(tester);
    expect(find.text('Изибук'), findsWidgets);
    expect(find.text('База книг'), findsWidgets);
    await tester.ensureVisible(find.text('Готово'));
    await tester.tap(find.text('Готово'));
    await _pumpFrames(tester);
  });

  for (final languageCode in ['ru', 'en']) {
    testWidgets(
      'about keeps GitHub and metadata without removed links in $languageCode',
      (tester) async {
        final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
        await settings.setLanguageCode(languageCode);
        await _pumpApp(tester, seedPlayback: false, appSettingsStore: settings);

        final russian = languageCode == 'ru';
        await tester.tap(
          find.byKey(const ValueKey('mobile-navigation-item-4')),
        );
        await _pumpFrames(tester);
        await tester.tap(find.text(russian ? 'О приложении' : 'About'));
        await _pumpFrames(tester);

        expect(find.text(russian ? 'Версия' : 'Version'), findsOneWidget);
        expect(
          find.text(russian ? 'Номер сборки' : 'Build number'),
          findsOneWidget,
        );
        final github = find.text(
          russian ? 'GitHub приложения' : 'Application GitHub',
        );
        expect(github, findsOneWidget);
        expect(
          find.text('https://github.com/Dushnyj/Slovofon'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ListTile>(
                find.ancestor(of: github, matching: find.byType(ListTile)),
              )
              .onTap,
          isNotNull,
        );

        for (final removed in [
          'Сайт проекта',
          'Project website',
          'Telegram-бот поддержки',
          'Telegram support bot',
          'Telegram-канал',
          'Telegram channel',
          'https://slovofon.duckdns.org',
          'https://t.me/slovofon_bot',
          'https://t.me/slovofon',
        ]) {
          expect(find.text(removed), findsNothing);
        }
      },
    );
  }

  testWidgets('max text scale keeps shell mini player and full player stable', (
    tester,
  ) async {
    final appSettingsStore = AppSettingsStore(
      MemoryAppSettingsPersistenceStore(),
    );
    await appSettingsStore.setTextScale(2);

    await _pumpApp(tester, appSettingsStore: appSettingsStore);

    expect(tester.takeException(), isNull);
    final miniBottom = tester.getBottomLeft(find.byType(MiniPlayerBar)).dy;
    final navTop = tester
        .getTopLeft(find.byKey(const ValueKey('mobile-navigation-bar')))
        .dy;
    expect(navTop - miniBottom, lessThanOrEqualTo(4));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('mobile-navigation-bar-content')))
          .height,
      greaterThanOrEqualTo(64),
    );
    await _pumpUntilFound(tester, find.byTooltip('Open full player'));
    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Play'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Size viewportSize = const Size(430, 932),
  bool seedPlayback = true,
  PlaybackController? playbackController,
  SourceRegistry? sourceRegistry,
  SearchHistoryStore? searchHistoryStore,
  AppSettingsStore? appSettingsStore,
}) async {
  final controller =
      playbackController ??
      (seedPlayback
          ? await _testPlaybackController()
          : PlaybackController(engine: InMemoryAudioEngine()));
  appRouter.go('/');
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // This mock fixture has no disk-backed library; never wait on dev cache I/O.
        libraryPlaybackBooksProvider.overrideWith((ref) async => const []),
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(controller.dispose);
          return controller;
        }),
        searchHistoryStoreProvider.overrideWith(
          (ref) => searchHistoryStore ?? MemorySearchHistoryStore(),
        ),
        if (appSettingsStore != null)
          appSettingsStoreProvider.overrideWith((ref) => appSettingsStore),
        if (sourceRegistry != null)
          sourceRegistryProvider.overrideWith((ref) => sourceRegistry),
      ],
      child: const SlovofonApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await _pumpFrames(tester);
}

Future<void> _pumpAppWithDownloadManager(
  WidgetTester tester,
  DownloadManager manager,
) async {
  final playbackController = await _testPlaybackController();
  appRouter.go('/');
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(playbackController.dispose);
          return playbackController;
        }),
        downloadManagerProvider.overrideWith((ref) {
          ref.onDispose(manager.dispose);
          return manager;
        }),
        searchHistoryStoreProvider.overrideWith(
          (ref) => MemorySearchHistoryStore(),
        ),
      ],
      child: const SlovofonApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(
  WidgetTester tester, {
  int frames = 20,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var index = 0; index < frames; index++) {
    await tester.pump(step);
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 100,
  bool allowIo = false,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    final exception = tester.takeException();
    if (exception != null) {
      fail('Unexpected widget exception while waiting for $finder: $exception');
    }
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    if (allowIo) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
}

Future<PlaybackController> _testPlaybackController({
  bool enableSleepTimer = true,
}) async {
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  await controller.loadBook(
    mockAudioPlaybackBook(activeMockBook),
    chapterIndex: mockCurrentChapterIndex(activeMockBook),
    position: mockCurrentChapterPosition(activeMockBook),
  );
  if (enableSleepTimer) {
    controller.setSleepTimer(const Duration(minutes: 90));
  }
  return controller;
}

Future<PlaybackController> _metadataPlaybackController() async {
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  await controller.loadBook(
    const AudioPlaybackBook(
      id: 'metadata-book',
      versionId: 'yakniga-metadata-book',
      sourceId: 'yakniga',
      sourceBookId: 'metadata-book',
      title: 'Очень длинное название книги, которое занимает две строки',
      author: 'Автор Один, Автор Два, Автор Три',
      narrator: 'Чтец Один, Чтец Два, Чтец Три',
      sourceName: 'Yakniga',
      seriesTitle: 'Велес',
      seriesNumber: 1,
      publishedYear: 2015,
      chapters: [
        AudioPlaybackChapter(
          id: 'chapter-1',
          index: 1,
          title: 'Глава 1',
          duration: Duration(minutes: 42),
        ),
      ],
    ),
  );
  return controller;
}

MockBook _gridTestBook({
  required String id,
  required String title,
  required double progress,
}) {
  return MockBook(
    id: id,
    title: title,
    author: 'Автор плитки',
    narrator: 'Чтец плитки',
    sourceId: 'yakniga',
    sourceName: 'Yakniga',
    durationLabel: '11 ч 49 мин',
    chapterCount: 3,
    progress: progress,
    access: BookAccess.free,
    description: 'Книга для проверки desktop-сетки.',
    year: 2020,
    audioYear: 2020,
    genre: 'Фантастика',
    series: 'Тестовый цикл',
    ratingLabel: '4.5',
    activeChapterTitle: 'Глава 1',
    positionLabel: '00:00',
    remainingLabel: '10 мин',
    downloadStatus: MockDownloadStatus.downloaded,
    isFavorite: false,
    isLater: false,
    isFinished: false,
    versions: const [
      MockBookVersion(
        sourceName: 'Yakniga',
        narrator: 'Чтец плитки',
        durationLabel: '11 ч 49 мин',
        accessLabel: 'Бесплатно',
      ),
    ],
    chapters: const [
      MockChapter(
        index: 1,
        title: 'Глава 1',
        durationLabel: '10 мин',
        progress: 0,
        isDownloaded: false,
        isCurrent: true,
      ),
    ],
    bookmarks: const [],
  );
}

Future<PlaybackController> _longPlaybackController({
  required int chapterIndex,
}) async {
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  await controller.loadBook(
    AudioPlaybackBook(
      id: 'long-book',
      versionId: 'long-book-version',
      sourceId: 'izib',
      sourceBookId: 'long-book',
      title: 'Длинная книга',
      author: 'Автор',
      narrator: 'Чтец',
      sourceName: 'Izib',
      chapters: [
        for (var index = 1; index <= 80; index++)
          AudioPlaybackChapter(
            id: 'long-chapter-$index',
            index: index,
            title: 'Глава ${index.toString().padLeft(3, '0')}',
            duration: const Duration(minutes: 10),
          ),
      ],
    ),
    chapterIndex: chapterIndex,
    position: const Duration(minutes: 3),
  );
  return controller;
}

Future<DownloadManager> _seededDownloadManager(WidgetTester tester) async {
  final directory = Directory(
    '${Directory.systemTemp.path}/slovofon-ui-downloads-${DateTime.now().microsecondsSinceEpoch}',
  );
  directory.createSync(recursive: true);
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  final persistence = MemoryDownloadPersistenceStore();
  final now = DateTime(2026, 5, 26);
  final seeds = [
    _seedTask(
      book: stage3MockBooks[2],
      status: DownloadTaskStatus.completed,
      progress: 1,
      downloadedBytes: 148 * 1024 * 1024,
      totalBytes: 148 * 1024 * 1024,
      now: now,
    ),
    _seedTask(
      book: stage3MockBooks[0],
      status: DownloadTaskStatus.queued,
      progress: 0,
      downloadedBytes: 0,
      totalBytes: 64 * 1024 * 1024,
      now: now,
    ),
    _seedTask(
      book: stage3MockBooks[3],
      status: DownloadTaskStatus.failed,
      progress: 0.31,
      downloadedBytes: 14 * 1024 * 1024,
      totalBytes: 44 * 1024 * 1024,
      now: now,
    ),
  ];
  for (final task in seeds) {
    await persistence.saveTask(task);
  }

  final manager = DownloadManager(
    client: _NoopDownloadClient(),
    storage: FileDownloadStorage(rootDirectory: directory),
    persistence: persistence,
  );
  await tester.runAsync(manager.loadPersistedTasks);
  // Production never guesses metadata from fixture ids. Attach the books that
  // these synthetic download tasks were explicitly seeded from.
  for (final book in [
    stage3MockBooks[2],
    stage3MockBooks[0],
    stage3MockBooks[3],
  ]) {
    manager.attachBookContext(mockAudioPlaybackBook(book));
  }
  for (final task in manager.tasks) {
    expect(manager.bookForTask(task.id)?.versionId, task.bookVersionId);
    expect(manager.bookForTask(task.id)?.sourceId, task.sourceId);
  }
  return manager;
}

DownloadTask _seedTask({
  required MockBook book,
  required DownloadTaskStatus status,
  required double progress,
  required int downloadedBytes,
  required int totalBytes,
  required DateTime now,
}) {
  final playbackBook = mockAudioPlaybackBook(book);
  final chapter = playbackBook.chapters.first;
  return DownloadTask(
    id: 'chapter:${playbackBook.sourceId}:${playbackBook.versionId}:${chapter.id}',
    bookId: playbackBook.id,
    bookVersionId: playbackBook.versionId,
    chapterId: chapter.id,
    sourceId: playbackBook.sourceId,
    type: DownloadTaskType.chapter,
    status: status,
    progress: progress,
    downloadedBytes: downloadedBytes,
    totalBytes: totalBytes,
    createdAt: now,
    updatedAt: now,
  );
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
      fileExtension: 'bin',
    );
  }
}

AudioPlaybackBook _historyPlaybackBook({
  required String id,
  required String versionId,
  required String title,
}) {
  return AudioPlaybackBook(
    id: id,
    versionId: versionId,
    sourceId: 'izib',
    sourceBookId: id,
    title: title,
    author: 'Автор истории',
    narrator: 'Чтец истории',
    sourceName: 'Izib',
    coverUrl: 'https://example.com/$id.jpg',
    chapters: const [
      AudioPlaybackChapter(
        id: 'chapter-1',
        index: 0,
        title: 'Глава 1',
        duration: Duration(minutes: 10),
      ),
    ],
  );
}

void _writeHistoryMetadata(
  FileDownloadStorage storage,
  AudioPlaybackBook book,
) {
  final metadataFile = storage.metadataFileFor(book);
  metadataFile.parent.createSync(recursive: true);
  metadataFile.writeAsStringSync(
    jsonEncode({
      'bookId': book.id,
      'bookVersionId': book.versionId,
      'sourceId': book.sourceId,
      'sourceBookId': book.sourceBookId,
      'title': book.title,
      'authors': [book.author],
      'narrators': [book.narrator],
      'sourceName': book.sourceName,
      'coverUrl': book.coverUrl,
      'chapters': [
        for (final chapter in book.chapters)
          {
            'id': chapter.id,
            'index': chapter.index,
            'title': chapter.title,
            'durationMs': chapter.duration.inMilliseconds,
            'isDownloaded': chapter.isDownloaded,
          },
      ],
    }),
  );
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
