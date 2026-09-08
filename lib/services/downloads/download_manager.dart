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
    Future<void> Function(
      AudioPlaybackBook book,
      AudioPlaybackChapter? chapter,
    )?
    ensureDownloadAllowed,
    int maxConcurrentDownloads = 3,
  }) : _client = client,
       _storage = storage,
       _persistence = persistence,
       _clock = clock ?? DateTime.now,
       _refreshBookForDownloads = refreshBookForDownloads,
       _ensureDownloadAllowed = ensureDownloadAllowed,
       _maxConcurrentDownloads = maxConcurrentDownloads.clamp(1, 3);

  final DownloadClient _client;
  final FileDownloadStorage _storage;
  final DownloadPersistenceStore _persistence;
  final DateTime Function() _clock;
  final int _maxConcurrentDownloads;
  final Future<void> Function(
    AudioPlaybackBook book,
    AudioPlaybackChapter? chapter,
  )?
  _ensureDownloadAllowed;
  final Future<AudioPlaybackBook> Function(AudioPlaybackBook book)?
  _refreshBookForDownloads;

  final _tasks = <String, DownloadTask>{};
  final _jobs = <String, _DownloadJob>{};
  final _activeTokens = <String, DownloadCancellationToken>{};
  final _activeFutures = <String, Future<void>>{};

  bool _disposed = false;
  bool _shuttingDown = false;
  Future<void>? _shutdownFuture;
  final _pendingMutations = <Future<void>>{};
  final _pendingShutdownCheckpoints = <String>{};
  Future<void>? _loadFuture;
  Future<void> _writes = Future<void>.value();
  final _protectedBooks = <(String, String)>{};

  void _protectBook(String sourceId, String versionId) {
    if (_protectedBooks.add((sourceId, versionId))) {
      _storage.retainDownloadBook(sourceId, versionId);
    }
  }

  void _releaseBook(String sourceId, String versionId) {
    if (_protectedBooks.remove((sourceId, versionId))) {
      _storage.releaseDownloadBook(sourceId, versionId);
    }
  }

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

  Future<void> cacheBookMetadata(AudioPlaybackBook book) =>
      _acceptMutation(() => _cacheBookMetadata(book));

  /// Admits an entire metadata refresh before it starts asynchronous source or
  /// cover work. Its writer remains valid during shutdown only until the
  /// accepted refresh completes, so no new metadata can escape the drain.
  Future<T> runMetadataOperation<T>(
    Future<T> Function(Future<void> Function(AudioPlaybackBook) writeMetadata)
    operation,
  ) => _acceptMutation(() async {
    var active = true;
    try {
      return await operation((book) {
        if (!active) {
          return Future.error(StateError('Metadata operation has completed.'));
        }
        return _trackMutation(() => _cacheBookMetadata(book));
      });
    } finally {
      active = false;
    }
  });

  Future<void> _cacheBookMetadata(AudioPlaybackBook book) async {
    await _storage.writeMetadata(book);
    attachBookContext(book);
    for (final task in _tasks.values) {
      if (!taskMatchesBook(task, book)) {
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
    if (exactTask != null && taskMatchesBook(exactTask, book)) {
      return exactTask;
    }

    for (final task in _tasks.values) {
      if (task.chapterId == chapter.id && taskMatchesBook(task, book)) {
        return task;
      }
    }
    return null;
  }

  Future<void> loadPersistedTasks({bool recoverInterrupted = true}) {
    final pending = _loadFuture;
    if (pending != null) {
      return pending;
    }
    final loading = _loadPersistedTasks(recoverInterrupted: recoverInterrupted);
    _loadFuture = loading;
    loading.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(_loadFuture, loading)) {
          _loadFuture = null;
        }
      },
    );
    return loading;
  }

  Future<void> _loadPersistedTasks({required bool recoverInterrupted}) async {
    final persisted = await _persistence.loadTasks(
      recoverInterrupted: recoverInterrupted,
    );
    for (final task in persisted) {
      _protectBook(task.sourceId, task.bookVersionId);
    }
    _tasks
      ..clear()
      ..addEntries(persisted.map((task) => MapEntry(task.id, task)));
    _jobs.clear();
    await _restorePersistedBookContexts(persisted);
    _notify();
  }

  Future<List<DownloadTask>> enqueueBook(AudioPlaybackBook book) =>
      _acceptMutation(() async {
        await loadPersistedTasks();
        _protectBook(book.sourceId, book.versionId);
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
      });

  Future<List<DownloadTask>> enqueueMissingChapters(AudioPlaybackBook book) =>
      _acceptMutation(() async {
        await loadPersistedTasks();
        _protectBook(book.sourceId, book.versionId);
        await _storage.writeMetadata(book);
        final completed = await _storage.completedChapterFiles(book);
        final queued = <DownloadTask>[];
        for (final chapter in book.chapters) {
          if (!completed.containsKey(chapter.index)) {
            queued.add(await _enqueueChapter(book, chapter));
          }
        }
        return queued;
      });

  Future<DownloadTask> enqueueChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    bool writeMetadata = true,
  }) => _acceptMutation(
    () => _prepareChapterEnqueue(book, chapter, writeMetadata: writeMetadata),
  );

  Future<DownloadTask> _prepareChapterEnqueue(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    bool writeMetadata = true,
  }) async {
    await loadPersistedTasks();
    _protectBook(book.sourceId, book.versionId);
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
    if (current != null && current.status == DownloadTaskStatus.running) {
      return current;
    }
    if (existingFile != null) {
      final size = await existingFile.length();
      final completed = current == null
          ? _newTask(
              book,
              chapter,
              status: DownloadTaskStatus.completed,
              progress: 1,
              downloadedBytes: size,
              totalBytes: size,
            )
          : _copyTask(
              current,
              status: DownloadTaskStatus.completed,
              progress: 1,
              downloadedBytes: size,
              totalBytes: size,
              speedBytesPerSecond: 0,
              clearError: true,
              updatedAt: _clock(),
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

    final denied = await _accessDeniedTask(book, chapter, current);
    if (denied != null) {
      return denied;
    }
    if (current != null && current.status == DownloadTaskStatus.queued) {
      _schedule();
      return current;
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

  Future<void> pause(String taskId) => _acceptMutation(() => _pause(taskId));

  Future<void> _pause(String taskId) async {
    await loadPersistedTasks();
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
  ) => _acceptMutation(() async {
    await loadPersistedTasks();
    final current = taskForBookChapter(book, chapter);
    if (current == null) {
      await _prepareChapterEnqueue(book, chapter);
      return;
    }

    final completed = await _storage.completedChapterFile(book, chapter);
    if (completed != null) {
      await _enqueueChapter(book, chapter, existingFile: completed);
      return;
    }
    if (await _accessDeniedTask(book, chapter, current, refreshing: true) !=
        null) {
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
  });

  Future<void> cancel(String taskId) => _acceptMutation(() => _cancel(taskId));

  Future<void> _cancel(String taskId) async {
    await loadPersistedTasks();
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
  ) => _acceptMutation(() => _deleteChapter(book, chapter));

  Future<void> _deleteChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    await loadPersistedTasks();
    final task = taskForBookChapter(book, chapter);
    if (task != null) {
      _activeTokens[task.id]?.cancel();
      _tasks.remove(task.id);
      _jobs.remove(task.id);
      await _activeFutures[task.id]?.catchError((Object _) {});
      await _write(() => _persistence.deleteTask(task.id));
    }

    await _storage.deleteChapter(book, chapter);
    await _write(
      () => _persistence.updateChapter(
        DownloadChapterUpdate(
          chapterId: chapter.id,
          status: DownloadTaskStatus.canceled,
          progress: 0,
          localPath: null,
          fileSizeBytes: null,
          updatedAt: _clock(),
        ),
      ),
    );
    if (!_tasks.values.any((task) => taskMatchesBook(task, book))) {
      _releaseBook(book.sourceId, book.versionId);
    }
    _notify();
  }

  Future<void> deleteBook(AudioPlaybackBook book) =>
      _acceptMutation(() => _deleteBook(book));

  Future<void> _deleteBook(AudioPlaybackBook book) async {
    await loadPersistedTasks();
    // The current source chapter list may have shrunk. Remove every persisted
    // task of this version, including chapters no longer present in metadata.
    final removed = _tasks.values
        .where((task) => taskMatchesBook(task, book))
        .toList();
    for (final task in removed) {
      _activeTokens[task.id]?.cancel();
      _tasks.remove(task.id);
      _jobs.remove(task.id);
    }
    for (final task in removed) {
      await _activeFutures[task.id]?.catchError((Object _) {});
      await _write(() => _persistence.deleteTask(task.id));
      final chapterId = task.chapterId;
      if (chapterId != null) {
        await _write(
          () => _persistence.updateChapter(
            DownloadChapterUpdate(
              chapterId: chapterId,
              status: DownloadTaskStatus.canceled,
              progress: 0,
              updatedAt: _clock(),
            ),
          ),
        );
      }
    }
    for (final chapter in book.chapters) {
      await _deleteChapter(book, chapter);
    }
    await _storage.deleteBook(book);
    _releaseBook(book.sourceId, book.versionId);
    _notify();
  }

  Future<void> cancelAndDeleteBook(AudioPlaybackBook book) =>
      _acceptMutation(() => _cancelAndDeleteBook(book));

  Future<void> _cancelAndDeleteBook(AudioPlaybackBook book) async {
    await loadPersistedTasks();
    final taskIds = _tasks.values
        .where((task) => taskMatchesBook(task, book))
        .map((task) => task.id)
        .toList();
    for (final taskId in taskIds) {
      await _cancel(taskId);
    }
    for (final taskId in taskIds) {
      await _activeFutures[taskId]?.catchError((_) {});
    }
    await _deleteBook(book);
  }

  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) {
    return _storage.offlinePlaybackBook(book);
  }

  Future<T> _acceptMutation<T>(Future<T> Function() operation) {
    if (_disposed || _shuttingDown) {
      return Future.error(StateError('Download manager is shutting down.'));
    }
    return _trackMutation(operation);
  }

  Future<T> _trackMutation<T>(Future<T> Function() operation) {
    // Register before invoking even a synchronous callback: it can re-enter
    // shutdown, which must already see this accepted operation in its drain.
    final pending = Completer<void>();
    final tracked = pending.future;
    _pendingMutations.add(tracked);
    final result = Future<T>.sync(operation);
    void complete() {
      _pendingMutations.remove(tracked);
      pending.complete();
    }

    result.then<void>(
      (_) => complete(),
      onError: (Object _, StackTrace _) => complete(),
    );
    return result;
  }

  /// Quiesces the queue without deleting resumable files. Call before closing
  /// the database; unlike dispose, this awaits accepted mutations and final state.
  /// This instance does not accept further downloads after shutdown starts.
  Future<void> shutdown() {
    final existing = _shutdownFuture;
    if (existing != null) return existing;
    _shuttingDown = true;
    final result = _shutdown();
    _shutdownFuture = result;
    result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {
        if (identical(_shutdownFuture, result)) _shutdownFuture = null;
      },
    );
    return result;
  }

  Future<void> _shutdown() async {
    for (final token in _activeTokens.values.toList()) {
      token.cancel();
    }
    await _loadFuture;
    while (_pendingMutations.isNotEmpty) {
      await Future.wait(_pendingMutations.toList());
    }
    await waitForIdle();
    for (final task in _tasks.values.toList()) {
      if (task.status != DownloadTaskStatus.running &&
          task.status != DownloadTaskStatus.queued &&
          !_pendingShutdownCheckpoints.contains(task.id)) {
        continue;
      }
      _pendingShutdownCheckpoints.add(task.id);
      final paused = _copyTask(
        task,
        status: DownloadTaskStatus.paused,
        speedBytesPerSecond: 0,
        updatedAt: _clock(),
      );
      await _saveTask(paused);
      await _persistChapter(paused);
      _pendingShutdownCheckpoints.remove(task.id);
    }
    await _writes;
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
    for (final identity in _protectedBooks.toList()) {
      _releaseBook(identity.$1, identity.$2);
    }
    final client = _client;
    if (client is DefaultDownloadClient) {
      client.close();
    }
    super.dispose();
  }

  void _schedule() {
    if (_disposed || _shuttingDown) {
      return;
    }

    while (_activeTokens.length < _maxConcurrentDownloads) {
      final next = _nextQueuedTask();
      if (next == null) {
        return;
      }

      final job = _jobs[next.id];
      if (job == null) {
        unawaited(
          _saveTask(
            _copyTask(
              next,
              status: DownloadTaskStatus.paused,
              errorCode: 'missing_job_context',
              errorMessage: 'Download requires book and chapter context.',
              updatedAt: _clock(),
            ),
          ).catchError((Object _) {}),
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
      final future = _startTask(running, job, token).whenComplete(() {
        _activeTokens.remove(running.id);
        _activeFutures.remove(running.id);
        _schedule();
      });
      _activeFutures[running.id] = future;
    }
  }

  Future<void> _startTask(
    DownloadTask running,
    _DownloadJob job,
    DownloadCancellationToken token,
  ) async {
    try {
      await _saveTask(running);
      if (!token.isCanceled) {
        await _runTask(running.id, job, token);
      }
    } catch (_) {
      // Storage failures must not escape from an unawaited scheduler future.
      // Keep a truthful failed task in memory; an explicit retry may persist it.
      final task = _tasks[running.id];
      if (!token.isCanceled && task != null) {
        _tasks[running.id] = _copyTask(
          task,
          status: DownloadTaskStatus.failed,
          speedBytesPerSecond: 0,
          errorCode: 'persistence_failed',
          errorMessage: 'Could not save download state.',
          updatedAt: _clock(),
        );
        _notify();
      }
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

  bool taskMatchesBook(DownloadTask task, AudioPlaybackBook book) {
    if (task.sourceId != book.sourceId) {
      return false;
    }
    return task.bookVersionId == book.versionId ||
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

  bool _requiresRemoteMedia(AudioPlaybackChapter chapter) {
    final source = chapter.originalMediaSource ?? chapter.mediaSource;
    return source == null || source.type == AudioMediaSourceType.url;
  }

  Future<DownloadTask?> _accessDeniedTask(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
    DownloadTask? current, {
    bool refreshing = false,
  }) async {
    try {
      await _checkDownloadAccess(book, chapter, refreshing: refreshing);
      return null;
    } on DownloadClientException catch (error) {
      if (error.code != 'source_download_disabled') {
        rethrow;
      }
      final failed = _copyTask(
        current ?? _newTask(book, chapter),
        status: DownloadTaskStatus.failed,
        speedBytesPerSecond: 0,
        errorCode: error.code,
        errorMessage: error.message,
        updatedAt: _clock(),
      );
      _jobs[failed.id] = _DownloadJob(
        book: book,
        chapter: chapter,
        refreshMedia: true,
      );
      await _saveTask(failed);
      await _persistChapter(failed);
      return failed;
    }
  }

  Future<void> _checkDownloadAccess(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    bool refreshing = false,
  }) async {
    final guard = _ensureDownloadAllowed;
    if (guard == null || !_requiresRemoteMedia(chapter)) {
      return;
    }
    final source = chapter.originalMediaSource ?? chapter.mediaSource;
    // Null is the explicit pre-refresh remote boundary: refreshing an expired
    // URL must not contact a source after its download permission was disabled.
    await guard(book, refreshing || source == null ? null : chapter);
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
          _requiresRemoteMedia(job.chapter) &&
          refresh != null &&
          job.book.sourceBookId?.isNotEmpty == true) {
        await _checkDownloadAccess(job.book, job.chapter, refreshing: true);
        if (token.isCanceled) {
          return;
        }
        final refreshedBook = await token.waitFor(refresh(job.book));
        final legacyVersion =
            job.book.versionId == job.book.sourceBookId &&
            refreshedBook.sourceBookId == job.book.sourceBookId;
        if (refreshedBook.sourceId != job.book.sourceId ||
            (refreshedBook.versionId != job.book.versionId && !legacyVersion)) {
          throw const DownloadClientException('Refreshed book does not match.');
        }
        // Legacy raw ids must keep their persisted directory and task identity
        // while taking refreshed chapter media from the qualified source book.
        final downloadBook =
            legacyVersion && refreshedBook.versionId != job.book.versionId
            ? job.book.copyWith(chapters: refreshedBook.chapters)
            : refreshedBook;
        final chapter = _refreshedChapter(downloadBook, job.chapter);
        if (chapter == null) {
          throw const DownloadClientException('Chapter no longer available.');
        }
        await token.waitFor(cacheBookMetadata(downloadBook));
        job = _DownloadJob(book: downloadBook, chapter: chapter);
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
      await _checkDownloadAccess(job.book, job.chapter);
      if (token.isCanceled) {
        return;
      }
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
      // UI and disk checkpoints have independent time caps. Byte thresholds
      // cannot bound work on a fast connection (or a frozen test clock).
      var lastProgressSaveAt = startedAt;
      var lastProgressNotifyAt = lastProgressSaveAt;
      try {
        await for (final chunk in token.bindStream(response.bytes)) {
          if (token.isCanceled) {
            break;
          }
          sink.add(chunk);
          downloaded += chunk.length;
          final now = _clock();
          final current = _tasks[taskId];
          if (current == null || current.status != DownloadTaskStatus.running) {
            break;
          }
          final progress = _copyTask(
            current,
            progress: _progress(downloaded, total),
            downloadedBytes: downloaded,
            totalBytes: total,
            speedBytesPerSecond: _speed(
              downloaded - (response.shouldAppend ? startByte : 0),
              startedAt,
            ),
            updatedAt: now,
          );
          // Keep the latest byte count even between notifications/checkpoints:
          // pause, failures and shutdown must flush the actual current state.
          _tasks[taskId] = progress;
          if (now.difference(lastProgressNotifyAt) >=
              const Duration(milliseconds: 250)) {
            lastProgressNotifyAt = now;
            _notify();
          }
          if (now.difference(lastProgressSaveAt) >=
              const Duration(seconds: 1)) {
            lastProgressSaveAt = now;
            await _write(() => _persistence.saveTask(progress));
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

      final receivedBytes =
          downloaded - (response.shouldAppend ? startByte : 0);
      if ((response.contentLength != null &&
              receivedBytes != response.contentLength) ||
          (total != null && downloaded != total)) {
        throw const DownloadClientException('Incomplete media download.');
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
      await _failTask(
        taskId,
        error is DownloadClientException
            ? error.code ?? 'download_failed'
            : 'download_failed',
        _errorMessage(error),
      );
    } finally {
      if (token.isCanceled &&
          _tasks[taskId]?.status == DownloadTaskStatus.canceled) {
        await _storage.resetPart(job.book, job.chapter);
      } else if (token.isCanceled &&
          _disposed &&
          _tasks[taskId]?.status == DownloadTaskStatus.running) {
        // dispose cannot await; waitForIdle still drains this terminal write
        // after the canceled stream has flushed its resumable part file.
        final paused = _copyTask(
          _tasks[taskId]!,
          status: DownloadTaskStatus.paused,
          speedBytesPerSecond: 0,
          updatedAt: _clock(),
        );
        await _saveTask(paused);
        await _persistChapter(paused);
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

  Future<void> _write(Future<void> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _saveTask(DownloadTask task) async {
    _tasks[task.id] = task;
    await _write(() => _persistence.saveTask(task));
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

    if (!identical(_tasks[task.id], task)) {
      return Future.value();
    }
    return _write(
      () => _persistence.updateChapter(
        DownloadChapterUpdate(
          chapterId: chapterId,
          status: task.status,
          progress: task.progress,
          localPath: localPath,
          fileSizeBytes: fileSizeBytes,
          updatedAt: task.updatedAt,
        ),
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
    return 'chapter:${book.sourceId}:${book.versionId}:${chapter.id}';
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
  const _DownloadJob({
    required this.book,
    required this.chapter,
    this.refreshMedia = false,
  });

  final AudioPlaybackBook book;
  final AudioPlaybackChapter chapter;
  final bool refreshMedia;
}
