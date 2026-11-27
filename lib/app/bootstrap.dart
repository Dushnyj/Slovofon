import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../core/platform/app_device_profile.dart';
import '../data/database/database_connection.dart';
import '../services/audio/audio_persistence.dart';
import '../services/audio/playback_controller.dart';
import '../services/audio/playback_controller_provider.dart';
import '../services/downloads/download_manager_provider.dart';
import '../services/downloads/download_manager.dart';
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
import '../services/settings/android_download_network.dart';
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
    playbackChapterResolver: sourceCatalogService.resolvePlaybackChapter,
    playbackErrorBookResolver: (book) async {
      await ensureRemotePlaybackAllowedByPolicy(accessPolicy, book.sourceId);
      final sourceBookId = book.sourceBookId;
      if (sourceBookId == null || sourceBookId.isEmpty) return book;
      final refreshed = await sourceCatalogService.loadBookPreview(
        SourceBookRef(sourceId: book.sourceId, sourceBookId: sourceBookId),
        forceRefresh: true,
      );
      return downloadStorage.offlinePlaybackBook(refreshed.playbackBook);
    },
  );
  final sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
    unawaited(playbackController.pollSleepTimer());
  });
  Future<void>? databaseClose;
  ProviderContainer? providerContainer;
  DownloadManager? downloadManager;
  AppSettingsStore? appSettingsStore;
  LibraryStore? libraryStore;
  BookmarkStore? bookmarkStore;
  var exitRequested = false;

  Future<void> drainResources() async {
    exitRequested = true;
    final container = providerContainer;
    if (container != null && container.exists(downloadManagerProvider)) {
      downloadManager ??= container.read(downloadManagerProvider);
    }
    await playbackController.shutdown();
    sleepTimerTicker.cancel();
    await downloadManager?.shutdown();
    await appSettingsStore?.flushPendingWrites();
    await libraryStore?.flushPendingWrites();
    await bookmarkStore?.flushPendingWrites();
    await sourceSettings.flushPendingWrites();
  }

  Future<void> finishDatabaseClose() async {
    // Provider disposal is synchronous. Do not race its final playback writes
    // or native cleanup by closing Drift from a different provider first.
    // Normally drained before ProviderScope unmount. Keep the same ordering
    // for disposal requested independently of the native WM_CLOSE bridge.
    await playbackController.shutdown();
    await downloadManager?.shutdown();
    await appSettingsStore?.flushPendingWrites();
    await libraryStore?.flushPendingWrites();
    await bookmarkStore?.flushPendingWrites();
    await sourceSettings.flushPendingWrites();
    await appDatabase.close();
  }

  Future<void> closeDatabase() {
    final existing = databaseClose;
    if (existing != null) return existing;
    final closing = finishDatabaseClose();
    databaseClose = closing;
    closing.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(databaseClose, closing)) databaseClose = null;
      },
    );
    return closing;
  }

  runApp(
    WindowsAppExitListener(
      onExitRequested: drainResources,
      onExitReady: closeDatabase,
      retryOnlyOnFailure: true,
      child: ProviderScope(
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
          if (Platform.isAndroid)
            downloadInitialNetworkGateProvider.overrideWithValue(
              DownloadNetworkGate.offline,
            ),
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
            (ref) => bookmarkStore = BookmarkStore(
              DriftBookmarkPersistence(appDatabase),
            )..load(),
          ),
          libraryStoreProvider.overrideWith((ref) {
            ref.onDispose(() => unawaited(closeDatabase()));
            return libraryStore = LibraryStore(
              libraryPersistence,
              laterPersistence: laterPersistence,
            )..load();
          }),
          appSettingsStoreProvider.overrideWith((ref) {
            ref.onDispose(() => unawaited(closeDatabase()));
            return appSettingsStore = AppSettingsStore(
              DriftAppSettingsPersistenceStore(appDatabase),
            )..load();
          }),
          sourceSettingsStoreProvider.overrideWith((ref) {
            ref.onDispose(() => unawaited(closeDatabase()));
            return sourceSettings;
          }),
        ],
        child: Builder(
          builder: (context) {
            providerContainer = ProviderScope.containerOf(
              context,
              listen: false,
            );
            if (Platform.isAndroid) {
              providerContainer!.read(androidDownloadNetworkBindingProvider);
            }
            return SlovofonApp(deepLinks: PluginAppDeepLinkSource());
          },
        ),
      ),
    ),
  );

  final restoreRevision = playbackController.playbackSelectionRevision;
  unawaited(
    _restoreSavedPlaybackSession(
      persistence: playbackPersistence,
      metadataStore: metadataStore,
      playbackController: playbackController,
      shouldRestore: () =>
          !exitRequested &&
          playbackController.isPlaybackSelectionCurrent(restoreRevision),
    ),
  );
}

Future<void> _restoreSavedPlaybackSession({
  required PlaybackPersistenceStore persistence,
  required PlaybackBookMetadataStore metadataStore,
  required PlaybackController playbackController,
  required bool Function() shouldRestore,
}) async {
  try {
    final savedSession = await persistence.loadSession();
    if (!shouldRestore()) return;
    final savedSourceId = savedSession?.activeSourceId;
    final savedVersionId = savedSession?.activeBookVersionId;
    if (savedSourceId == null || savedVersionId == null) {
      return;
    }

    final savedBook = await metadataStore.loadBook(
      sourceId: savedSourceId,
      versionId: savedVersionId,
    );
    if (!shouldRestore() ||
        playbackController.state.hasBook ||
        savedBook == null ||
        savedBook.chapters.isEmpty) {
      return;
    }
    // Network refresh and the filesystem overlay run only when the user plays.
    await playbackController.loadSavedSession(savedBook, loadMedia: false);
  } catch (error, stackTrace) {
    if (!shouldRestore()) return;
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
