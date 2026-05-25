enum ChapterDownloadStatus {
  none,
  queued,
  running,
  paused,
  completed,
  failed,
  canceled,
}

class Chapter {
  const Chapter({
    required this.id,
    required this.bookVersionId,
    required this.sourceId,
    this.sourceBookId,
    this.sourceChapterId,
    required this.index,
    required this.title,
    required this.normalizedTitle,
    this.durationMs,
    this.streamRef,
    this.cachedStreamUrl,
    this.cachedStreamUrlUpdatedAt,
    this.cachedStreamUrlExpiresAt,
    this.audioFormat,
    this.mimeType,
    this.rawSourceDataJson,
    this.localPath,
    this.fileSizeBytes,
    this.downloadStatus = ChapterDownloadStatus.none,
    this.downloadProgress = 0,
    this.playbackPositionMs = 0,
    this.isFinished = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookVersionId;
  final String sourceId;
  final String? sourceBookId;
  final String? sourceChapterId;
  final int index;
  final String title;
  final String normalizedTitle;
  final int? durationMs;
  final String? streamRef;
  final String? cachedStreamUrl;
  final DateTime? cachedStreamUrlUpdatedAt;
  final DateTime? cachedStreamUrlExpiresAt;
  final String? audioFormat;
  final String? mimeType;
  final String? rawSourceDataJson;
  final String? localPath;
  final int? fileSizeBytes;
  final ChapterDownloadStatus downloadStatus;
  final double downloadProgress;
  final int playbackPositionMs;
  final bool isFinished;
  final DateTime createdAt;
  final DateTime updatedAt;
}
