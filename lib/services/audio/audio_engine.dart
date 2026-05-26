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

  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  });

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setSpeed(double speed);

  Future<void> dispose();
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
    this.errorMessage,
  });

  final Duration position;
  final AudioEngineProcessingState processingState;
  final bool isPlaying;
  final String? errorMessage;
}

class InMemoryAudioEngine implements AudioEngine {
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  AudioPlaybackChapter? loadedChapter;
  AudioPlaybackBook? loadedBook;
  Duration position = Duration.zero;
  double speed = 1;
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

class SwitchingAudioEngine implements AudioEngine {
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
}
