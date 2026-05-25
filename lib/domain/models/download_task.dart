enum DownloadTaskType { book, chapter, cover, metadata }

enum DownloadTaskStatus { queued, running, paused, completed, failed, canceled }

class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.bookId,
    required this.bookVersionId,
    this.chapterId,
    required this.sourceId,
    required this.type,
    this.status = DownloadTaskStatus.queued,
    this.priority = 0,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.speedBytesPerSecond = 0,
    this.errorCode,
    this.errorMessage,
    this.retryCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final String bookVersionId;
  final String? chapterId;
  final String sourceId;
  final DownloadTaskType type;
  final DownloadTaskStatus status;
  final int priority;
  final double progress;
  final int downloadedBytes;
  final int? totalBytes;
  final int speedBytesPerSecond;
  final String? errorCode;
  final String? errorMessage;
  final int retryCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}
