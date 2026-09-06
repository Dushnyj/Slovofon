import '../../domain/models/audio_book.dart';
import '../audio/audio_state.dart';
import '../downloads/download_manager.dart';
import '../downloads/download_storage.dart';
import '../library/library_store.dart';
import 'source_catalog_service.dart';
import 'source_cover_client.dart';

typedef CoverBytesLoader = Future<List<int>?> Function(Uri uri);

class SourceBookCache {
  const SourceBookCache({
    required this.downloadStorage,
    required this.downloadManager,
    required this.libraryStore,
    this.coverBytesLoader = _loadCoverBytes,
  });

  final FileDownloadStorage downloadStorage;
  final DownloadManager downloadManager;
  final LibraryStore libraryStore;
  final CoverBytesLoader coverBytesLoader;

  Future<SourceBookSnapshot> refresh(SourceBookSnapshot snapshot) async {
    final cached = await _snapshotWithCachedCover(snapshot);
    await downloadStorage.writeMetadata(cached.playbackBook);
    await downloadManager.cacheBookMetadata(cached.playbackBook);
    await libraryStore.refreshFavoriteMetadata(cached.audioBook);
    return SourceBookSnapshot(
      details: snapshot.details,
      chapters: snapshot.chapters,
      audioBook: cached.audioBook,
      playbackBook: cached.playbackBook,
    );
  }

  Future<_CachedBookSnapshot> _snapshotWithCachedCover(
    SourceBookSnapshot snapshot,
  ) async {
    final coverUrl =
        snapshot.playbackBook.coverUrl ?? snapshot.audioBook.coverUrl;
    final coverUri = coverUrl == null ? null : Uri.tryParse(coverUrl);
    if (coverUri == null ||
        (coverUri.scheme != 'http' && coverUri.scheme != 'https')) {
      return _CachedBookSnapshot(
        audioBook: snapshot.audioBook,
        playbackBook: snapshot.playbackBook,
      );
    }

    final bytes = await coverBytesLoader(coverUri);
    if (bytes == null || bytes.isEmpty) {
      return _CachedBookSnapshot(
        audioBook: snapshot.audioBook,
        playbackBook: snapshot.playbackBook,
      );
    }

    final localCoverUrl = await downloadStorage.writeCoverBytes(
      snapshot.playbackBook,
      bytes,
    );
    return _CachedBookSnapshot(
      audioBook: snapshot.audioBook.copyWith(coverUrl: localCoverUrl),
      playbackBook: _copyPlaybackBook(
        snapshot.playbackBook,
        coverUrl: localCoverUrl,
      ),
    );
  }
}

class _CachedBookSnapshot {
  const _CachedBookSnapshot({
    required this.audioBook,
    required this.playbackBook,
  });

  final AudioBook audioBook;
  final AudioPlaybackBook playbackBook;
}

AudioPlaybackBook _copyPlaybackBook(
  AudioPlaybackBook book, {
  required String coverUrl,
}) {
  return AudioPlaybackBook(
    id: book.id,
    versionId: book.versionId,
    sourceId: book.sourceId,
    sourceBookId: book.sourceBookId,
    title: book.title,
    isFragment: book.isFragment,
    author: book.author,
    narrator: book.narrator,
    sourceName: book.sourceName,
    coverUrl: coverUrl,
    description: book.description,
    genre: book.genre,
    seriesTitle: book.seriesTitle,
    seriesNumber: book.seriesNumber,
    ratingValue: book.ratingValue,
    ratingCount: book.ratingCount,
    publishedYear: book.publishedYear,
    sourceUrl: book.sourceUrl,
    chapters: book.chapters,
  );
}

Future<List<int>?> _loadCoverBytes(Uri uri) =>
    const SourceCoverClient().load(uri);
