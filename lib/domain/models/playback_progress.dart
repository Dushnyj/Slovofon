class PlaybackProgress {
  const PlaybackProgress({
    required this.bookId,
    required this.bookVersionId,
    this.currentChapterId,
    this.currentPositionMs = 0,
    this.maxReachedGlobalPositionMs = 0,
    this.totalDurationMs = 0,
    this.listenedDurationMs = 0,
    this.percent = 0,
    this.isFinished = false,
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

  double get clampedPercent => percent.clamp(0, 100).toDouble();
}
