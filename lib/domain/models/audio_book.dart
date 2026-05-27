enum BookAccess { free, paid, subscription, unknown }

class AudioBook {
  const AudioBook({
    required this.id,
    required this.title,
    required this.author,
    required this.narrator,
    required this.sourceId,
    required this.sourceName,
    required this.durationLabel,
    required this.chapterCount,
    required this.progress,
    required this.access,
    this.sourceBookId,
    this.coverUrl,
    this.description,
    this.year,
  });

  final String id;
  final String title;
  final String author;
  final String narrator;
  final String sourceId;
  final String sourceName;
  final String durationLabel;
  final int chapterCount;
  final double progress;
  final BookAccess access;
  final String? sourceBookId;
  final String? coverUrl;
  final String? description;
  final int? year;
}
