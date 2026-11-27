import 'dart:async';
import 'dart:io';

import '../../domain/models/audio_track.dart';
import '../../domain/models/chapter.dart';
import '../../services/audio/audio_state.dart';
import '../built_in_source_policies.dart';
import '../source_connector.dart';
import '../source_media_validator.dart';
import '../source_models.dart';
import '../source_html_parser.dart';
import '../source_request_cache.dart';
import '../source_search_text.dart';
import 'baza_knig_client.dart';
import 'baza_knig_mapper.dart';
import 'baza_knig_public_search.dart';
import 'baza_knig_smart_plan.dart';

class BazaKnigSourceConnector
    implements SourceConnector, PagedSourceConnector, SourceCacheInvalidator {
  BazaKnigSourceConnector({
    BazaKnigClient? client,
    BazaKnigMapper? mapper,
    DateTime Function()? clock,
  }) : _client = client ?? BazaKnigClient(),
       _useParserWorker = mapper == null,
       _mapper = mapper ?? BazaKnigMapper(clock: clock),
       _clock = clock ?? DateTime.now,
       _genreCache = SourceRequestCache(
         clock: clock,
         ttl: const Duration(minutes: 15),
         maxEntries: 1,
       ),
       _bookHtmlCache = SourceRequestCache(clock: clock);

  final BazaKnigClient _client;
  final BazaKnigMapper _mapper;
  final bool _useParserWorker;
  final DateTime Function() _clock;
  final SourceRequestCache<Uri, Map<String, Uri>> _genreCache;
  final SourceRequestCache<String, String> _bookHtmlCache;

  @override
  String get id => 'baza_knig';

  @override
  String get name => 'Baza Knig';

  @override
  String get host => 'https://baza-knig.top';

  @override
  String get color => '#8a6f28';

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
    supportsDescription: true,
    supportsDirectAudio: true,
    supportsDownload: true,
    requiresSpecialHeaders: true,
    hasTemporaryUrls: true,
    hasHtmlParser: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy => BuiltInSourcePolicies.byId(id)!;

  @override
  Future<SourceHealth> checkHealth() async {
    final started = _clock();
    try {
      await searchPage(const SearchRequest(query: 'метро'));
      return SourceHealth.working(
        sourceId: id,
        checkedAt: _clock(),
        responseTime: _clock().difference(started),
      );
    } on SourceException catch (error) {
      return SourceHealth(
        sourceId: id,
        status: switch (error.kind) {
          SourceErrorKind.parser => SourceHealthStatus.structureChanged,
          SourceErrorKind.rateLimited => SourceHealthStatus.rateLimited,
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
  Future<List<BookSearchResult>> search(SearchRequest request) async =>
      (await searchPage(request)).results;

  @override
  Future<SourceSearchPage> searchPage(SearchRequest request) async {
    final cursor = request.sourceCursor;
    if (cursor is _BazaPublicSearchCursor && cursor.matches(request)) {
      return _continuePublicSearch(request, cursor);
    }
    if (cursor != null) {
      throw const SourceException(
        sourceId: 'baza_knig',
        kind: SourceErrorKind.parser,
        message: 'Invalid Baza Knig search continuation.',
      );
    }
    if (request.page > 1) return _generalPage(request);

    final genres = BazaKnigSmartPlan.mayUseGenres(request)
        ? await _publicGenres()
        : const <String, Uri>{};
    final plans = BazaKnigSmartPlan.forRequest(request, genres: genres);
    if (request.effectiveKinds.length == 1) {
      final routes = plans.map(_publicRoute).nonNulls.toSet().toList();
      if (routes.isNotEmpty) {
        return _continuePublicSearch(
          request,
          _BazaPublicSearchCursor(
            request,
            routes,
            const {},
            coversScope: plans.every((plan) => plan.usedRequestedScope),
          ),
        );
      }
      return _generalPage(request);
    }
    return _startMixedSearch(request, plans, genres);
  }

  Future<SourceSearchPage> _generalPage(SearchRequest request) async {
    final html = await _client.searchBooksHtml(
      query: request.query,
      page: request.page,
    );
    return _useParserWorker
        ? SourceHtmlParser.searchPage(id, html, request)
        : SourceHtmlParser.parsedSearchPage(
            id,
            html,
            _mapper.searchResults(html),
            request.page,
            request.query,
          );
  }

  Future<Map<String, Uri>> _publicGenres() async {
    final root = _client.baseUri.resolve('/');
    try {
      return await _genreCache.getOrLoad(root, () async {
        final page = await _client.publicSearchHtml(root);
        return BazaKnigPublicSearch.parseGenres(page.html, page.uri);
      });
    } on SourceException catch (error) {
      // This optional menu is not a substitute for access restrictions.
      if (_siteRestriction(error)) rethrow;
      return const {};
    } on TimeoutException {
      return const {};
    } on SocketException {
      return const {};
    }
  }

  Uri? _publicRoute(BazaKnigSmartPlan plan) {
    final base = _client.baseUri;
    final catalogue = plan.catalogUri;
    if (catalogue != null) {
      return BazaKnigPublicSearch.isGenreCatalogue(base, catalogue)
          ? catalogue
          : null;
    }
    return BazaKnigPublicSearch.filterUri(base, plan.filters);
  }

  Future<BazaKnigPublicSearchPage> _publicPage(Uri uri) async {
    final page = await _client.publicSearchHtml(uri);
    return BazaKnigPublicSearch.parsePage(page.html, page.uri);
  }

  Future<SourceSearchPage> _startMixedSearch(
    SearchRequest request,
    List<BazaKnigSmartPlan> plans,
    Map<String, Uri> genres,
  ) async {
    final seenRoutes = <Uri>{};
    final nextRoutes = <Uri>[];
    final publicBooks = <String, BookSearchResult>{};
    var publicLimited = false;
    var publicSuccessful = false;
    Object? publicFailure;

    Future<void> tryPublic(BazaKnigSmartPlan plan) async {
      final uri = _publicRoute(plan);
      if (uri == null || !seenRoutes.add(uri)) return;
      try {
        final page = await _publicPage(uri);
        publicSuccessful = true;
        publicBooks.addEntries(
          page.results.map((book) => MapEntry(book.sourceBookId, book)),
        );
        if (page.next case final next?) nextRoutes.add(next);
        publicLimited |= page.limited;
      } on SourceException catch (error) {
        if (_siteRestriction(error)) rethrow;
        publicFailure ??= error;
      } on TimeoutException catch (error) {
        publicFailure ??= error;
      } on SocketException catch (error) {
        publicFailure ??= error;
      }
    }

    SourceSearchPage? general;
    Object? generalFailure;
    var restricted = false;
    var generalRestricted = false;
    try {
      // Independently scheduled lookups, not alternate endpoints for a blocked
      // general page. A bounded title seed lets mixed lines supply evidence
      // even when they do not match the whole-query form at all.
      for (final plan
          in plans.where((plan) => plan.catalogUri != null).take(1)) {
        await tryPublic(plan);
      }
      final longQuery = SourceSearchText.tokens(request.query).length >= 5;
      for (final probe
          in plans.where((plan) => plan.isTitleProbe).take(longQuery ? 2 : 1)) {
        final count = publicBooks.length;
        await tryPublic(probe);
        if (publicBooks.length > count) break;
      }
      if (request.effectiveKinds.length < 5) {
        final startedFields = <String>{};
        for (final plan in plans.where(_isEvidencedNativePlan)) {
          final uri = _publicRoute(plan);
          if (uri == null) continue;
          if (startedFields.length < 2 &&
              startedFields.add(plan.filters.keys.join(','))) {
            await tryPublic(plan);
          } else if (seenRoutes.add(uri)) {
            // Alternate spellings and the remaining selected fields are
            // normal, independently planned routes. Do not launch all of
            // them before publishing the first useful batch.
            nextRoutes.add(uri);
          }
        }
      }
      if (longQuery) {
        final evidenced = BazaKnigSmartPlan.forRequest(
          request,
          seeds: publicBooks.values,
          genres: genres,
        );
        for (final plan in evidenced.where(_isEvidencedNativePlan).take(1)) {
          await tryPublic(plan);
        }
      }
      try {
        general = await _generalPage(request);
      } on SourceException catch (error) {
        if (_siteRestriction(error)) {
          generalRestricted = true;
          rethrow;
        }
        generalFailure = error;
      } on SocketException catch (error) {
        generalFailure = error;
      } on TimeoutException catch (error) {
        generalFailure = error;
      }
      final seedPlans = BazaKnigSmartPlan.forRequest(
        request,
        seeds: [...publicBooks.values, ...?general?.results],
        genres: genres,
      );
      for (final plan
          in seedPlans
              .where(
                (plan) =>
                    _isEvidencedNativePlan(plan) &&
                    !seenRoutes.contains(_publicRoute(plan)),
              )
              .take(1)) {
        await tryPublic(plan);
      }
      if (publicBooks.isEmpty) {
        for (final plan
            in plans
                .where(
                  (plan) =>
                      plan.isTitleProbe &&
                      !seenRoutes.contains(_publicRoute(plan)),
                )
                .take(1)) {
          await tryPublic(plan);
        }
      }
    } on SourceException catch (error) {
      if (!_siteRestriction(error)) rethrow;
      if (error.kind == SourceErrorKind.rateLimited ||
          (publicBooks.isEmpty && (general?.results.isEmpty ?? true))) {
        rethrow;
      }
      // Keep previously obtained cards. A check does not trigger new lookups;
      // a public continuation already obtained before the generic restriction
      // remains a continuation of its own scope, never of the generic form.
      restricted = true;
      if (!generalRestricted) nextRoutes.clear();
      generalFailure ??= error;
    }
    if (nextRoutes.isEmpty &&
        (!publicSuccessful || (publicBooks.isEmpty && !restricted))) {
      if (general != null && !restricted) return general;
      if (generalFailure case final failure?) throw failure;
      if (publicFailure case final failure?) throw failure;
    }
    final results = <String, BookSearchResult>{
      for (final book in general?.results ?? const <BookSearchResult>[])
        book.sourceBookId: book,
      ...publicBooks,
    };
    final pending = nextRoutes.toSet().toList();
    final next = pending.isEmpty ? null : request.page + 1;
    return SourceSearchPage(
      results: results.values.toList(),
      nextPage: next,
      nextCursor: next == null
          ? null
          : _BazaPublicSearchCursor(
              request.copyWith(page: next),
              pending,
              results.keys.toSet(),
            ),
      // A distinct structured route never proves completion of free text.
      limited:
          publicLimited ||
          publicFailure != null ||
          generalFailure != null ||
          (general?.limited ?? false) ||
          general?.nextPage != null,
      handlesQueryVariants: true,
    );
  }

  static bool _isEvidencedNativePlan(BazaKnigSmartPlan plan) =>
      !plan.isTitleProbe && plan.catalogUri == null && plan.filters.isNotEmpty;

  Future<SourceSearchPage> _continuePublicSearch(
    SearchRequest request,
    _BazaPublicSearchCursor cursor,
  ) async {
    final routes = cursor.routes.toList();
    final page = await _publicPage(routes.removeAt(0));
    if (page.next case final next? when !routes.contains(next)) {
      routes.add(next);
    }
    final emitted = {...cursor.emitted};
    final results = page.results.where(
      (book) => emitted.add(book.sourceBookId),
    );
    final nextPage = routes.isEmpty ? null : request.page + 1;
    return SourceSearchPage(
      results: results.toList(),
      nextPage: nextPage,
      nextCursor: nextPage == null
          ? null
          : _BazaPublicSearchCursor(
              request.copyWith(page: nextPage),
              routes,
              emitted,
              coversScope: cursor.coversScope,
            ),
      limited: page.limited,
      usedRequestedScope: cursor.coversScope && !page.limited,
      handlesQueryVariants: true,
    );
  }

  static bool _siteRestriction(SourceException error) =>
      error.kind == SourceErrorKind.accessRestricted ||
      error.kind == SourceErrorKind.rateLimited;

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    _validateRef(ref);
    final html = await _bookHtml(ref);
    return _useParserWorker
        ? SourceHtmlParser.details(id, html, ref, _clock())
        : _mapper.bookDetails(html, ref);
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    _validateRef(ref);
    final html = await _bookHtml(ref);
    return _useParserWorker
        ? SourceHtmlParser.chapters(id, html, ref, _clock())
        : _mapper.chapters(html, ref);
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    final chapters = await getChapters(ref);
    return _mapper.audioTracks(chapters);
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
        sourceId: 'baza_knig',
        kind: SourceErrorKind.parser,
        message: 'Baza Knig chapter has no media URL.',
      );
    }

    final media = ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(
        uri,
        headers: BazaKnigClient.mediaHeaders(
          referer: BazaKnigMapper.sourceBaseUri
              .resolve(chapter.sourceBookId ?? '')
              .toString(),
        ),
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

  Future<String> _bookHtml(SourceBookRef ref) {
    return _bookHtmlCache.getOrLoad(
      ref.sourceBookId,
      () => _client.bookHtml(ref),
    );
  }

  @override
  void invalidateBook(SourceBookRef ref) {
    _bookHtmlCache.remove(ref.sourceBookId);
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
}

final class _BazaPublicSearchCursor implements SourceSearchPageCursor {
  _BazaPublicSearchCursor(
    SearchRequest request,
    Iterable<Uri> routes,
    Set<String> emitted, {
    this.coversScope = false,
  }) : query = request.query,
       kinds = request.effectiveKinds,
       page = request.page,
       routes = List.unmodifiable(routes),
       emitted = Set.unmodifiable(emitted);

  final String query;
  final Set<SearchKind> kinds;
  final int page;
  final List<Uri> routes;
  final Set<String> emitted;
  final bool coversScope;

  bool matches(SearchRequest request) =>
      query == request.query &&
      page == request.page &&
      routes.isNotEmpty &&
      kinds.length == request.effectiveKinds.length &&
      kinds.containsAll(request.effectiveKinds);
}
