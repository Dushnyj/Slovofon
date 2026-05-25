class Book {
  const Book({
    required this.id,
    required this.normalizedTitle,
    required this.displayTitle,
    this.authors = const [],
    this.seriesTitle,
    this.seriesNumber,
    this.year,
    this.bestCoverUrl,
    this.bestLocalCoverPath,
    this.bestDescription,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String normalizedTitle;
  final String displayTitle;
  final List<String> authors;
  final String? seriesTitle;
  final double? seriesNumber;
  final int? year;
  final String? bestCoverUrl;
  final String? bestLocalCoverPath;
  final String? bestDescription;
  final DateTime createdAt;
  final DateTime updatedAt;
}
