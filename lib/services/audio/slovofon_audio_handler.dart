import 'dart:async';

import 'package:audio_service/audio_service.dart' as background_audio;

import 'audio_engine.dart';
import 'audio_state.dart';

class SlovofonAudioHandler extends background_audio.BaseAudioHandler
    with background_audio.SeekHandler {
  SlovofonAudioHandler({required AudioEngine engine}) : _engine = engine {
    playbackState.add(_state());
    _engineSubscription = _engine.snapshots.listen(_handleEngineSnapshot);
  }

  final AudioEngine _engine;
  late final StreamSubscription<AudioEngineSnapshot> _engineSubscription;
  bool _disposed = false;

  Stream<AudioEngineSnapshot> get snapshots => _engine.snapshots;

  Future<void> loadChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    required Duration position,
  }) async {
    await _engine.load(chapter, position: position, book: book);

    mediaItem.add(
      background_audio.MediaItem(
        id: chapter.id,
        album: book.title,
        title: chapter.title,
        artist: book.author,
        displayTitle: book.title,
        displaySubtitle: book.narrator,
        duration: chapter.duration,
        extras: {
          'bookId': book.id,
          'bookVersionId': book.versionId,
          'sourceId': book.sourceId,
          'sourceName': book.sourceName,
          'chapterIndex': chapter.index,
        },
      ),
    );

    playbackState.add(
      _state(
        processingState: background_audio.AudioProcessingState.ready,
        updatePosition: position,
      ),
    );
  }

  @override
  Future<void> pause() async {
    await _engine.pause();
    playbackState.add(_state(playing: false));
  }

  @override
  Future<void> play() async {
    await _engine.play();
    playbackState.add(_state(playing: true));
  }

  @override
  Future<void> seek(Duration position) async {
    await _engine.seek(position);
    playbackState.add(_state(updatePosition: position));
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _engine.setSpeed(speed);
    playbackState.add(_state(speed: speed));
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _engineSubscription.cancel();
    await _engine.dispose();
  }

  background_audio.PlaybackState _state({
    bool? playing,
    double? speed,
    Duration? updatePosition,
    background_audio.AudioProcessingState? processingState,
  }) {
    final current = playbackState.valueOrNull;
    final isPlaying = playing ?? current?.playing ?? false;

    return background_audio.PlaybackState(
      controls: [
        background_audio.MediaControl.skipToPrevious,
        isPlaying
            ? background_audio.MediaControl.pause
            : background_audio.MediaControl.play,
        background_audio.MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState:
          processingState ??
          current?.processingState ??
          background_audio.AudioProcessingState.idle,
      playing: isPlaying,
      speed: speed ?? current?.speed ?? 1,
      updatePosition:
          updatePosition ?? current?.updatePosition ?? Duration.zero,
      systemActions: const {
        background_audio.MediaAction.seek,
        background_audio.MediaAction.seekForward,
        background_audio.MediaAction.seekBackward,
      },
    );
  }

  void _handleEngineSnapshot(AudioEngineSnapshot snapshot) {
    playbackState.add(
      _state(
        playing: snapshot.isPlaying,
        updatePosition: snapshot.position,
        processingState: _processingState(snapshot.processingState),
      ),
    );
  }

  background_audio.AudioProcessingState _processingState(
    AudioEngineProcessingState state,
  ) {
    switch (state) {
      case AudioEngineProcessingState.idle:
        return background_audio.AudioProcessingState.idle;
      case AudioEngineProcessingState.loading:
        return background_audio.AudioProcessingState.loading;
      case AudioEngineProcessingState.buffering:
        return background_audio.AudioProcessingState.buffering;
      case AudioEngineProcessingState.ready:
        return background_audio.AudioProcessingState.ready;
      case AudioEngineProcessingState.completed:
        return background_audio.AudioProcessingState.completed;
      case AudioEngineProcessingState.error:
        return background_audio.AudioProcessingState.error;
    }
  }
}

class AudioHandlerEngine implements AudioEngine {
  AudioHandlerEngine(this._handler);

  final SlovofonAudioHandler _handler;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _handler.snapshots;

  @override
  Future<void> dispose() {
    return _handler.dispose();
  }

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) {
    final activeBook = book;
    if (activeBook == null) {
      throw const AudioEngineException(
        'AudioHandlerEngine requires book metadata to load a chapter.',
      );
    }

    return _handler.loadChapter(activeBook, chapter, position: position);
  }

  @override
  Future<void> pause() {
    return _handler.pause();
  }

  @override
  Future<void> play() {
    return _handler.play();
  }

  @override
  Future<void> seek(Duration position) {
    return _handler.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) {
    return _handler.setSpeed(speed);
  }
}
