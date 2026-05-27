import '../../domain/models/audio_book.dart';
import '../../domain/models/book_version.dart';
import '../../domain/models/chapter.dart';
import '../../sources/sources.dart';
import '../audio/audio_state.dart';

class SourceBookSnapshot {
  const SourceBookSnapshot({
    required this.details,
    required this.chapters,
    required this.audioBook,
    required this.playbackBook,
  });

  final BookVersionDetails details;
  final List<Chapter> chapters;
  final AudioBook audioBook;
  final AudioPlaybackBook playbackBook;
}

class SourceCatalogService {
  const SourceCatalogService({required SourceRegistry registry})
    : _registry = registry;

  final SourceRegistry _registry;

  Future<SourceSearchResponse> search(SearchRequest request) async {
    final normalizedQuery = _normalizeSearchText(request.query);
    final tokens = _queryTokens(normalizedQuery);
    if (tokens.isEmpty) {
      return const SourceSearchResponse(results: []);
    }

    final responses = <SourceSearchResponse>[
      await _registry.search(request.copyWith(query: normalizedQuery)),
    ];
    if (tokens.length > 1) {
      for (final token in tokens) {
        responses.add(await _registry.search(request.copyWith(query: token)));
      }
    }

    final resultsByKey = <String, BookSearchResult>{};
    final failures = <SourceFailure>[];
    for (final response in responses) {
      failures.addAll(response.failures);
      for (final result in response.results) {
        resultsByKey['${result.sourceId}:${result.sourceBookId}'] = result;
      }
    }

    final filtered = resultsByKey.values
        .where((result) => _matchesRequest(result, request.kind, tokens))
        .toList();
    filtered.sort(
      (left, right) => _sortScore(
        right,
        request.kind,
        tokens,
      ).compareTo(_sortScore(left, request.kind, tokens)),
    );

    return SourceSearchResponse(
      results: List.unmodifiable(filtered),
      failures: List.unmodifiable(failures),
    );
  }

  Future<SourceBookSnapshot> loadBook(SourceBookRef ref) async {
    final connector = _registry.connectorById(ref.sourceId);
    final details = await connector.getBookDetails(ref);
    final chapters = await connector.getChapters(ref);
    final playbackChapters = <AudioPlaybackChapter>[];

    for (final chapter in chapters) {
      final resolved = await connector.resolveMedia(
        chapter,
        MediaResolvePurpose.playback,
      );
      playbackChapters.add(_playbackChapter(chapter, resolved));
    }

    final audioBook = audioBookForDetails(details, chapters.length);
    final playbackBook = _playbackBook(
      details,
      playbackChapters,
      requestedRef: ref,
    );

    return SourceBookSnapshot(
      details: details,
      chapters: List.unmodifiable(chapters),
      audioBook: audioBook,
      playbackBook: playbackBook,
    );
  }

  AudioBook audioBookForSearchResult(BookSearchResult result) {
    return AudioBook(
      id: result.ref.sourceBookId,
      sourceBookId: result.ref.sourceBookId,
      title: result.title,
      author: result.author ?? '',
      narrator: result.narrator ?? '',
      sourceId: result.sourceId,
      sourceName: result.sourceName,
      durationLabel: _durationLabel(result.duration),
      chapterCount: result.chapterCount ?? 0,
      progress: 0,
      access: _bookAccess(result.accessType),
      coverUrl: result.coverUri?.toString(),
      year: result.year,
    );
  }

  AudioBook audioBookForDetails(BookVersionDetails details, int chapterCount) {
    final version = details.version;
    return AudioBook(
      id: version.bookId,
      sourceBookId: version.sourceBookId,
      title: version.title,
      author: version.authors.join(', '),
      narrator: version.narrators.join(', '),
      sourceId: version.sourceId,
      sourceName: _sourceName(version.sourceId),
      durationLabel:
          version.durationText ?? _durationMsLabel(version.durationMs),
      chapterCount: chapterCount,
      progress: 0,
      access: _bookAccess(version.accessType),
      coverUrl: version.coverUrl,
      description: version.description,
      year: version.publishedYear,
    );
  }

  AudioPlaybackBook _playbackBook(
    BookVersionDetails details,
    List<AudioPlaybackChapter> chapters, {
    required SourceBookRef requestedRef,
  }) {
    final version = details.version;
    final sourceBookId = requestedRef.sourceId == version.sourceId
        ? requestedRef.sourceBookId
        : version.sourceBookId;
    return AudioPlaybackBook(
      id: version.bookId,
      versionId: version.id,
      sourceId: version.sourceId,
      sourceBookId: sourceBookId,
      title: version.title,
      author: version.authors.join(', '),
      narrator: version.narrators.join(', '),
      sourceName: _sourceName(version.sourceId),
      coverUrl: version.coverUrl,
      description: version.description,
      genre: _first(version.genres),
      publishedYear: version.publishedYear,
      sourceUrl: version.sourceUrl,
      chapters: List.unmodifiable(chapters),
    );
  }

  AudioPlaybackChapter _playbackChapter(
    Chapter chapter,
    ResolvedMedia resolved,
  ) {
    return AudioPlaybackChapter(
      id: chapter.id,
      index: chapter.index,
      title: chapter.title,
      duration: Duration(milliseconds: chapter.durationMs ?? 0),
      isDownloaded: chapter.downloadStatus == ChapterDownloadStatus.completed,
      mediaSource: resolved.mediaSource,
    );
  }

  static String _sourceName(String sourceId) {
    return switch (sourceId) {
      'izib' => 'Izib',
      'akniga' => 'Akniga',
      'yakniga' => 'Yakniga',
      'knigavuhe' => 'Knigavuhe',
      'knigoblud' => 'Knigoblud',
      'baza_knig' => 'Baza Knig',
      _ => sourceId,
    };
  }

  static BookAccess _bookAccess(AccessType accessType) {
    return switch (accessType) {
      AccessType.free => BookAccess.free,
      AccessType.paid => BookAccess.paid,
      AccessType.subscription => BookAccess.subscription,
      AccessType.unknown => BookAccess.unknown,
    };
  }

  static String _durationLabel(Duration? duration) {
    if (duration == null || duration <= Duration.zero) {
      return '—';
    }
    return _formatDuration(duration);
  }

  static String _durationMsLabel(int? milliseconds) {
    if (milliseconds == null || milliseconds <= 0) {
      return '—';
    }
    return _formatDuration(Duration(milliseconds: milliseconds));
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return minutes > 0 ? '$hours ч $minutes мин' : '$hours ч';
    }
    return '$minutes мин';
  }

  static String? _first(List<String> values) {
    return values.isEmpty ? null : values.first;
  }

  static bool _matchesRequest(
    BookSearchResult result,
    SearchKind kind,
    List<String> tokens,
  ) {
    final haystacks = _haystacks(result, kind);
    if (haystacks.isEmpty) {
      return false;
    }

    return tokens.every((token) {
      return haystacks.any((haystack) => _containsTokenPrefix(haystack, token));
    });
  }

  static int _sortScore(
    BookSearchResult result,
    SearchKind kind,
    List<String> tokens,
  ) {
    final haystacks = _haystacks(result, kind);
    var score = 0;
    for (final haystack in haystacks) {
      final words = _queryTokens(haystack);
      for (final token in tokens) {
        if (words.contains(token)) {
          score += 4;
        } else if (words.any((word) => word.startsWith(token))) {
          score += 2;
        }
      }
    }
    return score;
  }

  static List<String> _haystacks(BookSearchResult result, SearchKind kind) {
    return switch (kind) {
      SearchKind.title => [result.title],
      SearchKind.author => [result.author ?? ''],
      SearchKind.narrator => [result.narrator ?? ''],
      SearchKind.series => [result.series ?? ''],
      SearchKind.all => [
        result.title,
        result.author ?? '',
        result.narrator ?? '',
        result.series ?? '',
      ],
    }.map(_normalizeSearchText).where((value) => value.isNotEmpty).toList();
  }

  static bool _containsTokenPrefix(String text, String token) {
    return _queryTokens(text).any((word) => word.startsWith(token));
  }

  static List<String> _queryTokens(String text) {
    return _normalizeSearchText(
      text,
    ).split(' ').where((token) => token.isNotEmpty).toList();
  }

  static String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^0-9a-zа-я]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
