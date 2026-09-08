import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';

const _book = AudioPlaybackBook(
  id: 'volume-book',
  versionId: 'volume-version',
  sourceId: 'test',
  title: 'Book',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Test',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter',
      index: 0,
      title: 'Chapter',
      duration: Duration(minutes: 10),
    ),
  ],
);

void main() {
  test(
    '60 simultaneous volume updates coalesce without rewriting progress',
    () async {
      final engine = _Engine();
      final store = _Persistence();
      final controller = PlaybackController(engine: engine, persistence: store);
      await controller.loadBook(_book);
      engine.volumes.clear();
      store.clear();
      var revisions = 0;
      final sub = controller.progressChanges.listen((_) => revisions++);
      await Future.wait([
        for (var i = 0; i < 60; i++) controller.setVolume(i / 60),
      ]);
      await controller.flushVolume(requireSuccess: true);
      expect(engine.volumes, [59 / 60]);
      expect(controller.state.volume, 59 / 60);
      expect(store.sessions.length, lessThanOrEqualTo(2));
      expect(store.sessions.last.volume, 59 / 60);
      expect(store.progressWrites, 0);
      expect(revisions, 0);
      await sub.cancel();
      await controller.shutdown();
      controller.dispose();
    },
  );

  test(
    'separate live volume events save leading and trailing session only',
    () async {
      final store = _Persistence();
      final controller = PlaybackController(
        engine: _Engine(),
        persistence: store,
      );
      await controller.loadBook(_book);
      store.clear();
      await controller.setVolume(.2);
      await controller.setVolume(.4);
      await controller.setVolume(.6);
      expect(store.sessions, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(store.sessions, hasLength(2));
      expect(store.sessions.last.volume, .6);
      expect(store.progressWrites, 0);
      await controller.shutdown();
      controller.dispose();
    },
  );

  test('mute remembers final nonzero volume through coalesced burst', () async {
    final engine = _Engine();
    final controller = PlaybackController(engine: engine);
    final values = [
      controller.setVolume(.2),
      controller.setVolume(.65),
      controller.toggleMute(),
    ];
    await Future.wait(values);
    expect(controller.state.volume, 0);
    expect(controller.state.lastNonMutedVolume, .65);
    expect(engine.volumes, [0]);
    await controller.toggleMute();
    expect(engine.volumes.last, .65);
    await controller.shutdown();
    controller.dispose();
  });

  for (final seek in [false, true]) {
    test(
      'latest volume survives in-flight engine call and ${seek ? 'seek' : 'pause'}',
      () async {
        final engine = _Engine();
        final store = _Persistence();
        final controller = PlaybackController(
          engine: engine,
          persistence: store,
        );
        await controller.loadBook(_book, autoPlay: true);
        engine.volumes.clear();
        engine.volumeGate = Completer<void>();
        final first = controller.setVolume(.2);
        await _turn();
        expect(engine.volumes, [.2]);
        final updates = [
          for (var i = 3; i <= 8; i++) controller.setVolume(i / 10),
        ];
        final transport = seek
            ? controller.seek(const Duration(seconds: 43))
            : controller.pause();
        engine.volumeGate!.complete();
        await Future.wait([first, ...updates, transport]);
        await controller.flushVolume(requireSuccess: true);
        expect(engine.volumes, [.2, .8]);
        expect(engine.volume, .8);
        expect(controller.state.volume, .8);
        expect(store.sessions.last.volume, .8);
        if (seek) {
          expect(controller.state.position, const Duration(seconds: 43));
          expect(controller.state.isPlaying, isTrue);
        } else {
          expect(controller.state.isPlaying, isFalse);
        }
        await controller.shutdown();
        controller.dispose();
      },
    );
  }

  test('slow session save does not hold up latest native volume', () async {
    final engine = _Engine();
    final store = _Persistence();
    final controller = PlaybackController(engine: engine, persistence: store);
    await controller.loadBook(_book);
    store.gate = Completer<void>();
    final first = controller.setVolume(.2);
    await _turn();
    final last = controller.setVolume(.8);
    await _turn();
    expect(engine.volume, .8);
    store.gate!.complete();
    await Future.wait([first, last]);
    await controller.flushVolume(requireSuccess: true);
    expect(store.sessions.last.volume, .8);
    await controller.shutdown();
    controller.dispose();
  });

  test(
    'volume storage failures remain retryable and required flush reports them',
    () async {
      final store = _Persistence();
      final controller = PlaybackController(
        engine: _Engine(),
        persistence: store,
      );
      await controller.loadBook(_book);
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        store.fail = true;
        await controller.setVolume(.7);
        expect(errors, hasLength(1));
        await expectLater(
          controller.flushVolume(requireSuccess: true),
          throwsStateError,
        );
        expect(errors, hasLength(1));
        store.fail = false;
        await controller.flushVolume(requireSuccess: true);
        expect(store.sessions.last.volume, .7);
        await controller.shutdown();
        controller.dispose();
      } finally {
        FlutterError.onError = previous;
      }
    },
  );

  test(
    'failed forced checkpoint preserves the final volume for a required retry',
    () async {
      final store = _Persistence();
      final controller = PlaybackController(
        engine: _Engine(),
        persistence: store,
      );
      await controller.loadBook(_book, autoPlay: true);
      await controller.setVolume(.2);
      await controller.setVolume(.8);
      expect(store.sessions.last.volume, .2);
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        store.fail = true;
        await controller.pause();
        expect(controller.state.volume, .8);
        expect(errors, hasLength(1));
        await expectLater(
          controller.flushVolume(requireSuccess: true),
          throwsStateError,
        );
        expect(errors, hasLength(1));
        store.fail = false;
        await controller.flushVolume(requireSuccess: true);
        expect(store.sessions.last.volume, .8);
        expect(store.sessions.last.isPlaying, isFalse);
        await controller.shutdown();
        controller.dispose();
      } finally {
        FlutterError.onError = previous;
      }
    },
  );

  test(
    'old checkpoint cannot overwrite later volume and seek session',
    () async {
      final store = _Persistence();
      final controller = PlaybackController(
        engine: _Engine(),
        persistence: store,
      );
      await controller.loadBook(_book, autoPlay: true);
      store.clear();
      store.gate = Completer<void>();
      final oldCheckpoint = controller.flushPlayback(requireSuccess: true);
      await _turn();
      final volume = controller.setVolume(.8);
      final seek = controller.seek(const Duration(seconds: 43));
      await _turn();
      expect(controller.state.position, const Duration(seconds: 43));
      store.gate!.complete();
      await Future.wait([oldCheckpoint, volume, seek]);
      await controller.flushVolume(requireSuccess: true);
      expect(store.sessions.last.positionMs, 43000);
      expect(store.sessions.last.volume, .8);
      expect(store.sessions.last.activeBookVersionId, _book.versionId);
      expect(store.sessions.last.isPlaying, isTrue);
      await controller.shutdown();
      controller.dispose();
    },
  );

  test(
    'shutdown requested by volume listener prevents new native work',
    () async {
      final engine = _Engine();
      final store = _Persistence();
      final controller = PlaybackController(engine: engine, persistence: store);
      await controller.loadBook(_book);
      engine.volumes.clear();
      Future<void>? closing;
      void closeWhenVolumeChanges() {
        if (controller.state.volume == .8 && closing == null) {
          controller.removeListener(closeWhenVolumeChanges);
          closing = controller.shutdown();
        }
      }

      controller.addListener(closeWhenVolumeChanges);
      await controller.setVolume(.8);
      await closing;
      expect(engine.volumes, isEmpty);
      expect(engine.disposals, 1);
      expect(store.sessions.last.volume, .8);
      controller.dispose();
    },
  );

  test(
    'shutdown persists final volume with pending native update exactly once',
    () async {
      final engine = _Engine();
      final store = _Persistence();
      final controller = PlaybackController(engine: engine, persistence: store);
      await controller.loadBook(_book);
      engine.volumeGate = Completer<void>();
      final first = controller.setVolume(.2);
      await _turn();
      final last = controller.setVolume(.8);
      final closing = controller.shutdown();
      await controller.setVolume(.1);
      engine.volumeGate!.complete();
      await Future.wait([first, last, closing]);
      expect(store.sessions.last.volume, .8);
      expect(store.sessions.last.isPlaying, isFalse);
      expect(engine.disposals, 1);
      expect(engine.calledAfterDispose, isFalse);
      await controller.shutdown();
      controller.dispose();
    },
  );

  test(
    'autoplay starts while metadata is pending; shutdown still drains it',
    () async {
      final metadata = _Metadata()..gate = Completer<void>();
      final engine = _Engine();
      final controller = PlaybackController(
        engine: engine,
        bookMetadataStore: metadata,
      );
      await controller.loadBook(_book, autoPlay: true);
      expect(metadata.completed, isEmpty);
      expect(engine.isPlaying, isTrue);
      var closed = false;
      final closing = controller.shutdown().then((_) => closed = true);
      await _turn();
      expect(closed, isFalse);
      expect(engine.disposals, 0);
      metadata.gate!.complete();
      await closing;
      expect(metadata.completed, [_book]);
      expect(engine.disposals, 1);
      controller.dispose();
    },
  );

  test(
    'background metadata writes remain ordered when book is refreshed',
    () async {
      final metadata = _Metadata()..gate = Completer<void>();
      final engine = _Engine();
      final controller = PlaybackController(
        engine: engine,
        bookMetadataStore: metadata,
      );
      final revised = _book.copyWith(
        chapters: [
          _book.chapters.single.copyWith(duration: const Duration(minutes: 12)),
        ],
      );
      await controller.loadBook(_book, autoPlay: true);
      await controller.loadBook(revised, autoPlay: true);
      expect(engine.isPlaying, isTrue);
      expect(metadata.started, [_book]);
      metadata.gate!.complete();
      await controller.flushPlayback(requireSuccess: true);
      expect(metadata.completed, [_book, revised]);
      expect(controller.state.book, same(revised));
      await controller.shutdown();
      controller.dispose();
    },
  );

  test(
    'dispose drains pending metadata without late autoplay or double disposal',
    () async {
      final metadata = _Metadata()..gate = Completer<void>();
      final engine = _Engine();
      final controller = PlaybackController(
        engine: engine,
        bookMetadataStore: metadata,
      );
      await controller.loadBook(_book);
      controller.dispose();
      final closing = controller.shutdown();
      expect(engine.disposals, 0);
      metadata.gate!.complete();
      await closing;
      expect(engine.isPlaying, isFalse);
      expect(engine.disposals, 1);
      expect(engine.calledAfterDispose, isFalse);
      controller.dispose();
    },
  );
}

Future<void> _turn() => Future<void>.delayed(Duration.zero);

class _Engine extends InMemoryAudioEngine {
  final volumes = <double>[];
  Completer<void>? volumeGate;
  int disposals = 0;
  bool calledAfterDispose = false;
  @override
  Future<void> setVolume(double value) async {
    calledAfterDispose |= disposals > 0;
    volumes.add(value);
    await volumeGate?.future;
    await super.setVolume(value);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await super.dispose();
  }
}

class _Persistence implements PlaybackPersistenceStore {
  final sessions = <PlaybackSession>[];
  int progressWrites = 0;
  bool fail = false;
  Completer<void>? gate;
  void clear() {
    sessions.clear();
    progressWrites = 0;
  }

  @override
  Future<PlaybackSession?> loadSession({String id = 'active'}) async =>
      sessions.lastOrNull;
  @override
  Future<List<PlaybackProgressSnapshot>> loadProgress() async => [];
  @override
  Future<void> saveSession(PlaybackSession session) async {
    await gate?.future;
    if (fail) throw StateError('fixture save failed');
    sessions.add(session);
  }

  @override
  Future<void> saveProgress(PlaybackProgressSnapshot progress) async {
    progressWrites++;
  }
}

class _Metadata implements PlaybackBookMetadataStore {
  final started = <AudioPlaybackBook>[];
  final completed = <AudioPlaybackBook>[];
  Completer<void>? gate;
  @override
  Future<void> saveBook(AudioPlaybackBook book) async {
    started.add(book);
    await gate?.future;
    completed.add(book);
  }

  @override
  Future<AudioPlaybackBook?> loadBook({
    required String sourceId,
    required String versionId,
  }) async => completed.lastOrNull;
}
