import 'dart:async';

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
  SourceCatalogService({
    required SourceRegistry registry,
    Duration searchEnrichmentTimeout = const Duration(milliseconds: 800),
    int searchEnrichmentLimit = 8,
  }) : _registry = registry,
       _searchEnrichmentTimeout = searchEnrichmentTimeout,
       _searchEnrichmentLimit = searchEnrichmentLimit < 0
           ? 0
           : searchEnrichmentLimit;

  final SourceRegistry _registry;
  final Duration _searchEnrichmentTimeout;
  final int _searchEnrichmentLimit;
  final _searchDetailsCache = <String, Future<BookVersionDetails?>>{};

  Future<SourceSearchResponse> search(SearchRequest request) async {
    final normalizedQuery = _normalizeSearchText(request.query);
    final tokens = _queryTokens(normalizedQuery);
    if (tokens.isEmpty) {
      return const SourceSearchResponse(results: []);
    }

    final primaryResponse = await _registry.search(
      request.copyWith(query: normalizedQuery),
    );
    final resultsByKey = <String, BookSearchResult>{};
    final failures = <SourceFailure>[...primaryResponse.failures];
    _addSearchResults(resultsByKey, primaryResponse.results);

    var filtered = _filteredSortedResults(
      resultsByKey.values,
      request.effectiveKinds,
      tokens,
    );
    if (filtered.isEmpty && tokens.length > 1) {
      final fallbackResponses = await Future.wait(
        tokens.map((token) => _registry.search(request.copyWith(query: token))),
      );
      for (final response in fallbackResponses) {
        failures.addAll(response.failures);
        _addSearchResults(resultsByKey, response.results);
      }
      filtered = _filteredSortedResults(
        resultsByKey.values,
        request.effectiveKinds,
        tokens,
      );
    }
    final enriched = await _enrichSearchResults(filtered, request.pageSize);

    return SourceSearchResponse(
      results: List.unmodifiable(enriched),
      failures: List.unmodifiable(failures),
    );
  }

  static void _addSearchResults(
    Map<String, BookSearchResult> resultsByKey,
    Iterable<BookSearchResult> results,
  ) {
    for (final result in results) {
      resultsByKey['${result.sourceId}:${result.sourceBookId}'] = result;
    }
  }

  static List<BookSearchResult> _filteredSortedResults(
    Iterable<BookSearchResult> results,
    Set<SearchKind> kinds,
    List<String> tokens,
  ) {
    final filtered = results
        .where((result) => _matchesRequest(result, kinds, tokens))
        .toList();
    filtered.sort(
      (left, right) => _sortScore(
        right,
        kinds,
        tokens,
      ).compareTo(_sortScore(left, kinds, tokens)),
    );
    return filtered;
  }

  Future<List<BookSearchResult>> _enrichSearchResults(
    List<BookSearchResult> results,
    int pageSize,
  ) async {
    if (results.isEmpty) {
      return const [];
    }

    final limit = _effectiveEnrichmentLimit(results.length, pageSize);
    if (limit == 0) {
      return results;
    }

    final enrichedByIndex = <int, BookSearchResult>{};
    final jobs = <Future<void>>[];
    for (var index = 0; index < limit; index++) {
      final result = results[index];
      if (!_needsSearchEnrichment(result)) {
        continue;
      }
      jobs.add(
        _detailsForSearchResult(result).then((details) {
          if (details != null) {
            enrichedByIndex[index] = _mergeSearchDetails(result, details);
          }
        }),
      );
    }

    if (jobs.isEmpty) {
      return results;
    }

    final wait = Future.wait<void>(jobs, eagerError: false);
    if (_searchEnrichmentTimeout <= Duration.zero) {
      unawaited(wait.then<void>((_) {}));
      return _applyEnrichedResults(results, enrichedByIndex);
    }

    try {
      await wait.timeout(_searchEnrichmentTimeout);
    } on TimeoutException {
      unawaited(wait.then<void>((_) {}));
    }
    return _applyEnrichedResults(results, enrichedByIndex);
  }

  Future<BookVersionDetails?> _detailsForSearchResult(BookSearchResult result) {
    SourceConnector connector;
    try {
      connector = _registry.connectorById(result.sourceId);
    } on Object {
      return Future.value(null);
    }

    if (!connector.capabilities.supportsDetails ||
        !_needsSearchEnrichment(result)) {
      return Future.value(null);
    }

    final key = _detailsCacheKey(result.ref);
    final cached = _searchDetailsCache[key];
    if (cached != null) {
      return cached;
    }

    late final Future<BookVersionDetails?> future;
    future = connector
        .getBookDetails(result.ref)
        .then<BookVersionDetails?>(
          (details) => details,
          onError: (Object _) {
            _searchDetailsCache.remove(key);
            return null;
          },
        );
    _searchDetailsCache[key] = future;
    return future;
  }

  BookSearchResult _mergeSearchDetails(
    BookSearchResult result,
    BookVersionDetails details,
  ) {
    final version = details.version;
    final coverUri = _uriOrNull(version.coverUrl);
    final duration = _durationFromMs(version.durationMs);

    return BookSearchResult(
      ref: details.ref,
      sourceName: result.sourceName,
      title: _firstNonEmptyString([version.title, result.title]),
      author: _firstNonEmptyStringOrNull([
        version.authors.join(', '),
        result.author,
      ]),
      narrator: _firstNonEmptyStringOrNull([
        version.narrators.join(', '),
        result.narrator,
      ]),
      series: _firstNonEmptyStringOrNull([version.seriesTitle, result.series]),
      seriesNumber: version.seriesNumber ?? result.seriesNumber,
      genres: version.genres.isNotEmpty ? version.genres : result.genres,
      coverUri: coverUri ?? result.coverUri,
      duration: duration ?? result.duration,
      year: version.publishedYear ?? result.year,
      audioYear: version.audioYear ?? result.audioYear,
      chapterCount: result.chapterCount,
      isFull: version.isFull || (result.isFull ?? false),
      isFree: version.isAccessibleForFree || (result.isFree ?? false),
      accessType: version.accessType == AccessType.unknown
          ? result.accessType
          : version.accessType,
      ratingValue: version.ratingValue ?? result.ratingValue,
      ratingCount: version.ratingCount ?? result.ratingCount,
      score: result.score,
    );
  }

  Future<List<BookSearchResult>> findOtherNarrations(
    SourceBookSnapshot snapshot, {
    int limit = 12,
  }) async {
    final details = snapshot.details;
    final version = details.version;
    final resultsByKey = <String, BookSearchResult>{};

    void addResult(BookSearchResult result, {required bool explicit}) {
      if (_sameSourceRef(details.ref, result.ref)) {
        return;
      }
      if (!explicit && !_isSameWorkOtherNarration(version, result)) {
        return;
      }
      resultsByKey['${result.sourceId}:${result.sourceBookId}'] = result;
    }

    for (final alternative in details.alternatives) {
      addResult(alternative, explicit: true);
    }

    final rawQuery = _firstNonEmptyString([
      _canonicalTitle(version.title),
      version.title,
      version.seriesTitle,
      version.authors.join(' '),
    ]);
    final query = _normalizeSearchText(rawQuery);
    final tokens = _queryTokens(query);
    if (tokens.isNotEmpty) {
      final response = await _registry.search(
        SearchRequest(
          query: query,
          kinds: const {SearchKind.title},
          pageSize: limit < 20 ? 20 : limit * 2,
        ),
      );
      var filtered = _filteredSortedResults(response.results, const {
        SearchKind.title,
      }, tokens);
      if (filtered.isEmpty && tokens.length > 1) {
        final fallbackResponses = await Future.wait(
          tokens.map(
            (token) => _registry.search(
              SearchRequest(
                query: token,
                kinds: const {SearchKind.title},
                pageSize: limit < 20 ? 20 : limit * 2,
              ),
            ),
          ),
        );
        final fallbackResults = <BookSearchResult>[
          for (final response in fallbackResponses) ...response.results,
        ];
        filtered = _filteredSortedResults(fallbackResults, const {
          SearchKind.title,
        }, tokens);
      }
      for (final result in filtered) {
        addResult(result, explicit: false);
      }
    }

    final alternatives = resultsByKey.values.toList()
      ..sort((left, right) {
        final sourceCompare = left.sourceName.compareTo(right.sourceName);
        if (sourceCompare != 0) {
          return sourceCompare;
        }
        return (left.narrator ?? '').compareTo(right.narrator ?? '');
      });
    return List.unmodifiable(alternatives.take(limit));
  }

  Future<SourceBookSnapshot> loadBook(SourceBookRef ref) async {
    final connector = _registry.connectorById(ref.sourceId);
    final details = await connector.getBookDetails(ref);
    final chapters = await connector.getChapters(ref);
    final playbackChapters = await Future.wait([
      for (final chapter in chapters)
        _resolvePlaybackChapter(connector, chapter),
    ]);

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

  Future<AudioPlaybackChapter> _resolvePlaybackChapter(
    SourceConnector connector,
    Chapter chapter,
  ) async {
    final resolved = await connector.resolveMedia(
      chapter,
      MediaResolvePurpose.playback,
    );
    return _playbackChapter(chapter, resolved);
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
      seriesTitle: _emptyToNull(result.series),
      seriesNumber: result.seriesNumber,
      ratingValue: result.ratingValue,
      ratingCount: result.ratingCount,
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
      seriesTitle: _emptyToNull(version.seriesTitle),
      seriesNumber: version.seriesNumber,
      ratingValue: version.ratingValue,
      ratingCount: version.ratingCount,
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
    final playbackChapters = _chaptersWithFallbackDurations(
      chapters,
      version.durationMs,
    );
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
      seriesTitle: _emptyToNull(version.seriesTitle),
      seriesNumber: version.seriesNumber,
      ratingValue: version.ratingValue,
      ratingCount: version.ratingCount,
      publishedYear: version.publishedYear,
      sourceUrl: version.sourceUrl,
      chapters: List.unmodifiable(playbackChapters),
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

  int _effectiveEnrichmentLimit(int resultCount, int pageSize) {
    final requested = pageSize <= 0 || pageSize > _searchEnrichmentLimit
        ? _searchEnrichmentLimit
        : pageSize;
    if (requested <= 0) {
      return 0;
    }
    return requested > resultCount ? resultCount : requested;
  }

  static List<BookSearchResult> _applyEnrichedResults(
    List<BookSearchResult> results,
    Map<int, BookSearchResult> enrichedByIndex,
  ) {
    if (enrichedByIndex.isEmpty) {
      return results;
    }
    return [
      for (var index = 0; index < results.length; index++)
        enrichedByIndex[index] ?? results[index],
    ];
  }

  static String _detailsCacheKey(SourceBookRef ref) {
    return '${ref.sourceId}:${ref.sourceBookId}';
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

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static bool _needsSearchEnrichment(BookSearchResult result) {
    return result.author == null ||
        result.author!.trim().isEmpty ||
        result.narrator == null ||
        result.narrator!.trim().isEmpty ||
        result.series == null ||
        result.series!.trim().isEmpty ||
        result.seriesNumber == null ||
        result.coverUri == null ||
        result.duration == null ||
        result.year == null ||
        result.ratingValue == null ||
        result.ratingCount == null;
  }

  static Uri? _uriOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : Uri.tryParse(trimmed);
  }

  static Duration? _durationFromMs(int? milliseconds) {
    if (milliseconds == null || milliseconds <= 0) {
      return null;
    }
    return Duration(milliseconds: milliseconds);
  }

  static String _firstNonEmptyString(Iterable<String?> values) {
    return _firstNonEmptyStringOrNull(values) ?? '';
  }

  static String? _firstNonEmptyStringOrNull(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static bool _matchesRequest(
    BookSearchResult result,
    Set<SearchKind> kinds,
    List<String> tokens,
  ) {
    final haystacks = _haystacks(result, kinds);
    if (haystacks.isEmpty) {
      return false;
    }

    return tokens.every((token) {
      return haystacks.any((haystack) => _containsTokenPrefix(haystack, token));
    });
  }

  static int _sortScore(
    BookSearchResult result,
    Set<SearchKind> kinds,
    List<String> tokens,
  ) {
    final haystacks = _haystacks(result, kinds);
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

  static List<String> _haystacks(
    BookSearchResult result,
    Set<SearchKind> kinds,
  ) {
    final fields = <String>[];
    for (final kind in kinds) {
      switch (kind) {
        case SearchKind.title:
          fields.add(result.title);
          break;
        case SearchKind.author:
          fields.add(result.author ?? '');
          break;
        case SearchKind.narrator:
          fields.add(result.narrator ?? '');
          break;
        case SearchKind.series:
          fields.add(result.series ?? '');
          break;
        case SearchKind.genre:
          fields.addAll(result.genres);
          break;
        case SearchKind.all:
          fields.addAll([
            result.title,
            result.author ?? '',
            result.narrator ?? '',
            result.series ?? '',
            ...result.genres,
          ]);
          break;
      }
    }
    return fields
        .map(_normalizeSearchText)
        .where((value) => value.isNotEmpty)
        .toList();
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

  static bool _sameSourceRef(SourceBookRef left, SourceBookRef right) {
    return left.sourceId == right.sourceId &&
        left.sourceBookId == right.sourceBookId;
  }

  static List<AudioPlaybackChapter> _chaptersWithFallbackDurations(
    List<AudioPlaybackChapter> chapters,
    int? totalDurationMs,
  ) {
    if (chapters.isEmpty || totalDurationMs == null || totalDurationMs <= 0) {
      return chapters;
    }

    final missingDurationCount = chapters
        .where((chapter) => chapter.duration <= Duration.zero)
        .length;
    if (missingDurationCount == 0) {
      return chapters;
    }

    final knownDurationMs = chapters
        .where((chapter) => chapter.duration > Duration.zero)
        .fold<int>(0, (sum, chapter) => sum + chapter.duration.inMilliseconds);
    final remainingMs = totalDurationMs - knownDurationMs;
    if (remainingMs <= 0) {
      return chapters;
    }

    final baseMissingDurationMs = remainingMs ~/ missingDurationCount;
    var remainderMs = remainingMs % missingDurationCount;
    return [
      for (final chapter in chapters)
        if (chapter.duration > Duration.zero)
          chapter
        else
          chapter.copyWith(
            duration: Duration(
              milliseconds: baseMissingDurationMs + (remainderMs-- > 0 ? 1 : 0),
            ),
          ),
    ];
  }

  static bool _isSameWorkOtherNarration(
    BookVersion version,
    BookSearchResult result,
  ) {
    if (!_titleLooksSame(version.title, result.title)) {
      return false;
    }

    final authorMatches = _peopleOverlap(
      version.authors.join(', '),
      result.author,
    );
    final seriesMatches =
        _normalizeSearchText(version.seriesTitle ?? '').isNotEmpty &&
        _normalizeSearchText(version.seriesTitle ?? '') ==
            _normalizeSearchText(result.series ?? '') &&
        _seriesNumberMatches(version.seriesNumber, result.seriesNumber);
    if (!authorMatches && !seriesMatches) {
      return false;
    }

    final narratorMatches = _peopleOverlap(
      version.narrators.join(', '),
      result.narrator,
    );
    return !narratorMatches || version.sourceId != result.sourceId;
  }

  static bool _titleLooksSame(String left, String right) {
    final leftTokens = _queryTokens(_canonicalTitle(left)).toSet();
    final rightTokens = _queryTokens(_canonicalTitle(right)).toSet();
    if (leftTokens.isEmpty || rightTokens.isEmpty) {
      return false;
    }
    if (leftTokens.length == rightTokens.length &&
        leftTokens.containsAll(rightTokens)) {
      return true;
    }
    final shorter = leftTokens.length < rightTokens.length
        ? leftTokens
        : rightTokens;
    final longer = identical(shorter, leftTokens) ? rightTokens : leftTokens;
    return shorter.length >= 2 && longer.containsAll(shorter);
  }

  static String _canonicalTitle(String value) {
    final normalized = _normalizeSearchText(
      value
          .replaceFirst(RegExp(r'\bавтор\b.*$', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b(?:s|t|a|l|k|e|r)\b'), ''),
    );
    final tokens = normalized.split(' ').where((token) {
      if (token.length != 1) {
        return true;
      }
      return !RegExp(r'^[a-z]$').hasMatch(token);
    }).toList();
    return tokens.join(' ');
  }

  static bool _peopleOverlap(String left, String? right) {
    final leftKeys = _personKeys(left);
    final rightKeys = _personKeys(right ?? '');
    if (leftKeys.isEmpty || rightKeys.isEmpty) {
      return false;
    }
    return leftKeys.any(rightKeys.contains);
  }

  static Set<String> _personKeys(String value) {
    return value
        .split(RegExp(r'\s*(?:,|;|\n|/)\s*'))
        .map(_normalizeSearchText)
        .map(
          (person) => person
              .replaceAll(RegExp(r'\b(?:автор|читает|чтец|и|др)\b'), ' ')
              .trim(),
        )
        .where((person) => person.isNotEmpty)
        .map((person) {
          final tokens =
              person.split(' ').where((token) => token.length > 1).toList()
                ..sort();
          return tokens.join(' ');
        })
        .where((person) => person.isNotEmpty)
        .toSet();
  }

  static bool _seriesNumberMatches(double? left, double? right) {
    if (left == null || right == null) {
      return true;
    }
    return (left - right).abs() < 0.001;
  }
}
