import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/audio_book.dart';
import '../audio/audio_persistence.dart';
import '../audio/audio_state.dart';
import '../audio/playback_controller_provider.dart';
import '../downloads/download_manager_provider.dart';

abstract interface class LibraryMetadataPersistence {
  Future<void> savePlaybackBook(AudioPlaybackBook book);
  Future<List<AudioPlaybackBook>> loadPlaybackBooks();
}

final libraryMetadataPersistenceProvider =
    Provider<LibraryMetadataPersistence?>((ref) => null);

/// Cached metadata alone is not a library membership. The shelf projection
/// below only includes books referenced by progress, downloads, Later or marks.
final libraryPlaybackBooksProvider = FutureProvider<List<AudioPlaybackBook>>((
  ref,
) async {
  ref.watch(
    playbackProgressSnapshotsProvider.select((value) {
      final ids =
          value.asData?.value.map((p) => p.bookVersionId).toSet().toList() ??
          <String>[];
      ids.sort();
      return ids.join('\u0000');
    }),
  );
  final persistence = ref.watch(libraryMetadataPersistenceProvider);
  final storage = ref.watch(downloadStorageProvider);
  final durable =
      await persistence?.loadPlaybackBooks() ?? <AudioPlaybackBook>[];
  final cached = await storage.readAllMetadata();
  if (persistence != null) {
    final progress = await ref.read(playbackProgressSnapshotsProvider.future);
    final referenced = progress.map((p) => p.bookVersionId).toSet();
    final persisted = durable.map((b) => b.versionId).toSet();
    for (final book in cached) {
      if (referenced.contains(book.versionId) &&
          !persisted.contains(book.versionId)) {
        await persistence.savePlaybackBook(book);
      }
    }
  }
  final books = {for (final b in durable) libraryPlaybackKey(b): b};
  for (final b in cached) {
    books[libraryPlaybackKey(b)] = b;
  }
  return List.unmodifiable(books.values);
});

String libraryPlaybackKey(AudioPlaybackBook book) =>
    '${book.sourceId}:${book.versionId}';
String libraryBookKey(AudioBook book) =>
    '${book.sourceId}:${book.sourceBookId ?? book.id}';

AudioBook libraryCardBook(AudioPlaybackBook book) {
  final duration = book.totalDuration;
  final label =
      '${duration.inHours.toString().padLeft(2, '0')}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}';
  return AudioBook(
    id: book.id,
    sourceBookId: book.sourceBookId,
    title: book.title,
    author: book.author,
    narrator: book.narrator,
    sourceId: book.sourceId,
    sourceName: book.sourceName,
    durationLabel: label,
    chapterCount: book.chapters.length,
    progress: 0,
    access: BookAccess.unknown,
    isFragment: book.isFragment,
    coverUrl: book.coverUrl,
    description: book.description,
    seriesTitle: book.seriesTitle,
    seriesNumber: book.seriesNumber,
    ratingValue: book.ratingValue,
    ratingCount: book.ratingCount,
    year: book.publishedYear,
  );
}

/// Playback metadata is user-library data, not disposable card cache. Mirror
/// descriptions/identities (not headers or media URLs) into the existing DB.
class LibraryPlaybackMetadataStore implements PlaybackBookMetadataStore {
  LibraryPlaybackMetadataStore(this.cache, this.library);
  final PlaybackBookMetadataStore cache;
  final LibraryMetadataPersistence library;
  @override
  Future<void> saveBook(AudioPlaybackBook book) async {
    await library.savePlaybackBook(book);
    await cache.saveBook(book);
  }

  @override
  Future<AudioPlaybackBook?> loadBook({
    required String sourceId,
    required String versionId,
  }) async {
    final cached = await cache.loadBook(
      sourceId: sourceId,
      versionId: versionId,
    );
    if (cached != null) return cached;
    for (final book in await library.loadPlaybackBooks()) {
      if (book.sourceId == sourceId && book.versionId == versionId) return book;
    }
    return null;
  }
}
