import '../../domain/models/audio_book.dart';
import '../../domain/models/download_task.dart';
import '../audio/audio_persistence.dart';
import '../audio/audio_state.dart';
import '../bookmarks/bookmark_store.dart';
import 'library_metadata.dart';
import 'library_store.dart';

enum LibraryShelf {
  all,
  listening,
  favorites,
  later,
  downloaded,
  finished,
  bookmarks,
  history,
}

class LibraryShelfEntry {
  LibraryShelfEntry({required this.book, required this.updatedAt});
  AudioBook book;
  DateTime updatedAt;
  AudioPlaybackBook? playbackBook;
  final shelves = <LibraryShelf>{};
  final bookmarks = <PlaybackBookmark>[];
  bool get isFavorite => shelves.contains(LibraryShelf.favorites);
  LibraryBookEntry get cardEntry => LibraryBookEntry(
    book: book,
    isFavorite: isFavorite,
    updatedAt: updatedAt,
  );
}

/// Pure union/projection. Merely seeing a search result or caching its artwork
/// does not add it to a shelf. Version identities keep source narrations apart.
List<LibraryShelfEntry> projectLibraryShelves({
  required List<LibraryBookEntry> favorites,
  required List<LibraryBookEntry> later,
  required List<AudioPlaybackBook> metadata,
  required List<PlaybackProgressSnapshot> progress,
  required List<DownloadTask> downloads,
  required List<PlaybackBookmark> bookmarks,
  AudioPlaybackState current = AudioPlaybackState.idle,
}) {
  final result = <String, LibraryShelfEntry>{};
  final books = {for (final book in metadata) book.versionId: book};
  for (final bookmark in bookmarks) {
    if (bookmark.book != null) {
      books.putIfAbsent(bookmark.bookVersionId, () => bookmark.book!);
    }
  }
  if (current.book != null) books[current.book!.versionId] = current.book!;

  LibraryShelfEntry add(
    AudioBook book,
    DateTime time,
    LibraryShelf shelf, {
    AudioPlaybackBook? playback,
  }) {
    final key = libraryBookKey(book);
    final entry = result.putIfAbsent(
      key,
      () => LibraryShelfEntry(book: book, updatedAt: time),
    );
    entry.shelves.addAll([LibraryShelf.all, shelf]);
    if (time.isAfter(entry.updatedAt)) entry.updatedAt = time;
    entry.playbackBook ??= playback;
    return entry;
  }

  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  for (final favorite in favorites) {
    add(favorite.book, favorite.updatedAt, LibraryShelf.favorites);
  }
  for (final entry in later) {
    add(entry.book, entry.updatedAt, LibraryShelf.later);
  }

  AudioPlaybackBook? resolve(String versionId, String bookId) {
    final exact = books[versionId];
    if (exact != null) return exact;
    // Favorites written before playback retain canonical source/version IDs.
    for (final saved in [...favorites, ...later]) {
      final b = saved.book;
      final expected = '${b.sourceId}-${b.sourceBookId ?? b.id}';
      if (versionId == expected || (versionId == b.id && bookId == b.id)) {
        return AudioPlaybackBook(
          id: bookId,
          versionId: versionId,
          sourceId: b.sourceId,
          sourceBookId: b.sourceBookId,
          title: b.title,
          author: b.author,
          narrator: b.narrator,
          sourceName: b.sourceName,
          coverUrl: b.coverUrl,
          description: b.description,
          chapters: const [],
          seriesTitle: b.seriesTitle,
          seriesNumber: b.seriesNumber,
          ratingValue: b.ratingValue,
          ratingCount: b.ratingCount,
          publishedYear: b.year,
        );
      }
    }
    return null;
  }

  for (final snapshot in progress) {
    final book = resolve(snapshot.bookVersionId, snapshot.bookId);
    if (book == null) continue;
    final entry = add(
      libraryCardBook(book),
      snapshot.lastPlayedAt,
      LibraryShelf.history,
      playback: book,
    );
    entry.book = entry.book.copyWith(
      progress: snapshot.percent.isFinite
          ? (snapshot.percent / 100).clamp(0, 1)
          : 0,
    );
    if (snapshot.isFinished || snapshot.percent >= 100) {
      entry.shelves.add(LibraryShelf.finished);
    } else if (snapshot.currentPositionMs > 0 ||
        snapshot.maxReachedGlobalPositionMs > 0 ||
        snapshot.percent > 0) {
      entry.shelves.add(LibraryShelf.listening);
    }
  }
  for (final task in downloads) {
    final book = resolve(task.bookVersionId, task.bookId);
    if (book == null ||
        book.sourceId != task.sourceId ||
        task.status == DownloadTaskStatus.canceled) {
      continue;
    }
    final entry = add(
      libraryCardBook(book),
      task.updatedAt,
      LibraryShelf.all,
      playback: book,
    );
    // A partially downloaded audiobook is still available offline by chapter.
    if (task.status == DownloadTaskStatus.completed &&
        (task.type == DownloadTaskType.chapter ||
            task.type == DownloadTaskType.book)) {
      entry.shelves.add(LibraryShelf.downloaded);
    }
  }
  for (final bookmark in bookmarks) {
    final book = resolve(bookmark.bookVersionId, bookmark.bookId);
    if (book == null) continue; // UI still exposes orphan marks individually.
    final entry = add(
      libraryCardBook(book),
      bookmark.updatedAt,
      LibraryShelf.bookmarks,
      playback: book,
    );
    entry.bookmarks.add(bookmark);
  }
  final active = current.book;
  if (active != null) {
    // A restored, paused zero-position book belongs to History too.
    final previous = progress.where((p) => p.bookVersionId == active.versionId);
    final time = previous.isEmpty ? epoch : previous.first.lastPlayedAt;
    final entry = add(
      libraryCardBook(active),
      time,
      LibraryShelf.history,
      playback: active,
    );
    entry.playbackBook = active;
    entry.book = entry.book.copyWith(
      progress: current.bookProgress.clamp(0, 1),
    );
    if (current.status == AudioPlaybackStatus.completed ||
        current.bookProgress >= 1) {
      entry.shelves
        ..remove(LibraryShelf.listening)
        ..add(LibraryShelf.finished);
    } else {
      entry.shelves
        ..remove(LibraryShelf.finished)
        ..add(LibraryShelf.listening);
    }
  }
  return result.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}
