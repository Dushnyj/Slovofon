import '../../domain/models/audio_track.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_version.dart';
import '../../domain/models/chapter.dart';
import '../source_models.dart';
import '../source_parser_helpers.dart';

class IzibMapper {
  IzibMapper({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const sourceId = 'izib';
  static const sourceName = 'Izib';
  static final sourceBaseUri = Uri.parse('https://izib.uk/');

  final DateTime Function() _clock;

  SourceBookRef bookRef(Map<String, Object?> book) {
    final id = _bookId(book);
    return SourceBookRef(
      sourceId: sourceId,
      sourceBookId: id,
      sourceUri: _bookUri(id),
    );
  }

  List<BookSearchResult> searchResults(List<Object?> items) {
    return [
      for (final item in items)
        if (item is Map<String, Object?>) searchResult(item),
    ];
  }

  BookSearchResult searchResult(Map<String, Object?> book) {
    final files = _files(book);
    final duration = _secondsDuration(book['totalDuration']);
    final hasFiles = files.isNotEmpty;

    return BookSearchResult(
      ref: bookRef(book),
      sourceName: sourceName,
      title: _string(book['name']),
      author: _people(book['authors']),
      narrator: _people(book['readers']),
      coverUri: _posterUri(book),
      duration: duration,
      year: _yearFromUnixSeconds(book['publishTs']),
      chapterCount: hasFiles ? files.length : null,
      isFull: hasFiles ? true : null,
      isFree: hasFiles ? true : null,
      accessType: hasFiles ? AccessType.free : AccessType.unknown,
      score: _ratingValue(book),
    );
  }

  BookVersionDetails bookDetails(Map<String, Object?> book) {
    final now = _clock();
    final id = _bookId(book);
    final files = _files(book);
    final hasFiles = files.isNotEmpty;
    final title = _string(book['name']);
    final normalizedTitle = SourceParserHelpers.normalizeTitle(title);
    final description = _stripMarkup(_string(book['aboutBb']));

    return BookVersionDetails(
      ref: bookRef(book),
      book: Book(
        id: 'izib-book-$id',
        normalizedTitle: normalizedTitle,
        displayTitle: title,
        authors: _peopleList(book['authors']),
        seriesTitle: _entityName(book['serie']),
        seriesNumber: _seriesNumber(book['serieIndex']),
        year: _yearFromUnixSeconds(book['publishTs']),
        bestCoverUrl: _posterUri(book)?.toString(),
        bestDescription: description,
        createdAt: now,
        updatedAt: now,
      ),
      version: BookVersion(
        id: 'izib-$id',
        bookId: 'izib-book-$id',
        sourceId: sourceId,
        sourceBookId: id,
        sourceUrl: _bookUri(id).toString(),
        title: title,
        normalizedTitle: normalizedTitle,
        authors: _peopleList(book['authors']),
        narrators: _peopleList(book['readers']),
        seriesTitle: _entityName(book['serie']),
        seriesNumber: _seriesNumber(book['serieIndex']),
        genres: [
          _entityName(book['genre']),
        ].where((value) => value.isNotEmpty).toList(),
        description: description,
        coverUrl: _posterUri(book)?.toString(),
        durationMs: _secondsDuration(book['totalDuration'])?.inMilliseconds,
        durationText: _durationText(book['totalDuration']),
        publishedYear: _yearFromUnixSeconds(book['publishTs']),
        ratingValue: _ratingValue(book),
        ratingCount: _ratingCount(book),
        accessType: hasFiles ? AccessType.free : AccessType.unknown,
        playbackAccess: hasFiles
            ? PlaybackAccess.streamAndDownload
            : PlaybackAccess.none,
        isFull: hasFiles,
        isFragment: !hasFiles,
        isAccessibleForFree: hasFiles,
        canStream: hasFiles,
        canDownload: hasFiles,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  List<Chapter> chapters(Map<String, Object?> book) {
    final now = _clock();
    final bookId = _bookId(book);
    final files = _files(book);

    return [
      for (var i = 0; i < files.length; i++)
        Chapter(
          id: _chapterId(bookId, files[i], i),
          bookVersionId: 'izib-$bookId',
          sourceId: sourceId,
          sourceBookId: bookId,
          sourceChapterId: _fileId(files[i], i),
          index: _fileIndex(files[i], i),
          title: _fileTitle(files[i], i),
          normalizedTitle: SourceParserHelpers.normalizeTitle(
            _fileTitle(files[i], i),
          ),
          durationMs: _secondsDuration(files[i]['duration'])?.inMilliseconds,
          streamRef: _string(files[i]['url']),
          cachedStreamUrl: _string(files[i]['url']),
          audioFormat: _audioFormat(files[i]),
          mimeType: _mimeType(_audioFormat(files[i])),
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  List<AudioTrack> audioTracks(Map<String, Object?> book) {
    final bookId = _bookId(book);
    final files = _files(book);

    return [
      for (var i = 0; i < files.length; i++)
        AudioTrack(
          id: 'izib-$bookId-track-${_fileId(files[i], i)}',
          chapterId: _chapterId(bookId, files[i], i),
          sourceId: sourceId,
          index: 1,
          title: _fileTitle(files[i], i),
          durationMs: _secondsDuration(files[i]['duration'])?.inMilliseconds,
          mediaRef: _string(files[i]['url']),
          directUrl: _string(files[i]['url']),
          format: _audioFormat(files[i]),
          mimeType: _mimeType(_audioFormat(files[i])),
        ),
    ];
  }

  static Uri _bookUri(String id) {
    return sourceBaseUri.resolve('art$id');
  }

  static String _bookId(Map<String, Object?> book) {
    return _string(book['id']);
  }

  static String _chapterId(
    String bookId,
    Map<String, Object?> file,
    int fallbackIndex,
  ) {
    return 'izib-$bookId-chapter-${_fileId(file, fallbackIndex)}';
  }

  static String _fileId(Map<String, Object?> file, int fallbackIndex) {
    final id = _string(file['id']);
    return id.isEmpty ? '${fallbackIndex + 1}' : id;
  }

  static int _fileIndex(Map<String, Object?> file, int fallbackIndex) {
    return _intValue(file['index']) ?? fallbackIndex + 1;
  }

  static String _fileTitle(Map<String, Object?> file, int fallbackIndex) {
    final title = _stripMarkup(_string(file['title']));
    if (title.isNotEmpty) {
      return title;
    }

    final fileName = _string(file['fileName']);
    final withoutExtension = fileName.replaceFirst(
      RegExp(r'\.[a-z0-9]+$', caseSensitive: false),
      '',
    );
    return withoutExtension.isEmpty
        ? 'Глава ${fallbackIndex + 1}'
        : withoutExtension;
  }

  static String _audioFormat(Map<String, Object?> file) {
    final fileName = _string(file['fileName']);
    final match = RegExp(
      r'\.([a-z0-9]+)$',
      caseSensitive: false,
    ).firstMatch(fileName);
    if (match != null) {
      return match.group(1)!.toLowerCase();
    }

    final url = _string(file['url']);
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final urlMatch = RegExp(
      r'\.([a-z0-9]+)$',
      caseSensitive: false,
    ).firstMatch(path);
    return urlMatch?.group(1)?.toLowerCase() ?? 'mp3';
  }

  static String _mimeType(String format) {
    return switch (format) {
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'ogg' => 'audio/ogg',
      'wav' => 'audio/wav',
      _ => 'audio/mpeg',
    };
  }

  static List<Map<String, Object?>> _files(Map<String, Object?> book) {
    final files = book['files'];
    if (files is! Map<String, Object?>) {
      return const [];
    }

    final mobile = _fileList(files['mobile']);
    final full = _fileList(files['full']);
    final selected = mobile.length >= full.length ? mobile : full;
    selected.sort((left, right) {
      final leftIndex = _intValue(left['index']) ?? 0;
      final rightIndex = _intValue(right['index']) ?? 0;
      return leftIndex.compareTo(rightIndex);
    });
    return selected.where((file) => _string(file['url']).isNotEmpty).toList();
  }

  static List<Map<String, Object?>> _fileList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return [
      for (final item in value)
        if (item is Map<String, Object?>) item,
    ];
  }

  static Uri? _posterUri(Map<String, Object?> book) {
    final posters = book['posters'] is List
        ? book['posters']! as List
        : const [];
    final value = _firstNonEmpty([
      _string(book['defaultPosterMain']),
      _string(book['defaultPoster']),
      for (final poster in posters) _string(poster),
    ]);
    return SourceParserHelpers.safeResolveUri(sourceBaseUri, value);
  }

  static String _people(Object? value) {
    return _peopleList(value).join(', ');
  }

  static List<String> _peopleList(Object? value) {
    if (value is! List) {
      return const [];
    }

    final names = <String>[];
    final seen = <String>{};
    for (final item in value) {
      final name = _entityName(item);
      final key = name.toLowerCase();
      if (name.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      names.add(name);
    }

    return names;
  }

  static String _entityName(Object? value) {
    if (value is! Map<String, Object?>) {
      return '';
    }

    return SourceParserHelpers.normalizeWhitespace(
      [
        _string(value['name']),
        _string(value['surname']),
      ].where((part) => part.isNotEmpty).join(' '),
    );
  }

  static Duration? _secondsDuration(Object? value) {
    final seconds = _numValue(value);
    if (seconds == null || seconds <= 0) {
      return null;
    }

    return Duration(milliseconds: (seconds * 1000).round());
  }

  static String? _durationText(Object? value) {
    final duration = _secondsDuration(value);
    if (duration == null) {
      return null;
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return minutes > 0 ? '$hours ч $minutes мин' : '$hours ч';
    }

    return '$minutes мин';
  }

  static int? _yearFromUnixSeconds(Object? value) {
    final seconds = _intValue(value);
    if (seconds == null || seconds <= 0) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).year;
  }

  static double? _seriesNumber(Object? value) {
    final normalized = _string(value).replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  static double? _ratingValue(Map<String, Object?> book) {
    final likes = _numValue(book['likes']);
    final dislikes = _numValue(book['dislikes']);
    if (likes == null || dislikes == null) {
      return null;
    }
    final total = likes + dislikes;
    if (total <= 0) {
      return null;
    }

    return double.parse(((likes / total) * 5).toStringAsFixed(1));
  }

  static int? _ratingCount(Map<String, Object?> book) {
    final likes = _intValue(book['likes']) ?? 0;
    final dislikes = _intValue(book['dislikes']) ?? 0;
    final total = likes + dislikes;
    return total <= 0 ? null : total;
  }

  static String _stripMarkup(String value) {
    return SourceParserHelpers.normalizeWhitespace(
      value
          .replaceAll(RegExp(r'\[\/?[^\]]+\]'), ' ')
          .replaceAll(RegExp(r'<[^>]+>'), ' '),
    );
  }

  static String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(_string(value));
  }

  static double? _numValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(_string(value).replaceAll(',', '.'));
  }

  static String _string(Object? value) {
    return SourceParserHelpers.normalizeWhitespace(value?.toString() ?? '');
  }
}
