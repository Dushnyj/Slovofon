import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/models/download_task.dart';
import '../audio/audio_state.dart';
import 'download_client.dart';
import 'download_persistence.dart';
import 'download_storage.dart';

class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required DownloadClient client,
    required FileDownloadStorage storage,
    required DownloadPersistenceStore persistence,
    DateTime Function()? clock,
    int maxConcurrentDownloads = 2,
  }) : _client = client,
       _storage = storage,
       _persistence = persistence,
       _clock = clock ?? DateTime.now,
       _maxConcurrentDownloads = maxConcurrentDownloads.clamp(1, 3);

  final DownloadClient _client;
  final FileDownloadStorage _storage;
  final DownloadPersistenceStore _persistence;
  final DateTime Function() _clock;
  final int _maxConcurrentDownloads;

  final _tasks = <String, DownloadTask>{};
  final _jobs = <String, _DownloadJob>{};
  final _activeTokens = <String, DownloadCancellationToken>{};
  final _activeFutures = <String, Future<void>>{};

  bool _disposed = false;

  List<DownloadTask> get tasks {
    return _tasks.values.toList()..sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      if (priority != 0) {
        return priority;
      }
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  DownloadTask? taskById(String id) => _tasks[id];

  AudioPlaybackBook? bookForTask(String taskId) => _jobs[taskId]?.book;

  void attachBookContext(AudioPlaybackBook book) {
    for (final chapter in book.chapters) {
      _jobs[_taskId(book, chapter)] = _DownloadJob(
        book: book,
        chapter: chapter,
      );
    }
  }

  DownloadTask? taskForChapter(String chapterId) {
    for (final task in _tasks.values) {
      if (task.chapterId == chapterId) {
        return task;
      }
    }
    return null;
  }

  Future<void> loadPersistedTasks({bool recoverInterrupted = true}) async {
    final persisted = await _persistence.loadTasks(
      recoverInterrupted: recoverInterrupted,
    );
    _tasks
      ..clear()
      ..addEntries(persisted.map((task) => MapEntry(task.id, task)));
    _jobs.clear();
    await _restorePersistedBookContexts(persisted);
    _notify();
  }

  Future<List<DownloadTask>> enqueueBook(AudioPlaybackBook book) async {
    await _storage.writeMetadata(book);
    final queued = <DownloadTask>[];
    for (final chapter in book.chapters) {
      queued.add(await enqueueChapter(book, chapter, writeMetadata: false));
    }
    return queued;
  }

  Future<List<DownloadTask>> enqueueMissingChapters(
    AudioPlaybackBook book,
  ) async {
    final queued = <DownloadTask>[];
    for (final chapter in book.chapters) {
      final completed = await _storage.completedChapterFile(book, chapter);
      if (completed == null) {
        queued.add(await enqueueChapter(book, chapter));
      }
    }
    return queued;
  }

  Future<DownloadTask> enqueueChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    bool writeMetadata = true,
  }) async {
    final mediaSource = chapter.mediaSource;
    if (mediaSource == null) {
      final failed = _newTask(
        book,
        chapter,
        status: DownloadTaskStatus.failed,
        errorCode: 'missing_media_source',
        errorMessage: 'Chapter has no downloadable media source.',
      );
      await _saveTask(failed);
      return failed;
    }

    if (writeMetadata) {
      await _storage.writeMetadata(book);
    }

    final existingFile = await _storage.completedChapterFile(book, chapter);
    if (existingFile != null) {
      final completed = _newTask(
        book,
        chapter,
        status: DownloadTaskStatus.completed,
        progress: 1,
        downloadedBytes: await existingFile.length(),
        totalBytes: await existingFile.length(),
      );
      _jobs[completed.id] = _DownloadJob(book: book, chapter: chapter);
      await _saveTask(completed);
      await _persistChapter(
        completed,
        localPath: existingFile.path,
        fileSizeBytes: completed.downloadedBytes,
      );
      return completed;
    }

    final current = taskForChapter(chapter.id);
    final nextTask = current == null
        ? _newTask(book, chapter)
        : _copyTask(
            current,
            status: DownloadTaskStatus.queued,
            clearError: true,
            updatedAt: _clock(),
          );

    _jobs[nextTask.id] = _DownloadJob(book: book, chapter: chapter);
    await _saveTask(nextTask);
    _schedule();
    return nextTask;
  }

  Future<void> pause(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) {
      return;
    }

    _activeTokens[taskId]?.cancel();
    final paused = _copyTask(
      task,
      status: DownloadTaskStatus.paused,
      speedBytesPerSecond: 0,
      updatedAt: _clock(),
    );
    await _saveTask(paused);
    await _persistChapter(paused);
  }

  Future<void> resumeChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) {
    return enqueueChapter(book, chapter);
  }

  Future<void> retryChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    final current = taskForChapter(chapter.id);
    if (current == null) {
      await enqueueChapter(book, chapter);
      return;
    }

    final retry = _copyTask(
      current,
      status: DownloadTaskStatus.queued,
      retryCount: current.retryCount + 1,
      clearError: true,
      updatedAt: _clock(),
    );
    _jobs[retry.id] = _DownloadJob(book: book, chapter: chapter);
    await _saveTask(retry);
    _schedule();
  }

  Future<void> cancel(String taskId) async {
    final task = _tasks[taskId];
    final job = _jobs[taskId];
    if (task == null) {
      return;
    }

    _activeTokens[taskId]?.cancel();
    if (job != null && !_activeFutures.containsKey(taskId)) {
      await _storage.resetPart(job.book, job.chapter);
    }

    final canceled = _copyTask(
      task,
      status: DownloadTaskStatus.canceled,
      progress: 0,
      downloadedBytes: 0,
      speedBytesPerSecond: 0,
      clearError: true,
      updatedAt: _clock(),
    );
    await _saveTask(canceled);
    await _persistChapter(canceled, localPath: null, fileSizeBytes: null);
  }

  Future<void> deleteChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    final task = taskForChapter(chapter.id);
    if (task != null) {
      _activeTokens[task.id]?.cancel();
      _tasks.remove(task.id);
      _jobs.remove(task.id);
      await _persistence.deleteTask(task.id);
    }

    await _storage.deleteChapter(book, chapter);
    await _persistence.updateChapter(
      DownloadChapterUpdate(
        chapterId: chapter.id,
        status: DownloadTaskStatus.canceled,
        progress: 0,
        localPath: null,
        fileSizeBytes: null,
        updatedAt: _clock(),
      ),
    );
    _notify();
  }

  Future<void> deleteBook(AudioPlaybackBook book) async {
    for (final chapter in book.chapters) {
      await deleteChapter(book, chapter);
    }
    await _storage.deleteBook(book);
  }

  Future<void> cancelAndDeleteBook(AudioPlaybackBook book) async {
    final taskIds = _tasks.values
        .where((task) => task.bookVersionId == book.versionId)
        .map((task) => task.id)
        .toList();
    for (final taskId in taskIds) {
      await cancel(taskId);
    }
    for (final taskId in taskIds) {
      await _activeFutures[taskId]?.catchError((_) {});
    }
    await deleteBook(book);
  }

  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) {
    return _storage.offlinePlaybackBook(book);
  }

  Future<void> waitForIdle() async {
    while (_activeFutures.isNotEmpty) {
      final active = _activeFutures.values.toList();
      await Future.wait(active, eagerError: false);
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final token in _activeTokens.values) {
      token.cancel();
    }
    final client = _client;
    if (client is DefaultDownloadClient) {
      client.close();
    }
    super.dispose();
  }

  void _schedule() {
    if (_disposed) {
      return;
    }

    while (_activeTokens.length < _maxConcurrentDownloads) {
      final next = _nextQueuedTask();
      if (next == null) {
        return;
      }

      final job = _jobs[next.id];
      if (job == null) {
        _saveTask(
          _copyTask(
            next,
            status: DownloadTaskStatus.paused,
            errorCode: 'missing_job_context',
            errorMessage: 'Download requires book and chapter context.',
            updatedAt: _clock(),
          ),
        );
        continue;
      }

      final token = DownloadCancellationToken();
      _activeTokens[next.id] = token;
      final running = _copyTask(
        next,
        status: DownloadTaskStatus.running,
        speedBytesPerSecond: 0,
        updatedAt: _clock(),
      );
      unawaited(_saveTask(running));
      final future = _runTask(running.id, job, token).whenComplete(() {
        _activeTokens.remove(running.id);
        _activeFutures.remove(running.id);
        _schedule();
      });
      _activeFutures[running.id] = future;
    }
  }

  Future<void> _restorePersistedBookContexts(List<DownloadTask> tasks) async {
    final booksByKey = <String, Future<AudioPlaybackBook?>>{};
    for (final task in tasks) {
      final key = '${task.sourceId}:${task.bookVersionId}';
      final book = booksByKey.putIfAbsent(
        key,
        () => _storage.readMetadataForIds(task.sourceId, task.bookVersionId),
      );
      final restoredBook = await book;
      final chapter = _chapterForTask(restoredBook, task);
      if (restoredBook != null && chapter != null) {
        _jobs[task.id] = _DownloadJob(book: restoredBook, chapter: chapter);
      }
    }
  }

  AudioPlaybackChapter? _chapterForTask(
    AudioPlaybackBook? book,
    DownloadTask task,
  ) {
    if (book == null) {
      return null;
    }
    for (final chapter in book.chapters) {
      if (chapter.id == task.chapterId) {
        return chapter;
      }
    }
    return null;
  }

  DownloadTask? _nextQueuedTask() {
    final queued =
        _tasks.values
            .where((task) => task.status == DownloadTaskStatus.queued)
            .where((task) => !_activeTokens.containsKey(task.id))
            .toList()
          ..sort((a, b) {
            final priority = b.priority.compareTo(a.priority);
            if (priority != 0) {
              return priority;
            }
            return a.createdAt.compareTo(b.createdAt);
          });

    return queued.isEmpty ? null : queued.first;
  }

  Future<void> _runTask(
    String taskId,
    _DownloadJob job,
    DownloadCancellationToken token,
  ) async {
    final source = job.chapter.mediaSource;
    if (source == null) {
      await _failTask(taskId, 'missing_media_source', 'Missing media source.');
      return;
    }

    final startedAt = _clock();
    try {
      final startByte = await _storage.partialBytesFor(job.book, job.chapter);
      final response = await _client.open(
        source,
        startByte: startByte,
        cancellationToken: token,
      );

      if (!response.shouldAppend && startByte > 0) {
        await _storage.resetPart(job.book, job.chapter);
      }

      final sink = await _storage.openPartSink(
        job.book,
        job.chapter,
        append: response.shouldAppend,
      );

      var downloaded = response.shouldAppend ? startByte : 0;
      final total = response.totalBytes;
      try {
        await for (final chunk in response.bytes) {
          if (token.isCanceled) {
            break;
          }
          sink.add(chunk);
          await sink.flush();
          downloaded += chunk.length;
          await _saveTask(
            _copyTask(
              _tasks[taskId]!,
              status: DownloadTaskStatus.running,
              progress: _progress(downloaded, total),
              downloadedBytes: downloaded,
              totalBytes: total,
              speedBytesPerSecond: _speed(downloaded, startedAt),
              updatedAt: _clock(),
            ),
          );
        }
      } finally {
        await sink.close();
      }

      if (token.isCanceled) {
        if (_tasks[taskId]?.status == DownloadTaskStatus.canceled) {
          await _storage.resetPart(job.book, job.chapter);
        }
        return;
      }

      final finalFile = await _storage.finalizeChapter(
        job.book,
        job.chapter,
        extension: response.fileExtension,
      );
      final finalSize = await finalFile.length();
      final completed = _copyTask(
        _tasks[taskId]!,
        status: DownloadTaskStatus.completed,
        progress: 1,
        downloadedBytes: finalSize,
        totalBytes: total ?? finalSize,
        speedBytesPerSecond: 0,
        clearError: true,
        updatedAt: _clock(),
      );
      await _saveTask(completed);
      await _persistChapter(
        completed,
        localPath: finalFile.path,
        fileSizeBytes: finalSize,
      );
    } on Object catch (error) {
      if (token.isCanceled) {
        return;
      }
      await _failTask(taskId, 'download_failed', _errorMessage(error));
    }
  }

  Future<void> _failTask(
    String taskId,
    String errorCode,
    String errorMessage,
  ) async {
    final task = _tasks[taskId];
    if (task == null) {
      return;
    }

    final failed = _copyTask(
      task,
      status: DownloadTaskStatus.failed,
      speedBytesPerSecond: 0,
      errorCode: errorCode,
      errorMessage: errorMessage,
      updatedAt: _clock(),
    );
    await _saveTask(failed);
    await _persistChapter(failed);
  }

  Future<void> _saveTask(DownloadTask task) async {
    _tasks[task.id] = task;
    await _persistence.saveTask(task);
    _notify();
  }

  Future<void> _persistChapter(
    DownloadTask task, {
    String? localPath,
    int? fileSizeBytes,
  }) {
    final chapterId = task.chapterId;
    if (chapterId == null) {
      return Future.value();
    }

    return _persistence.updateChapter(
      DownloadChapterUpdate(
        chapterId: chapterId,
        status: task.status,
        progress: task.progress,
        localPath: localPath,
        fileSizeBytes: fileSizeBytes,
        updatedAt: task.updatedAt,
      ),
    );
  }

  DownloadTask _newTask(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    DownloadTaskStatus status = DownloadTaskStatus.queued,
    double progress = 0,
    int downloadedBytes = 0,
    int? totalBytes,
    String? errorCode,
    String? errorMessage,
  }) {
    final now = _clock();
    return DownloadTask(
      id: _taskId(book, chapter),
      bookId: book.id,
      bookVersionId: book.versionId,
      chapterId: chapter.id,
      sourceId: book.sourceId,
      type: DownloadTaskType.chapter,
      status: status,
      progress: progress,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      errorCode: errorCode,
      errorMessage: errorMessage,
      createdAt: now,
      updatedAt: now,
    );
  }

  String _taskId(AudioPlaybackBook book, AudioPlaybackChapter chapter) {
    return 'chapter:${book.versionId}:${chapter.id}';
  }

  double _progress(int downloadedBytes, int? totalBytes) {
    if (totalBytes == null || totalBytes <= 0) {
      return 0;
    }
    return (downloadedBytes / totalBytes).clamp(0, 1).toDouble();
  }

  int _speed(int downloadedBytes, DateTime startedAt) {
    final elapsedMs = _clock().difference(startedAt).inMilliseconds;
    if (elapsedMs <= 0) {
      return 0;
    }
    return (downloadedBytes / elapsedMs * Duration.millisecondsPerSecond)
        .round();
  }

  String _errorMessage(Object error) {
    if (error is DownloadClientException) {
      return error.message;
    }
    return 'Download failed.';
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  DownloadTask _copyTask(
    DownloadTask task, {
    DownloadTaskStatus? status,
    int? priority,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    int? speedBytesPerSecond,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
    int? retryCount,
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
      priority: priority ?? task.priority,
      progress: progress ?? task.progress,
      downloadedBytes: downloadedBytes ?? task.downloadedBytes,
      totalBytes: totalBytes ?? task.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? task.speedBytesPerSecond,
      errorCode: clearError ? null : errorCode ?? task.errorCode,
      errorMessage: clearError ? null : errorMessage ?? task.errorMessage,
      retryCount: retryCount ?? task.retryCount,
      createdAt: task.createdAt,
      updatedAt: updatedAt ?? task.updatedAt,
    );
  }
}

class _DownloadJob {
  const _DownloadJob({required this.book, required this.chapter});

  final AudioPlaybackBook book;
  final AudioPlaybackChapter chapter;
}
