import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';

void main() {
  group('PlaybackController', () {
    test('loads a book and controls engine playback', () async {
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.loadBook(_book, autoPlay: true);

      expect(service.state.status, AudioPlaybackStatus.playing);
      expect(service.state.currentChapter?.id, 'chapter-1');
      expect(engine.loadedChapterIds, ['chapter-1']);
      expect(engine.playCount, 1);

      await service.pause();

      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(engine.pauseCount, 1);

      await service.play();

      expect(service.state.status, AudioPlaybackStatus.playing);
      expect(engine.playCount, 2);
    });

    test(
      'seeks, advances time, and calculates chapter and book progress',
      () async {
        final engine = RecordingAudioEngine();
        final service = PlaybackController(engine: engine);

        await service.loadBook(_book);
        await service.seek(const Duration(minutes: 5));

        expect(service.state.position, const Duration(minutes: 5));
        expect(service.state.chapterProgress, closeTo(0.5, 0.001));
        expect(service.state.bookProgress, closeTo(0.166, 0.01));
        expect(engine.seekPositions, [const Duration(minutes: 5)]);

        await service.play();
        await service.tick(const Duration(minutes: 6));

        expect(service.state.currentChapter?.id, 'chapter-2');
        expect(service.state.position, const Duration(minutes: 1));
        expect(service.state.bookProgress, closeTo(0.366, 0.01));
      },
    );

    test('moves between chapters and restores saved session', () async {
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.loadBook(_book);
      await service.nextChapter();

      expect(service.state.currentChapter?.id, 'chapter-2');
      expect(engine.loadedChapterIds, ['chapter-1', 'chapter-2']);

      await service.previousChapter();

      expect(service.state.currentChapter?.id, 'chapter-1');

      await service.restoreSession(
        _book,
        PlaybackSession(
          id: 'session',
          activeBookId: _book.id,
          activeBookVersionId: _book.versionId,
          activeSourceId: _book.sourceId,
          activeChapterId: 'chapter-3',
          positionMs: const Duration(minutes: 2).inMilliseconds,
          speed: 1.25,
          isPlaying: false,
          updatedAt: DateTime.utc(2026, 5, 26),
        ),
      );

      expect(service.state.currentChapter?.id, 'chapter-3');
      expect(service.state.position, const Duration(minutes: 2));
      expect(service.state.speed, 1.25);
      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(engine.speedValues.last, 1.25);
    });

    test('sleep timer pauses playback when remaining time expires', () async {
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.loadBook(_book, autoPlay: true);
      service.setSleepTimer(const Duration(minutes: 5));

      expect(service.state.sleepTimerRemaining, const Duration(minutes: 5));

      await service.tick(const Duration(minutes: 3));

      expect(service.state.status, AudioPlaybackStatus.playing);
      expect(service.state.sleepTimerRemaining, const Duration(minutes: 2));

      await service.tick(const Duration(minutes: 2));

      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(service.state.sleepTimerRemaining, Duration.zero);
      expect(engine.pauseCount, 1);
    });

    test('keeps a recoverable error state when engine fails to load', () async {
      final service = PlaybackController(
        engine: const FailingAudioEngine(
          AudioEngineException('Media source is unavailable.'),
        ),
      );

      await service.loadBook(_book);

      expect(service.state.status, AudioPlaybackStatus.error);
      expect(service.state.errorMessage, 'Media source is unavailable.');
      expect(service.state.currentChapter?.id, 'chapter-1');
    });

    test(
      'follows runtime position and playback state from the engine',
      () async {
        final engine = StreamingAudioEngine();
        final service = PlaybackController(engine: engine);

        await service.loadBook(_book);
        engine.emit(
          const AudioEngineSnapshot(
            position: Duration(minutes: 4),
            processingState: AudioEngineProcessingState.ready,
            isPlaying: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.position, const Duration(minutes: 4));
        expect(service.state.status, AudioPlaybackStatus.playing);

        engine.emit(
          const AudioEngineSnapshot(
            position: Duration(minutes: 4, seconds: 10),
            processingState: AudioEngineProcessingState.buffering,
            isPlaying: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.position, const Duration(minutes: 4, seconds: 10));
        expect(service.state.status, AudioPlaybackStatus.buffering);

        engine.emit(
          const AudioEngineSnapshot(
            position: Duration(minutes: 4, seconds: 10),
            processingState: AudioEngineProcessingState.error,
            isPlaying: false,
            errorMessage: 'Decoder failed.',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.status, AudioPlaybackStatus.error);
        expect(service.state.errorMessage, 'Decoder failed.');
      },
    );

    test(
      'moves to the next chapter when the engine completes a chapter',
      () async {
        final engine = StreamingAudioEngine();
        final service = PlaybackController(engine: engine);

        await service.loadBook(_book, autoPlay: true);
        engine.emit(
          const AudioEngineSnapshot(
            position: Duration(minutes: 10),
            processingState: AudioEngineProcessingState.completed,
            isPlaying: false,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.currentChapter?.id, 'chapter-2');
        expect(service.state.position, Duration.zero);
        expect(engine.loadedChapterIds, ['chapter-1', 'chapter-2']);
      },
    );

    test('persists session and progress after position changes', () async {
      final store = RecordingPlaybackPersistenceStore();
      final service = PlaybackController(
        engine: RecordingAudioEngine(),
        persistence: store,
        clock: () => DateTime.utc(2026, 5, 26, 10),
        persistenceInterval: Duration.zero,
      );

      await service.loadBook(_book, autoPlay: true);
      await service.seek(const Duration(minutes: 5));

      expect(store.savedSessions, isNotEmpty);
      expect(store.savedSessions.last.activeBookId, _book.id);
      expect(store.savedSessions.last.activeChapterId, 'chapter-1');
      expect(
        store.savedSessions.last.positionMs,
        const Duration(minutes: 5).inMilliseconds,
      );
      expect(store.savedSessions.last.isPlaying, isTrue);
      expect(store.savedProgress, isNotEmpty);
      expect(store.savedProgress.last.percent, closeTo(16.66, 0.1));
      expect(
        store.savedProgress.last.maxReachedGlobalPositionMs,
        const Duration(minutes: 5).inMilliseconds,
      );
    });

    test('loads a saved session without auto-starting playback', () async {
      final store = RecordingPlaybackPersistenceStore()
        ..savedSessions.add(
          PlaybackSession(
            id: 'active',
            activeBookId: _book.id,
            activeBookVersionId: _book.versionId,
            activeSourceId: _book.sourceId,
            activeChapterId: 'chapter-3',
            positionMs: const Duration(minutes: 3).inMilliseconds,
            speed: 1.5,
            isPlaying: true,
            updatedAt: DateTime.utc(2026, 5, 26, 9),
          ),
        );
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine, persistence: store);

      final restored = await service.loadSavedSession(_book);

      expect(restored, isTrue);
      expect(service.state.currentChapter?.id, 'chapter-3');
      expect(service.state.position, const Duration(minutes: 3));
      expect(service.state.speed, 1.5);
      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(engine.playCount, 0);
    });

    test(
      'play resumes from a valid position when saved at chapter end',
      () async {
        final engine = RecordingAudioEngine();
        final service = PlaybackController(engine: engine);

        await service.loadBook(
          _book,
          chapterIndex: 2,
          position: const Duration(minutes: 10),
        );
        await service.play();

        expect(service.state.currentChapter?.id, 'chapter-3');
        expect(service.state.position, Duration.zero);
        expect(service.state.status, AudioPlaybackStatus.playing);
        expect(engine.seekPositions.last, Duration.zero);
        expect(engine.playCount, 1);
      },
    );

    test('audio engines tolerate repeated dispose calls', () async {
      final inMemory = InMemoryAudioEngine();
      await inMemory.dispose();

      await expectLater(inMemory.dispose(), completes);
    });

    test('switching engine disposes child engines only once', () async {
      final primary = CountingAudioEngine();
      final fallback = CountingAudioEngine();
      final engine = SwitchingAudioEngine(primary: primary, fallback: fallback);

      await engine.dispose();
      await engine.dispose();

      expect(primary.disposeCount, 1);
      expect(fallback.disposeCount, 1);
    });
  });
}

const _book = AudioPlaybackBook(
  id: 'book-1',
  versionId: 'version-1',
  sourceId: 'yakniga',
  title: 'Мастер и Маргарита',
  author: 'Михаил Булгаков',
  narrator: 'Вячеслав Герасимов',
  sourceName: 'Yakniga',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-1',
      index: 1,
      title: 'Глава 1',
      duration: Duration(minutes: 10),
    ),
    AudioPlaybackChapter(
      id: 'chapter-2',
      index: 2,
      title: 'Глава 2',
      duration: Duration(minutes: 10),
    ),
    AudioPlaybackChapter(
      id: 'chapter-3',
      index: 3,
      title: 'Глава 3',
      duration: Duration(minutes: 10),
    ),
  ],
);

class RecordingAudioEngine implements AudioEngine {
  final loadedChapterIds = <String>[];
  final loadedPositions = <Duration>[];
  final seekPositions = <Duration>[];
  final speedValues = <double>[];
  int playCount = 0;
  int pauseCount = 0;

  @override
  Stream<AudioEngineSnapshot> get snapshots => const Stream.empty();

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    loadedChapterIds.add(chapter.id);
    loadedPositions.add(position);
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    speedValues.add(speed);
  }

  @override
  Future<void> dispose() async {}
}

class FailingAudioEngine implements AudioEngine {
  const FailingAudioEngine(this.error);

  final Object error;

  @override
  Stream<AudioEngineSnapshot> get snapshots => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    throw error;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}
}

class StreamingAudioEngine implements AudioEngine {
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  final loadedChapterIds = <String>[];
  bool disposed = false;

  void emit(AudioEngineSnapshot snapshot) {
    _snapshots.add(snapshot);
  }

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> dispose() async {
    disposed = true;
    await _snapshots.close();
  }

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    loadedChapterIds.add(chapter.id);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}
}

class RecordingPlaybackPersistenceStore implements PlaybackPersistenceStore {
  final savedSessions = <PlaybackSession>[];
  final savedProgress = <PlaybackProgressSnapshot>[];

  @override
  Future<PlaybackSession?> loadSession({String id = 'active'}) async {
    return savedSessions.where((session) => session.id == id).lastOrNull;
  }

  @override
  Future<void> saveProgress(PlaybackProgressSnapshot progress) async {
    savedProgress.add(progress);
  }

  @override
  Future<void> saveSession(PlaybackSession session) async {
    savedSessions.add(session);
  }
}

class CountingAudioEngine implements AudioEngine {
  int disposeCount = 0;

  @override
  Stream<AudioEngineSnapshot> get snapshots => const Stream.empty();

  @override
  Future<void> dispose() async {
    disposeCount++;
  }

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}
}
