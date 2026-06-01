import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/shared/download_ui_state.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/ui/components/download_action_button.dart';

void main() {
  group('DownloadManager', () {
    late Directory tempDir;
    late FileDownloadStorage storage;
    late RecordingDownloadPersistenceStore persistence;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slovofon-downloads-');
      storage = FileDownloadStorage(rootDirectory: tempDir);
      persistence = RecordingDownloadPersistenceStore();
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'downloads a chapter through a part file and exposes offline media',
      () async {
        final client = ByteDownloadClient([
          [1, 2, 3],
          [4, 5, 6],
        ]);
        final manager = DownloadManager(
          client: client,
          storage: storage,
          persistence: persistence,
          clock: () => DateTime.utc(2026, 5, 26, 12),
        );

        final task = await manager.enqueueChapter(_book, _book.chapters.first);
        await manager.waitForIdle();

        final completed = manager.taskById(task.id)!;
        final offlineBook = await manager.offlinePlaybackBook(_book);
        final offlineSource = offlineBook.chapters.first.mediaSource!;
        final finalFile = File(offlineSource.filePath);
        final partFile = storage.partFileFor(_book, _book.chapters.first);

        expect(completed.status, DownloadTaskStatus.completed);
        expect(completed.progress, 1);
        expect(completed.downloadedBytes, 6);
        expect(completed.totalBytes, 6);
        expect(client.startBytes, [0]);
        expect(partFile.existsSync(), isFalse);
        expect(finalFile.existsSync(), isTrue);
        expect(finalFile.readAsBytesSync(), [1, 2, 3, 4, 5, 6]);
        expect(offlineSource.type, AudioMediaSourceType.file);
        expect(
          persistence.savedTasks.last.status,
          DownloadTaskStatus.completed,
        );
        expect(persistence.chapterUpdates.last.localPath, finalFile.path);
      },
    );

    test('pauses and resumes from the existing part file', () async {
      final gate = Completer<void>();
      final firstChunkWritten = Completer<void>();
      final client = PausableDownloadClient(
        firstChunkWritten: firstChunkWritten,
        gate: gate,
      );
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
        clock: () => DateTime.utc(2026, 5, 26, 12),
      );

      final task = await manager.enqueueChapter(_book, _book.chapters.first);
      await firstChunkWritten.future;
      await manager.pause(task.id);
      gate.complete();
      await manager.waitForIdle();

      final partFile = storage.partFileFor(_book, _book.chapters.first);
      expect(manager.taskById(task.id)!.status, DownloadTaskStatus.paused);
      expect(partFile.existsSync(), isTrue);
      expect(partFile.readAsBytesSync(), [1, 2, 3]);

      await manager.resumeChapter(_book, _book.chapters.first);
      await manager.waitForIdle();

      final finalFile = storage.chapterFileFor(
        _book,
        _book.chapters.first,
        extension: 'bin',
      );
      expect(manager.taskById(task.id)!.status, DownloadTaskStatus.completed);
      expect(client.startBytes, [0, 3]);
      expect(finalFile.readAsBytesSync(), [1, 2, 3, 4, 5, 6]);
    });

    test(
      'cancels partial downloads and deletes completed files only',
      () async {
        final gate = Completer<void>();
        final firstChunkWritten = Completer<void>();
        final client = PausableDownloadClient(
          firstChunkWritten: firstChunkWritten,
          gate: gate,
        );
        final manager = DownloadManager(
          client: client,
          storage: storage,
          persistence: persistence,
        );

        final task = await manager.enqueueChapter(_book, _book.chapters.first);
        await firstChunkWritten.future;
        await manager.cancel(task.id);
        gate.complete();
        await manager.waitForIdle();

        expect(manager.taskById(task.id)!.status, DownloadTaskStatus.canceled);
        expect(
          storage.partFileFor(_book, _book.chapters.first).existsSync(),
          isFalse,
        );

        await manager.enqueueChapter(_book, _book.chapters.first);
        await manager.waitForIdle();
        final offlineBook = await manager.offlinePlaybackBook(_book);
        final downloadedFile = File(
          offlineBook.chapters.first.mediaSource!.filePath,
        );
        expect(downloadedFile.existsSync(), isTrue);

        await manager.deleteChapter(_book, _book.chapters.first);

        expect(downloadedFile.existsSync(), isFalse);
        expect(manager.taskForChapter(_book.chapters.first.id), isNull);
        expect(persistence.deletedTaskIds, contains(task.id));
        expect(
          persistence.chapterUpdates.last.status,
          DownloadTaskStatus.canceled,
        );
      },
    );

    test('downloads a whole book and writes metadata', () async {
      final manager = DownloadManager(
        client: ByteDownloadClient([
          [7, 8, 9],
        ]),
        storage: storage,
        persistence: persistence,
      );

      final tasks = await manager.enqueueBook(_book);
      await manager.waitForIdle();

      final metadata = storage.metadataFileFor(_book);
      expect(tasks, hasLength(2));
      expect(
        manager.tasks.where(
          (task) => task.status == DownloadTaskStatus.completed,
        ),
        hasLength(2),
      );
      expect(metadata.existsSync(), isTrue);
      expect(
        metadata.readAsStringSync(),
        contains('"title":"Мастер и Маргарита"'),
      );
      expect(metadata.readAsStringSync(), contains('"chapters"'));
    });

    test(
      'book download action continues a partially downloaded book',
      () async {
        final manager = DownloadManager(
          client: ByteDownloadClient([
            [7, 8, 9],
          ]),
          storage: storage,
          persistence: persistence,
        );

        await manager.enqueueChapter(_book, _book.chapters.first);
        await manager.waitForIdle();

        expect(
          downloadStateForBook(manager, _book),
          BookCardDownloadState.paused,
        );
        expect(manager.tasks, hasLength(1));

        await runBookCardDownloadAction(manager, _book);
        await manager.waitForIdle();

        expect(manager.tasks, hasLength(2));
        expect(manager.tasks.map((task) => task.status).toSet(), {
          DownloadTaskStatus.completed,
        });
        final offlineBook = await manager.offlinePlaybackBook(_book);
        expect(
          offlineBook.chapters.map((chapter) => chapter.isDownloaded).toList(),
          [true, true],
        );
      },
    );

    test('starts three chapter downloads in parallel by default', () async {
      final client = BlockingDownloadClient(expectedStartedCount: 3);
      addTearDown(() {
        if (!client.release.isCompleted) {
          client.release.complete();
        }
      });
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
      );

      await manager.enqueueBook(_bookWithChapterCount(4));

      await expectLater(
        client.allExpectedStarted.future.timeout(
          const Duration(milliseconds: 100),
        ),
        completes,
      );

      client.release.complete();
      await manager.waitForIdle();
    });

    test('loads persisted tasks with saved book metadata context', () async {
      await storage.writeMetadata(_book);
      final chapter = _book.chapters.first;
      final task = DownloadTask(
        id: 'chapter:${_book.versionId}:${chapter.id}',
        bookId: _book.id,
        bookVersionId: _book.versionId,
        chapterId: chapter.id,
        sourceId: _book.sourceId,
        type: DownloadTaskType.chapter,
        status: DownloadTaskStatus.completed,
        progress: 1,
        downloadedBytes: 10,
        totalBytes: 10,
        createdAt: DateTime.utc(2026, 5, 26, 12),
        updatedAt: DateTime.utc(2026, 5, 26, 12),
      );
      await persistence.saveTask(task);
      final manager = DownloadManager(
        client: ByteDownloadClient([]),
        storage: storage,
        persistence: persistence,
      );

      await manager.loadPersistedTasks(recoverInterrupted: false);

      final restoredBook = manager.bookForTask(task.id);
      expect(restoredBook?.title, 'Мастер и Маргарита');
      expect(restoredBook?.author, 'Михаил Булгаков');
      expect(restoredBook?.narrator, 'Вячеслав Герасимов');
      expect(restoredBook?.chapters, hasLength(2));
      expect(
        restoredBook?.chapters.first.mediaSource?.uri.toString(),
        'https://media.example.test/book-1/chapter-1.bin',
      );
    });

    test(
      'metadata refresh preserves cached cover, local files, and durations',
      () async {
        final localCover = await storage.writeCoverBytes(_book, [1, 2, 3]);
        final localChapterFile = storage.chapterFileFor(
          _book,
          _book.chapters.first,
          extension: 'mp3',
        );
        await localChapterFile.parent.create(recursive: true);
        await localChapterFile.writeAsBytes([4, 5, 6]);
        final cachedBook = _bookWith(
          coverUrl: localCover,
          chapters: [
            _book.chapters.first.copyWith(
              isDownloaded: true,
              mediaSource: AudioMediaSource.file(localChapterFile.path),
            ),
          ],
        );
        await storage.writeMetadata(cachedBook);

        await storage.writeMetadata(
          _bookWith(
            coverUrl: 'https://img.example.test/remote.jpg',
            chapters: [
              _book.chapters.first.copyWith(
                duration: Duration.zero,
                isDownloaded: false,
              ),
            ],
          ),
        );

        final persisted = await storage.readMetadataForIds(
          _book.sourceId,
          _book.versionId,
        );
        final chapter = persisted!.chapters.single;
        expect(persisted.coverUrl, localCover);
        expect(chapter.duration, const Duration(minutes: 10));
        expect(chapter.isDownloaded, isTrue);
        expect(chapter.mediaSource?.type, AudioMediaSourceType.file);
      },
    );

    test(
      'offlinePlaybackBook reuses cached metadata and local cover',
      () async {
        final localCover = await storage.writeCoverBytes(_book, [1, 2, 3]);
        final localChapterFile = storage.chapterFileFor(
          _book,
          _book.chapters.first,
          extension: 'mp3',
        );
        await localChapterFile.parent.create(recursive: true);
        await localChapterFile.writeAsBytes([4, 5, 6]);
        await storage.writeMetadata(
          _bookWith(
            coverUrl: localCover,
            chapters: [
              _book.chapters.first.copyWith(
                id: 'cached-chapter-1',
                index: 1,
                isDownloaded: true,
                mediaSource: AudioMediaSource.file(localChapterFile.path),
              ),
              _book.chapters.last,
            ],
          ),
        );

        final offlineBook = await storage.offlinePlaybackBook(
          _bookWith(coverUrl: 'https://img.example.test/remote.jpg'),
        );

        expect(offlineBook.coverUrl, localCover);
        expect(
          offlineBook.chapters.first.mediaSource?.type,
          AudioMediaSourceType.file,
        );
        expect(
          offlineBook.chapters.first.duration,
          const Duration(minutes: 10),
        );
      },
    );

    test('card cache cleanup preserves downloaded book files', () async {
      final downloadedCover = await storage.writeCoverBytes(_book, [1, 2, 3]);
      final downloadedFile = storage.chapterFileFor(
        _book,
        _book.chapters.first,
        extension: 'mp3',
      );
      await downloadedFile.parent.create(recursive: true);
      await downloadedFile.writeAsBytes([4, 5, 6]);
      await storage.writeMetadata(
        _bookWith(
          coverUrl: downloadedCover,
          chapters: [
            _book.chapters.first.copyWith(
              isDownloaded: true,
              mediaSource: AudioMediaSource.file(downloadedFile.path),
            ),
          ],
        ),
      );

      final cacheOnlyBook = _bookWith(
        id: 'cache-only',
        versionId: 'cache-only-version',
        coverUrl: 'https://img.example.test/cache-only.jpg',
      );
      await storage.writeMetadata(cacheOnlyBook);
      await storage.writeCoverBytes(cacheOnlyBook, [7, 8, 9, 10]);

      final before = await storage.cardCacheStats();
      expect(before.bookCount, 2);
      expect(before.bytes, greaterThan(0));

      final cleared = await storage.clearCardCache();

      expect(cleared.bookCount, 1);
      expect(downloadedFile.existsSync(), isTrue);
      expect(
        await storage.readMetadataForIds(_book.sourceId, _book.versionId),
        isNotNull,
      );
      expect(
        await storage.readMetadataForIds(
          cacheOnlyBook.sourceId,
          cacheOnlyBook.versionId,
        ),
        isNull,
      );
    });

    test(
      'cacheBookMetadata refreshes persisted and active book context',
      () async {
        await storage.writeMetadata(_book);
        final chapter = _book.chapters.first;
        final task = DownloadTask(
          id: 'chapter:${_book.versionId}:${chapter.id}',
          bookId: _book.id,
          bookVersionId: _book.versionId,
          chapterId: chapter.id,
          sourceId: _book.sourceId,
          type: DownloadTaskType.chapter,
          status: DownloadTaskStatus.paused,
          progress: 0.4,
          downloadedBytes: 4,
          totalBytes: 10,
          createdAt: DateTime.utc(2026, 5, 26, 12),
          updatedAt: DateTime.utc(2026, 5, 26, 12),
        );
        await persistence.saveTask(task);
        final manager = DownloadManager(
          client: ByteDownloadClient([]),
          storage: storage,
          persistence: persistence,
        );
        await manager.loadPersistedTasks(recoverInterrupted: false);

        await manager.cacheBookMetadata(_updatedBook);

        expect(manager.bookForTask(task.id)?.title, 'Мастер и Маргарита 2');
        expect(manager.bookForTask(task.id)?.coverUrl, contains('updated'));
        final persisted = await storage.readMetadataForIds(
          _updatedBook.sourceId,
          _updatedBook.versionId,
        );
        expect(persisted?.title, 'Мастер и Маргарита 2');
        expect(persisted?.coverUrl, contains('updated'));
      },
    );
  });
}

final _book = AudioPlaybackBook(
  id: 'book-1',
  versionId: 'version-1',
  sourceId: 'yakniga',
  title: 'Мастер и Маргарита',
  author: 'Михаил Булгаков',
  narrator: 'Вячеслав Герасимов',
  sourceName: 'Yakniga',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-1',
      index: 1,
      title: 'Глава 1',
      duration: const Duration(minutes: 10),
      mediaSource: AudioMediaSource.url(
        Uri.parse('https://media.example.test/book-1/chapter-1.bin'),
      ),
    ),
    AudioPlaybackChapter(
      id: 'chapter-2',
      index: 2,
      title: 'Глава 2',
      duration: const Duration(minutes: 9),
      mediaSource: AudioMediaSource.url(
        Uri.parse('https://media.example.test/book-1/chapter-2.bin'),
      ),
    ),
  ],
);

final _updatedBook = AudioPlaybackBook(
  id: 'book-1',
  versionId: 'version-1',
  sourceId: 'yakniga',
  sourceBookId: 'canonical-book-1',
  title: 'Мастер и Маргарита 2',
  author: 'Михаил Булгаков',
  narrator: 'Вячеслав Герасимов',
  sourceName: 'Yakniga',
  coverUrl: 'https://img.example.test/updated.jpg',
  chapters: _book.chapters,
);

AudioPlaybackBook _bookWith({
  String? id,
  String? versionId,
  String? coverUrl,
  List<AudioPlaybackChapter>? chapters,
}) {
  return AudioPlaybackBook(
    id: id ?? _book.id,
    versionId: versionId ?? _book.versionId,
    sourceId: _book.sourceId,
    sourceBookId: _book.sourceBookId,
    title: _book.title,
    author: _book.author,
    narrator: _book.narrator,
    sourceName: _book.sourceName,
    coverUrl: coverUrl ?? _book.coverUrl,
    chapters: chapters ?? _book.chapters,
  );
}

AudioPlaybackBook _bookWithChapterCount(int count) {
  return AudioPlaybackBook(
    id: 'book-many',
    versionId: 'version-many',
    sourceId: 'yakniga',
    title: 'Большая книга',
    author: 'Автор',
    narrator: 'Чтец',
    sourceName: 'Yakniga',
    chapters: [
      for (var index = 0; index < count; index++)
        AudioPlaybackChapter(
          id: 'chapter-many-$index',
          index: index,
          title: 'Глава $index',
          duration: const Duration(minutes: 5),
          mediaSource: AudioMediaSource.url(
            Uri.parse('https://media.example.test/book-many/$index.bin'),
          ),
        ),
    ],
  );
}

class ByteDownloadClient implements DownloadClient {
  ByteDownloadClient(this.chunks);

  final List<List<int>> chunks;
  final startBytes = <int>[];

  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    startBytes.add(startByte);
    final allBytes = chunks.expand((chunk) => chunk).toList();
    final bytes = allBytes.skip(startByte).toList();

    return DownloadClientResponse(
      bytes: Stream<List<int>>.fromIterable([bytes]),
      totalBytes: allBytes.length,
      contentLength: bytes.length,
      supportsResume: true,
      shouldAppend: startByte > 0,
      fileExtension: p.extension(source.uri.path).replaceFirst('.', ''),
    );
  }
}

class PausableDownloadClient implements DownloadClient {
  PausableDownloadClient({required this.firstChunkWritten, required this.gate});

  final Completer<void> firstChunkWritten;
  final Completer<void> gate;
  final startBytes = <int>[];

  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    startBytes.add(startByte);

    return DownloadClientResponse(
      totalBytes: 6,
      contentLength: 6 - startByte,
      supportsResume: true,
      shouldAppend: startByte > 0,
      fileExtension: 'bin',
      bytes: _stream(startByte, cancellationToken),
    );
  }

  Stream<List<int>> _stream(
    int startByte,
    DownloadCancellationToken cancellationToken,
  ) async* {
    if (startByte == 0) {
      yield [1, 2, 3];
      if (!firstChunkWritten.isCompleted) {
        firstChunkWritten.complete();
      }
      await gate.future;
    }

    if (!cancellationToken.isCanceled) {
      yield [4, 5, 6];
    }
  }
}

class BlockingDownloadClient implements DownloadClient {
  BlockingDownloadClient({required this.expectedStartedCount});

  final int expectedStartedCount;
  final allExpectedStarted = Completer<void>();
  final release = Completer<void>();
  final startedSources = <Uri>[];

  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    startedSources.add(source.uri);
    if (startedSources.length >= expectedStartedCount &&
        !allExpectedStarted.isCompleted) {
      allExpectedStarted.complete();
    }

    return DownloadClientResponse(
      bytes: _stream(cancellationToken),
      totalBytes: 1,
      contentLength: 1,
      supportsResume: true,
      shouldAppend: false,
      fileExtension: 'bin',
    );
  }

  Stream<List<int>> _stream(
    DownloadCancellationToken cancellationToken,
  ) async* {
    await release.future;
    if (!cancellationToken.isCanceled) {
      yield [1];
    }
  }
}

class RecordingDownloadPersistenceStore implements DownloadPersistenceStore {
  final savedTasks = <DownloadTask>[];
  final chapterUpdates = <DownloadChapterUpdate>[];
  final deletedTaskIds = <String>[];

  @override
  Future<void> deleteTask(String id) async {
    deletedTaskIds.add(id);
    savedTasks.removeWhere((task) => task.id == id);
  }

  @override
  Future<List<DownloadTask>> loadTasks({
    bool recoverInterrupted = false,
  }) async {
    return savedTasks;
  }

  @override
  Future<void> saveTask(DownloadTask task) async {
    savedTasks.removeWhere((existing) => existing.id == task.id);
    savedTasks.add(task);
  }

  @override
  Future<void> updateChapter(DownloadChapterUpdate update) async {
    chapterUpdates.add(update);
  }
}
