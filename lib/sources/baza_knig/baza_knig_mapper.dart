import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../domain/models/audio_track.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_version.dart';
import '../../domain/models/chapter.dart';
import '../source_models.dart';
import '../source_parser_helpers.dart';

class BazaKnigMapper {
  BazaKnigMapper({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const sourceId = 'baza_knig';
  static const sourceName = 'Baza Knig';
  static const _strDecodeAlphabet =
      'Z83UhncLHApBrM7GvdqT4tNWRjemgak9oVzwK1PXDfY5bQOSlsF26yi0JCIuxE+/=';
  static final sourceBaseUri = Uri.parse('https://baza-knig.top/');

  final DateTime Function() _clock;

  List<BookSearchResult> searchResults(String html) {
    final document = html_parser.parse(html);
    return [
      for (final item in document.querySelectorAll('.short'))
        ?_searchResult(item),
    ];
  }

  BookVersionDetails bookDetails(String html, SourceBookRef ref) {
    final document = html_parser.parse(html);
    final now = _clock();
    final sourceUri = _sourceUri(ref);
    final sourceBookId = _sourceBookIdFromUri(sourceUri) ?? ref.sourceBookId;
    final idSegment = _idSegment(sourceBookId);
    final tracks = playerTracks(html);
    final hasPlayableTracks = tracks.any(
      (track) => _mediaUrl(track).isNotEmpty,
    );
    final authors = _labelPeople(document, ['Автор']);
    final narrators = _labelPeople(document, ['Читает', 'Исполнитель']);
    final title = _cleanTitle(
      _firstNonEmpty([_text(document, '.full-title'), _text(document, 'h1')]),
      authors,
    );
    final description = _firstNonEmpty([
      _text(document, '.short-text'),
      _text(document, '.full-text'),
    ]);
    final seriesValue = _seriesValue(document);
    final duration = SourceParserHelpers.parseDuration(
      _labelValue(document, ['Время звучания', 'Длительность']),
    );

    return BookVersionDetails(
      ref: SourceBookRef(
        sourceId: sourceId,
        sourceBookId: sourceBookId,
        sourceUri: sourceUri,
      ),
      book: Book(
        id: 'baza-knig-book-$idSegment',
        normalizedTitle: SourceParserHelpers.normalizeTitle(title),
        displayTitle: title,
        authors: authors,
        seriesTitle: _seriesFromValue(seriesValue),
        seriesNumber: _seriesNumberFromValue(seriesValue),
        bestCoverUrl: _coverUri(document)?.toString(),
        bestDescription: description,
        createdAt: now,
        updatedAt: now,
      ),
      version: BookVersion(
        id: 'baza-knig-$idSegment',
        bookId: 'baza-knig-book-$idSegment',
        sourceId: sourceId,
        sourceBookId: sourceBookId,
        sourceUrl: sourceUri.toString(),
        title: title,
        normalizedTitle: SourceParserHelpers.normalizeTitle(title),
        authors: authors,
        narrators: narrators,
        seriesTitle: _seriesFromValue(seriesValue),
        seriesNumber: _seriesNumberFromValue(seriesValue),
        genres: _genres(document),
        description: description,
        coverUrl: _coverUri(document)?.toString(),
        durationMs: duration?.inMilliseconds,
        durationText: _durationText(duration),
        publishedYear: _year(document),
        ratingValue: _rating(document),
        ratingCount: _ratingCount(document),
        accessType: hasPlayableTracks ? AccessType.free : AccessType.unknown,
        playbackAccess: hasPlayableTracks
            ? PlaybackAccess.streamAndDownload
            : PlaybackAccess.none,
        isFull: hasPlayableTracks,
        isFragment: false,
        isPaid: false,
        isAccessibleForFree: hasPlayableTracks,
        canStream: hasPlayableTracks,
        canDownload: hasPlayableTracks,
        rawSourceDataJson: jsonEncode({
          'sourceUrl': sourceUri.toString(),
          'playerTracks': tracks.length,
          'likes': _voteCount(document, '1'),
          'dislikes': _voteCount(document, '-1'),
        }),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  List<Chapter> chapters(String html, SourceBookRef ref) {
    final now = _clock();
    final sourceUri = _sourceUri(ref);
    final sourceBookId = _sourceBookIdFromUri(sourceUri) ?? ref.sourceBookId;
    final idSegment = _idSegment(sourceBookId);
    final tracks = playerTracks(html);

    return [
      for (var index = 0; index < tracks.length; index++)
        if (_mediaUrl(tracks[index]) case final mediaUrl
            when mediaUrl.isNotEmpty)
          Chapter(
            id: 'baza-knig-$idSegment-chapter-${_trackId(tracks[index], index)}',
            bookVersionId: 'baza-knig-$idSegment',
            sourceId: sourceId,
            sourceBookId: sourceBookId,
            sourceChapterId: _trackId(tracks[index], index),
            index: index + 1,
            title: _trackTitle(tracks[index], index),
            normalizedTitle: SourceParserHelpers.normalizeTitle(
              _trackTitle(tracks[index], index),
            ),
            durationMs: _trackDurationMs(tracks[index]),
            streamRef: mediaUrl,
            cachedStreamUrl: mediaUrl,
            audioFormat: _audioFormat(mediaUrl),
            mimeType: _mimeType(_audioFormat(mediaUrl)),
            rawSourceDataJson: jsonEncode(tracks[index]),
            createdAt: now,
            updatedAt: now,
          ),
    ];
  }

  List<AudioTrack> audioTracks(List<Chapter> chapters) {
    return [
      for (final chapter in chapters)
        AudioTrack(
          id: '${chapter.id}-track',
          chapterId: chapter.id,
          sourceId: sourceId,
          index: 1,
          title: chapter.title,
          durationMs: chapter.durationMs,
          mediaRef: chapter.streamRef ?? '',
          directUrl: chapter.streamRef,
          headersJson: jsonEncode(
            mediaHeadersForSourceBookId(chapter.sourceBookId ?? ''),
          ),
          format: chapter.audioFormat,
          mimeType: chapter.mimeType,
          rawSourceDataJson: chapter.rawSourceDataJson,
        ),
    ];
  }

  List<Map<String, Object?>> playerTracks(String html) {
    final tracks = <Map<String, Object?>>[];
    final seenMediaUrls = <String>{};

    void addTrack(Map<String, Object?> track) {
      final mediaUrl = _mediaUrl(track);
      if (mediaUrl.isNotEmpty && seenMediaUrls.add(mediaUrl)) {
        tracks.add(track);
      }
    }

    void addDecoded(Object? decoded) {
      if (decoded is List) {
        for (final item in decoded) {
          addDecoded(item);
        }
      } else if (decoded is Map) {
        final track = decoded.cast<String, Object?>();
        addTrack(track);
      }
    }

    final strDecodePattern = RegExp(
      r'''\bstrDecode\s*\(\s*["']([\s\S]*?)["']\s*\)''',
      caseSensitive: false,
    );
    for (final match in strDecodePattern.allMatches(html)) {
      final encoded = match.group(1);
      if (encoded == null || encoded.isEmpty) {
        continue;
      }
      try {
        addDecoded(jsonDecode(_strDecode(encoded)));
      } on Object catch (error) {
        throw SourceException(
          sourceId: sourceId,
          kind: SourceErrorKind.parser,
          message: 'Baza Knig strDecode Playerjs data is invalid.',
          cause: error,
        );
      }
    }

    final filePattern = RegExp(r'\bfile\s*:\s*\[', caseSensitive: false);
    for (final match in filePattern.allMatches(html)) {
      final openBracket = html.indexOf('[', match.start);
      if (openBracket < 0) {
        continue;
      }
      final jsonArray = _balanced(html, openBracket, '[', ']');
      if (jsonArray.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(jsonArray);
        if (decoded is! List) {
          continue;
        }
        addDecoded(decoded);
      } on Object catch (error) {
        throw SourceException(
          sourceId: sourceId,
          kind: SourceErrorKind.parser,
          message: 'Baza Knig Playerjs data is invalid.',
          cause: error,
        );
      }
    }
    return tracks;
  }

  static String _strDecode(String encoded) {
    final cleaned = encoded.replaceAll(
      RegExp(r'[^a-z0-9+/=]', caseSensitive: false),
      '',
    );
    final bytes = <int>[];
    for (var index = 0; index < cleaned.length;) {
      final first = _strDecodeValue(cleaned[index++]);
      if (index >= cleaned.length) {
        break;
      }
      final second = _strDecodeValue(cleaned[index++]);
      final third = index < cleaned.length
          ? _strDecodeValue(cleaned[index++])
          : 64;
      final fourth = index < cleaned.length
          ? _strDecodeValue(cleaned[index++])
          : 64;
      if (first < 0 || second < 0) {
        continue;
      }
      bytes.add(((first << 2) | (second >> 4)) & 0xff);
      if (third >= 0 && third < 64) {
        bytes.add((((second & 15) << 4) | (third >> 2)) & 0xff);
      }
      if (fourth >= 0 && fourth < 64) {
        bytes.add((((third & 3) << 6) | fourth) & 0xff);
      }
    }
    return utf8.decode(bytes);
  }

  static int _strDecodeValue(String char) {
    return _strDecodeAlphabet.indexOf(char);
  }

  static Map<String, String> mediaHeadersForSourceBookId(String sourceBookId) {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/125.0 Safari/537.36',
      'Accept': 'audio/mpeg,audio/*,*/*;q=0.8',
      'Referer': sourceBaseUri.resolve(sourceBookId).toString(),
    };
  }

  BookSearchResult? _searchResult(dom.Element item) {
    final rawUrl = _firstNonEmpty([
      _attr(item, '.short-title[href]', 'href'),
      _attr(item, '.short-title a[href]', 'href'),
      _attr(item, 'a[href]', 'href'),
    ]);
    final sourceUri = SourceParserHelpers.safeResolveUri(sourceBaseUri, rawUrl);
    final sourceBookId = _sourceBookIdFromUri(sourceUri);
    if (sourceUri == null || sourceBookId == null) {
      return null;
    }
    final authors = _labelPeople(item, ['Автор']);
    final title = _cleanTitle(
      _firstNonEmpty([
        _text(item, '.short-title'),
        _attr(item, 'a[title]', 'title'),
      ]),
      authors,
    );
    if (title.isEmpty) {
      return null;
    }
    final seriesValue = _labelPeople(item, ['Цикл', 'Серия']).join(', ');

    return BookSearchResult(
      ref: SourceBookRef(
        sourceId: sourceId,
        sourceBookId: sourceBookId,
        sourceUri: sourceUri,
      ),
      sourceName: sourceName,
      title: title,
      author: authors.join(', '),
      narrator: _labelPeople(item, ['Читает', 'Исполнитель']).join(', '),
      series: _seriesFromValue(seriesValue),
      seriesNumber: _seriesNumberFromValue(seriesValue),
      genres: _genres(item),
      coverUri: _coverUri(item),
      duration: SourceParserHelpers.parseDuration(
        _labelValue(item, ['Время звучания', 'Длительность']),
      ),
      year: _year(item),
      ratingValue: _rating(item),
      ratingCount: _ratingCount(item),
      isFull: true,
      isFree: true,
      accessType: AccessType.free,
    );
  }

  static String _seriesValue(Object root) {
    return _labelPeople(root, ['Цикл', 'Серия']).join(', ');
  }

  static String _seriesFromValue(String value) {
    return SourceParserHelpers.normalizeWhitespace(
      value.replaceFirst(RegExp(r'\(\d+(?:[.,]\d+)*\)\s*$'), ''),
    );
  }

  static double? _seriesNumberFromValue(String value) {
    final match = RegExp(r'\((\d+(?:[.,]\d+)*)\)\s*$').firstMatch(value);
    return match == null
        ? null
        : SourceParserHelpers.parseSeriesNumber(match.group(1)!);
  }

  static List<String> _genres(Object document) {
    final values = _labelPeople(document, ['Жанр', 'Жанры']);
    if (values.isNotEmpty) {
      return _splitLabels(values.join(', '));
    }
    return _splitLabels(_labelValue(document, ['Жанр', 'Жанры']));
  }

  static Uri? _coverUri(Object root) {
    final value = _firstNonEmpty([
      _attr(root, '.full-img img', 'src'),
      _attr(root, '.short-img img', 'src'),
      _attr(root, 'img[data-src]', 'data-src'),
      _attr(root, 'img[src]', 'src'),
    ]);
    return SourceParserHelpers.safeResolveUri(sourceBaseUri, value);
  }

  static List<String> _labelPeople(Object root, List<String> labels) {
    final result = <String>[];
    final seen = <String>{};
    for (final line in _querySelectorAll(
      root,
      '.full-items > *, .short-items > *, .full-info > *, .short-info > *',
    )) {
      final normalizedText = SourceParserHelpers.normalizeTitle(line.text);
      final matches = labels.any(
        (label) => normalizedText.startsWith(
          SourceParserHelpers.normalizeTitle(label),
        ),
      );
      if (!matches) {
        continue;
      }
      final links = line.querySelectorAll('a');
      if (links.isEmpty) {
        final value = _cleanPersonValue(_lineValue(line.text));
        final key = SourceParserHelpers.normalizeTitle(value);
        if (value.isNotEmpty && seen.add(key)) {
          result.add(value);
        }
      } else {
        for (final link in links) {
          final value = _cleanPersonValue(
            SourceParserHelpers.normalizeWhitespace(link.text),
          );
          final key = SourceParserHelpers.normalizeTitle(value);
          if (value.isNotEmpty && seen.add(key)) {
            result.add(value);
          }
        }
      }
    }
    return result;
  }

  static String _labelValue(Object root, List<String> labels) {
    for (final line in _querySelectorAll(
      root,
      '.full-items > *, .short-items > *, .full-info > *, .short-info > *',
    )) {
      final normalizedText = SourceParserHelpers.normalizeTitle(line.text);
      final matches = labels.any(
        (label) => normalizedText.startsWith(
          SourceParserHelpers.normalizeTitle(label),
        ),
      );
      if (matches) {
        return _lineValue(line.text);
      }
    }
    return '';
  }

  static String _lineValue(String text) {
    final parts = text.split(RegExp(r':'));
    if (parts.length < 2) {
      return SourceParserHelpers.normalizeWhitespace(text);
    }
    return SourceParserHelpers.normalizeWhitespace(parts.skip(1).join(':'));
  }

  static String _cleanPersonValue(String value) {
    final withoutVoiceNotes = value.replaceAll(
      RegExp(r'\s*,?\s*\([^)]*озвуч[^)]*\)', caseSensitive: false),
      ' ',
    );
    return SourceParserHelpers.normalizeWhitespace(
      withoutVoiceNotes.replaceAll(RegExp(r'\s*,\s*$'), ''),
    );
  }

  static String _cleanTitle(String value, List<String> authors) {
    var title = SourceParserHelpers.normalizeWhitespace(value)
        .replaceFirst(
          RegExp(r'^скачать\s+аудиокнигу\s+', caseSensitive: false),
          '',
        )
        .replaceFirst(RegExp(r'^скачать\s+', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^аудиокнига\s+', caseSensitive: false), '')
        .replaceFirst(
          RegExp(r'^слушать\s+аудиокнигу\s+', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'^смотреть\s+аудиокнигу\s+', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'^скачать\s+аудиокнигу\s+', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'^Скачать\s+аудиокнигу\s+', caseSensitive: false),
          '',
        );
    title = SourceParserHelpers.normalizeWhitespace(
      title.replaceFirst(
        RegExp(r'\s+слушать онлайн.*$', caseSensitive: false),
        '',
      ),
    );

    final authorSplit = RegExp(r'\s+[-–—]\s+(.+)$').firstMatch(title);
    if (authorSplit != null) {
      final suffix = SourceParserHelpers.normalizeWhitespace(
        authorSplit.group(1)!.replaceAll(RegExp(r'\s*»\s*$'), ''),
      );
      if (authors.any((author) => _samePersonName(suffix, author))) {
        title = title.substring(0, authorSplit.start);
      }
    }

    return SourceParserHelpers.normalizeWhitespace(title);
  }

  static bool _samePersonName(String left, String right) {
    final leftTokens = SourceParserHelpers.normalizeTitle(
      left,
    ).split(' ').where((token) => token.isNotEmpty).toList()..sort();
    final rightTokens = SourceParserHelpers.normalizeTitle(
      right,
    ).split(' ').where((token) => token.isNotEmpty).toList()..sort();
    if (leftTokens.isEmpty || leftTokens.length != rightTokens.length) {
      return false;
    }
    for (var index = 0; index < leftTokens.length; index++) {
      if (leftTokens[index] != rightTokens[index]) {
        return false;
      }
    }
    return true;
  }

  static double? _rating(Object root) {
    final likes = _voteCount(root, '1');
    final dislikes = _voteCount(root, '-1');
    final total = likes + dislikes;
    if (total <= 0) {
      return null;
    }
    return double.parse(((likes / total) * 5).toStringAsFixed(1));
  }

  static int? _ratingCount(Object root) {
    final total = _voteCount(root, '1') + _voteCount(root, '-1');
    return total <= 0 ? null : total;
  }

  static int _voteCount(Object root, String value) {
    for (final link in _querySelectorAll(root, '.short-rate a')) {
      final action = link.attributes['onclick'] ?? '';
      final singleQuote = "doRate('$value'";
      final doubleQuote = 'doRate("$value"';
      if (!action.contains(singleQuote) && !action.contains(doubleQuote)) {
        continue;
      }
      return _humanCount(link.text);
    }
    final attr = value == '1' ? 'data-likes-id' : 'data-dislikes-id';
    for (final span in _querySelectorAll(root, 'span[$attr]')) {
      return _humanCount(span.text);
    }
    return 0;
  }

  static int? _year(Object root) {
    final explicit = SourceParserHelpers.parseYear(_labelValue(root, ['Год']));
    if (explicit != null) {
      return explicit;
    }
    final added = _labelValue(root, ['Добавлена']);
    final match = RegExp(
      r'\b\d{1,2}\.\d{1,2}\.(\d{2}|\d{4})\b',
    ).firstMatch(added);
    if (match == null) {
      return null;
    }
    final rawYear = int.tryParse(match.group(1)!);
    if (rawYear == null) {
      return null;
    }
    return rawYear < 100 ? 2000 + rawYear : rawYear;
  }

  static int _humanCount(String value) {
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)([kкmм])?',
    ).firstMatch(value.replaceAll(' ', ''));
    if (match == null) {
      return 0;
    }
    var parsed = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
    final suffix = match.group(2)?.toLowerCase();
    if (suffix == 'k' || suffix == 'к') {
      parsed *= 1000;
    } else if (suffix == 'm' || suffix == 'м') {
      parsed *= 1000000;
    }
    return parsed.round();
  }

  static String _mediaUrl(Map<String, Object?> item) {
    final raw = _firstNonEmpty([
      _string(item['file']),
      _string(item['src']),
      _string(item['url']),
    ]);
    final uri = SourceParserHelpers.safeResolveUri(sourceBaseUri, raw);
    if (uri == null || !_isAllowedMediaUri(uri)) {
      return '';
    }
    return uri.toString();
  }

  static bool _isAllowedMediaUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'abooka.casa' || host.endsWith('.abooka.casa')) {
      return true;
    }
    final isArchive = host == 'archive.org' || host.endsWith('.archive.org');
    if (!isArchive) {
      return false;
    }
    return uri.path.startsWith('/download/') &&
        RegExp(
          r'\.(mp3|m4a|ogg|aac)(?:$|\?)',
          caseSensitive: false,
        ).hasMatch(uri.path);
  }

  static String _trackTitle(Map<String, Object?> item, int index) {
    return _firstNonEmpty([
      _string(item['title']),
      _string(item['name']),
      'Глава ${index + 1}',
    ]);
  }

  static String _trackId(Map<String, Object?> item, int index) {
    return _firstNonEmpty([
      _string(item['id']),
      _string(item['fileId']),
      '${index + 1}',
    ]);
  }

  static int? _trackDurationMs(Map<String, Object?> item) {
    final seconds = _seconds(item['duration'] ?? item['time']);
    return seconds <= 0 ? null : seconds * 1000;
  }

  static int _seconds(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    final raw = _string(value);
    final duration = SourceParserHelpers.parseDuration(raw);
    if (duration != null) {
      return duration.inSeconds;
    }
    return int.tryParse(raw) ?? 0;
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

  static String? _durationText(Duration? duration) {
    if (duration == null || duration <= Duration.zero) {
      return null;
    }
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return minutes > 0 ? '$hours ч $minutes мин' : '$hours ч';
    }
    return '$minutes мин';
  }

  static Uri _sourceUri(SourceBookRef ref) {
    return ref.sourceUri ?? sourceBaseUri.resolve(ref.sourceBookId);
  }

  static String? _sourceBookIdFromUri(Uri? uri) {
    if (uri == null) {
      return null;
    }
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return segments.isEmpty ? null : segments.join('/');
  }

  static String _idSegment(String sourceBookId) {
    return sourceBookId
        .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .toLowerCase();
  }

  static List<String> _splitLabels(String value) {
    return value
        .split(RegExp(r'\s*,\s*|\s*/\s*'))
        .map(SourceParserHelpers.normalizeWhitespace)
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _text(Object root, String selector) {
    return SourceParserHelpers.normalizeWhitespace(
      _querySelector(root, selector)?.text ?? '',
    );
  }

  static String _attr(Object root, String selector, String name) {
    return SourceParserHelpers.normalizeWhitespace(
      _querySelector(root, selector)?.attributes[name] ?? '',
    );
  }

  static dom.Element? _querySelector(Object root, String selector) {
    return switch (root) {
      dom.Document() => root.querySelector(selector),
      dom.Element() => root.querySelector(selector),
      _ => null,
    };
  }

  static List<dom.Element> _querySelectorAll(Object root, String selector) {
    return switch (root) {
      dom.Document() => root.querySelectorAll(selector),
      dom.Element() => root.querySelectorAll(selector),
      _ => const <dom.Element>[],
    };
  }

  static String _balanced(
    String input,
    int openIndex,
    String open,
    String close,
  ) {
    var depth = 0;
    var inString = false;
    var quote = '';
    var escaped = false;
    for (var index = openIndex; index < input.length; index++) {
      final char = input[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == quote) {
          inString = false;
        }
        continue;
      }
      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
        continue;
      }
      if (char == open) {
        depth++;
      } else if (char == close) {
        depth--;
        if (depth == 0) {
          return input.substring(openIndex, index + 1);
        }
      }
    }
    return '';
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
    return SourceParserHelpers.normalizeWhitespace(value?.toString() ?? '');
  }
}
