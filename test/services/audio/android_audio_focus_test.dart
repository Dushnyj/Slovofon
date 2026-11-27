import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/android_audio_session_focus.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_focus.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/just_audio_engine.dart';
import 'package:slovofon/services/audio/playback_controller.dart';

import 'just_audio_engine_test.dart' show RecordingJustAudioPlayerAdapter;

void main() {
  test('Android uses media speech but distinguishes duck from a real loss', () {
    final configuration = AndroidAudioSessionFocus.configuration;
    expect(
      configuration.androidAudioAttributes?.usage,
      AndroidAudioUsage.media,
    );
    expect(
      configuration.androidAudioAttributes?.contentType,
      AndroidAudioContentType.speech,
    );
    expect(configuration.androidWillPauseWhenDucked, isFalse);
    expect(
      configuration.androidAudioFocusGainType,
      AndroidAudioFocusGainType.gain,
    );
    final map = AndroidAudioSessionFocus.mapInterruption;
    expect(
      map(AudioInterruptionEvent(true, AudioInterruptionType.duck)),
      AudioFocusEvent.canDuck,
    );
    expect(
      map(AudioInterruptionEvent(true, AudioInterruptionType.pause)),
      AudioFocusEvent.transientLoss,
    );
    expect(
      map(AudioInterruptionEvent(true, AudioInterruptionType.unknown)),
      AudioFocusEvent.loss,
    );
    expect(
      map(AudioInterruptionEvent(false, AudioInterruptionType.duck)),
      AudioFocusEvent.gain,
    );
  });

  test(
    'denial clears the cached request; transient loss does not fake gain',
    () async {
      final session = _TestAudioSession();
      final focus = AndroidAudioSessionFocus(session);
      final received = <AudioFocusEvent>[];
      final subscription = focus.audioFocusEvents.listen(received.add);
      addTearDown(() async {
        await subscription.cancel();
        await session.interruptions.close();
      });

      session.grant = false;
      expect(await focus.request(), isFalse);
      expect(session.activation, [true, false]);
      session.grant = true;
      expect(await focus.request(), isTrue);

      session.interruptions.add(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await _settle();
      expect(received.last, AudioFocusEvent.transientLoss);
      expect(await focus.request(), isFalse);
      expect(session.activation, [true, false, true]);

      session.interruptions.add(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      await _settle();
      expect(await focus.request(), isTrue);
      expect(session.activation, [true, false, true]);
    },
  );

  test('focus denial must not start the actual decoder', () async {
    final player = RecordingJustAudioPlayerAdapter();
    final session = _TestAudioSession()..grant = false;
    final engine = JustAudioEngine(
      player: player,
      audioFocus: AndroidAudioSessionFocus(session),
    );
    addTearDown(() async {
      await engine.dispose();
      await session.interruptions.close();
    });
    final states = <AudioEngineSnapshot>[];
    final subscription = engine.snapshots.listen(states.add);
    addTearDown(subscription.cancel);

    await expectLater(engine.play(), throwsA(isA<AudioEngineException>()));
    expect(player.playCount, 0);
    expect(states, isEmpty);
  });

  test(
    'manual pause invalidates a focus request awaiting native grant',
    () async {
      final player = RecordingJustAudioPlayerAdapter();
      final session = _TestAudioSession();
      final grant = session.pendingGrant = Completer<bool>();
      final engine = JustAudioEngine(
        player: player,
        audioFocus: AndroidAudioSessionFocus(session),
      );
      addTearDown(() async {
        if (!grant.isCompleted) grant.complete(false);
        await engine.dispose();
        await session.interruptions.close();
      });

      final starting = engine.play();
      await engine.pause();
      grant.complete(true);
      await starting;
      expect(player.playCount, 0);
      expect(player.pauseCount, 1);
    },
  );

  test(
    'notification duck preserves media position, intent and volume',
    () async {
      final (controller, engine) = _controllerFixture();
      const position = Duration(seconds: 12);
      await controller.loadBook(
        _book('first'),
        position: position,
        autoPlay: true,
      );
      await controller.setVolume(0.35);
      await _settle();

      engine.emit(AudioFocusEvent.canDuck);
      engine.emit(AudioFocusEvent.gain);
      await _settle();

      expect(engine.playCount, 1);
      expect(engine.pauseCount, 0);
      expect(controller.state.isPlaying, isTrue);
      expect(controller.state.position, position);
      expect(engine.position, position);
      expect(engine.volume, 0.35);
      expect(controller.state.volume, 0.35);
    },
  );

  test(
    'gain waits for actual pause and duplicate gains resume only once',
    () async {
      final (controller, engine) = _controllerFixture();
      await controller.loadBook(_book('first'), autoPlay: true);
      final pauseGate = engine.pauseGate = Completer<void>();
      engine.emit(AudioFocusEvent.transientLoss);
      engine.emit(AudioFocusEvent.transientLoss);
      engine.emit(AudioFocusEvent.gain);
      engine.emit(AudioFocusEvent.gain);
      await _settle();
      final callsBeforePauseFinished = engine.playCount;
      pauseGate.complete();
      await _settle();

      expect(callsBeforePauseFinished, 1);
      expect(engine.pauseCount, 1);
      expect(engine.playCount, 2);
      expect(controller.state.isPlaying, isTrue);
    },
  );

  test('a second loss while authorizing resume requires a new gain', () async {
    final authorizationStarted = Completer<void>();
    final authorizeResume = Completer<void>();
    var holdAuthorization = false;
    var resolverCalls = 0;
    final (controller, engine) = _controllerFixture(
      playbackAccessGuard: (_, _) async {
        if (holdAuthorization && !authorizationStarted.isCompleted) {
          authorizationStarted.complete();
          await authorizeResume.future;
        }
      },
      playbackBookResolver: (book) async {
        resolverCalls++;
        return book;
      },
    );
    addTearDown(() {
      if (!authorizeResume.isCompleted) authorizeResume.complete();
    });
    const position = Duration(seconds: 24);
    await controller.loadBook(
      _book('first'),
      position: position,
      autoPlay: true,
    );
    await _settle();
    holdAuthorization = true;

    engine.emit(AudioFocusEvent.transientLoss);
    engine.emit(AudioFocusEvent.gain);
    await authorizationStarted.future;
    engine.emit(AudioFocusEvent.transientLoss);
    authorizeResume.complete();
    await _settle();
    expect(engine.playCount, 1);
    expect(controller.state.status, AudioPlaybackStatus.paused);

    engine.emit(AudioFocusEvent.gain);
    await _settle();
    expect(engine.playCount, 2);
    expect(engine.pauseCount, 1);
    expect(resolverCalls, 0);
    expect(controller.state.isPlaying, isTrue);
    expect(controller.state.position, position);
  });

  test(
    'user pause or switching book invalidates pending automatic resume',
    () async {
      final (controller, engine) = _controllerFixture();
      await controller.loadBook(_book('first'), autoPlay: true);
      engine.emit(AudioFocusEvent.transientLoss);
      await _settle();
      await controller.pause();
      engine.emit(AudioFocusEvent.gain);
      await _settle();
      expect(engine.playCount, 1);
      expect(controller.state.isPlaying, isFalse);

      await controller.play();
      await _settle();
      engine.emit(AudioFocusEvent.transientLoss);
      await _settle();
      await controller.loadBook(_book('second'));
      engine.emit(AudioFocusEvent.gain);
      await _settle();
      expect(engine.playCount, 2);
      expect(controller.state.book?.id, 'second');
      expect(controller.state.isPlaying, isFalse);
    },
  );

  for (final event in [AudioFocusEvent.loss, AudioFocusEvent.becomingNoisy]) {
    test(
      '$event never resumes after gain, including cold/paused playback',
      () async {
        final (controller, engine) = _controllerFixture();
        await controller.loadBook(_book('first'));
        engine.emit(AudioFocusEvent.gain);
        await _settle();
        expect(engine.playCount, 0);

        await controller.play();
        await _settle();
        engine.emit(AudioFocusEvent.transientLoss);
        engine.emit(event);
        engine.emit(AudioFocusEvent.gain);
        await _settle();
        expect(engine.playCount, 1);
        expect(controller.state.isPlaying, isFalse);
      },
    );
  }
}

(PlaybackController, _FocusRecordingEngine) _controllerFixture({
  PlaybackAccessGuard? playbackAccessGuard,
  PlaybackBookResolver? playbackBookResolver,
}) {
  final engine = _FocusRecordingEngine();
  final controller = PlaybackController(
    engine: engine,
    playbackAccessGuard: playbackAccessGuard,
    playbackBookResolver: playbackBookResolver,
  );
  addTearDown(() async {
    final gate = engine.pauseGate;
    if (gate != null && !gate.isCompleted) gate.complete();
    await controller.shutdown();
    controller.dispose();
    await engine.focus.close();
  });
  return (controller, engine);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

AudioPlaybackBook _book(String id) => AudioPlaybackBook(
  id: id,
  versionId: '$id-version',
  sourceId: 'test',
  sourceName: 'Test',
  title: id,
  author: 'Test author',
  narrator: 'Test narrator',
  chapters: const [
    AudioPlaybackChapter(
      id: 'chapter',
      index: 0,
      title: 'Chapter',
      duration: Duration(minutes: 4),
    ),
  ],
);

class _FocusRecordingEngine extends InMemoryAudioEngine
    implements AudioInterruptionSource {
  final focus = StreamController<AudioFocusEvent>.broadcast(sync: true);
  int playCount = 0;
  int pauseCount = 0;
  Completer<void>? pauseGate;

  @override
  Stream<AudioFocusEvent> get audioFocusEvents => focus.stream;

  void emit(AudioFocusEvent event) => focus.add(event);

  @override
  Future<void> play() {
    playCount++;
    return super.play();
  }

  @override
  Future<void> pause() async {
    pauseCount++;
    await pauseGate?.future;
    await super.pause();
  }
}

class _TestAudioSession extends Fake implements AudioSession {
  final interruptions = StreamController<AudioInterruptionEvent>.broadcast();
  final activation = <bool>[];
  bool grant = true;
  Completer<bool>? pendingGrant;

  @override
  Stream<AudioInterruptionEvent> get interruptionEventStream =>
      interruptions.stream;

  @override
  Stream<void> get becomingNoisyEventStream => const Stream.empty();

  @override
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? avAudioSessionSetActiveOptions,
    AndroidAudioFocusGainType? androidAudioFocusGainType,
    AndroidAudioAttributes? androidAudioAttributes,
    bool? androidWillPauseWhenDucked,
    AudioSessionConfiguration fallbackConfiguration =
        const AudioSessionConfiguration.music(),
  }) async {
    activation.add(active);
    if (!active) return true;
    return await pendingGrant?.future ?? grant;
  }
}
