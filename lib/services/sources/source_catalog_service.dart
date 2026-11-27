import 'dart:async';
import 'dart:convert';

import '../../domain/models/audio_book.dart';
import '../../domain/models/book_version.dart';
import '../../domain/models/chapter.dart';
import '../../sources/sources.dart';
import '../../sources/source_request_cache.dart';
import '../../sources/source_search_text.dart';
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
    Duration searchTimeout = const Duration(seconds: 20),
  }) : _registry = registry,
       _searchTimeout = searchTimeout,
       _searchEnrichmentTimeout = searchEnrichmentTimeout,
       _searchEnrichmentLimit = searchEnrichmentLimit < 0
           ? 0
           : searchEnrichmentLimit;

  final SourceRegistry _registry;
  final Duration _searchTimeout;
  final Duration _searchEnrichmentTimeout;
  final int _searchEnrichmentLimit;
  final _bookDetailsCache = SourceRequestCache<String, BookVersionDetails>();
  final _chapterDescriptorsCache = SourceRequestCache<String, List<Chapter>>();
  final _chapterDescriptorRefreshes = <String, Future<List<Chapter>>>{};
  final _bookRefreshes = <String, Future<SourceBookSnapshot>>{};
  static const _pagesPerLane = 3;
  static const _requestsPerSource = 6;

  /// Publishes cumulative, filtered and sorted results as sources finish.
  /// The returned Future remains the final snapshot for existing consumers.
  Future<SourceSearchResponse> search(
    SearchRequest request, {
    void Function(SourceSearchResponse response)? onUpdate,
    SourceSearchCancellation? cancellation,
  }) async {
    final tokens = _queryTokens(request.query).toSet().toList();
    if (tokens.isEmpty) {
      return const SourceSearchResponse(results: []);
    }
    final query = request.query.trim();
    final kinds = request.effectiveKinds;
    final previous = request.continuation;
    final state =
        previous is _CatalogSearchContinuation &&
            previous.belongsTo(this, request)
        ? previous.copy(retryFailuresOnly: previous.retryFailuresOnly)
        : _CatalogSearchContinuation(
            owner: this,
            request: request,
            sources: {
              for (final connector in _registry.enabledConnectors)
                if (request.allowsSource(connector.id))
                  connector.id: _SourceSearchState(connector, [
                    _SearchLane(query, request.page < 1 ? 1 : request.page),
                  ]),
            },
          );

    final operation = SourceSearchCancellation();
    final unlink = cancellation?.addListener(operation.cancel);
    final deadline = Timer(
      _searchTimeout > Duration.zero ? _searchTimeout : Duration.zero,
      () => operation.cancel(timedOut: true),
    );
    final retrySourceIds = state.retryFailuresOnly
        ? {
            for (final source in state.sources.values)
              if (source.lanes.any((lane) => lane.retryPage != null))
                source.connector.id,
          }
        : null;
    final fetchable = [
      for (final source in state.sources.values)
        if (source.canFetch(retryOnly: state.retryFailuresOnly)) source,
    ];
    final searching = {for (final source in fetchable) source.connector.id};

    SourceSearchResponse snapshot({bool finalResult = false}) {
      final matches = state.sortedMatches;
      final counts = state.matchCounts;
      final failures = {
        for (final entry in state.sources.entries)
          entry.key: ?entry.value.failure,
      };
      return SourceSearchResponse(
        results: matches,
        failures: List.unmodifiable(failures.values.map((item) => item.error)),
        limitedSourceIds: Set.unmodifiable({
          for (final source in state.sources.values)
            if (source.limited) source.connector.id,
          ...state.incompleteMetadataSourceIds,
        }),
        sourceStatuses: List.unmodifiable([
          for (final connector in _registry.connectors)
            SearchSourceStatus(
              sourceId: connector.id,
              participation: !_registry.enabledSourceIds.contains(connector.id)
                  ? SearchSourceParticipation.disabled
                  : !request.allowsSource(connector.id)
                  ? SearchSourceParticipation.filtered
                  : searching.contains(connector.id)
                  ? SearchSourceParticipation.searching
                  : SearchSourceParticipation.completed,
              matchCount: counts[connector.id] ?? 0,
              paginationLimited: state.sources[connector.id]?.limited ?? false,
              metadataIncomplete: state.incompleteMetadataSourceIds.contains(
                connector.id,
              ),
              failureKind: failures[connector.id]?.error.kind,
              failedPage: failures[connector.id]?.page,
            ),
        ]),
        continuation: finalResult && state.hasMore
            ? state.copy(retryFailuresOnly: false)
            : null,
        retryContinuation: finalResult && state.hasRetryableLane
            ? state.copy(retryFailuresOnly: true)
            : null,
      );
    }

    Timer? updateTimer;
    var publishedResults = false;
    void publish() {
      if (operation.isCancelled || onUpdate == null) return;
      // The first ready results must not wait for other connectors. Thereafter
      // publish at most one update per frame-sized burst of upstream pages.
      if (!publishedResults && state.sortedMatches.isNotEmpty) {
        updateTimer?.cancel();
        updateTimer = null;
        publishedResults = true;
        onUpdate(snapshot());
        return;
      }
      updateTimer ??= Timer(const Duration(milliseconds: 16), () {
        updateTimer = null;
        if (!operation.isCancelled) onUpdate(snapshot());
      });
    }

    Future<void> fetchSource(_SourceSearchState source) async {
      final attempts = <_SearchLane, int>{};
      for (
        var attempt = 0;
        attempt < _requestsPerSource && !operation.isCancelled;
        attempt++
      ) {
        _SearchLane? lane;
        var least = _pagesPerLane;
        for (final candidate in source.lanes) {
          final count = attempts[candidate] ?? 0;
          final page = state.retryFailuresOnly
              ? candidate.retryPage
              : candidate.nextPage;
          if (page != null && count < least) {
            lane = candidate;
            least = count;
          }
        }
        if (lane == null) break;
        final currentPage = state.retryFailuresOnly
            ? lane.retryPage!
            : lane.nextPage!;
        attempts[lane] = least + 1;
        SourceSearchPage page;
        try {
          page = await _registry.searchPage(
            source.connector,
            request.copyWith(
              query: lane.query,
              page: currentPage,
              sourceCursor: lane.cursor,
            ),
            cancellation: operation,
          );
          operation.throwIfCancelled();
        } on SourceSearchCancelled {
          if (operation.isTimedOut) {
            lane.failure = (
              error: SourceFailure(
                sourceId: source.connector.id,
                kind: SourceErrorKind.network,
                message: 'Source search exceeded the overall time budget.',
              ),
              page: currentPage,
            );
            lane.retryPage = currentPage;
          }
          return;
        } on Object catch (error) {
          final failure = SourceFailure.fromError(source.connector.id, error);
          lane.failure = (error: failure, page: currentPage);
          lane.retryPage = failure.kind == SourceErrorKind.unsupported
              ? null
              : currentPage;
          lane.nextPage = null;
          attempts[lane] = _pagesPerLane;
          // Alternative spellings are not a network/proxy retry mechanism.
          if (source.pausesAutomaticRequests ||
              (identical(lane, source.lanes.first) &&
                  !source.plannedAlternatives)) {
            break;
          }
          continue;
        }
        lane.retryPage = null;
        lane.failure = null;
        final pageKeys = page.results.map(_searchResultKey).toSet().toList()
          ..sort();
        final repeated =
            pageKeys.isNotEmpty && !lane.seenPages.add(jsonEncode(pageKeys));
        source.limited |=
            page.limited ||
            (repeated && page.nextPage != null) ||
            (page.nextPage != null && page.nextPage! <= currentPage);
        lane.nextPage =
            !repeated && page.nextPage != null && page.nextPage! > currentPage
            ? page.nextPage
            : null;
        lane.cursor = lane.nextPage == null ? null : page.nextCursor;
        for (final result in page.results) {
          final key = _searchResultKey(result);
          final existing = state.results[key];
          state.setResult(
            key,
            existing == null || identical(existing, result)
                ? result
                : _combineSearchCards(existing, result),
          );
        }

        if (!source.plannedAlternatives) {
          source.plannedAlternatives = true;
          final alreadyMatched = page.results.any(
            (result) => state.project(result).matches,
          );
          if (request.page <= 1 &&
              !page.usedRequestedScope &&
              (!alreadyMatched ||
                  page.limited ||
                  tokens.length >= 5 ||
                  _isPersonSearch(kinds))) {
            source.lanes.addAll(
              _queryVariants(
                query,
                tokens,
                kinds,
              ).map((variant) => _SearchLane(variant, 1)),
            );
          }
        }
        publish();
      }
    }

    try {
      cancellation?.throwIfCancelled();
      _applySettledSearchDetails(state);
      publish();
      await Future.wait<void>(
        fetchable.map((source) async {
          try {
            await fetchSource(source);
          } finally {
            searching.remove(source.connector.id);
            publish();
          }
        }),
      );
      cancellation?.throwIfCancelled();
      // First results never wait for optional detail/enrichment requests.
      await _enrichSearchResults(state, operation, sourceIds: retrySourceIds);
      cancellation?.throwIfCancelled();
      state.metadataHasMore = false;
      state.incompleteMetadataSourceIds.clear();
      for (final result in state.results.values) {
        final projected = state.project(result);
        if (projected.matches || !projected.couldMatchWithDetails) {
          continue;
        }
        state.incompleteMetadataSourceIds.add(result.sourceId);
        final key = _searchResultKey(result);
        if (state.pendingDetails.containsKey(key) ||
            (state.sources[result.sourceId]?.pausesAutomaticRequests != true &&
                _searchEnrichmentLimit > 0 &&
                !state.attemptedDetails.contains(key) &&
                _canEnrichSearchResult(result))) {
          state.metadataHasMore = true;
        }
      }
      final response = snapshot(finalResult: true);
      if (!operation.isCancelled) onUpdate?.call(response);
      return response;
    } finally {
      updateTimer?.cancel();
      deadline.cancel();
      unlink?.call();
      operation.cancel();
    }
  }

  static String _searchResultKey(BookSearchResult result) =>
      '${result.sourceId}:${result.sourceBookId}';

  static BookSearchResult _combineSearchCards(
    BookSearchResult primary,
    BookSearchResult added,
  ) {
    List<String> mergePeople(
      String? existingDisplay,
      List<String> existingPeople,
      String? newDisplay,
      List<String> newPeople,
    ) {
      if (existingPeople.isNotEmpty || newPeople.isEmpty) return existingPeople;
      if (existingDisplay?.trim().isNotEmpty != true ||
          _normalizeSearchText(existingDisplay!) ==
              _normalizeSearchText(newDisplay ?? newPeople.join(', '))) {
        return newPeople;
      }
      return existingPeople;
    }

    return BookSearchResult(
      ref: primary.ref.sourceUri != null ? primary.ref : added.ref,
      sourceName: primary.sourceName,
      title: _firstNonEmptyString([primary.title, added.title]),
      author: _firstNonEmptyStringOrNull([
        primary.author,
        primary.authors.join(', '),
        added.author,
        added.authors.join(', '),
      ]),
      narrator: _firstNonEmptyStringOrNull([
        primary.narrator,
        primary.narrators.join(', '),
        added.narrator,
        added.narrators.join(', '),
      ]),
      authors: mergePeople(
        primary.author,
        primary.authors,
        added.author,
        added.authors,
      ),
      narrators: mergePeople(
        primary.narrator,
        primary.narrators,
        added.narrator,
        added.narrators,
      ),
      series: _firstNonEmptyStringOrNull([primary.series, added.series]),
      seriesNumber: primary.seriesNumber ?? added.seriesNumber,
      genres: List.unmodifiable({...primary.genres, ...added.genres}),
      coverUri: primary.coverUri ?? added.coverUri,
      duration: primary.duration ?? added.duration,
      year: primary.year ?? added.year,
      audioYear: primary.audioYear ?? added.audioYear,
      chapterCount: primary.chapterCount ?? added.chapterCount,
      isFull: primary.isFull ?? added.isFull,
      isFragment: primary.isFragment || added.isFragment,
      isFree: primary.isFree ?? added.isFree,
      accessType: primary.accessType == AccessType.unknown
          ? added.accessType
          : primary.accessType,
      ratingValue: primary.ratingValue ?? added.ratingValue,
      ratingCount: primary.ratingCount ?? added.ratingCount,
      score: primary.score ?? added.score,
    );
  }

  static bool _isPersonSearch(Set<SearchKind> kinds) =>
      !kinds.contains(SearchKind.title) &&
      (kinds.contains(SearchKind.author) ||
          kinds.contains(SearchKind.narrator));

  static Iterable<String> _queryVariants(
    String query,
    List<String> tokens,
    Set<SearchKind> kinds,
  ) {
    final lowerQuery = query.toLowerCase();
    final variants = <String>{
      if (_normalizeSearchText(query) != lowerQuery)
        _normalizeSearchText(query),
      if (tokens.length == 2 &&
          (kinds.contains(SearchKind.author) ||
              kinds.contains(SearchKind.narrator)))
        tokens.reversed.join(' '),
      if (tokens.length >= 3)
        for (var start = 0; start + 1 < tokens.length && start < 8; start += 2)
          '${tokens[start]} ${tokens[start + 1]}',
      if (tokens.length >= 2) ...tokens.where((token) => token.length > 2),
    };
    variants.remove(lowerQuery);
    return variants.take(4);
  }

  static bool _couldMatchWithDetails(
    BookSearchResult result,
    Set<SearchKind> kinds,
    List<String> tokens,
  ) {
    if (!kinds.any(
      (kind) => switch (kind) {
        SearchKind.author => result.author?.trim().isNotEmpty != true,
        SearchKind.narrator => result.narrator?.trim().isNotEmpty != true,
        SearchKind.series => result.series?.trim().isNotEmpty != true,
        SearchKind.genre => result.genres.isEmpty,
        SearchKind.title => result.title.trim().isEmpty,
        SearchKind.all => false,
      },
    )) {
      return false;
    }
    // Explicit roles/genres can be absent from listing cards even when the
    // source got the entity right. In unrestricted search, require some
    // already-known word evidence before spending a detail request.
    if (kinds.length == 1 && !kinds.contains(SearchKind.title)) return true;
    return _haystacks(
      result,
      kinds,
    ).any((field) => tokens.any((token) => _containsTokenPrefix(field, token)));
  }

  static List<BookSearchResult> _filteredSortedResults(
    Iterable<BookSearchResult> results,
    Set<SearchKind> kinds,
    List<String> tokens,
  ) => _sortedProjections(
    results
        .map((result) => _SearchProjection(result, kinds, tokens))
        .where((projection) => projection.matches),
    SearchSort.relevance,
  );

  /// Applies the same field matching and ordering to already available books.
  /// Unlike [search], this has no connector access or enrichment.
  static List<BookSearchResult> searchMetadata(
    Iterable<BookSearchResult> books,
    SearchRequest request,
  ) {
    final tokens = _queryTokens(request.query).toSet().toList();
    final kinds = request.effectiveKinds;
    return _sortedProjections(
      books
          .where((book) => request.allowsSource(book.sourceId))
          .map((book) => _SearchProjection(book, kinds, tokens))
          .where((projection) => tokens.isEmpty || projection.matches),
      request.sort,
    );
  }

  static List<BookSearchResult> _sortedProjections(
    Iterable<_SearchProjection> results,
    SearchSort sort,
  ) {
    final sorted = results.toList()
      ..sort((a, b) => _compareProjections(a, b, sort));
    return List.unmodifiable(sorted.map((projection) => projection.result));
  }

  static int _compareProjections(
    _SearchProjection a,
    _SearchProjection b,
    SearchSort sort,
  ) {
    final left = a.result;
    final right = b.result;
    final primary = switch (sort) {
      SearchSort.relevance => b.score.compareTo(a.score),
      SearchSort.rating => _compareNullableDouble(
        right.ratingValue,
        left.ratingValue,
      ).ifZero(_compareNullableInt(right.ratingCount, left.ratingCount)),
      SearchSort.year => _compareNullableInt(
        right.audioYear ?? right.year,
        left.audioYear ?? left.year,
      ),
      SearchSort.duration => _compareNullableDuration(
        right.duration,
        left.duration,
      ),
      SearchSort.title => a.normalizedTitle.compareTo(b.normalizedTitle),
    };
    if (primary != 0) return primary;
    final byTitle = a.normalizedTitle.compareTo(b.normalizedTitle);
    if (byTitle != 0) return byTitle;
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return left.sourceId
        .compareTo(right.sourceId)
        .ifZero(left.sourceBookId.compareTo(right.sourceBookId));
  }

  bool _applySettledSearchDetails(_CatalogSearchContinuation state) {
    var changed = false;
    state.pendingDetails.removeWhere((key, pending) {
      if (!pending.completed) return false;
      final result = state.results[key];
      final details = pending.details;
      if (result != null && details != null) {
        state.setResult(key, _mergeSearchDetails(result, details));
        changed = true;
      }
      return true;
    });
    return changed;
  }

  Future<void> _enrichSearchResults(
    _CatalogSearchContinuation state,
    SourceSearchCancellation cancellation, {
    Set<String>? sourceIds,
  }) async {
    _applySettledSearchDetails(state);
    final limit = _effectiveEnrichmentLimit(
      state.results.length,
      state.request.pageSize,
    );
    if (limit == 0 || cancellation.isCancelled) return;

    // Missing searchable fields take precedence over display-only updates.
    final candidates = <_SearchProjection>[];
    if (state.pendingDetails.length < limit) {
      for (final entry in state.results.entries) {
        if (state.sources[entry.value.sourceId]?.pausesAutomaticRequests ==
            true) {
          continue;
        }
        if (sourceIds != null && !sourceIds.contains(entry.value.sourceId)) {
          continue;
        }
        if (state.attemptedDetails.contains(entry.key)) continue;
        final candidate = state.project(entry.value);
        if ((candidate.matches || candidate.couldMatchWithDetails) &&
            _needsSearchEnrichment(candidate.result) &&
            _canEnrichSearchResult(candidate.result)) {
          candidates.add(candidate);
        }
      }
      candidates.sort((a, b) {
        if (a.matches != b.matches) return a.matches ? 1 : -1;
        return _compareProjections(a, b, SearchSort.relevance);
      });
    }
    for (final candidate in candidates) {
      if (state.pendingDetails.length >= limit) break;
      final result = candidate.result;
      final key = _searchResultKey(result);
      state.attemptedDetails.add(key);
      state.pendingDetails[key] = _PendingSearchDetails(
        _detailsForSearchResult(result),
      );
    }

    final pending = [
      for (final entry in state.pendingDetails.entries)
        if (sourceIds == null ||
            sourceIds.contains(state.results[entry.key]?.sourceId))
          entry.value.future,
    ];
    if (pending.isEmpty || _searchEnrichmentTimeout <= Duration.zero) {
      return;
    }
    try {
      await cancellation.wait(
        Future.wait<void>(pending).timeout(_searchEnrichmentTimeout),
      );
    } on TimeoutException {
      // Keep unfinished futures in this query's continuation. A successful
      // response arriving after this deadline can still produce a match.
    } on SourceSearchCancelled {
      // Do not cancel shared cache work used by a different consumer.
    }
    _applySettledSearchDetails(state);
  }

  bool _canEnrichSearchResult(BookSearchResult result) {
    try {
      return _registry
          .connectorById(result.sourceId)
          .capabilities
          .supportsDetails;
    } on SourceException {
      return false;
    }
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

    return loadBookDetails(result.ref).then<BookVersionDetails?>(
      (details) => details,
      onError: (Object _) => null,
    );
  }

  BookSearchResult _mergeSearchDetails(
    BookSearchResult result,
    BookVersionDetails details,
  ) {
    final version = details.version;
    final coverUri = _uriOrNull(version.coverUrl);
    final duration = _durationFromMs(version.durationMs);

    return BookSearchResult(
      ref: result.ref,
      sourceName: result.sourceName,
      title: _firstNonEmptyString([result.title, version.title]),
      author: _firstNonEmptyStringOrNull([
        result.author,
        version.authors.join(', '),
      ]),
      narrator: _firstNonEmptyStringOrNull([
        result.narrator,
        version.narrators.join(', '),
      ]),
      authors: result.author?.trim().isNotEmpty == true
          ? result.authors
          : version.authors,
      narrators: result.narrator?.trim().isNotEmpty == true
          ? result.narrators
          : version.narrators,
      series: _firstNonEmptyStringOrNull([result.series, version.seriesTitle]),
      seriesNumber: version.seriesNumber ?? result.seriesNumber,
      genres: List.unmodifiable({...result.genres, ...version.genres}),
      coverUri: coverUri ?? result.coverUri,
      duration: duration ?? result.duration,
      year: version.publishedYear ?? result.year,
      audioYear: version.audioYear ?? result.audioYear,
      chapterCount: result.chapterCount,
      isFull: version.isFull,
      isFragment: version.isFragment,
      isFree: version.isAccessibleForFree,
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
    SourceSearchCancellation? cancellation,
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
    if (tokens.isNotEmpty && cancellation?.isCancelled != true) {
      Future<SourceSearchResponse> searchTitle(String value) =>
          _registry.search(
            SearchRequest(
              query: value,
              kinds: const {SearchKind.title},
              pageSize: limit < 20 ? 20 : limit * 2,
            ),
            cancellation: cancellation,
          );
      final response = await searchTitle(query);
      var filtered = _filteredSortedResults(response.results, const {
        SearchKind.title,
      }, tokens);
      if (filtered.isEmpty &&
          tokens.length > 1 &&
          cancellation?.isCancelled != true) {
        final fallbackResponses = await Future.wait(
          tokens.toSet().take(3).map(searchTitle),
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

  /// Metadata can be rendered before chapter parsing or media resolution.
  Future<BookVersionDetails> loadBookDetails(SourceBookRef ref) =>
      _bookDetailsCache.getOrLoad(_detailsCacheKey(ref), () {
        return _registry.connectorById(ref.sourceId).getBookDetails(ref);
      });

  Future<List<Chapter>> _loadChapterDescriptors(SourceBookRef ref) =>
      _chapterDescriptorsCache.getOrLoad(_detailsCacheKey(ref), () async {
        final chapters = await _registry
            .connectorById(ref.sourceId)
            .getChapters(ref);
        return List.unmodifiable(chapters);
      });

  /// A browseable playlist: no connector media resolution takes place here.
  Future<SourceBookSnapshot> loadBookPreview(
    SourceBookRef ref, {
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) _invalidateBook(ref);
    final details = await loadBookDetails(ref);
    final chapters = await _loadChapterDescriptors(ref);
    return _snapshot(ref, details, chapters, [
      for (final chapter in chapters) _playbackChapter(chapter, null),
    ]);
  }

  /// Resolves the selected chapter, not the entire playlist. Retrying must not
  /// fall back to a different chapter simply because it took the same index.
  Future<AudioPlaybackChapter> resolvePlaybackChapter(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter, {
    bool forceRefresh = false,
    MediaResolvePurpose purpose = MediaResolvePurpose.playback,
  }) async {
    final existing = chapter.mediaSource;
    if (existing != null && existing.type != AudioMediaSourceType.url) {
      return chapter;
    }
    if (existing != null &&
        !forceRefresh &&
        purpose == MediaResolvePurpose.playback) {
      return chapter;
    }
    final sourceBookId = book.sourceBookId;
    if (sourceBookId == null || sourceBookId.isEmpty) {
      if (existing != null && !forceRefresh) return chapter;
      throw _chapterNotFound(book.sourceId);
    }
    final ref = SourceBookRef(
      sourceId: book.sourceId,
      sourceBookId: sourceBookId,
    );
    final connector = _registry.connectorById(ref.sourceId);
    final descriptors = await (forceRefresh
        ? _refreshChapterDescriptors(ref)
        : _loadChapterDescriptors(ref));
    final identity = chapter.storageIdentity;
    final mediaReference = chapter.storageMediaReference;
    final matches = descriptors.where((descriptor) {
      if (identity != null) return descriptor.storageIdentity == identity;
      if (descriptor.id != chapter.id) return false;
      return mediaReference == null ||
          _chapterMediaReference(descriptor) == mediaReference;
    }).iterator;
    // A new playlist must not silently substitute an item with the same ordinal.
    if (!matches.moveNext()) throw _chapterNotFound(book.sourceId);
    final descriptor = matches.current;
    if (matches.moveNext()) throw _chapterNotFound(book.sourceId);
    final resolved = await connector.resolveMedia(descriptor, purpose);
    return chapter.copyWith(mediaSource: resolved.mediaSource);
  }

  Future<List<Chapter>> _refreshChapterDescriptors(SourceBookRef ref) {
    final key = _detailsCacheKey(ref);
    final pending = _chapterDescriptorRefreshes[key];
    if (pending != null) return pending;
    _invalidateBook(ref);
    late final Future<List<Chapter>> refresh;
    refresh = _loadChapterDescriptors(ref).whenComplete(() {
      if (identical(_chapterDescriptorRefreshes[key], refresh)) {
        _chapterDescriptorRefreshes.remove(key);
      }
    });
    _chapterDescriptorRefreshes[key] = refresh;
    return refresh;
  }

  static SourceException _chapterNotFound(String sourceId) => SourceException(
    sourceId: sourceId,
    kind: SourceErrorKind.notFound,
    message: 'The requested source chapter could not be matched.',
  );

  Future<SourceBookSnapshot> loadBook(
    SourceBookRef ref, {
    bool forceRefresh = false,
    MediaResolvePurpose purpose = MediaResolvePurpose.playback,
  }) {
    if (!forceRefresh) return _loadBook(ref, purpose);
    final key = '${_detailsCacheKey(ref)}:${purpose.name}';
    final pending = _bookRefreshes[key];
    if (pending != null) return pending;
    _invalidateBook(ref);
    late final Future<SourceBookSnapshot> future;
    future = _loadBook(ref, purpose).whenComplete(() {
      if (identical(_bookRefreshes[key], future)) _bookRefreshes.remove(key);
    });
    _bookRefreshes[key] = future;
    return future;
  }

  void _invalidateBook(SourceBookRef ref) {
    final connector = _registry.connectorById(ref.sourceId);
    if (connector is SourceCacheInvalidator) {
      (connector as SourceCacheInvalidator).invalidateBook(ref);
    }
    _bookDetailsCache.remove(_detailsCacheKey(ref));
    _chapterDescriptorsCache.remove(_detailsCacheKey(ref));
  }

  /// Refreshes original remote media, not a local-file overlay. DownloadManager
  /// owns completed files/progress and reapplies that state by chapter identity.
  Future<AudioPlaybackBook> refreshBookForDownloads(AudioPlaybackBook book) =>
      _refreshBookMedia(book, MediaResolvePurpose.download);

  /// Called on a remote playback retry; callers keep pause/local-only playback
  /// offline and overlay existing local files after this explicit refresh.
  Future<AudioPlaybackBook> refreshBookForPlayback(AudioPlaybackBook book) =>
      _refreshBookMedia(book, MediaResolvePurpose.playback);

  Future<AudioPlaybackBook> _refreshBookMedia(
    AudioPlaybackBook book,
    MediaResolvePurpose purpose,
  ) async {
    final sourceBookId = book.sourceBookId;
    if (sourceBookId == null || sourceBookId.isEmpty) {
      throw SourceException(
        sourceId: book.sourceId,
        kind: SourceErrorKind.notFound,
        message: 'Source book reference is missing for media refresh.',
      );
    }
    return (await loadBook(
      SourceBookRef(sourceId: book.sourceId, sourceBookId: sourceBookId),
      forceRefresh: true,
      purpose: purpose,
    )).playbackBook;
  }

  Future<SourceBookSnapshot> _loadBook(
    SourceBookRef ref,
    MediaResolvePurpose purpose,
  ) async {
    final connector = _registry.connectorById(ref.sourceId);
    final details = await loadBookDetails(ref);
    final chapters = await _loadChapterDescriptors(ref);
    final playbackChapters = await Future.wait([
      for (final chapter in chapters)
        _resolvePlaybackChapter(connector, chapter, purpose),
    ]);

    return _snapshot(ref, details, chapters, playbackChapters);
  }

  SourceBookSnapshot _snapshot(
    SourceBookRef ref,
    BookVersionDetails details,
    List<Chapter> chapters,
    List<AudioPlaybackChapter> playbackChapters,
  ) {
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
    MediaResolvePurpose purpose,
  ) async {
    final resolved = await connector.resolveMedia(chapter, purpose);
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
      isFragment: result.isFragment,
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
      isFragment: version.isFragment,
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
      isFragment: version.isFragment,
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
    ResolvedMedia? resolved,
  ) {
    return AudioPlaybackChapter(
      id: chapter.id,
      index: chapter.index,
      title: chapter.title,
      duration: Duration(milliseconds: chapter.durationMs ?? 0),
      isDownloaded: chapter.downloadStatus == ChapterDownloadStatus.completed,
      storageIdentity: chapter.storageIdentity,
      storageMediaReference: _chapterMediaReference(chapter),
      mediaSource: resolved?.mediaSource,
    );
  }

  static String? _chapterMediaReference(Chapter chapter) =>
      SourceParserHelpers.mediaReferenceIdentity(
        chapter.streamRef ?? chapter.cachedStreamUrl,
      );

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
        result.ratingCount == null ||
        result.genres.isEmpty;
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
    if (kinds.length == 1 && kinds.contains(SearchKind.genre)) {
      return _haystacks(result, kinds).any(
        (field) => tokens.every((token) => _containsTokenPrefix(field, token)),
      );
    }
    final effectiveKinds = kinds.contains(SearchKind.all)
        ? const {
            SearchKind.title,
            SearchKind.author,
            SearchKind.narrator,
            SearchKind.series,
            SearchKind.genre,
          }
        : kinds;
    final text = _haystacks(
      result,
      effectiveKinds.difference({SearchKind.author, SearchKind.narrator}),
    ).expand(_queryTokens).toSet();
    final remaining = tokens
        .where((token) => !SourceSearchText.containsToken(text, token))
        .toList();
    if (remaining.isEmpty) return true;

    // One role may contain several people. Do not join unrelated first and
    // last names into a synthetic person, even in unrestricted mode. Multiple
    // complete names are accepted only when each contributes its own words.
    List<Set<String>> choices(Iterable<String> people) {
      final matches = [
        for (final person in people)
          {
            for (final token in remaining)
              if (_containsTokenPrefix(person, token)) token,
          },
      ].where((match) => match.isNotEmpty).toList();
      if (matches.isEmpty) return [const {}];
      final strongPeople = matches.where((match) => match.length > 1).toList();
      if (strongPeople.length > 1) {
        matches.add({for (final person in strongPeople) ...person});
      }
      return matches;
    }

    final authorChoices = choices(
      effectiveKinds.contains(SearchKind.author)
          ? _peopleFields(result.authors, result.author)
          : const [],
    );
    final narratorChoices = choices(
      effectiveKinds.contains(SearchKind.narrator)
          ? _peopleFields(result.narrators, result.narrator)
          : const [],
    );
    return authorChoices.any(
      (author) => narratorChoices.any(
        (narrator) => remaining.every(
          (token) => author.contains(token) || narrator.contains(token),
        ),
      ),
    );
  }

  static int _sortScore(
    BookSearchResult result,
    Set<SearchKind> kinds,
    List<String> tokens,
  ) {
    final haystacks = _haystacks(result, kinds);
    final joinedTokens = tokens.join(' ');
    var score = 0;
    for (final haystack in haystacks) {
      final words = _queryTokens(haystack);
      if (haystack == joinedTokens) score += 8;
      if (tokens.length > 1 &&
          tokens.every(
            (token) => SourceSearchText.containsToken(words, token),
          )) {
        score += 4;
      }
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

  static int _compareNullableInt(int? right, int? left) {
    if (right == null && left == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return right.compareTo(left);
  }

  static int _compareNullableDouble(double? right, double? left) {
    if (right == null && left == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return right.compareTo(left);
  }

  static int _compareNullableDuration(Duration? right, Duration? left) {
    return _compareNullableInt(right?.inMilliseconds, left?.inMilliseconds);
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
          fields.addAll(_peopleFields(result.authors, result.author));
          break;
        case SearchKind.narrator:
          fields.addAll(_peopleFields(result.narrators, result.narrator));
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
            ..._peopleFields(result.authors, result.author),
            ..._peopleFields(result.narrators, result.narrator),
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

  static Iterable<String> _peopleFields(List<String> people, String? display) =>
      people.isNotEmpty ? people : (display ?? '').split(RegExp(r'[,;\n]+'));

  static bool _containsTokenPrefix(String text, String token) {
    return SourceSearchText.containsToken(_queryTokens(text), token);
  }

  static List<String> _queryTokens(String text) =>
      SourceSearchText.tokens(text);

  static String _normalizeSearchText(String value) =>
      SourceSearchText.normalize(value);

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

typedef _PageSearchFailure = ({SourceFailure error, int page});

class _SearchLane {
  _SearchLane(this.query, this.nextPage, [Set<String>? seenPages, this.cursor])
    : seenPages = seenPages ?? <String>{};

  final String query;
  int? nextPage;
  SourceSearchPageCursor? cursor;
  final Set<String> seenPages;
  int? retryPage;
  _PageSearchFailure? failure;

  _SearchLane copy() => _SearchLane(query, nextPage, {...seenPages}, cursor)
    ..retryPage = retryPage
    ..failure = failure;
}

class _SourceSearchState {
  _SourceSearchState(
    this.connector,
    this.lanes, {
    this.plannedAlternatives = false,
    this.limited = false,
  });

  final SourceConnector connector;
  final List<_SearchLane> lanes;
  bool plannedAlternatives;
  bool limited;

  _PageSearchFailure? get _restriction {
    for (final lane in lanes) {
      final kind = lane.failure?.error.kind;
      if (kind == SourceErrorKind.accessRestricted ||
          kind == SourceErrorKind.rateLimited) {
        return lane.failure;
      }
    }
    return null;
  }

  bool get pausesAutomaticRequests => _restriction != null;

  bool canFetch({required bool retryOnly}) => retryOnly
      ? lanes.any((lane) => lane.retryPage != null)
      : !pausesAutomaticRequests && lanes.any((lane) => lane.nextPage != null);

  _PageSearchFailure? get failure {
    final restriction = _restriction;
    if (restriction != null) return restriction;
    for (final lane in lanes) {
      if (lane.failure != null) return lane.failure;
    }
    return null;
  }

  _SourceSearchState copy() => _SourceSearchState(
    connector,
    [for (final lane in lanes) lane.copy()],
    plannedAlternatives: plannedAlternatives,
    limited: limited,
  );
}

class _SearchProjection {
  _SearchProjection(this.result, this.kinds, this.tokens);

  final BookSearchResult result;
  final Set<SearchKind> kinds;
  final List<String> tokens;
  late final bool matches = SourceCatalogService._matchesRequest(
    result,
    kinds,
    tokens,
  );
  late final bool couldMatchWithDetails =
      SourceCatalogService._couldMatchWithDetails(result, kinds, tokens);
  late final String normalizedTitle = SourceCatalogService._normalizeSearchText(
    result.title,
  );
  late final int score = SourceCatalogService._sortScore(result, kinds, tokens);
}

class _PendingSearchDetails {
  _PendingSearchDetails(Future<BookVersionDetails?> load) {
    future = load
        .timeout(const Duration(seconds: 15), onTimeout: () => null)
        .then((value) {
          details = value;
          completed = true;
        });
  }

  late final Future<void> future;
  bool completed = false;
  BookVersionDetails? details;
}

class _CatalogSearchContinuation implements SourceSearchContinuation {
  _CatalogSearchContinuation({
    required this.owner,
    required this.request,
    required this.sources,
    Map<String, BookSearchResult>? results,
    Set<String>? attemptedDetails,
    Map<String, _PendingSearchDetails>? pendingDetails,
    Expando<_SearchProjection>? projections,
    this.retryFailuresOnly = false,
  }) : results = results ?? <String, BookSearchResult>{},
       attemptedDetails = attemptedDetails ?? <String>{},
       pendingDetails = pendingDetails ?? <String, _PendingSearchDetails>{},
       _projections = projections ?? Expando<_SearchProjection>();

  final SourceCatalogService owner;
  final SearchRequest request;
  final Map<String, _SourceSearchState> sources;
  final Map<String, BookSearchResult> results;
  final Set<String> attemptedDetails;
  final Map<String, _PendingSearchDetails> pendingDetails;
  final Expando<_SearchProjection> _projections;
  final bool retryFailuresOnly;
  final Set<String> incompleteMetadataSourceIds = {};
  bool metadataHasMore = false;
  List<BookSearchResult>? _sortedMatches;
  Map<String, int>? _matchCounts;
  late final Set<SearchKind> _kinds = request.effectiveKinds;
  late final List<String> _tokens = SourceCatalogService._queryTokens(
    request.query,
  ).toSet().toList();

  _SearchProjection project(BookSearchResult result) =>
      _projections[result] ??= _SearchProjection(result, _kinds, _tokens);

  List<BookSearchResult> get sortedMatches =>
      _sortedMatches ??= SourceCatalogService._sortedProjections(
        results.values.map(project).where((projection) => projection.matches),
        request.sort,
      );

  Map<String, int> get matchCounts {
    final previous = _matchCounts;
    if (previous != null) return previous;
    final counts = <String, int>{};
    for (final match in sortedMatches) {
      counts.update(match.sourceId, (count) => count + 1, ifAbsent: () => 1);
    }
    return _matchCounts = counts;
  }

  void setResult(String key, BookSearchResult result) {
    if (identical(results[key], result)) return;
    results[key] = result;
    _sortedMatches = null;
    _matchCounts = null;
  }

  bool get hasRetryableLane => sources.values.any(
    (source) => source.lanes.any((lane) => lane.retryPage != null),
  );

  bool get hasMore =>
      metadataHasMore ||
      sources.values.any((source) => source.canFetch(retryOnly: false));

  bool belongsTo(SourceCatalogService service, SearchRequest incoming) {
    bool sameSet<T>(Set<T> a, Set<T> b) =>
        a.length == b.length && a.containsAll(b);
    return identical(service, owner) &&
        request.query.trim() == incoming.query.trim() &&
        request.page == incoming.page &&
        request.pageSize == incoming.pageSize &&
        request.sort == incoming.sort &&
        sameSet(request.effectiveKinds, incoming.effectiveKinds) &&
        sameSet(request.sourceIds, incoming.sourceIds);
  }

  _CatalogSearchContinuation copy({required bool retryFailuresOnly}) =>
      _CatalogSearchContinuation(
          owner: owner,
          request: request,
          sources: {
            for (final entry in sources.entries) entry.key: entry.value.copy(),
          },
          results: {...results},
          attemptedDetails: {...attemptedDetails},
          pendingDetails: {...pendingDetails},
          projections: _projections,
          retryFailuresOnly: retryFailuresOnly,
        )
        .._sortedMatches = _sortedMatches
        .._matchCounts = _matchCounts
        ..incompleteMetadataSourceIds.addAll(incompleteMetadataSourceIds)
        ..metadataHasMore = metadataHasMore;
}

extension _CompareResult on int {
  int ifZero(int fallback) {
    return this == 0 ? fallback : this;
  }
}
