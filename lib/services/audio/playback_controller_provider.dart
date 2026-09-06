import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'android_media_session_engine.dart';
import 'audio_persistence.dart';
import 'audio_engine.dart';
import 'audio_state.dart';
import 'just_audio_engine.dart';
import 'playback_controller.dart';
import '../downloads/download_manager_provider.dart';
import '../sources/source_catalog_provider.dart';
import '../sources/source_access_policy.dart';
import '../sources/source_access_policy_provider.dart';

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
  final accessPolicy = ref.watch(sourceAccessPolicyProvider);
  final service = PlaybackController(
    engine: ref.watch(audioEngineProvider),
    persistence: ref.watch(playbackPersistenceStoreProvider),
    bookMetadataStore: ref.watch(downloadStorageProvider),
    playbackAccessGuard: (book, chapter) =>
        ensurePlaybackAllowedByPolicy(accessPolicy, book, chapter),
    playbackBookResolver: (book) {
      return ref.read(downloadStorageProvider).offlinePlaybackBook(book);
    },
    playbackErrorBookResolver: (book) async {
      await ensureRemotePlaybackAllowedByPolicy(accessPolicy, book.sourceId);
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

/// Translate policy codes at the composition boundary, keeping the controller
/// independent of source preferences and preserving localized error handling.
Future<void> ensurePlaybackAllowedByPolicy(
  SourceAccessPolicy policy,
  AudioPlaybackBook book,
  AudioPlaybackChapter chapter,
) async {
  try {
    await policy.ensurePlaybackAllowed(book, chapter);
  } on SourceAccessDeniedException catch (error) {
    throw AudioEngineException(error.code, cause: error);
  }
}

Future<void> ensureRemotePlaybackAllowedByPolicy(
  SourceAccessPolicy policy,
  String sourceId,
) async {
  try {
    await policy.ensureRemoteAllowed(sourceId, SourceAccessOperation.streaming);
  } on SourceAccessDeniedException catch (error) {
    throw AudioEngineException(error.code, cause: error);
  }
}

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

  if (effectivePlatform == TargetPlatform.android) {
    return AndroidMediaSessionEngine(
      delegate: realEngine,
      platform: MethodChannelAndroidMediaSessionPlatform(),
    );
  }

  // Missing cached media must fail recoverably, not select a silent simulator.
  // Mock/story/test entry points explicitly override audioEngineProvider.
  return realEngine;
}

Future<void> configureAudiobookAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.speech());
}
