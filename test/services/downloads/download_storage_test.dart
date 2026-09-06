import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_storage.dart';

void main() {
  late Directory root;
  late FileDownloadStorage storage;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('slovofon-storage-test-');
    storage = FileDownloadStorage(rootDirectory: root);
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'offline overlay scans a large book once and yields the event loop',
    () async {
      final counted = _CountingStorage(rootDirectory: root);
      final book = _book(chapterCount: 1000);
      await counted.chaptersDirectoryFor(book).create(recursive: true);
      for (final chapter in book.chapters) {
        await counted
            .chapterFileFor(book, chapter, extension: 'mp3')
            .writeAsBytes([1]);
      }
      await counted.writeMetadata(book);
      var yielded = false;
      final timer = Timer(Duration.zero, () => yielded = true);
      final offline = await counted.offlinePlaybackBook(book);
      timer.cancel();
      expect(counted.directoryScans, 1);
      expect(
        yielded,
        isTrue,
        reason: 'File discovery must not block the UI isolate.',
      );
      expect(offline.chapters.every((chapter) => chapter.isDownloaded), isTrue);
    },
  );

  test(
    'deleting a played chapter preserves its original remote source',
    () async {
      final book = _book();
      await storage.writeMetadata(book);
      final file = storage.chapterFileFor(
        book,
        book.chapters.first,
        extension: 'mp3',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes([1, 2, 3]);
      final offline = await storage.offlinePlaybackBook(book);
      expect(
        offline.chapters.first.originalMediaSource?.type,
        AudioMediaSourceType.url,
      );
      await storage.saveBook(offline);
      await storage.deleteChapter(offline, offline.chapters.first);

      // The active player still holds an offline overlay, not a freshly loaded URL.
      final refreshed = await storage.offlinePlaybackBook(offline);
      expect(await file.exists(), isFalse);
      expect(refreshed.chapters.first.isDownloaded, isFalse);
      expect(
        refreshed.chapters.first.mediaSource?.type,
        AudioMediaSourceType.url,
      );
      expect(
        refreshed.chapters.first.mediaSource?.uri,
        book.chapters.first.mediaSource?.uri,
      );
      final persisted = await storage.loadBook(
        sourceId: book.sourceId,
        versionId: book.versionId,
      );
      expect(
        persisted!.chapters.first.mediaSource?.type,
        AudioMediaSourceType.url,
      );
    },
  );

  test('fresh remote metadata repairs legacy local-only metadata', () async {
    final book = _book();
    final legacy = book.copyWith(
      chapters: [
        book.chapters.first.copyWith(
          mediaSource: AudioMediaSource.file('${root.path}/missing.mp3'),
        ),
      ],
    );
    await storage.writeMetadata(legacy);
    final unavailable = await storage.offlinePlaybackBook(legacy);
    expect(unavailable.chapters.first.mediaSource, isNull);
    await storage.writeMetadata(book);
    final refreshed = await storage.offlinePlaybackBook(book);
    expect(
      refreshed.chapters.first.mediaSource?.type,
      AudioMediaSourceType.url,
    );
  });

  test(
    'concurrent metadata readers never observe an incomplete JSON write',
    () async {
      final book = _book(chapterCount: 100);
      await storage.writeMetadata(book);
      final anotherStorage = FileDownloadStorage(rootDirectory: root);
      await Future.wait([
        for (var index = 0; index < 20; index++)
          () async {
            await (index.isEven ? storage : anotherStorage).writeMetadata(book);
            final read = await anotherStorage.readMetadataForIds(
              book.sourceId,
              book.versionId,
            );
            expect(read?.chapters, hasLength(100));
          }(),
      ]);
      expect(
        jsonDecode(await storage.metadataFileFor(book).readAsString()),
        isA<Map>(),
      );
    },
  );

  test('unreadable metadata is skipped without deleting book files', () async {
    final book = _book();
    final metadata = storage.metadataFileFor(book);
    await metadata.parent.create(recursive: true);
    await metadata.writeAsString('{');
    final audio = storage.chapterFileFor(
      book,
      book.chapters.first,
      extension: 'mp3',
    );
    await audio.parent.create(recursive: true);
    await audio.writeAsBytes([1, 2, 3]);
    expect(
      await storage.readMetadataForIds(book.sourceId, book.versionId),
      isNull,
    );
    expect(await storage.readAllMetadata(), isEmpty);
    expect(await metadata.readAsString(), '{');
    expect(await audio.readAsBytes(), [1, 2, 3]);
    await storage.writeMetadata(book);
    final retained = await metadata.parent
        .list()
        .where((file) => file.path.contains('.corrupt.'))
        .toList();
    expect(retained, hasLength(1));
    expect(await File(retained.single.path).readAsString(), '{');
  });

  test(
    'corrupt metadata recovers the last good book and preserves trial flag',
    () async {
      final book = _book(isFragment: true);
      await storage.writeMetadata(book);
      await storage.writeMetadata(book);
      await storage.metadataFileFor(book).writeAsString('');
      final recovered = await storage.readMetadataForIds(
        book.sourceId,
        book.versionId,
      );
      expect(recovered?.title, book.title);
      expect(recovered?.isFragment, isTrue);
      final offline = await storage.offlinePlaybackBook(book);
      expect(offline.isFragment, isTrue);
    },
  );
}

AudioPlaybackBook _book({int chapterCount = 1, bool isFragment = false}) {
  return AudioPlaybackBook(
    id: 'book',
    versionId: 'version',
    sourceId: 'source',
    title: 'Book',
    author: 'Author',
    narrator: 'Narrator',
    sourceName: 'Source',
    isFragment: isFragment,
    chapters: [
      for (var index = 0; index < chapterCount; index++)
        AudioPlaybackChapter(
          id: 'chapter-$index',
          index: index,
          title: 'Chapter $index',
          duration: const Duration(minutes: 10),
          mediaSource: AudioMediaSource.url(
            Uri.parse('https://example.test/$index.mp3'),
          ),
        ),
    ],
  );
}

class _CountingStorage extends FileDownloadStorage {
  _CountingStorage({required super.rootDirectory});
  var directoryScans = 0;
  @override
  Future<Map<int, File>> completedChapterFiles(AudioPlaybackBook book) {
    directoryScans++;
    return super.completedChapterFiles(book);
  }
}
