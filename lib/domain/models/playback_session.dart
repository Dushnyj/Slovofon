enum SleepTimerMode { off, stopAfterDuration, stopAtChapterEnd, unknown }

class PlaybackSession {
  const PlaybackSession({
    required this.id,
    this.activeBookId,
    this.activeBookVersionId,
    this.activeSourceId,
    this.activeChapterId,
    this.positionMs = 0,
    this.speed = 1,
    this.volume = 1,
    this.isPlaying = false,
    this.playerPageIndex = 0,
    this.sleepTimerRemainingMs,
    this.sleepTimerMode = SleepTimerMode.off,
    required this.updatedAt,
  });

  final String id;
  final String? activeBookId;
  final String? activeBookVersionId;
  final String? activeSourceId;
  final String? activeChapterId;
  final int positionMs;
  final double speed;
  final double volume;
  final bool isPlaying;
  final int playerPageIndex;
  final int? sleepTimerRemainingMs;
  final SleepTimerMode sleepTimerMode;
  final DateTime updatedAt;
}
