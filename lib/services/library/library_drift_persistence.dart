import 'dart:convert';

import 'package:drift/drift.dart';

import '../../data/database/app_database.dart';
import '../../domain/models/audio_book.dart';
import 'library_store.dart';
import '../audio/audio_state.dart';
import 'library_metadata.dart';

class DriftLibraryPersistenceStore
    implements LibraryPersistenceStore, LibraryMetadataPersistence {
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
  Future<void> saveFavorite(LibraryBookEntry entry) => _saveBook(entry);

  Future<void> _saveBook(
    LibraryBookEntry entry, {
    AudioPlaybackBook? playback,
    bool favorite = true,
  }) async {
    final now = entry.updatedAt;
    final book = entry.book;
    final bookId = playback?.id ?? _bookId(book);
    final versionId = playback?.versionId ?? _versionId(book);
    final authors = _peopleList(book.author);
    final narrators = _peopleList(book.narrator);
    await _db.transaction(() async {
      final previous = await (_db.select(
        _db.bookVersions,
      )..where((r) => r.id.equals(versionId))).getSingleOrNull();
      final previousBook = await (_db.select(
        _db.books,
      )..where((r) => r.id.equals(bookId))).getSingleOrNull();
      final metadataJson = jsonEncode({
        ..._decodeMap(previous?.rawSourceDataJson),
        'sourceName': book.sourceName,
        'chapterCount': book.chapterCount,
        'isFragment': book.isFragment,
        if (playback != null) 'librarySourceBookId': playback.sourceBookId,
        if (playback != null)
          'libraryChapters': [
            for (final c in playback.chapters)
              {
                'id': c.id,
                'index': c.index,
                'title': c.title,
                'durationMs': c.duration.inMilliseconds,
              },
          ],
      });

      await _db
          .into(_db.books)
          .insertOnConflictUpdate(
            BooksCompanion(
              id: Value(bookId),
              normalizedTitle: Value(_normalizeTitle(book.title)),
              displayTitle: Value(book.title),
              authorsJson: Value(jsonEncode(authors)),
              seriesTitle: Value(book.seriesTitle),
              seriesNumber: Value(book.seriesNumber),
              year: Value(book.year),
              bestCoverUrl: Value(book.coverUrl),
              bestDescription: Value(book.description),
              createdAt: Value(previousBook?.createdAt ?? now),
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
              seriesTitle: Value(book.seriesTitle ?? previous?.seriesTitle),
              seriesNumber: Value(book.seriesNumber ?? previous?.seriesNumber),
              description: Value(book.description ?? previous?.description),
              coverUrl: Value(book.coverUrl ?? previous?.coverUrl),
              durationText: Value(book.durationLabel),
              publishedYear: Value(book.year ?? previous?.publishedYear),
              ratingValue: Value(book.ratingValue ?? previous?.ratingValue),
              ratingCount: Value(book.ratingCount ?? previous?.ratingCount),
              accessType: Value(
                book.access == BookAccess.unknown
                    ? previous?.accessType ?? 'unknown'
                    : _accessTypeName(book.access),
              ),
              isFragment: Value(book.isFragment),
              playbackAccess: Value(previous?.playbackAccess ?? 'unknown'),
              durationMs: playback == null
                  ? const Value.absent()
                  : Value(playback.totalDuration.inMilliseconds),
              sourceUrl: playback?.sourceUrl == null
                  ? const Value.absent()
                  : Value(playback!.sourceUrl),
              rawSourceDataJson: Value(metadataJson),
              createdAt: Value(previous?.createdAt ?? now),
              updatedAt: Value(now),
            ),
          );
      if (favorite) {
        await _db
            .into(_db.favorites)
            .insertOnConflictUpdate(
              FavoritesCompanion(
                bookId: Value(bookId),
                bookVersionId: Value(versionId),
                createdAt: Value(now),
              ),
            );
      }
    });
  }

  @override
  Future<void> savePlaybackBook(AudioPlaybackBook book) => _saveBook(
    LibraryBookEntry(
      book: libraryCardBook(book),
      isFavorite: false,
      updatedAt: DateTime.now(),
    ),
    playback: book,
    favorite: false,
  );

  @override
  Future<List<AudioPlaybackBook>> loadPlaybackBooks({
    Set<String>? versionIds,
  }) async {
    if (versionIds != null && versionIds.isEmpty) return [];
    final query = _db.select(_db.bookVersions);
    if (versionIds != null) query.where((row) => row.id.isIn(versionIds));
    final versions = await query.get();
    return [for (final version in versions) await _playbackBook(version)];
  }

  Future<AudioPlaybackBook> _playbackBook(BookVersionRow version) async {
    final card = _audioBookFromVersion(version);
    final metadata = _decodeMap(version.rawSourceDataJson);
    final embedded = metadata['libraryChapters'];
    final chapters = <AudioPlaybackChapter>[];
    if (embedded is List) {
      for (final row in embedded) {
        if (row is Map && row['id'] is String && row['title'] is String) {
          chapters.add(
            AudioPlaybackChapter(
              id: row['id'] as String,
              index: _intValue(row['index']),
              title: row['title'] as String,
              duration: Duration(milliseconds: _intValue(row['durationMs'])),
            ),
          );
        }
      }
    } else {
      // Keep bookmarks created by earlier schema-1 consumers resolvable too.
      final rows =
          await (_db.select(_db.chapters)
                ..where((r) => r.bookVersionId.equals(version.id))
                ..orderBy([(r) => OrderingTerm.asc(r.index)]))
              .get();
      chapters.addAll(
        rows.map(
          (r) => AudioPlaybackChapter(
            id: r.id,
            index: r.index,
            title: r.title,
            duration: Duration(milliseconds: r.durationMs ?? 0),
          ),
        ),
      );
    }
    return AudioPlaybackBook(
      id: version.bookId,
      versionId: version.id,
      sourceId: version.sourceId,
      sourceBookId: metadata['librarySourceBookId'] is String
          ? metadata['librarySourceBookId'] as String
          : metadata.containsKey('librarySourceBookId') &&
                metadata['librarySourceBookId'] == null
          ? null
          : version.sourceBookId,
      title: card.title,
      author: card.author,
      narrator: card.narrator,
      sourceName: card.sourceName,
      chapters: List.unmodifiable(chapters),
      coverUrl: card.coverUrl,
      description: card.description,
      seriesTitle: card.seriesTitle,
      seriesNumber: card.seriesNumber,
      publishedYear: card.year,
      ratingValue: card.ratingValue,
      ratingCount: card.ratingCount,
      sourceUrl: version.sourceUrl,
      isFragment: card.isFragment,
    );
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
      isFragment: version.isFragment || metadata['isFragment'] == true,
      coverUrl: version.coverUrl,
      description: version.description,
      seriesTitle: version.seriesTitle,
      seriesNumber: version.seriesNumber,
      ratingValue: version.ratingValue,
      ratingCount: version.ratingCount,
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
    return trimmed
        .split(RegExp(r'\s*,\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  List<String> _decodePeople(String jsonText) {
    Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      return const [];
    }
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
    Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      /* Keep recovery data below. */
    }
    if (decoded is Map<String, Object?>) return decoded;
    // Optional connector metadata must not hide otherwise valid favorites or
    // bookmarks. A later metadata refresh retains the original rather than
    // silently overwriting damaged source data with a fresh empty map.
    return {'_legacyUnparsedSourceData': jsonText};
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
