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
    this.seriesTitle,
    this.seriesNumber,
    this.ratingValue,
    this.ratingCount,
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
  final String? seriesTitle;
  final double? seriesNumber;
  final double? ratingValue;
  final int? ratingCount;
  final int? year;

  AudioBook copyWith({
    String? id,
    String? title,
    String? author,
    String? narrator,
    String? sourceId,
    String? sourceName,
    String? durationLabel,
    int? chapterCount,
    double? progress,
    BookAccess? access,
    String? sourceBookId,
    String? coverUrl,
    String? description,
    String? seriesTitle,
    double? seriesNumber,
    double? ratingValue,
    int? ratingCount,
    int? year,
  }) {
    return AudioBook(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      narrator: narrator ?? this.narrator,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      durationLabel: durationLabel ?? this.durationLabel,
      chapterCount: chapterCount ?? this.chapterCount,
      progress: progress ?? this.progress,
      access: access ?? this.access,
      sourceBookId: sourceBookId ?? this.sourceBookId,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      seriesNumber: seriesNumber ?? this.seriesNumber,
      ratingValue: ratingValue ?? this.ratingValue,
      ratingCount: ratingCount ?? this.ratingCount,
      year: year ?? this.year,
    );
  }
}
