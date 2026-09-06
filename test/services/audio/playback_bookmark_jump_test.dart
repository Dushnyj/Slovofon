import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';

import 'playback_controller_test.dart' show RecordingAudioEngine;

AudioPlaybackBook _book(String id) => AudioPlaybackBook(
  id: id,
  versionId: 'version-$id',
  sourceId: 'fixture',
  sourceName: 'Fixture',
  title: id,
  author: 'Author',
  narrator: 'Narrator',
  chapters: List.generate(
    3,
    (index) => AudioPlaybackChapter(
      id: '$id-$index',
      index: index,
      title: 'Chapter $index',
      duration: const Duration(minutes: 10),
    ),
  ),
);

void main() {
  for (final play in [true, false]) {
    test(
      'bookmark jump loads exact position atomically and preserves options play=$play',
      () async {
        final engine = RecordingAudioEngine();
        final service = PlaybackController(engine: engine);
        addTearDown(service.dispose);
        await service.loadBook(_book('a'));
        await service.setSpeed(1.5);
        await service.setVolume(.37);
        service.setSleepTimer(const Duration(minutes: 45));
        await service.seekChapterAt(
          2,
          const Duration(minutes: 3, seconds: 12),
          play: play,
        );
        expect(service.state.chapterIndex, 2);
        expect(service.state.position, const Duration(minutes: 3, seconds: 12));
        expect(service.state.isPlaying, play);
        expect(engine.loadedChapterIds.last, 'a-2');
        expect(
          engine.loadedPositions.last,
          const Duration(minutes: 3, seconds: 12),
        );
        expect(
          engine.seekPositions,
          isEmpty,
          reason: 'No separate post-load seek race',
        );
        expect(service.state.speed, 1.5);
        expect(service.state.volume, .37);
        expect(service.state.sleepTimerRemaining, isNotNull);
        expect(engine.speedValues.last, 1.5);
        expect(engine.volumeValues.last, .37);
      },
    );
  }

  test(
    'late bookmark load cannot overwrite a newer chapter and position',
    () async {
      final engine = _GatedSecondLoad();
      final service = PlaybackController(engine: engine);
      addTearDown(service.dispose);
      await service.loadBook(_book('a'));
      final first = service.seekChapterAt(1, const Duration(minutes: 3));
      await engine.started.future;
      final second = service.seekChapterAt(
        2,
        const Duration(minutes: 7),
        play: false,
      );
      engine.release.complete();
      await Future.wait([first, second]);
      expect(service.state.chapterIndex, 2);
      expect(service.state.position, const Duration(minutes: 7));
      expect(service.state.isPlaying, isFalse);
      expect(engine.loadedChapterIds.last, 'a-2');
      expect(engine.loadedPositions.last, const Duration(minutes: 7));
      expect(
        engine.playCount,
        0,
        reason: 'The stale bookmark operation must not start audio',
      );
    },
  );

  test('late bookmark load cannot replace a newly selected book', () async {
    final engine = _GatedSecondLoad();
    final service = PlaybackController(engine: engine);
    addTearDown(service.dispose);
    await service.loadBook(_book('a'));
    final jump = service.seekChapterAt(1, const Duration(minutes: 3));
    await engine.started.future;
    final nextBook = service.loadBook(_book('b'));
    engine.release.complete();
    await Future.wait([jump, nextBook]);
    expect(service.state.book!.id, 'b');
    expect(service.state.chapterIndex, 0);
    expect(service.state.position, Duration.zero);
    expect(engine.loadedChapterIds.last, 'b-0');
    expect(engine.playCount, 0);
  });
}

class _GatedSecondLoad extends RecordingAudioEngine {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    await super.load(chapter, position: position, book: book);
    if (loadedChapterIds.length == 2) {
      started.complete();
      await release.future;
    }
  }
}
