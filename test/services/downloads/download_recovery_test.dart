import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';

void main() {
  late Directory root;
  late FileDownloadStorage storage;
  late MemoryDownloadPersistenceStore persistence;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('slovofon-recovery-test-');
    storage = FileDownloadStorage(rootDirectory: root);
    persistence = MemoryDownloadPersistenceStore();
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'pausing a stalled producer immediately frees the concurrency slot',
    () async {
      final book = _book();
      final client = _StalledFirstClient();
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
        maxConcurrentDownloads: 1,
      );
      final first = await manager.enqueueChapter(book, book.chapters.first);
      await client.started.future;
      await manager.pause(first.id);
      final next = await manager.enqueueChapter(book, book.chapters.last);
      await manager.waitForIdle().timeout(const Duration(seconds: 2));
      expect(client.opened, 2);
      expect(manager.taskById(first.id)?.status, DownloadTaskStatus.paused);
      expect(manager.taskById(next.id)?.status, DownloadTaskStatus.completed);
      manager.dispose();
      client.release.complete();
    },
  );

  test(
    'cancel and delete book finishes while client.open remains pending',
    () async {
      final book = _book();
      final client = _PendingClient();
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
      );
      await manager.enqueueChapter(book, book.chapters.first);
      await client.started.future;
      await manager
          .cancelAndDeleteBook(book)
          .timeout(const Duration(seconds: 2));
      expect(manager.tasks, isEmpty);
      expect(await storage.bookDirectoryFor(book).exists(), isFalse);
      client.release.complete(_bytesResponse(0));
      await Future<void>.delayed(Duration.zero);
      manager.dispose();
    },
  );

  test(
    'retry resolves fresh media instead of replaying an expired URL',
    () async {
      final book = _book();
      final client = _RecordingClient(failFirst: true);
      var refreshes = 0;
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
        refreshBookForDownloads: (previous) async {
          refreshes++;
          return _freshBook(previous);
        },
      );
      final task = await manager.enqueueChapter(book, book.chapters.first);
      await manager.waitForIdle();
      expect(manager.taskById(task.id)?.status, DownloadTaskStatus.failed);
      await manager.retryChapter(book, book.chapters.first);
      await manager.waitForIdle();
      expect(manager.taskById(task.id)?.status, DownloadTaskStatus.completed);
      expect(refreshes, 1);
      expect(client.sources.map((source) => source.uri.query), [
        'token=old',
        'token=fresh',
      ]);
      manager.dispose();
    },
  );

  test(
    'restored paused chapter refreshes URL and resumes existing bytes',
    () async {
      final book = _book();
      final chapter = book.chapters.first;
      await storage.writeMetadata(book);
      final part = storage.partFileFor(book, chapter);
      await part.parent.create(recursive: true);
      await part.writeAsBytes([1, 2, 3]);
      final now = DateTime.utc(2026, 1, 1);
      final task = DownloadTask(
        id: 'chapter:${book.versionId}:${chapter.id}',
        bookId: book.id,
        bookVersionId: book.versionId,
        chapterId: chapter.id,
        sourceId: book.sourceId,
        type: DownloadTaskType.chapter,
        status: DownloadTaskStatus.running,
        downloadedBytes: 3,
        totalBytes: 6,
        createdAt: now,
        updatedAt: now,
      );
      await persistence.saveTask(task);
      final client = _RecordingClient();
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
        refreshBookForDownloads: (previous) async => _freshBook(previous),
      );
      await manager.loadPersistedTasks();
      expect(manager.taskById(task.id)?.status, DownloadTaskStatus.paused);
      final restored = manager.bookForTask(task.id)!;
      await manager.resumeChapter(restored, restored.chapters.first);
      await manager.waitForIdle();
      expect(client.sources.single.uri.query, 'token=fresh');
      expect(client.startBytes.single, 3);
      final completed = await storage.completedChapterFile(book, chapter);
      expect(await completed!.readAsBytes(), [1, 2, 3, 4, 5, 6]);
      manager.dispose();
    },
  );

  test(
    'enqueue missing chapters scans and writes metadata only once',
    () async {
      final counted = _CountingStorage(rootDirectory: root);
      final book = _book();
      final manager = DownloadManager(
        client: _RecordingClient(),
        storage: counted,
        persistence: persistence,
      );
      await manager.enqueueMissingChapters(book);
      await manager.waitForIdle();
      expect(counted.scans, 1);
      expect(counted.writes, 1);
      manager.dispose();
    },
  );

  test(
    'resuming a restored queued task schedules its refreshed media',
    () async {
      final book = _book();
      final chapter = book.chapters.first;
      await storage.writeMetadata(book);
      final now = DateTime.utc(2026, 1, 1);
      await persistence.saveTask(
        DownloadTask(
          id: 'chapter:${book.versionId}:${chapter.id}',
          bookId: book.id,
          bookVersionId: book.versionId,
          chapterId: chapter.id,
          sourceId: book.sourceId,
          type: DownloadTaskType.chapter,
          status: DownloadTaskStatus.queued,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final client = _RecordingClient();
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
        refreshBookForDownloads: (previous) async => _freshBook(previous),
      );
      await manager.loadPersistedTasks();
      await manager.resumeChapter(book, chapter);
      await manager.waitForIdle();
      expect(client.sources.single.uri.query, 'token=fresh');
      expect(manager.tasks.single.status, DownloadTaskStatus.completed);
      manager.dispose();
    },
  );
}

AudioPlaybackBook _book() => AudioPlaybackBook(
  id: 'book',
  versionId: 'version',
  sourceId: 'source',
  sourceBookId: 'remote',
  title: 'Book',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Source',
  chapters: [
    for (var i = 0; i < 2; i++)
      AudioPlaybackChapter(
        id: 'chapter-$i',
        index: i,
        title: 'Chapter $i',
        duration: const Duration(minutes: 1),
        mediaSource: AudioMediaSource.url(
          Uri.parse('https://example.test/$i.mp3?token=old'),
        ),
      ),
  ],
);

AudioPlaybackBook _freshBook(AudioPlaybackBook previous) => previous.copyWith(
  chapters: [
    for (final chapter in previous.chapters)
      chapter.copyWith(
        mediaSource: AudioMediaSource.url(
          chapter.mediaSource!.uri.replace(query: 'token=fresh'),
        ),
      ),
  ],
);

DownloadClientResponse _bytesResponse(int startByte) => DownloadClientResponse(
  bytes: Stream.value([1, 2, 3, 4, 5, 6].skip(startByte).toList()),
  totalBytes: 6,
  contentLength: 6 - startByte,
  supportsResume: true,
  shouldAppend: startByte > 0,
  fileExtension: 'mp3',
);

class _RecordingClient implements DownloadClient {
  _RecordingClient({this.failFirst = false});
  final bool failFirst;
  final sources = <AudioMediaSource>[];
  final startBytes = <int>[];
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    sources.add(source);
    startBytes.add(startByte);
    if (failFirst && sources.length == 1) {
      throw const DownloadClientException('Expired media.', statusCode: 403);
    }
    return _bytesResponse(startByte);
  }
}

class _StalledFirstClient implements DownloadClient {
  final started = Completer<void>();
  final release = Completer<void>();
  var opened = 0;
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    opened++;
    if (opened > 1) return _bytesResponse(startByte);
    started.complete();
    return DownloadClientResponse(
      bytes: _stalled(),
      totalBytes: 1,
      contentLength: 1,
      supportsResume: false,
      shouldAppend: false,
      fileExtension: 'mp3',
    );
  }

  Stream<List<int>> _stalled() async* {
    await release.future;
    yield [1];
  }
}

class _PendingClient implements DownloadClient {
  final started = Completer<void>();
  final release = Completer<DownloadClientResponse>();
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) {
    started.complete();
    return release.future;
  }
}

class _CountingStorage extends FileDownloadStorage {
  _CountingStorage({required super.rootDirectory});
  var scans = 0;
  var writes = 0;
  @override
  Future<Map<int, File>> completedChapterFiles(AudioPlaybackBook book) {
    scans++;
    return super.completedChapterFiles(book);
  }

  @override
  Future<void> writeMetadata(AudioPlaybackBook book) {
    writes++;
    return super.writeMetadata(book);
  }
}
