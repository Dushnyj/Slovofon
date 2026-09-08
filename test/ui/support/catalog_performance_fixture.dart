import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/core/platform/app_device_profile.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/library/library_metadata.dart';
import 'package:slovofon/services/library/library_store.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/services/updates/update_service.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/sources/sources.dart';

/// No test binding, DB, disk, HTTP, audio platform, or native windows dependency.
/// Deliberately fails closed for fixture actions not implemented in memory.
class CatalogPerformanceFixture {
  CatalogPerformanceFixture({this.bookCount = 500, this.searchCount = 120});
  final int bookCount;
  final int searchCount;
  final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
  final library = LibraryStore(
    MemoryLibraryPersistenceStore(),
    // Favorites predate listening history, so wall-clock execution time cannot
    // move fixture-0 below 499 newer favorites in the lazy Library viewport.
    clock: () => DateTime(2026, 9, 7),
  );
  final engine = InMemoryAudioEngine();
  final downloads = CatalogPerformanceDownloads();
  late final controller = PlaybackController(engine: engine);
  late final books = List.generate(
    bookCount,
    (index) => AudioPlaybackBook(
      id: 'fixture-$index',
      versionId: 'fixture-version-$index',
      sourceId: 'izib',
      sourceBookId: 'fixture-$index',
      sourceName: 'Izib',
      title: 'Audiobook ${index.toString().padLeft(3, '0')}',
      author: 'Fixture Author',
      narrator: 'Fixture Narrator',
      description:
          'A deterministic in-memory audiobook for catalog performance measurements.',
      // Placeholder art intentionally excludes network/decode from catalog CPU proof.
      chapters: List.generate(
        20,
        (chapter) => AudioPlaybackChapter(
          id: 'fixture-$index-chapter-$chapter',
          index: chapter,
          title: 'Chapter ${chapter + 1}',
          duration: const Duration(minutes: 20),
        ),
      ),
    ),
  );
  late final progress = [
    for (var i = 0; i < books.length; i++)
      PlaybackProgressSnapshot(
        bookId: books[i].id,
        bookVersionId: books[i].versionId,
        currentChapterId: books[i].chapters.first.id,
        currentPositionMs: 600000,
        maxReachedGlobalPositionMs: 600000,
        totalDurationMs: books[i].totalDuration.inMilliseconds,
        listenedDurationMs: 600000,
        percent: .025,
        isFinished: false,
        lastPlayedAt: DateTime(2026, 9, 8).subtract(Duration(minutes: i)),
      ),
  ];

  Future<void> initialize({double textScale = 1}) async {
    await settings.setLanguageCode('en');
    await settings.setThemeMode(AppThemeMode.dark);
    await settings.setTextScale(textScale);
    await library.load();
    for (final book in books) {
      await library.toggleFavorite(libraryCardBook(book));
    }
    await controller.loadBook(
      books.first,
      position: const Duration(minutes: 10),
    );
  }

  Widget app({
    AppDeviceProfile profile = const AppDeviceProfile(),
  }) => ProviderScope(
    overrides: [
      appDeviceProfileProvider.overrideWithValue(profile),
      appSettingsStoreProvider.overrideWith((ref) => settings),
      libraryStoreProvider.overrideWith((ref) => library),
      audioEngineProvider.overrideWithValue(engine),
      playbackControllerProvider.overrideWith((ref) {
        ref.onDispose(controller.dispose);
        return controller;
      }),
      playbackProgressSnapshotsProvider.overrideWith((ref) async => progress),
      libraryPlaybackBooksProvider.overrideWith((ref) async => books),
      historyPlaybackBooksProvider.overrideWith((ref) async => books),
      downloadStorageProvider.overrideWithValue(_MemoryCatalogStorage(books)),
      downloadManagerProvider.overrideWith((ref) => downloads),
      searchHistoryStoreProvider.overrideWithValue(_MemoryHistory()),
      sourceRegistryProvider.overrideWithValue(SourceRegistry([])),
      sourceCatalogServiceProvider.overrideWithValue(
        _Catalog(books.take(searchCount).toList()),
      ),
      updateServiceProvider.overrideWithValue(
        UpdateService(
          client: const UpdateClient(),
          installer: PlatformUpdateInstaller(),
          runtimePlatform: UpdateRuntimePlatform.unsupported,
        ),
      ),
    ],
    child: const SlovofonApp(),
  );
}

class CatalogPerformanceDownloads extends ChangeNotifier
    implements DownloadManager {
  List<DownloadTask> _tasks = const [];
  AudioPlaybackBook? _book;
  @override
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  @override
  DownloadTask? taskById(String id) =>
      _tasks.where((task) => task.id == id).firstOrNull;
  @override
  AudioPlaybackBook? bookForTask(String taskId) =>
      taskById(taskId) == null ? null : _book;
  @override
  DownloadTask? taskForChapter(String chapterId) =>
      _tasks.where((task) => task.chapterId == chapterId).firstOrNull;
  @override
  DownloadTask? taskForBookChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) => _tasks
      .where(
        (task) => task.chapterId == chapter.id && taskMatchesBook(task, book),
      )
      .firstOrNull;
  @override
  bool taskMatchesBook(DownloadTask task, AudioPlaybackBook book) =>
      task.sourceId == book.sourceId &&
      (task.bookVersionId == book.versionId ||
          (book.sourceBookId != null &&
              task.bookVersionId == book.sourceBookId));

  void updateBook(
    AudioPlaybackBook book,
    DownloadTaskStatus status,
    double progress,
  ) {
    _book = book;
    _tasks = [
      for (final chapter in book.chapters)
        DownloadTask(
          id: 'fixture-download-${chapter.id}',
          bookId: book.id,
          bookVersionId: book.versionId,
          chapterId: chapter.id,
          sourceId: book.sourceId,
          type: DownloadTaskType.chapter,
          status: status,
          progress: progress,
          downloadedBytes: (1000 * progress).round(),
          totalBytes: 1000,
          createdAt: DateTime(2026, 9, 8),
          updatedAt: DateTime(2026, 9, 8),
        ),
    ];
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('No download I/O actions in catalog-only fixture');
}

class _MemoryCatalogStorage implements FileDownloadStorage {
  _MemoryCatalogStorage(this.books);
  final List<AudioPlaybackBook> books;
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => books;
  @override
  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async =>
      book;
  @override
  Future<void> saveBook(AudioPlaybackBook book) async {}
  @override
  Future<void> writeMetadata(AudioPlaybackBook book) async {}
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);
  @override
  Future<AudioPlaybackBook?> readMetadataForIds(
    String sourceId,
    String versionId,
  ) async => books
      .where((book) => book.sourceId == sourceId && book.versionId == versionId)
      .firstOrNull;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('No filesystem actions in catalog-only fixture');
}

class _Catalog extends SourceCatalogService {
  _Catalog(this.books) : super(registry: SourceRegistry([]));
  final List<AudioPlaybackBook> books;
  @override
  Future<SourceSearchResponse> search(
    SearchRequest request, {
    void Function(SourceSearchResponse)? onUpdate,
    SourceSearchCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    return SourceSearchResponse(
      results: [
        for (final book in books)
          BookSearchResult(
            ref: SourceBookRef(
              sourceId: book.sourceId,
              sourceBookId: book.sourceBookId!,
            ),
            sourceName: book.sourceName,
            title: book.title,
            author: book.author,
            narrator: book.narrator,
            duration: book.totalDuration,
            accessType: AccessType.free,
          ),
      ],
    );
  }

  @override
  Future<AudioPlaybackBook> refreshBookForPlayback(
    AudioPlaybackBook book,
  ) async => book;
}

class _MemoryHistory extends SearchHistoryStore {
  final _entries = <SearchHistoryEntry>[];
  @override
  Future<List<SearchHistoryEntry>> load() async => List.unmodifiable(_entries);
  @override
  Future<List<SearchHistoryEntry>> record(String query, SearchKind kind) async {
    _entries.removeWhere((entry) => entry.query == query && entry.kind == kind);
    _entries.insert(
      0,
      SearchHistoryEntry(
        query: query,
        kind: kind,
        lastUsedAt: DateTime(2026, 9, 8),
        usageCount: 1,
      ),
    );
    return load();
  }

  @override
  Future<List<SearchHistoryEntry>> delete(String query, SearchKind kind) async {
    _entries.removeWhere((entry) => entry.query == query && entry.kind == kind);
    return load();
  }
}
