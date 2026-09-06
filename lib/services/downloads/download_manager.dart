import 'dart:async';
import 'dart:io';
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
    Future<AudioPlaybackBook> Function(AudioPlaybackBook book)?
    refreshBookForDownloads,
    int maxConcurrentDownloads = 3,
  }) : _client = client,
       _storage = storage,
       _persistence = persistence,
       _clock = clock ?? DateTime.now,
       _refreshBookForDownloads = refreshBookForDownloads,
       _maxConcurrentDownloads = maxConcurrentDownloads.clamp(1, 3);

  final DownloadClient _client;
  final FileDownloadStorage _storage;
  final DownloadPersistenceStore _persistence;
  final DateTime Function() _clock;
  final int _maxConcurrentDownloads;
  final Future<AudioPlaybackBook> Function(AudioPlaybackBook book)?
  _refreshBookForDownloads;

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

  Future<void> cacheBookMetadata(AudioPlaybackBook book) async {
    await _storage.writeMetadata(book);
    attachBookContext(book);
    for (final task in _tasks.values) {
      if (!_taskMatchesBook(task, book)) {
        continue;
      }
      final chapter = _chapterForTask(book, task);
      if (chapter == null) {
        continue;
      }
      _jobs[task.id] = _DownloadJob(book: book, chapter: chapter);
    }
    _notify();
  }

  DownloadTask? taskForChapter(String chapterId) {
    for (final task in _tasks.values) {
      if (task.chapterId == chapterId) {
        return task;
      }
    }
    return null;
  }

  DownloadTask? taskForBookChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) {
    final exactTask = _tasks[_taskId(book, chapter)];
    if (exactTask != null) {
      return exactTask;
    }

    for (final task in _tasks.values) {
      if (task.chapterId == chapter.id && _taskMatchesBook(task, book)) {
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
    final completed = await _storage.completedChapterFiles(book);
    final queued = <DownloadTask>[];
    for (final chapter in book.chapters) {
      queued.add(
        await _enqueueChapter(
          book,
          chapter,
          existingFile: completed[chapter.index],
        ),
      );
    }
    return queued;
  }

  Future<List<DownloadTask>> enqueueMissingChapters(
    AudioPlaybackBook book,
  ) async {
    await _storage.writeMetadata(book);
    final completed = await _storage.completedChapterFiles(book);
    final queued = <DownloadTask>[];
    for (final chapter in book.chapters) {
      if (!completed.containsKey(chapter.index)) {
        queued.add(await _enqueueChapter(book, chapter));
      }
    }
    return queued;
  }

  Future<DownloadTask> enqueueChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    bool writeMetadata = true,
  }) async {
    if (writeMetadata) {
      await _storage.writeMetadata(book);
    }

    final existingFile = await _storage.completedChapterFile(book, chapter);
    return _enqueueChapter(book, chapter, existingFile: existingFile);
  }

  Future<DownloadTask> _enqueueChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    File? existingFile,
  }) async {
    final current = taskForBookChapter(book, chapter);
    if (current != null &&
        (current.status == DownloadTaskStatus.running ||
            current.status == DownloadTaskStatus.queued)) {
      if (current.status == DownloadTaskStatus.queued) {
        _schedule();
      }
      return current;
    }
    if (existingFile != null) {
      final size = await existingFile.length();
      final completed = _newTask(
        book,
        chapter,
        status: DownloadTaskStatus.completed,
        progress: 1,
        downloadedBytes: size,
        totalBytes: size,
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

    final nextTask = current == null
        ? _newTask(book, chapter)
        : _copyTask(
            current,
            status: DownloadTaskStatus.queued,
            clearError: true,
            updatedAt: _clock(),
          );

    _jobs[nextTask.id] = _DownloadJob(
      book: book,
      chapter: chapter,
      refreshMedia: current != null,
    );
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
    final current = taskForBookChapter(book, chapter);
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
    _jobs[retry.id] = _DownloadJob(
      book: book,
      chapter: chapter,
      refreshMedia: true,
    );
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
    final task = taskForBookChapter(book, chapter);
    if (task != null) {
      _activeTokens[task.id]?.cancel();
      _tasks.remove(task.id);
      _jobs.remove(task.id);
      await _activeFutures[task.id]?.catchError((Object _) {});
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
        .where((task) => _taskMatchesBook(task, book))
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
        _jobs[task.id] = _DownloadJob(
          book: restoredBook,
          chapter: chapter,
          refreshMedia: true,
        );
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

  bool _taskMatchesBook(DownloadTask task, AudioPlaybackBook book) {
    if (task.sourceId != book.sourceId) {
      return false;
    }
    return task.bookId == book.id ||
        task.bookVersionId == book.versionId ||
        (book.sourceBookId != null && task.bookVersionId == book.sourceBookId);
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
    _DownloadJob initialJob,
    DownloadCancellationToken token,
  ) async {
    var job = initialJob;
    final startedAt = _clock();
    try {
      final refresh = _refreshBookForDownloads;
      if (job.refreshMedia &&
          refresh != null &&
          job.book.sourceBookId?.isNotEmpty == true) {
        final refreshedBook = await token.waitFor(refresh(job.book));
        if (refreshedBook.sourceId != job.book.sourceId ||
            (refreshedBook.versionId != job.book.versionId &&
                refreshedBook.sourceBookId != job.book.sourceBookId)) {
          throw const DownloadClientException('Refreshed book does not match.');
        }
        final chapter = _refreshedChapter(refreshedBook, job.chapter);
        if (chapter == null) {
          throw const DownloadClientException('Chapter no longer available.');
        }
        await token.waitFor(cacheBookMetadata(refreshedBook));
        job = _DownloadJob(book: refreshedBook, chapter: chapter);
        _jobs[taskId] = job;
      }
      final source = job.chapter.originalMediaSource ?? job.chapter.mediaSource;
      if (source == null) {
        await _failTask(
          taskId,
          'missing_media_source',
          'Missing media source.',
        );
        return;
      }
      final startByte = await _storage.partialBytesFor(job.book, job.chapter);
      final response = await token.waitFor(
        _client.open(source, startByte: startByte, cancellationToken: token),
        onCanceledValue: (lateResponse) {
          final subscription = lateResponse.bytes.listen(
            (_) {},
            onError: (Object _) {},
          );
          unawaited(subscription.cancel().catchError((Object _) {}));
        },
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
      var lastProgressSaveAt = startedAt;
      var lastProgressSaveBytes = downloaded;
      try {
        await for (final chunk in token.bindStream(response.bytes)) {
          if (token.isCanceled) {
            break;
          }
          sink.add(chunk);
          downloaded += chunk.length;
          final now = _clock();
          if (_shouldSaveProgress(
            downloadedBytes: downloaded,
            totalBytes: total,
            lastSavedBytes: lastProgressSaveBytes,
            lastSavedAt: lastProgressSaveAt,
            now: now,
          )) {
            await _saveTask(
              _copyTask(
                _tasks[taskId]!,
                status: DownloadTaskStatus.running,
                progress: _progress(downloaded, total),
                downloadedBytes: downloaded,
                totalBytes: total,
                speedBytesPerSecond: _speed(downloaded, startedAt),
                updatedAt: now,
              ),
            );
            lastProgressSaveAt = now;
            lastProgressSaveBytes = downloaded;
          }
        }
      } finally {
        try {
          await sink.flush();
        } finally {
          await sink.close();
        }
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
    } finally {
      if (token.isCanceled &&
          _tasks[taskId]?.status == DownloadTaskStatus.canceled) {
        await _storage.resetPart(job.book, job.chapter);
      }
    }
  }

  AudioPlaybackChapter? _refreshedChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter previous,
  ) {
    for (final chapter in book.chapters) {
      if (chapter.id == previous.id) {
        return chapter;
      }
    }
    for (final chapter in book.chapters) {
      if (chapter.index == previous.index) {
        return chapter;
      }
    }
    return null;
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

  bool _shouldSaveProgress({
    required int downloadedBytes,
    required int? totalBytes,
    required int lastSavedBytes,
    required DateTime lastSavedAt,
    required DateTime now,
  }) {
    const minBytesBetweenSaves = 1024 * 1024;
    const minDurationBetweenSaves = Duration(seconds: 1);

    final completed =
        totalBytes != null && totalBytes > 0 && downloadedBytes >= totalBytes;
    final enoughBytes =
        downloadedBytes - lastSavedBytes >= minBytesBetweenSaves;
    final enoughTime = now.difference(lastSavedAt) >= minDurationBetweenSaves;
    return completed || enoughBytes || enoughTime;
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
  const _DownloadJob({
    required this.book,
    required this.chapter,
    this.refreshMedia = false,
  });

  final AudioPlaybackBook book;
  final AudioPlaybackChapter chapter;
  final bool refreshMedia;
}
