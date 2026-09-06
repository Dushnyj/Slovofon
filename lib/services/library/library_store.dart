import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/models/audio_book.dart';
import 'later_persistence.dart';

final libraryStoreProvider = ChangeNotifierProvider<LibraryStore>((ref) {
  final store = LibraryStore(MemoryLibraryPersistenceStore())..load();
  return store;
});

class LibraryStore extends ChangeNotifier {
  LibraryStore(
    this._persistence, {
    DateTime Function()? clock,
    LaterPersistence? laterPersistence,
  }) : _clock = clock ?? DateTime.now,
       _laterPersistence = laterPersistence ?? MemoryLaterPersistence();

  final LibraryPersistenceStore _persistence;
  final LaterPersistence _laterPersistence;
  final _laterEntries = <String, LibraryBookEntry>{};
  Future<void>? _laterLoadFuture;
  Future<void> _operations = Future.value();
  bool _disposed = false;
  bool isLoaded = false;
  Object? error;
  Object? laterError;
  List<LibraryBookEntry> get later =>
      _laterEntries.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  bool isLater(AudioBook book) => _laterEntries.containsKey(_bookKey(book));

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadLater() => _laterLoadFuture ??= () async {
    try {
      final entries = await _laterPersistence.load();
      _laterEntries
        ..clear()
        ..addEntries(entries.map((e) => MapEntry(_bookKey(e.book), e)));
      laterError = null;
    } catch (e) {
      laterError = e;
      rethrow;
    }
  }();

  Future<bool> toggleLater(AudioBook book) => _serialize(() async {
    if (laterError != null) _laterLoadFuture = null;
    await _loadLater();
    final next = Map<String, LibraryBookEntry>.of(_laterEntries);
    final key = _bookKey(book);
    final added = !next.containsKey(key);
    if (added) {
      next[key] = LibraryBookEntry(
        book: book,
        isFavorite: false,
        updatedAt: _clock(),
      );
    } else {
      next.remove(key);
    }
    await _laterPersistence.save(next.values.toList());
    _laterEntries
      ..clear()
      ..addAll(next);
    _notify();
    return added;
  });
  final DateTime Function() _clock;
  final _entries = <String, LibraryBookEntry>{};
  Future<void>? _loadFuture;

  List<LibraryBookEntry> get entries {
    final values = _entries.values.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List.unmodifiable(values);
  }

  List<LibraryBookEntry> get favorites {
    return entries.where((entry) => entry.isFavorite).toList();
  }

  bool isFavorite(AudioBook book) {
    return _entries[_bookKey(book)]?.isFavorite ?? false;
  }

  Future<void> load() {
    if (isLoaded && (error != null || laterError != null)) {
      _loadFuture = null;
      if (laterError != null) _laterLoadFuture = null;
      isLoaded = false;
    }
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final entries = await _persistence.loadFavorites();
      _entries
        ..clear()
        ..addEntries(
          entries.map((entry) => MapEntry(_bookKey(entry.book), entry)),
        );
      error = null;
    } catch (e) {
      error = e;
    }
    // A damaged Later file never hides or prevents changing valid favorites.
    try {
      await _loadLater();
    } catch (_) {}
    isLoaded = true;
    _notify();
  }

  Future<bool> toggleFavorite(AudioBook book) => _serialize(() async {
    await load();
    if (error != null) throw StateError('Library has not loaded');
    final key = _bookKey(book);
    final current = _entries[key];
    final nextFavorite = !(current?.isFavorite ?? false);

    if (nextFavorite) {
      final entry = LibraryBookEntry(
        book: book,
        isFavorite: true,
        updatedAt: _clock(),
      );
      await _persistence.saveFavorite(entry);
      _entries[key] = entry;
    } else {
      await _persistence.removeFavorite(book);
      _entries.remove(key);
    }
    _notify();
    return nextFavorite;
  });

  Future<void> refreshFavoriteMetadata(AudioBook book) => _serialize(() async {
    await load();
    if (error != null) throw StateError('Library has not loaded');
    final key = _bookKey(book);
    final currentLater = _laterEntries[key];
    if (currentLater != null) {
      final next = Map<String, LibraryBookEntry>.of(_laterEntries);
      next[key] = LibraryBookEntry(
        book: book,
        isFavorite: false,
        updatedAt: currentLater.updatedAt,
      );
      await _laterPersistence.save(next.values.toList());
      _laterEntries
        ..clear()
        ..addAll(next);
      _notify();
    }
    final current = _entries[key];
    if (current == null || !current.isFavorite) {
      return;
    }

    final refreshed = LibraryBookEntry(
      book: book,
      isFavorite: true,
      updatedAt: current.updatedAt,
    );
    await _persistence.saveFavorite(refreshed);
    _entries[key] = refreshed;
    _notify();
  });

  static String _bookKey(AudioBook book) {
    return '${book.sourceId}:${book.sourceBookId ?? book.id}';
  }
}

abstract interface class LibraryPersistenceStore {
  Future<List<LibraryBookEntry>> loadFavorites();

  Future<void> saveFavorite(LibraryBookEntry entry);

  Future<void> removeFavorite(AudioBook book);
}

class MemoryLibraryPersistenceStore implements LibraryPersistenceStore {
  final _entries = <String, LibraryBookEntry>{};

  @override
  Future<List<LibraryBookEntry>> loadFavorites() async {
    return _entries.values.toList()
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  }

  @override
  Future<void> saveFavorite(LibraryBookEntry entry) async {
    _entries[LibraryStore._bookKey(entry.book)] = entry;
  }

  @override
  Future<void> removeFavorite(AudioBook book) async {
    _entries.remove(LibraryStore._bookKey(book));
  }
}

class LibraryBookEntry {
  const LibraryBookEntry({
    required this.book,
    required this.isFavorite,
    required this.updatedAt,
  });

  final AudioBook book;
  final bool isFavorite;
  final DateTime updatedAt;
}
