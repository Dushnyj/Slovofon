import '../../services/audio/audio_state.dart';
import 'stage3_mock_data.dart';

AudioPlaybackBook mockAudioPlaybackBook(MockBook book) {
  return AudioPlaybackBook(
    id: book.id,
    versionId: '${book.id}-${book.sourceId}',
    sourceId: book.sourceId,
    title: book.title,
    author: book.author,
    narrator: book.narrator,
    sourceName: book.sourceName,
    chapters: [
      for (final chapter in book.chapters)
        AudioPlaybackChapter(
          id: mockAudioChapterId(book, chapter),
          index: chapter.index,
          title: chapter.title,
          duration: _parseDurationLabel(chapter.durationLabel),
          isDownloaded: chapter.isDownloaded,
          mediaSource: AudioMediaSource.asset(
            'assets/audio/stage4_mock_chapter.wav',
          ),
        ),
    ],
  );
}

String mockAudioChapterId(MockBook book, MockChapter chapter) {
  return '${book.id}-chapter-${chapter.index}';
}

int mockCurrentChapterIndex(MockBook book) {
  final index = book.chapters.indexWhere((chapter) => chapter.isCurrent);
  return index < 0 ? 0 : index;
}

Duration mockCurrentChapterPosition(MockBook book) {
  final currentIndex = mockCurrentChapterIndex(book);
  final currentChapter = book.chapters[currentIndex];
  final duration = _parseDurationLabel(currentChapter.durationLabel);

  return Duration(
    milliseconds: (duration.inMilliseconds * currentChapter.progress).round(),
  );
}

Duration _parseDurationLabel(String label) {
  final hoursMatch = RegExp(r'(\d+)\s*ч').firstMatch(label);
  final minutesMatch = RegExp(r'(\d+)\s*мин').firstMatch(label);

  final hours = hoursMatch == null ? 0 : int.parse(hoursMatch.group(1)!);
  final minutes = minutesMatch == null ? 0 : int.parse(minutesMatch.group(1)!);

  return Duration(hours: hours, minutes: minutes);
}
