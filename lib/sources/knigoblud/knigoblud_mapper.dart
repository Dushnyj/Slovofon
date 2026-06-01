import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../domain/models/audio_track.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_version.dart';
import '../../domain/models/chapter.dart';
import '../source_models.dart';
import '../source_parser_helpers.dart';

class KnigobludMapper {
  KnigobludMapper({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const sourceId = 'knigoblud';
  static const sourceName = 'Knigoblud';
  static final sourceBaseUri = Uri.parse('https://www.knigoblud.club/');

  final DateTime Function() _clock;

  List<BookSearchResult> searchResults(String html) {
    final document = html_parser.parse(html);
    return [
      for (final item in document.querySelectorAll('.bookListItem'))
        ?_searchResult(item),
    ];
  }

  BookVersionDetails bookDetails(String html, SourceBookRef ref) {
    final document = html_parser.parse(html);
    final now = _clock();
    final sourceUri = _sourceUri(ref);
    final sourceBookId = _sourceBookIdFromUri(sourceUri) ?? ref.sourceBookId;
    final playerData = _playerData(html);
    final playlist = _playlist(playerData);
    final blocked = playerData['blocked'] == true;
    final hasPlayableTracks =
        !blocked && playlist.any((track) => _mediaUrl(track).isNotEmpty);
    final title = _firstNonEmpty([
      _text(document, '.BookTitle'),
      _text(document, 'h1'),
    ]);
    final authors = _labelPeople(document, ['Автор']);
    final narrators = _labelPeople(document, ['Читает', 'Исполнитель']);
    final description = _text(document, '.BookDescriptionContent');
    final duration = _duration(document) ?? _tracksDuration(playlist);

    return BookVersionDetails(
      ref: SourceBookRef(
        sourceId: sourceId,
        sourceBookId: sourceBookId,
        sourceUri: sourceUri,
      ),
      book: Book(
        id: 'knigoblud-book-$sourceBookId',
        normalizedTitle: SourceParserHelpers.normalizeTitle(title),
        displayTitle: title,
        authors: authors,
        seriesTitle: _series(document),
        seriesNumber: _seriesNumber(document, sourceUri),
        bestCoverUrl: _coverUri(document)?.toString(),
        bestDescription: description,
        createdAt: now,
        updatedAt: now,
      ),
      version: BookVersion(
        id: 'knigoblud-$sourceBookId',
        bookId: 'knigoblud-book-$sourceBookId',
        sourceId: sourceId,
        sourceBookId: sourceBookId,
        sourceUrl: sourceUri.toString(),
        title: title,
        normalizedTitle: SourceParserHelpers.normalizeTitle(title),
        authors: authors,
        narrators: narrators,
        seriesTitle: _series(document),
        seriesNumber: _seriesNumber(document, sourceUri),
        genres: _genres(document),
        description: description,
        coverUrl: _coverUri(document)?.toString(),
        durationMs: duration?.inMilliseconds,
        durationText: _durationText(duration),
        publishedYear: SourceParserHelpers.parseYear(
          _labelValue(document, ['Год']),
        ),
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
          'uuid': playerData['uuid'],
          'playlist': playlist.length,
          'blocked': blocked,
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
    final playerData = _playerData(html);
    if (playerData['blocked'] == true) {
      return const [];
    }
    final playlist = _playlist(playerData);
    return [
      for (var index = 0; index < playlist.length; index++)
        if (_mediaUrl(playlist[index]) case final mediaUrl
            when mediaUrl.isNotEmpty)
          Chapter(
            id: 'knigoblud-$sourceBookId-chapter-${_trackId(playlist[index], index)}',
            bookVersionId: 'knigoblud-$sourceBookId',
            sourceId: sourceId,
            sourceBookId: sourceBookId,
            sourceChapterId: _trackId(playlist[index], index),
            index: index + 1,
            title: _trackTitle(playlist[index], index),
            normalizedTitle: SourceParserHelpers.normalizeTitle(
              _trackTitle(playlist[index], index),
            ),
            durationMs: _trackDurationMs(playlist[index]),
            streamRef: mediaUrl,
            cachedStreamUrl: mediaUrl,
            audioFormat: _audioFormat(mediaUrl),
            mimeType: _mimeType(_audioFormat(mediaUrl)),
            rawSourceDataJson: jsonEncode(playlist[index]),
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
      _attr(item, '.bookListItemCoverNameText[href]', 'href'),
      _attr(item, '.bookListItemCoverNameText a[href]', 'href'),
      _attr(item, '.bookListItemCover[href]', 'href'),
      _attr(item, 'a[href]', 'href'),
    ]);
    final sourceUri = SourceParserHelpers.safeResolveUri(sourceBaseUri, rawUrl);
    final sourceBookId = _sourceBookIdFromUri(sourceUri);
    if (sourceUri == null || sourceBookId == null) {
      return null;
    }
    final title = _firstNonEmpty([
      _text(item, '.bookListItemCoverNameText'),
      _attr(item, 'a[title]', 'title'),
    ]);
    if (title.isEmpty) {
      return null;
    }

    return BookSearchResult(
      ref: SourceBookRef(
        sourceId: sourceId,
        sourceBookId: sourceBookId,
        sourceUri: sourceUri,
      ),
      sourceName: sourceName,
      title: title,
      author: _labelPeople(item, ['Автор']).join(', '),
      narrator: _labelPeople(item, ['Читает', 'Исполнитель']).join(', '),
      series: _labelPeople(item, ['Серия']).join(', '),
      seriesNumber: SourceParserHelpers.parseSeriesNumber(
        _labelValue(item, ['Серия']),
      ),
      coverUri: _coverUri(item),
      duration: SourceParserHelpers.parseDuration(item.text),
      year: SourceParserHelpers.parseYear(_labelValue(item, ['Год'])),
      isFull: true,
      isFree: true,
      accessType: AccessType.free,
    );
  }

  static Map<String, Object?> _playerData(String html) {
    final index = html.indexOf('KB.playerInit');
    if (index < 0) {
      return const {};
    }
    final openBrace = html.indexOf('{', index);
    if (openBrace < 0) {
      return const {};
    }
    final jsonObject = _balanced(html, openBrace, '{', '}');
    if (jsonObject.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(jsonObject);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on Object catch (error) {
      throw SourceException(
        sourceId: sourceId,
        kind: SourceErrorKind.parser,
        message: 'Knigoblud player data is invalid.',
        cause: error,
      );
    }
  }

  static List<Map<String, Object?>> _playlist(Map<String, Object?> playerData) {
    final playlist = playerData['playlist'];
    if (playlist is! List) {
      return const [];
    }
    return [
      for (final item in playlist)
        if (item is Map) item.cast<String, Object?>(),
    ].where((item) => _mediaUrl(item).isNotEmpty).toList();
  }

  static String _mediaUrl(Map<String, Object?> item) {
    final raw = _firstNonEmpty([
      _string(item['src']),
      _string(item['url']),
      _string(item['file']),
    ]);
    final uri = SourceParserHelpers.safeResolveUri(sourceBaseUri, raw);
    if (uri == null || !_isAllowedMediaUri(uri)) {
      return '';
    }
    return uri.toString();
  }

  static bool _isAllowedMediaUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final isAudioKnigi =
        host == 'audioknigi.xyz' || host.endsWith('.audioknigi.xyz');
    if (isAudioKnigi) {
      return true;
    }
    final isLitres = host == 'litres.ru' || host.endsWith('.litres.ru');
    if (!isLitres) {
      return false;
    }
    return uri.path.contains('/audiotrial/') ||
        RegExp(
          r'/get_mp3_trial/\d+\.mp3$',
          caseSensitive: false,
        ).hasMatch(uri.path);
  }

  static List<String> _labelPeople(Object root, List<String> labels) {
    final iconValues = _labelPeopleByIcon(root, labels);
    if (iconValues.isNotEmpty) {
      return iconValues;
    }

    final result = <String>[];
    final seen = <String>{};
    for (final line in _querySelectorAll(
      root,
      '.BookMetaBlockLine, .bookListItemMetaBlock, .bookListItemInfo > *',
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
        final value = _lineValue(line.text);
        final key = SourceParserHelpers.normalizeTitle(value);
        if (value.isNotEmpty && seen.add(key)) {
          result.add(value);
        }
      } else {
        for (final link in links) {
          final value = SourceParserHelpers.normalizeWhitespace(link.text);
          final key = SourceParserHelpers.normalizeTitle(value);
          if (value.isNotEmpty && seen.add(key)) {
            result.add(value);
          }
        }
      }
    }
    return result;
  }

  static List<String> _labelPeopleByIcon(Object root, List<String> labels) {
    final icon = _iconForLabels(labels);
    if (icon == null) {
      return const [];
    }

    final result = <String>[];
    final seen = <String>{};
    for (final line in _querySelectorAll(
      root,
      '.BookMetaBlockLine, .bookListItemMetaBlock',
    )) {
      if (!line.text.contains(icon)) {
        continue;
      }
      final links = line.querySelectorAll('a[href]');
      if (links.isEmpty) {
        final value = _stripIconValue(line.text, icon);
        final key = SourceParserHelpers.normalizeTitle(value);
        if (value.isNotEmpty && seen.add(key)) {
          result.add(value);
        }
        continue;
      }
      for (final link in links) {
        final value = SourceParserHelpers.normalizeWhitespace(link.text);
        final key = SourceParserHelpers.normalizeTitle(value);
        if (value.isNotEmpty && seen.add(key)) {
          result.add(value);
        }
      }
    }
    return result;
  }

  static String? _iconForLabels(List<String> labels) {
    final normalized = labels.map(SourceParserHelpers.normalizeTitle).toList();
    if (normalized.any((label) => label == 'автор')) {
      return '✍';
    }
    if (normalized.any(
      (label) => label == 'читает' || label == 'исполнитель',
    )) {
      return '🎙';
    }
    if (normalized.any((label) => label == 'серия')) {
      return '📚';
    }
    if (normalized.any((label) => label == 'жанр' || label == 'жанры')) {
      return '📕';
    }
    return null;
  }

  static String _stripIconValue(String text, String icon) {
    return SourceParserHelpers.normalizeWhitespace(
      text.replaceFirst(icon, '').replaceFirst(RegExp(r'^\uFE0F'), ''),
    );
  }

  static String _labelValue(Object root, List<String> labels) {
    for (final line in _querySelectorAll(
      root,
      '.BookMetaBlockLine, .bookListItemMetaBlock, .bookListItemInfo > *',
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

  static String _series(dom.Document document) {
    final raw = _firstNonEmpty([
      _seriesTitleFromLabel(
        _text(document, '.BookDescription.BookSeries .BookDescriptionLabel'),
      ),
      _labelPeople(document, ['Серия']).join(', '),
    ]);
    return SourceParserHelpers.normalizeWhitespace(
      raw.replaceFirst(RegExp(r'\(\d+(?:[.,]\d+)*\)\s*$'), ''),
    );
  }

  static String _seriesTitleFromLabel(String value) {
    final text = SourceParserHelpers.normalizeWhitespace(value);
    final quoted = RegExp(r'[«"]([^»"]+)[»"]').firstMatch(text);
    if (quoted != null) {
      return SourceParserHelpers.normalizeWhitespace(quoted.group(1)!);
    }
    return SourceParserHelpers.normalizeWhitespace(
      text.replaceFirst(RegExp(r'^.*?\bцикл\b\s*:?', caseSensitive: false), ''),
    );
  }

  static double? _seriesNumber(dom.Document document, Uri sourceUri) {
    final items = document.querySelectorAll(
      '.BookDescription.BookSeries .BookDescriptionSeriesItem',
    );
    for (final item in items) {
      final href = _href(item);
      final itemUri = SourceParserHelpers.safeResolveUri(sourceBaseUri, href);
      if (itemUri == null || !_sameBookPath(itemUri, sourceUri)) {
        continue;
      }
      final number = SourceParserHelpers.parseSeriesNumber(
        _text(item, '.BookDescriptionSeriesItemIndex'),
      );
      if (number != null) {
        return number;
      }
    }
    if (items.isEmpty) {
      return SourceParserHelpers.parseSeriesNumber(
        _labelValue(document, ['Серия']),
      );
    }
    return SourceParserHelpers.parseSeriesNumber(
      _text(items.first, '.BookDescriptionSeriesItemIndex'),
    );
  }

  static bool _sameBookPath(Uri left, Uri right) {
    final leftPath = left.path.replaceFirst(RegExp(r'/$'), '');
    final rightPath = right.path.replaceFirst(RegExp(r'/$'), '');
    return leftPath.isNotEmpty && leftPath == rightPath;
  }

  static List<String> _genres(dom.Document document) {
    final links = _labelPeople(document, ['Жанр', 'Жанры']);
    if (links.isNotEmpty) {
      return _splitLabels(links.join(', '));
    }
    return _splitLabels(_labelValue(document, ['Жанр', 'Жанры']));
  }

  static Uri? _coverUri(Object root) {
    final value = _firstNonEmpty([
      _attr(root, '#BookCoverImage', 'src'),
      _attr(root, '.bookListItemCoverImg', 'src'),
      _attr(root, '.bookListItemCoverImg', 'data-img'),
      _attr(root, 'img[data-src]', 'data-src'),
      _attr(root, 'img[src]', 'src'),
    ]);
    return SourceParserHelpers.safeResolveUri(sourceBaseUri, value);
  }

  static Duration? _duration(dom.Document document) {
    return SourceParserHelpers.parseDuration(
      _firstNonEmpty([
        _labelValue(document, ['Длительность', 'Время']),
        _text(document, '.bookListItemNameDur'),
      ]),
    );
  }

  static String _href(dom.Element item) {
    if (item.localName == 'a' && item.attributes.containsKey('href')) {
      return SourceParserHelpers.normalizeWhitespace(item.attributes['href']!);
    }
    return _attr(item, 'a[href]', 'href');
  }

  static Duration? _tracksDuration(List<Map<String, Object?>> tracks) {
    var seconds = 0;
    for (final track in tracks) {
      seconds += (_trackDurationMs(track) ?? 0) ~/ 1000;
    }
    return seconds <= 0 ? null : Duration(seconds: seconds);
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

  static String _trackTitle(Map<String, Object?> item, int index) {
    return _firstNonEmpty([
      _string(item['title']),
      _string(item['name']),
      'Глава ${index + 1}',
    ]);
  }

  static String _trackId(Map<String, Object?> item, int index) {
    return _firstNonEmpty([
      _string(item['fileId']),
      _string(item['id']),
      '${index + 1}',
    ]);
  }

  static int? _trackDurationMs(Map<String, Object?> item) {
    final seconds = _seconds(item['duration'] ?? item['duration_float']);
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
