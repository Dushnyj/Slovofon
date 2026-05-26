import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/data/mock/mock_audio_playback.dart';
import 'package:slovofon/data/mock/stage3_mock_data.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';

void main() {
  testWidgets('home exposes Stage 3 mock sections and opens book details', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Continue listening'), findsOneWidget);
    expect(find.text('Started books'), findsOneWidget);

    await tester.tap(find.text('Мастер и Маргарита').first);
    await _pumpFrames(tester);

    expect(find.text('Book details'), findsOneWidget);
    expect(find.text('Other versions'), findsOneWidget);
    expect(find.text('Chapters'), findsWidgets);

    appRouter.go('/');
    await _pumpFrames(tester);
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -500),
      warnIfMissed: false,
    );
    await _pumpFrames(tester);
    expect(find.text('Offline downloads'), findsOneWidget);
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, -500),
      warnIfMissed: false,
    );
    await _pumpFrames(tester);
    expect(find.text('Mock recommendations'), findsOneWidget);
  });

  testWidgets('mini player opens full player mock pages', (tester) async {
    await _pumpApp(tester);
    await _pumpUntilFound(tester, find.byTooltip('Open full player'));

    await tester.tap(find.byTooltip('Open full player'));
    await _pumpFrames(tester);

    expect(find.text('Мастер и Маргарита'), findsWidgets);
    expect(find.text('1:30:00'), findsOneWidget);
    expect(find.byTooltip('Sleep timer'), findsOneWidget);
    expect(find.byTooltip('Rewind 15 seconds'), findsOneWidget);

    await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
    await _pumpFrames(tester);

    expect(find.text('Chapters'), findsOneWidget);
    expect(find.byTooltip('Download'), findsWidgets);
  });

  testWidgets('search shows filters and navigable mock results', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Search'));
    await _pumpFrames(tester);

    expect(find.text('Grouped duplicates'), findsOneWidget);
    expect(find.text('Sort: relevance'), findsOneWidget);
    expect(find.textContaining('mock results'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'метро');
    await _pumpFrames(tester);

    expect(find.text('Метро 2033'), findsOneWidget);
    await tester.tap(find.text('Метро 2033').first);
    await _pumpFrames(tester);

    expect(find.text('Book details'), findsOneWidget);
    expect(find.text('Метро 2033'), findsWidgets);
  });

  testWidgets('library downloads and settings expose Stage 3 sections', (
    tester,
  ) async {
    final manager = await _seededDownloadManager(tester);
    await _pumpAppWithDownloadManager(tester, manager);

    await tester.tap(find.text('Library'));
    await _pumpFrames(tester);

    expect(find.text('All'), findsWidgets);
    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Downloaded'), findsWidgets);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    await tester.tap(find.text('Downloads'));
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
    expect(find.byTooltip('Cancel download'), findsWidgets);
    expect(find.byTooltip('Delete downloaded'), findsWidgets);

    await tester.tap(find.text('Settings'));
    await _pumpFrames(tester);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Downloads'), findsWidgets);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
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
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    final exception = tester.takeException();
    if (exception != null) {
      fail('Unexpected widget exception while waiting for $finder: $exception');
    }
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
}

Future<PlaybackController> _testPlaybackController() async {
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  await controller.loadBook(
    mockAudioPlaybackBook(activeMockBook),
    chapterIndex: mockCurrentChapterIndex(activeMockBook),
    position: mockCurrentChapterPosition(activeMockBook),
  );
  controller.setSleepTimer(const Duration(minutes: 90));
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
  await manager.loadPersistedTasks();
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
    id: 'chapter:${playbackBook.versionId}:${chapter.id}',
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
