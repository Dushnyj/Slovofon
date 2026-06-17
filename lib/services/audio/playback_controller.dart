import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/playback_session.dart';
import 'audio_engine.dart';
import 'audio_persistence.dart';
import 'audio_state.dart';

typedef PlaybackBookResolver =
    Future<AudioPlaybackBook> Function(AudioPlaybackBook book);

class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required AudioEngine engine,
    PlaybackPersistenceStore? persistence,
    PlaybackBookMetadataStore? bookMetadataStore,
    PlaybackBookResolver? playbackBookResolver,
    DateTime Function()? clock,
    Duration persistenceInterval = const Duration(seconds: 5),
  }) : _engine = engine,
       _persistence = persistence,
       _bookMetadataStore = bookMetadataStore,
       _playbackBookResolver = playbackBookResolver,
       _clock = clock ?? DateTime.now,
       _persistenceInterval = persistenceInterval {
    _engineSubscription = _engine.snapshots.listen(_handleEngineSnapshot);
  }

  final AudioEngine _engine;
  final PlaybackPersistenceStore? _persistence;
  final PlaybackBookMetadataStore? _bookMetadataStore;
  final PlaybackBookResolver? _playbackBookResolver;
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
  final _chapterResumePositions = <String, Duration>{};
  final _chapterResumePositionsByIndex = <int, Duration>{};

  AudioPlaybackState get state => _state;

  Future<bool> loadSavedSession(AudioPlaybackBook book) async {
    final session = await _persistence?.loadSession();
    if (session == null ||
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
    );
    if (!loaded) {
      return;
    }

    await _bookMetadataStore?.saveBook(book);
    await _engine.setSpeed(_state.speed);

    if (autoPlay) {
      _startEnginePlayback();
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

    _state = AudioPlaybackState(
      book: book,
      status: AudioPlaybackStatus.loading,
      chapterIndex: normalizedIndex,
      position: _clampPosition(position, book.chapters[normalizedIndex]),
      speed: _normalizeSpeed(session.speed),
      sleepTimerRemaining: restoredSleepTimer,
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
    );
    if (!loaded) {
      return;
    }

    await _bookMetadataStore?.saveBook(book);
    await _engine.setSpeed(_state.speed);

    if (session.isPlaying) {
      _startEnginePlayback();
    }

    _state = _state.copyWith(
      status: session.isPlaying
          ? AudioPlaybackStatus.playing
          : AudioPlaybackStatus.paused,
      clearError: true,
    );
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
      isPlaying: _state.isPlaying,
      sleepTimerRemainingMs: _state.sleepTimerRemaining?.inMilliseconds,
      sleepTimerMode: _state.sleepTimerRemaining == null
          ? SleepTimerMode.off
          : SleepTimerMode.stopAfterDuration,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Future<void> play() async {
    if (!_state.hasBook) {
      return;
    }

    final prepared = await _preparePositionForPlayback();
    if (!prepared) {
      return;
    }
    _startEnginePlayback();
    _state = _state.copyWith(
      status: AudioPlaybackStatus.playing,
      clearError: true,
    );
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<void> pause() async {
    if (!_state.hasBook) {
      return;
    }

    _pendingPlayRequest = false;
    await _engine.pause();
    _state = _state.copyWith(status: AudioPlaybackStatus.paused);
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<void> togglePlayPause() {
    return _state.isPlaying ? pause() : play();
  }

  Future<void> seek(Duration position) async {
    final chapter = _state.currentChapter;
    if (chapter == null) {
      return;
    }

    final normalizedPosition = _clampPosition(position, chapter);
    await _engine.seek(normalizedPosition);
    _state = _state.copyWith(position: normalizedPosition);
    _rememberCurrentChapterPosition();
    _updateMaxReachedPosition();
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<void> skipBy(Duration delta) {
    return seek(_state.position + delta);
  }

  Future<void> setSpeed(double speed) async {
    if (!_state.hasBook) {
      return;
    }

    final normalizedSpeed = _normalizeSpeed(speed);
    await _engine.setSpeed(normalizedSpeed);
    _state = _state.copyWith(speed: normalizedSpeed);
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<void> nextChapter() async {
    final activeBook = _state.book;
    if (activeBook == null) {
      return;
    }

    final nextIndex = _state.chapterIndex + 1;
    if (nextIndex >= activeBook.chapters.length) {
      _state = _state.copyWith(status: AudioPlaybackStatus.completed);
      notifyListeners();
      await _persistPlayback(force: true);
      return;
    }

    await _loadChapterAt(
      nextIndex,
      position: _chapterResumePositionFor(activeBook, nextIndex),
    );
  }

  Future<void> previousChapter() async {
    final activeBook = _state.book;
    if (activeBook == null) {
      return;
    }

    final previousIndex = (_state.chapterIndex - 1).clamp(
      0,
      activeBook.chapters.length - 1,
    );
    await _loadChapterAt(
      previousIndex,
      position: _chapterResumePositionFor(activeBook, previousIndex),
    );
  }

  Future<void> playChapterAt(int index) async {
    final activeBook = _state.book;
    if (activeBook == null) {
      return;
    }

    final normalizedIndex = _clampChapterIndex(activeBook, index);
    if (normalizedIndex == _state.chapterIndex) {
      await play();
      return;
    }

    await _loadChapterAt(
      normalizedIndex,
      position: _chapterResumePositionFor(activeBook, normalizedIndex),
      playAfterLoad: true,
    );
  }

  void setSleepTimer(Duration duration) {
    _state = _state.copyWith(sleepTimerRemaining: _nonNegative(duration));
    notifyListeners();
    unawaited(_persistPlayback(force: true));
  }

  void setSleepTimerToChapterEnd() {
    final remaining = _remainingCurrentChapterDuration();
    if (remaining == null) {
      return;
    }
    _state = _state.copyWith(sleepTimerRemaining: remaining);
    notifyListeners();
    unawaited(_persistPlayback(force: true));
  }

  void clearSleepTimer() {
    _state = _state.copyWith(clearSleepTimer: true);
    notifyListeners();
    unawaited(_persistPlayback(force: true));
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
    if (elapsed <= Duration.zero) {
      return;
    }

    if (!_state.isPlaying) {
      return;
    }

    final remaining = _state.sleepTimerRemaining;
    if (remaining == null) {
      return;
    }

    final nextRemaining = _nonNegative(remaining - elapsed);
    final expired = nextRemaining == Duration.zero;
    // When the timer expires we clear it instead of leaving Duration.zero.
    // A lingering zero value gets persisted and restored on the next launch,
    // which then immediately re-pauses playback via the 1s ticker.
    _state = expired
        ? _state.copyWith(clearSleepTimer: true)
        : _state.copyWith(sleepTimerRemaining: nextRemaining);

    if (expired && _state.isPlaying) {
      _pendingPlayRequest = false;
      await _engine.pause();
      _state = _state.copyWith(status: AudioPlaybackStatus.paused);
    }

    notifyListeners();
    await _persistPlayback();
  }

  @override
  void dispose() {
    unawaited(_persistPlayback(force: true));
    unawaited(_engineSubscription.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }

  void _handleEngineSnapshot(AudioEngineSnapshot snapshot) {
    if (_engineLoadDepth > 0) {
      return;
    }
    var chapter = _state.currentChapter;
    if (chapter == null) {
      return;
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
      unawaited(_bookMetadataStore?.saveBook(_state.book!));
    }
    final position = _clampPosition(snapshot.position, chapter);
    if (snapshot.processingState == AudioEngineProcessingState.completed) {
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
    if (_handlingEngineCompletion) {
      return;
    }

    _handlingEngineCompletion = true;
    try {
      final activeBook = await _refreshActiveBookForPlayback();
      if (activeBook == null) {
        return;
      }

      final nextIndex = _state.chapterIndex + 1;
      if (nextIndex >= activeBook.chapters.length) {
        await _engine.pause();
        _state = _state.copyWith(status: AudioPlaybackStatus.completed);
        notifyListeners();
        await _persistPlayback(force: true);
        return;
      }

      await _loadChapterAt(
        nextIndex,
        position: Duration.zero,
        playAfterLoad: continuePlayback,
      );
    } finally {
      _handlingEngineCompletion = false;
    }
  }

  Future<bool> _preparePositionForPlayback() async {
    await _refreshActiveBookForPlayback();
    var activeBook = _state.book;
    var chapter = _state.currentChapter;
    if (activeBook == null || chapter == null) {
      return false;
    }
    if (chapter.duration <= Duration.zero ||
        _state.position < chapter.duration) {
      return _ensureCurrentEngineChapterLoaded(activeBook, chapter);
    }

    final nextIndex = _state.chapterIndex + 1;
    if (nextIndex < activeBook.chapters.length) {
      await _loadChapterAt(
        nextIndex,
        position: Duration.zero,
        playAfterLoad: false,
      );
      return _state.status != AudioPlaybackStatus.error;
    }

    await _engine.seek(Duration.zero);
    _state = _state.copyWith(
      position: Duration.zero,
      status: AudioPlaybackStatus.paused,
      clearError: true,
    );
    notifyListeners();
    activeBook = _state.book;
    chapter = _state.currentChapter;
    return activeBook != null && chapter != null
        ? _ensureCurrentEngineChapterLoaded(activeBook, chapter)
        : false;
  }

  Future<bool> _ensureCurrentEngineChapterLoaded(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    final identity = _chapterLoadIdentity(book, chapter);
    if (_loadedChapterIdentity == identity) {
      return true;
    }

    final normalizedPosition = _clampPosition(_state.position, chapter);
    final loaded = await _loadEngineChapter(
      book,
      chapter,
      position: normalizedPosition,
    );
    if (!loaded) {
      return false;
    }
    if (normalizedPosition != _state.position) {
      _state = _state.copyWith(position: normalizedPosition);
    }
    if (normalizedPosition > Duration.zero) {
      await _engine.seek(normalizedPosition);
    }
    await _engine.setSpeed(_state.speed);
    return true;
  }

  Future<void> _loadChapterAt(
    int index, {
    required Duration position,
    bool? playAfterLoad,
  }) async {
    _rememberCurrentChapterPosition();
    final activeBook = await _refreshActiveBookForPlayback();
    if (activeBook == null) {
      return;
    }

    final normalizedIndex = _clampChapterIndex(activeBook, index);
    final chapter = activeBook.chapters[normalizedIndex];
    final wasPlaying = playAfterLoad ?? _state.isPlaying;
    final normalizedPosition = _clampPosition(position, chapter);
    _pendingPlayRequest = false;

    final loaded = await _loadEngineChapter(
      activeBook,
      chapter,
      position: normalizedPosition,
    );
    if (!loaded) {
      return;
    }

    _state = _state.copyWith(
      chapterIndex: normalizedIndex,
      position: normalizedPosition,
      status: wasPlaying
          ? AudioPlaybackStatus.playing
          : AudioPlaybackStatus.paused,
      clearError: true,
    );
    if (normalizedPosition > Duration.zero) {
      await _engine.seek(normalizedPosition);
    }
    await _engine.setSpeed(_state.speed);
    if (wasPlaying) {
      _startEnginePlayback();
    }

    _rememberCurrentChapterPosition();
    _updateMaxReachedPosition();
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<bool> _loadEngineChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    required Duration position,
  }) async {
    _engineLoadDepth++;
    try {
      await _engine.load(chapter, position: position, book: book);
      _loadedChapterIdentity = _chapterLoadIdentity(book, chapter);
      return true;
    } catch (error) {
      _pendingPlayRequest = false;
      _loadedChapterIdentity = null;
      _state = _state.copyWith(
        status: AudioPlaybackStatus.error,
        errorMessage: _errorMessage(error),
      );
      notifyListeners();
      return false;
    } finally {
      _engineLoadDepth--;
    }
  }

  Future<AudioPlaybackBook?> _refreshActiveBookForPlayback() async {
    final activeBook = _state.book;
    final resolver = _playbackBookResolver;
    if (activeBook == null || resolver == null) {
      return activeBook;
    }

    final AudioPlaybackBook resolvedBook;
    try {
      resolvedBook = await resolver(activeBook);
    } catch (error, stackTrace) {
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
    if (!_isSameBookIdentity(activeBook, resolvedBook)) {
      return activeBook;
    }

    _state = _state.copyWith(book: resolvedBook);
    unawaited(_bookMetadataStore?.saveBook(resolvedBook));
    notifyListeners();
    return resolvedBook;
  }

  void _startEnginePlayback() {
    _pendingPlayRequest = true;
    unawaited(
      _engine.play().catchError((Object error, StackTrace stackTrace) {
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

  Future<void> _persistPlayback({bool force = false}) async {
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

    await persistence.saveSession(toPlaybackSession(updatedAt: now));
    await persistence.saveProgress(_progressSnapshot(now));
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
