import 'dart:async';

import 'audio_state.dart';

class AudioEngineException implements Exception {
  const AudioEngineException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    final errorCause = cause;
    if (errorCause == null) {
      return 'AudioEngineException: $message';
    }

    return 'AudioEngineException: $message ($errorCause)';
  }
}

abstract interface class AudioEngine {
  Stream<AudioEngineSnapshot> get snapshots;

  /// Loads a chapter in a paused state. Playback starts only through [play],
  /// even if a previous chapter was playing before this call.
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setSpeed(double speed);

  Future<void> setVolume(double volume);

  Future<void> dispose();
}

class AudioEngineChapterNavigationCallbacks {
  const AudioEngineChapterNavigationCallbacks({
    this.onPlay,
    this.onPause,
    this.onSeek,
    this.onPreviousChapter,
    this.onNextChapter,
  });

  final Future<void> Function()? onPreviousChapter;
  final Future<void> Function()? onNextChapter;
  final Future<void> Function()? onPlay;
  final Future<void> Function()? onPause;
  final Future<void> Function(Duration position)? onSeek;
}

abstract interface class AudioEngineChapterNavigationBinding {
  void bindChapterNavigation(AudioEngineChapterNavigationCallbacks callbacks);
}

enum AudioEngineProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
  error,
}

class AudioEngineSnapshot {
  const AudioEngineSnapshot({
    required this.position,
    required this.processingState,
    required this.isPlaying,
    this.duration,
    this.errorMessage,
  });

  final Duration position;
  final AudioEngineProcessingState processingState;
  final bool isPlaying;
  final Duration? duration;
  final String? errorMessage;
}

class InMemoryAudioEngine implements AudioEngine {
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  AudioPlaybackChapter? loadedChapter;
  AudioPlaybackBook? loadedBook;
  Duration position = Duration.zero;
  double speed = 1;
  double volume = 1;
  bool isPlaying = false;
  bool _disposed = false;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    loadedChapter = chapter;
    loadedBook = book;
    this.position = position;
    isPlaying = false;
    _emit(AudioEngineProcessingState.ready);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _emit(AudioEngineProcessingState.ready);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    _emit(AudioEngineProcessingState.ready);
  }

  @override
  Future<void> seek(Duration position) async {
    this.position = position;
    _emit(AudioEngineProcessingState.ready);
  }

  @override
  Future<void> setSpeed(double speed) async {
    this.speed = speed;
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _snapshots.close();
  }

  void _emit(AudioEngineProcessingState processingState) {
    if (_snapshots.isClosed) {
      return;
    }

    _snapshots.add(
      AudioEngineSnapshot(
        position: position,
        processingState: processingState,
        isPlaying: isPlaying,
      ),
    );
  }
}

class SwitchingAudioEngine
    implements AudioEngine, AudioEngineChapterNavigationBinding {
  SwitchingAudioEngine({
    required AudioEngine primary,
    required AudioEngine fallback,
  }) : _primary = primary,
       _fallback = fallback,
       _active = fallback {
    _activeSubscription = _active.snapshots.listen(_snapshots.add);
  }

  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  final AudioEngine _primary;
  final AudioEngine _fallback;
  AudioEngine _active;
  late StreamSubscription<AudioEngineSnapshot> _activeSubscription;
  bool _disposed = false;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _activeSubscription.cancel();
    await _primary.dispose();
    if (!identical(_primary, _fallback)) {
      await _fallback.dispose();
    }
    await _snapshots.close();
  }

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    final nextActive = chapter.mediaSource == null ? _fallback : _primary;
    if (!identical(_active, nextActive)) {
      await _active.pause();
      await _activeSubscription.cancel();
      _active = nextActive;
      _activeSubscription = _active.snapshots.listen(_snapshots.add);
    }

    await _active.load(chapter, position: position, book: book);
  }

  @override
  Future<void> pause() {
    return _active.pause();
  }

  @override
  Future<void> play() {
    return _active.play();
  }

  @override
  Future<void> seek(Duration position) {
    return _active.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) {
    return _active.setSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) {
    return _active.setVolume(volume);
  }

  @override
  void bindChapterNavigation(AudioEngineChapterNavigationCallbacks callbacks) {
    final primary = _primary;
    if (primary is AudioEngineChapterNavigationBinding) {
      (primary as AudioEngineChapterNavigationBinding).bindChapterNavigation(
        callbacks,
      );
    }
    final fallback = _fallback;
    if (fallback is AudioEngineChapterNavigationBinding) {
      (fallback as AudioEngineChapterNavigationBinding).bindChapterNavigation(
        callbacks,
      );
    }
  }
}
