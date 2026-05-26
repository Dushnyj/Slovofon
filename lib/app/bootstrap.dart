import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/database/database_connection.dart';
import '../services/audio/audio_persistence.dart';
import '../services/audio/playback_controller_provider.dart';
import '../services/downloads/download_manager_provider.dart';
import '../services/downloads/download_persistence.dart';
import '../services/downloads/download_storage.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioEngine = await createPlatformAudioEngine();
  final appDatabase = AppDatabase(openAppDatabaseConnection());
  final downloadStorage = await FileDownloadStorage.create();
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
          ref.onDispose(() => unawaited(audioEngine.dispose()));
          return audioEngine;
        }),
        playbackPersistenceStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(closeDatabase()));
          return DriftPlaybackPersistenceStore(appDatabase);
        }),
        downloadStorageProvider.overrideWith((ref) => downloadStorage),
        downloadPersistenceStoreProvider.overrideWith((ref) {
          return DriftDownloadPersistenceStore(appDatabase);
        }),
      ],
      child: const SlovofonApp(),
    ),
  );
}
