import '../../domain/models/audio_track.dart';
import '../../domain/models/chapter.dart';
import '../../services/audio/audio_state.dart';
import '../built_in_source_policies.dart';
import '../source_connector.dart';
import '../source_media_validator.dart';
import '../source_models.dart';
import '../source_request_cache.dart';
import '../source_search_cancellation.dart';
import '../source_search_text.dart';
import 'yakniga_graphql_client.dart';
import 'yakniga_mapper.dart';

class YaknigaSourceConnector
    implements SourceConnector, PagedSourceConnector, SourceCacheInvalidator {
  YaknigaSourceConnector({
    YaknigaGraphQlClient? client,
    YaknigaMapper? mapper,
    DateTime Function()? clock,
  }) : _client = client ?? YaknigaGraphQlClient(),
       _mapper = mapper ?? YaknigaMapper(clock: clock),
       _clock = clock ?? DateTime.now,
       _bookCache = SourceRequestCache(clock: clock);

  final YaknigaGraphQlClient _client;
  final YaknigaMapper _mapper;
  final DateTime Function() _clock;
  final SourceRequestCache<String, Map<String, Object?>> _bookCache;
  static const _autocompleteBookLimit = 20;
  static const _maxScopesPerTerm = 3;

  @override
  String get id => 'yakniga';

  @override
  String get name => 'Yakniga';

  @override
  String get host => 'https://yakniga.org';

  @override
  String get color => '#1d8f7a';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsSearchByTitle: true,
    supportsSearchByAuthor: true,
    supportsSearchByNarrator: true,
    supportsSearchBySeries: true,
    supportsDetails: true,
    supportsChapters: true,
    supportsSeries: true,
    supportsRating: true,
    supportsDescription: true,
    supportsDirectAudio: true,
    supportsDownload: true,
    supportsPaidItems: true,
    requiresSpecialHeaders: true,
    hasGraphQlApi: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy => BuiltInSourcePolicies.byId(id)!;

  @override
  Future<SourceHealth> checkHealth() async {
    final started = _clock();
    try {
      await _client.searchBooks(term: 'метро');
      return SourceHealth.working(
        sourceId: id,
        checkedAt: _clock(),
        responseTime: _clock().difference(started),
      );
    } on SourceException catch (error) {
      return SourceHealth(
        sourceId: id,
        status: switch (error.kind) {
          SourceErrorKind.api => SourceHealthStatus.apiError,
          SourceErrorKind.parser => SourceHealthStatus.structureChanged,
          _ => SourceHealthStatus.unavailable,
        },
        checkedAt: _clock(),
        responseTime: _clock().difference(started),
        message: error.message,
      );
    } on Object catch (error) {
      return SourceHealth(
        sourceId: id,
        status: SourceHealthStatus.unavailable,
        checkedAt: _clock(),
        responseTime: _clock().difference(started),
        message: error.toString(),
      );
    }
  }

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    if (request.page > 1) return const [];
    final items = await _autocomplete(request.query);
    final pageSize = request.pageSize < 1 ? 20 : request.pageSize;
    return _mapper.searchResults(items).take(pageSize).toList();
  }

  @override
  Future<SourceSearchPage> searchPage(SearchRequest request) async {
    final cursor = request.sourceCursor;
    if (cursor is _YaknigaSearchCursor && cursor.query == request.query) {
      return _scopedPage(request, cursor.scopes);
    }
    if (request.page > 1) {
      return const SourceSearchPage(results: []);
    }
    final items = await _autocomplete(request.query);
    final general = _mapper.searchResults(items);
    final kinds = request.effectiveKinds;
    final strictScope =
        kinds.length == 1 &&
        !kinds.contains(SearchKind.title) &&
        !kinds.contains(SearchKind.all);
    final tokens = SourceSearchText.tokens(request.query).toSet();
    final eligible = <({bool exact, _YaknigaScope scope})>[];
    final seen = <(SearchKind, String)>{};
    if (tokens.isNotEmpty) {
      for (final item in items.whereType<Map<String, Object?>>()) {
        final kind = switch (item['__typename']) {
          'Author' => SearchKind.author,
          'Reader' => SearchKind.narrator,
          'Series' => SearchKind.series,
          'Genre' => SearchKind.genre,
          _ => null,
        };
        final alias = item['aliasName'];
        final name = item['name'];
        // A one-word general query can name a real catalogue (e.g. «Метро»).
        // Keep people scoped to multi-word or explicit searches; a short name
        // returned as a suggestion can easily refer to an unrelated person.
        if (kind == null ||
            !kinds.contains(kind) ||
            (!strictScope &&
                tokens.length == 1 &&
                kind != SearchKind.series &&
                kind != SearchKind.genre) ||
            alias is! String ||
            alias.isEmpty ||
            name is! String) {
          continue;
        }
        final words = SourceSearchText.tokens(name).toSet();
        final exact =
            words.length == tokens.length && words.containsAll(tokens);
        if ((exact ||
                (strictScope &&
                    tokens.every(
                      (token) => SourceSearchText.containsToken(words, token),
                    ))) &&
            seen.add((kind, alias))) {
          eligible.add((exact: exact, scope: _YaknigaScope(kind, alias, 1)));
        }
      }
    }
    eligible.sort((a, b) {
      if (a.exact != b.exact) return a.exact ? -1 : 1;
      final byAlias = a.scope.alias.compareTo(b.scope.alias);
      return byAlias == 0
          ? a.scope.kind.index.compareTo(b.scope.kind.index)
          : byAlias;
    });
    final selected = eligible.take(_maxScopesPerTerm).toList();
    final scoped = selected.isEmpty
        ? null
        : await _scopedPage(
            request,
            selected.map((entry) => entry.scope).toList(),
          );
    final coversRequestedScope =
        strictScope &&
        selected.any((entry) => entry.exact) &&
        eligible.length == selected.length &&
        scoped?.limited == false;
    final resultsById = <String, BookSearchResult>{
      // Both endpoints use the same fields; prefer scoped identity/metadata.
      for (final book in general) book.sourceBookId: book,
      for (final book in scoped?.results ?? const <BookSearchResult>[])
        book.sourceBookId: book,
    };
    return SourceSearchPage(
      results: resultsById.values.toList(),
      nextPage: scoped?.nextPage,
      nextCursor: scoped?.nextCursor,
      limited:
          eligible.length > selected.length ||
          (scoped?.limited ?? false) ||
          (general.length >= _autocompleteBookLimit && !coversRequestedScope),
      usedRequestedScope: coversRequestedScope,
    );
  }

  Future<List<Object?>> _autocomplete(String query) async {
    final data = await _client.searchBooks(term: query);
    final items = data['search'];
    if (items is! List<Object?>) {
      throw const SourceException(
        sourceId: 'yakniga',
        kind: SourceErrorKind.parser,
        message: 'Yakniga autocomplete response is missing its item list.',
      );
    }
    return items;
  }

  Future<SourceSearchPage> _scopedPage(
    SearchRequest request,
    List<_YaknigaScope> scopes,
  ) async {
    final pageSize = (request.pageSize < 1 ? 20 : request.pageSize).clamp(
      1,
      20,
    );
    final slices = await Future.wait([
      for (final scope in scopes) _fetchScope(scope, pageSize),
    ]);
    final nextScopes = [for (final slice in slices) ?slice.next];
    return SourceSearchPage(
      results: [for (final slice in slices) ...slice.results],
      nextPage: nextScopes.isEmpty ? null : request.page + 1,
      nextCursor: nextScopes.isEmpty
          ? null
          : _YaknigaSearchCursor(request.query, List.unmodifiable(nextScopes)),
      limited: slices.any((slice) => slice.limited),
    );
  }

  Future<_YaknigaScopeSlice> _fetchScope(_YaknigaScope scope, int size) async {
    try {
      final data = await _client.scopedBooks(
        kind: scope.kind,
        alias: scope.alias,
        page: scope.page,
        pageSize: size,
      );
      final entity = data['entity'];
      final books = entity is Map<String, Object?> ? entity['books'] : null;
      final items = books is Map<String, Object?> ? books['collection'] : null;
      final metadata = books is Map<String, Object?> ? books['metadata'] : null;
      if (items is! List<Object?> ||
          metadata is! Map<String, Object?> ||
          metadata['currentPage'] != scope.page) {
        return const _YaknigaScopeSlice(limited: true);
      }
      final next = metadata['nextPage'];
      final invalidNext = next != null && (next is! int || next <= scope.page);
      return _YaknigaScopeSlice(
        results: _mapper.searchResults(items),
        next: next is int && !invalidNext
            ? _YaknigaScope(scope.kind, scope.alias, next)
            : null,
        limited: invalidNext,
      );
    } on SourceSearchCancelled {
      rethrow;
    } on SourceException {
      // Keep usable autocomplete results if an optional entity page fails.
      return const _YaknigaScopeSlice(limited: true);
    }
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final book = await _fetchBook(ref);
    return _mapper.bookDetails(book);
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    final book = await _fetchBook(ref);
    return _mapper.chapters(book);
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    final book = await _fetchBook(ref);
    return _mapper.audioTracks(book);
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async {
    if (chapter.sourceId != id) {
      throw SourceException(
        sourceId: id,
        kind: SourceErrorKind.notFound,
        message: 'Chapter belongs to another source.',
      );
    }

    final streamRef = chapter.streamRef ?? chapter.cachedStreamUrl;
    final uri = Uri.tryParse(streamRef ?? '');
    if (uri == null) {
      throw const SourceException(
        sourceId: 'yakniga',
        kind: SourceErrorKind.parser,
        message: 'Yakniga chapter has no media URL.',
      );
    }

    final media = ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(
        uri,
        headers: YaknigaMapper.mediaHeadersForChapter(chapter),
      ),
      originalUri: uri,
      resolvedAt: _clock(),
      supportsRange: true,
    );

    return SourceMediaValidator.validateResolvedMedia(
      mediaPolicy,
      media,
      purpose,
    );
  }

  Future<Map<String, Object?>> _fetchBook(SourceBookRef ref) {
    _validateRef(ref);
    final cacheKey = [
      ref.sourceBookId,
      ref.sourceUri?.toString() ?? '',
    ].join('|');
    return _bookCache.getOrLoad(cacheKey, () async {
      final aliases = _aliasesFromUri(ref.sourceUri);
      final id = RegExp(r'^\d+$').hasMatch(ref.sourceBookId)
          ? ref.sourceBookId
          : null;
      final data = await _client.book(
        id: id,
        aliasName: aliases.aliasName ?? (id == null ? ref.sourceBookId : null),
        authorAliasName: aliases.authorAliasName,
      );
      final book = data['book'];
      if (book is! Map<String, Object?>) {
        throw SourceException(
          sourceId: this.id,
          kind: SourceErrorKind.notFound,
          message: 'Yakniga book was not found.',
        );
      }
      return book;
    });
  }

  @override
  void invalidateBook(SourceBookRef ref) {
    _bookCache.removeWhere((key) => key.startsWith('${ref.sourceBookId}|'));
  }

  void _validateRef(SourceBookRef ref) {
    if (ref.sourceId != id) {
      throw SourceException(
        sourceId: ref.sourceId,
        kind: SourceErrorKind.notFound,
        message: 'Source book ref belongs to another source.',
      );
    }
  }

  static _YaknigaAliases _aliasesFromUri(Uri? uri) {
    if (uri == null) {
      return const _YaknigaAliases();
    }
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.trim().isNotEmpty) segment.trim(),
    ];
    if (segments.length >= 2) {
      return _YaknigaAliases(
        authorAliasName: segments[segments.length - 2],
        aliasName: segments.last,
      );
    }
    if (segments.length == 1) {
      return _YaknigaAliases(aliasName: segments.single);
    }
    return const _YaknigaAliases();
  }
}

class _YaknigaScope {
  const _YaknigaScope(this.kind, this.alias, this.page);

  final SearchKind kind;
  final String alias;
  final int page;
}

class _YaknigaSearchCursor implements SourceSearchPageCursor {
  const _YaknigaSearchCursor(this.query, this.scopes);

  final String query;
  final List<_YaknigaScope> scopes;
}

class _YaknigaScopeSlice {
  const _YaknigaScopeSlice({
    this.results = const [],
    this.next,
    this.limited = false,
  });

  final List<BookSearchResult> results;
  final _YaknigaScope? next;
  final bool limited;
}

class _YaknigaAliases {
  const _YaknigaAliases({this.aliasName, this.authorAliasName});

  final String? aliasName;
  final String? authorAliasName;
}
