import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/sources/source_settings_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/source_registry.dart';

void main() {
  late Directory root;
  late FileDownloadStorage storage;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('slovofon-download-access-');
    storage = FileDownloadStorage(rootDirectory: root);
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  _identityTests(() => storage);

  test(
    'production provider enforces live settings without replacing the manager',
    () async {
      final settings = SourceSettingsStore(
        MemorySourceSettingsPersistenceStore(),
      );
      final client = _BytesClient();
      final container = ProviderContainer(
        overrides: [
          downloadStorageProvider.overrideWithValue(storage),
          downloadClientProvider.overrideWithValue(client),
          sourceSettingsStoreProvider.overrideWith((ref) => settings),
          sourceCatalogServiceProvider.overrideWith((ref) => _Catalog()),
        ],
      );
      addTearDown(container.dispose);
      final manager = container.read(downloadManagerProvider);
      await settings.setMediaPermissions('izib', allowDownload: false);
      expect(
        identical(container.read(downloadManagerProvider), manager),
        isTrue,
      );
      await manager.enqueueBook(_book);
      expect(client.opens, 0);
      expect(manager.tasks.single.status, DownloadTaskStatus.failed);
      expect(manager.tasks.single.errorCode, 'source_download_disabled');
      await settings.setMediaPermissions('izib', allowDownload: true);
      await manager.enqueueBook(_book);
      await manager.waitForIdle();
      expect(
        identical(container.read(downloadManagerProvider), manager),
        isTrue,
      );
      expect(client.opens, 1);
      expect(manager.tasks.single.status, DownloadTaskStatus.completed);
    },
  );

  test(
    'verified completed offline file bypasses denial and is not downloaded again',
    () async {
      await storage.writeMetadata(_book);
      final finalFile = storage.chapterFileFor(
        _book,
        _book.chapters.first,
        extension: 'mp3',
      );
      await finalFile.parent.create(recursive: true);
      await finalFile.writeAsBytes([7, 8]);
      final offline = await storage.offlinePlaybackBook(_book);
      expect(offline.chapters.first.originalMediaSource, isNotNull);
      final client = _BytesClient();
      var checks = 0;
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: MemoryDownloadPersistenceStore(),
        ensureDownloadAllowed: (_, _) async {
          checks++;
          throw _denial;
        },
      );
      addTearDown(manager.dispose);
      await manager.enqueueBook(offline);
      await manager.waitForIdle();
      expect(checks, 0);
      expect(client.opens, 0);
      expect(manager.tasks.single.status, DownloadTaskStatus.completed);
      expect(await finalFile.readAsBytes(), [7, 8]);
    },
  );

  for (final local in [
    AudioMediaSource.file('synthetic-local.mp3'),
    AudioMediaSource.asset('synthetic-local.mp3'),
  ]) {
    test(
      'restored ${local.type.name} transfer never refreshes or checks remote permission',
      () async {
        final book = _book.copyWith(
          chapters: [_book.chapters.first.copyWith(mediaSource: local)],
        );
        final persistence = MemoryDownloadPersistenceStore();
        await storage.writeMetadata(book);
        await persistence.saveTask(_task(book, DownloadTaskStatus.paused));
        var checks = 0;
        var refreshes = 0;
        final client = _BytesClient();
        final manager = DownloadManager(
          client: client,
          storage: storage,
          persistence: persistence,
          ensureDownloadAllowed: (_, _) async {
            checks++;
            throw _denial;
          },
          refreshBookForDownloads: (value) async {
            refreshes++;
            return value;
          },
        );
        addTearDown(manager.dispose);
        await manager.retryChapter(book, book.chapters.first);
        await manager.waitForIdle();
        expect(checks, 0);
        expect(refreshes, 0);
        expect(client.opens, 1);
        expect(manager.tasks.single.status, DownloadTaskStatus.completed);
      },
    );
  }

  for (final retry in [false, true]) {
    test(
      'restored ${retry ? 'retry' : 'resume'} denial retains task and partial bytes',
      () async {
        final persistence = MemoryDownloadPersistenceStore();
        await storage.writeMetadata(_book);
        await persistence.saveTask(_task(_book, DownloadTaskStatus.paused));
        final part = storage.partFileFor(_book, _book.chapters.first);
        await part.parent.create(recursive: true);
        await part.writeAsBytes([4, 5]);
        final client = _BytesClient();
        var refreshes = 0;
        final manager = DownloadManager(
          client: client,
          storage: storage,
          persistence: persistence,
          ensureDownloadAllowed: (_, _) async => throw _denial,
          refreshBookForDownloads: (value) async {
            refreshes++;
            return value;
          },
        );
        addTearDown(manager.dispose);
        await (retry
            ? manager.retryChapter(_book, _book.chapters.first)
            : manager.resumeChapter(_book, _book.chapters.first));
        await manager.waitForIdle();
        expect(client.opens, 0);
        expect(refreshes, 0);
        expect(manager.tasks.single.id, 'restored');
        expect(manager.tasks.single.status, DownloadTaskStatus.failed);
        expect(manager.tasks.single.errorCode, 'source_download_disabled');
        expect(
          (await persistence.loadTasks()).single.status,
          DownloadTaskStatus.failed,
        );
        expect(await part.readAsBytes(), [4, 5]);
      },
    );
  }

  test(
    'queued chapter rechecks permission at actual open and persists denial code',
    () async {
      final book = _book.copyWith(
        chapters: [
          _book.chapters.first,
          _book.chapters.first.copyWith(id: 'second', index: 1),
        ],
      );
      final firstDone = Completer<void>();
      final client = _BytesClient(firstDone: firstDone);
      var allowed = true;
      final persistence = MemoryDownloadPersistenceStore();
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
        maxConcurrentDownloads: 1,
        ensureDownloadAllowed: (_, _) async {
          if (!allowed) throw _denial;
        },
      );
      addTearDown(manager.dispose);
      await manager.enqueueBook(book);
      await client.firstOpened.future;
      expect(
        manager.tasks.where((task) => task.status == DownloadTaskStatus.queued),
        hasLength(1),
      );
      allowed = false;
      firstDone.complete();
      await manager.waitForIdle();
      expect(client.opens, 1);
      final denied = manager.taskForBookChapter(book, book.chapters.last)!;
      expect(denied.status, DownloadTaskStatus.failed);
      expect(denied.errorCode, 'source_download_disabled');
      expect(
        (await persistence.loadTasks())
            .singleWhere((task) => task.id == denied.id)
            .errorCode,
        'source_download_disabled',
      );
      expect(
        await storage.completedChapterFile(book, book.chapters.first),
        isNotNull,
      );
      expect(
        await storage.completedChapterFile(book, book.chapters.last),
        isNull,
      );
    },
  );

  test(
    'permission revoked after retry queued blocks remote refresh and preserves part',
    () async {
      final persistence = _GatedRunningPersistence();
      await storage.writeMetadata(_book);
      await persistence.saveTask(_task(_book, DownloadTaskStatus.paused));
      final part = storage.partFileFor(_book, _book.chapters.first);
      await part.parent.create(recursive: true);
      await part.writeAsBytes([4, 5]);
      final client = _BytesClient();
      var allowed = true;
      var refreshes = 0;
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
        ensureDownloadAllowed: (_, _) async {
          if (!allowed) throw _denial;
        },
        refreshBookForDownloads: (value) async {
          refreshes++;
          return value;
        },
      );
      addTearDown(manager.dispose);
      await manager.retryChapter(_book, _book.chapters.first);
      await persistence.started.future;
      allowed = false;
      persistence.release.complete();
      await manager.waitForIdle();
      expect(refreshes, 0);
      expect(client.opens, 0);
      expect(manager.tasks.single.errorCode, 'source_download_disabled');
      expect(await part.readAsBytes(), [4, 5]);
    },
  );

  test(
    'permission revoked during remote refresh blocks media open afterwards',
    () async {
      final persistence = MemoryDownloadPersistenceStore();
      await storage.writeMetadata(_book);
      await persistence.saveTask(_task(_book, DownloadTaskStatus.paused));
      final refreshed = Completer<AudioPlaybackBook>();
      final refreshStarted = Completer<void>();
      final client = _BytesClient();
      var allowed = true;
      final manager = DownloadManager(
        client: client,
        storage: storage,
        persistence: persistence,
        ensureDownloadAllowed: (_, _) async {
          if (!allowed) throw _denial;
        },
        refreshBookForDownloads: (value) {
          refreshStarted.complete();
          return refreshed.future;
        },
      );
      addTearDown(manager.dispose);
      await manager.retryChapter(_book, _book.chapters.first);
      await refreshStarted.future;
      allowed = false;
      refreshed.complete(_book);
      await manager.waitForIdle();
      expect(client.opens, 0);
      expect(manager.tasks.single.status, DownloadTaskStatus.failed);
      expect(manager.tasks.single.errorCode, 'source_download_disabled');
    },
  );
}

void _identityTests(FileDownloadStorage Function() getStorage) {
  for (final legacy in [false, true]) {
    test(
      'refresh rejects another version but preserves legacy identity=$legacy',
      () async {
        final storage = getStorage();
        final initial = AudioPlaybackBook(
          id: _book.id,
          versionId: legacy ? 'version' : _book.versionId,
          sourceId: _book.sourceId,
          sourceBookId: _book.sourceBookId,
          title: _book.title,
          author: _book.author,
          narrator: _book.narrator,
          sourceName: _book.sourceName,
          chapters: _book.chapters,
        );
        final refreshed = legacy
            ? _book
            : AudioPlaybackBook(
                id: _book.id,
                versionId: 'another-narration',
                sourceId: _book.sourceId,
                sourceBookId: _book.sourceBookId,
                title: _book.title,
                author: _book.author,
                narrator: 'Other',
                sourceName: _book.sourceName,
                chapters: _book.chapters,
              );
        final persistence = MemoryDownloadPersistenceStore();
        await storage.writeMetadata(initial);
        await persistence.saveTask(_task(initial, DownloadTaskStatus.paused));
        final part = storage.partFileFor(initial, initial.chapters.first);
        await part.parent.create(recursive: true);
        await part.writeAsBytes([4, 5]);
        final originalDirectory = storage.bookDirectoryFor(initial).path;
        final client = _BytesClient(append: true);
        final manager = DownloadManager(
          client: client,
          storage: storage,
          persistence: persistence,
          refreshBookForDownloads: (_) async => refreshed,
        );
        addTearDown(manager.dispose);
        await manager.retryChapter(initial, initial.chapters.first);
        await manager.waitForIdle();
        expect(manager.tasks.single.bookVersionId, initial.versionId);
        expect(manager.bookForTask('restored')!.versionId, initial.versionId);
        expect(storage.bookDirectoryFor(initial).path, originalDirectory);
        expect(
          await storage.readMetadataForIds(
            refreshed.sourceId,
            refreshed.versionId,
          ),
          isNull,
        );
        if (legacy) {
          expect(client.opens, 1);
          expect(manager.tasks.single.status, DownloadTaskStatus.completed);
          expect(
            await (await storage.completedChapterFile(
              initial,
              initial.chapters.first,
            ))!.readAsBytes(),
            [4, 5, 1],
          );
        } else {
          expect(client.opens, 0);
          expect(manager.tasks.single.status, DownloadTaskStatus.failed);
          expect(
            manager.tasks.single.errorMessage,
            'Refreshed book does not match.',
          );
          expect(await part.readAsBytes(), [4, 5]);
        }
      },
    );
  }
}

const _denial = DownloadClientException(
  'source_download_disabled',
  code: 'source_download_disabled',
);
final _book = AudioPlaybackBook(
  id: 'book',
  versionId: 'izib:version',
  sourceId: 'izib',
  sourceBookId: 'version',
  title: 'Book',
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
        Uri.parse('https://media.example.invalid/chapter.mp3'),
      ),
    ),
  ],
);
DownloadTask _task(AudioPlaybackBook book, DownloadTaskStatus status) =>
    DownloadTask(
      id: 'restored',
      bookId: book.id,
      bookVersionId: book.versionId,
      sourceId: book.sourceId,
      chapterId: book.chapters.first.id,
      type: DownloadTaskType.chapter,
      status: status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _BytesClient implements DownloadClient {
  _BytesClient({this.firstDone, this.append = false});
  final bool append;
  final Completer<void>? firstDone;
  final firstOpened = Completer<void>();
  int opens = 0;
  @override
  Future<DownloadClientResponse> open(
    AudioMediaSource source, {
    required int startByte,
    required DownloadCancellationToken cancellationToken,
  }) async {
    opens++;
    if (!firstOpened.isCompleted) firstOpened.complete();
    return DownloadClientResponse(
      bytes: _bytes(opens),
      totalBytes: append ? startByte + 1 : 1,
      contentLength: 1,
      supportsResume: append,
      shouldAppend: append,
      fileExtension: 'mp3',
    );
  }

  Stream<List<int>> _bytes(int number) async* {
    if (number == 1 && firstDone != null) await firstDone!.future;
    yield [1];
  }
}

class _Catalog extends SourceCatalogService {
  _Catalog() : super(registry: SourceRegistry(const []));
  @override
  Future<AudioPlaybackBook> refreshBookForDownloads(
    AudioPlaybackBook book,
  ) async => book;
}

class _GatedRunningPersistence extends MemoryDownloadPersistenceStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> saveTask(DownloadTask task) async {
    if (task.status == DownloadTaskStatus.running && !started.isCompleted) {
      started.complete();
      await release.future;
    }
    await super.saveTask(task);
  }
}
