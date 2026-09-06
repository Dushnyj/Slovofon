import '../../domain/models/audio_track.dart';
import '../../domain/models/chapter.dart';
import '../../services/audio/audio_state.dart';
import '../source_connector.dart';
import '../source_media_validator.dart';
import '../source_models.dart';
import '../source_request_cache.dart';
import 'yakniga_graphql_client.dart';
import 'yakniga_mapper.dart';

class YaknigaSourceConnector
    implements SourceConnector, SourceCacheInvalidator {
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
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy(
    metadataHosts: {'yakniga.org', 'www.yakniga.org'},
    mediaHosts: {'yakniga.org', 'www.yakniga.org'},
    coverHosts: {'yakniga.org', 'www.yakniga.org'},
  );

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
    // This endpoint exposes only an autocomplete collection, not remote pages.
    // Do not repeat a discarded API call for pages known to be unsupported.
    if (request.page > 1) {
      return const [];
    }
    final data = await _client.searchBooks(term: request.query);
    final items = data['search'];
    if (items is! List<Object?>) {
      return const [];
    }
    final pageSize = request.pageSize < 1 ? 20 : request.pageSize;
    return _mapper.searchResults(items).take(pageSize).toList();
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

class _YaknigaAliases {
  const _YaknigaAliases({this.aliasName, this.authorAliasName});

  final String? aliasName;
  final String? authorAliasName;
}
