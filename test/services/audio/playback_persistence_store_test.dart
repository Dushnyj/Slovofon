import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/database/app_database.dart';
import 'package:slovofon/domain/models/playback_session.dart';
import 'package:slovofon/services/audio/audio_persistence.dart';

void main() {
  group('DriftPlaybackPersistenceStore', () {
    late AppDatabase db;
    late DriftPlaybackPersistenceStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftPlaybackPersistenceStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('saves and loads the active playback session', () async {
      final session = PlaybackSession(
        id: 'active',
        activeBookId: 'book-1',
        activeBookVersionId: 'version-1',
        activeSourceId: 'yakniga',
        activeChapterId: 'chapter-2',
        positionMs: const Duration(minutes: 7).inMilliseconds,
        speed: 1.25,
        isPlaying: true,
        sleepTimerRemainingMs: const Duration(minutes: 20).inMilliseconds,
        sleepTimerMode: SleepTimerMode.stopAfterDuration,
        updatedAt: DateTime.utc(2026, 5, 26, 10),
      );

      await store.saveSession(session);

      final restored = await store.loadSession();
      expect(restored?.activeBookId, 'book-1');
      expect(restored?.activeChapterId, 'chapter-2');
      expect(restored?.positionMs, const Duration(minutes: 7).inMilliseconds);
      expect(restored?.speed, 1.25);
      expect(restored?.isPlaying, isTrue);
      expect(restored?.sleepTimerMode, SleepTimerMode.stopAfterDuration);
    });

    test(
      'round-trips chapter-end mode without converting it to a duration timer',
      () async {
        await store.saveSession(
          PlaybackSession(
            id: 'active',
            activeBookId: 'book-1',
            activeBookVersionId: 'version-1',
            activeChapterId: 'chapter-2',
            positionMs: 480000,
            speed: 2,
            volume: 0.4,
            sleepTimerRemainingMs: 120000,
            sleepTimerMode: SleepTimerMode.stopAtChapterEnd,
            updatedAt: DateTime.utc(2026, 9, 5),
          ),
        );
        final restored = await store.loadSession();
        expect(restored?.sleepTimerMode, SleepTimerMode.stopAtChapterEnd);
        expect(restored?.sleepTimerRemainingMs, 120000);
        expect(restored?.activeChapterId, 'chapter-2');
        expect(restored?.speed, 2);
        expect(restored?.volume, 0.4);
      },
    );

    test(
      'upserts playback progress without decreasing max reached position',
      () async {
        final first = PlaybackProgressSnapshot(
          bookId: 'book-1',
          bookVersionId: 'version-1',
          currentChapterId: 'chapter-2',
          currentPositionMs: const Duration(minutes: 9).inMilliseconds,
          maxReachedGlobalPositionMs: const Duration(
            minutes: 19,
          ).inMilliseconds,
          totalDurationMs: const Duration(minutes: 30).inMilliseconds,
          listenedDurationMs: const Duration(minutes: 19).inMilliseconds,
          percent: 63.33,
          isFinished: false,
          lastPlayedAt: DateTime.utc(2026, 5, 26, 10),
        );
        final rewind = PlaybackProgressSnapshot(
          bookId: 'book-1',
          bookVersionId: 'version-1',
          currentChapterId: 'chapter-1',
          currentPositionMs: const Duration(minutes: 2).inMilliseconds,
          maxReachedGlobalPositionMs: const Duration(minutes: 2).inMilliseconds,
          totalDurationMs: const Duration(minutes: 30).inMilliseconds,
          listenedDurationMs: const Duration(minutes: 2).inMilliseconds,
          percent: 6.66,
          isFinished: false,
          lastPlayedAt: DateTime.utc(2026, 5, 26, 11),
        );

        await store.saveProgress(first);
        await store.saveProgress(rewind);

        final rows = await db.select(db.playbackProgressEntries).get();
        expect(rows, hasLength(1));
        expect(
          rows.single.maxReachedGlobalPositionMs,
          const Duration(minutes: 19).inMilliseconds,
        );
        expect(rows.single.currentChapterId, 'chapter-1');
        expect(rows.single.percent, 6.66);
      },
    );

    test('loads persisted playback progress for search cards', () async {
      final now = DateTime.utc(2026, 5, 26, 10);
      await store.saveProgress(
        PlaybackProgressSnapshot(
          bookId: 'izib-book-2033',
          bookVersionId: 'izib-2033',
          currentChapterId: 'chapter-1',
          currentPositionMs: 120000,
          maxReachedGlobalPositionMs: 120000,
          totalDurationMs: 600000,
          listenedDurationMs: 120000,
          percent: 20,
          isFinished: false,
          lastPlayedAt: now,
        ),
      );

      final progress = await store.loadProgress();

      expect(progress, hasLength(1));
      expect(progress.single.bookVersionId, 'izib-2033');
      expect(progress.single.percent, 20);
    });
  });
}
