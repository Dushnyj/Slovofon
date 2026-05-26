import 'dart:async';

import 'package:audio_service/audio_service.dart' as background_audio;
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/slovofon_audio_handler.dart';

void main() {
  group('SlovofonAudioHandler', () {
    test('publishes book metadata and delegates chapter loading', () async {
      final engine = RecordingAudioEngine();
      final handler = SlovofonAudioHandler(engine: engine);

      await handler.loadChapter(
        _book,
        _book.chapters.first,
        position: const Duration(seconds: 12),
      );

      expect(engine.loadedChapterIds, ['chapter-1']);
      expect(engine.loadedPositions, [const Duration(seconds: 12)]);
      expect(handler.mediaItem.value?.id, 'chapter-1');
      expect(handler.mediaItem.value?.album, 'Мастер и Маргарита');
      expect(handler.mediaItem.value?.title, 'Глава 1');
      expect(handler.mediaItem.value?.artist, 'Михаил Булгаков');
      expect(handler.mediaItem.value?.displaySubtitle, 'Вячеслав Герасимов');
      expect(
        handler.playbackState.value.processingState,
        background_audio.AudioProcessingState.ready,
      );
    });

    test('updates system playback state for play and pause', () async {
      final engine = RecordingAudioEngine();
      final handler = SlovofonAudioHandler(engine: engine);

      await handler.loadChapter(
        _book,
        _book.chapters.first,
        position: Duration.zero,
      );
      await handler.play();

      expect(engine.playCount, 1);
      expect(handler.playbackState.value.playing, isTrue);

      await handler.pause();

      expect(engine.pauseCount, 1);
      expect(handler.playbackState.value.playing, isFalse);
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
  ],
);

class RecordingAudioEngine implements AudioEngine {
  final loadedChapterIds = <String>[];
  final loadedPositions = <Duration>[];
  int playCount = 0;
  int pauseCount = 0;

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
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}
}
