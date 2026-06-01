import 'dart:async';

import 'package:flutter/services.dart';

import 'audio_engine.dart';
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
    this.coverUrl,
    this.canSkipPrevious = true,
    this.canSkipNext = true,
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
  final bool canSkipPrevious;
  final bool canSkipNext;

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
      'canSkipPrevious': canSkipPrevious,
      'canSkipNext': canSkipNext,
    };
  }
}

abstract interface class AndroidMediaSessionPlatform {
  Stream<AndroidMediaSessionCommand> get commands;

  Future<void> update(AndroidMediaSessionSnapshot snapshot);

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
    implements AudioEngine, AudioEngineChapterNavigationBinding {
  AndroidMediaSessionEngine({
    required AudioEngine delegate,
    required AndroidMediaSessionPlatform platform,
    this.appName = 'Словофон',
    this.skipInterval = const Duration(seconds: 30),
    this.positionPublishInterval = const Duration(seconds: 5),
  }) : _delegate = delegate,
       _platform = platform {
    _delegateSubscription = _delegate.snapshots.listen(_handleSnapshot);
    _commandSubscription = _platform.commands.listen((command) {
      _commandQueue = _commandQueue
          .then((_) => _handleCommand(command))
          .catchError((Object _) {});
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

  @override
  Stream<AudioEngineSnapshot> get snapshots => _snapshots.stream;

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
  }) async {
    _loadedChapter = chapter;
    _loadedBook = book;
    _lastSnapshot = AudioEngineSnapshot(
      position: position,
      processingState: AudioEngineProcessingState.loading,
      isPlaying: false,
      duration: chapter.duration,
    );
    unawaited(_publishToPlatform());
    await _delegate.load(chapter, position: position, book: book);
  }

  @override
  Future<void> play() async {
    await _delegate.play();
    _lastSnapshot = AudioEngineSnapshot(
      position: _lastSnapshot.position,
      duration: _effectiveDuration,
      processingState: _lastSnapshot.processingState,
      isPlaying: true,
      errorMessage: _lastSnapshot.errorMessage,
    );
    unawaited(_publishToPlatform());
  }

  @override
  Future<void> pause() async {
    await _delegate.pause();
    _lastSnapshot = AudioEngineSnapshot(
      position: _lastSnapshot.position,
      duration: _effectiveDuration,
      processingState: _lastSnapshot.processingState,
      isPlaying: false,
      errorMessage: _lastSnapshot.errorMessage,
    );
    unawaited(_publishToPlatform());
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
    return _delegate.setSpeed(speed);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _commandSubscription.cancel();
    await _commandQueue;
    await _delegateSubscription.cancel();
    await _platform.clear();
    await _delegate.dispose();
    if (_platform
        case final MethodChannelAndroidMediaSessionPlatform platform) {
      await platform.dispose();
    }
    await _snapshots.close();
  }

  Future<void> _handleCommand(AndroidMediaSessionCommand command) async {
    if (_disposed) {
      return;
    }

    switch (command.type) {
      case AndroidMediaSessionCommandType.play:
        await play();
      case AndroidMediaSessionCommandType.pause:
        await pause();
      case AndroidMediaSessionCommandType.stop:
        await pause();
        await _platform.clear();
      case AndroidMediaSessionCommandType.seek:
        await seek(command.position ?? Duration.zero);
      case AndroidMediaSessionCommandType.rewind:
        await seek(_lastSnapshot.position - skipInterval);
      case AndroidMediaSessionCommandType.fastForward:
        await seek(_lastSnapshot.position + skipInterval);
      case AndroidMediaSessionCommandType.previousChapter:
        await _chapterNavigation.onPreviousChapter?.call();
      case AndroidMediaSessionCommandType.nextChapter:
        await _chapterNavigation.onNextChapter?.call();
    }
  }

  void _handleSnapshot(AudioEngineSnapshot snapshot) {
    if (_disposed) {
      return;
    }

    _lastSnapshot = snapshot;
    if (!_snapshots.isClosed) {
      _snapshots.add(snapshot);
    }
    unawaited(_publishToPlatform());
  }

  Future<void> _publishToPlatform() async {
    if (_disposed) {
      return;
    }

    final book = _loadedBook;
    final chapter = _loadedChapter;
    if (book == null || chapter == null) {
      return;
    }

    final snapshot = AndroidMediaSessionSnapshot(
      appName: appName,
      bookTitle: book.title,
      chapterTitle: chapter.title,
      sourceName: book.sourceName,
      coverUrl: book.coverUrl,
      position: _clampPosition(_lastSnapshot.position),
      duration: _effectiveDuration,
      processingState: _lastSnapshot.processingState,
      isPlaying: _lastSnapshot.isPlaying,
    );
    if (!_shouldPublish(snapshot)) {
      return;
    }

    _lastPublishedSnapshot = snapshot;
    await _platform.update(snapshot);
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
