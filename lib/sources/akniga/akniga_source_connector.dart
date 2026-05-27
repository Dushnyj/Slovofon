import '../../domain/models/audio_track.dart';
import '../../domain/models/chapter.dart';
import '../../services/audio/audio_state.dart';
import '../source_connector.dart';
import '../source_media_validator.dart';
import '../source_models.dart';
import 'akniga_client.dart';
import 'akniga_mapper.dart';

class AknigaSourceConnector implements SourceConnector {
  AknigaSourceConnector({
    AknigaClient? client,
    AknigaMapper? mapper,
    DateTime Function()? clock,
  }) : _client = client ?? AknigaClient(),
       _mapper = mapper ?? AknigaMapper(clock: clock),
       _clock = clock ?? DateTime.now;

  final AknigaClient _client;
  final AknigaMapper _mapper;
  final DateTime Function() _clock;
  final _bookHtmlCache = <String, Future<String>>{};
  final _tracksCache = <String, Future<List<Map<String, Object?>>>>{};

  @override
  String get id => 'akniga';

  @override
  String get name => 'Akniga';

  @override
  String get host => 'https://akniga.org';

  @override
  String get color => '#247a4d';

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
    supportsFragments: true,
    supportsPaidItems: true,
    requiresSpecialHeaders: true,
    hasTemporaryUrls: true,
    hasApiSignature: true,
    hasHtmlParser: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy(
    metadataHosts: {'akniga.org', 'www.akniga.org'},
    mediaHosts: {'akniga.org', 'akniga.club', 'audioknigi.xyz'},
    coverHosts: {'akniga.org', 'www.akniga.org'},
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
    final tracks = await _tracks(ref, html);
    return _mapper.chapters(html, ref, tracks);
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
        sourceId: 'akniga',
        kind: SourceErrorKind.parser,
        message: 'Akniga chapter has no media URL.',
      );
    }

    final referer = AknigaMapper.sourceBaseUri
        .resolve(chapter.sourceBookId ?? '')
        .toString();
    final media = ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(
        uri,
        headers: AknigaClient.mediaHeaders(referer: referer),
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
    return _bookHtmlCache.putIfAbsent(ref.sourceBookId, () {
      return _client.bookHtml(ref);
    });
  }

  Future<List<Map<String, Object?>>> _tracks(SourceBookRef ref, String html) {
    return _tracksCache.putIfAbsent(ref.sourceBookId, () async {
      final bid = _mapper.bookIdFromHtml(html);
      if (bid.isEmpty) {
        throw const SourceException(
          sourceId: 'akniga',
          kind: SourceErrorKind.parser,
          message: 'Akniga book has no ajax/bid id.',
        );
      }
      final referer =
          ref.sourceUri ?? AknigaMapper.sourceBaseUri.resolve(ref.sourceBookId);
      return _client.ajaxBidTracks(
        bookId: bid,
        referer: referer,
        securityKey: _securityKeyFromBookHtml(html),
      );
    });
  }

  String? _securityKeyFromBookHtml(String html) {
    try {
      return AknigaClient.extractSecurityKey(html);
    } on SourceException {
      return null;
    }
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
