import '../../domain/models/audio_track.dart';
import '../../domain/models/chapter.dart';
import '../../services/audio/audio_state.dart';
import '../source_connector.dart';
import '../source_media_validator.dart';
import '../source_models.dart';
import 'knigavuhe_client.dart';
import 'knigavuhe_mapper.dart';

class KnigavuheSourceConnector implements SourceConnector {
  KnigavuheSourceConnector({
    KnigavuheClient? client,
    KnigavuheMapper? mapper,
    DateTime Function()? clock,
  }) : _client = client ?? KnigavuheClient(),
       _mapper = mapper ?? KnigavuheMapper(clock: clock),
       _clock = clock ?? DateTime.now;

  final KnigavuheClient _client;
  final KnigavuheMapper _mapper;
  final DateTime Function() _clock;
  final _bookHtmlCache = <String, Future<String>>{};

  @override
  String get id => 'knigavuhe';

  @override
  String get name => 'Knigavuhe';

  @override
  String get host => 'https://knigavuhe.org';

  @override
  String get color => '#2f7f86';

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
    hasTemporaryUrls: false,
    hasHtmlParser: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy(
    metadataHosts: {'knigavuhe.org', 'www.knigavuhe.org'},
    mediaHosts: {'knigavuhe.org', 'www.knigavuhe.org', 'litres.ru'},
    coverHosts: {'knigavuhe.org', 'www.knigavuhe.org'},
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
        sourceId: 'knigavuhe',
        kind: SourceErrorKind.parser,
        message: 'Knigavuhe chapter has no media URL.',
      );
    }

    final media = ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(
        uri,
        headers: KnigavuheClient.mediaHeaders(
          referer: KnigavuheMapper.refererForSourceBookId(
            chapter.sourceBookId ?? '',
          ),
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
    final cached = _bookHtmlCache[ref.sourceBookId];
    if (cached != null) {
      return cached;
    }
    late final Future<String> future;
    future = _client.bookHtml(ref).catchError((Object error) {
      _bookHtmlCache.remove(ref.sourceBookId);
      throw error;
    });
    _bookHtmlCache[ref.sourceBookId] = future;
    return future;
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
