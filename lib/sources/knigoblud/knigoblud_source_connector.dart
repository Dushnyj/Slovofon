import '../../domain/models/audio_track.dart';
import '../../domain/models/chapter.dart';
import '../../services/audio/audio_state.dart';
import '../source_connector.dart';
import '../source_media_validator.dart';
import '../source_models.dart';
import '../source_html_parser.dart';
import '../source_request_cache.dart';
import 'knigoblud_client.dart';
import 'knigoblud_mapper.dart';

class KnigobludSourceConnector
    implements SourceConnector, SourceCacheInvalidator {
  KnigobludSourceConnector({
    KnigobludClient? client,
    KnigobludMapper? mapper,
    DateTime Function()? clock,
  }) : _client = client ?? KnigobludClient(),
       _useParserWorker = mapper == null,
       _mapper = mapper ?? KnigobludMapper(clock: clock),
       _clock = clock ?? DateTime.now,
       _bookHtmlCache = SourceRequestCache(clock: clock);

  final KnigobludClient _client;
  final KnigobludMapper _mapper;
  final bool _useParserWorker;
  final DateTime Function() _clock;
  final SourceRequestCache<String, String> _bookHtmlCache;

  @override
  String get id => 'knigoblud';

  @override
  String get name => 'Knigoblud';

  @override
  String get host => 'https://www.knigoblud.club';

  @override
  String get color => '#5f7c2d';

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
    supportsFragments: true,
    supportsPaidItems: true,
    requiresSpecialHeaders: true,
    hasTemporaryUrls: false,
    hasHtmlParser: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy(
    metadataHosts: {'knigoblud.club', 'www.knigoblud.club'},
    mediaHosts: {'audioknigi.xyz', 'litres.ru'},
    coverHosts: {'knigoblud.club', 'www.knigoblud.club', 'audioknigi.xyz'},
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
    return _useParserWorker
        ? SourceHtmlParser.search(id, html)
        : _mapper.searchResults(html);
  }

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
        sourceId: 'knigoblud',
        kind: SourceErrorKind.parser,
        message: 'Knigoblud chapter has no media URL.',
      );
    }

    final media = ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(
        uri,
        headers: KnigobludClient.mediaHeaders(
          referer: KnigobludMapper.sourceBaseUri
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
