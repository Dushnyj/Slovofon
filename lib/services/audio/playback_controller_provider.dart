import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'android_media_session_engine.dart';
import 'audio_persistence.dart';
import 'audio_engine.dart';
import 'just_audio_engine.dart';
import 'playback_controller.dart';
import '../downloads/download_manager_provider.dart';
import '../sources/source_catalog_provider.dart';

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = InMemoryAudioEngine();
  ref.onDispose(() => unawaited(engine.dispose()));
  return engine;
});

final playbackPersistenceStoreProvider = Provider<PlaybackPersistenceStore?>((
  ref,
) {
  return null;
});

final playbackProgressSnapshotsProvider =
    FutureProvider<List<PlaybackProgressSnapshot>>((ref) async {
      ref.watch(_playbackProgressRevisionProvider);
      final store = ref.watch(playbackPersistenceStoreProvider);
      return store?.loadProgress() ?? const <PlaybackProgressSnapshot>[];
    });

final _playbackProgressRevisionProvider = StreamProvider<int>((ref) async* {
  final controller = ref.watch(playbackControllerProvider);
  yield controller.progressRevision;
  yield* controller.progressChanges;
});

final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final service = PlaybackController(
    engine: ref.watch(audioEngineProvider),
    persistence: ref.watch(playbackPersistenceStoreProvider),
    bookMetadataStore: ref.watch(downloadStorageProvider),
    playbackBookResolver: (book) {
      return ref.read(downloadStorageProvider).offlinePlaybackBook(book);
    },
    playbackErrorBookResolver: (book) async {
      final refreshed = await ref
          .read(sourceCatalogServiceProvider)
          .refreshBookForPlayback(book);
      return ref.read(downloadStorageProvider).offlinePlaybackBook(refreshed);
    },
  );
  final sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
    if (service.state.isPlaying && service.state.sleepTimerRemaining != null) {
      unawaited(service.tick(const Duration(seconds: 1)));
    }
  });

  ref.onDispose(sleepTimerTicker.cancel);
  ref.onDispose(service.dispose);
  return service;
});

Future<AudioEngine> createPlatformAudioEngine({
  TargetPlatform? platform,
}) async {
  final effectivePlatform = platform ?? defaultTargetPlatform;
  if (effectivePlatform == TargetPlatform.android ||
      effectivePlatform == TargetPlatform.iOS ||
      effectivePlatform == TargetPlatform.macOS) {
    await configureAudiobookAudioSession();
  }

  final realEngine = JustAudioEngine();
  final fallbackEngine = InMemoryAudioEngine();

  if (effectivePlatform == TargetPlatform.android) {
    return SwitchingAudioEngine(
      primary: AndroidMediaSessionEngine(
        delegate: realEngine,
        platform: MethodChannelAndroidMediaSessionPlatform(),
      ),
      fallback: fallbackEngine,
    );
  }

  return SwitchingAudioEngine(primary: realEngine, fallback: fallbackEngine);
}

Future<void> configureAudiobookAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.speech());
}
