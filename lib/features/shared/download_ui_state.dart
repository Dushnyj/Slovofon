import '../../domain/models/download_task.dart';
import '../../services/audio/audio_state.dart';
import '../../services/downloads/download_manager.dart';
import '../../ui/components/download_action_button.dart';

Iterable<DownloadTask> activeTasksForBook(
  DownloadManager manager,
  AudioPlaybackBook book,
) {
  return manager.tasks.where(
    (task) =>
        task.status != DownloadTaskStatus.canceled &&
        _taskBelongsToBook(manager, task, book),
  );
}

BookCardDownloadState downloadStateForBook(
  DownloadManager manager,
  AudioPlaybackBook book,
) {
  final tasks = activeTasksForBook(manager, book).toList();
  if (tasks.isEmpty) {
    return BookCardDownloadState.none;
  }

  if (_allBookChaptersCompleted(tasks, book)) {
    return BookCardDownloadState.downloaded;
  }
  if (tasks.any((task) => task.status == DownloadTaskStatus.running)) {
    return BookCardDownloadState.downloading;
  }
  if (tasks.any((task) => task.status == DownloadTaskStatus.failed)) {
    return BookCardDownloadState.failed;
  }
  if (tasks.any((task) => task.status == DownloadTaskStatus.paused)) {
    return BookCardDownloadState.paused;
  }
  if (tasks.any((task) => task.status == DownloadTaskStatus.queued)) {
    return BookCardDownloadState.queued;
  }
  if (tasks.any((task) => task.status == DownloadTaskStatus.completed)) {
    return BookCardDownloadState.paused;
  }

  return BookCardDownloadState.none;
}

BookCardDownloadState downloadStateForChapter(
  DownloadManager manager,
  AudioPlaybackChapter chapter,
) {
  return downloadStateForTask(manager.taskForChapter(chapter.id));
}

BookCardDownloadState downloadStateForTask(DownloadTask? task) {
  if (task == null || task.status == DownloadTaskStatus.canceled) {
    return BookCardDownloadState.none;
  }

  return switch (task.status) {
    DownloadTaskStatus.completed => BookCardDownloadState.downloaded,
    DownloadTaskStatus.running => BookCardDownloadState.downloading,
    DownloadTaskStatus.queued => BookCardDownloadState.queued,
    DownloadTaskStatus.paused => BookCardDownloadState.paused,
    DownloadTaskStatus.failed => BookCardDownloadState.failed,
    DownloadTaskStatus.canceled => BookCardDownloadState.none,
  };
}

double downloadProgressForBook(
  DownloadManager manager,
  AudioPlaybackBook book,
) {
  final tasks = activeTasksForBook(manager, book).toList();
  if (tasks.isEmpty) {
    return 0;
  }

  final taskProgressByChapter = {
    for (final task in tasks)
      if (task.chapterId != null) task.chapterId!: task.progress,
  };
  final summed = book.chapters.fold<double>(0, (sum, chapter) {
    return sum + (taskProgressByChapter[chapter.id] ?? 0);
  });
  return (summed / book.chapters.length).clamp(0, 1).toDouble();
}

double downloadProgressForChapter(
  DownloadManager manager,
  AudioPlaybackChapter chapter,
) {
  return manager.taskForChapter(chapter.id)?.progress ?? 0;
}

bool isChapterDownloaded(
  DownloadManager manager,
  AudioPlaybackChapter chapter,
) {
  return downloadStateForChapter(manager, chapter) ==
      BookCardDownloadState.downloaded;
}

AudioPlaybackChapter? chapterForTask(
  AudioPlaybackBook book,
  DownloadTask task,
) {
  for (final chapter in book.chapters) {
    if (chapter.id == task.chapterId) {
      return chapter;
    }
  }
  return null;
}

Future<void> toggleBookDownload(
  DownloadManager manager,
  AudioPlaybackBook book,
) async {
  final state = downloadStateForBook(manager, book);
  final tasks = activeTasksForBook(manager, book).toList();

  switch (state) {
    case BookCardDownloadState.downloaded:
      await manager.deleteBook(book);
    case BookCardDownloadState.downloading:
    case BookCardDownloadState.queued:
      for (final task in tasks) {
        if (task.status == DownloadTaskStatus.running ||
            task.status == DownloadTaskStatus.queued) {
          await manager.pause(task.id);
        }
      }
    case BookCardDownloadState.paused:
      await _resumeBookTasks(manager, book, tasks);
    case BookCardDownloadState.failed:
      await _retryBookTasks(manager, book, tasks);
    case BookCardDownloadState.none:
      await manager.enqueueMissingChapters(book);
  }
}

Future<void> runBookCardDownloadAction(
  DownloadManager manager,
  AudioPlaybackBook book,
) async {
  final state = downloadStateForBook(manager, book);
  final tasks = activeTasksForBook(manager, book).toList();

  switch (state) {
    case BookCardDownloadState.downloaded:
    case BookCardDownloadState.downloading:
    case BookCardDownloadState.queued:
      await manager.cancelAndDeleteBook(book);
    case BookCardDownloadState.paused:
      await _resumeBookTasks(manager, book, tasks);
    case BookCardDownloadState.failed:
      await _retryBookTasks(manager, book, tasks);
    case BookCardDownloadState.none:
      await manager.enqueueMissingChapters(book);
  }
}

Future<void> toggleChapterDownload(
  DownloadManager manager,
  AudioPlaybackBook book,
  AudioPlaybackChapter chapter,
) async {
  final task = manager.taskForChapter(chapter.id);
  final state = downloadStateForTask(task);

  switch (state) {
    case BookCardDownloadState.downloaded:
      await manager.deleteChapter(book, chapter);
    case BookCardDownloadState.downloading:
    case BookCardDownloadState.queued:
      if (task != null) {
        await manager.pause(task.id);
      }
    case BookCardDownloadState.paused:
      await manager.resumeChapter(book, chapter);
    case BookCardDownloadState.failed:
      await manager.retryChapter(book, chapter);
    case BookCardDownloadState.none:
      await manager.enqueueChapter(book, chapter);
  }
}

Future<void> runChapterCardDownloadAction(
  DownloadManager manager,
  AudioPlaybackBook book,
  AudioPlaybackChapter chapter,
) async {
  final task = manager.taskForChapter(chapter.id);
  final state = downloadStateForTask(task);

  switch (state) {
    case BookCardDownloadState.downloaded:
      await manager.deleteChapter(book, chapter);
    case BookCardDownloadState.downloading:
    case BookCardDownloadState.queued:
      if (task != null) {
        await manager.cancel(task.id);
      }
    case BookCardDownloadState.paused:
      await manager.resumeChapter(book, chapter);
    case BookCardDownloadState.failed:
      await manager.retryChapter(book, chapter);
    case BookCardDownloadState.none:
      await manager.enqueueChapter(book, chapter);
  }
}

Future<void> _resumeBookTasks(
  DownloadManager manager,
  AudioPlaybackBook book,
  List<DownloadTask> tasks,
) async {
  if (tasks.isEmpty) {
    await manager.enqueueMissingChapters(book);
    return;
  }

  for (final task in tasks) {
    final chapter = chapterForTask(book, task);
    if (chapter == null || task.status == DownloadTaskStatus.completed) {
      continue;
    }
    await manager.resumeChapter(book, chapter);
  }
}

Future<void> _retryBookTasks(
  DownloadManager manager,
  AudioPlaybackBook book,
  List<DownloadTask> tasks,
) async {
  var retried = false;
  for (final task in tasks) {
    if (task.status != DownloadTaskStatus.failed) {
      continue;
    }
    final chapter = chapterForTask(book, task);
    if (chapter == null) {
      continue;
    }
    retried = true;
    await manager.retryChapter(book, chapter);
  }

  if (!retried) {
    await manager.enqueueMissingChapters(book);
  }
}

bool _allBookChaptersCompleted(
  List<DownloadTask> tasks,
  AudioPlaybackBook book,
) {
  final completedChapterIds = {
    for (final task in tasks)
      if (task.status == DownloadTaskStatus.completed && task.chapterId != null)
        task.chapterId!,
  };
  return book.chapters.every(
    (chapter) => completedChapterIds.contains(chapter.id),
  );
}

bool _taskBelongsToBook(
  DownloadManager manager,
  DownloadTask task,
  AudioPlaybackBook book,
) {
  if (task.bookVersionId == book.versionId || task.bookId == book.id) {
    return true;
  }

  final sourceBookId = book.sourceBookId;
  if (sourceBookId != null &&
      (task.bookVersionId == sourceBookId ||
          task.bookVersionId == '${book.sourceId}-$sourceBookId' ||
          task.bookId == sourceBookId ||
          task.bookId == '${book.sourceId}-book-$sourceBookId')) {
    return true;
  }

  final taskBook = manager.bookForTask(task.id);
  if (taskBook == null || taskBook.sourceId != book.sourceId) {
    return false;
  }

  return taskBook.versionId == book.versionId ||
      taskBook.id == book.id ||
      (taskBook.sourceBookId != null &&
          taskBook.sourceBookId == book.sourceBookId);
}
