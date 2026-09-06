import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/android_media_session_engine.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/just_audio_engine.dart';
import 'package:slovofon/services/audio/playback_controller.dart';

import 'just_audio_engine_test.dart' show RecordingJustAudioPlayerAdapter;
import 'android_media_session_engine_test.dart' as android_fixture;

AudioPlaybackBook _book(String id) => AudioPlaybackBook(
  id: id,
  versionId: 'version-$id',
  sourceId: 'fixture',
  sourceBookId: id,
  title: id,
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Fixture',
  chapters: List.generate(
    2,
    (index) => AudioPlaybackChapter(
      id: '$id-$index',
      index: index,
      title: 'Chapter $index',
      duration: const Duration(minutes: 10),
      mediaSource: AudioMediaSource.asset('fixture-not-opened.mp3'),
    ),
  ),
);

void main() {
  test(
    'package adapter forwards just_audio 0.10 runtime error values',
    () async {
      final player = _RuntimeErrorPlayer();
      final adapter = PackageJustAudioPlayerAdapter(player: player);
      final snapshots = <JustAudioAdapterSnapshot>[];
      final subscription = adapter.playbackSnapshots.listen(snapshots.add);
      addTearDown(subscription.cancel);
      addTearDown(adapter.dispose);

      player.states.add(
        just_audio.PlayerState(true, just_audio.ProcessingState.ready),
      );
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.last.isPlaying, isTrue);

      // Native decoder/network failures are data on errorStream in 0.10.5.
      // A fake package player exercises the real adapter subscription; no native
      // engine or network is started by this contract test.
      player.errors.add(
        just_audio.PlayerException(500, 'Fixture stream failure', 0),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        snapshots.last.processingState,
        JustAudioAdapterProcessingState.error,
      );
      expect(snapshots.last.isPlaying, isFalse);
      expect(snapshots.last.errorMessage, 'Fixture stream failure');

      player.states.add(
        just_audio.PlayerState(false, just_audio.ProcessingState.ready),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        snapshots.last.processingState,
        JustAudioAdapterProcessingState.ready,
      );
      expect(snapshots.last.errorMessage, isNull);
      await adapter.dispose();
      expect(player.hadErrorListenerAtDispose, isFalse);
    },
  );

  test('a paused book load does not inherit backend playWhenReady', () async {
    final adapter = _PlayingStatePreservingAdapter();
    final controller = PlaybackController(
      engine: JustAudioEngine(player: adapter),
    );
    addTearDown(controller.dispose);
    await controller.loadBook(_book('a'), autoPlay: true);
    expect(adapter.playing, isTrue);
    await controller.loadBook(_book('b'));
    expect(controller.state.isPlaying, isFalse);
    expect(adapter.playing, isFalse);
    expect(adapter.playingAtLoad, [false, false]);
  });

  for (final play in [false, true]) {
    test(
      'bookmark load starts paused and resumes only when requested ($play)',
      () async {
        final adapter = _PlayingStatePreservingAdapter();
        final controller = PlaybackController(
          engine: JustAudioEngine(player: adapter),
        );
        addTearDown(controller.dispose);
        await controller.loadBook(_book('a'), autoPlay: true);
        await controller.seekChapterAt(
          1,
          const Duration(minutes: 3),
          play: play,
        );
        expect(adapter.playingAtLoad, [false, false]);
        expect(adapter.playing, play);
        expect(controller.state.isPlaying, play);
        expect(
          adapter.requests.last.initialPosition,
          const Duration(minutes: 3),
        );
      },
    );
  }

  test(
    'pause during a pending chapter load cannot leave old audio playing',
    () async {
      final adapter = _PlayingStatePreservingAdapter(gateSecondLoad: true);
      final controller = PlaybackController(
        engine: JustAudioEngine(player: adapter),
      );
      addTearDown(controller.dispose);
      await controller.loadBook(_book('a'), autoPlay: true);
      final navigation = controller.nextChapter();
      await adapter.secondLoadStarted.future;
      final pausing = controller.pause();
      // Capture before releasing the load; still clean up if the assertion fails.
      final wasPlayingDuringLoad = adapter.playing;
      adapter.secondLoadRelease.complete();
      await Future.wait([navigation, pausing]);
      expect(wasPlayingDuringLoad, isFalse);
      expect(adapter.playing, isFalse);
      expect(controller.state.isPlaying, isFalse);
    },
  );

  test('production platform factory has no simulator fallback', () {
    final source = File(
      'lib/services/audio/playback_controller_provider.dart',
    ).readAsStringSync();
    final factory = source.substring(
      source.indexOf('Future<AudioEngine> createPlatformAudioEngine'),
    );
    expect(factory, isNot(contains('InMemoryAudioEngine(')));
    expect(factory, isNot(contains('SwitchingAudioEngine(')));
    expect(factory, contains('final realEngine = JustAudioEngine()'));
    expect(factory, contains('delegate: realEngine'));
    expect(factory, contains('return realEngine;'));
  });

  test(
    'offline metadata-only restore stays recoverable until media retry succeeds',
    () async {
      final adapter = _PlayingStatePreservingAdapter();
      final playable = _book('a');
      final metadataOnly = playable.copyWith(
        chapters: [
          for (final chapter in playable.chapters)
            AudioPlaybackChapter(
              id: chapter.id,
              index: chapter.index,
              title: chapter.title,
              duration: chapter.duration,
            ),
        ],
      );
      var networkAvailable = false;
      var refreshes = 0;
      final controller = PlaybackController(
        engine: JustAudioEngine(player: adapter),
        playbackBookResolver: (book) async => book,
        playbackErrorBookResolver: (book) async {
          refreshes++;
          if (!networkAvailable) {
            throw const AudioEngineException('Source unavailable.');
          }
          return playable;
        },
      );
      addTearDown(controller.dispose);
      await controller.restoreSession(
        metadataOnly,
        PlaybackSession(
          id: 'active',
          activeBookId: playable.id,
          activeBookVersionId: playable.versionId,
          activeSourceId: playable.sourceId,
          activeChapterId: playable.chapters.first.id,
          positionMs: 42000,
          updatedAt: DateTime(2026),
        ),
      );
      expect(controller.state.status, AudioPlaybackStatus.error);
      expect(controller.state.position, const Duration(seconds: 42));
      expect(adapter.playing, isFalse);
      expect(adapter.playCount, 0);
      // Telemetry from the previously paused/empty decoder is not a successful
      // load of this chapter and must not overwrite its persisted position.
      adapter.emitPosition(Duration.zero);
      adapter._publishReady();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, AudioPlaybackStatus.error);
      expect(controller.state.position, const Duration(seconds: 42));
      await controller.play();
      expect(controller.state.status, AudioPlaybackStatus.error);
      expect(controller.state.position, const Duration(seconds: 42));
      expect(adapter.playing, isFalse);
      networkAvailable = true;
      await controller.play();
      expect(refreshes, 2);
      expect(controller.state.status, AudioPlaybackStatus.playing);
      expect(adapter.playing, isTrue);
      expect(
        adapter.requests.single.initialPosition,
        const Duration(seconds: 42),
      );
    },
  );

  test('missing media also pauses the previously playing source', () async {
    final adapter = _PlayingStatePreservingAdapter();
    final controller = PlaybackController(
      engine: JustAudioEngine(player: adapter),
    );
    addTearDown(controller.dispose);
    await controller.loadBook(_book('a'), autoPlay: true);
    await controller.loadBook(
      _book('b').copyWith(
        chapters: const [
          AudioPlaybackChapter(
            id: 'missing',
            index: 0,
            title: 'Missing media',
            duration: Duration(minutes: 1),
          ),
        ],
      ),
    );
    expect(controller.state.status, AudioPlaybackStatus.error);
    expect(adapter.playing, isFalse);
  });

  test('failed native updates are contained, redacted and retried', () async {
    final errors = <FlutterErrorDetails>[];
    final previousHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousHandler);
    final delegate = android_fixture.RecordingAudioEngine();
    final platform = _FailingMediaSessionPlatform()..failUpdates = true;
    final engine = AndroidMediaSessionEngine(
      delegate: delegate,
      platform: platform,
    );
    final book = _book('a');
    await engine.load(book.chapters.first, position: Duration.zero, book: book);
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    expect(
      errors.single.exception.toString(),
      isNot(contains('fixture-secret')),
    );
    platform.failUpdates = false;
    // Identical state must retry: the failed publication was not delivered.
    await engine.setSpeed(1);
    await Future<void>.delayed(Duration.zero);
    expect(platform.updateAttempts, 2);
    await engine.play();
    expect(delegate.playCount, 1);
    await engine.dispose();
  });

  test(
    'failed native clear never skips disposal of the actual audio backend',
    () async {
      final errors = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previousHandler);
      final delegate = android_fixture.RecordingAudioEngine();
      final platform = _FailingMediaSessionPlatform()..failClear = true;
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      await engine.dispose();
      expect(delegate.disposeCount, 1);
      expect(errors, hasLength(1));
      await engine.dispose();
      expect(delegate.disposeCount, 1);
    },
  );

  for (final restore in [false, true]) {
    test(
      'metadata write failure does not strand a loaded player (restore=$restore)',
      () async {
        final errors = <FlutterErrorDetails>[];
        final previousHandler = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = previousHandler);
        final adapter = _PlayingStatePreservingAdapter();
        final controller = PlaybackController(
          engine: JustAudioEngine(player: adapter),
          bookMetadataStore: _FailingMetadataStore(),
        );
        addTearDown(controller.dispose);
        final book = _book('a');
        if (restore) {
          await controller.restoreSession(
            book,
            PlaybackSession(
              id: 'active',
              activeBookId: book.id,
              activeBookVersionId: book.versionId,
              activeSourceId: book.sourceId,
              activeChapterId: book.chapters.first.id,
              positionMs: 42000,
              updatedAt: DateTime(2026),
            ),
          );
        } else {
          await controller.loadBook(book);
        }
        expect(controller.state.status, AudioPlaybackStatus.paused);
        expect(errors, hasLength(1));
        await controller.play();
        expect(controller.state.status, AudioPlaybackStatus.playing);
        expect(adapter.playing, isTrue);
        await controller.pause();
        expect(adapter.playing, isFalse);
      },
    );
  }
}

class _FailingMetadataStore implements PlaybackBookMetadataStore {
  @override
  Future<void> saveBook(AudioPlaybackBook book) async {
    throw const FileSystemException('Fixture metadata storage unavailable.');
  }

  @override
  Future<AudioPlaybackBook?> loadBook({
    required String sourceId,
    required String versionId,
  }) async => null;
}

class _RuntimeErrorPlayer extends Fake implements just_audio.AudioPlayer {
  final states = StreamController<just_audio.PlayerState>.broadcast();
  final errors = StreamController<just_audio.PlayerException>.broadcast();
  bool? hadErrorListenerAtDispose;

  @override
  Stream<just_audio.PlayerState> get playerStateStream => states.stream;

  @override
  Stream<just_audio.PlayerException> get errorStream => errors.stream;

  @override
  Stream<just_audio.PlaybackEvent> get playbackEventStream =>
      const Stream.empty();

  @override
  Future<void> dispose() async {
    hadErrorListenerAtDispose = errors.hasListener;
    await states.close();
    await errors.close();
  }
}

class _FailingMediaSessionPlatform
    extends android_fixture.RecordingAndroidMediaSessionPlatform {
  bool failUpdates = false;
  bool failClear = false;
  int updateAttempts = 0;
  @override
  Future<void> update(AndroidMediaSessionSnapshot snapshot) async {
    updateAttempts++;
    if (failUpdates) {
      throw PlatformException(code: 'fixture', details: 'fixture-secret');
    }
    await super.update(snapshot);
  }

  @override
  Future<void> clear() async {
    if (failClear) {
      throw PlatformException(code: 'fixture', details: 'fixture-secret');
    }
    await super.clear();
  }
}

/// Models just_audio's real setAudioSources behavior: changing the source does
/// not clear playWhenReady. This is an adapter contract test, not audible QA.
class _PlayingStatePreservingAdapter extends RecordingJustAudioPlayerAdapter {
  _PlayingStatePreservingAdapter({this.gateSecondLoad = false});
  final bool gateSecondLoad;
  bool playing = false;
  final playingAtLoad = <bool>[];
  final secondLoadStarted = Completer<void>();
  final secondLoadRelease = Completer<void>();
  final _stateSnapshots =
      StreamController<JustAudioAdapterSnapshot>.broadcast();

  @override
  Stream<JustAudioAdapterSnapshot> get playbackSnapshots =>
      _stateSnapshots.stream;

  void _publishReady() {
    _stateSnapshots.add(
      JustAudioAdapterSnapshot(
        processingState: JustAudioAdapterProcessingState.ready,
        isPlaying: playing,
      ),
    );
  }

  @override
  Future<void> load(AudioLoadRequest request) async {
    playingAtLoad.add(playing);
    await super.load(request);
    if (gateSecondLoad && requests.length == 2) {
      secondLoadStarted.complete();
      await secondLoadRelease.future;
    }
    _publishReady();
  }

  @override
  Future<void> play() async {
    playing = true;
    await super.play();
    _publishReady();
  }

  @override
  Future<void> pause() async {
    playing = false;
    await super.pause();
    _publishReady();
  }

  @override
  Future<void> dispose() async {
    await _stateSnapshots.close();
    await super.dispose();
  }
}
