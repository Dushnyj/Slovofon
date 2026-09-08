import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';

void main() {
  late Directory directory;
  late FileDownloadStorage storage;
  late _Persistence persistence;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('slovofon-progress-cap-');
    storage = FileDownloadStorage(rootDirectory: directory);
    persistence = _Persistence();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    '8 MiB burst cannot bypass time caps and completion flushes exact bytes',
    () async {
      final bytes = Uint8List(1024 * 1024)..fillRange(0, 1024 * 1024, 17);
      final manager = DownloadManager(
        client: _Client(
          Stream.fromIterable(List.filled(8, bytes)),
          8 * bytes.length,
        ),
        storage: storage,
        persistence: persistence,
        clock: () => DateTime.utc(2026, 9, 8),
      );
      addTearDown(manager.dispose);
      var progressNotifications = 0;
      manager.addListener(() {
        if (manager.tasks.any(
          (task) =>
              task.status == DownloadTaskStatus.running &&
              task.downloadedBytes > 0,
        )) {
          progressNotifications++;
        }
      });
      final task = await manager.enqueueChapter(_book, _chapter);
      await manager.waitForIdle();
      expect(persistence.progressSaves, isEmpty);
      expect(progressNotifications, 0);
      expect(persistence.saves.map((task) => task.status), [
        DownloadTaskStatus.queued,
        DownloadTaskStatus.running,
        DownloadTaskStatus.completed,
      ]);
      final completed = manager.taskById(task.id)!;
      expect(completed.downloadedBytes, 8 * bytes.length);
      expect(completed.progress, 1);
      final file = await storage.completedChapterFile(_book, _chapter);
      expect(await file!.length(), completed.downloadedBytes);
      expect(persistence.updates.last.status, DownloadTaskStatus.completed);
      expect(persistence.updates.last.fileSizeBytes, completed.downloadedBytes);
    },
  );

  test('running UI and persistence have independent time caps', () async {
    var now = DateTime.utc(2026, 9, 8);
    final stream = StreamController<List<int>>();
    final manager = DownloadManager(
      client: _Client(stream.stream, 20 * 1024),
      storage: storage,
      persistence: persistence,
      clock: () => now,
    );
    addTearDown(manager.dispose);
    final notifications = <DateTime>[];
    final task = await manager.enqueueChapter(_book, _chapter);
    manager.addListener(() {
      final value = manager.taskById(task.id)!;
      if (value.status == DownloadTaskStatus.running &&
          value.downloadedBytes > 0) {
        notifications.add(now);
      }
    });
    await _until(() => stream.hasListener);
    for (var i = 1; i <= 20; i++) {
      now = DateTime.utc(2026, 9, 8).add(Duration(milliseconds: i * 100));
      stream.add(Uint8List(1024));
      await _until(
        () => manager.taskById(task.id)!.downloadedBytes == i * 1024,
      );
    }
    await stream.close();
    await manager.waitForIdle();
    expect(persistence.progressSaves.length, 2);
    expect(notifications.length, greaterThan(persistence.progressSaves.length));
    for (var i = 1; i < notifications.length; i++) {
      expect(
        notifications[i].difference(notifications[i - 1]),
        greaterThanOrEqualTo(const Duration(milliseconds: 250)),
      );
    }
    expect(
      persistence.progressSaves[1].updatedAt.difference(
        persistence.progressSaves[0].updatedAt,
      ),
      greaterThanOrEqualTo(const Duration(seconds: 1)),
    );
    expect(persistence.saves.last.status, DownloadTaskStatus.completed);
    expect(persistence.saves.last.downloadedBytes, 20 * 1024);
  });

  for (final operation in ['pause', 'fail', 'cancel', 'dispose', 'shutdown']) {
    test(
      '$operation flushes latest burst state before a timed checkpoint',
      () async {
        final stream = StreamController<List<int>>();
        final manager = DownloadManager(
          client: _Client(stream.stream, 8192),
          storage: storage,
          persistence: persistence,
          clock: () => DateTime.utc(2026, 9, 8),
        );
        addTearDown(manager.dispose);
        final task = await manager.enqueueChapter(_book, _chapter);
        await _until(() => stream.hasListener);
        stream.add(Uint8List(4096));
        await _until(() => manager.taskById(task.id)!.downloadedBytes == 4096);
        expect(persistence.progressSaves, isEmpty);
        switch (operation) {
          case 'pause':
            await manager.pause(task.id);
          case 'fail':
            stream.addError(const DownloadClientException('fixture failure'));
          case 'cancel':
            await manager.cancel(task.id);
          case 'dispose':
            manager.dispose();
          case 'shutdown':
            final first = manager.shutdown();
            expect(manager.shutdown(), same(first));
            await first;
            await expectLater(
              manager.enqueueChapter(_book, _chapter),
              throwsStateError,
            );
        }
        await manager.waitForIdle();
        await stream.close();
        final terminal = persistence.saves.last;
        expect(terminal.status, switch (operation) {
          'fail' => DownloadTaskStatus.failed,
          'cancel' => DownloadTaskStatus.canceled,
          _ => DownloadTaskStatus.paused,
        });
        expect(terminal.downloadedBytes, operation == 'cancel' ? 0 : 4096);
        expect(manager.taskById(task.id)!.status, terminal.status);
        expect(
          await storage.partialBytesFor(_book, _chapter),
          operation == 'cancel' ? 0 : 4096,
        );
        expect(await storage.completedChapterFile(_book, _chapter), isNull);
      },
    );
  }

  test(
    'shutdown drains an already accepted enqueue but never starts its stream',
    () async {
      final gate = Completer<void>();
      persistence.loadGate = gate;
      final manager = DownloadManager(
        client: _Client(Stream.value(Uint8List(8192)), 8192),
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      final enqueue = manager.enqueueChapter(_book, _chapter);
      var done = false;
      final shutdown = manager.shutdown().then((_) => done = true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(done, isFalse);
      gate.complete();
      final task = await enqueue;
      await shutdown;
      expect(persistence.saves.map((task) => task.status), [
        DownloadTaskStatus.queued,
        DownloadTaskStatus.paused,
      ]);
      expect(manager.taskById(task.id)!.downloadedBytes, 0);
      expect(await storage.completedChapterFile(_book, _chapter), isNull);
    },
  );

  test(
    'shutdown waits for paused checkpoint and retries a failed terminal write',
    () async {
      final stream = StreamController<List<int>>();
      final manager = DownloadManager(
        client: _Client(stream.stream, 8192),
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      final task = await manager.enqueueChapter(_book, _chapter);
      await _until(() => stream.hasListener);
      stream.add(Uint8List(4096));
      await _until(() => manager.taskById(task.id)!.downloadedBytes == 4096);
      persistence.failPausedOnce = true;
      await expectLater(manager.shutdown(), throwsStateError);
      expect(manager.taskById(task.id)!.status, DownloadTaskStatus.paused);
      final gate = Completer<void>();
      persistence.pausedGate = gate;
      var done = false;
      final finalShutdown = manager.shutdown().then((_) => done = true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(done, isFalse);
      gate.complete();
      await finalShutdown;
      expect(persistence.saves.last.status, DownloadTaskStatus.paused);
      expect(persistence.saves.last.downloadedBytes, 4096);
      expect(persistence.updates.last.status, DownloadTaskStatus.paused);
      await stream.close();
    },
  );

  for (final operation in ['metadata', 'delete']) {
    test('shutdown drains accepted $operation file mutation', () async {
      final gatedStorage = _GatedStorage(
        rootDirectory: directory,
        operation: operation,
      );
      final manager = DownloadManager(
        client: _Client(const Stream.empty(), 0),
        storage: gatedStorage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      final mutation = operation == 'metadata'
          ? manager.cacheBookMetadata(_book)
          : manager.deleteBook(_book);
      await gatedStorage.started.future;
      var done = false;
      final closing = manager.shutdown().then((_) => done = true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(done, isFalse);
      await expectLater(manager.cacheBookMetadata(_book), throwsStateError);
      await expectLater(manager.deleteBook(_book), throwsStateError);
      gatedStorage.release.complete();
      await mutation;
      await closing;
      expect(gatedStorage.finished, isTrue);
    });
  }

  test(
    'accepted metadata scope survives reentrant shutdown, but cannot escape',
    () async {
      final manager = DownloadManager(
        client: _Client(const Stream.empty(), 0),
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      final coverGate = Completer<void>();
      late Future<void> closing;
      late Future<void> Function(AudioPlaybackBook) escapedWriter;
      var done = false;
      final refresh = manager.runMetadataOperation<void>((writeMetadata) {
        escapedWriter = writeMetadata;
        // A source callback can re-enter close before Future.sync returns. The
        // outer operation must already have been registered in the drain.
        closing = manager.shutdown().then((_) => done = true);
        return () async {
          await coverGate.future;
          await writeMetadata(_book);
        }();
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(done, isFalse);
      coverGate.complete();
      await refresh;
      await closing;
      expect(
        await storage.readMetadataForIds(_book.sourceId, _book.versionId),
        isNotNull,
      );
      await expectLater(escapedWriter(_book), throwsStateError);
    },
  );
}

Future<void> _until(bool Function() predicate) async {
  for (var i = 0; i < 1000; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Fixture did not reach its expected stream state');
}

class _Client implements DownloadClient {
  _Client(this.bytes, this.total);
  final Stream<List<int>> bytes;
  final int total;
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async => DownloadClientResponse(
    bytes: bytes,
    totalBytes: total,
    contentLength: total,
    supportsResume: true,
    shouldAppend: false,
    fileExtension: 'bin',
  );
}

class _GatedStorage extends FileDownloadStorage {
  _GatedStorage({required super.rootDirectory, required this.operation});
  final String operation;
  final started = Completer<void>();
  final release = Completer<void>();
  bool finished = false;

  Future<void> _gate(String current) async {
    if (operation != current) return;
    started.complete();
    await release.future;
  }

  @override
  Future<void> writeMetadata(AudioPlaybackBook book) async {
    await _gate('metadata');
    await super.writeMetadata(book);
    finished = true;
  }

  @override
  Future<void> deleteBook(AudioPlaybackBook book) async {
    await _gate('delete');
    await super.deleteBook(book);
    finished = true;
  }
}

class _Persistence extends MemoryDownloadPersistenceStore {
  final saves = <DownloadTask>[];
  final updates = <DownloadChapterUpdate>[];
  bool failPausedOnce = false;
  Completer<void>? pausedGate;
  Completer<void>? loadGate;
  @override
  Future<List<DownloadTask>> loadTasks({
    bool recoverInterrupted = false,
  }) async {
    await loadGate?.future;
    return super.loadTasks(recoverInterrupted: recoverInterrupted);
  }

  List<DownloadTask> get progressSaves => saves
      .where(
        (task) =>
            task.status == DownloadTaskStatus.running &&
            task.downloadedBytes > 0,
      )
      .toList();
  @override
  Future<void> saveTask(DownloadTask task) async {
    if (task.status == DownloadTaskStatus.paused) {
      if (failPausedOnce) {
        failPausedOnce = false;
        throw StateError('fixture persistence failure');
      }
      await pausedGate?.future;
    }
    await super.saveTask(task);
    saves.add(task);
  }

  @override
  Future<void> updateChapter(DownloadChapterUpdate update) async {
    await super.updateChapter(update);
    updates.add(update);
  }
}

final _chapter = AudioPlaybackChapter(
  id: 'chapter',
  index: 0,
  title: 'Chapter',
  duration: const Duration(minutes: 5),
  mediaSource: AudioMediaSource.url(
    Uri.parse('https://media.example.test/book.bin'),
  ),
);
final _book = AudioPlaybackBook(
  id: 'book',
  versionId: 'version',
  sourceId: 'izib',
  sourceName: 'Izib',
  title: 'Book',
  author: 'Author',
  narrator: 'Narrator',
  chapters: [_chapter],
);
