import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_storage.dart';

void main() {
  late Directory root;
  late FileDownloadStorage storage;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('slovofon-identity-test-');
    storage = FileDownloadStorage(rootDirectory: root);
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('punctuation and case variants receive distinct stable paths', () async {
    final books = [
      book('book/a'),
      book('book?a'),
      book('Book_A'),
      book('book_a'),
    ];
    final paths = books
        .map((b) => storage.bookDirectoryFor(b).path.toLowerCase())
        .toSet();
    expect(paths, hasLength(4));
    for (var index = 0; index < books.length; index++) {
      final b = books[index];
      await storage.writeMetadata(b);
      final audio = storage.chapterFileFor(
        b,
        b.chapters.first,
        extension: 'mp3',
      );
      await audio.parent.create(recursive: true);
      await audio.writeAsBytes([index + 1]);
    }
    final fresh = FileDownloadStorage(rootDirectory: root);
    for (var index = 0; index < books.length; index++) {
      final b = books[index];
      expect(
        (await fresh.readMetadataForIds(b.sourceId, b.versionId))!.versionId,
        b.versionId,
      );
      final offline = await fresh.offlinePlaybackBook(b);
      expect(
        await File(offline.chapters.first.mediaSource!.filePath).readAsBytes(),
        [index + 1],
      );
    }
    await fresh.deleteBook(books.first);
    expect(await fresh.readAllMetadata(), hasLength(3));
    expect(
      await (await fresh.completedChapterFile(
        books.last,
        books.last.chapters.first,
      ))!.readAsBytes(),
      [4],
    );
  });

  test(
    'legacy offline paths remain unchanged across read, resume, and delete',
    () async {
      final b = book('old-book');
      final legacy = await legacyBook(root, b, bytes: [1, 2, 3]);
      final loaded = await storage.readMetadataForIds(b.sourceId, b.versionId);
      expect(loaded!.versionId, b.versionId);
      expect(storage.bookDirectoryFor(b).path, legacy.path);
      final offline = await storage.offlinePlaybackBook(b);
      expect(
        offline.chapters.first.mediaSource!.filePath,
        contains('source_old-book'),
      );
      expect(
        await File(offline.chapters.first.mediaSource!.filePath).readAsBytes(),
        [1, 2, 3],
      );
      await storage.writeMetadata(b);
      expect(storage.metadataFileFor(b).parent.path, legacy.path);
      final sink = await storage.openPartSink(
        b,
        b.chapters.first,
        append: false,
      );
      sink.add([4, 5, 6]);
      await sink.close();
      await storage.finalizeChapter(b, b.chapters.first, extension: 'mp3');
      expect(await File('${legacy.path}/chapters/000.mp3').readAsBytes(), [
        4,
        5,
        6,
      ]);
      await storage.deleteBook(b);
      expect(await legacy.exists(), isFalse);
    },
  );

  test(
    'readAllMetadata registers legacy layout before synchronous path access',
    () async {
      final b = book('old-book');
      final legacy = await legacyBook(root, b, bytes: [1]);
      expect(await storage.readAllMetadata(), hasLength(1));
      expect(storage.coverFileFor(b).parent.path, legacy.path);
    },
  );

  test(
    'colliding new book never merges or deletes another legacy book',
    () async {
      final a = book('book/a');
      final b = book('book?a');
      final legacy = await legacyBook(root, a, bytes: [7]);
      expect(await storage.readMetadataForIds(b.sourceId, b.versionId), isNull);
      await storage.writeMetadata(b);
      expect(storage.bookDirectoryFor(b).path, isNot(legacy.path));
      expect(
        (await storage.readMetadataForIds(a.sourceId, a.versionId))!.versionId,
        a.versionId,
      );
      await storage.deleteBook(b);
      expect(await File('${legacy.path}/chapters/000.mp3').readAsBytes(), [7]);
      expect((await storage.readAllMetadata()).single.versionId, a.versionId);
    },
  );

  test(
    'legacy directory without identity cannot be deleted by a guessed book',
    () async {
      final b = book('book/a');
      final legacy = Directory('${root.path}/source_book_a');
      final audio = File('${legacy.path}/chapters/000.mp3');
      await audio.parent.create(recursive: true);
      await audio.writeAsBytes([8, 9]);
      await expectLater(
        storage.deleteBook(b),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        storage.deleteChapter(b, b.chapters.first),
        throwsA(isA<FileSystemException>()),
      );
      expect(await audio.readAsBytes(), [8, 9]);
      // Saving a new book uses a new identity-safe directory; the orphan stays.
      await storage.writeMetadata(b);
      expect(storage.bookDirectoryFor(b).path, isNot(legacy.path));
      expect(await audio.readAsBytes(), [8, 9]);
    },
  );

  test('legacy ownership is rechecked before destructive operation', () async {
    final a = book('book/a');
    final b = book('book?a');
    final legacy = await legacyBook(root, a, bytes: [2]);
    await storage.readMetadataForIds(a.sourceId, a.versionId);
    await File(
      '${legacy.path}/metadata.json',
    ).writeAsString(jsonEncode(metadata(b)));
    await storage.deleteBook(a);
    expect(await File('${legacy.path}/chapters/000.mp3').readAsBytes(), [2]);
  });
}

AudioPlaybackBook book(String id) => AudioPlaybackBook(
  id: 'book-$id',
  versionId: id,
  sourceId: 'source',
  title: 'Book $id',
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
        Uri.parse('https://fixture.test/audio.mp3'),
      ),
    ),
  ],
);
Map<String, Object?> metadata(AudioPlaybackBook b) => {
  'bookId': b.id,
  'bookVersionId': b.versionId,
  'sourceId': b.sourceId,
  'title': b.title,
  'authors': [b.author],
  'narrators': [b.narrator],
  'sourceName': b.sourceName,
  'chapters': [
    for (final c in b.chapters)
      {
        'id': c.id,
        'index': c.index,
        'title': c.title,
        'durationMs': c.duration.inMilliseconds,
        'mediaSource': {'type': 'url', 'uri': c.mediaSource!.uri.toString()},
      },
  ],
};
Future<Directory> legacyBook(
  Directory root,
  AudioPlaybackBook b, {
  required List<int> bytes,
}) async {
  final name = '${b.sourceId}_${b.versionId}'
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final directory = Directory(p.join(root.path, name));
  final audio = File('${directory.path}/chapters/000.mp3');
  await audio.parent.create(recursive: true);
  await audio.writeAsBytes(bytes);
  await File(
    '${directory.path}/metadata.json',
  ).writeAsString(jsonEncode(metadata(b)));
  return directory;
}
