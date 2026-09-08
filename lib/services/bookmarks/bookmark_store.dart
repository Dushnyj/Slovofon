import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../audio/audio_state.dart';

class PlaybackBookmark {
  const PlaybackBookmark({
    required this.id,
    required this.bookId,
    required this.bookVersionId,
    required this.chapterId,
    required this.positionMs,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.book,
  });
  final String id;
  final String bookId;
  final String bookVersionId;
  final String chapterId;
  final int positionMs;
  final String title;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AudioPlaybackBook? book;
}

abstract interface class BookmarkPersistence {
  Future<List<PlaybackBookmark>> load();
  Future<void> save(PlaybackBookmark bookmark);
  Future<void> remove(String id);
}

class MemoryBookmarkPersistence implements BookmarkPersistence {
  final _bookmarks = <String, PlaybackBookmark>{};
  @override
  Future<List<PlaybackBookmark>> load() async => _bookmarks.values.toList();
  @override
  Future<void> save(PlaybackBookmark bookmark) async {
    _bookmarks[bookmark.id] = bookmark;
  }

  @override
  Future<void> remove(String id) async {
    _bookmarks.remove(id);
  }
}

final bookmarkStoreProvider = ChangeNotifierProvider<BookmarkStore>((ref) {
  return BookmarkStore(MemoryBookmarkPersistence())..load();
});

class BookmarkStore extends ChangeNotifier {
  BookmarkStore(this._persistence, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final BookmarkPersistence _persistence;
  final DateTime Function() _clock;
  final _entries = <String, PlaybackBookmark>{};
  Future<void>? _loadFuture;
  Future<void> _operations = Future.value();
  static int _sequence = 0;
  bool _disposed = false;
  bool isLoaded = false;
  Object? error;

  Future<void> flushPendingWrites() async {
    await _loadFuture;
    await _operations;
  }

  List<PlaybackBookmark> get entries => List.unmodifiable(
    _entries.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
  List<PlaybackBookmark> forBook(String bookVersionId) => List.unmodifiable(
    entries.where((bookmark) => bookmark.bookVersionId == bookVersionId),
  );

  Future<void> load() {
    if (isLoaded && error != null) {
      _loadFuture = null;
      isLoaded = false;
    }
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final bookmarks = await _persistence.load();
      _entries
        ..clear()
        ..addEntries(bookmarks.map((b) => MapEntry(b.id, b)));
      error = null;
    } catch (e) {
      error = e;
    }
    isLoaded = true;
    _notify();
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<PlaybackBookmark> add({
    required AudioPlaybackBook book,
    required String chapterId,
    required int positionMs,
    String? title,
    String? note,
  }) => _serialize(() async {
    await load();
    if (error != null) throw StateError('Bookmarks have not loaded');
    final chapters = book.chapters.where((chapter) => chapter.id == chapterId);
    if (chapters.isEmpty) throw ArgumentError.value(chapterId, 'chapterId');
    final chapter = chapters.first;
    final maxPosition = chapter.duration.inMilliseconds;
    final position = positionMs.clamp(
      0,
      maxPosition > 0 ? maxPosition : 0x7fffffffffffffff,
    );
    final now = _clock();
    final bookmark = PlaybackBookmark(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      bookId: book.id,
      bookVersionId: book.versionId,
      chapterId: chapter.id,
      positionMs: position,
      title: title?.trim().isNotEmpty == true ? title!.trim() : chapter.title,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
      book: book,
    );
    await _persistence.save(bookmark);
    _entries[bookmark.id] = bookmark;
    _notify();
    return bookmark;
  });

  Future<void> remove(String id) => _serialize(() async {
    await load();
    if (error != null) throw StateError('Bookmarks have not loaded');
    if (!_entries.containsKey(id)) return;
    await _persistence.remove(id);
    _entries.remove(id);
    _notify();
  });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
