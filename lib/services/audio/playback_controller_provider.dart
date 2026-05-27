import 'dart:async';

import 'package:audio_service/audio_service.dart' as background_audio;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_persistence.dart';
import 'audio_engine.dart';
import 'just_audio_engine.dart';
import 'playback_controller.dart';
import 'slovofon_audio_handler.dart';

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

final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final service = PlaybackController(
    engine: ref.watch(audioEngineProvider),
    persistence: ref.watch(playbackPersistenceStoreProvider),
  );

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
    final handler = SlovofonAudioHandler(engine: realEngine);
    await background_audio.AudioService.init(
      builder: () => handler,
      config: const background_audio.AudioServiceConfig(
        androidNotificationChannelId: 'com.slovofon.app.playback',
        androidNotificationChannelName: 'Slovofon playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );

    return SwitchingAudioEngine(
      primary: AudioHandlerEngine(handler),
      fallback: fallbackEngine,
    );
  }

  return SwitchingAudioEngine(primary: realEngine, fallback: fallbackEngine);
}

Future<void> configureAudiobookAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.speech());
}
