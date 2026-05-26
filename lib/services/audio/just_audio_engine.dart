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

  Stream<JustAudioAdapterSnapshot> get playbackSnapshots;

  Future<void> load(AudioLoadRequest request);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> setSpeed(double speed);

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
    _playbackEventSubscription = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _playbackSnapshots.add(
          JustAudioAdapterSnapshot(
            processingState: JustAudioAdapterProcessingState.error,
            isPlaying: false,
            errorMessage: _errorMessage(error),
          ),
        );
      },
    );
  }

  final just_audio.AudioPlayer _player;
  final _playbackSnapshots =
      StreamController<JustAudioAdapterSnapshot>.broadcast();
  late final StreamSubscription<just_audio.PlayerState>
  _playerStateSubscription;
  late final StreamSubscription<just_audio.PlaybackEvent>
  _playbackEventSubscription;
  bool _disposed = false;

  @override
  Stream<JustAudioAdapterSnapshot> get playbackSnapshots =>
      _playbackSnapshots.stream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _playerStateSubscription.cancel();
    await _playbackEventSubscription.cancel();
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
  late final StreamSubscription<JustAudioAdapterSnapshot> _playbackSubscription;
  Duration _position = Duration.zero;
  AudioEngineProcessingState _processingState = AudioEngineProcessingState.idle;
  bool _isPlaying = false;
  String? _errorMessage;
  bool _disposed = false;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _positionSubscription.cancel();
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
    final mediaSource = chapter.mediaSource;
    if (mediaSource == null) {
      throw AudioEngineException(
        'Chapter "${chapter.id}" has no playable media source.',
      );
    }

    await _player.load(
      AudioLoadRequest(source: mediaSource, initialPosition: position),
    );
    _position = position;
    _emit();
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
    _position = position;
    _emit();
    return _player.seek(position);
  }

  @override
  Future<void> setSpeed(double speed) {
    return _player.setSpeed(speed);
  }

  void _emit() {
    if (_snapshots.isClosed) {
      return;
    }

    _snapshots.add(
      AudioEngineSnapshot(
        position: _position,
        processingState: _processingState,
        isPlaying: _isPlaying,
        errorMessage: _errorMessage,
      ),
    );
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
