import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/database/database_connection.dart';
import '../services/audio/audio_persistence.dart';
import '../services/audio/playback_controller_provider.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioEngine = await createPlatformAudioEngine();
  final appDatabase = AppDatabase(openAppDatabaseConnection());

  runApp(
    ProviderScope(
      overrides: [
        audioEngineProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(audioEngine.dispose()));
          return audioEngine;
        }),
        playbackPersistenceStoreProvider.overrideWith((ref) {
          ref.onDispose(() => unawaited(appDatabase.close()));
          return DriftPlaybackPersistenceStore(appDatabase);
        }),
      ],
      child: const SlovofonApp(),
    ),
  );
}
