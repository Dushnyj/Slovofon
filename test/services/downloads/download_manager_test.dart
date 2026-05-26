import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';

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
