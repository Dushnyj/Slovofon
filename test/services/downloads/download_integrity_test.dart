import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/shared/download_ui_state.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';

void main() {
  late Directory root;
  late FileDownloadStorage storage;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('slovofon-integrity-test-');
    storage = FileDownloadStorage(rootDirectory: root);
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'failed finalize never deletes the previous completed chapter',
    () async {
      final file = storage.chapterFileFor(
        _book,
        _book.chapters.first,
        extension: 'mp3',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes([10, 20, 30]);
      await expectLater(
        storage.finalizeChapter(_book, _book.chapters.first, extension: 'mp3'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsBytes(), [10, 20, 30]);
    },
  );

  for (final size in [2, 4]) {
    test(
      'body size $size cannot be published as a complete three-byte chapter',
      () async {
        final manager = DownloadManager(
          client: _BytesClient(List.filled(size, 1), total: 3),
          storage: storage,
          persistence: MemoryDownloadPersistenceStore(),
        );
        addTearDown(manager.dispose);
        final task = await manager.enqueueChapter(_book, _book.chapters.first);
        await manager.waitForIdle();
        expect(manager.taskById(task.id)!.status, DownloadTaskStatus.failed);
        expect(
          await storage.completedChapterFile(_book, _book.chapters.first),
          isNull,
        );
        expect(
          await storage.partialBytesFor(_book, _book.chapters.first),
          size,
        );
      },
    );
  }

  test(
    'short bounded range keeps resumable bytes rather than marking complete',
    () async {
      final part = storage.partFileFor(_book, _book.chapters.first);
      await part.parent.create(recursive: true);
      await part.writeAsBytes([1, 2]);
      final manager = DownloadManager(
        client: _BytesClient([3, 4], total: 6, append: true),
        storage: storage,
        persistence: MemoryDownloadPersistenceStore(),
      );
      addTearDown(manager.dispose);
      final task = await manager.enqueueChapter(_book, _book.chapters.first);
      await manager.waitForIdle();
      expect(manager.taskById(task.id)!.status, DownloadTaskStatus.failed);
      expect(await part.readAsBytes(), [1, 2, 3, 4]);
      expect(
        await storage.completedChapterFile(_book, _book.chapters.first),
        isNull,
      );
    },
  );

  test(
    'oversized partial file restarts local media rather than appending stale bytes',
    () async {
      final original = File('${root.path}/original.mp3');
      await original.writeAsBytes([1, 2, 3]);
      final book = _book.copyWith(
        chapters: [
          _book.chapters.first.copyWith(
            mediaSource: AudioMediaSource.file(original.path),
          ),
        ],
      );
      final part = storage.partFileFor(book, book.chapters.first);
      await part.parent.create(recursive: true);
      await part.writeAsBytes([9, 9, 9, 9, 9]);
      final manager = DownloadManager(
        client: DefaultDownloadClient(),
        storage: storage,
        persistence: MemoryDownloadPersistenceStore(),
      );
      addTearDown(manager.dispose);
      final task = await manager.enqueueChapter(book, book.chapters.first);
      await manager.waitForIdle();
      expect(manager.taskById(task.id)!.status, DownloadTaskStatus.completed);
      expect(
        await (await storage.completedChapterFile(
          book,
          book.chapters.first,
        ))!.readAsBytes(),
        [1, 2, 3],
      );
    },
  );

  test(
    'enqueue during hydration waits before modifying the recovered task map',
    () async {
      final persistence = _DeferredLoad();
      final client = _BytesClient([1, 2, 3], total: 3);
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      final loading = manager.loadPersistedTasks();
      final enqueuing = manager.enqueueChapter(_book, _book.chapters.first);
      // Allow a pre-fix enqueue to run: it must not be allowed to commit anything
      // while the initial read is still capable of replacing the whole task map.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(client.opens, 0);
      expect(persistence.saves, 0);
      persistence.gate.complete();
      await loading;
      final task = await enqueuing;
      await manager.waitForIdle();
      expect(manager.tasks.single.id, task.id);
      expect(manager.tasks.single.status, DownloadTaskStatus.completed);
      expect(
        (await persistence.loadTasks()).single.status,
        DownloadTaskStatus.completed,
      );
    },
  );

  test('late running write cannot overwrite a newer paused state', () async {
    final persistence = _DeferredRunningWrite();
    final manager = DownloadManager(
      client: _BytesClient([1], total: 1),
      storage: storage,
      persistence: persistence,
    );
    addTearDown(manager.dispose);
    final task = await manager.enqueueChapter(_book, _book.chapters.first);
    await persistence.runningStarted.future;
    final pausing = manager.pause(task.id);
    await Future<void>.delayed(Duration.zero);
    persistence.releaseRunning.complete();
    await pausing;
    await manager.waitForIdle();
    expect(manager.taskById(task.id)!.status, DownloadTaskStatus.paused);
    expect(
      (await persistence.loadTasks()).single.status,
      DownloadTaskStatus.paused,
    );
    expect(persistence.maxWriters, 1);
  });

  test(
    'scheduler persistence failure is contained and retry can recover',
    () async {
      final persistence = _FailRunningWrite();
      final manager = DownloadManager(
        client: _BytesClient([1], total: 1),
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      final task = await manager.enqueueChapter(_book, _book.chapters.first);
      await manager.waitForIdle();
      expect(manager.taskById(task.id)!.status, DownloadTaskStatus.failed);
      expect(manager.taskById(task.id)!.errorCode, 'persistence_failed');
      persistence.fail = false;
      await manager.retryChapter(_book, _book.chapters.first);
      await manager.waitForIdle();
      expect(manager.taskById(task.id)!.status, DownloadTaskStatus.completed);
    },
  );
  test(
    'cache cleanup preserves pending and paused download metadata before first byte',
    () async {
      final persistence = MemoryDownloadPersistenceStore();
      final client = _PendingHeadersClient();
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      final task = await manager.enqueueChapter(_book, _book.chapters.first);
      await client.opened.future;
      expect(
        await storage.partFileFor(_book, _book.chapters.first).exists(),
        isFalse,
      );
      final secondStorage = FileDownloadStorage(rootDirectory: root);
      await secondStorage.clearCardCache();
      expect(await storage.metadataFileFor(_book).exists(), isTrue);
      await manager.pause(task.id);
      await manager.waitForIdle();
      await secondStorage.clearCardCache();
      expect(
        (await secondStorage.readMetadataForIds(
          _book.sourceId,
          _book.versionId,
        ))!.versionId,
        _book.versionId,
      );
      final restarted = DownloadManager(
        client: _BytesClient([1], total: 1),
        storage: secondStorage,
        persistence: persistence,
      );
      addTearDown(restarted.dispose);
      await restarted.loadPersistedTasks();
      expect(restarted.bookForTask(task.id), isNotNull);
      client.release.complete(
        const DownloadClientResponse(
          bytes: Stream.empty(),
          totalBytes: 0,
          contentLength: 0,
          supportsResume: false,
          shouldAppend: false,
          fileExtension: 'mp3',
        ),
      );
    },
  );

  test(
    'cleanup started before a metadata write cannot delete the newer write',
    () async {
      await storage.writeMetadata(_book);
      final cleanup = storage.clearCardCache();
      final writing = storage.writeMetadata(_book);
      await cleanup;
      await writing;
      expect(
        (await storage.readMetadataForIds(
          _book.sourceId,
          _book.versionId,
        ))!.versionId,
        _book.versionId,
      );
    },
  );

  test(
    'versions of the same canonical book keep separate download task contexts',
    () async {
      final persistence = MemoryDownloadPersistenceStore();
      final now = DateTime(2026);
      final another = AudioPlaybackBook(
        id: _book.id,
        versionId: 'another-version',
        sourceId: _book.sourceId,
        title: 'Another narration',
        author: _book.author,
        narrator: 'Other narrator',
        sourceName: _book.sourceName,
        chapters: _book.chapters,
      );
      await storage.writeMetadata(another);
      final oldTask = DownloadTask(
        id: 'old-task',
        bookId: another.id,
        bookVersionId: another.versionId,
        sourceId: another.sourceId,
        chapterId: another.chapters.first.id,
        type: DownloadTaskType.chapter,
        status: DownloadTaskStatus.paused,
        createdAt: now,
        updatedAt: now,
      );
      await persistence.saveTask(oldTask);
      final manager = DownloadManager(
        client: _BytesClient([1], total: 1),
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      await manager.loadPersistedTasks();
      expect(manager.taskForBookChapter(_book, _book.chapters.first), isNull);
      expect(activeTasksForBook(manager, _book), isEmpty);
      await manager.cacheBookMetadata(_book);
      expect(manager.bookForTask(oldTask.id)!.versionId, another.versionId);
      await manager.cancelAndDeleteBook(_book);
      expect(manager.tasks.single.id, oldTask.id);
      expect(
        (await persistence.loadTasks()).single.status,
        DownloadTaskStatus.paused,
      );
    },
  );

  test(
    'deleteBook removes orphan chapter tasks absent from refreshed metadata',
    () async {
      final persistence = MemoryDownloadPersistenceStore();
      final now = DateTime(2026);
      await storage.writeMetadata(_book);
      await persistence.saveTask(
        DownloadTask(
          id: 'orphan',
          bookId: _book.id,
          bookVersionId: _book.versionId,
          sourceId: _book.sourceId,
          chapterId: 'removed-at-source',
          type: DownloadTaskType.chapter,
          status: DownloadTaskStatus.paused,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final manager = DownloadManager(
        client: _BytesClient([1], total: 1),
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      await manager.loadPersistedTasks();
      await manager.cancelAndDeleteBook(_book);
      expect(manager.tasks, isEmpty);
      expect(await persistence.loadTasks(), isEmpty);
      expect(await storage.bookDirectoryFor(_book).exists(), isFalse);
    },
  );

  test(
    'resumed transfer speed excludes bytes already stored in the part',
    () async {
      final part = storage.partFileFor(_book, _book.chapters.first);
      await part.parent.create(recursive: true);
      await part.writeAsBytes([1, 2, 3]);
      var now = DateTime(2026);
      final persistence = _RecordingWrites();
      final manager = DownloadManager(
        client: _AdvancingClient(
          () => now = now.add(const Duration(seconds: 1)),
        ),
        storage: storage,
        persistence: persistence,
        clock: () => now,
      );
      addTearDown(manager.dispose);
      await manager.enqueueChapter(_book, _book.chapters.first);
      await manager.waitForIdle();
      final progress = persistence.writes.singleWhere(
        (t) => t.status == DownloadTaskStatus.running && t.downloadedBytes == 6,
      );
      expect(progress.speedBytesPerSecond, 3);
    },
  );

  test(
    'equal version and chapter ids from different sources never overwrite task identity',
    () async {
      final persistence = MemoryDownloadPersistenceStore();
      final other = AudioPlaybackBook(
        id: _book.id,
        versionId: _book.versionId,
        sourceId: 'other',
        title: 'Other source',
        author: _book.author,
        narrator: _book.narrator,
        sourceName: 'Other',
        chapters: _book.chapters,
      );
      final manager = DownloadManager(
        client: _BytesClient([1], total: 1),
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      await manager.enqueueChapter(_book, _book.chapters.first);
      await manager.waitForIdle();
      await manager.enqueueChapter(other, other.chapters.first);
      await manager.waitForIdle();
      expect(manager.tasks, hasLength(2));
      expect(manager.tasks.map((task) => task.id).toSet(), hasLength(2));
      expect(
        activeTasksForBook(manager, _book).single.sourceId,
        _book.sourceId,
      );
      expect(activeTasksForBook(manager, other).single.sourceId, 'other');
      await manager.deleteBook(other);
      expect(manager.tasks.single.sourceId, _book.sourceId);
    },
  );
}

class _BytesClient implements DownloadClient {
  _BytesClient(this.bytes, {required this.total, this.append = false});
  final List<int> bytes;
  final int total;
  final bool append;
  int opens = 0;
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    opens++;
    return DownloadClientResponse(
      bytes: Stream.value(bytes),
      totalBytes: total,
      contentLength: bytes.length,
      supportsResume: true,
      shouldAppend: append,
      fileExtension: 'mp3',
    );
  }
}

class _DeferredLoad extends MemoryDownloadPersistenceStore {
  final gate = Completer<void>();
  int saves = 0;
  @override
  Future<List<DownloadTask>> loadTasks({
    bool recoverInterrupted = false,
  }) async {
    await gate.future;
    return super.loadTasks(recoverInterrupted: recoverInterrupted);
  }

  @override
  Future<void> saveTask(DownloadTask task) async {
    saves++;
    await super.saveTask(task);
  }
}

class _DeferredRunningWrite extends MemoryDownloadPersistenceStore {
  final runningStarted = Completer<void>();
  final releaseRunning = Completer<void>();
  int writers = 0;
  int maxWriters = 0;
  @override
  Future<void> saveTask(DownloadTask task) async {
    writers++;
    if (writers > maxWriters) maxWriters = writers;
    if (task.status == DownloadTaskStatus.running &&
        !runningStarted.isCompleted) {
      runningStarted.complete();
      await releaseRunning.future;
    }
    await super.saveTask(task);
    writers--;
  }
}

class _FailRunningWrite extends MemoryDownloadPersistenceStore {
  bool fail = true;
  @override
  Future<void> saveTask(DownloadTask task) async {
    if (fail && task.status == DownloadTaskStatus.running) {
      throw StateError('Disk error');
    }
    await super.saveTask(task);
  }
}

final _book = AudioPlaybackBook(
  id: 'book',
  versionId: 'version',
  sourceId: 'source',
  title: 'Book',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Source',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter',
      index: 0,
      title: 'Chapter',
      duration: const Duration(minutes: 1),
      mediaSource: AudioMediaSource.url(
        Uri.parse('https://fixture.test/chapter.mp3'),
      ),
    ),
  ],
);

class _PendingHeadersClient implements DownloadClient {
  final opened = Completer<void>();
  final release = Completer<DownloadClientResponse>();
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) {
    opened.complete();
    return release.future;
  }
}

class _RecordingWrites extends MemoryDownloadPersistenceStore {
  final writes = <DownloadTask>[];
  @override
  Future<void> saveTask(DownloadTask task) async {
    writes.add(task);
    await super.saveTask(task);
  }
}

class _AdvancingClient implements DownloadClient {
  _AdvancingClient(this.advance);
  final void Function() advance;
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    advance();
    return DownloadClientResponse(
      bytes: Stream.value([4, 5, 6]),
      totalBytes: 6,
      contentLength: 3,
      supportsResume: true,
      shouldAppend: true,
      fileExtension: 'mp3',
    );
  }
}
