import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/database/app_database.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/downloads/download_persistence.dart';

void main() {
  group('DriftDownloadPersistenceStore', () {
    late AppDatabase db;
    late DriftDownloadPersistenceStore store;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftDownloadPersistenceStore(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'recovers interrupted running tasks as paused and resumable',
      () async {
        final running = _task(status: DownloadTaskStatus.running);
        final completed = _task(
          id: 'download-completed',
          chapterId: 'chapter-2',
          status: DownloadTaskStatus.completed,
          progress: 1,
        );

        await store.saveTask(running);
        await store.saveTask(completed);

        final restored = await store.loadTasks(recoverInterrupted: true);

        expect(
          restored.where((task) => task.id == running.id).single.status,
          DownloadTaskStatus.paused,
        );
        expect(
          restored.where((task) => task.id == completed.id).single.status,
          DownloadTaskStatus.completed,
        );
      },
    );

    test(
      'updates chapter download status without touching playback progress',
      () async {
        await db
            .into(db.playbackProgressEntries)
            .insert(
              PlaybackProgressEntriesCompanion.insert(
                bookId: 'book-1',
                bookVersionId: 'version-1',
                lastPlayedAt: DateTime.utc(2026, 5, 26, 9),
              ),
            );

        await store.updateChapter(
          DownloadChapterUpdate(
            chapterId: 'chapter-1',
            status: DownloadTaskStatus.completed,
            progress: 1,
            localPath: r'C:\offline\chapter-1.bin',
            fileSizeBytes: 42,
            updatedAt: DateTime.utc(2026, 5, 26, 10),
          ),
        );

        final progress = await db.select(db.playbackProgressEntries).get();

        expect(progress, hasLength(1));
        expect(progress.single.currentPositionMs, 0);
      },
    );
  });
}

DownloadTask _task({
  String id = 'download-1',
  String? chapterId = 'chapter-1',
  DownloadTaskStatus status = DownloadTaskStatus.queued,
  double progress = 0,
}) {
  return DownloadTask(
    id: id,
    bookId: 'book-1',
    bookVersionId: 'version-1',
    chapterId: chapterId,
    sourceId: 'yakniga',
    type: DownloadTaskType.chapter,
    status: status,
    progress: progress,
    createdAt: DateTime.utc(2026, 5, 26, 9),
    updatedAt: DateTime.utc(2026, 5, 26, 10),
  );
}
