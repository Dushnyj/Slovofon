import 'dart:async';

import 'package:just_audio/just_audio.dart' as just_audio;

import 'audio_engine.dart';
import 'audio_state.dart';

class AudioLoadRequest {
  const AudioLoadRequest({required this.source, required this.initialPosition});

  final AudioMediaSource source;
  final Duration initialPosition;
}

abstract interface class JustAudioPlayerAdapter {
  Stream<Duration> get positionStream;

  Stream<Duration?> get durationStream;

  Stream<JustAudioAdapterSnapshot> get playbackSnapshots;

  Future<void> load(AudioLoadRequest request);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setSpeed(double speed);

  Future<void> setVolume(double volume);

  Future<void> dispose();
}

enum JustAudioAdapterProcessingState {
  idle,
  loading,
  buffering,
  ready,
  completed,
  error,
}

class JustAudioAdapterSnapshot {
  const JustAudioAdapterSnapshot({
    required this.processingState,
    required this.isPlaying,
    this.errorMessage,
  });

  final JustAudioAdapterProcessingState processingState;
  final bool isPlaying;
  final String? errorMessage;
}

class PackageJustAudioPlayerAdapter implements JustAudioPlayerAdapter {
  PackageJustAudioPlayerAdapter({just_audio.AudioPlayer? player})
    : _player = player ?? just_audio.AudioPlayer() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      _playbackSnapshots.add(
        JustAudioAdapterSnapshot(
          processingState: _processingState(state.processingState),
          isPlaying: state.playing,
        ),
      );
    });
    // just_audio 0.10 reports runtime failures as values on errorStream, not
    // playbackEventStream.onError. Without this subscription a network/decoder
    // failure after load never reaches the controller's recoverable error state.
    _errorSubscription = _player.errorStream.listen((error) {
      _playbackSnapshots.add(
        JustAudioAdapterSnapshot(
          processingState: JustAudioAdapterProcessingState.error,
          isPlaying: false,
          errorMessage: _errorMessage(error),
        ),
      );
    });
  }

  final just_audio.AudioPlayer _player;
  final _playbackSnapshots =
      StreamController<JustAudioAdapterSnapshot>.broadcast();
  late final StreamSubscription<just_audio.PlayerState>
  _playerStateSubscription;
  late final StreamSubscription<just_audio.PlayerException> _errorSubscription;
  bool _disposed = false;

  @override
  Stream<JustAudioAdapterSnapshot> get playbackSnapshots =>
      _playbackSnapshots.stream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _playerStateSubscription.cancel();
    await _errorSubscription.cancel();
    await _playbackSnapshots.close();
    await _player.dispose();
  }

  @override
  Future<void> load(AudioLoadRequest request) async {
    final source = request.source;

    switch (source.type) {
      case AudioMediaSourceType.url:
        await _player.setUrl(
          source.uri.toString(),
          headers: source.headers.isEmpty ? null : source.headers,
          initialPosition: request.initialPosition,
        );
      case AudioMediaSourceType.file:
        await _player.setFilePath(
          source.filePath,
          initialPosition: request.initialPosition,
        );
      case AudioMediaSourceType.asset:
        await _player.setAsset(
          source.assetPath,
          initialPosition: request.initialPosition,
        );
    }
  }

  @override
  Future<void> pause() {
    return _player.pause();
  }

  @override
  Future<void> play() {
    return _player.play();
  }

  @override
  Future<void> seek(Duration position) {
    return _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) {
    return _player.setSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) {
    return _player.setVolume(volume);
  }

  JustAudioAdapterProcessingState _processingState(
    just_audio.ProcessingState state,
  ) {
    switch (state) {
      case just_audio.ProcessingState.idle:
        return JustAudioAdapterProcessingState.idle;
      case just_audio.ProcessingState.loading:
        return JustAudioAdapterProcessingState.loading;
      case just_audio.ProcessingState.buffering:
        return JustAudioAdapterProcessingState.buffering;
      case just_audio.ProcessingState.ready:
        return JustAudioAdapterProcessingState.ready;
      case just_audio.ProcessingState.completed:
        return JustAudioAdapterProcessingState.completed;
    }
  }

  String _errorMessage(Object error) {
    if (error is just_audio.PlayerException) {
      return error.message ?? 'Audio playback failed.';
    }

    return 'Audio playback failed.';
  }
}

class JustAudioEngine implements AudioEngine {
  JustAudioEngine({JustAudioPlayerAdapter? player})
    : _player = player ?? PackageJustAudioPlayerAdapter() {
    _positionSubscription = _player.positionStream.listen((position) {
      _position = position;
      if (_shouldEmitPosition(position)) {
        _emit();
      }
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      _duration = duration;
      _emit();
    });
    _playbackSubscription = _player.playbackSnapshots.listen((snapshot) {
      _processingState = _processingStateFromAdapter(snapshot.processingState);
      _isPlaying = snapshot.isPlaying;
      _errorMessage = snapshot.errorMessage;
      _emit();
    });
  }

  final JustAudioPlayerAdapter _player;
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<JustAudioAdapterSnapshot> _playbackSubscription;
  Duration _position = Duration.zero;
  Duration? _duration;
  Duration? _lastEmittedPosition;
  AudioEngineProcessingState _processingState = AudioEngineProcessingState.idle;
  bool _isPlaying = false;
  String? _errorMessage;
  bool _disposed = false;
  static const _positionEmitInterval = Duration(seconds: 1);

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _positionSubscription.cancel();
    await _durationSubscription.cancel();
    await _playbackSubscription.cancel();
    await _snapshots.close();
    await _player.dispose();
  }

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) async {
    // setUrl/setFilePath preserve just_audio's existing playWhenReady state.
    // Loading is explicitly paused in our engine contract: the controller alone
    // decides whether to resume after its load/seek generation still wins.
    // Stop the previous source even when the new chapter has no playable media.
    await _player.pause();
    _isPlaying = false;
    final mediaSource = chapter.mediaSource;
    if (mediaSource == null) {
      throw AudioEngineException(
        'Chapter "${chapter.id}" has no playable media source.',
      );
    }

    // Seed before loading: a decoder duration discovered during load wins over
    // catalogue metadata (and durationStream may never emit it a second time).
    _position = position;
    _duration = chapter.duration > Duration.zero ? chapter.duration : null;
    _processingState = AudioEngineProcessingState.loading;
    _errorMessage = null;
    _emit();
    await _player.load(
      AudioLoadRequest(source: mediaSource, initialPosition: position),
    );
    if (position > Duration.zero) {
      await _player.seek(position);
    }
    _position = position;
    _emit();
  }

  @override
  Future<void> pause() {
    _isPlaying = false;
    _emit();
    return _player.pause();
  }

  @override
  Future<void> play() {
    _isPlaying = true;
    _emit();
    return _player.play();
  }

  @override
  Future<void> seek(Duration position) {
    _position = position;
    _emit();
    return _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) {
    return _player.setSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) {
    return _player.setVolume(volume);
  }

  void _emit() {
    if (_snapshots.isClosed) {
      return;
    }

    _lastEmittedPosition = _position;
    _snapshots.add(
      AudioEngineSnapshot(
        position: _position,
        processingState: _processingState,
        isPlaying: _isPlaying,
        duration: _duration,
        errorMessage: _errorMessage,
      ),
    );
  }

  bool _shouldEmitPosition(Duration position) {
    final lastEmitted = _lastEmittedPosition;
    if (lastEmitted == null) {
      return true;
    }

    if ((position - lastEmitted).abs() >= _positionEmitInterval) {
      return true;
    }

    final duration = _duration;
    return duration != null &&
        duration > Duration.zero &&
        position >= duration - _positionEmitInterval;
  }

  AudioEngineProcessingState _processingStateFromAdapter(
    JustAudioAdapterProcessingState state,
  ) {
    switch (state) {
      case JustAudioAdapterProcessingState.idle:
        return AudioEngineProcessingState.idle;
      case JustAudioAdapterProcessingState.loading:
        return AudioEngineProcessingState.loading;
      case JustAudioAdapterProcessingState.buffering:
        return AudioEngineProcessingState.buffering;
      case JustAudioAdapterProcessingState.ready:
        return AudioEngineProcessingState.ready;
      case JustAudioAdapterProcessingState.completed:
        return AudioEngineProcessingState.completed;
      case JustAudioAdapterProcessingState.error:
        return AudioEngineProcessingState.error;
    }
  }
}
