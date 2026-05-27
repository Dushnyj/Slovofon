import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../domain/models/audio_book.dart';
import 'library_store.dart';

class DriftLibraryPersistenceStore implements LibraryPersistenceStore {
  DriftLibraryPersistenceStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<LibraryBookEntry>> loadFavorites() async {
    final favorites = await (_db.select(
      _db.favorites,
    )..orderBy([(favorite) => OrderingTerm.desc(favorite.createdAt)])).get();
    final entries = <LibraryBookEntry>[];

    for (final favorite in favorites) {
      final versionId = favorite.bookVersionId;
      if (versionId == null) {
        continue;
      }
      final versionQuery = _db.select(_db.bookVersions)
        ..where((version) => version.id.equals(versionId));
      final version = await versionQuery.getSingleOrNull();
      if (version == null) {
        continue;
      }
      entries.add(
        LibraryBookEntry(
          book: _audioBookFromVersion(version),
          isFavorite: true,
          updatedAt: favorite.createdAt,
        ),
      );
    }

    return entries;
  }

  @override
  Future<void> saveFavorite(LibraryBookEntry entry) async {
    final now = entry.updatedAt;
    final book = entry.book;
    final bookId = _bookId(book);
    final versionId = _versionId(book);
    final authors = _peopleList(book.author);
    final narrators = _peopleList(book.narrator);
    final metadataJson = jsonEncode({
      'sourceName': book.sourceName,
      'chapterCount': book.chapterCount,
    });

    await _db.transaction(() async {
      await _db
          .into(_db.books)
          .insertOnConflictUpdate(
            BooksCompanion(
              id: Value(bookId),
              normalizedTitle: Value(_normalizeTitle(book.title)),
              displayTitle: Value(book.title),
              authorsJson: Value(jsonEncode(authors)),
              year: Value(book.year),
              bestCoverUrl: Value(book.coverUrl),
              bestDescription: Value(book.description),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _db
          .into(_db.bookVersions)
          .insertOnConflictUpdate(
            BookVersionsCompanion(
              id: Value(versionId),
              bookId: Value(bookId),
              sourceId: Value(book.sourceId),
              sourceBookId: Value(book.sourceBookId ?? book.id),
              title: Value(book.title),
              normalizedTitle: Value(_normalizeTitle(book.title)),
              authorsJson: Value(jsonEncode(authors)),
              narratorsJson: Value(jsonEncode(narrators)),
              description: Value(book.description),
              coverUrl: Value(book.coverUrl),
              durationText: Value(book.durationLabel),
              publishedYear: Value(book.year),
              accessType: Value(_accessTypeName(book.access)),
              playbackAccess: const Value('unknown'),
              rawSourceDataJson: Value(metadataJson),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _db
          .into(_db.favorites)
          .insertOnConflictUpdate(
            FavoritesCompanion(
              bookId: Value(bookId),
              bookVersionId: Value(versionId),
              createdAt: Value(now),
            ),
          );
    });
  }

  @override
  Future<void> removeFavorite(AudioBook book) async {
    final delete = _db.delete(_db.favorites)
      ..where((favorite) => favorite.bookId.equals(_bookId(book)));
    await delete.go();
  }

  AudioBook _audioBookFromVersion(BookVersionRow version) {
    final metadata = _decodeMap(version.rawSourceDataJson);
    return AudioBook(
      id: version.bookId,
      sourceBookId: version.sourceBookId,
      title: version.title,
      author: _decodePeople(version.authorsJson).join(', '),
      narrator: _decodePeople(version.narratorsJson).join(', '),
      sourceId: version.sourceId,
      sourceName:
          metadata['sourceName']?.toString() ?? _sourceName(version.sourceId),
      durationLabel: version.durationText ?? _durationLabel(version.durationMs),
      chapterCount: _intValue(metadata['chapterCount']),
      progress: 0,
      access: _bookAccess(version.accessType),
      coverUrl: version.coverUrl,
      description: version.description,
      year: version.publishedYear,
    );
  }

  String _bookId(AudioBook book) {
    final sourceBookId = book.sourceBookId;
    if (sourceBookId != null && sourceBookId.isNotEmpty) {
      return '${book.sourceId}-book-$sourceBookId';
    }
    return book.id;
  }

  String _versionId(AudioBook book) {
    final sourceBookId = book.sourceBookId;
    if (sourceBookId != null && sourceBookId.isNotEmpty) {
      return '${book.sourceId}-$sourceBookId';
    }
    return '${book.sourceId}-${book.id}';
  }

  List<String> _peopleList(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    return [trimmed];
  }

  List<String> _decodePeople(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! List<Object?>) {
      return const [];
    }
    return [
      for (final item in decoded)
        if (item != null && item.toString().trim().isNotEmpty)
          item.toString().trim(),
    ];
  }

  Map<String, Object?> _decodeMap(String? jsonText) {
    if (jsonText == null || jsonText.isEmpty) {
      return const {};
    }
    final decoded = jsonDecode(jsonText);
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    return const {};
  }

  int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return 0;
  }

  String _normalizeTitle(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^0-9a-zа-я]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _durationLabel(int? durationMs) {
    if (durationMs == null || durationMs <= 0) {
      return '-';
    }
    final duration = Duration(milliseconds: durationMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return minutes > 0 ? '$hours ч $minutes мин' : '$hours ч';
    }
    return '$minutes мин';
  }

  BookAccess _bookAccess(String value) {
    return switch (value) {
      'free' => BookAccess.free,
      'paid' => BookAccess.paid,
      'subscription' => BookAccess.subscription,
      _ => BookAccess.unknown,
    };
  }

  String _accessTypeName(BookAccess access) {
    return switch (access) {
      BookAccess.free => 'free',
      BookAccess.paid => 'paid',
      BookAccess.subscription => 'subscription',
      BookAccess.unknown => 'unknown',
    };
  }

  String _sourceName(String sourceId) {
    return switch (sourceId) {
      'izib' => 'Izib',
      'akniga' => 'Akniga',
      'yakniga' => 'Yakniga',
      'knigavuhe' => 'Knigavuhe',
      'knigoblud' => 'Knigoblud',
      'baza_knig' => 'Baza Knig',
      _ => sourceId,
    };
  }
}
