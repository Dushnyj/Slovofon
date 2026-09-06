import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../library/library_drift_persistence.dart';
import 'bookmark_store.dart';

class DriftBookmarkPersistence implements BookmarkPersistence {
  DriftBookmarkPersistence(this._db);
  final AppDatabase _db;

  @override
  Future<List<PlaybackBookmark>> load() async {
    final rows = await (_db.select(
      _db.bookmarks,
    )..orderBy([(b) => OrderingTerm.desc(b.createdAt)])).get();
    if (rows.isEmpty) return [];
    final books = {
      for (final book
          in await DriftLibraryPersistenceStore(_db).loadPlaybackBooks(
            versionIds: rows.map((row) => row.bookVersionId).toSet(),
          ))
        book.versionId: book,
    };
    return [
      for (final row in rows)
        PlaybackBookmark(
          id: row.id,
          bookId: row.bookId,
          bookVersionId: row.bookVersionId,
          chapterId: row.chapterId,
          positionMs: row.positionMs,
          title: row.title,
          note: row.note,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          book: books[row.bookVersionId],
        ),
    ];
  }

  @override
  Future<void> save(PlaybackBookmark bookmark) => _db.transaction(() async {
    final book = bookmark.book;
    if (book != null) {
      await DriftLibraryPersistenceStore(_db).savePlaybackBook(book);
    }
    await _db
        .into(_db.bookmarks)
        .insertOnConflictUpdate(
          BookmarksCompanion(
            id: Value(bookmark.id),
            bookId: Value(bookmark.bookId),
            bookVersionId: Value(bookmark.bookVersionId),
            chapterId: Value(bookmark.chapterId),
            positionMs: Value(bookmark.positionMs),
            title: Value(bookmark.title),
            note: Value(bookmark.note),
            createdAt: Value(bookmark.createdAt),
            updatedAt: Value(bookmark.updatedAt),
          ),
        );
  });

  @override
  Future<void> remove(String id) async {
    await (_db.delete(_db.bookmarks)..where((b) => b.id.equals(id))).go();
  }
}
