import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/audio_book.dart';
import '../audio/audio_persistence.dart';
import '../audio/audio_state.dart';
import '../audio/playback_controller_provider.dart';
import '../downloads/download_manager_provider.dart';

abstract interface class LibraryMetadataPersistence {
  Future<void> savePlaybackBook(AudioPlaybackBook book);
  Future<List<AudioPlaybackBook>> loadPlaybackBooks({Set<String>? versionIds});
}

final libraryMetadataPersistenceProvider =
    Provider<LibraryMetadataPersistence?>((ref) => null);

/// Home needs listening history, not every book ever cached by search/details.
/// Read those durable identities first. Only legacy history missing from the DB
/// needs a cache scan; recover that metadata without moving/deleting any files.
final historyPlaybackBooksProvider = FutureProvider<List<AudioPlaybackBook>>((
  ref,
) async {
  final identities = ref.watch(
    playbackProgressSnapshotsProvider.selectAsync((value) {
      final ids = value.map((p) => p.bookVersionId).toSet().toList();
      ids.sort();
      return jsonEncode(ids);
    }),
  );
  final persistence = ref.watch(libraryMetadataPersistenceProvider);
  final storage = ref.watch(downloadStorageProvider);
  final ids = (jsonDecode(await identities) as List).cast<String>().toSet();
  if (!ref.mounted) return const [];
  if (ids.isEmpty) return const [];
  final durable =
      await persistence?.loadPlaybackBooks(versionIds: ids) ??
      <AudioPlaybackBook>[];
  if (!ref.mounted) return const [];
  final missing = ids.difference(durable.map((book) => book.versionId).toSet());
  if (missing.isEmpty) return List.unmodifiable(durable);
  final books = {for (final book in durable) libraryPlaybackKey(book): book};
  for (final book in await storage.readAllMetadata()) {
    if (!ref.mounted) return const [];
    if (!missing.contains(book.versionId)) continue;
    books[libraryPlaybackKey(book)] = book;
    await persistence?.savePlaybackBook(book);
  }
  return List.unmodifiable(books.values);
});

/// Cached metadata alone is not a library membership. The shelf projection
/// below only includes books referenced by progress, downloads, Later or marks.
final libraryPlaybackBooksProvider = FutureProvider<List<AudioPlaybackBook>>((
  ref,
) async {
  final identities = ref.watch(
    playbackProgressSnapshotsProvider.selectAsync((value) {
      final ids = value.map((p) => p.bookVersionId).toSet().toList();
      ids.sort();
      return jsonEncode(ids);
    }),
  );
  final persistence = ref.watch(libraryMetadataPersistenceProvider);
  final storage = ref.watch(downloadStorageProvider);
  final durable =
      await persistence?.loadPlaybackBooks() ?? <AudioPlaybackBook>[];
  if (!ref.mounted) return const [];
  final cached = await storage.readAllMetadata();
  if (!ref.mounted) return const [];
  if (persistence != null) {
    final referenced = (jsonDecode(await identities) as List)
        .cast<String>()
        .toSet();
    if (!ref.mounted) return const [];
    final persisted = durable.map((b) => b.versionId).toSet();
    for (final book in cached) {
      if (!ref.mounted) return const [];
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
    for (final book in await library.loadPlaybackBooks(
      versionIds: {versionId},
    )) {
      if (book.sourceId == sourceId && book.versionId == versionId) return book;
    }
    return null;
  }
}
