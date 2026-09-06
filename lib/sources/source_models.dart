import '../domain/models/book.dart';
import '../domain/models/book_version.dart';
import '../services/audio/audio_state.dart';

enum SearchKind { all, title, author, narrator, series, genre }

enum SearchSort { relevance, rating, year, duration, title }

enum MediaResolvePurpose { playback, download, probe }

enum SourceErrorKind {
  unsupported,
  api,
  network,
  parser,
  mediaValidation,
  notFound,
  unauthorized,
  rateLimited,
  unknown,
}

enum SourceHealthStatus {
  working,
  workingThroughProxy,
  unavailable,
  requiresProxy,
  apiError,
  structureChanged,
  chaptersUnavailable,
  mediaUnavailable,
  rateLimited,
}

class SearchRequest {
  const SearchRequest({
    required this.query,
    this.kind = SearchKind.all,
    this.kinds = const {},
    this.page = 1,
    this.pageSize = 20,
    this.sourceIds = const {},
    this.sort = SearchSort.relevance,
  });

  final String query;
  final SearchKind kind;
  final Set<SearchKind> kinds;
  final int page;
  final int pageSize;
  final Set<String> sourceIds;
  final SearchSort sort;

  Set<SearchKind> get effectiveKinds {
    final selected = kinds.where((kind) => kind != SearchKind.all).toSet();
    if (selected.isNotEmpty) {
      return Set.unmodifiable(selected);
    }
    if (kind == SearchKind.all) {
      return const {
        SearchKind.title,
        SearchKind.author,
        SearchKind.narrator,
        SearchKind.series,
        SearchKind.genre,
      };
    }
    return {kind};
  }

  bool allowsSource(String sourceId) {
    return sourceIds.isEmpty || sourceIds.contains(sourceId);
  }

  SearchRequest copyWith({
    String? query,
    SearchKind? kind,
    Set<SearchKind>? kinds,
    int? page,
    int? pageSize,
    Set<String>? sourceIds,
    SearchSort? sort,
  }) {
    return SearchRequest(
      query: query ?? this.query,
      kind: kind ?? this.kind,
      kinds: kinds ?? this.kinds,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sourceIds: sourceIds ?? this.sourceIds,
      sort: sort ?? this.sort,
    );
  }
}

class SourceBookRef {
  const SourceBookRef({
    required this.sourceId,
    required this.sourceBookId,
    this.sourceUri,
  });

  final String sourceId;
  final String sourceBookId;
  final Uri? sourceUri;
}

class BookSearchResult {
  const BookSearchResult({
    required this.ref,
    required this.sourceName,
    required this.title,
    this.author,
    this.narrator,
    this.series,
    this.seriesNumber,
    this.genres = const [],
    this.coverUri,
    this.duration,
    this.year,
    this.audioYear,
    this.chapterCount,
    this.isFull,
    this.isFragment = false,
    this.isFree,
    this.accessType = AccessType.unknown,
    this.ratingValue,
    this.ratingCount,
    this.score,
  });

  final SourceBookRef ref;
  final String sourceName;
  final String title;
  final String? author;
  final String? narrator;
  final String? series;
  final double? seriesNumber;
  final List<String> genres;
  final Uri? coverUri;
  final Duration? duration;
  final int? year;
  final int? audioYear;
  final int? chapterCount;
  final bool? isFull;
  final bool isFragment;
  final bool? isFree;
  final AccessType accessType;
  final double? ratingValue;
  final int? ratingCount;
  final double? score;

  String get sourceId => ref.sourceId;
  String get sourceBookId => ref.sourceBookId;
}

class BookVersionDetails {
  const BookVersionDetails({
    required this.ref,
    required this.version,
    this.book,
    this.alternatives = const [],
  });

  final SourceBookRef ref;
  final BookVersion version;
  final Book? book;
  final List<BookSearchResult> alternatives;
}

class SourceCapabilities {
  const SourceCapabilities({
    this.supportsSearch = false,
    this.supportsSearchByTitle = false,
    this.supportsSearchByAuthor = false,
    this.supportsSearchByNarrator = false,
    this.supportsSearchBySeries = false,
    this.supportsDetails = false,
    this.supportsChapters = false,
    this.supportsSeries = false,
    this.supportsRating = false,
    this.supportsDescription = false,
    this.supportsDirectAudio = false,
    this.supportsDownload = false,
    this.supportsFragments = false,
    this.supportsPaidItems = false,
    this.requiresSpecialHeaders = false,
    this.requiresMediaProxy = false,
    this.hasTemporaryUrls = false,
    this.hasApiSignature = false,
    this.hasHtmlParser = false,
    this.hasGraphQlApi = false,
  });

  static const none = SourceCapabilities();

  final bool supportsSearch;
  final bool supportsSearchByTitle;
  final bool supportsSearchByAuthor;
  final bool supportsSearchByNarrator;
  final bool supportsSearchBySeries;
  final bool supportsDetails;
  final bool supportsChapters;
  final bool supportsSeries;
  final bool supportsRating;
  final bool supportsDescription;
  final bool supportsDirectAudio;
  final bool supportsDownload;
  final bool supportsFragments;
  final bool supportsPaidItems;
  final bool requiresSpecialHeaders;
  final bool requiresMediaProxy;
  final bool hasTemporaryUrls;
  final bool hasApiSignature;
  final bool hasHtmlParser;
  final bool hasGraphQlApi;
}

class SourceMediaPolicy {
  const SourceMediaPolicy({
    this.metadataHosts = const {},
    this.mediaHosts = const {},
    this.coverHosts = const {},
    this.allowLocalMedia = false,
  });

  final Set<String> metadataHosts;
  final Set<String> mediaHosts;
  final Set<String> coverHosts;
  final bool allowLocalMedia;

  bool allowsMediaHost(String host) {
    return _matchesHost(host, mediaHosts);
  }

  bool allowsMetadataHost(String host) {
    return _matchesHost(host, metadataHosts);
  }

  bool allowsCoverHost(String host) {
    return _matchesHost(host, coverHosts);
  }

  static bool _matchesHost(String host, Set<String> allowlist) {
    final normalizedHost = _normalizeHost(host);
    if (normalizedHost.isEmpty) {
      return false;
    }

    for (final allowed in allowlist) {
      final normalizedAllowed = _normalizeHost(allowed);
      if (normalizedAllowed.isEmpty) {
        continue;
      }
      if (normalizedHost == normalizedAllowed ||
          normalizedHost.endsWith('.$normalizedAllowed')) {
        return true;
      }
    }

    return false;
  }

  static String _normalizeHost(String host) {
    return host.trim().toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  }
}

class ResolvedMedia {
  const ResolvedMedia({
    required this.sourceId,
    required this.mediaSource,
    required this.resolvedAt,
    this.sourceBookId,
    this.chapterId,
    this.originalUri,
    this.expiresAt,
    this.requiresProxy = false,
    this.supportsRange = false,
  });

  final String sourceId;
  final String? sourceBookId;
  final String? chapterId;
  final AudioMediaSource mediaSource;
  final Uri? originalUri;
  final DateTime resolvedAt;
  final DateTime? expiresAt;
  final bool requiresProxy;
  final bool supportsRange;
}

class SourceHealth {
  const SourceHealth({
    required this.sourceId,
    required this.status,
    required this.checkedAt,
    this.responseTime,
    this.message,
  });

  factory SourceHealth.working({
    required String sourceId,
    DateTime? checkedAt,
    Duration? responseTime,
    String? message,
  }) {
    return SourceHealth(
      sourceId: sourceId,
      status: SourceHealthStatus.working,
      checkedAt: checkedAt ?? DateTime.now(),
      responseTime: responseTime,
      message: message,
    );
  }

  final String sourceId;
  final SourceHealthStatus status;
  final DateTime checkedAt;
  final Duration? responseTime;
  final String? message;

  bool get isUsable {
    return status == SourceHealthStatus.working ||
        status == SourceHealthStatus.workingThroughProxy;
  }
}

class SourceException implements Exception {
  const SourceException({
    required this.sourceId,
    required this.kind,
    required this.message,
    this.cause,
  });

  final String sourceId;
  final SourceErrorKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() {
    return 'SourceException($sourceId, $kind, $message)';
  }
}

class SourceFailure {
  const SourceFailure({
    required this.sourceId,
    required this.kind,
    required this.message,
    this.cause,
  });

  factory SourceFailure.fromError(String sourceId, Object error) {
    if (error is SourceException) {
      return SourceFailure(
        sourceId: error.sourceId,
        kind: error.kind,
        message: error.message,
        cause: error.cause,
      );
    }

    return SourceFailure(
      sourceId: sourceId,
      kind: SourceErrorKind.unknown,
      message: error.toString(),
      cause: error,
    );
  }

  final String sourceId;
  final SourceErrorKind kind;
  final String message;
  final Object? cause;
}

class SourceSearchResponse {
  const SourceSearchResponse({required this.results, this.failures = const []});

  final List<BookSearchResult> results;
  final List<SourceFailure> failures;

  bool get hasPartialFailures => results.isNotEmpty && failures.isNotEmpty;
  bool get hasFailures => failures.isNotEmpty;
}
