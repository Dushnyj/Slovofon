import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/just_audio_engine.dart';
import 'package:slovofon/services/audio/android_media_session_engine.dart';
import 'playback_controller_test.dart' as controller_fixture;
import 'android_media_session_engine_test.dart' as android_fixture;
import 'just_audio_engine_test.dart' as just_fixture;

AudioPlaybackBook book(
  String id, {
  Duration duration = const Duration(minutes: 10),
}) => AudioPlaybackBook(
  id: id,
  versionId: 'v-$id',
  sourceId: 'fixture',
  title: id,
  author: 'fixture',
  narrator: 'fixture',
  sourceName: 'fixture',
  chapters: List.generate(
    2,
    (i) => AudioPlaybackChapter(
      id: '$id-$i',
      index: i,
      title: 'Chapter $i',
      duration: duration,
      mediaSource: AudioMediaSource.asset('not-opened-by-fake.mp3'),
    ),
  ),
);
Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  test('native pause must not wait for the outstanding play future', () async {
    final delegate = controller_fixture.HangingPlayAudioEngine();
    final platform = android_fixture.RecordingAndroidMediaSessionPlatform();
    final engine = AndroidMediaSessionEngine(
      delegate: delegate,
      platform: platform,
    );
    final b = book('A');
    await engine.load(b.chapters.first, position: Duration.zero, book: b);
    platform.emit(const AndroidMediaSessionCommand.play());
    await pump();
    platform.emit(const AndroidMediaSessionCommand.pause());
    await pump();
    final countBeforeEndingPlayback = delegate.pauseCount;
    delegate.completePlay();
    await pump();
    await engine.dispose();
    expect(
      countBeforeEndingPlayback,
      1,
      reason: 'Pause must be usable while chapter is still playing',
    );
  });
  test(
    'native or audio-focus pause must be reflected after ready/playing acknowledgement',
    () async {
      final engine = controller_fixture.StreamingAudioEngine();
      final service = PlaybackController(engine: engine);
      await service.loadBook(book('A'), autoPlay: true);
      engine.emit(
        const AudioEngineSnapshot(
          position: Duration(seconds: 1),
          processingState: AudioEngineProcessingState.ready,
          isPlaying: true,
        ),
      );
      await pump();
      engine.emit(
        const AudioEngineSnapshot(
          position: Duration(seconds: 1),
          processingState: AudioEngineProcessingState.ready,
          isPlaying: false,
        ),
      );
      await pump();
      expect(service.state.status, AudioPlaybackStatus.paused);
    },
  );
  test(
    'runtime duration emitted while load is awaited must not be erased',
    () async {
      final adapter = DurationDuringLoadAdapter();
      final engine = JustAudioEngine(player: adapter);
      final service = PlaybackController(engine: engine);
      await service.loadBook(book('A', duration: Duration.zero));
      adapter.emitPosition(const Duration(seconds: 2));
      await pump();
      expect(service.state.chapterDuration, const Duration(minutes: 11));
    },
  );
  test(
    'chapter-end timer must stop at completion when playback speed is 2x',
    () async {
      final engine = controller_fixture.StreamingAudioEngine();
      final service = PlaybackController(engine: engine);
      await service.loadBook(book('A'), autoPlay: true);
      await service.setSpeed(2);
      service.setSleepTimerToChapterEnd();
      await service.tick(const Duration(minutes: 5));
      engine.emit(
        const AudioEngineSnapshot(
          position: Duration(minutes: 10),
          processingState: AudioEngineProcessingState.completed,
          isPlaying: true,
        ),
      );
      await pump();
      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(service.state.chapterIndex, 0);
    },
  );
  test(
    'stale playback refresh must not replace a newer selected book',
    () async {
      final refresh = Completer<AudioPlaybackBook>();
      final engine = InMemoryAudioEngine();
      final a = book('A'), b = book('B');
      final service = PlaybackController(
        engine: engine,
        playbackBookResolver: (_) => refresh.future,
      );
      await service.loadBook(a);
      final oldPlay = service.play();
      await pump();
      await service.loadBook(b);
      refresh.complete(a);
      await oldPlay;
      expect(service.state.book!.id, 'B');
      expect(engine.loadedBook!.id, 'B');
    },
  );
  test(
    'next on final chapter must not mark completion while audio continues playing',
    () async {
      final engine = InMemoryAudioEngine();
      final service = PlaybackController(engine: engine);
      await service.loadBook(book('A'), chapterIndex: 1, autoPlay: true);
      await service.nextChapter();
      expect(engine.isPlaying, false);
    },
  );
  test(
    'chapter-end mode survives persistence and ignores clock ticks after seek and speed change',
    () async {
      final service = PlaybackController(
        engine: controller_fixture.StreamingAudioEngine(),
      );
      await service.loadBook(book('A'));
      service.setSleepTimerToChapterEnd();
      await service.setSpeed(0.5);
      await service.seek(const Duration(minutes: 8));
      final session = service.toPlaybackSession();
      expect(session.sleepTimerMode, SleepTimerMode.stopAtChapterEnd);
      expect(
        session.sleepTimerRemainingMs,
        const Duration(minutes: 2).inMilliseconds,
      );
      final engine = controller_fixture.StreamingAudioEngine();
      final restored = PlaybackController(engine: engine);
      await restored.restoreSession(book('A'), session);
      await restored.play();
      await restored.tick(const Duration(hours: 1));
      expect(restored.state.isPlaying, true);
      engine.emit(
        const AudioEngineSnapshot(
          position: Duration(minutes: 10),
          processingState: AudioEngineProcessingState.completed,
          isPlaying: true,
        ),
      );
      await pump();
      expect(restored.state.status, AudioPlaybackStatus.paused);
      expect(restored.state.sleepTimerMode, SleepTimerMode.off);
      expect(restored.toPlaybackSession().sleepTimerMode, SleepTimerMode.off);
    },
  );
  test(
    'pause invalidates a pending playback resolver without restarting later',
    () async {
      final resolver = Completer<AudioPlaybackBook>();
      final engine = controller_fixture.RecordingAudioEngine();
      final b = book('A');
      final service = PlaybackController(
        engine: engine,
        playbackBookResolver: (_) => resolver.future,
      );
      await service.loadBook(b);
      final pending = service.play();
      await pump();
      await service.pause();
      resolver.complete(b);
      await pending;
      expect(engine.playCount, 0);
      expect(service.state.status, AudioPlaybackStatus.paused);
    },
  );
  test(
    'overlapping book loads are serialized and only latest may autoplay',
    () async {
      final engine = GatedLoadEngine();
      final service = PlaybackController(engine: engine);
      final old = service.loadBook(book('A'), autoPlay: true);
      await pump();
      final current = service.loadBook(book('B'));
      await pump();
      expect(engine.loadedChapterIds, ['A-0']);
      engine.gate.complete();
      await Future.wait([old, current]);
      expect(engine.loadedChapterIds, ['A-0', 'B-0']);
      expect(service.state.book!.id, 'B');
      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(engine.playCount, 0);
    },
  );
  test('an interrupted old load error cannot poison the newer book', () async {
    final engine = GatedLoadEngine();
    final service = PlaybackController(engine: engine);
    final old = service.loadBook(book('A'), autoPlay: true);
    await pump();
    final current = service.loadBook(book('B'));
    engine.gate.completeError(const AudioEngineException('old load failed'));
    await Future.wait([old, current]);
    expect(service.state.book!.id, 'B');
    expect(service.state.status, AudioPlaybackStatus.paused);
    expect(service.state.errorMessage, isNull);
  });
  test('late play error cannot replace the state of a newer book', () async {
    final engine = GatedPlayEngine();
    final service = PlaybackController(engine: engine);
    await service.loadBook(book('A'), autoPlay: true);
    await service.loadBook(book('B'));
    engine.gate.completeError(const AudioEngineException('old play failed'));
    await pump();
    expect(service.state.book!.id, 'B');
    expect(service.state.status, AudioPlaybackStatus.paused);
    expect(service.state.errorMessage, isNull);
  });
  test(
    'dispose invalidates a pending resolver and no later notification occurs',
    () async {
      final resolver = Completer<AudioPlaybackBook>();
      final engine = controller_fixture.RecordingAudioEngine();
      final b = book('A');
      final service = PlaybackController(
        engine: engine,
        playbackBookResolver: (_) => resolver.future,
      );
      await service.loadBook(b);
      final pending = service.play();
      await pump();
      service.dispose();
      resolver.complete(b);
      await pending;
      expect(engine.playCount, 0);
    },
  );
  test(
    'session and progress writes capture the same book before awaiting persistence',
    () async {
      final store = GatedPersistence();
      final service = PlaybackController(
        engine: controller_fixture.RecordingAudioEngine(),
        persistence: store,
      );
      final a = service.loadBook(book('A'));
      await pump();
      final b = service.loadBook(book('B'));
      await pump();
      store.gate.complete();
      await Future.wait([a, b]);
      expect(store.savedProgress.length, store.savedSessions.length);
      for (var i = 0; i < store.savedProgress.length; i++) {
        expect(
          store.savedProgress[i].bookId,
          store.savedSessions[i].activeBookId,
        );
      }
    },
  );
  test(
    'history provider reacts to discrete saves, not periodic position persistence',
    () async {
      final store = controller_fixture.RecordingPlaybackPersistenceStore();
      final engine = controller_fixture.StreamingAudioEngine();
      final service = PlaybackController(
        engine: engine,
        persistence: store,
        persistenceInterval: Duration.zero,
      );
      final container = ProviderContainer(
        overrides: [
          playbackPersistenceStoreProvider.overrideWithValue(store),
          playbackControllerProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        playbackProgressSnapshotsProvider,
        (_, next) {},
      );
      addTearDown(sub.close);
      await container.read(playbackProgressSnapshotsProvider.future);
      await service.loadBook(book('A'));
      await pump();
      expect(
        (await container.read(
          playbackProgressSnapshotsProvider.future,
        )).last.bookId,
        'A',
      );
      final revision = service.progressRevision;
      engine.emit(
        const AudioEngineSnapshot(
          position: Duration(seconds: 5),
          processingState: AudioEngineProcessingState.ready,
          isPlaying: true,
        ),
      );
      await pump();
      expect(service.progressRevision, revision);
      await service.loadBook(book('B'));
      await pump();
      expect(
        (await container.read(
          playbackProgressSnapshotsProvider.future,
        )).last.bookId,
        'B',
      );
    },
  );
  test(
    'controller binds native pause and play without bootstrap-specific wiring',
    () async {
      final delegate = InMemoryAudioEngine();
      final platform = android_fixture.RecordingAndroidMediaSessionPlatform();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      final service = PlaybackController(engine: engine);
      await service.loadBook(book('A'), autoPlay: true);
      platform.emit(const AndroidMediaSessionCommand.pause());
      await pump();
      expect(service.state.status, AudioPlaybackStatus.paused);
      platform.emit(const AndroidMediaSessionCommand.play());
      await pump();
      expect(service.state.isPlaying, true);
      expect(delegate.isPlaying, true);
    },
  );
  test('native pause can cancel an in-flight chapter resolver', () async {
    final refresh = Completer<AudioPlaybackBook>();
    final delegate = InMemoryAudioEngine();
    final platform = android_fixture.RecordingAndroidMediaSessionPlatform();
    final engine = AndroidMediaSessionEngine(
      delegate: delegate,
      platform: platform,
    );
    final b = book('A');
    final service = PlaybackController(
      engine: engine,
      playbackBookResolver: (_) => refresh.future,
    );
    await service.loadBook(b, autoPlay: true);
    platform.emit(const AndroidMediaSessionCommand.nextChapter());
    await pump();
    platform.emit(const AndroidMediaSessionCommand.pause());
    await pump();
    expect(service.state.status, AudioPlaybackStatus.paused);
    expect(delegate.isPlaying, false);
    refresh.complete(b);
    await pump();
    expect(service.state.chapterIndex, 0);
    expect(service.state.status, AudioPlaybackStatus.paused);
  });
  test(
    'native burst play then pause does not execute stale queued play',
    () async {
      final delegate = InMemoryAudioEngine();
      final platform = android_fixture.RecordingAndroidMediaSessionPlatform();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      final service = PlaybackController(engine: engine);
      await service.loadBook(book('A'));
      platform.emit(const AndroidMediaSessionCommand.play());
      platform.emit(const AndroidMediaSessionCommand.pause());
      await pump();
      expect(service.state.status, AudioPlaybackStatus.paused);
      expect(delegate.isPlaying, false);
    },
  );
  test(
    'media retry resolver is called only after remote playback error',
    () async {
      final base = book('A');
      final stale = base.copyWith(
        chapters: base.chapters
            .map(
              (c) => c.copyWith(
                mediaSource: AudioMediaSource.url(
                  Uri.parse('https://example.test/stale.mp3'),
                ),
              ),
            )
            .toList(),
      );
      final fresh = stale.copyWith(
        chapters: stale.chapters
            .map(
              (c) => c.copyWith(
                mediaSource: AudioMediaSource.url(
                  Uri.parse('https://example.test/fresh.mp3'),
                ),
              ),
            )
            .toList(),
      );
      var retries = 0;
      final engine = controller_fixture.StreamingAudioEngine();
      final service = PlaybackController(
        engine: engine,
        playbackBookResolver: (b) async => b,
        playbackErrorBookResolver: (_) async {
          retries++;
          return fresh;
        },
      );
      await service.loadBook(stale);
      await service.play();
      await service.pause();
      expect(retries, 0);
      engine.emit(
        const AudioEngineSnapshot(
          position: Duration(seconds: 5),
          processingState: AudioEngineProcessingState.error,
          isPlaying: false,
        ),
      );
      await pump();
      await service.play();
      expect(retries, 1);
      expect(service.state.currentChapter!.mediaSource!.uri.path, '/fresh.mp3');
      expect(engine.loadedChapterIds, ['A-0', 'A-0']);
    },
  );
  test(
    'retry of an available local chapter never calls remote media resolver',
    () async {
      final b = book('A');
      final local = b.copyWith(
        chapters: b.chapters
            .map(
              (c) => c.copyWith(
                mediaSource: AudioMediaSource.file('/fixture/audio.mp3'),
              ),
            )
            .toList(),
      );
      var retries = 0;
      final engine = controller_fixture.StreamingAudioEngine();
      final service = PlaybackController(
        engine: engine,
        playbackBookResolver: (_) async => local,
        playbackErrorBookResolver: (_) async {
          retries++;
          return b;
        },
      );
      await service.loadBook(b);
      engine.emit(
        const AudioEngineSnapshot(
          position: Duration.zero,
          processingState: AudioEngineProcessingState.error,
          isPlaying: false,
        ),
      );
      await pump();
      await service.play();
      expect(retries, 0);
      expect(
        service.state.currentChapter!.mediaSource!.type,
        AudioMediaSourceType.file,
      );
    },
  );
  test(
    'native metadata publishes speed and actual chapter navigation bounds',
    () async {
      final delegate = controller_fixture.StreamingAudioEngine();
      final platform = android_fixture.RecordingAndroidMediaSessionPlatform();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      final b = book('A');
      await engine.load(b.chapters.first, position: Duration.zero, book: b);
      await engine.setSpeed(2);
      expect(platform.updates.last.toMap()['speed'], 2.0);
      expect(platform.updates.last.canSkipPrevious, false);
      expect(platform.updates.last.canSkipNext, true);
      await engine.load(b.chapters.last, position: Duration.zero, book: b);
      expect(platform.updates.last.canSkipPrevious, true);
      expect(platform.updates.last.canSkipNext, false);
    },
  );
  test(
    'native queued command rejection reports an error and leaves queue usable',
    () async {
      final delegate = android_fixture.RecordingAudioEngine();
      final platform = android_fixture.RecordingAndroidMediaSessionPlatform();
      final engine = AndroidMediaSessionEngine(
        delegate: delegate,
        platform: platform,
      );
      final b = book('A');
      await engine.load(b.chapters.first, position: Duration.zero, book: b);
      engine.bindChapterNavigation(
        AudioEngineChapterNavigationCallbacks(
          onNextChapter: () =>
              Future<void>.error(StateError('rejected command')),
        ),
      );
      platform.emit(const AndroidMediaSessionCommand.nextChapter());
      await pump();
      expect(
        platform.updates.last.processingState,
        AudioEngineProcessingState.error,
      );
      platform.emit(
        const AndroidMediaSessionCommand.seek(Duration(seconds: 20)),
      );
      await pump();
      expect(delegate.seekPositions, [const Duration(seconds: 20)]);
      await engine.dispose();
    },
  );
}

class DurationDuringLoadAdapter
    extends just_fixture.RecordingJustAudioPlayerAdapter {
  @override
  Future<void> load(AudioLoadRequest request) async {
    await super.load(request);
    emitDuration(const Duration(minutes: 11));
    await pump();
  }
}

class GatedLoadEngine extends controller_fixture.RecordingAudioEngine {
  final gate = Completer<void>();
  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    await super.load(chapter, position: position, book: book);
    if (loadedChapterIds.length == 1) await gate.future;
  }
}

class GatedPlayEngine extends controller_fixture.RecordingAudioEngine {
  final gate = Completer<void>();
  @override
  Future<void> play() {
    playCount++;
    return gate.future;
  }
}

class GatedPersistence
    extends controller_fixture.RecordingPlaybackPersistenceStore {
  final gate = Completer<void>();
  @override
  Future<void> saveSession(PlaybackSession session) async {
    await gate.future;
    await super.saveSession(session);
  }
}
