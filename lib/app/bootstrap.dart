import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../core/platform/app_device_profile.dart';
import '../data/database/database_connection.dart';
import '../services/audio/audio_persistence.dart';
import '../services/audio/audio_state.dart';
import '../services/audio/playback_controller.dart';
import '../services/audio/playback_controller_provider.dart';
import '../services/downloads/download_manager_provider.dart';
import '../services/downloads/download_persistence.dart';
import '../services/downloads/download_storage.dart';
import '../services/deep_links/app_deep_links.dart';
import '../services/home/home_listening_visibility_store.dart';
import '../services/library/library_drift_persistence.dart';
import '../services/library/library_store.dart';
import '../services/library/later_persistence.dart';
import '../services/library/library_metadata.dart';
import '../services/bookmarks/bookmark_store.dart';
import '../services/bookmarks/bookmark_drift_persistence.dart';
import '../services/settings/app_settings_store.dart';
import '../services/sources/source_catalog_provider.dart';
import '../services/sources/source_catalog_service.dart';
import '../services/sources/source_settings_store.dart';
import '../services/sources/source_access_policy.dart';
import '../sources/sources.dart';
import 'app.dart';
import 'windows_app_exit_listener.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deviceProfile = await AppDeviceProfile.detect();
  final audioEngine = await createPlatformAudioEngine();
  final appDatabase = AppDatabase(openAppDatabaseConnection());
  final downloadStorage = await FileDownloadStorage.create();
  final libraryPersistence = DriftLibraryPersistenceStore(appDatabase);
  final laterPersistence = await FileLaterPersistence.create();
  final metadataStore = LibraryPlaybackMetadataStore(
    downloadStorage,
    libraryPersistence,
  );
  final homeVisibilityStore = HomeListeningVisibilityStore(
    await FileHomeListeningVisibilityPersistence.create(),
  );
  await homeVisibilityStore.load();
  final playbackPersistence = DriftPlaybackPersistenceStore(appDatabase);
  final sourceRegistry = SourceRegistry(defaultSourceConnectors());
  final sourceCatalogService = SourceCatalogService(registry: sourceRegistry);
  final sourceSettings = SourceSettingsStore(
    DriftSourceSettingsPersistenceStore(appDatabase),
  );
  await sourceSettings.load();
  final accessPolicy = SourceAccessPolicy(sourceSettings);
  final playbackController = PlaybackController(
    engine: audioEngine,
    persistence: playbackPersistence,
    bookMetadataStore: metadataStore,
    playbackAccessGuard: (book, chapter) =>
        ensurePlaybackAllowedByPolicy(accessPolicy, book, chapter),
    playbackBookResolver: downloadStorage.offlinePlaybackBook,
    playbackErrorBookResolver: (book) async {
      await ensureRemotePlaybackAllowedByPolicy(accessPolicy, book.sourceId);
      final refreshed = await sourceCatalogService.refreshBookForPlayback(book);
      return downloadStorage.offlinePlaybackBook(refreshed);
    },
  );
  final sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
    if (playbackController.state.isPlaying &&
        playbackController.state.sleepTimerRemaining != null) {
      unawaited(playbackController.tick(const Duration(seconds: 1)));
    }
  });
  Future<void>? databaseClose;

  Future<void> finishDatabaseClose() async {
    // Provider disposal is synchronous. Do not race its final playback writes
    // or native cleanup by closing Drift from a different provider first.
    await playbackController.shutdown();
    await appDatabase.close();
  }

  Future<void> closeDatabase() => databaseClose ??= finishDatabaseClose();

  runApp(
    ProviderScope(
      overrides: [
        appDeviceProfileProvider.overrideWithValue(deviceProfile),
        audioEngineProvider.overrideWith((ref) {
          return audioEngine;
        }),
        playbackPersistenceStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(closeDatabase()));
          return playbackPersistence;
        }),
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(sleepTimerTicker.cancel);
          ref.onDispose(playbackController.dispose);
          return playbackController;
        }),
        downloadStorageProvider.overrideWith((ref) => downloadStorage),
        homeListeningVisibilityStoreProvider.overrideWith((ref) {
          return homeVisibilityStore;
        }),
        downloadPersistenceStoreProvider.overrideWith((ref) {
          return DriftDownloadPersistenceStore(appDatabase);
        }),
        libraryMetadataPersistenceProvider.overrideWith(
          (ref) => libraryPersistence,
        ),
        bookmarkStoreProvider.overrideWith(
          (ref) => BookmarkStore(DriftBookmarkPersistence(appDatabase))..load(),
        ),
        libraryStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(closeDatabase()));
          return LibraryStore(
            libraryPersistence,
            laterPersistence: laterPersistence,
          )..load();
        }),
        appSettingsStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(closeDatabase()));
          return AppSettingsStore(DriftAppSettingsPersistenceStore(appDatabase))
            ..load();
        }),
        sourceSettingsStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(closeDatabase()));
          return sourceSettings;
        }),
      ],
      child: WindowsAppExitListener(
        onExitRequested: () async {
          await playbackController.shutdown();
          sleepTimerTicker.cancel();
          // Other stores/downloads still own this database while widgets live.
          // Keep it open until process exit or ProviderScope disposal.
        },
        child: SlovofonApp(deepLinks: PluginAppDeepLinkSource()),
      ),
    ),
  );

  unawaited(
    _restoreSavedPlaybackSession(
      persistence: playbackPersistence,
      metadataStore: metadataStore,
      downloadStorage: downloadStorage,
      playbackController: playbackController,
      sourceRegistry: sourceRegistry,
      sourceCatalogService: sourceCatalogService,
      accessPolicy: accessPolicy,
    ),
  );
}

Future<void> _restoreSavedPlaybackSession({
  required PlaybackPersistenceStore persistence,
  required PlaybackBookMetadataStore metadataStore,
  required FileDownloadStorage downloadStorage,
  required PlaybackController playbackController,
  required SourceRegistry sourceRegistry,
  required SourceCatalogService sourceCatalogService,
  required SourceAccessPolicy accessPolicy,
}) async {
  try {
    final savedSession = await persistence.loadSession();
    final savedSourceId = savedSession?.activeSourceId;
    final savedVersionId = savedSession?.activeBookVersionId;
    if (savedSourceId == null || savedVersionId == null) {
      return;
    }

    var savedBook = await metadataStore.loadBook(
      sourceId: savedSourceId,
      versionId: savedVersionId,
    );
    if (savedBook == null) {
      return;
    }

    final sourceBookId = savedBook.sourceBookId;
    savedBook = await downloadStorage.offlinePlaybackBook(savedBook);
    final savedChapter = savedBook.chapters
        .where((chapter) => chapter.id == savedSession?.activeChapterId)
        .firstOrNull;
    final hasLocalChapter =
        savedChapter?.mediaSource?.type == AudioMediaSourceType.file ||
        savedChapter?.mediaSource?.type == AudioMediaSourceType.asset;
    var hasTemporaryUrls = false;
    try {
      hasTemporaryUrls = sourceRegistry
          .connectorById(savedSourceId)
          .capabilities
          .hasTemporaryUrls;
    } on Object {
      hasTemporaryUrls = false;
    }

    final missingMedia =
        savedBook.chapters.isEmpty ||
        savedBook.chapters.any((chapter) => chapter.mediaSource == null);
    if (sourceBookId != null &&
        sourceBookId.isNotEmpty &&
        !hasLocalChapter &&
        (hasTemporaryUrls || missingMedia)) {
      try {
        await ensureRemotePlaybackAllowedByPolicy(accessPolicy, savedSourceId);
        savedBook = (await sourceCatalogService.loadBook(
          SourceBookRef(sourceId: savedSourceId, sourceBookId: sourceBookId),
        )).playbackBook;
      } on Object {
        // Keep the cached metadata usable for offline files or non-expired URLs.
      }
    }

    final cachedOrFreshBook = savedBook;
    if (cachedOrFreshBook == null) {
      return;
    }
    final bookToRestore = await downloadStorage.offlinePlaybackBook(
      cachedOrFreshBook,
    );
    if (playbackController.state.hasBook) {
      // User selection wins over a late startup metadata/network response.
      return;
    }
    await playbackController.loadSavedSession(bookToRestore);
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'slovofon bootstrap',
        context: ErrorDescription('while restoring playback session'),
      ),
    );
  }
}
