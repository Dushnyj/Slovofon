enum AccessType { free, paid, subscription, unknown }

enum PlaybackAccess {
  none,
  streamOnly,
  downloadOnly,
  streamAndDownload,
  unknown,
}

class BookVersion {
  const BookVersion({
    required this.id,
    required this.bookId,
    required this.sourceId,
    required this.sourceBookId,
    this.sourceUrl,
    required this.title,
    required this.normalizedTitle,
    this.authors = const [],
    this.narrators = const [],
    this.translators = const [],
    this.seriesTitle,
    this.seriesNumber,
    this.genres = const [],
    this.tags = const [],
    this.description,
    this.coverUrl,
    this.localCoverPath,
    this.durationMs,
    this.durationText,
    this.publishedYear,
    this.audioYear,
    this.ratingValue,
    this.ratingCount,
    this.accessType = AccessType.unknown,
    this.playbackAccess = PlaybackAccess.unknown,
    this.isFull = false,
    this.isFragment = false,
    this.isPaid = false,
    this.isSubscription = false,
    this.isAccessibleForFree = false,
    this.canStream = false,
    this.canDownload = false,
    this.rawSourceDataJson,
    this.lastResolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final String sourceId;
  final String sourceBookId;
  final String? sourceUrl;
  final String title;
  final String normalizedTitle;
  final List<String> authors;
  final List<String> narrators;
  final List<String> translators;
  final String? seriesTitle;
  final double? seriesNumber;
  final List<String> genres;
  final List<String> tags;
  final String? description;
  final String? coverUrl;
  final String? localCoverPath;
  final int? durationMs;
  final String? durationText;
  final int? publishedYear;
  final int? audioYear;
  final double? ratingValue;
  final int? ratingCount;
  final AccessType accessType;
  final PlaybackAccess playbackAccess;
  final bool isFull;
  final bool isFragment;
  final bool isPaid;
  final bool isSubscription;
  final bool isAccessibleForFree;
  final bool canStream;
  final bool canDownload;
  final String? rawSourceDataJson;
  final DateTime? lastResolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
