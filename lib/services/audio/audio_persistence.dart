import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../domain/models/playback_session.dart';

abstract interface class PlaybackPersistenceStore {
  Future<PlaybackSession?> loadSession({String id = 'active'});

  Future<void> saveSession(PlaybackSession session);

  Future<void> saveProgress(PlaybackProgressSnapshot progress);
}

class PlaybackProgressSnapshot {
  const PlaybackProgressSnapshot({
    required this.bookId,
    required this.bookVersionId,
    required this.currentChapterId,
    required this.currentPositionMs,
    required this.maxReachedGlobalPositionMs,
    required this.totalDurationMs,
    required this.listenedDurationMs,
    required this.percent,
    required this.isFinished,
    required this.lastPlayedAt,
  });

  final String bookId;
  final String bookVersionId;
  final String? currentChapterId;
  final int currentPositionMs;
  final int maxReachedGlobalPositionMs;
  final int totalDurationMs;
  final int listenedDurationMs;
  final double percent;
  final bool isFinished;
  final DateTime lastPlayedAt;
}

class DriftPlaybackPersistenceStore implements PlaybackPersistenceStore {
  DriftPlaybackPersistenceStore(this._db);

  final AppDatabase _db;

  @override
  Future<PlaybackSession?> loadSession({String id = 'active'}) async {
    final query = _db.select(_db.playbackSessions)
      ..where((session) => session.id.equals(id));
    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    return PlaybackSession(
      id: row.id,
      activeBookId: row.activeBookId,
      activeBookVersionId: row.activeBookVersionId,
      activeSourceId: row.activeSourceId,
      activeChapterId: row.activeChapterId,
      positionMs: row.positionMs,
      speed: row.speed,
      volume: row.volume,
      isPlaying: row.isPlaying,
      playerPageIndex: row.playerPageIndex,
      sleepTimerRemainingMs: row.sleepTimerRemainingMs,
      sleepTimerMode: _sleepTimerMode(row.sleepTimerMode),
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> saveProgress(PlaybackProgressSnapshot progress) async {
    final existingQuery = _db.select(_db.playbackProgressEntries)
      ..where(
        (row) =>
            row.bookId.equals(progress.bookId) &
            row.bookVersionId.equals(progress.bookVersionId),
      );
    final existing = await existingQuery.getSingleOrNull();
    final maxReached = existing == null
        ? progress.maxReachedGlobalPositionMs
        : existing.maxReachedGlobalPositionMs >
              progress.maxReachedGlobalPositionMs
        ? existing.maxReachedGlobalPositionMs
        : progress.maxReachedGlobalPositionMs;

    await _db
        .into(_db.playbackProgressEntries)
        .insertOnConflictUpdate(
          PlaybackProgressEntriesCompanion(
            bookId: Value(progress.bookId),
            bookVersionId: Value(progress.bookVersionId),
            currentChapterId: Value(progress.currentChapterId),
            currentPositionMs: Value(progress.currentPositionMs),
            maxReachedGlobalPositionMs: Value(maxReached),
            totalDurationMs: Value(progress.totalDurationMs),
            listenedDurationMs: Value(progress.listenedDurationMs),
            percent: Value(progress.percent),
            isFinished: Value(progress.isFinished),
            lastPlayedAt: Value(progress.lastPlayedAt),
          ),
        );
  }

  @override
  Future<void> saveSession(PlaybackSession session) async {
    await _db
        .into(_db.playbackSessions)
        .insertOnConflictUpdate(
          PlaybackSessionsCompanion(
            id: Value(session.id),
            activeBookId: Value(session.activeBookId),
            activeBookVersionId: Value(session.activeBookVersionId),
            activeSourceId: Value(session.activeSourceId),
            activeChapterId: Value(session.activeChapterId),
            positionMs: Value(session.positionMs),
            speed: Value(session.speed),
            volume: Value(session.volume),
            isPlaying: Value(session.isPlaying),
            playerPageIndex: Value(session.playerPageIndex),
            sleepTimerRemainingMs: Value(session.sleepTimerRemainingMs),
            sleepTimerMode: Value(session.sleepTimerMode.name),
            updatedAt: Value(session.updatedAt),
          ),
        );
  }

  SleepTimerMode _sleepTimerMode(String value) {
    return SleepTimerMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => SleepTimerMode.unknown,
    );
  }
}
