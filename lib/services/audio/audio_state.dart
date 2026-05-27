enum AudioPlaybackStatus {
  idle,
  loading,
  buffering,
  playing,
  paused,
  completed,
  error,
}

enum AudioMediaSourceType { url, file, asset }

class AudioMediaSource {
  AudioMediaSource._({
    required this.type,
    required this.uri,
    Map<String, String> headers = const {},
  }) : headers = Map.unmodifiable(headers);

  factory AudioMediaSource.url(
    Uri uri, {
    Map<String, String> headers = const {},
  }) {
    return AudioMediaSource._(
      type: AudioMediaSourceType.url,
      uri: uri,
      headers: headers,
    );
  }

  factory AudioMediaSource.file(String path) {
    return AudioMediaSource._(
      type: AudioMediaSourceType.file,
      uri: Uri.file(path),
    );
  }

  factory AudioMediaSource.asset(String assetPath) {
    return AudioMediaSource._(
      type: AudioMediaSourceType.asset,
      uri: Uri(path: assetPath),
    );
  }

  final AudioMediaSourceType type;
  final Uri uri;
  final Map<String, String> headers;

  String get assetPath => uri.path;
  String get filePath => uri.toFilePath();
}

class AudioPlaybackChapter {
  const AudioPlaybackChapter({
    required this.id,
    required this.index,
    required this.title,
    required this.duration,
    this.isDownloaded = false,
    this.mediaSource,
  });

  final String id;
  final int index;
  final String title;
  final Duration duration;
  final bool isDownloaded;
  final AudioMediaSource? mediaSource;
}

class AudioPlaybackBook {
  const AudioPlaybackBook({
    required this.id,
    required this.versionId,
    required this.sourceId,
    required this.title,
    required this.author,
    required this.narrator,
    required this.sourceName,
    required this.chapters,
    this.sourceBookId,
    this.coverUrl,
    this.description,
    this.genre,
    this.publishedYear,
    this.sourceUrl,
  });

  final String id;
  final String versionId;
  final String sourceId;
  final String title;
  final String author;
  final String narrator;
  final String sourceName;
  final List<AudioPlaybackChapter> chapters;
  final String? sourceBookId;
  final String? coverUrl;
  final String? description;
  final String? genre;
  final int? publishedYear;
  final String? sourceUrl;

  Duration get totalDuration {
    return chapters.fold(
      Duration.zero,
      (sum, chapter) => sum + chapter.duration,
    );
  }
}

class AudioPlaybackState {
  const AudioPlaybackState({
    this.book,
    this.status = AudioPlaybackStatus.idle,
    this.chapterIndex = 0,
    this.position = Duration.zero,
    this.speed = 1,
    this.sleepTimerRemaining,
    this.errorMessage,
  });

  final AudioPlaybackBook? book;
  final AudioPlaybackStatus status;
  final int chapterIndex;
  final Duration position;
  final double speed;
  final Duration? sleepTimerRemaining;
  final String? errorMessage;

  static const idle = AudioPlaybackState();

  bool get hasBook => book != null;
  bool get isPlaying => status == AudioPlaybackStatus.playing;

  AudioPlaybackChapter? get currentChapter {
    final activeBook = book;
    if (activeBook == null || activeBook.chapters.isEmpty) {
      return null;
    }

    return activeBook.chapters[chapterIndex.clamp(
      0,
      activeBook.chapters.length - 1,
    )];
  }

  Duration get chapterDuration => currentChapter?.duration ?? Duration.zero;

  Duration get bookPosition {
    final activeBook = book;
    if (activeBook == null) {
      return Duration.zero;
    }

    final previous = activeBook.chapters
        .take(chapterIndex)
        .fold(Duration.zero, (sum, chapter) => sum + chapter.duration);
    return previous + position;
  }

  double get chapterProgress {
    final durationMs = chapterDuration.inMilliseconds;
    if (durationMs <= 0) {
      return 0;
    }

    return (position.inMilliseconds / durationMs).clamp(0, 1).toDouble();
  }

  double get bookProgress {
    final activeBook = book;
    final totalMs = activeBook?.totalDuration.inMilliseconds ?? 0;
    if (totalMs <= 0) {
      return 0;
    }

    return (bookPosition.inMilliseconds / totalMs).clamp(0, 1).toDouble();
  }

  AudioPlaybackState copyWith({
    AudioPlaybackBook? book,
    AudioPlaybackStatus? status,
    int? chapterIndex,
    Duration? position,
    double? speed,
    Duration? sleepTimerRemaining,
    String? errorMessage,
    bool clearSleepTimer = false,
    bool clearError = false,
  }) {
    return AudioPlaybackState(
      book: book ?? this.book,
      status: status ?? this.status,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      position: position ?? this.position,
      speed: speed ?? this.speed,
      sleepTimerRemaining: clearSleepTimer
          ? null
          : sleepTimerRemaining ?? this.sleepTimerRemaining,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
