import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/android_media_session_engine.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';

void main() {
  group('AndroidMediaSessionEngine', () {
    test('publishes Media3 metadata from loaded book and chapter', () async {
      final delegate = RecordingAudioEngine();
      final platform = RecordingAndroidMediaSessionPlatform();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );

      await engine.load(
        _book.chapters.first,
        book: _book,
        position: const Duration(seconds: 12),
      );
      delegate.emit(
        const AudioEngineSnapshot(
          position: Duration(seconds: 12),
          duration: Duration(minutes: 10),
          processingState: AudioEngineProcessingState.ready,
          isPlaying: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(platform.updates.last.appName, 'Slovofon');
      expect(platform.updates.last.bookTitle, 'Мастер и Маргарита');
      expect(platform.updates.last.chapterTitle, 'Глава 1');
      expect(platform.updates.last.sourceName, 'Yakniga');
      expect(platform.updates.last.coverUrl, 'https://example.test/cover.jpg');
      expect(platform.updates.last.position, const Duration(seconds: 12));
      expect(platform.updates.last.duration, const Duration(minutes: 10));
      expect(
        platform.updates.last.processingState,
        AudioEngineProcessingState.ready,
      );
      expect(platform.updates.last.isPlaying, isFalse);
      expect(platform.updates.last.playWhenReady, isFalse);
      expect(platform.foregroundRequests, isEmpty);

      await engine.dispose();
    });

    test(
      'opens foreground during autoplay load but waits for acknowledgement',
      () async {
        final platform = RecordingAndroidMediaSessionPlatform();
        final delegate = RecordingAudioEngine();
        final blockedLoad = delegate.pendingLoad = Completer<void>();
        final foreground = platform.pendingForeground = Completer<bool>();
        final engine = AndroidMediaSessionEngine(
          delegate: delegate,
          platform: platform,
        );
        final loading = engine.loadForPlayback(
          _book.chapters.first,
          book: _book,
          position: Duration.zero,
        );
        expect(platform.foregroundRequests, hasLength(1));
        expect(platform.foregroundRequests.single.playWhenReady, isTrue);
        expect(platform.foregroundRequests.single.isPlaying, isFalse);
        expect(
          platform.foregroundRequests.single.processingState,
          AudioEngineProcessingState.loading,
        );
        expect(delegate.playCount, 0);

        blockedLoad.complete();
        await loading;
        final playing = engine.play();
        expect(delegate.playCount, 0);
        foreground.complete(true);
        await playing;
        expect(delegate.playCount, 1);
        expect(platform.foregroundRequests, hasLength(1));
        await engine.dispose();
      },
    );

    test('pause supersedes a queued foreground start', () async {
      final platform = RecordingAndroidMediaSessionPlatform();
      final delegate = RecordingAudioEngine();
      final foreground = platform.pendingForeground = Completer<bool>();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      await engine.load(
        _book.chapters.first,
        book: _book,
        position: Duration.zero,
      );
      final playing = engine.play();
      await Future<void>.delayed(Duration.zero);
      expect(platform.foregroundRequests, hasLength(1));
      expect(delegate.playCount, 0);
      await engine.pause();
      foreground.complete(true);
      await playing;
      expect(delegate.playCount, 0);
      expect(platform.updates.last.playWhenReady, isFalse);
      await engine.dispose();
    });

    test('denied foreground does not request actual playback', () async {
      final platform = RecordingAndroidMediaSessionPlatform()
        ..foregroundAllowed = false;
      final delegate = RecordingAudioEngine();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      await engine.load(
        _book.chapters.first,
        book: _book,
        position: Duration.zero,
      );
      await expectLater(engine.play(), throwsA(isA<AudioEngineException>()));
      expect(delegate.playCount, 0);
      expect(platform.updates.last.playWhenReady, isFalse);
      await engine.dispose();
    });

    test('routes native notification controls to playback engine', () async {
      final delegate = RecordingAudioEngine();
      final platform = RecordingAndroidMediaSessionPlatform();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      var previousCount = 0;
      var nextCount = 0;
      engine.bindChapterNavigation(
        AudioEngineChapterNavigationCallbacks(
          onPreviousChapter: () async => previousCount++,
          onNextChapter: () async => nextCount++,
        ),
      );

      await engine.load(
        _book.chapters.first,
        book: _book,
        position: const Duration(minutes: 2),
      );
      delegate.emit(
        const AudioEngineSnapshot(
          position: Duration(minutes: 2),
          duration: Duration(minutes: 10),
          processingState: AudioEngineProcessingState.ready,
          isPlaying: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      platform.emit(const AndroidMediaSessionCommand.play());
      platform.emit(
        const AndroidMediaSessionCommand.seek(Duration(minutes: 4)),
      );
      platform.emit(const AndroidMediaSessionCommand.rewind());
      platform.emit(const AndroidMediaSessionCommand.fastForward());
      platform.emit(const AndroidMediaSessionCommand.previousChapter());
      platform.emit(const AndroidMediaSessionCommand.nextChapter());
      await Future<void>.delayed(Duration.zero);

      expect(delegate.playCount, 1);
      expect(delegate.seekPositions, [
        const Duration(minutes: 4),
        const Duration(minutes: 3, seconds: 30),
        const Duration(minutes: 4),
      ]);
      expect(previousCount, 1);
      expect(nextCount, 1);

      await engine.dispose();
    });

    test('clears native media session on stop and dispose', () async {
      final delegate = RecordingAudioEngine();
      final platform = RecordingAndroidMediaSessionPlatform();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );

      await engine.load(
        _book.chapters.first,
        book: _book,
        position: Duration.zero,
      );

      platform.emit(const AndroidMediaSessionCommand.stop());
      await Future<void>.delayed(Duration.zero);

      expect(delegate.pauseCount, 1);
      expect(platform.clearCount, 1);

      await engine.dispose();

      expect(delegate.disposeCount, 1);
      expect(platform.clearCount, 2);
    });

    test('an older stop cannot clear a newer play request', () async {
      final delegate = RecordingAudioEngine();
      final platform = RecordingAndroidMediaSessionPlatform();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      final finishStop = Completer<void>();
      engine.bindChapterNavigation(
        AudioEngineChapterNavigationCallbacks(
          onPause: () async {
            await engine.pause();
            await finishStop.future;
          },
        ),
      );
      await engine.load(
        _book.chapters.first,
        book: _book,
        position: Duration.zero,
      );
      platform.emit(const AndroidMediaSessionCommand.stop());
      await Future<void>.delayed(Duration.zero);
      expect(delegate.pauseCount, 1);

      await engine.play();
      expect(delegate.playCount, 1);
      finishStop.complete();
      await Future<void>.delayed(Duration.zero);
      expect(platform.clearCount, 0);
      await engine.dispose();
    });

    test('buffering does not report audible playback to Android', () async {
      final delegate = RecordingAudioEngine();
      final platform = RecordingAndroidMediaSessionPlatform();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      await engine.load(
        _book.chapters.first,
        book: _book,
        position: Duration.zero,
      );
      await engine.play();
      delegate.emit(
        const AudioEngineSnapshot(
          position: Duration(seconds: 3),
          processingState: AudioEngineProcessingState.buffering,
          isPlaying: true,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(platform.updates.last.playWhenReady, isTrue);
      expect(platform.updates.last.isPlaying, isFalse);
      await engine.dispose();
    });

    test(
      'coalesces position-only updates before crossing five seconds',
      () async {
        final delegate = RecordingAudioEngine();
        final platform = RecordingAndroidMediaSessionPlatform();
        final engine = AndroidMediaSessionEngine(
          delegate: delegate,
          platform: platform,
        );

        await engine.load(
          _book.chapters.first,
          book: _book,
          position: Duration.zero,
        );
        delegate.emit(
          const AudioEngineSnapshot(
            position: Duration.zero,
            duration: Duration(minutes: 10),
            processingState: AudioEngineProcessingState.ready,
            isPlaying: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        final updatesAfterPlaying = platform.updates.length;

        delegate.emit(
          const AudioEngineSnapshot(
            position: Duration(seconds: 1),
            duration: Duration(minutes: 10),
            processingState: AudioEngineProcessingState.ready,
            isPlaying: true,
          ),
        );
        delegate.emit(
          const AudioEngineSnapshot(
            position: Duration(seconds: 4),
            duration: Duration(minutes: 10),
            processingState: AudioEngineProcessingState.ready,
            isPlaying: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(platform.updates, hasLength(updatesAfterPlaying));

        delegate.emit(
          const AudioEngineSnapshot(
            position: Duration(seconds: 5),
            duration: Duration(minutes: 10),
            processingState: AudioEngineProcessingState.ready,
            isPlaying: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(platform.updates, hasLength(updatesAfterPlaying + 1));
        expect(platform.updates.last.position, const Duration(seconds: 5));

        await engine.dispose();
      },
    );
  });
}

final _book = AudioPlaybackBook(
  id: 'book-1',
  versionId: 'version-1',
  sourceId: 'yakniga',
  title: 'Мастер и Маргарита',
  author: 'Михаил Булгаков',
  narrator: 'Вячеслав Герасимов',
  sourceName: 'Yakniga',
  coverUrl: 'https://example.test/cover.jpg',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-1',
      index: 1,
      title: 'Глава 1',
      duration: const Duration(minutes: 10),
      mediaSource: AudioMediaSource.asset('assets/audio/chapter-1.mp3'),
    ),
  ],
);

class RecordingAudioEngine implements AudioEngine {
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  final loadedChapterIds = <String>[];
  final loadedPositions = <Duration>[];
  final seekPositions = <Duration>[];
  int playCount = 0;
  int pauseCount = 0;
  int disposeCount = 0;
  Completer<void>? pendingLoad;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  void emit(AudioEngineSnapshot snapshot) {
    _snapshots.add(snapshot);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    await _snapshots.close();
  }

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    loadedChapterIds.add(chapter.id);
    loadedPositions.add(position);
    await pendingLoad?.future;
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
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}
}

class RecordingAndroidMediaSessionPlatform
    implements AndroidMediaSessionPlatform {
  final _commands = StreamController<AndroidMediaSessionCommand>.broadcast();
  final updates = <AndroidMediaSessionSnapshot>[];
  final foregroundRequests = <AndroidMediaSessionSnapshot>[];
  Completer<bool>? pendingForeground;
  bool foregroundAllowed = true;
  int clearCount = 0;

  @override
  Stream<AndroidMediaSessionCommand> get commands => _commands.stream;

  void emit(AndroidMediaSessionCommand command) {
    _commands.add(command);
  }

  @override
  Future<void> clear() async {
    clearCount++;
  }

  @override
  Future<void> update(AndroidMediaSessionSnapshot snapshot) async {
    updates.add(snapshot);
  }

  @override
  Future<bool> preparePlayback(AndroidMediaSessionSnapshot snapshot) async {
    foregroundRequests.add(snapshot);
    final pending = pendingForeground;
    return pending == null ? foregroundAllowed : await pending.future;
  }
}
