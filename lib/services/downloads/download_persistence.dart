import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../domain/models/download_task.dart';

abstract interface class DownloadPersistenceStore {
  Future<List<DownloadTask>> loadTasks({bool recoverInterrupted = false});

  Future<void> saveTask(DownloadTask task);

  Future<void> deleteTask(String id);

  Future<void> updateChapter(DownloadChapterUpdate update);
}

class DownloadChapterUpdate {
  const DownloadChapterUpdate({
    required this.chapterId,
    required this.status,
    required this.progress,
    required this.updatedAt,
    this.localPath,
    this.fileSizeBytes,
  });

  final String chapterId;
  final DownloadTaskStatus status;
  final double progress;
  final String? localPath;
  final int? fileSizeBytes;
  final DateTime updatedAt;
}

class DriftDownloadPersistenceStore implements DownloadPersistenceStore {
  DriftDownloadPersistenceStore(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<void> deleteTask(String id) async {
    await (_db.delete(
      _db.downloadTasks,
    )..where((row) => row.id.equals(id))).go();
  }

  @override
  Future<List<DownloadTask>> loadTasks({
    bool recoverInterrupted = false,
  }) async {
    final rows = await (_db.select(
      _db.downloadTasks,
    )..orderBy([(row) => OrderingTerm.asc(row.createdAt)])).get();
    final tasks = rows.map(_taskFromRow).toList();

    if (!recoverInterrupted) {
      return tasks;
    }

    final recovered = <DownloadTask>[];
    for (final task in tasks) {
      if (task.status == DownloadTaskStatus.running) {
        final paused = _copyTask(
          task,
          status: DownloadTaskStatus.paused,
          speedBytesPerSecond: 0,
          updatedAt: _clock(),
        );
        await saveTask(paused);
        recovered.add(paused);
      } else {
        recovered.add(task);
      }
    }

    return recovered;
  }

  @override
  Future<void> saveTask(DownloadTask task) async {
    await _db
        .into(_db.downloadTasks)
        .insertOnConflictUpdate(
          DownloadTasksCompanion(
            id: Value(task.id),
            bookId: Value(task.bookId),
            bookVersionId: Value(task.bookVersionId),
            chapterId: Value(task.chapterId),
            sourceId: Value(task.sourceId),
            type: Value(task.type.name),
            status: Value(task.status.name),
            priority: Value(task.priority),
            progress: Value(task.progress),
            downloadedBytes: Value(task.downloadedBytes),
            totalBytes: Value(task.totalBytes),
            speedBytesPerSecond: Value(task.speedBytesPerSecond),
            errorCode: Value(task.errorCode),
            errorMessage: Value(task.errorMessage),
            retryCount: Value(task.retryCount),
            createdAt: Value(task.createdAt),
            updatedAt: Value(task.updatedAt),
          ),
        );
  }

  @override
  Future<void> updateChapter(DownloadChapterUpdate update) async {
    await (_db.update(
      _db.chapters,
    )..where((row) => row.id.equals(update.chapterId))).write(
      ChaptersCompanion(
        localPath: Value(update.localPath),
        fileSizeBytes: Value(update.fileSizeBytes),
        downloadStatus: Value(_chapterStatus(update.status)),
        downloadProgress: Value(update.progress),
        updatedAt: Value(update.updatedAt),
      ),
    );
  }

  DownloadTask _taskFromRow(DownloadTaskRow row) {
    return DownloadTask(
      id: row.id,
      bookId: row.bookId,
      bookVersionId: row.bookVersionId,
      chapterId: row.chapterId,
      sourceId: row.sourceId,
      type: _type(row.type),
      status: _status(row.status),
      priority: row.priority,
      progress: row.progress,
      downloadedBytes: row.downloadedBytes,
      totalBytes: row.totalBytes,
      speedBytesPerSecond: row.speedBytesPerSecond,
      errorCode: row.errorCode,
      errorMessage: row.errorMessage,
      retryCount: row.retryCount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  DownloadTaskType _type(String value) {
    return DownloadTaskType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => DownloadTaskType.chapter,
    );
  }

  DownloadTaskStatus _status(String value) {
    return DownloadTaskStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => DownloadTaskStatus.failed,
    );
  }

  String _chapterStatus(DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.queued => 'queued',
      DownloadTaskStatus.running => 'running',
      DownloadTaskStatus.paused => 'paused',
      DownloadTaskStatus.completed => 'completed',
      DownloadTaskStatus.failed => 'failed',
      DownloadTaskStatus.canceled => 'canceled',
    };
  }

  DownloadTask _copyTask(
    DownloadTask task, {
    DownloadTaskStatus? status,
    int? speedBytesPerSecond,
    DateTime? updatedAt,
  }) {
    return DownloadTask(
      id: task.id,
      bookId: task.bookId,
      bookVersionId: task.bookVersionId,
      chapterId: task.chapterId,
      sourceId: task.sourceId,
      type: task.type,
      status: status ?? task.status,
      priority: task.priority,
      progress: task.progress,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? task.speedBytesPerSecond,
      errorCode: task.errorCode,
      errorMessage: task.errorMessage,
      retryCount: task.retryCount,
      createdAt: task.createdAt,
      updatedAt: updatedAt ?? task.updatedAt,
    );
  }
}

class MemoryDownloadPersistenceStore implements DownloadPersistenceStore {
  final _tasks = <String, DownloadTask>{};

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<DownloadTask>> loadTasks({
    bool recoverInterrupted = false,
  }) async {
    final tasks = _tasks.values.map((task) {
      if (recoverInterrupted && task.status == DownloadTaskStatus.running) {
        return _copyTask(
          task,
          status: DownloadTaskStatus.paused,
          speedBytesPerSecond: 0,
          updatedAt: DateTime.now(),
        );
      }
      return task;
    }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _tasks
      ..clear()
      ..addEntries(tasks.map((task) => MapEntry(task.id, task)));
    return tasks;
  }

  @override
  Future<void> saveTask(DownloadTask task) async {
    _tasks[task.id] = task;
  }

  @override
  Future<void> updateChapter(DownloadChapterUpdate update) async {}

  DownloadTask _copyTask(
    DownloadTask task, {
    DownloadTaskStatus? status,
    int? speedBytesPerSecond,
    DateTime? updatedAt,
  }) {
    return DownloadTask(
      id: task.id,
      bookId: task.bookId,
      bookVersionId: task.bookVersionId,
      chapterId: task.chapterId,
      sourceId: task.sourceId,
      type: task.type,
      status: status ?? task.status,
      priority: task.priority,
      progress: task.progress,
      downloadedBytes: task.downloadedBytes,
      totalBytes: task.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? task.speedBytesPerSecond,
      errorCode: task.errorCode,
      errorMessage: task.errorMessage,
      retryCount: task.retryCount,
      createdAt: task.createdAt,
      updatedAt: updatedAt ?? task.updatedAt,
    );
  }
}
