import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/playback_session.dart';
import 'audio_engine.dart';
import 'audio_persistence.dart';
import 'audio_state.dart';

class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required AudioEngine engine,
    PlaybackPersistenceStore? persistence,
    PlaybackBookMetadataStore? bookMetadataStore,
    DateTime Function()? clock,
    Duration persistenceInterval = const Duration(seconds: 5),
  }) : _engine = engine,
       _persistence = persistence,
       _bookMetadataStore = bookMetadataStore,
       _clock = clock ?? DateTime.now,
       _persistenceInterval = persistenceInterval {
    _engineSubscription = _engine.snapshots.listen(_handleEngineSnapshot);
  }

  final AudioEngine _engine;
  final PlaybackPersistenceStore? _persistence;
  final PlaybackBookMetadataStore? _bookMetadataStore;
  final DateTime Function() _clock;
  final Duration _persistenceInterval;
  late final StreamSubscription<AudioEngineSnapshot> _engineSubscription;

  AudioPlaybackState _state = AudioPlaybackState.idle;
  DateTime? _lastPersistedAt;
  int _maxReachedGlobalPositionMs = 0;
  bool _handlingEngineCompletion = false;

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
    final chapterIndex = book.chapters.indexWhere(
      (chapter) => chapter.id == session.activeChapterId,
    );
    final normalizedIndex = chapterIndex < 0 ? 0 : chapterIndex;
    final position = Duration(milliseconds: session.positionMs);

    _state = AudioPlaybackState(
      book: book,
      status: AudioPlaybackStatus.loading,
      chapterIndex: normalizedIndex,
      position: _clampPosition(position, book.chapters[normalizedIndex]),
      speed: _normalizeSpeed(session.speed),
      sleepTimerRemaining: session.sleepTimerRemainingMs == null
          ? null
          : Duration(milliseconds: session.sleepTimerRemainingMs!),
    );
    _maxReachedGlobalPositionMs = _bookPositionFor(
      book,
      normalizedIndex,
      _state.position,
    ).inMilliseconds;
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
    if (!_state.hasBook || _state.status == AudioPlaybackStatus.error) {
      return;
    }

    await _preparePositionForPlayback();
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

    await _loadChapterAt(nextIndex, position: Duration.zero);
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
    await _loadChapterAt(previousIndex, position: Duration.zero);
  }

  void setSleepTimer(Duration duration) {
    _state = _state.copyWith(sleepTimerRemaining: _nonNegative(duration));
    notifyListeners();
    unawaited(_persistPlayback(force: true));
  }

  void clearSleepTimer() {
    _state = _state.copyWith(clearSleepTimer: true);
    notifyListeners();
    unawaited(_persistPlayback(force: true));
  }

  Future<void> tick(Duration elapsed) async {
    if (elapsed <= Duration.zero) {
      return;
    }

    if (_state.isPlaying) {
      await _advancePosition(elapsed);
    }

    final remaining = _state.sleepTimerRemaining;
    if (remaining == null) {
      return;
    }

    final nextRemaining = _nonNegative(remaining - elapsed);
    _state = _state.copyWith(sleepTimerRemaining: nextRemaining);

    if (nextRemaining == Duration.zero && _state.isPlaying) {
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
    final chapter = _state.currentChapter;
    if (chapter == null) {
      return;
    }

    final position = _clampPosition(snapshot.position, chapter);
    if (snapshot.processingState == AudioEngineProcessingState.completed) {
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

    _state = _state.copyWith(
      position: position,
      status: _statusFromEngineSnapshot(snapshot),
      errorMessage: snapshot.errorMessage,
      clearError: snapshot.processingState != AudioEngineProcessingState.error,
    );
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
      final activeBook = _state.book;
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

  Future<void> _advancePosition(Duration elapsed) async {
    final chapter = _state.currentChapter;
    final activeBook = _state.book;
    if (chapter == null || activeBook == null) {
      return;
    }

    final nextPosition = _state.position + elapsed;
    if (nextPosition < chapter.duration) {
      _state = _state.copyWith(position: nextPosition);
      await _engine.seek(nextPosition);
      _updateMaxReachedPosition();
      notifyListeners();
      return;
    }

    final overflow = nextPosition - chapter.duration;
    final nextIndex = _state.chapterIndex + 1;
    if (nextIndex >= activeBook.chapters.length) {
      await _engine.pause();
      _state = _state.copyWith(
        position: chapter.duration,
        status: AudioPlaybackStatus.completed,
      );
      _updateMaxReachedPosition();
      notifyListeners();
      await _persistPlayback(force: true);
      return;
    }

    await _loadChapterAt(nextIndex, position: overflow);
  }

  Future<void> _preparePositionForPlayback() async {
    final activeBook = _state.book;
    final chapter = _state.currentChapter;
    if (activeBook == null ||
        chapter == null ||
        chapter.duration <= Duration.zero ||
        _state.position < chapter.duration) {
      return;
    }

    final nextIndex = _state.chapterIndex + 1;
    if (nextIndex < activeBook.chapters.length) {
      await _loadChapterAt(
        nextIndex,
        position: Duration.zero,
        playAfterLoad: false,
      );
      return;
    }

    await _engine.seek(Duration.zero);
    _state = _state.copyWith(
      position: Duration.zero,
      status: AudioPlaybackStatus.paused,
      clearError: true,
    );
    notifyListeners();
  }

  Future<void> _loadChapterAt(
    int index, {
    required Duration position,
    bool? playAfterLoad,
  }) async {
    final activeBook = _state.book;
    if (activeBook == null) {
      return;
    }

    final chapter = activeBook.chapters[index];
    final wasPlaying = playAfterLoad ?? _state.isPlaying;
    final normalizedPosition = _clampPosition(position, chapter);

    final loaded = await _loadEngineChapter(
      activeBook,
      chapter,
      position: normalizedPosition,
    );
    if (!loaded) {
      return;
    }

    await _engine.setSpeed(_state.speed);
    if (wasPlaying) {
      _startEnginePlayback();
    }

    _state = _state.copyWith(
      chapterIndex: index,
      position: normalizedPosition,
      status: wasPlaying
          ? AudioPlaybackStatus.playing
          : AudioPlaybackStatus.paused,
      clearError: true,
    );
    _updateMaxReachedPosition();
    notifyListeners();
    await _persistPlayback(force: true);
  }

  Future<bool> _loadEngineChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    required Duration position,
  }) async {
    try {
      await _engine.load(chapter, position: position, book: book);
      return true;
    } catch (error) {
      _state = _state.copyWith(
        status: AudioPlaybackStatus.error,
        errorMessage: _errorMessage(error),
      );
      notifyListeners();
      return false;
    }
  }

  void _startEnginePlayback() {
    unawaited(
      _engine.play().catchError((Object error, StackTrace stackTrace) {
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
    if (position > chapter.duration) {
      return chapter.duration;
    }
    return position;
  }

  Duration _nonNegative(Duration duration) {
    return duration < Duration.zero ? Duration.zero : duration;
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
        return _state.hasBook
            ? AudioPlaybackStatus.paused
            : AudioPlaybackStatus.idle;
      case AudioEngineProcessingState.loading:
        return AudioPlaybackStatus.loading;
      case AudioEngineProcessingState.buffering:
        return AudioPlaybackStatus.buffering;
      case AudioEngineProcessingState.ready:
        return snapshot.isPlaying
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
}
