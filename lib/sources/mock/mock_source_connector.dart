import '../../data/mock/stage3_mock_data.dart';
import '../../domain/models/audio_book.dart';
import '../../domain/models/audio_track.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_version.dart';
import '../../domain/models/chapter.dart';
import '../../services/audio/audio_state.dart';
import '../source_connector.dart';
import '../source_models.dart';
import '../source_parser_helpers.dart';

class MockSourceConnector implements SourceConnector {
  MockSourceConnector({
    required this.id,
    required this.name,
    required this.host,
    required this.color,
    List<MockBook> books = stage3MockBooks,
    DateTime Function()? clock,
  }) : _books = List.unmodifiable(books.where((book) => book.sourceId == id)),
       _clock = clock ?? DateTime.now;

  factory MockSourceConnector.yakniga({DateTime Function()? clock}) {
    return MockSourceConnector(
      id: 'yakniga',
      name: 'Yakniga',
      host: 'mock.yakniga.local',
      color: '#2E7D63',
      clock: clock,
    );
  }

  static const stage4AssetPath = 'assets/audio/stage4_mock_chapter.wav';

  @override
  final String id;

  @override
  final String name;

  @override
  final String host;

  @override
  final String color;

  final List<MockBook> _books;
  final DateTime Function() _clock;

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsSearchByTitle: true,
    supportsSearchByAuthor: true,
    supportsSearchByNarrator: true,
    supportsDetails: true,
    supportsChapters: true,
    supportsSeries: true,
    supportsRating: true,
    supportsDescription: true,
    supportsDirectAudio: true,
    supportsDownload: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy(
    metadataHosts: {'mock.yakniga.local'},
    allowLocalMedia: true,
  );

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(
      sourceId: id,
      checkedAt: _clock(),
      message: 'Local mock source is available.',
    );
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final book = _bookByRef(ref);
    final now = _clock();

    return BookVersionDetails(
      ref: ref,
      book: Book(
        id: book.id,
        normalizedTitle: SourceParserHelpers.normalizeTitle(book.title),
        displayTitle: book.title,
        authors: [book.author],
        seriesTitle: book.series,
        year: book.year,
        bestDescription: book.description,
        createdAt: now,
        updatedAt: now,
      ),
      version: BookVersion(
        id: _versionId(book),
        bookId: book.id,
        sourceId: book.sourceId,
        sourceBookId: book.id,
        sourceUrl: 'mock://${book.sourceId}/${book.id}',
        title: book.title,
        normalizedTitle: SourceParserHelpers.normalizeTitle(book.title),
        authors: [book.author],
        narrators: [book.narrator],
        seriesTitle: book.series,
        genres: [book.genre],
        description: book.description,
        durationMs: SourceParserHelpers.parseDuration(
          book.durationLabel,
        )?.inMilliseconds,
        durationText: book.durationLabel,
        publishedYear: book.year,
        audioYear: book.audioYear,
        ratingValue: double.tryParse(book.ratingLabel.replaceAll(',', '.')),
        accessType: _accessType(book.access),
        playbackAccess: PlaybackAccess.streamAndDownload,
        isFull: true,
        isFragment: false,
        isPaid: book.access == BookAccess.paid,
        isSubscription: book.access == BookAccess.subscription,
        isAccessibleForFree: book.access == BookAccess.free,
        canStream: true,
        canDownload: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    final book = _bookByRef(ref);
    final now = _clock();

    return [
      for (final chapter in book.chapters)
        Chapter(
          id: _chapterId(book, chapter),
          bookVersionId: _versionId(book),
          sourceId: book.sourceId,
          sourceBookId: book.id,
          sourceChapterId: chapter.index.toString(),
          index: chapter.index,
          title: chapter.title,
          normalizedTitle: SourceParserHelpers.normalizeTitle(chapter.title),
          durationMs: SourceParserHelpers.parseDuration(
            chapter.durationLabel,
          )?.inMilliseconds,
          streamRef: 'asset:$stage4AssetPath',
          audioFormat: 'wav',
          mimeType: 'audio/wav',
          downloadStatus: chapter.isDownloaded
              ? ChapterDownloadStatus.completed
              : ChapterDownloadStatus.none,
          downloadProgress: chapter.isDownloaded ? 1 : 0,
          playbackPositionMs: 0,
          isFinished: chapter.progress >= 1,
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async {
    final chapters = await getChapters(ref);

    return [
      for (final chapter in chapters)
        AudioTrack(
          id: '${chapter.id}-track-1',
          chapterId: chapter.id,
          sourceId: id,
          index: 1,
          title: chapter.title,
          durationMs: chapter.durationMs,
          mediaRef: 'asset:$stage4AssetPath',
          format: 'wav',
          mimeType: 'audio/wav',
        ),
    ];
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

    return ResolvedMedia(
      sourceId: id,
      sourceBookId: chapter.sourceBookId,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.asset(stage4AssetPath),
      resolvedAt: _clock(),
      supportsRange: true,
    );
  }

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    final normalizedQuery = SourceParserHelpers.normalizeTitle(request.query);

    return [
      for (final book in _books)
        if (_matches(book, normalizedQuery, request.kind))
          BookSearchResult(
            ref: SourceBookRef(
              sourceId: book.sourceId,
              sourceBookId: book.id,
              sourceUri: Uri.parse('mock://${book.sourceId}/${book.id}'),
            ),
            sourceName: book.sourceName,
            title: book.title,
            author: book.author,
            narrator: book.narrator,
            duration: SourceParserHelpers.parseDuration(book.durationLabel),
            year: book.year,
            audioYear: book.audioYear,
            chapterCount: book.chapterCount,
            isFull: true,
            isFree: book.access == BookAccess.free,
            accessType: _accessType(book.access),
            score: book.progress,
          ),
    ];
  }

  MockBook _bookByRef(SourceBookRef ref) {
    if (ref.sourceId != id) {
      throw SourceException(
        sourceId: ref.sourceId,
        kind: SourceErrorKind.notFound,
        message: 'Source book ref belongs to another source.',
      );
    }

    for (final book in _books) {
      if (book.id == ref.sourceBookId) {
        return book;
      }
    }

    throw SourceException(
      sourceId: ref.sourceId,
      kind: SourceErrorKind.notFound,
      message: 'Mock book was not found.',
    );
  }

  bool _matches(MockBook book, String normalizedQuery, SearchKind kind) {
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final title = SourceParserHelpers.normalizeTitle(book.title);
    final author = SourceParserHelpers.normalizeTitle(book.author);
    final narrator = SourceParserHelpers.normalizeTitle(book.narrator);
    final series = SourceParserHelpers.normalizeTitle(book.series);

    return switch (kind) {
      SearchKind.title => title.contains(normalizedQuery),
      SearchKind.author => author.contains(normalizedQuery),
      SearchKind.narrator => narrator.contains(normalizedQuery),
      SearchKind.series => series.contains(normalizedQuery),
      SearchKind.all =>
        title.contains(normalizedQuery) ||
            author.contains(normalizedQuery) ||
            narrator.contains(normalizedQuery) ||
            series.contains(normalizedQuery),
    };
  }

  static String _versionId(MockBook book) {
    return '${book.id}-${book.sourceId}';
  }

  static String _chapterId(MockBook book, MockChapter chapter) {
    return '${book.id}-chapter-${chapter.index}';
  }

  static AccessType _accessType(BookAccess access) {
    return switch (access) {
      BookAccess.free => AccessType.free,
      BookAccess.paid => AccessType.paid,
      BookAccess.subscription => AccessType.subscription,
      BookAccess.unknown => AccessType.unknown,
    };
  }
}
