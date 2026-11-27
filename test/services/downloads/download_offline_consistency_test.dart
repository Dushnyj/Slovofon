import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/sources/source_parser_helpers.dart';

void main() {
  late Directory root;
  late FileDownloadStorage storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'slovofon-offline-consistency-',
    );
    storage = FileDownloadStorage(rootDirectory: root);
  });

  tearDown(() async => root.delete(recursive: true));

  test('fresh order cannot reassign old numbered audio or old parts', () async {
    final a = _chapter('a', 0, 'Alpha');
    final b = _chapter('b', 1, 'Beta');
    final old = _book([a, b]);
    final directory = await _writeLegacy(old, storage);
    final oldA = File(p.join(directory.path, '000.mp3'));
    final oldB = File(p.join(directory.path, '001.mp3'));
    final oldPart = File(p.join(directory.path, '001.part'));
    await oldA.writeAsBytes([1]);
    await oldB.writeAsBytes([2]);
    await oldPart.writeAsBytes([3]);
    final refreshed = _book([
      _chapter('c', 0, 'New'),
      b.copyWith(index: 1),
      a.copyWith(index: 2),
    ]);
    await storage.writeMetadata(refreshed);
    final reopened = FileDownloadStorage(rootDirectory: root);
    final completed = await reopened.completedChapterFiles(refreshed);
    expect(completed.keys, unorderedEquals([1, 2]));
    expect(completed[1]!.path, oldB.path);
    expect(completed[2]!.path, oldA.path);
    expect(await reopened.partialBytesFor(refreshed, b), 0);
    expect(await oldPart.readAsBytes(), [3]);
  });

  test(
    'preview matches a legacy ordinal only by prior media evidence',
    () async {
      final first = _chapter('izib-book-chapter-1', 0, 'Часть');
      final next = _chapter('izib-book-chapter-2', 1, 'Часть');
      final old = _book([first, next], sourceId: 'izib');
      final directory = await _writeLegacy(old, storage);
      final original = File(p.join(directory.path, '000.mp3'));
      await original.writeAsBytes([1]);
      final refreshed = _book([
        AudioPlaybackChapter(
          id: first.id,
          index: 0,
          title: first.title,
          duration: Duration.zero,
          storageIdentity: 'id:replacement',
        ),
        AudioPlaybackChapter(
          id: next.id,
          index: 1,
          title: next.title,
          duration: Duration.zero,
          storageIdentity: 'id:exact',
          storageMediaReference: SourceParserHelpers.mediaReferenceIdentity(
            first.mediaSource!.uri.toString(),
          ),
        ),
      ], sourceId: 'izib');
      await storage.writeMetadata(refreshed);
      final completed = await storage.completedChapterFiles(refreshed);
      expect(completed.keys, [1]);
      expect(completed[1]!.path, original.path);

      final ambiguous = refreshed.copyWith(
        chapters: [
          refreshed.chapters[1].copyWith(index: 0),
          refreshed.chapters[1].copyWith(index: 1),
        ],
      );
      expect(await storage.completedChapterFiles(ambiguous), isEmpty);
      expect(await original.readAsBytes(), [1]);
    },
  );

  test('stable modern bytes follow the chapter after order changes', () async {
    final chapter = _chapter('provider-a', 0, 'Alpha', identity: 'id:a');
    final original = _book([chapter]);
    await storage.writeMetadata(original);
    final sink = await storage.openPartSink(original, chapter, append: false);
    sink.add([9, 8]);
    await sink.close();
    final file = await storage.finalizeChapter(
      original,
      chapter,
      extension: 'mp3',
    );
    final moved = chapter.copyWith(
      id: 'new-display-id',
      index: 1,
      title: 'New title',
    );
    final refreshed = _book([
      _chapter('new', 0, 'New', identity: 'id:new'),
      moved,
    ]);
    await storage.writeMetadata(refreshed);
    final files = await storage.completedChapterFiles(refreshed);
    expect(files.keys, [1]);
    expect(files[1]!.path, file.path);
    expect(await files[1]!.readAsBytes(), [9, 8]);
  });

  test(
    'startup repairs both interrupted completion and missing final file',
    () async {
      final a = _chapter('has-final', 0, 'First');
      final b = _chapter('missing-final', 1, 'Second');
      final book = _book([a, b]);
      await storage.writeMetadata(book);
      final ready = storage.chapterFileFor(book, a, extension: 'mp3');
      await ready.parent.create(recursive: true);
      await ready.writeAsBytes([1, 2, 3]);
      // A part of the second chapter cannot stand in for the missing final.
      await storage.partFileFor(book, b).writeAsBytes([4, 5]);
      final persistence = MemoryDownloadPersistenceStore();
      await persistence.saveTask(_task(book, a, DownloadTaskStatus.running));
      await persistence.saveTask(_task(book, b, DownloadTaskStatus.completed));
      final manager = DownloadManager(
        client: _BytesClient(),
        storage: storage,
        persistence: persistence,
      );
      addTearDown(manager.dispose);
      await manager.loadPersistedTasks();
      expect(
        manager.taskForBookChapter(book, a)!.status,
        DownloadTaskStatus.completed,
      );
      expect(manager.taskForBookChapter(book, a)!.downloadedBytes, 3);
      expect(
        manager.taskForBookChapter(book, b)!.errorCode,
        'local_file_missing',
      );
      expect(await storage.partFileFor(book, b).readAsBytes(), [4, 5]);
      expect(
        (await persistence.loadTasks()).map((task) => task.status),
        unorderedEquals([
          DownloadTaskStatus.completed,
          DownloadTaskStatus.failed,
        ]),
      );
    },
  );

  test('Wi-Fi gate holds lazy work and resumes it when allowed', () async {
    final chapter = const AudioPlaybackChapter(
      id: 'one',
      index: 0,
      title: 'Chapter',
      duration: Duration.zero,
      storageIdentity: 'id:one',
    );
    final book = _book([chapter]);
    var resolutions = 0;
    final client = _BytesClient();
    final manager = DownloadManager(
      client: client,
      storage: storage,
      persistence: MemoryDownloadPersistenceStore(),
      initialNetworkGate: DownloadNetworkGate.wifiRequired,
      resolveChapterForDownload:
          (book, chapter, {required forceRefresh}) async {
            expect(forceRefresh, isFalse);
            resolutions++;
            return chapter.copyWith(
              mediaSource: AudioMediaSource.url(
                Uri.parse('https://fixture.test/one.mp3'),
              ),
            );
          },
    );
    addTearDown(manager.dispose);
    final queued = await manager.enqueueChapter(book, chapter);
    await manager.waitForIdle();
    expect(manager.taskById(queued.id)!.status, DownloadTaskStatus.queued);
    expect(resolutions, 0);
    expect(client.opens, 0);
    manager.setNetworkGate(DownloadNetworkGate.allowed);
    await manager.waitForIdle();
    expect(resolutions, 1);
    expect(client.opens, 1);
    expect(manager.taskById(queued.id)!.status, DownloadTaskStatus.completed);
  });

  for (final failure in <Object?>[
    null,
    const SocketException('Route is still unavailable.'),
    const DownloadClientException('Invalid media byte range.'),
  ]) {
    test(
      'Wi-Fi handoff preserves part and retries socket failure only once: $failure',
      () async {
        final chapter = _chapter('one', 0, 'Chapter');
        final book = _book([chapter]);
        final client = _HandoffClient(failure);
        addTearDown(client.firstAttempt.close);
        var now = DateTime.utc(2026, 1, 1);
        final manager = DownloadManager(
          client: client,
          storage: storage,
          persistence: MemoryDownloadPersistenceStore(),
          clock: () => now = now.add(const Duration(seconds: 1)),
        );
        addTearDown(manager.dispose);
        final partial = Completer<void>();
        manager.addListener(() {
          if (!partial.isCompleted &&
              manager.taskForBookChapter(book, chapter)?.downloadedBytes == 2) {
            partial.complete();
          }
        });

        final started = await manager.enqueueChapter(book, chapter);
        await partial.future.timeout(const Duration(seconds: 5));
        manager.setNetworkGate(DownloadNetworkGate.wifiRequired);
        await manager.waitForIdle();
        expect(manager.taskById(started.id)?.status, DownloadTaskStatus.queued);
        expect(await storage.partFileFor(book, chapter).readAsBytes(), [1, 2]);
        expect(client.offsets, [0]);

        manager.setNetworkGate(DownloadNetworkGate.allowed);
        await manager.waitForIdle();
        expect(
          client.offsets,
          failure is DownloadClientException ? [0, 2] : [0, 2, 2],
        );
        if (failure == null) {
          expect(
            manager.taskById(started.id)?.status,
            DownloadTaskStatus.completed,
          );
          final file = await storage.completedChapterFile(book, chapter);
          expect(await file!.readAsBytes(), [1, 2, 3, 4]);
        } else {
          expect(
            manager.taskById(started.id)?.status,
            DownloadTaskStatus.failed,
          );
          expect(await storage.partFileFor(book, chapter).readAsBytes(), [
            1,
            2,
          ]);
        }
      },
    );
  }

  for (final body in [
    '<!doctype html><title>Temporary error</title>',
    '#EXTM3U\n',
  ]) {
    test(
      'unrecognized generic response is not published: ${body[0]}',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          request.response.headers.contentType = ContentType.binary;
          request.response.write(body);
          await request.response.close();
        });
        final chapter = AudioPlaybackChapter(
          id: 'one',
          index: 0,
          title: 'Chapter',
          duration: Duration.zero,
          mediaSource: AudioMediaSource.url(
            Uri.parse('http://127.0.0.1:${server.port}/one.mp3'),
          ),
        );
        final book = _book([chapter]);
        final manager = DownloadManager(
          client: DefaultDownloadClient(),
          storage: storage,
          persistence: MemoryDownloadPersistenceStore(),
        );
        addTearDown(manager.dispose);
        final task = await manager.enqueueChapter(book, chapter);
        await manager.waitForIdle();
        expect(manager.taskById(task.id)!.errorCode, 'invalid_media_response');
        expect(await storage.completedChapterFile(book, chapter), isNull);
        expect(await storage.partialBytesFor(book, chapter), 0);
      },
    );
  }
}

AudioPlaybackBook _book(
  List<AudioPlaybackChapter> chapters, {
  String sourceId = 'test',
}) => AudioPlaybackBook(
  id: 'book',
  versionId: 'version',
  sourceId: sourceId,
  sourceBookId: 'book',
  title: 'Book',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Fixture',
  chapters: chapters,
);

AudioPlaybackChapter _chapter(
  String id,
  int index,
  String title, {
  String? identity,
}) => AudioPlaybackChapter(
  id: id,
  index: index,
  title: title,
  duration: Duration.zero,
  storageIdentity: identity,
  mediaSource: AudioMediaSource.url(Uri.parse('https://fixture.test/$id.mp3')),
);

Future<Directory> _writeLegacy(
  AudioPlaybackBook book,
  FileDownloadStorage storage,
) async {
  // The book-directory hash predates chapter identity; an indexed chapter
  // layout therefore exists in both historical and hashed book directories.
  final chapters = storage.chaptersDirectoryFor(book);
  await chapters.create(recursive: true);
  await storage
      .metadataFileFor(book)
      .writeAsString(
        jsonEncode({
          'sourceId': book.sourceId,
          'bookVersionId': book.versionId,
          'bookId': book.id,
          'title': book.title,
          'chapters': [
            for (final chapter in book.chapters)
              {
                'id': chapter.id,
                'index': chapter.index,
                'title': chapter.title,
                'mediaSource': {
                  'type': 'url',
                  'uri': chapter.mediaSource!.uri.toString(),
                },
              },
          ],
        }),
      );
  return chapters;
}

DownloadTask _task(
  AudioPlaybackBook book,
  AudioPlaybackChapter chapter,
  DownloadTaskStatus status,
) => DownloadTask(
  id: 'chapter:${book.sourceId}:${book.versionId}:${chapter.id}',
  bookId: book.id,
  bookVersionId: book.versionId,
  chapterId: chapter.id,
  sourceId: book.sourceId,
  type: DownloadTaskType.chapter,
  status: status,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

class _BytesClient implements DownloadClient {
  int opens = 0;

  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    opens++;
    return DownloadClientResponse(
      bytes: Stream.value([1, 2]),
      totalBytes: 2,
      contentLength: 2,
      supportsResume: false,
      shouldAppend: false,
      fileExtension: 'mp3',
    );
  }
}

class _HandoffClient implements DownloadClient {
  _HandoffClient(this.failure);

  final Object? failure;
  final offsets = <int>[];
  final firstAttempt = StreamController<List<int>>();

  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    offsets.add(startByte);
    if (offsets.length == 1) {
      firstAttempt.add([1, 2]);
      return DownloadClientResponse(
        bytes: firstAttempt.stream,
        totalBytes: 4,
        contentLength: 4,
        supportsResume: true,
        shouldAppend: false,
        fileExtension: 'mp3',
      );
    }
    if (offsets.length == 2) {
      throw failure ?? const SocketException('New route not ready yet.');
    }
    if (failure != null) throw failure!;
    return DownloadClientResponse(
      bytes: Stream.value([3, 4]),
      totalBytes: 4,
      contentLength: 2,
      supportsResume: true,
      shouldAppend: true,
      fileExtension: 'mp3',
    );
  }
}
