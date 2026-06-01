import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/database/database_connection.dart';
import '../services/audio/audio_persistence.dart';
import '../services/audio/audio_engine.dart';
import '../services/audio/playback_controller.dart';
import '../services/audio/playback_controller_provider.dart';
import '../services/downloads/download_manager_provider.dart';
import '../services/downloads/download_persistence.dart';
import '../services/downloads/download_storage.dart';
import '../services/deep_links/app_deep_links.dart';
import '../services/home/home_listening_visibility_store.dart';
import '../services/library/library_drift_persistence.dart';
import '../services/library/library_store.dart';
import '../services/settings/app_settings_store.dart';
import '../services/sources/source_catalog_provider.dart';
import '../services/sources/source_catalog_service.dart';
import '../services/sources/source_settings_store.dart';
import '../sources/sources.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioEngine = await createPlatformAudioEngine();
  final appDatabase = AppDatabase(openAppDatabaseConnection());
  final downloadStorage = await FileDownloadStorage.create();
  final homeVisibilityStore = HomeListeningVisibilityStore(
    await FileHomeListeningVisibilityPersistence.create(),
  );
  await homeVisibilityStore.load();
  final playbackPersistence = DriftPlaybackPersistenceStore(appDatabase);
  final sourceRegistry = SourceRegistry(defaultSourceConnectors());
  final sourceCatalogService = SourceCatalogService(registry: sourceRegistry);
  final playbackController = PlaybackController(
    engine: audioEngine,
    persistence: playbackPersistence,
    bookMetadataStore: downloadStorage,
    playbackBookResolver: downloadStorage.offlinePlaybackBook,
  );
  if (audioEngine is AudioEngineChapterNavigationBinding) {
    final bindableEngine = audioEngine as AudioEngineChapterNavigationBinding;
    bindableEngine.bindChapterNavigation(
      AudioEngineChapterNavigationCallbacks(
        onPreviousChapter: playbackController.previousChapter,
        onNextChapter: playbackController.nextChapter,
      ),
    );
  }
  final sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
    if (playbackController.state.isPlaying &&
        playbackController.state.sleepTimerRemaining != null) {
      unawaited(playbackController.tick(const Duration(seconds: 1)));
    }
  });
  var databaseClosed = false;

  Future<void> closeDatabase() async {
    if (databaseClosed) {
      return;
    }
    databaseClosed = true;
    await appDatabase.close();
  }

  runApp(
    ProviderScope(
      overrides: [
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
        libraryStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(closeDatabase()));
          return LibraryStore(DriftLibraryPersistenceStore(appDatabase))
            ..load();
        }),
        appSettingsStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(closeDatabase()));
          return AppSettingsStore(DriftAppSettingsPersistenceStore(appDatabase))
            ..load();
        }),
        sourceSettingsStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(closeDatabase()));
          return SourceSettingsStore(
            DriftSourceSettingsPersistenceStore(appDatabase),
          )..load();
        }),
      ],
      child: SlovofonApp(deepLinks: PluginAppDeepLinkSource()),
    ),
  );

  unawaited(
    _restoreSavedPlaybackSession(
      persistence: playbackPersistence,
      metadataStore: downloadStorage,
      downloadStorage: downloadStorage,
      playbackController: playbackController,
      sourceRegistry: sourceRegistry,
      sourceCatalogService: sourceCatalogService,
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
    var hasTemporaryUrls = false;
    try {
      hasTemporaryUrls = sourceRegistry
          .connectorById(savedSourceId)
          .capabilities
          .hasTemporaryUrls;
    } on Object {
      hasTemporaryUrls = false;
    }

    if (sourceBookId != null && sourceBookId.isNotEmpty && hasTemporaryUrls) {
      try {
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
