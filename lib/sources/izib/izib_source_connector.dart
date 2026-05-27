import '../../domain/models/audio_track.dart';
import '../../domain/models/chapter.dart';
import '../../services/audio/audio_state.dart';
import '../source_connector.dart';
import '../source_media_validator.dart';
import '../source_models.dart';
import 'izib_graphql_client.dart';
import 'izib_mapper.dart';

class IzibSourceConnector implements SourceConnector {
  IzibSourceConnector({
    IzibGraphQlClient? client,
    IzibMapper? mapper,
    DateTime Function()? clock,
  }) : _client = client ?? IzibGraphQlClient(),
       _clock = clock ?? DateTime.now,
       _mapper = mapper ?? IzibMapper(clock: clock);

  final IzibGraphQlClient _client;
  final IzibMapper _mapper;
  final DateTime Function() _clock;

  @override
  String get id => 'izib';

  @override
  String get name => 'Izib';

  @override
  String get host => 'https://izib.uk';

  @override
  String get color => '#7d5a9d';

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
    requiresSpecialHeaders: true,
    hasTemporaryUrls: true,
    hasApiSignature: true,
    hasGraphQlApi: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy(
    metadataHosts: {'izib.uk', 'api.izib.uk'},
    mediaHosts: {'izib.uk', 'audioknigi.xyz'},
    coverHosts: {'izib.uk'},
  );

  @override
  Future<SourceHealth> checkHealth() async {
    final started = _clock();
    try {
      await _client.searchBooks(query: 'метро', offset: 0, count: 1);
      return SourceHealth.working(
        sourceId: id,
        checkedAt: _clock(),
        responseTime: _clock().difference(started),
      );
    } on SourceException catch (error) {
      return SourceHealth(
        sourceId: id,
        status: error.kind == SourceErrorKind.api
            ? SourceHealthStatus.apiError
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
    final page = request.page < 1 ? 1 : request.page;
    final pageSize = request.pageSize < 1 ? 20 : request.pageSize;
    final data = await _client.searchBooks(
      query: request.query,
      offset: (page - 1) * pageSize,
      count: pageSize,
    );
    final collection = data['booksSearch'];
    if (collection is! Map<String, Object?>) {
      throw const SourceException(
        sourceId: 'izib',
        kind: SourceErrorKind.parser,
        message: 'Izib search response is missing booksSearch.',
      );
    }
    final items = collection['items'];
    if (items is! List<Object?>) {
      return const [];
    }

    return _mapper.searchResults(items);
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
        sourceId: 'izib',
        kind: SourceErrorKind.parser,
        message: 'Izib chapter has no media URL.',
      );
    }

    final media = ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(uri),
      originalUri: uri,
      resolvedAt: _clock(),
      requiresProxy: capabilities.requiresMediaProxy,
      supportsRange: true,
    );

    return SourceMediaValidator.validateResolvedMedia(
      mediaPolicy,
      media,
      purpose,
    );
  }

  Future<Map<String, Object?>> _fetchBook(SourceBookRef ref) async {
    if (ref.sourceId != id) {
      throw SourceException(
        sourceId: ref.sourceId,
        kind: SourceErrorKind.notFound,
        message: 'Source book ref belongs to another source.',
      );
    }

    final bookId =
        int.tryParse(ref.sourceBookId) ?? _extractBookId(ref.sourceUri);
    if (bookId == null) {
      throw SourceException(
        sourceId: id,
        kind: SourceErrorKind.notFound,
        message: 'Izib book id was not found.',
      );
    }

    final data = await _client.book(id: bookId);
    final book = data['book'];
    if (book is! Map<String, Object?>) {
      throw SourceException(
        sourceId: id,
        kind: SourceErrorKind.notFound,
        message: 'Izib book was not found.',
      );
    }

    return book;
  }

  static int? _extractBookId(Uri? uri) {
    if (uri == null) {
      return null;
    }

    final match = RegExp(r'/art(\d+)(?:\D|$)').firstMatch(uri.path);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
