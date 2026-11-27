import 'dart:io';

import '../../sources/sources.dart';
import '../audio/audio_state.dart';
import '../downloads/download_storage.dart';
import '../sources/source_catalog_service.dart';

class DownloadedSearchResponse extends SourceSearchResponse {
  const DownloadedSearchResponse({required super.results, required this.books});

  /// Each key identifies an exact downloaded edition, not just the work.
  final Map<(String, String), AudioPlaybackBook> books;

  AudioPlaybackBook? bookFor(BookSearchResult result) =>
      books[(result.sourceId, result.sourceBookId)];
}

/// A source-independent query over locally available complete editions.
class DownloadedCatalogSearch {
  const DownloadedCatalogSearch(this.storage);

  final FileDownloadStorage storage;
  static const _filesPerBatch = 4;

  Future<DownloadedSearchResponse> search(
    SearchRequest request, {
    SourceSearchCancellation? cancellation,
  }) async {
    final searchBooks = {
      for (final book in await storage.readDownloadedMetadata())
        if (book.chapters.isNotEmpty) (book.sourceId, book.versionId): book,
    };
    cancellation?.throwIfCancelled();
    final ranked = SourceCatalogService.searchMetadata(
      searchBooks.values.map(_metadataResult),
      request,
    );
    final available = <BookSearchResult>[];
    final books = <(String, String), AudioPlaybackBook>{};
    for (var offset = 0; offset < ranked.length; offset += _filesPerBatch) {
      cancellation?.throwIfCancelled();
      final found = await Future.wait([
        for (final result in ranked.skip(offset).take(_filesPerBatch))
          _verifiedResult(searchBooks[(result.sourceId, result.sourceBookId)]!),
      ]);
      for (final candidate in found.nonNulls) {
        available.add(candidate.result);
        final book = candidate.book;
        books[(book.sourceId, book.versionId)] = book;
      }
    }
    cancellation?.throwIfCancelled();
    return DownloadedSearchResponse(
      results: List.unmodifiable(available),
      books: Map.unmodifiable(books),
    );
  }

  Future<({AudioPlaybackBook book, BookSearchResult result})?> _verifiedResult(
    AudioPlaybackBook book,
  ) async {
    try {
      final files = await storage.completedChapterFiles(book);
      if (!_allChaptersAvailable(book, files)) return null;
      return (
        book: book,
        result: _metadataResult(book, coverUri: await _localCover(book)),
      );
    } on FileSystemException {
      // Storage can change while a query is in flight. Ignore that edition.
      return null;
    }
  }

  /// Revalidate immediately before playback; never substitute a remote source.
  Future<AudioPlaybackBook?> playableBook(AudioPlaybackBook book) async {
    final files = await storage.completedChapterFiles(book);
    if (!_allChaptersAvailable(book, files)) return null;
    final cover = await _localCover(book);
    return book.copyWith(
      offlineOnly: true,
      coverUrl: cover?.toString(),
      clearCoverUrl: cover == null,
      chapters: List.unmodifiable([
        for (final chapter in book.chapters)
          chapter.copyWith(
            isDownloaded: true,
            mediaSource: AudioMediaSource.file(files[chapter.index]!.path),
          ),
      ]),
    );
  }

  Future<Uri?> _localCover(AudioPlaybackBook book) async {
    final cover = storage.coverFileFor(book);
    final type = await FileSystemEntity.type(cover.path, followLinks: false);
    return type == FileSystemEntityType.file ? cover.uri : null;
  }

  static bool _allChaptersAvailable(
    AudioPlaybackBook book,
    Map<int, File> files,
  ) =>
      book.chapters.isNotEmpty &&
      files.length == book.chapters.length &&
      book.chapters.every((chapter) => files.containsKey(chapter.index));

  static BookSearchResult _metadataResult(
    AudioPlaybackBook book, {
    Uri? coverUri,
  }) => BookSearchResult(
    ref: SourceBookRef(sourceId: book.sourceId, sourceBookId: book.versionId),
    sourceName: book.sourceName,
    title: book.title,
    author: book.author,
    narrator: book.narrator,
    series: book.seriesTitle,
    seriesNumber: book.seriesNumber,
    genres: [if (book.genre?.trim().isNotEmpty == true) book.genre!],
    coverUri: coverUri,
    duration: book.totalDuration,
    year: book.publishedYear,
    chapterCount: book.chapters.length,
    isFragment: book.isFragment,
    isFull: !book.isFragment,
    ratingValue: book.ratingValue,
    ratingCount: book.ratingCount,
  );
}
