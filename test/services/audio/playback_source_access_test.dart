import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/sources/source_access_policy.dart';
import 'package:slovofon/services/sources/source_settings_store.dart';

import 'android_media_session_engine_test.dart' show RecordingAudioEngine;

final _remote = AudioMediaSource.url(
  Uri.parse('https://media.example.invalid/book.mp3'),
);
final _book = AudioPlaybackBook(
  id: 'access-book',
  versionId: 'access-version',
  sourceId: 'izib',
  title: 'Book',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Izib',
  chapters: [
    for (var index = 0; index < 2; index++)
      AudioPlaybackChapter(
        id: 'chapter-$index',
        index: index,
        title: 'Chapter $index',
        duration: const Duration(minutes: 10),
        mediaSource: _remote,
      ),
  ],
);

void main() {
  for (final restore in [false, true]) {
    test(
      'denied remote ${restore ? 'restore' : 'load'} never reaches the decoder',
      () async {
        final fixture = await _fixture(allowed: false);
        if (restore) {
          await fixture.controller.restoreSession(
            _book,
            PlaybackSession(
              id: 'active',
              activeBookId: _book.id,
              activeBookVersionId: _book.versionId,
              activeSourceId: _book.sourceId,
              activeChapterId: _book.chapters.first.id,
              positionMs: 42000,
              isPlaying: true,
              updatedAt: DateTime(2026),
            ),
          );
        } else {
          await fixture.controller.loadBook(
            _book,
            position: const Duration(seconds: 42),
            autoPlay: true,
          );
        }
        expect(fixture.engine.loadedChapterIds, isEmpty);
        expect(fixture.engine.playCount, 0);
        expect(
          fixture.controller.state.errorMessage,
          'source_streaming_disabled',
        );
        expect(fixture.controller.state.position, const Duration(seconds: 42));
      },
    );
  }

  test(
    'already loaded resume reads live permission and succeeds after re-enable',
    () async {
      final fixture = await _fixture();
      await fixture.controller.loadBook(
        _book,
        position: const Duration(seconds: 42),
        autoPlay: true,
      );
      await fixture.controller.pause();
      await fixture.store.setMediaPermissions('izib', allowStreaming: false);
      await fixture.controller.play();
      expect(fixture.engine.playCount, 1);
      expect(
        fixture.controller.state.errorMessage,
        'source_streaming_disabled',
      );
      expect(fixture.controller.state.position, const Duration(seconds: 42));
      await fixture.store.setMediaPermissions('izib', allowStreaming: true);
      await fixture.controller.play();
      expect(fixture.engine.playCount, 2);
      expect(fixture.engine.loadedPositions.last, const Duration(seconds: 42));
      expect(fixture.controller.state.isPlaying, isTrue);
    },
  );

  test('denied retry stops before the remote media resolver', () async {
    var refreshes = 0;
    final fixture = await _fixture(
      allowed: false,
      retry: (book) async {
        refreshes++;
        return book;
      },
    );
    await fixture.controller.loadBook(_book);
    await fixture.controller.play();
    expect(refreshes, 0);
    expect(fixture.engine.loadedChapterIds, isEmpty);
    expect(fixture.controller.state.errorMessage, 'source_streaming_disabled');
  });

  for (final local in [
    AudioMediaSource.file('fixture-downloaded.mp3'),
    AudioMediaSource.asset('fixture.mp3'),
  ]) {
    test(
      'local ${local.type.name} plays and retries despite disabled streaming; next remote is blocked',
      () async {
        var refreshes = 0;
        final fixture = await _fixture(
          allowed: false,
          retry: (book) async {
            refreshes++;
            return book;
          },
        );
        final book = _book.copyWith(
          chapters: [
            _book.chapters.first.copyWith(
              mediaSource: local,
              originalMediaSource: _remote,
            ),
            _book.chapters.last,
          ],
        );
        await fixture.controller.loadBook(book, autoPlay: true);
        expect(fixture.engine.playCount, 1);
        fixture.engine.emit(
          const AudioEngineSnapshot(
            position: Duration(seconds: 20),
            processingState: AudioEngineProcessingState.error,
            isPlaying: false,
            errorMessage: 'Fixture local decoder failure',
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await fixture.controller.play();
        expect(refreshes, 0);
        expect(fixture.engine.playCount, 2);
        await fixture.controller.nextChapter();
        expect(fixture.engine.loadedChapterIds, ['chapter-0', 'chapter-0']);
        expect(fixture.engine.pauseCount, greaterThan(0));
        expect(
          fixture.controller.state.errorMessage,
          'source_streaming_disabled',
        );
        await fixture.controller.previousChapter();
        expect(fixture.controller.state.currentChapter?.id, 'chapter-0');
        expect(fixture.controller.state.status, AudioPlaybackStatus.paused);
      },
    );
  }

  test(
    'disabled remote seeking does not issue a new decoder range request',
    () async {
      final fixture = await _fixture();
      await fixture.controller.loadBook(
        _book,
        position: const Duration(seconds: 42),
      );
      await fixture.store.setMediaPermissions('izib', allowStreaming: false);
      await fixture.controller.seek(const Duration(seconds: 90));
      expect(fixture.engine.seekPositions, isEmpty);
      expect(fixture.controller.state.position, const Duration(seconds: 42));
      expect(
        fixture.controller.state.errorMessage,
        'source_streaming_disabled',
      );
    },
  );

  test(
    'permission is checked again after a pending load and before autoplay',
    () async {
      final engine = _GatedLoadEngine();
      final fixture = await _fixture(engine: engine);
      final load = fixture.controller.loadBook(_book, autoPlay: true);
      await engine.started.future;
      await fixture.store.setMediaPermissions('izib', allowStreaming: false);
      engine.release.complete();
      await load;
      expect(engine.loadedChapterIds, ['chapter-0']);
      expect(engine.playCount, 0);
      expect(
        fixture.controller.state.errorMessage,
        'source_streaming_disabled',
      );
    },
  );

  test(
    'Pause cancels an in-flight final play authorization without stale playing state',
    () async {
      final engine = RecordingAudioEngine();
      final started = Completer<void>();
      final release = Completer<void>();
      var checks = 0;
      final controller = PlaybackController(
        engine: engine,
        playbackAccessGuard: (book, chapter) async {
          checks++;
          // load=1, prepare already-loaded chapter=2, final play check=3.
          if (checks == 3) {
            started.complete();
            await release.future;
          }
        },
      );
      addTearDown(controller.dispose);
      await controller.loadBook(_book, position: const Duration(seconds: 42));
      final playing = controller.play();
      await started.future;
      final pausing = controller.pause();
      release.complete();
      await Future.wait([playing, pausing]);
      expect(engine.playCount, 0);
      expect(controller.state.status, AudioPlaybackStatus.paused);
      expect(controller.state.position, const Duration(seconds: 42));
    },
  );

  test(
    'remote resolver composition preserves the denial code without media details',
    () async {
      final fixture = await _fixture(allowed: false);
      await expectLater(
        ensureRemotePlaybackAllowedByPolicy(
          SourceAccessPolicy(fixture.store),
          'izib',
        ),
        throwsA(
          isA<AudioEngineException>().having(
            (error) => error.message,
            'code',
            'source_streaming_disabled',
          ),
        ),
      );
    },
  );
}

Future<
  ({
    PlaybackController controller,
    RecordingAudioEngine engine,
    SourceSettingsStore store,
  })
>
_fixture({
  bool allowed = true,
  PlaybackBookResolver? retry,
  RecordingAudioEngine? engine,
}) async {
  final store = SourceSettingsStore(MemorySourceSettingsPersistenceStore());
  addTearDown(store.dispose);
  await store.setMediaPermissions('izib', allowStreaming: allowed);
  final policy = SourceAccessPolicy(store);
  final decoder = engine ?? RecordingAudioEngine();
  final controller = PlaybackController(
    engine: decoder,
    playbackAccessGuard: (book, chapter) =>
        ensurePlaybackAllowedByPolicy(policy, book, chapter),
    playbackErrorBookResolver: retry,
  );
  addTearDown(controller.dispose);
  return (controller: controller, engine: decoder, store: store);
}

class _GatedLoadEngine extends RecordingAudioEngine {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    await super.load(chapter, position: position, book: book);
    started.complete();
    await release.future;
  }
}
