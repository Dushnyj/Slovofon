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
      expect(handler.mediaItem.value?.id, 'version-1:chapter-1');
      expect(handler.mediaItem.value?.album, 'Словофон');
      expect(handler.mediaItem.value?.title, 'Мастер и Маргарита');
      expect(handler.mediaItem.value?.artist, 'Глава 1');
      expect(handler.mediaItem.value?.displayTitle, 'Мастер и Маргарита');
      expect(handler.mediaItem.value?.displaySubtitle, 'Глава 1');
      expect(handler.mediaItem.value?.displayDescription, 'Словофон');
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

    test('publishes expanded notification controls', () async {
      final engine = RecordingAudioEngine();
      final handler = SlovofonAudioHandler(engine: engine);

      await handler.loadChapter(
        _book,
        _book.chapters.first,
        position: Duration.zero,
      );

      expect(
        handler.playbackState.value.controls.map((control) => control.action),
        [
          background_audio.MediaAction.skipToPrevious,
          background_audio.MediaAction.rewind,
          background_audio.MediaAction.play,
          background_audio.MediaAction.fastForward,
          background_audio.MediaAction.skipToNext,
        ],
      );
      expect(handler.playbackState.value.androidCompactActionIndices, [
        0,
        2,
        4,
      ]);
      expect(
        handler.playbackState.value.controls.map(
          (control) => control.androidIcon,
        ),
        [
          'drawable/audio_service_previous',
          'drawable/audio_service_rewind',
          'drawable/audio_service_play',
          'drawable/audio_service_forward',
          'drawable/audio_service_next',
        ],
      );
      expect(
        handler.playbackState.value.controls[1].androidIcon,
        contains('rewind'),
      );
      expect(
        handler.playbackState.value.controls[3].androidIcon,
        contains('forward'),
      );
      expect(
        handler.playbackState.value.systemActions,
        containsAll([
          background_audio.MediaAction.rewind,
          background_audio.MediaAction.fastForward,
          background_audio.MediaAction.skipToPrevious,
          background_audio.MediaAction.skipToNext,
          background_audio.MediaAction.seek,
        ]),
      );
      expect(
        handler.playbackState.value.systemActions,
        isNot(contains(background_audio.MediaAction.stop)),
      );
    });

    test('notification rewind forward and stop delegate to engine', () async {
      final engine = RecordingAudioEngine();
      final handler = SlovofonAudioHandler(engine: engine);

      await handler.loadChapter(
        _book,
        _book.chapters.first,
        position: const Duration(minutes: 2),
      );

      await handler.rewind();
      await handler.fastForward();
      await handler.stop();

      expect(engine.seekPositions, [
        const Duration(seconds: 90),
        const Duration(minutes: 2),
      ]);
      expect(engine.pauseCount, 1);
      expect(handler.playbackState.value.playing, isFalse);
      expect(
        handler.playbackState.value.processingState,
        background_audio.AudioProcessingState.idle,
      );
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
  final seekPositions = <Duration>[];
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
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {}
}
