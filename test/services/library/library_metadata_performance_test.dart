import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/database/app_database.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_drift_persistence.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/library/library_store.dart';

void main() {
  test(
    'home history reads only referenced durable versions without cache scan',
    () async {
      final durable = _Metadata([_book('current'), _book('unrelated')]);
      final cache = _Cache([_book('unrelated')]);
      final container = ProviderContainer(
        overrides: [
          playbackProgressSnapshotsProvider.overrideWith(
            (ref) async => [_progress('current')],
          ),
          libraryMetadataPersistenceProvider.overrideWithValue(durable),
          downloadStorageProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      final books = await container.read(historyPlaybackBooksProvider.future);
      expect(books.map((book) => book.versionId), ['current']);
      expect(durable.requested, [
        {'current'},
      ]);
      expect(cache.scans, 0);
    },
  );

  test(
    'legacy history recovers only missing referenced cache metadata',
    () async {
      final durable = _Metadata([_book('current')]);
      final cache = _Cache([_book('legacy'), _book('unrelated')]);
      final container = ProviderContainer(
        overrides: [
          playbackProgressSnapshotsProvider.overrideWith(
            (ref) async => [_progress('current'), _progress('legacy')],
          ),
          libraryMetadataPersistenceProvider.overrideWithValue(durable),
          downloadStorageProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      final books = await container.read(historyPlaybackBooksProvider.future);
      expect(books.map((book) => book.versionId).toSet(), {
        'current',
        'legacy',
      });
      expect(cache.scans, 1);
      expect(durable.saved, ['legacy']);
    },
  );

  test('position-only history refresh does not reload book metadata', () async {
    final durable = _Metadata([_book('current')]);
    final cache = _Cache([]);
    final container = ProviderContainer(
      overrides: [
        playbackProgressSnapshotsProvider.overrideWith(
          (ref) async => [_progress('current')],
        ),
        libraryMetadataPersistenceProvider.overrideWithValue(durable),
        downloadStorageProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      historyPlaybackBooksProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(historyPlaybackBooksProvider.future);
    for (var i = 0; i < 10; i++) {
      container.invalidate(playbackProgressSnapshotsProvider);
      await container.read(playbackProgressSnapshotsProvider.future);
      await container.pump();
      expect(
        (await container.read(
          historyPlaybackBooksProvider.future,
        )).single.versionId,
        'current',
      );
    }
    expect(durable.requested, [
      {'current'},
    ]);
    expect(cache.scans, 0);
  });

  for (final historyOnly in [true, false]) {
    test(
      'disposed metadata provider skips late cache repair (history=$historyOnly)',
      () async {
        final durable = _Metadata([]);
        final cache = _GatedCache();
        final container = ProviderContainer(
          overrides: [
            playbackProgressSnapshotsProvider.overrideWith(
              (ref) async => [_progress('legacy')],
            ),
            libraryMetadataPersistenceProvider.overrideWithValue(durable),
            downloadStorageProvider.overrideWithValue(cache),
          ],
        );
        final provider = historyOnly
            ? historyPlaybackBooksProvider
            : libraryPlaybackBooksProvider;
        final result = container
            .read(provider.future)
            .then<void>((_) {}, onError: (Object _) {});
        await cache.started.future;
        container.dispose();
        cache.result.complete([_book('legacy')]);
        await result;
        await Future<void>.delayed(Duration.zero);
        expect(durable.saved, isEmpty);
      },
    );
  }

  test(
    'metadata fallback queries a single version and checks source identity',
    () async {
      final durable = _Metadata([_book('one'), _book('two')]);
      final store = LibraryPlaybackMetadataStore(_Cache([]), durable);
      expect(
        (await store.loadBook(
          sourceId: 'fixture',
          versionId: 'one',
        ))?.versionId,
        'one',
      );
      expect(await store.loadBook(sourceId: 'other', versionId: 'one'), isNull);
      expect(durable.requested, [
        {'one'},
        {'one'},
      ]);
    },
  );

  test(
    'Drift favorites join keeps order and filtered metadata accepts large ID sets',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final persistence = DriftLibraryPersistenceStore(db);
      for (var i = 0; i < 4; i++) {
        await persistence.saveFavorite(
          LibraryBookEntry(
            book: libraryCardBook(_book('book-$i')),
            isFavorite: true,
            updatedAt: DateTime(2026, 1, i + 1),
          ),
        );
      }
      final favorites = await persistence.loadFavorites();
      expect(favorites.map((entry) => entry.book.title), [
        'book-3',
        'book-2',
        'book-1',
        'book-0',
      ]);
      await persistence.savePlaybackBook(_book('target'));
      final books = await persistence.loadPlaybackBooks(
        versionIds: {'target', for (var i = 0; i < 1200; i++) 'missing-$i'},
      );
      expect(books.map((book) => book.versionId), ['target']);
      expect(await persistence.loadPlaybackBooks(versionIds: {}), isEmpty);
    },
  );
}

AudioPlaybackBook _book(String id) => AudioPlaybackBook(
  id: 'book-$id',
  versionId: id,
  sourceId: 'fixture',
  sourceBookId: id,
  title: id,
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Fixture',
  chapters: const [],
);

PlaybackProgressSnapshot _progress(String id) => PlaybackProgressSnapshot(
  bookId: 'book-$id',
  bookVersionId: id,
  currentChapterId: null,
  currentPositionMs: 0,
  maxReachedGlobalPositionMs: 0,
  totalDurationMs: 1000,
  listenedDurationMs: 0,
  percent: 0,
  isFinished: false,
  lastPlayedAt: DateTime(2026),
);

class _Metadata implements LibraryMetadataPersistence {
  _Metadata(this.books);
  final List<AudioPlaybackBook> books;
  final requested = <Set<String>?>[];
  final saved = <String>[];
  @override
  Future<List<AudioPlaybackBook>> loadPlaybackBooks({
    Set<String>? versionIds,
  }) async {
    requested.add(versionIds == null ? null : Set.of(versionIds));
    return books
        .where(
          (book) => versionIds == null || versionIds.contains(book.versionId),
        )
        .toList();
  }

  @override
  Future<void> savePlaybackBook(AudioPlaybackBook book) async {
    saved.add(book.versionId);
  }
}

class _Cache extends FileDownloadStorage {
  _Cache(this.books)
    : super(rootDirectory: Directory('never-written-metadata-probe'));
  final List<AudioPlaybackBook> books;
  var scans = 0;
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async {
    scans++;
    return books;
  }

  @override
  Future<AudioPlaybackBook?> loadBook({
    required String sourceId,
    required String versionId,
  }) async => null;
}

class _GatedCache extends _Cache {
  _GatedCache() : super([]);
  final started = Completer<void>();
  final result = Completer<List<AudioPlaybackBook>>();
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() {
    started.complete();
    return result.future;
  }
}
