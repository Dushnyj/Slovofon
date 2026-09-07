import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/playback_session.dart';
import 'audio_engine.dart';
import 'audio_persistence.dart';
import 'audio_state.dart';

typedef PlaybackBookResolver =
    Future<AudioPlaybackBook> Function(AudioPlaybackBook book);
typedef PlaybackAccessGuard =
    FutureOr<void> Function(
      AudioPlaybackBook book,
      AudioPlaybackChapter chapter,
    );

class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required AudioEngine engine,
    PlaybackPersistenceStore? persistence,
    PlaybackBookMetadataStore? bookMetadataStore,
    PlaybackBookResolver? playbackBookResolver,
    PlaybackBookResolver? playbackErrorBookResolver,
    PlaybackAccessGuard? playbackAccessGuard,
    DateTime Function()? clock,
    Duration persistenceInterval = const Duration(seconds: 5),
  }) : _engine = engine,
       _persistence = persistence,
       _bookMetadataStore = bookMetadataStore,
       _playbackBookResolver = playbackBookResolver,
       _playbackErrorBookResolver = playbackErrorBookResolver,
       _playbackAccessGuard = playbackAccessGuard,
       _clock = clock ?? DateTime.now,
       _persistenceInterval = persistenceInterval {
    _engineSubscription = _engine.snapshots.listen(_handleEngineSnapshot);
    if (_engine case final AudioEngineChapterNavigationBinding binding) {
      binding.bindChapterNavigation(
        AudioEngineChapterNavigationCallbacks(
          onPlay: play,
          onPause: pause,
          onSeek: seek,
          onPreviousChapter: previousChapter,
          onNextChapter: nextChapter,
        ),
      );
    }
  }

  final AudioEngine _engine;
  final PlaybackPersistenceStore? _persistence;
  final PlaybackBookMetadataStore? _bookMetadataStore;
  final PlaybackBookResolver? _playbackBookResolver;
  final PlaybackBookResolver? _playbackErrorBookResolver;
  final PlaybackAccessGuard? _playbackAccessGuard;
  final DateTime Function() _clock;
  final Duration _persistenceInterval;
  late final StreamSubscription<AudioEngineSnapshot> _engineSubscription;

  AudioPlaybackState _state = AudioPlaybackState.idle;
  DateTime? _lastPersistedAt;
  int _maxReachedGlobalPositionMs = 0;
  bool _handlingEngineCompletion = false;
  bool _pendingPlayRequest = false;
  int _engineLoadDepth = 0;
  String? _loadedChapterIdentity;
  int _operationGeneration = 0;
  bool _disposed = false;
  bool _shuttingDown = false;
  bool _notifierDisposed = false;
  Future<void>? _shutdownOperation;
  Future<void> _engineOperations = Future<void>.value();
  Future<void> _persistenceOperations = Future<void>.value();
  final _metadataWrites = <Future<void>>{};
  AudioEngineSnapshot? _snapshotDuringLoad;
  final _progressChanges = StreamController<int>.broadcast();
  int _progressRevision = 0;
  final _chapterResumePositions = <String, Duration>{};
  final _chapterResumePositionsByIndex = <int, Duration>{};

  AudioPlaybackState get state => _state;
  Stream<int> get progressChanges => _progressChanges.stream;
  int get progressRevision => _progressRevision;

  bool get _unavailable => _disposed || _shuttingDown || _notifierDisposed;

  bool _isCurrent(int generation) =>
      !_unavailable && generation == _operationGeneration;

  Future<bool> loadSavedSession(AudioPlaybackBook book) async {
    final generation = _operationGeneration;
    final session = await _persistence?.loadSession();
    if (!_isCurrent(generation) ||
        session == null ||
        session.activeBookId != book.id ||
        session.activeBookVersionId != book.versionId) {
      return false;
    }

    await restoreSession(
      book,
      PlaybackSession(
        id: session.id,
        activeBookId: session.activeBookId,
        activeBookVersionId: session.activeBookVersionId,
        activeSourceId: session.activeSourceId,
        activeChapterId: session.activeChapterId,
        positionMs: session.positionMs,
        speed: session.speed,
        volume: session.volume,
        isPlaying: false,
        playerPageIndex: session.playerPageIndex,
        sleepTimerRemainingMs: session.sleepTimerRemainingMs,
        sleepTimerMode: session.sleepTimerMode,
        updatedAt: session.updatedAt,
      ),
    );
    return true;
  }

  Future<void> loadBook(
    AudioPlaybackBook book, {
    int chapterIndex = 0,
    Duration position = Duration.zero,
    bool autoPlay = false,
  }) async {
    if (_unavailable) return;
    final generation = ++_operationGeneration;
    unawaited(_persistPlayback(force: true));
    _pendingPlayRequest = false;
    _loadedChapterIdentity = null;
    _chapterResumePositions.clear();
    _chapterResumePositionsByIndex.clear();
    final normalizedIndex = _clampChapterIndex(book, chapterIndex);
    final normalizedPosition = _clampPosition(
      position,
      book.chapters[normalizedIndex],
    );

    _state = AudioPlaybackState(
      book: book,
      status: AudioPlaybackStatus.loading,
      chapterIndex: normalizedIndex,
      position: normalizedPosition,
      speed: _state.speed,
      volume: _state.volume,
      lastNonMutedVolume: _state.lastNonMutedVolume,
    );
    _maxReachedGlobalPositionMs = _bookPositionFor(
      book,
      normalizedIndex,
      normalizedPosition,
    ).inMilliseconds;
    _rememberCurrentChapterPosition();
    notifyListeners();

    final loaded = await _loadEngineChapter(
      book,
      book.chapters[normalizedIndex],
      position: normalizedPosition,
      generation: generation,
    );
    if (!loaded || !_isCurrent(generation)) {
      return;
    }

    await _persistMetadata(_state.book!);
    if (!await _configureEngine(generation)) return;

    if (autoPlay) {
      if (!await _authorizeEnginePlayback(generation) ||
          !_isCurrent(generation)) {
        return;
      }
      _startEnginePlayback(generation);
    }

    _state = _state.copyWith(
      status: autoPlay
          ? AudioPlaybackStatus.playing
          : AudioPlaybackStatus.paused,
      clearError: true,
    );
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<void> restoreSession(
    AudioPlaybackBook book,
    PlaybackSession session,
  ) async {
    if (_unavailable) return;
    final generation = ++_operationGeneration;
    unawaited(_persistPlayback(force: true));
    _pendingPlayRequest = false;
    _loadedChapterIdentity = null;
    _chapterResumePositions.clear();
    _chapterResumePositionsByIndex.clear();
    final chapterIndex = book.chapters.indexWhere(
      (chapter) => chapter.id == session.activeChapterId,
    );
    final normalizedIndex = chapterIndex < 0 ? 0 : chapterIndex;
    final position = Duration(milliseconds: session.positionMs);
    // A persisted zero is an already-expired timer, not an active one. Treat
    // it as "no timer" so playback does not immediately re-pause on resume.
    final restoredSleepTimer =
        (session.sleepTimerRemainingMs == null ||
            session.sleepTimerRemainingMs! <= 0)
        ? null
        : Duration(milliseconds: session.sleepTimerRemainingMs!);

    final restoredVolume = _normalizeVolume(session.volume);
    _state = AudioPlaybackState(
      book: book,
      status: AudioPlaybackStatus.loading,
      chapterIndex: normalizedIndex,
      position: _clampPosition(position, book.chapters[normalizedIndex]),
      speed: _normalizeSpeed(session.speed),
      volume: restoredVolume,
      lastNonMutedVolume: restoredVolume > 0
          ? restoredVolume
          : _state.lastNonMutedVolume,
      sleepTimerRemaining: restoredSleepTimer,
      sleepTimerMode: session.sleepTimerMode == SleepTimerMode.stopAtChapterEnd
          ? SleepTimerMode.stopAtChapterEnd
          : restoredSleepTimer == null
          ? SleepTimerMode.off
          : SleepTimerMode.stopAfterDuration,
    );
    _maxReachedGlobalPositionMs = _bookPositionFor(
      book,
      normalizedIndex,
      _state.position,
    ).inMilliseconds;
    _rememberCurrentChapterPosition();
    notifyListeners();

    final loaded = await _loadEngineChapter(
      book,
      book.chapters[normalizedIndex],
      position: _state.position,
      generation: generation,
    );
    if (!loaded) {
      return;
    }

    await _persistMetadata(_state.book!);
    if (!await _configureEngine(generation)) return;

    if (session.isPlaying) {
      if (!await _authorizeEnginePlayback(generation) ||
          !_isCurrent(generation)) {
        return;
      }
      _startEnginePlayback(generation);
    }

    _state = _state.copyWith(
      status: session.isPlaying
          ? AudioPlaybackStatus.playing
          : AudioPlaybackStatus.paused,
      clearError: true,
    );
    _refreshChapterEndTimer();
    notifyListeners();
    await _persistPlayback(force: true);
  }

  PlaybackSession toPlaybackSession({
    String id = 'active',
    DateTime? updatedAt,
  }) {
    final activeBook = _state.book;

    return PlaybackSession(
      id: id,
      activeBookId: activeBook?.id,
      activeBookVersionId: activeBook?.versionId,
      activeSourceId: activeBook?.sourceId,
      activeChapterId: _state.currentChapter?.id,
      positionMs: _state.position.inMilliseconds,
      speed: _state.speed,
      volume: _state.volume,
      isPlaying: _state.isPlaying,
      sleepTimerRemainingMs: _state.sleepTimerRemaining?.inMilliseconds,
      sleepTimerMode: _state.sleepTimerMode,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Future<void> play() async {
    if (_unavailable || !_state.hasBook) return;
    final generation = ++_operationGeneration;
    if (!await _preparePositionForPlayback(generation)) return;
    if (!_isCurrent(generation)) return;
    if (!await _authorizeEnginePlayback(generation) ||
        !_isCurrent(generation)) {
      return;
    }
    _startEnginePlayback(generation);
    _state = _state.copyWith(
      status: AudioPlaybackStatus.playing,
      clearError: true,
    );
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<void> pause() async {
    if (_unavailable || !_state.hasBook) return;
    final generation = ++_operationGeneration;
    _pendingPlayRequest = false;
    _state = _state.copyWith(status: AudioPlaybackStatus.paused);
    notifyListeners();
    if (!await _runEngineOperation(generation, _engine.pause)) return;
    _state = _state.copyWith(status: AudioPlaybackStatus.paused);
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<void> togglePlayPause() {
    return _state.isPlaying ||
            _state.status == AudioPlaybackStatus.buffering ||
            _pendingPlayRequest
        ? pause()
        : play();
  }

  Future<void> seek(Duration position) async {
    final chapter = _state.currentChapter;
    if (_unavailable || chapter == null) return;
    final generation = ++_operationGeneration;
    final normalized = _clampPosition(position, chapter);
    if (!await _runEngineOperation(generation, () async {
      await _guardPlaybackAccess(_state.book!, chapter);
      if (_isCurrent(generation)) await _engine.seek(normalized);
    })) {
      return;
    }
    _state = _state.copyWith(position: normalized);
    if (_state.status == AudioPlaybackStatus.completed) {
      _state = _state.copyWith(status: AudioPlaybackStatus.paused);
    }
    _refreshChapterEndTimer();
    _rememberCurrentChapterPosition();
    _updateMaxReachedPosition();
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<void> skipBy(Duration delta) => seek(_state.position + delta);

  Future<void> setSpeed(double speed) async {
    if (_unavailable || !_state.hasBook) return;
    final generation = _operationGeneration;
    final normalized = _normalizeSpeed(speed);
    _state = _state.copyWith(speed: normalized);
    notifyListeners();
    if (!await _runEngineOperation(
      generation,
      () => _engine.setSpeed(normalized),
    )) {
      return;
    }
    await _persistPlayback(force: true);
  }

  Future<void> setVolume(double volume) async {
    if (_unavailable) return;
    final generation = _operationGeneration;
    final normalized = _normalizeVolume(volume);
    _state = _state.copyWith(
      volume: normalized,
      lastNonMutedVolume: normalized > 0
          ? normalized
          : _state.lastNonMutedVolume,
    );
    notifyListeners();
    if (!await _runEngineOperation(
      generation,
      () => _engine.setVolume(normalized),
    )) {
      return;
    }
    await _persistPlayback(force: true);
  }

  Future<void> toggleMute() => setVolume(
    _state.volume > 0
        ? 0
        : _state.lastNonMutedVolume > 0
        ? _state.lastNonMutedVolume
        : 1,
  );

  Future<void> nextChapter() async {
    final book = _state.book;
    if (_unavailable || book == null) return;
    final generation = ++_operationGeneration;
    final index = _state.chapterIndex + 1;
    if (index >= book.chapters.length) {
      await _stopAtChapterEnd(generation, completed: true);
      return;
    }
    await _loadChapterAt(
      index,
      position: _chapterResumePositionFor(book, index),
      generation: generation,
    );
  }

  Future<void> previousChapter() async {
    final book = _state.book;
    if (_unavailable || book == null) return;
    final generation = ++_operationGeneration;
    final index = (_state.chapterIndex - 1).clamp(0, book.chapters.length - 1);
    await _loadChapterAt(
      index,
      position: _chapterResumePositionFor(book, index),
      generation: generation,
    );
  }

  Future<void> playChapterAt(int index) async {
    final book = _state.book;
    if (_unavailable || book == null) return;
    final normalized = _clampChapterIndex(book, index);
    if (normalized == _state.chapterIndex) {
      await play();
      return;
    }
    final generation = ++_operationGeneration;
    await _loadChapterAt(
      normalized,
      position: _chapterResumePositionFor(book, normalized),
      playAfterLoad: true,
      generation: generation,
    );
  }

  /// Selects a chapter and an exact position as one guarded engine operation.
  /// Unlike playChapterAt followed by seek, a delayed load cannot overwrite a
  /// later user's chapter choice or briefly play a saved resume position.
  Future<void> seekChapterAt(
    int index,
    Duration position, {
    bool play = true,
  }) async {
    final book = _state.book;
    if (_unavailable || book == null || book.chapters.isEmpty) return;
    final generation = ++_operationGeneration;
    await _loadChapterAt(
      _clampChapterIndex(book, index),
      position: position,
      playAfterLoad: play,
      generation: generation,
    );
  }

  void setSleepTimer(Duration duration) {
    if (_unavailable) return;
    _state = _state.copyWith(
      sleepTimerRemaining: _nonNegative(duration),
      sleepTimerMode: SleepTimerMode.stopAfterDuration,
    );
    notifyListeners();
    unawaited(_persistPlayback(force: true));
  }

  void setSleepTimerToChapterEnd() {
    if (_unavailable) return;
    final remaining = _remainingCurrentChapterDuration();
    if (remaining == null) return;
    _state = _state.copyWith(
      sleepTimerRemaining: remaining,
      sleepTimerMode: SleepTimerMode.stopAtChapterEnd,
    );
    notifyListeners();
    unawaited(_persistPlayback(force: true));
  }

  void clearSleepTimer() {
    if (_unavailable) return;
    _state = _state.copyWith(clearSleepTimer: true);
    notifyListeners();
    unawaited(_persistPlayback(force: true));
  }

  void _refreshChapterEndTimer() {
    if (_state.sleepTimerMode == SleepTimerMode.stopAtChapterEnd) {
      _state = _state.copyWith(
        sleepTimerRemaining: _remainingCurrentChapterDuration(),
      );
    }
  }

  double chapterProgressAt(int index) {
    final activeBook = _state.book;
    if (activeBook == null) {
      return 0;
    }

    final normalizedIndex = _clampChapterIndex(activeBook, index);
    final chapter = activeBook.chapters[normalizedIndex];
    if (normalizedIndex == _state.chapterIndex) {
      return _state.chapterProgress;
    }

    final remembered = _chapterResumePositions[chapter.id];
    if (remembered != null) {
      return _chapterProgressForPosition(chapter, remembered);
    }

    return normalizedIndex < _state.chapterIndex ? 1 : 0;
  }

  Future<void> tick(Duration elapsed) async {
    if (_unavailable ||
        elapsed <= Duration.zero ||
        !_state.isPlaying ||
        _state.sleepTimerMode == SleepTimerMode.stopAtChapterEnd) {
      return;
    }
    final remaining = _state.sleepTimerRemaining;
    if (remaining == null) return;
    final next = _nonNegative(remaining - elapsed);
    if (next == Duration.zero) {
      _state = _state.copyWith(clearSleepTimer: true);
      await pause();
    } else {
      _state = _state.copyWith(sleepTimerRemaining: next);
      notifyListeners();
      await _persistPlayback();
    }
  }

  /// Await before closing the database on a graceful application shutdown.
  /// Required checkpoints (for example, installer handoff) surface storage
  /// failures to their caller. Ordinary playback retains best-effort reporting.
  Future<void> flushPlayback({bool requireSuccess = false}) =>
      _persistPlayback(force: true, requireSuccess: requireSuccess);

  /// Completes while the platform engine and its messenger are still alive.
  /// Windows must await this before acknowledging a cancelable close request:
  /// ChangeNotifier.dispose alone cannot await native disposePlayer.
  ///
  /// A failed pause/checkpoint leaves the player available for retry. Once
  /// native teardown starts, its result is retained: a failure must not be
  /// mistaken for successful teardown by a second close request.
  Future<void> shutdown() {
    final pending = _shutdownOperation;
    if (pending != null) return pending;
    _shuttingDown = true;
    _operationGeneration++;
    _pendingPlayRequest = false;
    return _shutdownOperation = _shutdown();
  }

  Future<void> _shutdown() async {
    try {
      // Invalidate queued/stale work, but allow the currently running finite
      // load/seek to finish before disposing the same native player.
      await _engineOperations;
      await Future.wait(_metadataWrites.toList());
      if (_state.hasBook) {
        await _engine.pause();
        if (_state.status != AudioPlaybackStatus.completed) {
          _state = _state.copyWith(status: AudioPlaybackStatus.paused);
          if (!_notifierDisposed) notifyListeners();
        }
      }
      await _persistPlayback(force: true, requireSuccess: !_notifierDisposed);
    } catch (error, stack) {
      if (!_notifierDisposed) {
        _shuttingDown = false;
        _shutdownOperation = null;
        rethrow;
      }
      // Synchronous owner disposal is not cancelable. Still release native
      // resources if a checkpoint or pause failed, and report the failure.
      _reportShutdownError(error, stack);
    }

    _disposed = true;
    try {
      await _engineSubscription.cancel();
    } finally {
      try {
        await _engine.dispose();
      } finally {
        // A paused/offscreen UI subscriber can defer delivery of stream done.
        // Native teardown and exit must not wait for that UI-only notification.
        unawaited(_progressChanges.close());
      }
    }
  }

  @override
  void dispose() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    unawaited(shutdown().catchError(_reportShutdownError));
    super.dispose();
  }

  void _reportShutdownError(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'slovofon playback',
        context: ErrorDescription('while shutting down the audio player'),
      ),
    );
  }

  void _handleEngineSnapshot(AudioEngineSnapshot snapshot) {
    if (_unavailable) return;
    if (_engineLoadDepth > 0) {
      _snapshotDuringLoad = snapshot;
      return;
    }
    // A failed/replaced load has no decoder bound to the selected chapter.
    // Late pause/position events still belong to the previous decoder and must
    // not erase the saved resume position or dismiss the recoverable error.
    if (_loadedChapterIdentity == null) return;
    var chapter = _state.currentChapter;
    if (chapter == null) {
      return;
    }
    // Backend pause can publish one final ready/idle snapshot after we have
    // persisted completion. Do not turn a finished book back into paused.
    if (_state.status == AudioPlaybackStatus.completed &&
        !snapshot.isPlaying &&
        (snapshot.processingState == AudioEngineProcessingState.ready ||
            snapshot.processingState == AudioEngineProcessingState.idle)) {
      return;
    }
    if (snapshot.isPlaying &&
        snapshot.processingState == AudioEngineProcessingState.ready) {
      _pendingPlayRequest = false;
    }
    final snapshotDuration = snapshot.duration;
    var durationChanged = false;
    if (snapshotDuration != null &&
        snapshotDuration > Duration.zero &&
        snapshotDuration != chapter.duration) {
      _state = _state.copyWith(
        book: _bookWithChapterDuration(
          _state.book!,
          _state.chapterIndex,
          snapshotDuration,
        ),
      );
      chapter = _state.currentChapter!;
      durationChanged = true;
      _saveMetadata(_state.book!);
    }
    final position = _clampPosition(snapshot.position, chapter);
    if (snapshot.processingState == AudioEngineProcessingState.completed) {
      if (_handlingEngineCompletion ||
          (!_state.isPlaying &&
              !snapshot.isPlaying &&
              _state.position >= chapter.duration)) {
        return;
      }
      _pendingPlayRequest = false;
      _state = _state.copyWith(position: chapter.duration);
      _updateMaxReachedPosition();
      notifyListeners();
      unawaited(
        _completeEngineChapter(
          continuePlayback: _state.isPlaying || snapshot.isPlaying,
        ),
      );
      return;
    }

    if (snapshot.processingState == AudioEngineProcessingState.error) {
      _pendingPlayRequest = false;
      _loadedChapterIdentity = null;
    }

    final nextStatus = _statusFromEngineSnapshot(snapshot);
    final nextErrorMessage =
        snapshot.processingState == AudioEngineProcessingState.error
        ? snapshot.errorMessage
        : null;
    if (!durationChanged &&
        _state.position == position &&
        _state.status == nextStatus &&
        _state.errorMessage == nextErrorMessage) {
      return;
    }

    _state = _state.copyWith(
      position: position,
      status: nextStatus,
      errorMessage: nextErrorMessage,
      clearError: nextErrorMessage == null,
    );
    _refreshChapterEndTimer();
    _rememberCurrentChapterPosition();
    _updateMaxReachedPosition();
    notifyListeners();
    unawaited(
      _persistPlayback(
        force: snapshot.processingState == AudioEngineProcessingState.error,
      ),
    );
  }

  Future<void> _completeEngineChapter({required bool continuePlayback}) async {
    if (_unavailable || _handlingEngineCompletion) return;
    final generation = ++_operationGeneration;
    _handlingEngineCompletion = true;
    try {
      if (_state.sleepTimerMode == SleepTimerMode.stopAtChapterEnd) {
        await _stopAtChapterEnd(generation, completed: false);
        return;
      }
      final activeBook = _state.book;
      if (activeBook == null) return;
      final nextIndex = _state.chapterIndex + 1;
      if (nextIndex >= activeBook.chapters.length) {
        await _stopAtChapterEnd(generation, completed: true);
        return;
      }
      // _loadChapterAt refreshes once. Do not scan the whole offline book twice.
      await _loadChapterAt(
        nextIndex,
        position: Duration.zero,
        playAfterLoad: continuePlayback,
        generation: generation,
      );
    } finally {
      _handlingEngineCompletion = false;
    }
  }

  Future<void> _stopAtChapterEnd(
    int generation, {
    required bool completed,
  }) async {
    _pendingPlayRequest = false;
    _state = _state.copyWith(status: AudioPlaybackStatus.paused);
    if (!await _runEngineOperation(generation, () async {
      _engineLoadDepth++;
      try {
        await _engine.pause();
        if (!_isCurrent(generation)) return;
        if (_state.chapterDuration > Duration.zero) {
          await _engine.seek(_state.chapterDuration);
        }
      } finally {
        _engineLoadDepth--;
      }
    })) {
      return;
    }
    _state = _state.copyWith(
      position: _state.chapterDuration,
      status: completed
          ? AudioPlaybackStatus.completed
          : AudioPlaybackStatus.paused,
      clearSleepTimer: true,
    );
    _rememberCurrentChapterPosition();
    _updateMaxReachedPosition();
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<bool> _preparePositionForPlayback(int generation) async {
    final retry = _state.status == AudioPlaybackStatus.error;
    var book = await _refreshActiveBookForPlayback(generation);
    if (!_isCurrent(generation) || book == null) return false;
    final currentChapter = _state.currentChapter;
    if (currentChapter == null ||
        !await _checkPlaybackAccess(book, currentChapter, generation)) {
      return false;
    }
    if (retry &&
        _playbackErrorBookResolver != null &&
        currentChapter.mediaSource?.type != AudioMediaSourceType.file &&
        currentChapter.mediaSource?.type != AudioMediaSourceType.asset) {
      book = await _refreshActiveBookForPlayback(generation, retryMedia: true);
      if (!_isCurrent(generation) || book == null) return false;
    }
    final chapter = _state.currentChapter;
    if (chapter == null) return false;
    if (chapter.duration > Duration.zero &&
        _state.position >= chapter.duration) {
      final next = _state.chapterIndex + 1;
      if (next < book.chapters.length) {
        await _loadChapterAt(
          next,
          position: Duration.zero,
          playAfterLoad: false,
          generation: generation,
          refreshedBook: book,
        );
        return _isCurrent(generation) &&
            _state.status != AudioPlaybackStatus.error;
      }
      if (!await _runEngineOperation(
        generation,
        () => _engine.seek(Duration.zero),
      )) {
        return false;
      }
      _state = _state.copyWith(
        position: Duration.zero,
        status: AudioPlaybackStatus.paused,
        clearError: true,
      );
    }
    return _ensureCurrentEngineChapterLoaded(
      book,
      _state.currentChapter!,
      generation,
    );
  }

  Future<bool> _ensureCurrentEngineChapterLoaded(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
    int generation,
  ) async {
    if (!_isCurrent(generation)) return false;
    if (_loadedChapterIdentity == _chapterLoadIdentity(book, chapter)) {
      return true;
    }
    final position = _clampPosition(_state.position, chapter);
    if (!await _loadEngineChapter(
      book,
      chapter,
      position: position,
      generation: generation,
    )) {
      return false;
    }
    _state = _state.copyWith(position: position);
    return _configureEngine(generation);
  }

  Future<void> _loadChapterAt(
    int index, {
    required Duration position,
    required int generation,
    bool? playAfterLoad,
    AudioPlaybackBook? refreshedBook,
  }) async {
    if (!_isCurrent(generation)) return;
    _rememberCurrentChapterPosition();
    final wasPlaying =
        playAfterLoad ??
        (_state.isPlaying ||
            _state.status == AudioPlaybackStatus.buffering ||
            _pendingPlayRequest);
    final activeBook =
        refreshedBook ?? await _refreshActiveBookForPlayback(generation);
    if (!_isCurrent(generation) || activeBook == null) return;
    final normalizedIndex = _clampChapterIndex(activeBook, index);
    final chapter = activeBook.chapters[normalizedIndex];
    final normalizedPosition = _clampPosition(position, chapter);
    _pendingPlayRequest = false;
    _state = _state.copyWith(
      chapterIndex: normalizedIndex,
      position: normalizedPosition,
      status: AudioPlaybackStatus.loading,
      clearError: true,
    );
    notifyListeners();
    if (!await _loadEngineChapter(
      activeBook,
      chapter,
      position: normalizedPosition,
      generation: generation,
    )) {
      return;
    }
    if (!await _configureEngine(generation)) return;
    if (wasPlaying &&
        (!await _authorizeEnginePlayback(generation) ||
            !_isCurrent(generation))) {
      return;
    }
    _state = _state.copyWith(
      status: wasPlaying
          ? AudioPlaybackStatus.playing
          : AudioPlaybackStatus.paused,
    );
    if (wasPlaying) _startEnginePlayback(generation);
    _refreshChapterEndTimer();
    _rememberCurrentChapterPosition();
    _updateMaxReachedPosition();
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<bool> _loadEngineChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    required Duration position,
    required int generation,
  }) async {
    AudioEngineSnapshot? loadedSnapshot;
    final loaded = await _runEngineOperation(generation, () async {
      _engineLoadDepth++;
      _snapshotDuringLoad = null;
      _loadedChapterIdentity = null;
      try {
        await _guardPlaybackAccess(book, chapter);
        if (!_isCurrent(generation)) return;
        await _engine.load(chapter, position: position, book: book);
        if (_isCurrent(generation)) {
          _loadedChapterIdentity = _chapterLoadIdentity(book, chapter);
        }
      } finally {
        // Stream wrappers can queue a final pause/position microtask even when
        // load throws. Keep both successful and failed loads inside the guard.
        await Future<void>.value();
        loadedSnapshot = _snapshotDuringLoad;
        _engineLoadDepth--;
      }
    });
    if (!loaded) return false;
    final duration = loadedSnapshot?.duration;
    if (loadedSnapshot?.processingState !=
            AudioEngineProcessingState.completed &&
        duration != null &&
        duration > Duration.zero &&
        duration != _state.chapterDuration) {
      _state = _state.copyWith(
        book: _bookWithChapterDuration(
          _state.book!,
          _state.chapterIndex,
          duration,
        ),
      );
      _saveMetadata(_state.book!);
    }
    return true;
  }

  Future<bool> _configureEngine(int generation) =>
      _runEngineOperation(generation, () async {
        await _engine.setSpeed(_state.speed);
        if (!_isCurrent(generation)) return;
        await _engine.setVolume(_state.volume);
      });

  /// Only finite transport operations are queued; play() is deliberately not.
  Future<bool> _runEngineOperation(
    int generation,
    Future<void> Function() operation,
  ) async {
    final pending = _engineOperations.then((_) async {
      if (!_isCurrent(generation)) return;
      await operation();
    });
    _engineOperations = pending.catchError((Object error, StackTrace stack) {});
    try {
      await pending;
      return _isCurrent(generation);
    } catch (error) {
      if (_isCurrent(generation)) {
        _pendingPlayRequest = false;
        _loadedChapterIdentity = null;
        _state = _state.copyWith(
          status: AudioPlaybackStatus.error,
          errorMessage: _errorMessage(error),
        );
        notifyListeners();
      }
      return false;
    }
  }

  Future<AudioPlaybackBook?> _refreshActiveBookForPlayback(
    int generation, {
    bool retryMedia = false,
  }) async {
    final activeBook = _state.book;
    final resolver = retryMedia
        ? _playbackErrorBookResolver
        : _playbackBookResolver;
    if (!_isCurrent(generation)) return null;
    if (activeBook == null || resolver == null) return activeBook;
    final AudioPlaybackBook resolvedBook;
    try {
      resolvedBook = await resolver(activeBook);
    } catch (error, stackTrace) {
      if (!_isCurrent(generation)) return null;
      if (retryMedia) {
        _state = _state.copyWith(
          status: AudioPlaybackStatus.error,
          errorMessage: _errorMessage(error),
        );
        notifyListeners();
        return null;
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'slovofon playback',
          context: ErrorDescription('while refreshing active playback book'),
        ),
      );
      return activeBook;
    }
    if (!_isCurrent(generation)) return null;
    if (!_isSameBookIdentity(activeBook, resolvedBook)) return activeBook;
    _state = _state.copyWith(book: resolvedBook);
    _saveMetadata(resolvedBook);
    notifyListeners();
    return resolvedBook;
  }

  void _saveMetadata(AudioPlaybackBook book) {
    unawaited(_persistMetadata(book));
  }

  Future<void> _persistMetadata(AudioPlaybackBook book) {
    final pending = _writeMetadata(book);
    _metadataWrites.add(pending);
    return pending.whenComplete(() => _metadataWrites.remove(pending));
  }

  Future<void> _writeMetadata(AudioPlaybackBook book) async {
    try {
      await _bookMetadataStore?.saveBook(book);
    } catch (error, stack) {
      // A cache/disk write failure must not strand an already loaded decoder
      // in "loading" or prevent Pause/Play. Persistence stays best-effort and
      // visible in diagnostics, as it is for runtime duration metadata updates.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'slovofon playback',
          context: ErrorDescription('while saving playback metadata'),
        ),
      );
    }
  }

  Future<bool> _checkPlaybackAccess(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
    int generation,
  ) {
    if (_playbackAccessGuard == null) {
      return Future<bool>.value(_isCurrent(generation));
    }
    return _runEngineOperation(
      generation,
      () => _guardPlaybackAccess(book, chapter),
    );
  }

  Future<void> _guardPlaybackAccess(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    try {
      await _playbackAccessGuard?.call(book, chapter);
    } catch (_) {
      // A denied switch/resume must not leave an older remote decoder sounding.
      // Preserve the policy error even if cleanup itself cannot reach a backend.
      try {
        await _engine.pause();
      } catch (_) {}
      rethrow;
    }
  }

  Future<bool> _authorizeEnginePlayback(int generation) async {
    if (!_isCurrent(generation)) return false;
    final book = _state.book;
    final chapter = _state.currentChapter;
    if (book == null || chapter == null) return false;
    return _checkPlaybackAccess(book, chapter, generation);
  }

  void _startEnginePlayback(int generation) {
    if (!_isCurrent(generation)) return;
    _pendingPlayRequest = true;
    unawaited(
      _engine.play().catchError((Object error, StackTrace stackTrace) {
        if (!_isCurrent(generation)) return;
        _pendingPlayRequest = false;
        _state = _state.copyWith(
          status: AudioPlaybackStatus.error,
          errorMessage: _errorMessage(error),
        );
        notifyListeners();
      }),
    );
  }

  int _clampChapterIndex(AudioPlaybackBook book, int index) {
    if (book.chapters.isEmpty) {
      throw ArgumentError.value(
        book,
        'book',
        'must contain at least one chapter',
      );
    }

    return index.clamp(0, book.chapters.length - 1);
  }

  Duration _clampPosition(Duration position, AudioPlaybackChapter chapter) {
    if (position < Duration.zero) {
      return Duration.zero;
    }
    if (chapter.duration <= Duration.zero) {
      return position;
    }
    if (position > chapter.duration) {
      return chapter.duration;
    }
    return position;
  }

  AudioPlaybackBook _bookWithChapterDuration(
    AudioPlaybackBook book,
    int chapterIndex,
    Duration duration,
  ) {
    final chapters = book.chapters.toList();
    final normalizedIndex = chapterIndex.clamp(0, chapters.length - 1);
    chapters[normalizedIndex] = chapters[normalizedIndex].copyWith(
      duration: duration,
    );
    return book.copyWith(chapters: List.unmodifiable(chapters));
  }

  Duration _nonNegative(Duration duration) {
    return duration < Duration.zero ? Duration.zero : duration;
  }

  Duration? _remainingCurrentChapterDuration() {
    final chapter = _state.currentChapter;
    if (chapter == null || chapter.duration <= Duration.zero) {
      return null;
    }
    return _nonNegative(chapter.duration - _state.position);
  }

  double _chapterProgressForPosition(
    AudioPlaybackChapter chapter,
    Duration position,
  ) {
    final durationMs = chapter.duration.inMilliseconds;
    if (durationMs <= 0) {
      return 0;
    }
    return (position.inMilliseconds / durationMs).clamp(0, 1).toDouble();
  }

  double _normalizeSpeed(double speed) {
    return speed.clamp(0.5, 3).toDouble();
  }

  double _normalizeVolume(double volume) {
    return volume.clamp(0, 1).toDouble();
  }

  String _errorMessage(Object error) {
    if (error is AudioEngineException) {
      return error.message;
    }

    return 'Audio playback failed.';
  }

  AudioPlaybackStatus _statusFromEngineSnapshot(AudioEngineSnapshot snapshot) {
    switch (snapshot.processingState) {
      case AudioEngineProcessingState.idle:
        if (_pendingPlayRequest) {
          return AudioPlaybackStatus.playing;
        }
        return _state.hasBook
            ? AudioPlaybackStatus.paused
            : AudioPlaybackStatus.idle;
      case AudioEngineProcessingState.loading:
        return AudioPlaybackStatus.loading;
      case AudioEngineProcessingState.buffering:
        return AudioPlaybackStatus.buffering;
      case AudioEngineProcessingState.ready:
        return snapshot.isPlaying || _pendingPlayRequest
            ? AudioPlaybackStatus.playing
            : AudioPlaybackStatus.paused;
      case AudioEngineProcessingState.completed:
        return AudioPlaybackStatus.completed;
      case AudioEngineProcessingState.error:
        return AudioPlaybackStatus.error;
    }
  }

  Future<void> _persistPlayback({
    bool force = false,
    bool requireSuccess = false,
  }) async {
    final persistence = _persistence;
    final activeBook = _state.book;
    if (persistence == null || activeBook == null) {
      return;
    }

    final now = _clock();
    final lastPersistedAt = _lastPersistedAt;
    if (!force &&
        lastPersistedAt != null &&
        now.difference(lastPersistedAt) < _persistenceInterval) {
      return;
    }
    _lastPersistedAt = now;

    // Capture both values before the first await: a later book selection must
    // never pair an old session write with a new book's progress.
    final session = toPlaybackSession(updatedAt: now);
    final progress = _progressSnapshot(now);
    final pending = _persistenceOperations.then((_) async {
      await persistence.saveSession(session);
      await persistence.saveProgress(progress);
      // Active playback already renders live position. Refresh stored history
      // only on discrete saves (book switch/pause/seek), not every 5s tick.
      if (force && !_disposed && !_progressChanges.isClosed) {
        _progressChanges.add(++_progressRevision);
      }
    });
    _persistenceOperations = pending.catchError((
      Object error,
      StackTrace stack,
    ) {
      if (!requireSuccess) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'slovofon playback',
            context: ErrorDescription('while saving playback session'),
          ),
        );
      }
    });
    // Recover the queue in either mode so a failed checkpoint does not poison
    // later saves. A required checkpoint awaits the original failing future;
    // its caller owns user feedback, avoiding a duplicate FlutterError report.
    await (requireSuccess ? pending : _persistenceOperations);
  }

  PlaybackProgressSnapshot _progressSnapshot(DateTime now) {
    final activeBook = _state.book!;
    final currentPositionMs = _state.position.inMilliseconds;
    final listenedDurationMs = _state.bookPosition.inMilliseconds;
    final totalDurationMs = activeBook.totalDuration.inMilliseconds;

    return PlaybackProgressSnapshot(
      bookId: activeBook.id,
      bookVersionId: activeBook.versionId,
      currentChapterId: _state.currentChapter?.id,
      currentPositionMs: currentPositionMs,
      maxReachedGlobalPositionMs: _maxReachedGlobalPositionMs,
      totalDurationMs: totalDurationMs,
      listenedDurationMs: listenedDurationMs,
      percent: totalDurationMs <= 0
          ? 0
          : (listenedDurationMs / totalDurationMs * 100).clamp(0, 100),
      isFinished: _state.status == AudioPlaybackStatus.completed,
      lastPlayedAt: now,
    );
  }

  void _updateMaxReachedPosition() {
    final activeBook = _state.book;
    if (activeBook == null) {
      return;
    }

    final currentGlobalPositionMs = _bookPositionFor(
      activeBook,
      _state.chapterIndex,
      _state.position,
    ).inMilliseconds;
    if (currentGlobalPositionMs > _maxReachedGlobalPositionMs) {
      _maxReachedGlobalPositionMs = currentGlobalPositionMs;
    }
  }

  void _rememberCurrentChapterPosition() {
    final chapter = _state.currentChapter;
    if (chapter == null) {
      return;
    }
    _rememberChapterPosition(chapter, _state.position);
    _chapterResumePositionsByIndex[_state.chapterIndex] = _clampPosition(
      _state.position,
      chapter,
    );
  }

  void _rememberChapterPosition(
    AudioPlaybackChapter chapter,
    Duration position,
  ) {
    _chapterResumePositions[chapter.id] = _clampPosition(position, chapter);
  }

  Duration _chapterResumePositionFor(AudioPlaybackBook book, int index) {
    final normalizedIndex = _clampChapterIndex(book, index);
    final chapter = book.chapters[normalizedIndex];
    final position =
        _chapterResumePositionsByIndex[normalizedIndex] ??
        _chapterResumePositions[chapter.id];
    return position == null ? Duration.zero : _clampPosition(position, chapter);
  }

  Duration _bookPositionFor(
    AudioPlaybackBook book,
    int chapterIndex,
    Duration chapterPosition,
  ) {
    final previous = book.chapters
        .take(chapterIndex)
        .fold(Duration.zero, (sum, chapter) => sum + chapter.duration);
    return previous + chapterPosition;
  }

  bool _isSameBookIdentity(AudioPlaybackBook left, AudioPlaybackBook right) {
    if (left.sourceId != right.sourceId) {
      return false;
    }
    return left.versionId == right.versionId ||
        (left.sourceBookId != null &&
            left.sourceBookId == right.sourceBookId) ||
        left.id == right.id;
  }

  String _chapterLoadIdentity(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) {
    final source = chapter.mediaSource;
    final headers = source?.headers.entries.toList()
      ?..sort((left, right) => left.key.compareTo(right.key));
    final headerLabel =
        headers?.map((entry) => '${entry.key}=${entry.value}').join('&') ?? '';
    return [
      book.sourceId,
      book.versionId,
      book.sourceBookId ?? '',
      book.id,
      chapter.id,
      chapter.index.toString(),
      source?.type.name ?? '',
      source?.uri.toString() ?? '',
      headerLabel,
    ].join('|');
  }
}
