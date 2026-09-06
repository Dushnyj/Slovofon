import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/database/app_database.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/bookmarks/bookmark_drift_persistence.dart';
import 'package:slovofon/services/bookmarks/bookmark_store.dart';
import 'package:slovofon/services/library/library_drift_persistence.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/library/library_store.dart';

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });
  BookmarkStore store() {
    final store = BookmarkStore(DriftBookmarkPersistence(db));
    addTearDown(store.dispose);
    return store;
  }

  test(
    'bookmark row and real metadata survive restart without download cache',
    () async {
      final first = store();
      final saved = await first.add(
        book: _book,
        chapterId: 'chapter-b',
        positionMs: 22000,
        note: '  Important  ',
      );
      expect(saved.title, 'Second chapter');
      final row = await db.select(db.bookmarks).getSingle();
      expect(row.bookId, _book.id);
      expect(row.bookVersionId, _book.versionId);
      expect(row.chapterId, 'chapter-b');
      expect(row.positionMs, 22000);
      expect(row.note, 'Important');
      final restarted = store();
      await restarted.load();
      final bookmark = restarted.forBook(_book.versionId).single;
      expect(bookmark.id, saved.id);
      expect(bookmark.book!.title, _book.title);
      expect(bookmark.book!.sourceName, 'Real Source');
      expect(bookmark.book!.chapters.map((c) => c.id), [
        'chapter-a',
        'chapter-b',
      ]);
      expect(bookmark.book!.chapters.last.duration, const Duration(minutes: 2));
      expect(bookmark.book!.chapters.first.mediaSource, isNull);
      expect((await db.select(db.favorites).get()), isEmpty);
      expect(db.schemaVersion, 1);
    },
  );

  test(
    'favorite updates preserve bookmarks, chapter metadata, old raw metadata and createdAt',
    () async {
      final library = LibraryStore(DriftLibraryPersistenceStore(db));
      addTearDown(library.dispose);
      final card = libraryCardBook(_book);
      await library.toggleFavorite(card);
      final version = await db.select(db.bookVersions).getSingle();
      await (db.update(
        db.bookVersions,
      )..where((v) => v.id.equals(_book.versionId))).write(
        const BookVersionsCompanion(
          rawSourceDataJson: Value('{"existingKey":"preserved"}'),
        ),
      );
      final bookmarks = store();
      await bookmarks.add(
        book: _book,
        chapterId: 'chapter-a',
        positionMs: 3000,
      );
      await library.refreshFavoriteMetadata(
        card.copyWith(title: 'Updated title'),
      );
      final updated = await db.select(db.bookVersions).getSingle();
      expect(updated.createdAt, version.createdAt);
      expect(updated.rawSourceDataJson, contains('existingKey'));
      expect(updated.rawSourceDataJson, contains('libraryChapters'));
      expect((await db.select(db.favorites).get()), hasLength(1));
      final restarted = store();
      await restarted.load();
      expect(restarted.entries.single.book!.chapters, hasLength(2));
      expect(restarted.entries.single.book!.title, 'Updated title');
    },
  );

  test(
    'remove deletes only selected bookmark and leaves library metadata/favorites',
    () async {
      final bookmarks = store();
      final first = await bookmarks.add(
        book: _book,
        chapterId: 'chapter-a',
        positionMs: 1000,
      );
      final second = await bookmarks.add(
        book: _book,
        chapterId: 'chapter-b',
        positionMs: 2000,
      );
      await bookmarks.remove(first.id);
      expect(bookmarks.entries.single.id, second.id);
      expect((await db.select(db.bookmarks).get()).single.id, second.id);
      expect(await db.select(db.bookVersions).get(), hasLength(1));
      final restarted = store();
      await restarted.load();
      expect(restarted.entries.single.id, second.id);
    },
  );

  test(
    'invalid chapter rejected and positions clamped to chapter range',
    () async {
      final bookmarks = store();
      await expectLater(
        bookmarks.add(book: _book, chapterId: 'missing', positionMs: 2),
        throwsArgumentError,
      );
      expect(bookmarks.entries, isEmpty);
      expect(
        (await bookmarks.add(
          book: _book,
          chapterId: 'chapter-a',
          positionMs: -10,
        )).positionMs,
        0,
      );
      expect(
        (await bookmarks.add(
          book: _book,
          chapterId: 'chapter-b',
          positionMs: 999999,
        )).positionMs,
        120000,
      );
    },
  );

  test(
    'concurrent adds await hydration and serialize persistent writes',
    () async {
      final persistence = _DelayedPersistence();
      final bookmarks = BookmarkStore(persistence);
      addTearDown(bookmarks.dispose);
      final first = bookmarks.add(
        book: _book,
        chapterId: 'chapter-a',
        positionMs: 1000,
      );
      final second = bookmarks.add(
        book: _book,
        chapterId: 'chapter-b',
        positionMs: 2000,
      );
      persistence.gate.complete();
      final values = await Future.wait([first, second]);
      expect(values.map((b) => b.id).toSet(), hasLength(2));
      expect(bookmarks.entries, hasLength(2));
      expect(await persistence.load(), hasLength(2));
      expect(persistence.maxWriters, 1);
    },
  );

  test(
    'write failure is visible, keeps entries and does not poison next write',
    () async {
      final persistence = _FailingPersistence();
      final bookmarks = BookmarkStore(persistence);
      addTearDown(bookmarks.dispose);
      await expectLater(
        bookmarks.add(book: _book, chapterId: 'chapter-a', positionMs: 1),
        throwsStateError,
      );
      expect(bookmarks.entries, isEmpty);
      persistence.failSave = false;
      await bookmarks.add(book: _book, chapterId: 'chapter-a', positionMs: 2);
      expect(bookmarks.entries, hasLength(1));
    },
  );

  test(
    'failed load can be retried without writes replacing old data',
    () async {
      final persistence = _FailingPersistence()
        ..failLoad = true
        ..failSave = false;
      final bookmarks = BookmarkStore(persistence);
      addTearDown(bookmarks.dispose);
      await bookmarks.load();
      expect(bookmarks.error, isNotNull);
      persistence.failLoad = false;
      await bookmarks.load();
      expect(bookmarks.error, isNull);
      await bookmarks.add(book: _book, chapterId: 'chapter-a', positionMs: 4);
      expect(bookmarks.entries, hasLength(1));
    },
  );

  test('orphan existing bookmark remains visible and is removable', () async {
    final now = DateTime(2026);
    await db
        .into(db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: 'old',
            bookId: 'old-book',
            bookVersionId: 'old-version',
            chapterId: 'old-chapter',
            positionMs: 1000,
            title: 'Old bookmark',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final bookmarks = store();
    await bookmarks.load();
    expect(bookmarks.entries.single.title, 'Old bookmark');
    expect(bookmarks.entries.single.book, isNull);
    await bookmarks.remove('old');
    expect(await db.select(db.bookmarks).get(), isEmpty);
  });
  test(
    'malformed optional book metadata does not hide persisted bookmarks',
    () async {
      final bookmarks = store();
      final mark = await bookmarks.add(
        book: _book,
        chapterId: 'chapter-a',
        positionMs: 3000,
      );
      await (db.update(
        db.bookVersions,
      )..where((row) => row.id.equals(_book.versionId))).write(
        const BookVersionsCompanion(
          rawSourceDataJson: Value('{broken'),
          authorsJson: Value('[broken'),
        ),
      );
      final restarted = store();
      await restarted.load();
      expect(restarted.error, isNull);
      expect(restarted.entries.single.id, mark.id);
      expect(restarted.entries.single.book!.title, _book.title);
      // A fresh source snapshot repairs data but retains the damaged original.
      await DriftLibraryPersistenceStore(db).savePlaybackBook(_book);
      final row = await db.select(db.bookVersions).getSingle();
      expect(row.rawSourceDataJson, contains('_legacyUnparsedSourceData'));
      expect(row.rawSourceDataJson, contains('{broken'));
      expect((await db.select(db.bookmarks).get()).single.id, mark.id);
    },
  );
}

class _DelayedPersistence extends MemoryBookmarkPersistence {
  final gate = Completer<void>();
  int writers = 0;
  int maxWriters = 0;
  @override
  Future<List<PlaybackBookmark>> load() async {
    await gate.future;
    return super.load();
  }

  @override
  Future<void> save(PlaybackBookmark bookmark) async {
    writers++;
    if (writers > maxWriters) maxWriters = writers;
    await Future<void>.delayed(Duration.zero);
    await super.save(bookmark);
    writers--;
  }
}

class _FailingPersistence extends MemoryBookmarkPersistence {
  bool failSave = true;
  bool failLoad = false;
  @override
  Future<List<PlaybackBookmark>> load() {
    if (failLoad) throw StateError('load');
    return super.load();
  }

  @override
  Future<void> save(PlaybackBookmark bookmark) {
    if (failSave) throw StateError('save');
    return super.save(bookmark);
  }
}

const _book = AudioPlaybackBook(
  id: 'source-book-1',
  versionId: 'source-1',
  sourceId: 'source',
  sourceBookId: '1',
  title: 'Real book',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Real Source',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-a',
      index: 0,
      title: 'First chapter',
      duration: Duration(minutes: 1),
    ),
    AudioPlaybackChapter(
      id: 'chapter-b',
      index: 1,
      title: 'Second chapter',
      duration: Duration(minutes: 2),
    ),
  ],
);
