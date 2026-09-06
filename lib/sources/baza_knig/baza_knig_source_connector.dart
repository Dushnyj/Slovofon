import '../../domain/models/audio_track.dart';
import '../../domain/models/chapter.dart';
import '../../services/audio/audio_state.dart';
import '../source_connector.dart';
import '../source_media_validator.dart';
import '../source_models.dart';
import '../source_request_cache.dart';
import 'baza_knig_client.dart';
import 'baza_knig_mapper.dart';

class BazaKnigSourceConnector
    implements SourceConnector, SourceCacheInvalidator {
  BazaKnigSourceConnector({
    BazaKnigClient? client,
    BazaKnigMapper? mapper,
    DateTime Function()? clock,
  }) : _client = client ?? BazaKnigClient(),
       _mapper = mapper ?? BazaKnigMapper(clock: clock),
       _clock = clock ?? DateTime.now,
       _bookHtmlCache = SourceRequestCache(clock: clock);

  final BazaKnigClient _client;
  final BazaKnigMapper _mapper;
  final DateTime Function() _clock;
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
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy(
    metadataHosts: {'baza-knig.top', 'www.baza-knig.top'},
    mediaHosts: {'abooka.casa', 'archive.org'},
    coverHosts: {'baza-knig.top', 'www.baza-knig.top'},
  );

  @override
  Future<SourceHealth> checkHealth() async {
    final started = _clock();
    try {
      await _client.searchBooksHtml(query: 'метро', page: 1);
      return SourceHealth.working(
        sourceId: id,
        checkedAt: _clock(),
        responseTime: _clock().difference(started),
      );
    } on SourceException catch (error) {
      return SourceHealth(
        sourceId: id,
        status: error.kind == SourceErrorKind.parser
            ? SourceHealthStatus.structureChanged
            : SourceHealthStatus.unavailable,
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
    final html = await _client.searchBooksHtml(
      query: request.query,
      page: request.page,
    );
    return _mapper.searchResults(html);
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    _validateRef(ref);
    final html = await _bookHtml(ref);
    return _mapper.bookDetails(html, ref);
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    _validateRef(ref);
    final html = await _bookHtml(ref);
    return _mapper.chapters(html, ref);
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
