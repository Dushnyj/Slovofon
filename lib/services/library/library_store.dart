import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/models/audio_book.dart';

final libraryStoreProvider = ChangeNotifierProvider<LibraryStore>((ref) {
  final store = LibraryStore(MemoryLibraryPersistenceStore())..load();
  return store;
});

class LibraryStore extends ChangeNotifier {
  LibraryStore(this._persistence, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LibraryPersistenceStore _persistence;
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
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    final entries = await _persistence.loadFavorites();
    _entries
      ..clear()
      ..addEntries(
        entries.map((entry) => MapEntry(_bookKey(entry.book), entry)),
      );
    notifyListeners();
  }

  Future<bool> toggleFavorite(AudioBook book) async {
    await load();
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
    notifyListeners();
    return nextFavorite;
  }

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
