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
  static const _seekStep = Duration(seconds: 30);
  static const _appName = 'Словофон';
  static const _previousChapterControl = background_audio.MediaControl(
    androidIcon: 'drawable/audio_service_previous',
    label: 'Предыдущая глава',
    action: background_audio.MediaAction.skipToPrevious,
  );
  static const _playControl = background_audio.MediaControl(
    androidIcon: 'drawable/audio_service_play',
    label: 'Воспроизвести',
    action: background_audio.MediaAction.play,
  );
  static const _pauseControl = background_audio.MediaControl(
    androidIcon: 'drawable/audio_service_pause',
    label: 'Пауза',
    action: background_audio.MediaAction.pause,
  );
  static const _rewind30Control = background_audio.MediaControl(
    androidIcon: 'drawable/audio_service_rewind',
    label: 'Перемотать назад',
    action: background_audio.MediaAction.rewind,
  );
  static const _forward30Control = background_audio.MediaControl(
    androidIcon: 'drawable/audio_service_forward',
    label: 'Перемотать вперёд',
    action: background_audio.MediaAction.fastForward,
  );
  static const _nextChapterControl = background_audio.MediaControl(
    androidIcon: 'drawable/audio_service_next',
    label: 'Следующая глава',
    action: background_audio.MediaAction.skipToNext,
  );
  late final StreamSubscription<AudioEngineSnapshot> _engineSubscription;
  AudioEngineChapterNavigationCallbacks? _chapterNavigation;
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
        id: '${book.versionId}:${chapter.id}',
        album: _appName,
        title: book.title,
        artist: _chapterNotificationTitle(chapter),
        artUri: _artUri(book.coverUrl),
        displayTitle: book.title,
        displaySubtitle: _chapterNotificationTitle(chapter),
        displayDescription: _appName,
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
    final target = _clampPosition(position);
    await _engine.seek(target);
    playbackState.add(_state(updatePosition: target));
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _engine.setSpeed(speed);
    playbackState.add(_state(speed: speed));
  }

  @override
  Future<void> rewind() async {
    await seek(_currentPosition() - _seekStep);
  }

  @override
  Future<void> fastForward() async {
    await seek(_currentPosition() + _seekStep);
  }

  @override
  Future<void> stop() async {
    final position = _currentPosition();
    await _engine.pause();
    playbackState.add(
      _state(
        playing: false,
        updatePosition: position,
        processingState: background_audio.AudioProcessingState.idle,
      ),
    );
    await super.stop();
  }

  void bindChapterNavigation(AudioEngineChapterNavigationCallbacks callbacks) {
    _chapterNavigation = callbacks;
  }

  @override
  Future<void> skipToPrevious() async {
    final callback = _chapterNavigation?.onPreviousChapter;
    if (callback != null) {
      await callback();
    }
  }

  @override
  Future<void> skipToNext() async {
    final callback = _chapterNavigation?.onNextChapter;
    if (callback != null) {
      await callback();
    }
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
        _previousChapterControl,
        _rewind30Control,
        isPlaying ? _pauseControl : _playControl,
        _forward30Control,
        _nextChapterControl,
      ],
      androidCompactActionIndices: const [0, 2, 4],
      processingState:
          processingState ??
          current?.processingState ??
          background_audio.AudioProcessingState.idle,
      playing: isPlaying,
      speed: speed ?? current?.speed ?? 1,
      updatePosition:
          updatePosition ?? current?.updatePosition ?? Duration.zero,
      systemActions: const {
        background_audio.MediaAction.rewind,
        background_audio.MediaAction.fastForward,
        background_audio.MediaAction.skipToPrevious,
        background_audio.MediaAction.skipToNext,
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

  Uri? _artUri(String? coverUrl) {
    final value = coverUrl?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return Uri.tryParse(value);
  }

  String _chapterNotificationTitle(AudioPlaybackChapter chapter) {
    final title = chapter.title.trim();
    if (title.isEmpty) {
      return 'Текущая глава';
    }
    return title;
  }

  Duration _currentPosition() {
    final state = playbackState.valueOrNull;
    return state?.position ?? state?.updatePosition ?? Duration.zero;
  }

  Duration _clampPosition(Duration position) {
    if (position <= Duration.zero) {
      return Duration.zero;
    }
    final duration = mediaItem.valueOrNull?.duration;
    if (duration != null && duration > Duration.zero && position > duration) {
      return duration;
    }
    return position;
  }
}

class AudioHandlerEngine
    implements AudioEngine, AudioEngineChapterNavigationBinding {
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

  @override
  void bindChapterNavigation(AudioEngineChapterNavigationCallbacks callbacks) {
    _handler.bindChapterNavigation(callbacks);
  }
}
