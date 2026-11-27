import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_engine.dart';
import 'audio_focus.dart';
import 'audio_state.dart';

enum AndroidMediaSessionCommandType {
  play,
  pause,
  stop,
  seek,
  rewind,
  fastForward,
  previousChapter,
  nextChapter,
}

class AndroidMediaSessionCommand {
  const AndroidMediaSessionCommand._(this.type, {this.position});

  const AndroidMediaSessionCommand.play()
    : this._(AndroidMediaSessionCommandType.play);

  const AndroidMediaSessionCommand.pause()
    : this._(AndroidMediaSessionCommandType.pause);

  const AndroidMediaSessionCommand.stop()
    : this._(AndroidMediaSessionCommandType.stop);

  const AndroidMediaSessionCommand.seek(Duration position)
    : this._(AndroidMediaSessionCommandType.seek, position: position);

  const AndroidMediaSessionCommand.rewind()
    : this._(AndroidMediaSessionCommandType.rewind);

  const AndroidMediaSessionCommand.fastForward()
    : this._(AndroidMediaSessionCommandType.fastForward);

  const AndroidMediaSessionCommand.previousChapter()
    : this._(AndroidMediaSessionCommandType.previousChapter);

  const AndroidMediaSessionCommand.nextChapter()
    : this._(AndroidMediaSessionCommandType.nextChapter);

  final AndroidMediaSessionCommandType type;
  final Duration? position;

  static AndroidMediaSessionCommand? fromMap(Map<Object?, Object?> map) {
    final name = map['name'] as String?;
    return switch (name) {
      'play' => const AndroidMediaSessionCommand.play(),
      'pause' => const AndroidMediaSessionCommand.pause(),
      'stop' => const AndroidMediaSessionCommand.stop(),
      'rewind' => const AndroidMediaSessionCommand.rewind(),
      'fastForward' => const AndroidMediaSessionCommand.fastForward(),
      'previousChapter' => const AndroidMediaSessionCommand.previousChapter(),
      'nextChapter' => const AndroidMediaSessionCommand.nextChapter(),
      'seek' => AndroidMediaSessionCommand.seek(
        Duration(milliseconds: (map['positionMs'] as num? ?? 0).round()),
      ),
      _ => null,
    };
  }
}

class AndroidMediaSessionSnapshot {
  const AndroidMediaSessionSnapshot({
    required this.appName,
    required this.bookTitle,
    required this.chapterTitle,
    required this.sourceName,
    required this.position,
    required this.duration,
    required this.processingState,
    required this.isPlaying,
    required this.playWhenReady,
    this.coverUrl,
    this.canSkipPrevious = true,
    this.canSkipNext = true,
    this.speed = 1,
  });

  final String appName;
  final String bookTitle;
  final String chapterTitle;
  final String sourceName;
  final String? coverUrl;
  final Duration position;
  final Duration duration;
  final AudioEngineProcessingState processingState;
  final bool isPlaying;
  final bool playWhenReady;
  final bool canSkipPrevious;
  final bool canSkipNext;
  final double speed;

  Map<String, Object?> toMap() {
    return {
      'appName': appName,
      'bookTitle': bookTitle,
      'chapterTitle': chapterTitle,
      'sourceName': sourceName,
      'coverUrl': coverUrl,
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      'processingState': processingState.name,
      'isPlaying': isPlaying,
      'playWhenReady': playWhenReady,
      'canSkipPrevious': canSkipPrevious,
      'canSkipNext': canSkipNext,
      'speed': speed,
    };
  }
}

abstract interface class AndroidMediaSessionPlatform {
  Stream<AndroidMediaSessionCommand> get commands;

  Future<void> update(AndroidMediaSessionSnapshot snapshot);

  Future<bool> preparePlayback(AndroidMediaSessionSnapshot snapshot);

  Future<void> clear();
}

class MethodChannelAndroidMediaSessionPlatform
    implements AndroidMediaSessionPlatform {
  MethodChannelAndroidMediaSessionPlatform({
    MethodChannel channel = _defaultChannel,
  }) : _channel = channel {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static const _defaultChannel = MethodChannel(
    'com.slovofon.app/media_session',
  );

  final MethodChannel _channel;
  final _commands = StreamController<AndroidMediaSessionCommand>.broadcast();

  @override
  Stream<AndroidMediaSessionCommand> get commands => _commands.stream;

  @override
  Future<void> clear() async {
    await _channel.invokeMethod<void>('clear');
  }

  @override
  Future<void> update(AndroidMediaSessionSnapshot snapshot) async {
    await _channel.invokeMethod<void>('update', snapshot.toMap());
  }

  @override
  Future<bool> preparePlayback(AndroidMediaSessionSnapshot snapshot) async {
    return await _channel.invokeMethod<bool>(
          'preparePlayback',
          snapshot.toMap(),
        ) ??
        false;
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    if (call.method != 'command') {
      return null;
    }

    final arguments = call.arguments;
    if (arguments is! Map<Object?, Object?>) {
      return null;
    }

    final command = AndroidMediaSessionCommand.fromMap(arguments);
    if (command != null && !_commands.isClosed) {
      _commands.add(command);
    }
    return null;
  }

  Future<void> dispose() async {
    _channel.setMethodCallHandler(null);
    await _commands.close();
  }
}

class AndroidMediaSessionEngine
    implements
        AudioEngine,
        AudioEngineChapterNavigationBinding,
        AudioEngineForegroundPlaybackBinding,
        AudioInterruptionSource {
  AndroidMediaSessionEngine({
    required AudioEngine delegate,
    required AndroidMediaSessionPlatform platform,
    this.appName = 'Slovofon',
    this.skipInterval = const Duration(seconds: 30),
    this.positionPublishInterval = const Duration(seconds: 5),
  }) : _delegate = delegate,
       _platform = platform {
    _delegateSubscription = _delegate.snapshots.listen(_handleSnapshot);
    _commandSubscription = _platform.commands.listen((command) {
      if (command.type == AndroidMediaSessionCommandType.pause ||
          command.type == AndroidMediaSessionCommandType.stop) {
        _commandEpoch++;
        // A user pause must invalidate a controller resolver/load immediately,
        // not wait behind chapter navigation in the native command queue.
        unawaited(
          _handleCommand(command).catchError(
            (Object error, StackTrace stack) => _reportCommandError(error),
          ),
        );
        return;
      }
      final epoch = _commandEpoch;
      _commandQueue = _commandQueue
          .then<void>((_) async {
            if (epoch == _commandEpoch) await _handleCommand(command);
          })
          .catchError(
            (Object error, StackTrace stack) => _reportCommandError(error),
          );
    });
  }

  final String appName;
  final Duration skipInterval;
  final Duration positionPublishInterval;
  final AudioEngine _delegate;
  final AndroidMediaSessionPlatform _platform;
  final _snapshots = StreamController<AudioEngineSnapshot>.broadcast();
  late final StreamSubscription<AudioEngineSnapshot> _delegateSubscription;
  late final StreamSubscription<AndroidMediaSessionCommand>
  _commandSubscription;
  AudioEngineChapterNavigationCallbacks _chapterNavigation =
      const AudioEngineChapterNavigationCallbacks();
  Future<void> _commandQueue = Future<void>.value();
  AudioPlaybackBook? _loadedBook;
  AudioPlaybackChapter? _loadedChapter;
  AudioEngineSnapshot _lastSnapshot = const AudioEngineSnapshot(
    position: Duration.zero,
    processingState: AudioEngineProcessingState.idle,
    isPlaying: false,
  );
  AndroidMediaSessionSnapshot? _lastPublishedSnapshot;
  bool _disposed = false;
  int _playGeneration = 0;
  int _startRequestGeneration = 0;
  int _commandEpoch = 0;
  double _speed = 1;
  bool _reportedPlatformFailure = false;
  bool _playWhenReady = false;
  Future<bool>? _preparingForeground;

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<AudioFocusEvent> get audioFocusEvents {
    final delegate = _delegate;
    return delegate is AudioInterruptionSource
        ? (delegate as AudioInterruptionSource).audioFocusEvents
        : const Stream.empty();
  }

  @override
  void bindChapterNavigation(AudioEngineChapterNavigationCallbacks callbacks) {
    _chapterNavigation = callbacks;
    final delegate = _delegate;
    if (delegate is AudioEngineChapterNavigationBinding) {
      (delegate as AudioEngineChapterNavigationBinding).bindChapterNavigation(
        callbacks,
      );
    }
  }

  @override
  Future<void> load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    AudioPlaybackBook? book,
  }) => _load(chapter, position: position, book: book, forPlayback: false);

  @override
  Future<void> loadForPlayback(
    AudioPlaybackChapter chapter, {
    required Duration position,
    required AudioPlaybackBook book,
  }) => _load(chapter, position: position, book: book, forPlayback: true);

  Future<void> _load(
    AudioPlaybackChapter chapter, {
    required Duration position,
    required AudioPlaybackBook? book,
    required bool forPlayback,
  }) async {
    final generation = ++_playGeneration;
    _startRequestGeneration++;
    _preparingForeground = null;
    _playWhenReady = forPlayback;
    _loadedChapter = chapter;
    _loadedBook = book;
    _lastSnapshot = AudioEngineSnapshot(
      position: position,
      processingState: AudioEngineProcessingState.loading,
      isPlaying: false,
      duration: chapter.duration,
    );
    final platformState = forPlayback ? _buildPlatformSnapshot() : null;
    if (platformState != null) {
      // Begin while the activity/user request is still in front, rather than
      // waiting for a slow network decoder load before asking Android to start.
      _preparingForeground = _ensureForeground(platformState);
    } else {
      unawaited(_publishToPlatform());
    }
    try {
      await _delegate.load(chapter, position: position, book: book);
    } catch (_) {
      if (!_disposed && generation == _playGeneration) {
        cancelPlaybackPreparation();
      }
      rethrow;
    }
  }

  @override
  void cancelPlaybackPreparation() {
    if (_preparingForeground == null) return;
    _preparingForeground = null;
    _playWhenReady = false;
    unawaited(_publishToPlatform());
  }

  @override
  Future<void> play() async {
    final generation = ++_playGeneration;
    _startRequestGeneration++;
    _playWhenReady = true;
    final preparing = _preparingForeground;
    _preparingForeground = null;
    var foregroundReady = preparing != null && await preparing;
    if (_disposed || generation != _playGeneration) return;
    final snapshot = _buildPlatformSnapshot(preparingPlayback: true);
    if (!foregroundReady && snapshot != null) {
      foregroundReady = await _ensureForeground(snapshot);
    }
    if (_disposed || generation != _playGeneration) return;
    if (!foregroundReady) {
      _playWhenReady = false;
      unawaited(_publishToPlatform());
      throw const AudioEngineException(
        'Android background playback unavailable.',
      );
    }
    // just_audio.play completes on pause/end, not on start. Never hold the
    // native command queue (including its Pause command) on that future.
    unawaited(
      _delegate.play().catchError((Object error, StackTrace stack) {
        if (!_disposed && generation == _playGeneration) {
          _playWhenReady = false;
          _reportCommandError(error);
        }
      }),
    );
  }

  @override
  Future<void> pause() async {
    _playGeneration++;
    _preparingForeground = null;
    _playWhenReady = false;
    _lastSnapshot = AudioEngineSnapshot(
      position: _lastSnapshot.position,
      duration: _effectiveDuration,
      processingState: _lastSnapshot.processingState,
      isPlaying: false,
      errorMessage: _lastSnapshot.errorMessage,
    );
    unawaited(_publishToPlatform());
    await _delegate.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    final clamped = _clampPosition(position);
    await _delegate.seek(clamped);
    _lastSnapshot = AudioEngineSnapshot(
      position: clamped,
      duration: _effectiveDuration,
      processingState: _lastSnapshot.processingState,
      isPlaying: _lastSnapshot.isPlaying,
      errorMessage: _lastSnapshot.errorMessage,
    );
    unawaited(_publishToPlatform());
  }

  @override
  Future<void> setSpeed(double speed) {
    _speed = speed;
    unawaited(_publishToPlatform());
    return _delegate.setSpeed(speed);
  }

  @override
  Future<void> setVolume(double volume) {
    return _delegate.setVolume(volume);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _playGeneration++;
    await _commandSubscription.cancel();
    await _commandQueue;
    await _delegateSubscription.cancel();
    await _clearPlatform();
    try {
      await _delegate.dispose();
    } finally {
      try {
        if (_platform
            case final MethodChannelAndroidMediaSessionPlatform platform) {
          await platform.dispose();
        }
      } finally {
        await _snapshots.close();
      }
    }
  }

  Future<void> _handleCommand(AndroidMediaSessionCommand command) async {
    if (_disposed) {
      return;
    }

    switch (command.type) {
      case AndroidMediaSessionCommandType.play:
        unawaited(
          (_chapterNavigation.onPlay?.call() ?? play()).catchError(
            (Object error, StackTrace stack) => _reportCommandError(error),
          ),
        );
      case AndroidMediaSessionCommandType.pause:
        await (_chapterNavigation.onPause?.call() ?? pause());
      case AndroidMediaSessionCommandType.stop:
        final startRequestGeneration = _startRequestGeneration;
        await (_chapterNavigation.onPause?.call() ?? pause());
        if (startRequestGeneration == _startRequestGeneration &&
            !_playWhenReady &&
            !_lastSnapshot.isPlaying) {
          await _clearPlatform();
        }
      case AndroidMediaSessionCommandType.seek:
        await _seekFromCommand(command.position ?? Duration.zero);
      case AndroidMediaSessionCommandType.rewind:
        await _seekFromCommand(_lastSnapshot.position - skipInterval);
      case AndroidMediaSessionCommandType.fastForward:
        await _seekFromCommand(_lastSnapshot.position + skipInterval);
      case AndroidMediaSessionCommandType.previousChapter:
        await _chapterNavigation.onPreviousChapter?.call();
      case AndroidMediaSessionCommandType.nextChapter:
        await _chapterNavigation.onNextChapter?.call();
    }
  }

  Future<void> _seekFromCommand(Duration position) {
    return _chapterNavigation.onSeek?.call(_clampPosition(position)) ??
        seek(position);
  }

  void _reportCommandError(Object error) {
    if (_disposed) return;
    _handleSnapshot(
      AudioEngineSnapshot(
        position: _lastSnapshot.position,
        duration: _effectiveDuration,
        processingState: AudioEngineProcessingState.error,
        isPlaying: false,
        errorMessage: error is AudioEngineException
            ? error.message
            : 'Audio playback failed.',
      ),
    );
  }

  void _handleSnapshot(AudioEngineSnapshot snapshot) {
    if (_disposed) {
      return;
    }

    _lastSnapshot = snapshot;
    if (snapshot.processingState == AudioEngineProcessingState.error) {
      _preparingForeground = null;
      _playWhenReady = false;
    }
    if (!_snapshots.isClosed) {
      _snapshots.add(snapshot);
    }
    unawaited(_publishToPlatform());
  }

  AndroidMediaSessionSnapshot? _buildPlatformSnapshot({
    bool preparingPlayback = false,
  }) {
    final book = _loadedBook;
    final chapter = _loadedChapter;
    if (book == null || chapter == null) {
      return null;
    }
    final processing = _lastSnapshot.processingState;
    final canStart =
        processing == AudioEngineProcessingState.ready ||
        processing == AudioEngineProcessingState.buffering ||
        processing == AudioEngineProcessingState.loading;
    return AndroidMediaSessionSnapshot(
      appName: appName,
      bookTitle: book.title,
      chapterTitle: chapter.title,
      sourceName: book.sourceName,
      coverUrl: book.coverUrl,
      position: _clampPosition(_lastSnapshot.position),
      duration: _effectiveDuration,
      processingState: preparingPlayback && !canStart
          ? AudioEngineProcessingState.loading
          : processing,
      // The backend's playing flag is intent: while buffering or at completion
      // the system session must not claim audio is actually advancing.
      isPlaying:
          _lastSnapshot.isPlaying &&
          processing == AudioEngineProcessingState.ready,
      playWhenReady: _playWhenReady || _lastSnapshot.isPlaying,
      speed: _speed,
      canSkipPrevious:
          book.chapters.indexWhere((item) => item.id == chapter.id) > 0,
      canSkipNext:
          book.chapters.indexWhere((item) => item.id == chapter.id) <
          book.chapters.length - 1,
    );
  }

  Future<bool> _ensureForeground(AndroidMediaSessionSnapshot snapshot) async {
    _lastPublishedSnapshot = snapshot;
    try {
      return await _platform.preparePlayback(snapshot);
    } catch (_, stack) {
      _reportPlatformFailure(stack);
      return false;
    }
  }

  Future<void> _publishToPlatform() async {
    if (_disposed) return;

    final snapshot = _buildPlatformSnapshot();
    if (snapshot == null) return;
    if (!_shouldPublish(snapshot)) {
      return;
    }

    _lastPublishedSnapshot = snapshot;
    try {
      await _platform.update(snapshot);
      _reportedPlatformFailure = false;
    } catch (_, stack) {
      // Notification/service availability is independent of the audio backend.
      // Do not let an unawaited channel failure escape, and allow a later tick
      // to retry the same state instead of treating this update as delivered.
      if (identical(_lastPublishedSnapshot, snapshot)) {
        _lastPublishedSnapshot = null;
      }
      _reportPlatformFailure(stack);
    }
  }

  Future<void> _clearPlatform() async {
    _lastPublishedSnapshot = null;
    try {
      await _platform.clear();
      _reportedPlatformFailure = false;
    } catch (_, stack) {
      // Cleanup of the actual player must still run if the native service has
      // already gone away (for example, during process/activity teardown).
      _reportPlatformFailure(stack);
    }
  }

  void _reportPlatformFailure(StackTrace stack) {
    if (_reportedPlatformFailure) return;
    _reportedPlatformFailure = true;
    FlutterError.reportError(
      FlutterErrorDetails(
        // PlatformException details may contain channel payloads. Keep tokens,
        // headers and media URLs out of this diagnostic.
        exception: const AudioEngineException(
          'System media session unavailable.',
        ),
        stack: stack,
        library: 'slovofon media session',
        context: ErrorDescription(
          'while updating the system playback controls',
        ),
      ),
    );
  }

  bool _shouldPublish(AndroidMediaSessionSnapshot snapshot) {
    final previous = _lastPublishedSnapshot;
    if (previous == null) {
      return true;
    }

    if (previous.appName != snapshot.appName ||
        previous.bookTitle != snapshot.bookTitle ||
        previous.chapterTitle != snapshot.chapterTitle ||
        previous.sourceName != snapshot.sourceName ||
        previous.coverUrl != snapshot.coverUrl ||
        previous.duration != snapshot.duration ||
        previous.processingState != snapshot.processingState ||
        previous.isPlaying != snapshot.isPlaying ||
        previous.playWhenReady != snapshot.playWhenReady ||
        previous.speed != snapshot.speed ||
        previous.canSkipPrevious != snapshot.canSkipPrevious ||
        previous.canSkipNext != snapshot.canSkipNext) {
      return true;
    }

    if (snapshot.position < previous.position) {
      return true;
    }

    if (!snapshot.isPlaying && snapshot.position != previous.position) {
      return true;
    }

    return snapshot.position - previous.position >= positionPublishInterval;
  }

  Duration get _effectiveDuration {
    return _lastSnapshot.duration ?? _loadedChapter?.duration ?? Duration.zero;
  }

  Duration _clampPosition(Duration position) {
    if (position.isNegative) {
      return Duration.zero;
    }

    final duration = _effectiveDuration;
    if (duration > Duration.zero && position > duration) {
      return duration;
    }
    return position;
  }
}
