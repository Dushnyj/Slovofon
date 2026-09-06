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
      'autoplay load returns after starting a long-lived play future',
      () async {
        final engine = HangingPlayAudioEngine();
        final service = PlaybackController(engine: engine);
        addTearDown(engine.completePlay);

        final loadFuture = service.loadBook(_book, autoPlay: true);
        await Future<void>.delayed(Duration.zero);

        expect(engine.playCount, 1);
        await loadFuture.timeout(const Duration(milliseconds: 100));
        expect(service.state.status, AudioPlaybackStatus.playing);
      },
    );

    test(
      'keeps pending autoplay only until the backend acknowledges playback',
      () async {
        final engine = StreamingAudioEngine();
        final service = PlaybackController(engine: engine);

        await service.loadBook(_book, autoPlay: true);
        engine.emit(
          const AudioEngineSnapshot(
            position: Duration.zero,
            processingState: AudioEngineProcessingState.idle,
            isPlaying: false,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.status, AudioPlaybackStatus.playing);

        engine.emit(
          const AudioEngineSnapshot(
            position: Duration.zero,
            processingState: AudioEngineProcessingState.ready,
            isPlaying: false,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.status, AudioPlaybackStatus.playing);

        engine.emit(
          const AudioEngineSnapshot(
            position: Duration(seconds: 1),
            processingState: AudioEngineProcessingState.ready,
            isPlaying: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.status, AudioPlaybackStatus.playing);
        expect(service.state.position, const Duration(seconds: 1));

        engine.emit(
          const AudioEngineSnapshot(
            position: Duration(seconds: 1),
            processingState: AudioEngineProcessingState.ready,
            isPlaying: false,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.status, AudioPlaybackStatus.paused);

        await service.pause();
        engine.emit(
          const AudioEngineSnapshot(
            position: Duration(seconds: 1),
            processingState: AudioEngineProcessingState.ready,
            isPlaying: false,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.status, AudioPlaybackStatus.paused);
      },
    );

    test('seek calculates chapter and book progress', () async {
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.loadBook(_book);
      await service.seek(const Duration(minutes: 5));

      expect(service.state.position, const Duration(minutes: 5));
      expect(service.state.chapterProgress, closeTo(0.5, 0.001));
      expect(service.state.bookProgress, closeTo(0.166, 0.01));
      expect(engine.seekPositions, [const Duration(minutes: 5)]);
    });

    test('toggleMute restores the previous non-zero volume', () async {
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.setVolume(0.55);
      await service.toggleMute();

      expect(service.state.volume, 0);

      await service.toggleMute();

      expect(service.state.volume, closeTo(0.55, 0.001));
      expect(engine.volumeValues, [0.55, 0, 0.55]);
    });

    test('ignores duplicate engine snapshots', () async {
      final engine = StreamingAudioEngine();
      final service = PlaybackController(engine: engine);
      var notifications = 0;

      await service.loadBook(_book);
      service.addListener(() => notifications++);

      engine.emit(
        const AudioEngineSnapshot(
          position: Duration.zero,
          processingState: AudioEngineProcessingState.ready,
          isPlaying: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 0);

      engine.emit(
        const AudioEngineSnapshot(
          position: Duration(seconds: 1),
          processingState: AudioEngineProcessingState.ready,
          isPlaying: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 1);

      engine.emit(
        const AudioEngineSnapshot(
          position: Duration(seconds: 1),
          processingState: AudioEngineProcessingState.ready,
          isPlaying: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 1);
    });

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
      expect(service.state.sleepTimerRemaining, isNull);
      expect(engine.pauseCount, 1);
    });

    test('sleep timer countdown pauses while playback is paused', () async {
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.loadBook(_book, autoPlay: true);
      service.setSleepTimer(const Duration(minutes: 30));
      await service.pause();

      await service.tick(const Duration(minutes: 5));

      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(service.state.sleepTimerRemaining, const Duration(minutes: 30));

      await service.play();
      await service.tick(const Duration(minutes: 1));

      expect(service.state.sleepTimerRemaining, const Duration(minutes: 29));
    });

    test(
      'sleep timer tick does not seek the audio engine every second',
      () async {
        final engine = RecordingAudioEngine();
        final service = PlaybackController(engine: engine);

        await service.loadBook(_book, autoPlay: true);
        service.setSleepTimer(const Duration(seconds: 30));

        await service.tick(const Duration(seconds: 1));

        expect(engine.seekPositions, isEmpty);
        expect(service.state.position, Duration.zero);
        expect(service.state.sleepTimerRemaining, const Duration(seconds: 29));
        expect(service.state.status, AudioPlaybackStatus.playing);
      },
    );

    test('sleep timer can stop at the end of the current chapter', () async {
      final engine = StreamingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.loadBook(
        _book,
        position: const Duration(minutes: 3),
        autoPlay: true,
      );
      service.setSleepTimerToChapterEnd();

      expect(service.state.sleepTimerRemaining, const Duration(minutes: 7));

      await service.tick(const Duration(minutes: 7));

      // Chapter-end mode follows backend completion, not a wall-clock guess.
      expect(service.state.status, AudioPlaybackStatus.playing);
      engine.emit(
        const AudioEngineSnapshot(
          position: Duration(minutes: 10),
          processingState: AudioEngineProcessingState.completed,
          isPlaying: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(service.state.sleepTimerRemaining, isNull);
      expect(service.state.chapterIndex, 0);
    });

    test('expired sleep timer does not re-pause playback after resume '
        '(regression: stuck pause after timer ends)', () async {
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.loadBook(_book, autoPlay: true);
      service.setSleepTimer(const Duration(minutes: 1));

      // Timer expires while playing -> playback pauses, timer clears.
      await service.tick(const Duration(minutes: 1));

      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(service.state.sleepTimerRemaining, isNull);

      // Resuming playback must keep playing: the previously expired timer
      // must no longer re-pause it on the next tick.
      await service.play();

      expect(service.state.status, AudioPlaybackStatus.playing);

      await service.tick(const Duration(seconds: 1));

      expect(service.state.status, AudioPlaybackStatus.playing);
      expect(service.state.sleepTimerRemaining, isNull);
      expect(engine.playCount, greaterThan(1));
    });

    test('restoreSession ignores a persisted zero sleep timer so playback '
        'does not immediately re-pause', () async {
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.restoreSession(
        _book,
        PlaybackSession(
          id: 'session',
          activeBookId: _book.id,
          activeBookVersionId: _book.versionId,
          activeSourceId: _book.sourceId,
          activeChapterId: 'chapter-1',
          positionMs: 0,
          speed: 1,
          isPlaying: false,
          sleepTimerRemainingMs: 0,
          sleepTimerMode: SleepTimerMode.stopAfterDuration,
          updatedAt: DateTime.utc(2026, 5, 26),
        ),
      );

      expect(service.state.sleepTimerRemaining, isNull);
      expect(service.state.status, AudioPlaybackStatus.paused);

      await service.play();
      await service.tick(const Duration(seconds: 1));

      expect(service.state.status, AudioPlaybackStatus.playing);
    });

    test('chapter switches resume saved runtime positions', () async {
      final engine = RecordingAudioEngine();
      final service = PlaybackController(engine: engine);

      await service.loadBook(_book);
      await service.seek(const Duration(minutes: 3));
      await service.nextChapter();
      await service.seek(const Duration(minutes: 4));

      await service.previousChapter();

      expect(service.state.currentChapter?.id, 'chapter-1');
      expect(service.state.position, const Duration(minutes: 3));

      await service.nextChapter();

      expect(service.state.currentChapter?.id, 'chapter-2');
      expect(service.state.position, const Duration(minutes: 4));
      expect(engine.loadedPositions, contains(const Duration(minutes: 3)));
      expect(engine.loadedPositions, contains(const Duration(minutes: 4)));
    });

    test(
      'chapter progress exposes remembered runtime position after switching',
      () async {
        final engine = RecordingAudioEngine();
        final service = PlaybackController(engine: engine);

        await service.loadBook(_book);
        await service.seek(const Duration(minutes: 3));
        await service.nextChapter();

        expect(service.chapterProgressAt(0), closeTo(0.3, 0.001));
        expect(service.chapterProgressAt(1), 0);

        await service.seek(const Duration(minutes: 4));
        await service.previousChapter();

        expect(service.chapterProgressAt(0), closeTo(0.3, 0.001));
        expect(service.chapterProgressAt(1), closeTo(0.4, 0.001));
      },
    );

    test(
      'refreshes active book through resolver before chapter navigation',
      () async {
        final engine = RecordingAudioEngine();
        final service = PlaybackController(
          engine: engine,
          playbackBookResolver: (book) async => _bookWithLocalSecondChapter,
        );

        await service.loadBook(_book);
        await service.nextChapter();

        expect(service.state.currentChapter?.id, 'chapter-2');
        expect(engine.loadedChapterIds, ['chapter-1', 'chapter-2']);
        expect(engine.loadedMediaSources.last?.type, AudioMediaSourceType.file);
        expect(service.state.book?.chapters[1].isDownloaded, isTrue);
      },
    );

    test(
      'reloads current chapter when resolver switches playback to a local file',
      () async {
        final engine = RecordingAudioEngine();
        final service = PlaybackController(
          engine: engine,
          playbackBookResolver: (book) async => _bookWithLocalFirstChapter,
        );

        await service.loadBook(_bookWithRemoteFirstChapter);
        await service.play();

        expect(engine.loadedChapterIds, ['chapter-1', 'chapter-1']);
        expect(engine.loadedMediaSources.first?.type, AudioMediaSourceType.url);
        expect(engine.loadedMediaSources.last?.type, AudioMediaSourceType.file);
        expect(service.state.book?.chapters.first.isDownloaded, isTrue);
        expect(engine.playCount, 1);
      },
    );

    test(
      'keeps chapter resume positions when refreshed chapter ids differ',
      () async {
        final engine = RecordingAudioEngine();
        final service = PlaybackController(
          engine: engine,
          playbackBookResolver: (book) async => _bookWithRefreshedChapterIds,
        );

        await service.loadBook(_book);
        await service.seek(const Duration(minutes: 3));
        await service.nextChapter();
        await service.previousChapter();

        expect(service.state.chapterIndex, 0);
        expect(service.state.position, const Duration(minutes: 3));
      },
    );

    test(
      'ignores stale completion snapshots while switching chapters manually',
      () async {
        final engine = CompletingDuringLoadAudioEngine();
        final service = PlaybackController(engine: engine);

        await service.loadBook(_book);
        await service.seek(const Duration(minutes: 3));
        await service.nextChapter();

        expect(service.state.currentChapter?.id, 'chapter-2');
        expect(service.state.position, Duration.zero);
        expect(service.chapterProgressAt(0), closeTo(0.3, 0.001));

        await service.previousChapter();

        expect(service.state.currentChapter?.id, 'chapter-1');
        expect(service.state.position, const Duration(minutes: 3));
      },
    );

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
      'learns unknown chapter duration from the engine without freezing position',
      () async {
        final engine = StreamingAudioEngine();
        final service = PlaybackController(engine: engine);

        await service.loadBook(_unknownDurationBook);
        engine.emit(
          const AudioEngineSnapshot(
            position: Duration(seconds: 8),
            duration: Duration(minutes: 9),
            processingState: AudioEngineProcessingState.ready,
            isPlaying: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(service.state.position, const Duration(seconds: 8));
        expect(
          service.state.currentChapter?.duration,
          const Duration(minutes: 9),
        );
        expect(service.state.chapterProgress, closeTo(0.014, 0.001));
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

    test('persists active book metadata when a book is loaded', () async {
      final metadataStore = RecordingPlaybackBookMetadataStore();
      final service = PlaybackController(
        engine: RecordingAudioEngine(),
        bookMetadataStore: metadataStore,
      );

      await service.loadBook(_book, autoPlay: true);

      expect(metadataStore.savedBooks, [_book]);
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

const _unknownDurationBook = AudioPlaybackBook(
  id: 'book-unknown-duration',
  versionId: 'version-unknown-duration',
  sourceId: 'baza_knig',
  title: 'Дыхание зоны',
  author: 'Грошев Николай',
  narrator: 'Орлов Глеб',
  sourceName: 'Baza Knig',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-1',
      index: 1,
      title: 'Глава 1',
      duration: Duration.zero,
    ),
  ],
);

final _bookWithLocalSecondChapter = AudioPlaybackBook(
  id: _book.id,
  versionId: _book.versionId,
  sourceId: _book.sourceId,
  title: _book.title,
  author: _book.author,
  narrator: _book.narrator,
  sourceName: _book.sourceName,
  chapters: [
    _book.chapters[0],
    _book.chapters[1].copyWith(
      isDownloaded: true,
      mediaSource: AudioMediaSource.file('/tmp/chapter-2.mp3'),
    ),
    _book.chapters[2],
  ],
);

final _bookWithRemoteFirstChapter = AudioPlaybackBook(
  id: _book.id,
  versionId: _book.versionId,
  sourceId: _book.sourceId,
  title: _book.title,
  author: _book.author,
  narrator: _book.narrator,
  sourceName: _book.sourceName,
  chapters: [
    _book.chapters[0].copyWith(
      mediaSource: AudioMediaSource.url(
        Uri.parse('https://example.test/chapter-1.mp3'),
      ),
    ),
    _book.chapters[1],
    _book.chapters[2],
  ],
);

final _bookWithLocalFirstChapter = AudioPlaybackBook(
  id: _book.id,
  versionId: _book.versionId,
  sourceId: _book.sourceId,
  title: _book.title,
  author: _book.author,
  narrator: _book.narrator,
  sourceName: _book.sourceName,
  chapters: [
    _book.chapters[0].copyWith(
      isDownloaded: true,
      mediaSource: AudioMediaSource.file('/tmp/slovofon/chapter-1.mp3'),
    ),
    _book.chapters[1],
    _book.chapters[2],
  ],
);

final _bookWithRefreshedChapterIds = AudioPlaybackBook(
  id: _book.id,
  versionId: _book.versionId,
  sourceId: _book.sourceId,
  title: _book.title,
  author: _book.author,
  narrator: _book.narrator,
  sourceName: _book.sourceName,
  chapters: [
    _book.chapters[0].copyWith(id: 'fresh-chapter-1'),
    _book.chapters[1].copyWith(id: 'fresh-chapter-2'),
    _book.chapters[2].copyWith(id: 'fresh-chapter-3'),
  ],
);

class RecordingAudioEngine implements AudioEngine {
  final loadedChapterIds = <String>[];
  final loadedPositions = <Duration>[];
  final loadedMediaSources = <AudioMediaSource?>[];
  final seekPositions = <Duration>[];
  final speedValues = <double>[];
  final volumeValues = <double>[];
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
    loadedMediaSources.add(chapter.mediaSource);
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
  Future<void> setVolume(double volume) async {
    volumeValues.add(volume);
  }

  @override
  Future<void> dispose() async {}
}

class CompletingDuringLoadAudioEngine extends RecordingAudioEngine {
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    await super.load(chapter, position: position, book: book);
    if (loadedChapterIds.length > 1) {
      _snapshots.add(
        const AudioEngineSnapshot(
          position: Duration(minutes: 10),
          processingState: AudioEngineProcessingState.completed,
          isPlaying: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  @override
  Future<void> dispose() async {
    await _snapshots.close();
  }
}

class HangingPlayAudioEngine extends RecordingAudioEngine {
  final _playCompleter = Completer<void>();

  @override
  Future<void> play() {
    playCount++;
    return _playCompleter.future;
  }

  void completePlay() {
    if (!_playCompleter.isCompleted) {
      _playCompleter.complete();
    }
  }
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

  @override
  Future<void> setVolume(double volume) async {}
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

  @override
  Future<void> setVolume(double volume) async {}
}

class RecordingPlaybackPersistenceStore implements PlaybackPersistenceStore {
  final savedSessions = <PlaybackSession>[];
  final savedProgress = <PlaybackProgressSnapshot>[];

  @override
  Future<PlaybackSession?> loadSession({String id = 'active'}) async {
    return savedSessions.where((session) => session.id == id).lastOrNull;
  }

  @override
  Future<List<PlaybackProgressSnapshot>> loadProgress() async {
    return savedProgress;
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

class RecordingPlaybackBookMetadataStore implements PlaybackBookMetadataStore {
  final savedBooks = <AudioPlaybackBook>[];

  @override
  Future<AudioPlaybackBook?> loadBook({
    required String sourceId,
    required String versionId,
  }) async {
    return savedBooks.cast<AudioPlaybackBook?>().firstWhere(
      (book) => book?.sourceId == sourceId && book?.versionId == versionId,
      orElse: () => null,
    );
  }

  @override
  Future<void> saveBook(AudioPlaybackBook book) async {
    savedBooks.add(book);
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

  @override
  Future<void> setVolume(double volume) async {}
}
