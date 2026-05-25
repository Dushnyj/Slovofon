import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('schema starts at version 1', () {
    expect(db.schemaVersion, 1);
  });

  test('stores core Stage 1 records', () async {
    final now = DateTime.utc(2026, 5, 25);

    await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            id: 'book-1',
            normalizedTitle: 'master and margarita',
            displayTitle: 'Мастер и Маргарита',
            authorsJson: '["Михаил Булгаков"]',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.bookVersions)
        .insert(
          BookVersionsCompanion.insert(
            id: 'version-1',
            bookId: 'book-1',
            sourceId: 'akniga',
            sourceBookId: '123',
            title: 'Мастер и Маргарита',
            normalizedTitle: 'master and margarita',
            authorsJson: '["Михаил Булгаков"]',
            narratorsJson: '["Чтец"]',
            accessType: 'free',
            playbackAccess: 'streamAndDownload',
            isFull: const Value(true),
            isAccessibleForFree: const Value(true),
            canStream: const Value(true),
            canDownload: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.chapters)
        .insert(
          ChaptersCompanion.insert(
            id: 'chapter-1',
            bookVersionId: 'version-1',
            sourceId: 'akniga',
            index: 0,
            title: 'Глава 1',
            normalizedTitle: 'glava 1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.audioTracks)
        .insert(
          AudioTracksCompanion.insert(
            id: 'track-1',
            chapterId: 'chapter-1',
            sourceId: 'akniga',
            index: 0,
            mediaRef: 'resolver:track-1',
          ),
        );

    await db
        .into(db.playbackSessions)
        .insert(
          PlaybackSessionsCompanion.insert(
            id: 'default',
            activeBookId: const Value('book-1'),
            activeBookVersionId: const Value('version-1'),
            activeSourceId: const Value('akniga'),
            activeChapterId: const Value('chapter-1'),
            positionMs: const Value(1200),
            updatedAt: now,
          ),
        );

    await db
        .into(db.playbackProgressEntries)
        .insert(
          PlaybackProgressEntriesCompanion.insert(
            bookId: 'book-1',
            bookVersionId: 'version-1',
            currentChapterId: const Value('chapter-1'),
            currentPositionMs: const Value(1200),
            totalDurationMs: const Value(5000),
            listenedDurationMs: const Value(1200),
            percent: const Value(24.0),
            lastPlayedAt: now,
          ),
        );

    await db
        .into(db.downloadTasks)
        .insert(
          DownloadTasksCompanion.insert(
            id: 'download-1',
            bookId: 'book-1',
            bookVersionId: 'version-1',
            chapterId: const Value('chapter-1'),
            sourceId: 'akniga',
            type: 'chapter',
            status: 'queued',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            id: 'bookmark-1',
            bookId: 'book-1',
            bookVersionId: 'version-1',
            chapterId: 'chapter-1',
            positionMs: 1200,
            title: 'Важное место',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.appSettingsRows)
        .insert(
          AppSettingsRowsCompanion.insert(
            id: 'default',
            themeMode: const Value('system'),
            languageCode: const Value('ru'),
            accentColor: const Value('default'),
            updatedAt: now,
          ),
        );

    expect(await db.select(db.books).get(), hasLength(1));
    expect(await db.select(db.bookVersions).get(), hasLength(1));
    expect(await db.select(db.chapters).get(), hasLength(1));
    expect(await db.select(db.audioTracks).get(), hasLength(1));
    expect(await db.select(db.playbackSessions).get(), hasLength(1));
    expect(await db.select(db.playbackProgressEntries).get(), hasLength(1));
    expect(await db.select(db.downloadTasks).get(), hasLength(1));
    expect(await db.select(db.bookmarks).get(), hasLength(1));
    expect(await db.select(db.appSettingsRows).get(), hasLength(1));
  });
}
