import 'dart:convert';

import 'package:html/parser.dart' as html_parser;

import '../../domain/models/audio_track.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_version.dart';
import '../../domain/models/chapter.dart';
import '../source_models.dart';
import '../source_parser_helpers.dart';
import 'yakniga_graphql_client.dart';

class YaknigaMapper {
  YaknigaMapper({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const sourceId = 'yakniga';
  static const sourceName = 'Yakniga';
  static final sourceBaseUri = Uri.parse('https://yakniga.org/');

  final DateTime Function() _clock;

  SourceBookRef bookRef(Map<String, Object?> book) {
    final id = _bookId(book);
    return SourceBookRef(
      sourceId: sourceId,
      sourceBookId: id,
      sourceUri: _bookUri(book),
    );
  }

  List<BookSearchResult> searchResults(List<Object?> items) {
    return [
      for (final item in items)
        if (item is Map<String, Object?> &&
            _string(item['__typename']) == 'Book')
          searchResult(item),
    ];
  }

  BookSearchResult searchResult(Map<String, Object?> book) {
    final blocked = _boolValue(book['copyrightBlock']);
    final paid = book['price'] != null;

    return BookSearchResult(
      ref: bookRef(book),
      sourceName: sourceName,
      title: _string(book['title']),
      author: _people(book['authors'], fallback: _string(book['authorName'])),
      narrator: _people(book['readers']),
      series: _entityName(book['series']),
      seriesNumber: _seriesNumber(book['seriesNum']),
      genres: _genres(book['genres']),
      coverUri: _coverUri(book),
      duration: _secondsDuration(book['duration']),
      year: _year(book['publishDate']),
      chapterCount: _intValue(book['chaptersCount']),
      isFull: blocked ? false : (_intValue(book['chaptersCount']) ?? 0) > 0,
      isFree: !blocked && !paid,
      accessType: blocked
          ? AccessType.unknown
          : paid
          ? AccessType.paid
          : AccessType.free,
      ratingValue: _ratingValue(book['rating']),
      score: _ratingValue(book['rating']),
    );
  }

  BookVersionDetails bookDetails(Map<String, Object?> book) {
    final now = _clock();
    final id = _bookId(book);
    final title = _string(book['title']);
    final normalizedTitle = SourceParserHelpers.normalizeTitle(title);
    final chapters = _chapters(book);
    final blocked = _boolValue(book['copyrightBlock']);
    final paid = book['price'] != null;
    final hasPlayableChapters = !blocked && chapters.isNotEmpty;
    final description = _description(book);
    final sourceUri = _bookUri(book);
    final authors = _peopleList(
      book['authors'],
      fallback: _string(book['authorName']),
    );

    return BookVersionDetails(
      ref: bookRef(book),
      book: Book(
        id: 'yakniga-book-$id',
        normalizedTitle: normalizedTitle,
        displayTitle: title,
        authors: authors,
        seriesTitle: _entityName(book['series']),
        seriesNumber: _seriesNumber(book['seriesNum']),
        year: _year(book['publishDate']),
        bestCoverUrl: _coverUri(book)?.toString(),
        bestDescription: description,
        createdAt: now,
        updatedAt: now,
      ),
      version: BookVersion(
        id: 'yakniga-$id',
        bookId: 'yakniga-book-$id',
        sourceId: sourceId,
        sourceBookId: id,
        sourceUrl: sourceUri.toString(),
        title: title,
        normalizedTitle: normalizedTitle,
        authors: authors,
        narrators: _peopleList(book['readers']),
        seriesTitle: _entityName(book['series']),
        seriesNumber: _seriesNumber(book['seriesNum']),
        genres: _genres(book['genres']),
        description: description,
        coverUrl: _coverUri(book)?.toString(),
        durationMs: _secondsDuration(book['duration'])?.inMilliseconds,
        durationText: _durationText(book['duration']),
        publishedYear: _year(book['publishDate']),
        ratingValue: _ratingValue(book['rating']),
        accessType: blocked
            ? AccessType.unknown
            : paid
            ? AccessType.paid
            : AccessType.free,
        playbackAccess: hasPlayableChapters
            ? PlaybackAccess.streamAndDownload
            : PlaybackAccess.none,
        isFull: hasPlayableChapters,
        isFragment: false,
        isPaid: paid,
        isAccessibleForFree: !blocked && !paid,
        canStream: hasPlayableChapters,
        canDownload: hasPlayableChapters,
        rawSourceDataJson: jsonEncode({
          'sourceUrl': sourceUri.toString(),
          'copyrightBlock': blocked,
          'price': book['price'],
        }),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  List<Chapter> chapters(Map<String, Object?> book) {
    final now = _clock();
    final id = _bookId(book);
    final sourceUri = _bookUri(book);
    final items = _chapters(book);
    return [
      for (var index = 0; index < items.length; index++)
        _chapter(book, items[index], index, now, sourceUri, id),
    ];
  }

  List<AudioTrack> audioTracks(Map<String, Object?> book) {
    return [
      for (final chapter in chapters(book))
        AudioTrack(
          id: '${chapter.id}-track',
          chapterId: chapter.id,
          sourceId: sourceId,
          index: 1,
          title: chapter.title,
          durationMs: chapter.durationMs,
          mediaRef: chapter.streamRef ?? '',
          directUrl: chapter.streamRef,
          headersJson: jsonEncode(mediaHeadersForChapter(chapter)),
          format: chapter.audioFormat,
          mimeType: chapter.mimeType,
          rawSourceDataJson: chapter.rawSourceDataJson,
        ),
    ];
  }

  static Map<String, String> mediaHeadersForChapter(Chapter chapter) {
    return YaknigaGraphQlClient.mediaHeaders(
      referer: _chapterSourceUrl(chapter) ?? sourceBaseUri.toString(),
    );
  }

  Chapter _chapter(
    Map<String, Object?> book,
    Map<String, Object?> item,
    int fallbackIndex,
    DateTime now,
    Uri sourceUri,
    String bookId,
  ) {
    final sourceChapterId = _firstNonEmpty([
      _string(item['id']),
      '${fallbackIndex + 1}',
    ]);
    final title = _firstNonEmpty([
      _string(item['name']),
      'Глава ${fallbackIndex + 1}',
    ]);
    final streamRef = _streamUri(item)?.toString();
    final format = _audioFormat(streamRef ?? '');

    return Chapter(
      id: 'yakniga-$bookId-chapter-$sourceChapterId',
      bookVersionId: 'yakniga-$bookId',
      sourceId: sourceId,
      sourceBookId: bookId,
      sourceChapterId: sourceChapterId,
      index: (_intValue(item['pos']) ?? fallbackIndex) + 1,
      title: title,
      normalizedTitle: SourceParserHelpers.normalizeTitle(title),
      durationMs: _secondsDuration(item['duration'])?.inMilliseconds,
      streamRef: streamRef,
      cachedStreamUrl: streamRef,
      audioFormat: format,
      mimeType: _mimeType(format),
      rawSourceDataJson: jsonEncode({
        ...item,
        'sourceUrl': sourceUri.toString(),
        'bookId': _bookId(book),
      }),
      createdAt: now,
      updatedAt: now,
    );
  }

  static List<Map<String, Object?>> _chapters(Map<String, Object?> book) {
    final chapters = book['chapters'];
    if (chapters is! Map<String, Object?>) {
      return const [];
    }

    final collection = chapters['collection'];
    if (collection is! List) {
      return const [];
    }

    final items = [
      for (final item in collection)
        if (item is Map<String, Object?> &&
            _streamUri(item)?.toString().isNotEmpty == true)
          item,
    ];
    items.sort((left, right) {
      final leftPos = _intValue(left['pos']) ?? 1 << 30;
      final rightPos = _intValue(right['pos']) ?? 1 << 30;
      return leftPos.compareTo(rightPos);
    });
    return items;
  }

  static Uri _bookUri(Map<String, Object?> book) {
    final aliasName = _string(book['aliasName']);
    final authorAlias = _string(book['authorAlias']);
    if (aliasName.isNotEmpty && authorAlias.isNotEmpty) {
      return sourceBaseUri.resolve('$authorAlias/$aliasName');
    }
    if (aliasName.isNotEmpty) {
      return sourceBaseUri.resolve(aliasName);
    }
    return sourceBaseUri.resolve(_bookId(book));
  }

  static Uri? _coverUri(Map<String, Object?> book) {
    return SourceParserHelpers.safeResolveUri(
      sourceBaseUri,
      _firstNonEmpty([
        _string(book['cover360']),
        _string(book['cover180']),
        _string(book['cover110']),
        _string(book['cover']),
        _string(book['downloadedCover']),
      ]),
    );
  }

  static Uri? _streamUri(Map<String, Object?> chapter) {
    return SourceParserHelpers.safeResolveUri(
      sourceBaseUri,
      _string(chapter['fileUrl']),
    );
  }

  static String _description(Map<String, Object?> book) {
    return _stripMarkup(
      _firstNonEmpty([
        _string(book['description']),
        _string(book['summary']),
        _string(book['summaryShort']),
      ]),
    );
  }

  static List<String> _genres(Object? value) {
    if (value is! Map<String, Object?>) {
      return const [];
    }
    final collection = value['collection'];
    if (collection is! List) {
      return const [];
    }
    return [
      for (final item in collection)
        if (_entityName(item).isNotEmpty) _entityName(item),
    ];
  }

  static String _people(Object? value, {String fallback = ''}) {
    return _peopleList(value, fallback: fallback).join(', ');
  }

  static List<String> _peopleList(Object? value, {String fallback = ''}) {
    final names = <String>[];
    final seen = <String>{};
    if (value is List) {
      for (final item in value) {
        final name = _entityName(item);
        final key = SourceParserHelpers.normalizeTitle(name);
        if (name.isNotEmpty && seen.add(key)) {
          names.add(name);
        }
      }
    }
    final fallbackName = SourceParserHelpers.normalizeWhitespace(fallback);
    final fallbackKey = SourceParserHelpers.normalizeTitle(fallbackName);
    if (names.isEmpty && fallbackName.isNotEmpty && seen.add(fallbackKey)) {
      names.add(fallbackName);
    }
    return names;
  }

  static String _entityName(Object? value) {
    if (value is! Map<String, Object?>) {
      return '';
    }
    return _string(value['name']);
  }

  static String _bookId(Map<String, Object?> book) {
    return _firstNonEmpty([_string(book['id']), _string(book['aliasName'])]);
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

  static int? _year(Object? value) {
    final raw = _string(value);
    if (raw.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return parsed.year;
    }
    return SourceParserHelpers.parseYear(raw);
  }

  static double? _ratingValue(Object? value) {
    final rating = _numValue(value);
    if (rating == null || rating <= 0) {
      return null;
    }
    final normalized = rating > 5 ? rating / 2 : rating;
    return double.parse(normalized.toStringAsFixed(1));
  }

  static double? _seriesNumber(Object? value) {
    return SourceParserHelpers.parseSeriesNumber(_string(value));
  }

  static String _stripMarkup(String value) {
    return SourceParserHelpers.normalizeWhitespace(
      value.replaceAll(RegExp(r'<[^>]+>'), ' '),
    );
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

  static bool _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    final normalized = _string(value).toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static String _audioFormat(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final match = RegExp(
      r'\.([a-z0-9]{2,5})$',
      caseSensitive: false,
    ).firstMatch(path);
    return match?.group(1)?.toLowerCase() ?? 'mp3';
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

  static String? _chapterSourceUrl(Chapter chapter) {
    final raw = chapter.rawSourceDataJson;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        final sourceUrl = decoded['sourceUrl'];
        if (sourceUrl is String && sourceUrl.isNotEmpty) {
          return sourceUrl;
        }
      }
    } on Object {
      return null;
    }
    return null;
  }

  static String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String _string(Object? value) {
    final raw = value?.toString() ?? '';
    final decoded = html_parser.parseFragment(raw).text ?? raw;
    return SourceParserHelpers.normalizeWhitespace(decoded);
  }
}
