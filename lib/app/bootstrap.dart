import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/database/database_connection.dart';
import '../services/audio/audio_persistence.dart';
import '../services/audio/playback_controller.dart';
import '../services/audio/playback_controller_provider.dart';
import '../services/downloads/download_manager_provider.dart';
import '../services/downloads/download_persistence.dart';
import '../services/downloads/download_storage.dart';
import '../services/library/library_drift_persistence.dart';
import '../services/library/library_store.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioEngine = await createPlatformAudioEngine();
  final appDatabase = AppDatabase(openAppDatabaseConnection());
  final downloadStorage = await FileDownloadStorage.create();
  final playbackPersistence = DriftPlaybackPersistenceStore(appDatabase);
  final playbackController = PlaybackController(
    engine: audioEngine,
    persistence: playbackPersistence,
    bookMetadataStore: downloadStorage,
  );
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
          ref.onDispose(playbackController.dispose);
          return playbackController;
        }),
        downloadStorageProvider.overrideWith((ref) => downloadStorage),
        downloadPersistenceStoreProvider.overrideWith((ref) {
          return DriftDownloadPersistenceStore(appDatabase);
        }),
        libraryStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(closeDatabase()));
          return LibraryStore(DriftLibraryPersistenceStore(appDatabase))
            ..load();
        }),
      ],
      child: const SlovofonApp(),
    ),
  );

  unawaited(
    _restoreSavedPlaybackSession(
      persistence: playbackPersistence,
      metadataStore: downloadStorage,
      playbackController: playbackController,
    ),
  );
}

Future<void> _restoreSavedPlaybackSession({
  required PlaybackPersistenceStore persistence,
  required PlaybackBookMetadataStore metadataStore,
  required PlaybackController playbackController,
}) async {
  try {
    final savedSession = await persistence.loadSession();
    final savedSourceId = savedSession?.activeSourceId;
    final savedVersionId = savedSession?.activeBookVersionId;
    if (savedSourceId == null || savedVersionId == null) {
      return;
    }

    final savedBook = await metadataStore.loadBook(
      sourceId: savedSourceId,
      versionId: savedVersionId,
    );
    if (savedBook == null) {
      return;
    }

    await playbackController.loadSavedSession(savedBook);
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
