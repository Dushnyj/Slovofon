import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/storage/atomic_json_file.dart';
import '../../domain/models/audio_book.dart';
import 'library_store.dart';

abstract interface class LaterPersistence {
  Future<List<LibraryBookEntry>> load();
  Future<void> save(List<LibraryBookEntry> entries);
}

class MemoryLaterPersistence implements LaterPersistence {
  List<LibraryBookEntry> _entries = [];
  @override
  Future<List<LibraryBookEntry>> load() async => List.of(_entries);
  @override
  Future<void> save(List<LibraryBookEntry> entries) async {
    _entries = List.of(entries);
  }
}

/// Separate from the settings row and from Favorites: changing one collection
/// cannot overwrite the other. AtomicJsonFile retains the last-good backup.
class FileLaterPersistence implements LaterPersistence {
  FileLaterPersistence(this.file);
  final File file;

  static Future<FileLaterPersistence> create() async {
    final directory = await getApplicationSupportDirectory();
    return FileLaterPersistence(
      File(p.join(directory.path, 'library_later.json')),
    );
  }

  @override
  Future<List<LibraryBookEntry>> load() async {
    final decoded = await AtomicJsonFile(file).read();
    if (decoded == null &&
        !await file.exists() &&
        !await File('${file.path}.bak').exists()) {
      return [];
    }
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['books'] is! List) {
      // Do not silently accept damaged data as an empty shelf, then overwrite it.
      throw const FormatException('Invalid later library data');
    }
    return [for (final row in decoded['books'] as List) _decode(row)];
  }

  @override
  Future<void> save(List<LibraryBookEntry> entries) =>
      AtomicJsonFile(file).write({
        'version': 1,
        'books': [for (final entry in entries) _encode(entry)],
      });

  Map<String, Object?> _encode(LibraryBookEntry entry) {
    final book = entry.book;
    return {
      'id': book.id,
      'sourceBookId': book.sourceBookId,
      'sourceId': book.sourceId,
      'sourceName': book.sourceName,
      'title': book.title,
      'author': book.author,
      'narrator': book.narrator,
      'durationLabel': book.durationLabel,
      'chapterCount': book.chapterCount,
      'access': book.access.name,
      'isFragment': book.isFragment,
      'coverUrl': book.coverUrl,
      'description': book.description,
      'seriesTitle': book.seriesTitle,
      'seriesNumber': book.seriesNumber,
      'ratingValue': book.ratingValue,
      'ratingCount': book.ratingCount,
      'year': book.year,
      'updatedAt': entry.updatedAt.toIso8601String(),
    };
  }

  LibraryBookEntry _decode(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['sourceId'] is! String ||
        value['title'] is! String ||
        value['updatedAt'] is! String) {
      throw const FormatException('Invalid later book');
    }
    return LibraryBookEntry(
      book: AudioBook(
        id: value['id'] as String,
        sourceId: value['sourceId'] as String,
        title: value['title'] as String,
        sourceBookId: value['sourceBookId'] as String?,
        sourceName:
            value['sourceName'] as String? ?? value['sourceId'] as String,
        author: value['author'] as String? ?? '',
        narrator: value['narrator'] as String? ?? '',
        durationLabel: value['durationLabel'] as String? ?? '',
        chapterCount: (value['chapterCount'] as num?)?.toInt() ?? 0,
        progress: 0,
        access: BookAccess.values.firstWhere(
          (access) => access.name == value['access'],
          orElse: () => BookAccess.unknown,
        ),
        isFragment: value['isFragment'] == true,
        coverUrl: value['coverUrl'] as String?,
        description: value['description'] as String?,
        seriesTitle: value['seriesTitle'] as String?,
        seriesNumber: (value['seriesNumber'] as num?)?.toDouble(),
        ratingValue: (value['ratingValue'] as num?)?.toDouble(),
        ratingCount: (value['ratingCount'] as num?)?.toInt(),
        year: (value['year'] as num?)?.toInt(),
      ),
      isFavorite: false,
      updatedAt: DateTime.parse(value['updatedAt'] as String),
    );
  }
}
