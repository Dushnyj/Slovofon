import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/database/app_database.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_store.dart';
import 'package:slovofon/services/library/library_drift_persistence.dart';
import 'package:slovofon/services/sources/source_book_cache.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/source_models.dart';

void main() {
  test(
    'refresh caches source details for home, library, and downloads',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'slovofon-source-book-cache-',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final storage = FileDownloadStorage(rootDirectory: tempDir);
      final downloadManager = DownloadManager(
        client: _NoopDownloadClient(),
        storage: storage,
        persistence: MemoryDownloadPersistenceStore(),
      );
      addTearDown(downloadManager.dispose);
      final libraryStore = LibraryStore(
        MemoryLibraryPersistenceStore(),
        clock: () => DateTime.utc(2026, 5, 30, 10),
      );
      addTearDown(libraryStore.dispose);
      await libraryStore.toggleFavorite(_oldAudioBook);
      downloadManager.attachBookContext(_oldPlaybackBook);
      final coverRequests = <Uri>[];

      await SourceBookCache(
        downloadStorage: storage,
        downloadManager: downloadManager,
        libraryStore: libraryStore,
        coverBytesLoader: (uri) async {
          coverRequests.add(uri);
          return const [1, 2, 3, 4];
        },
      ).refresh(_snapshot);

      final cachedPlaybackBook = await storage.readMetadataForIds(
        _playbackBook.sourceId,
        _playbackBook.versionId,
      );
      expect(cachedPlaybackBook?.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(coverRequests, [Uri.parse('https://izib.uk/covers/zone.jpg')]);
      expect(cachedPlaybackBook?.coverUrl, startsWith('file:'));
      expect(
        await File.fromUri(
          Uri.parse(cachedPlaybackBook!.coverUrl!),
        ).readAsBytes(),
        const [1, 2, 3, 4],
      );
      expect(cachedPlaybackBook.publishedYear, 2019);

      expect(libraryStore.favorites.single.book.title, _audioBook.title);
      expect(libraryStore.favorites.single.book.coverUrl, startsWith('file:'));
      expect(
        libraryStore.favorites.single.updatedAt,
        DateTime.utc(2026, 5, 30, 10),
      );

      final taskId =
          'chapter:${_playbackBook.sourceId}:${_playbackBook.versionId}:chapter-1';
      expect(downloadManager.bookForTask(taskId)?.title, _playbackBook.title);
      expect(
        downloadManager.bookForTask(taskId)?.coverUrl,
        startsWith('file:'),
      );
    },
  );

  test(
    'shutdown drains a refresh accepted before its cover and final Drift write',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'slovofon-source-cache-shutdown-',
      );
      addTearDown(() async {
        final resolved = await tempDir.resolveSymbolicLinks();
        final tempRoot = await Directory.systemTemp.resolveSymbolicLinks();
        if (Directory(resolved).parent.path != tempRoot ||
            !Directory(resolved).uri.pathSegments
                .where((part) => part.isNotEmpty)
                .last
                .startsWith('slovofon-source-cache-shutdown-')) {
          throw StateError('Unexpected temporary test directory: $resolved');
        }
        await Directory(resolved).delete(recursive: true);
      });
      final db = AppDatabase(NativeDatabase.memory());
      var databaseClosed = false;
      addTearDown(() async {
        if (!databaseClosed) await db.close();
      });
      final persistence = _GatedDriftLibraryStore(db);
      final libraryStore = LibraryStore(persistence);
      addTearDown(libraryStore.dispose);
      await libraryStore.toggleFavorite(_oldAudioBook);
      persistence.holdNextSave = true;
      final storage = _CountingDownloadStorage(rootDirectory: tempDir);
      final manager = DownloadManager(
        client: _NoopDownloadClient(),
        storage: storage,
        persistence: MemoryDownloadPersistenceStore(),
      );
      addTearDown(manager.dispose);
      final coverStarted = Completer<void>();
      final cover = Completer<List<int>?>();
      addTearDown(() async {
        if (!cover.isCompleted) cover.complete(null);
        if (!persistence.releaseSave.isCompleted) {
          persistence.releaseSave.complete();
        }
        await manager.shutdown();
      });
      var coverRequests = 0;
      final cache = SourceBookCache(
        downloadStorage: storage,
        downloadManager: manager,
        libraryStore: libraryStore,
        coverBytesLoader: (_) {
          coverRequests++;
          if (!coverStarted.isCompleted) coverStarted.complete();
          return cover.future;
        },
      );

      final refresh = cache.refresh(_snapshot);
      await coverStarted.future;
      var shutdownComplete = false;
      final shutdown = manager.shutdown().then((_) => shutdownComplete = true);
      await Future<void>.value();
      expect(shutdownComplete, isFalse);
      expect(storage.metadataWrites, 0);
      expect(storage.coverWrites, 0);

      // A new refresh must be rejected at admission, not after starting its
      // network/cover/file work and not by encountering an already closed DB.
      await expectLater(cache.refresh(_snapshot), throwsStateError);
      expect(coverRequests, 1);
      cover.complete(const [1, 2, 3, 4]);
      await persistence.saveStarted.future;
      expect(shutdownComplete, isFalse);
      expect(storage.metadataWrites, 1);
      expect(storage.coverWrites, 1);
      expect(
        (await persistence.loadFavorites()).single.book.title,
        _oldAudioBook.title,
      );

      persistence.releaseSave.complete();
      final refreshed = await refresh;
      await shutdown;
      await libraryStore.flushPendingWrites();
      expect(shutdownComplete, isTrue);
      expect(persistence.completedRefreshWrites, 1);
      expect(
        (await persistence.loadFavorites()).single.book.title,
        _audioBook.title,
      );
      expect(refreshed.audioBook.coverUrl, startsWith('file:'));
      expect(
        (await storage.readMetadataForIds(
          _playbackBook.sourceId,
          _playbackBook.versionId,
        ))?.coverUrl,
        refreshed.audioBook.coverUrl,
      );
      expect(
        manager.bookForTask('chapter:izib:izib-2033:chapter-1')?.coverUrl,
        refreshed.audioBook.coverUrl,
      );

      // Mirror bootstrap ordering: accepted cache work is already committed
      // before DB close, and no later refresh can start persistence afterwards.
      await db.close();
      databaseClosed = true;
      await expectLater(cache.refresh(_snapshot), throwsStateError);
      expect(coverRequests, 1);
      expect(storage.metadataWrites, 1);
      expect(storage.coverWrites, 1);
      expect(persistence.completedRefreshWrites, 1);
    },
  );
}

class _GatedDriftLibraryStore extends DriftLibraryPersistenceStore {
  _GatedDriftLibraryStore(super.db);

  bool holdNextSave = false;
  final saveStarted = Completer<void>();
  final releaseSave = Completer<void>();
  int completedRefreshWrites = 0;

  @override
  Future<void> saveFavorite(LibraryBookEntry entry) async {
    if (!holdNextSave) {
      await super.saveFavorite(entry);
      return;
    }
    saveStarted.complete();
    await releaseSave.future;
    await super.saveFavorite(entry);
    completedRefreshWrites++;
  }
}

class _CountingDownloadStorage extends FileDownloadStorage {
  _CountingDownloadStorage({required super.rootDirectory});

  int metadataWrites = 0;
  int coverWrites = 0;

  @override
  Future<void> writeMetadata(AudioPlaybackBook book) {
    metadataWrites++;
    return super.writeMetadata(book);
  }

  @override
  Future<String> writeCoverBytes(AudioPlaybackBook book, List<int> bytes) {
    coverWrites++;
    return super.writeCoverBytes(book, bytes);
  }
}

const _oldAudioBook = AudioBook(
  id: 'izib-book-2033',
  sourceBookId: '2033',
  title: 'Старое название',
  author: 'Николай Грошев',
  narrator: 'Олег Шубин',
  sourceId: 'izib',
  sourceName: 'Izib',
  durationLabel: '18 ч 1 мин',
  chapterCount: 1,
  progress: 0,
  access: BookAccess.free,
);

const _audioBook = AudioBook(
  id: 'izib-book-2033',
  sourceBookId: '2033',
  title: 'S.T.A.L.K.E.R. Дыхание зоны',
  author: 'Николай Грошев',
  narrator: 'Олег Шубин',
  sourceId: 'izib',
  sourceName: 'Izib',
  durationLabel: '18 ч 1 мин',
  chapterCount: 1,
  progress: 0,
  access: BookAccess.free,
  coverUrl: 'https://izib.uk/covers/zone.jpg',
  year: 2019,
);

const _oldPlaybackBook = AudioPlaybackBook(
  id: 'izib-book-2033',
  versionId: 'izib-2033',
  sourceId: 'izib',
  sourceBookId: '2033',
  title: 'Старое название',
  author: 'Николай Грошев',
  narrator: 'Олег Шубин',
  sourceName: 'Izib',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-1',
      index: 1,
      title: 'Глава 1',
      duration: Duration(minutes: 10),
    ),
  ],
);

const _playbackBook = AudioPlaybackBook(
  id: 'izib-book-2033',
  versionId: 'izib-2033',
  sourceId: 'izib',
  sourceBookId: '2033',
  title: 'S.T.A.L.K.E.R. Дыхание зоны',
  author: 'Николай Грошев',
  narrator: 'Олег Шубин',
  sourceName: 'Izib',
  coverUrl: 'https://izib.uk/covers/zone.jpg',
  publishedYear: 2019,
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-1',
      index: 1,
      title: 'Глава 1',
      duration: Duration(minutes: 10),
    ),
  ],
);

final _snapshot = SourceBookSnapshot(
  details: BookVersionDetails(
    ref: const SourceBookRef(sourceId: 'izib', sourceBookId: '2033'),
    version: BookVersion(
      id: 'izib-2033',
      bookId: 'izib-book-2033',
      sourceId: 'izib',
      sourceBookId: '2033',
      title: 'S.T.A.L.K.E.R. Дыхание зоны',
      normalizedTitle: 'stalker дыхание зоны',
      authors: const ['Николай Грошев'],
      narrators: const ['Олег Шубин'],
      coverUrl: 'https://izib.uk/covers/zone.jpg',
      durationText: '18 ч 1 мин',
      publishedYear: 2019,
      accessType: AccessType.free,
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    ),
  ),
  chapters: [
    Chapter(
      id: 'chapter-1',
      bookVersionId: 'izib-2033',
      sourceId: 'izib',
      sourceBookId: '2033',
      index: 1,
      title: 'Глава 1',
      normalizedTitle: 'глава 1',
      durationMs: 600000,
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    ),
  ],
  audioBook: _audioBook,
  playbackBook: _playbackBook,
);

class _NoopDownloadClient implements DownloadClient {
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    return const DownloadClientResponse(
      bytes: Stream.empty(),
      totalBytes: 0,
      contentLength: 0,
      supportsResume: true,
      shouldAppend: false,
      fileExtension: 'mp3',
    );
  }
}
