import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';

const shutdownBook = AudioPlaybackBook(
  id: 'shutdown-book',
  versionId: 'shutdown-version',
  sourceId: 'test',
  title: 'Белые ночи',
  author: 'Фёдор Достоевский',
  narrator: 'Чтец',
  sourceName: 'Тестовый источник',
  chapters: [
    AudioPlaybackChapter(
      id: 'one',
      title: 'Первая ночь',
      index: 0,
      duration: Duration(minutes: 10),
    ),
  ],
);

void main() {
  test('paused progress listeners do not block native shutdown', () async {
    final engine = ShutdownTestEngine([]);
    final controller = PlaybackController(engine: engine);
    final subscription = controller.progressChanges.listen((_) {})..pause();
    await controller.shutdown().timeout(const Duration(seconds: 1));
    expect(engine.disposals, 1);
    await subscription.cancel();
    controller.dispose();
  });

  test('shutdown awaits checkpoint and native disposal exactly once', () async {
    final events = <String>[];
    final engine = ShutdownTestEngine(events);
    final persistence = ShutdownTestPersistence(events);
    final controller = PlaybackController(
      engine: engine,
      persistence: persistence,
    );
    await controller.loadBook(shutdownBook, autoPlay: true);
    await controller.seek(const Duration(seconds: 43));
    events.clear();
    persistence.saveGate = Completer<void>();
    engine.disposeGate = Completer<void>();
    final first = controller.shutdown();
    final second = controller.shutdown();
    expect(identical(first, second), isTrue);
    var done = false;
    unawaited(first.then((_) => done = true));
    await Future<void>.delayed(Duration.zero);
    expect(events, ['pause', 'save-start']);
    expect(engine.disposals, 0);
    expect(done, isFalse);
    await controller.play();
    await controller.seek(const Duration(seconds: 99));
    controller.setSleepTimer(const Duration(minutes: 1));
    await controller.tick(const Duration(seconds: 1));
    expect(controller.state.position, const Duration(seconds: 43));
    persistence.saveGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(events, [
      'pause',
      'save-start',
      'save-end',
      'progress',
      'dispose-start',
    ]);
    expect(persistence.session!.positionMs, 43000);
    expect(persistence.session!.isPlaying, isFalse);
    expect(done, isFalse);
    engine.disposeGate!.complete();
    await first;
    await controller.shutdown();
    controller.dispose();
    controller.dispose();
    expect(engine.disposals, 1);
    expect(events.last, 'dispose-end');
  });

  test(
    'shutdown drains an in-flight load without starting stale autoplay',
    () async {
      final events = <String>[];
      final engine = ShutdownTestEngine(events)..loadGate = Completer<void>();
      final controller = PlaybackController(engine: engine);
      final loading = controller.loadBook(shutdownBook, autoPlay: true);
      await Future<void>.delayed(Duration.zero);
      expect(events, ['load-start']);
      final closing = controller.shutdown();
      await Future<void>.delayed(Duration.zero);
      expect(engine.disposals, 0);
      engine.loadGate!.complete();
      await loading;
      await closing;
      expect(events, [
        'load-start',
        'load-end',
        'pause',
        'dispose-start',
        'dispose-end',
      ]);
      controller.dispose();
    },
  );

  test(
    'failed checkpoint remains quiesced and retries final state before teardown',
    () async {
      final events = <String>[];
      final engine = ShutdownTestEngine(events);
      final persistence = ShutdownTestPersistence(events);
      final controller = PlaybackController(
        engine: engine,
        persistence: persistence,
      );
      await controller.loadBook(shutdownBook, autoPlay: true);
      await controller.seek(const Duration(seconds: 43));
      await controller.setVolume(.2);
      await controller.setVolume(.8);
      persistence.failSave = true;
      await expectLater(controller.shutdown(), throwsStateError);
      expect(engine.disposals, 0);
      final eventsAfterFailure = events.toList();
      await controller.play();
      await controller.seek(const Duration(seconds: 99));
      await controller.setVolume(.1);
      await controller.loadBook(shutdownBook, autoPlay: true);
      expect(controller.state.isPlaying, isFalse);
      expect(controller.state.position, const Duration(seconds: 43));
      expect(controller.state.volume, .8);
      expect(events, eventsAfterFailure);
      await expectLater(controller.shutdown(), throwsStateError);
      expect(engine.disposals, 0);
      persistence.failSave = false;
      await controller.shutdown();
      expect(engine.disposals, 1);
      expect(persistence.session!.volume, .8);
      expect(persistence.session!.positionMs, 43000);
      expect(persistence.session!.isPlaying, isFalse);
      await controller.shutdown();
      controller.dispose();
      expect(engine.disposals, 1);
    },
  );

  test(
    'native disposal failure is not reported as a successful second shutdown',
    () async {
      final engine = ShutdownTestEngine([])..failDispose = true;
      final controller = PlaybackController(engine: engine);
      final closing = controller.shutdown();
      await expectLater(closing, throwsStateError);
      expect(identical(controller.shutdown(), closing), isTrue);
      await expectLater(controller.shutdown(), throwsStateError);
      expect(engine.disposals, 1);
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      controller.dispose();
      await Future<void>.delayed(Duration.zero);
      FlutterError.onError = previous;
      expect(errors, hasLength(1));
    },
  );

  test(
    'synchronous dispose retains best-effort cleanup after a save failure',
    () async {
      final events = <String>[];
      final engine = ShutdownTestEngine(events);
      final persistence = ShutdownTestPersistence(events);
      final controller = PlaybackController(
        engine: engine,
        persistence: persistence,
      );
      await controller.loadBook(shutdownBook);
      persistence.failSave = true;
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      controller.dispose();
      await controller.shutdown();
      FlutterError.onError = previous;
      expect(engine.disposals, 1);
      expect(errors, hasLength(1));
    },
  );
}

class ShutdownTestEngine extends InMemoryAudioEngine {
  ShutdownTestEngine(this.events);
  final List<String> events;
  final disposalStarted = Completer<void>();
  Completer<void>? loadGate;
  Completer<void>? disposeGate;
  bool failDispose = false;
  int disposals = 0;

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    events.add('load-start');
    await loadGate?.future;
    await super.load(chapter, position: position, book: book);
    events.add('load-end');
  }

  @override
  Future<void> pause() async {
    events.add('pause');
    await super.pause();
  }

  @override
  Future<void> play() async {
    events.add('play');
    await super.play();
  }

  @override
  Future<void> dispose() async {
    disposals++;
    events.add('dispose-start');
    if (!disposalStarted.isCompleted) disposalStarted.complete();
    await disposeGate?.future;
    await super.dispose();
    if (failDispose) throw StateError('native disposal failed');
    events.add('dispose-end');
  }
}

class ShutdownTestPersistence implements PlaybackPersistenceStore {
  ShutdownTestPersistence(this.events);
  final List<String> events;
  PlaybackSession? session;
  Completer<void>? saveGate;
  bool failSave = false;

  @override
  Future<PlaybackSession?> loadSession({String id = 'active'}) async => session;
  @override
  Future<List<PlaybackProgressSnapshot>> loadProgress() async => [];
  @override
  Future<void> saveSession(PlaybackSession value) async {
    events.add('save-start');
    await saveGate?.future;
    if (failSave) throw StateError('checkpoint failed');
    session = value;
    events.add('save-end');
  }

  @override
  Future<void> saveProgress(PlaybackProgressSnapshot progress) async {
    events.add('progress');
  }
}
