import '../../services/audio/audio_persistence.dart';
import '../../services/audio/audio_state.dart';

class PlaybackResumePoint {
  const PlaybackResumePoint({
    required this.chapterIndex,
    required this.position,
  });

  final int chapterIndex;
  final Duration position;
}

PlaybackResumePoint playbackResumePointForBook(
  AudioPlaybackBook book,
  List<PlaybackProgressSnapshot> snapshots, {
  String? fallbackVersionId,
}) {
  final snapshot = _snapshotForBook(
    book,
    snapshots,
    fallbackVersionId: fallbackVersionId,
  );
  if (snapshot == null || snapshot.isFinished || book.chapters.isEmpty) {
    return const PlaybackResumePoint(chapterIndex: 0, position: Duration.zero);
  }

  final chapterId = snapshot.currentChapterId;
  if (chapterId != null && chapterId.isNotEmpty) {
    final chapterIndex = book.chapters.indexWhere(
      (chapter) => chapter.id == chapterId,
    );
    if (chapterIndex >= 0) {
      final chapter = book.chapters[chapterIndex];
      return PlaybackResumePoint(
        chapterIndex: chapterIndex,
        position: _clampPosition(
          Duration(milliseconds: snapshot.currentPositionMs),
          chapter.duration,
        ),
      );
    }
  }

  return _resumeFromGlobalPosition(
    book,
    Duration(milliseconds: snapshot.listenedDurationMs),
  );
}

PlaybackProgressSnapshot? playbackProgressForBook(
  AudioPlaybackBook book,
  List<PlaybackProgressSnapshot> snapshots, {
  String? fallbackVersionId,
}) {
  return _snapshotForBook(
    book,
    snapshots,
    fallbackVersionId: fallbackVersionId,
  );
}

PlaybackProgressSnapshot? _snapshotForBook(
  AudioPlaybackBook book,
  List<PlaybackProgressSnapshot> snapshots, {
  String? fallbackVersionId,
}) {
  for (final snapshot in snapshots) {
    if (snapshot.bookVersionId == book.versionId ||
        (fallbackVersionId != null &&
            snapshot.bookVersionId == fallbackVersionId)) {
      return snapshot;
    }
  }
  for (final snapshot in snapshots) {
    if (snapshot.bookId == book.id) {
      return snapshot;
    }
  }
  return null;
}

PlaybackResumePoint _resumeFromGlobalPosition(
  AudioPlaybackBook book,
  Duration globalPosition,
) {
  var remaining = globalPosition;
  for (var index = 0; index < book.chapters.length; index++) {
    final chapter = book.chapters[index];
    if (remaining <= chapter.duration || index == book.chapters.length - 1) {
      return PlaybackResumePoint(
        chapterIndex: index,
        position: _clampPosition(remaining, chapter.duration),
      );
    }
    remaining -= chapter.duration;
  }
  return const PlaybackResumePoint(chapterIndex: 0, position: Duration.zero);
}

Duration _clampPosition(Duration position, Duration duration) {
  if (position.isNegative) {
    return Duration.zero;
  }
  if (duration <= Duration.zero || position <= duration) {
    return position;
  }
  return duration;
}
