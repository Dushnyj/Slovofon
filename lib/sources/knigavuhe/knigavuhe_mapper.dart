import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../domain/models/audio_track.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_version.dart';
import '../../domain/models/chapter.dart';
import '../source_models.dart';
import '../source_parser_helpers.dart';

class KnigavuheMapper {
  KnigavuheMapper({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const sourceId = 'knigavuhe';
  static const sourceName = 'Knigavuhe';
  static final sourceBaseUri = Uri.parse('https://knigavuhe.org/');

  final DateTime Function() _clock;

  List<BookSearchResult> searchResults(String html) {
    final document = html_parser.parse(html);
    return [
      for (final item in document.querySelectorAll('.bookkitem, .bookitem'))
        ?_searchResult(item),
    ];
  }

  BookVersionDetails bookDetails(String html, SourceBookRef ref) {
    final document = html_parser.parse(html);
    final now = _clock();
    final sourceUri = _sourceUri(ref);
    final sourceBookId = _sourceBookIdFromUri(sourceUri) ?? ref.sourceBookId;
    final idSegment = _idSegment(sourceBookId);
    final tracks = bookPlayerTracks(html);
    final title = _firstNonEmpty([
      _text(document, '.book_title_elem.book_title_name'),
      _text(document, '.book_title_name'),
      _text(document, '.book_title h1'),
      _text(document, 'h1'),
    ]);
    final authors = _titleBlockPeople(document, ['автор']);
    final narrators = _titleBlockPeople(document, ['читает', 'исполнитель']);
    final description = _text(document, '.book_description').isNotEmpty
        ? _text(document, '.book_description')
        : _text(document, '[itemprop="description"]');
    final duration = _duration(document) ?? _tracksDuration(tracks);
    final hasPlayableTracks = tracks.any(
      (track) => _mediaUrl(track).isNotEmpty,
    );
    final isFragment =
        hasPlayableTracks &&
        tracks.any((track) {
          final uri = Uri.tryParse(_mediaUrl(track));
          return uri != null &&
              (uri.host == 'litres.ru' || uri.host.endsWith('.litres.ru'));
        });
    final series = _series(document);
    final seriesNumber = _seriesNumber(document);
    final alternatives = _alternateNarrations(
      document,
      sourceUri,
      title: title,
      authors: authors,
      series: series,
      seriesNumber: seriesNumber,
    );

    return BookVersionDetails(
      ref: SourceBookRef(
        sourceId: sourceId,
        sourceBookId: sourceBookId,
        sourceUri: sourceUri,
      ),
      book: Book(
        id: 'knigavuhe-book-$idSegment',
        normalizedTitle: SourceParserHelpers.normalizeTitle(title),
        displayTitle: title,
        authors: authors,
        seriesTitle: series,
        seriesNumber: seriesNumber,
        bestCoverUrl: _coverUri(document)?.toString(),
        bestDescription: description,
        createdAt: now,
        updatedAt: now,
      ),
      version: BookVersion(
        id: 'knigavuhe-$idSegment',
        bookId: 'knigavuhe-book-$idSegment',
        sourceId: sourceId,
        sourceBookId: sourceBookId,
        sourceUrl: sourceUri.toString(),
        title: title,
        normalizedTitle: SourceParserHelpers.normalizeTitle(title),
        authors: authors,
        narrators: narrators,
        seriesTitle: series,
        seriesNumber: seriesNumber,
        genres: _genres(document),
        description: description,
        coverUrl: _coverUri(document)?.toString(),
        durationMs: duration?.inMilliseconds,
        durationText: _durationText(duration),
        publishedYear: _publishedYear(document),
        ratingValue: _rating(document),
        ratingCount: _ratingCount(document),
        accessType: hasPlayableTracks ? AccessType.free : AccessType.unknown,
        playbackAccess: hasPlayableTracks
            ? PlaybackAccess.streamAndDownload
            : PlaybackAccess.none,
        isFull: hasPlayableTracks && !isFragment,
        isFragment: isFragment,
        isPaid: false,
        isAccessibleForFree: hasPlayableTracks,
        canStream: hasPlayableTracks,
        canDownload: hasPlayableTracks,
        rawSourceDataJson: jsonEncode({
          'sourceUrl': sourceUri.toString(),
          'bookPlayerTracks': tracks.length,
          'views': _views(document),
          'likes': _voteCount(document, '1'),
          'dislikes': _voteCount(document, '-1'),
          'alternateNarrations': alternatives.length,
        }),
        createdAt: now,
        updatedAt: now,
      ),
      alternatives: alternatives,
    );
  }

  List<Chapter> chapters(String html, SourceBookRef ref) {
    final now = _clock();
    final sourceUri = _sourceUri(ref);
    final sourceBookId = _sourceBookIdFromUri(sourceUri) ?? ref.sourceBookId;
    final idSegment = _idSegment(sourceBookId);
    final tracks = bookPlayerTracks(html);

    return [
      for (var index = 0; index < tracks.length; index++)
        if (_mediaUrl(tracks[index]) case final mediaUrl
            when mediaUrl.isNotEmpty)
          Chapter(
            id: 'knigavuhe-$idSegment-chapter-${_trackId(tracks[index], index)}',
            bookVersionId: 'knigavuhe-$idSegment',
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

  List<Map<String, Object?>> bookPlayerTracks(String html) {
    final index = html.indexOf('BookPlayer');
    if (index < 0) {
      return const [];
    }
    final openBracket = html.indexOf('[', index);
    if (openBracket < 0) {
      return const [];
    }
    final jsonArray = _balanced(html, openBracket, '[', ']');
    if (jsonArray.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(jsonArray);
      if (decoded is! List) {
        return const [];
      }
      return [
        for (final item in decoded)
          if (item is Map) item.cast<String, Object?>(),
      ].where((item) => _mediaUrl(item).isNotEmpty).toList();
    } on Object catch (error) {
      throw SourceException(
        sourceId: sourceId,
        kind: SourceErrorKind.parser,
        message: 'Knigavuhe BookPlayer data is invalid.',
        cause: error,
      );
    }
  }

  static Map<String, String> mediaHeadersForSourceBookId(String sourceBookId) {
    final referer = _refererForSourceBookId(sourceBookId);
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/125.0 Safari/537.36',
      'Accept': 'audio/mpeg,audio/*,*/*;q=0.8',
      'Referer': referer,
    };
  }

  static String refererForSourceBookId(String sourceBookId) {
    return _refererForSourceBookId(sourceBookId);
  }

  BookSearchResult? _searchResult(dom.Element item) {
    final rawUrl = _firstNonEmpty([
      _attr(item, '.bookkitem_name[href]', 'href'),
      _attr(item, '.bookkitem_name a[href]', 'href'),
      _attr(item, '.bookitem_name[href]', 'href'),
      _attr(item, '.bookitem_name a[href]', 'href'),
      _attr(item, 'a[href]', 'href'),
    ]);
    final sourceUri = SourceParserHelpers.safeResolveUri(sourceBaseUri, rawUrl);
    final sourceBookId = _sourceBookIdFromUri(sourceUri);
    if (sourceUri == null || sourceBookId == null) {
      return null;
    }
    final title = _firstNonEmpty([
      _text(item, '.bookkitem_name[href]'),
      _text(item, '.bookkitem_name a[href]'),
      _text(item, '.bookitem_name[href]'),
      _text(item, '.bookitem_name a[href]'),
      _attr(item, 'a[title]', 'title'),
    ]);
    if (title.isEmpty) {
      return null;
    }
    final narrator = _firstNonEmpty([
      _people(item, '.bookkitem_performer a, .bookitem_performer a').join(', '),
      _metaBlockLinks(
        item,
        classNeedles: const ['reader', 'performer'],
        labelNeedles: const ['читает', 'исполнитель'],
      ).join(', '),
    ]);
    final seriesText = _firstNonEmpty([
      _text(item, '.bookkitem_series a, .bookitem_series a'),
      _metaBlockLinks(
        item,
        classNeedles: const ['serie', 'series'],
        labelNeedles: const ['цикл', 'серия'],
      ).join(', '),
    ]);
    final seriesBlockText = _firstNonEmpty([
      _text(item, '.bookkitem_series, .bookitem_series'),
      _metaBlockText(
        item,
        classNeedles: const ['serie', 'series'],
        labelNeedles: const ['цикл', 'серия'],
      ),
    ]);

    return BookSearchResult(
      ref: SourceBookRef(
        sourceId: sourceId,
        sourceBookId: sourceBookId,
        sourceUri: sourceUri,
      ),
      sourceName: sourceName,
      title: title,
      author: _people(
        item,
        '.bookkitem_author a, .bookitem_author a',
      ).join(', '),
      narrator: narrator,
      series: seriesText,
      seriesNumber: SourceParserHelpers.parseSeriesNumber(seriesBlockText),
      genres: _genres(item),
      coverUri: _coverUri(item),
      duration: SourceParserHelpers.parseDuration(
        _firstNonEmpty([
          _text(item, '.bookkitem_meta_time'),
          _text(item, '.bookkitem_time'),
          _text(item, '.bookitem_time'),
          _text(item, '.book_time'),
        ]),
      ),
      isFull: null,
      isFree: true,
      accessType: AccessType.free,
    );
  }

  static List<String> _titleBlockPeople(
    dom.Document document,
    List<String> labels,
  ) {
    final names = <String>[];
    final seen = <String>{};
    for (final element in document.querySelectorAll('.book_title_elem')) {
      final normalizedText = SourceParserHelpers.normalizeTitle(element.text);
      final matchesLabel = labels.any(
        (label) =>
            normalizedText.contains(SourceParserHelpers.normalizeTitle(label)),
      );
      if (!matchesLabel) {
        continue;
      }
      for (final link in element.querySelectorAll('a')) {
        final name = SourceParserHelpers.normalizeWhitespace(link.text);
        final key = SourceParserHelpers.normalizeTitle(name);
        if (name.isNotEmpty && seen.add(key)) {
          names.add(name);
        }
      }
    }
    return names;
  }

  static String _series(dom.Document document) {
    final raw = _firstNonEmpty([
      _text(document, '.book_info_line.icon_serie a'),
      _text(document, '.book_series a'),
      _text(document, '.book_serie a'),
      _text(document, '.book_serie_block_title a'),
    ]);
    return SourceParserHelpers.normalizeWhitespace(
      raw.replaceFirst(RegExp(r'\(\d+(?:[.,]\d+)*\)\s*$'), ''),
    );
  }

  static double? _seriesNumber(dom.Document document) {
    return SourceParserHelpers.parseSeriesNumber(
          _firstNonEmpty([_text(document, '.book_info_line_serie_index')]),
        ) ??
        _trailingSeriesNumber(
          _firstNonEmpty([
            _text(document, '.book_info_line.icon_serie'),
            _text(document, '.book_series'),
            _text(document, '.book_serie'),
          ]),
        );
  }

  static double? _trailingSeriesNumber(String value) {
    final match = RegExp(r'\((\d+(?:[.,]\d+)*)\)\s*$').firstMatch(value);
    return match == null
        ? null
        : SourceParserHelpers.parseSeriesNumber(match.group(1)!);
  }

  static int? _publishedYear(dom.Document document) {
    final direct = SourceParserHelpers.parseYear(
      _firstNonEmpty([
        _text(document, '.book_info_block_year .book_info_block_tag'),
        _text(document, '.book_info_line.icon_year'),
        _text(document, '.book_year'),
      ]),
    );
    if (direct != null) {
      return direct;
    }

    for (final block in document.querySelectorAll('.book_info_block')) {
      final title = SourceParserHelpers.normalizeTitle(
        _text(block, '.book_info_block_title'),
      );
      if (title.contains('год издания') ||
          title.contains('год написания') ||
          title.contains('год')) {
        final year = SourceParserHelpers.parseYear(block.text);
        if (year != null) {
          return year;
        }
      }
    }
    for (final label in document.querySelectorAll('.book_info_label')) {
      final title = SourceParserHelpers.normalizeTitle(label.text);
      if (title.contains('год') || title.contains('добавлена')) {
        final year = SourceParserHelpers.parseYear(
          label.parent?.text ?? label.text,
        );
        if (year != null) {
          return year;
        }
      }
    }
    return null;
  }

  static List<String> _genres(Object document) {
    final values = [
      for (final link in _querySelectorAll(
        document,
        '.book_genre_pretitle a, .book_genres a, .book_genre a',
      ))
        SourceParserHelpers.normalizeWhitespace(link.text),
    ];
    return _unique(values);
  }

  static Uri? _coverUri(Object root) {
    final value = _firstNonEmpty([
      _attr(root, '.book_cover', 'src'),
      _attr(root, '.book_cover img', 'src'),
      _attr(root, '.bookkitem_img img', 'src'),
      _attr(root, '.bookitem_img img', 'src'),
      _attr(root, 'img[data-src]', 'data-src'),
      _attr(root, 'img[src]', 'src'),
    ]);
    return SourceParserHelpers.safeResolveUri(sourceBaseUri, value);
  }

  static Duration? _duration(dom.Document document) {
    return SourceParserHelpers.parseDuration(
      _firstNonEmpty([
        _text(document, '.book_duration'),
        _text(document, '.book_time'),
        _text(document, '.book_info_line.icon_time'),
        _text(document, '[itemprop="duration"]'),
      ]),
    );
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

  static double? _rating(dom.Document document) {
    final schemaRating = double.tryParse(
      _attr(
        document,
        '[itemprop="ratingValue"]',
        'content',
      ).replaceAll(',', '.'),
    );
    if (schemaRating != null && schemaRating > 0) {
      return double.parse(schemaRating.clamp(0, 5).toStringAsFixed(1));
    }

    final likes = _voteCount(document, '1');
    final dislikes = _voteCount(document, '-1');
    final total = likes + dislikes;
    if (total <= 0) {
      return null;
    }
    return double.parse(((likes / total) * 5).toStringAsFixed(1));
  }

  static int? _ratingCount(dom.Document document) {
    final schemaCount = SourceParserHelpers.parseFirstInt(
      _attr(document, '[itemprop="ratingCount"]', 'content'),
    );
    if (schemaCount != null && schemaCount > 0) {
      return schemaCount;
    }

    final total = _voteCount(document, '1') + _voteCount(document, '-1');
    return total <= 0 ? null : total;
  }

  static int _voteCount(dom.Document document, String value) {
    final voteItemCount = _humanCount(
      _text(
        document,
        '.ls-vote-item[data-vote-value="$value"] .counter-number',
      ),
    );
    if (voteItemCount > 0) {
      return voteItemCount;
    }

    final fallbackSelector = value == '1'
        ? '#book_likes_count, .book_likes_count, [data-vote-value="1"]'
        : '#book_dislikes_count, .book_dislikes_count, [data-vote-value="-1"]';
    return _humanCount(_text(document, fallbackSelector));
  }

  static int _views(dom.Document document) {
    return _humanCount(
      _firstNonEmpty([
        _text(document, '#book_views_count'),
        _text(document, '.book_views_count'),
        _text(document, '#book_read_count'),
        _text(document, '.book_read_count'),
        _text(document, '.book_stat_views'),
      ]),
    );
  }

  static List<BookSearchResult> _alternateNarrations(
    dom.Document document,
    Uri sourceUri, {
    required String title,
    required List<String> authors,
    required String series,
    required double? seriesNumber,
  }) {
    final alternatives = <BookSearchResult>[];
    final currentSourceBookId = _sourceBookIdFromUri(sourceUri);
    for (final block in document.querySelectorAll(
      '.book_serie_block, .book_blue_block, .book_other_versions',
    )) {
      final blockTitle = SourceParserHelpers.normalizeTitle(
        _firstNonEmpty([
          _text(block, '.book_serie_block_title'),
          _text(block, 'h2'),
          _text(block, 'h3'),
          block.text,
        ]),
      );
      if (!blockTitle.contains('другие озвучки') &&
          !blockTitle.contains('другая озвучка') &&
          !blockTitle.contains('другие исполнения')) {
        continue;
      }

      for (final item in block.querySelectorAll(
        '.book_serie_block_item, .book_other_version, li, a[href]',
      )) {
        final itemHref = item.attributes['href'] ?? '';
        final bookLink = item.localName == 'a' && itemHref.contains('/book/')
            ? item
            : item.querySelector('a[href*="/book/"]');
        final rawHref = bookLink?.attributes['href'] ?? '';
        final itemUri = SourceParserHelpers.safeResolveUri(
          sourceBaseUri,
          rawHref,
        );
        final sourceBookId = _sourceBookIdFromUri(itemUri);
        if (itemUri == null ||
            sourceBookId == null ||
            !sourceBookId.startsWith('book/') ||
            sourceBookId == currentSourceBookId) {
          continue;
        }
        final readerLink =
            item.querySelector('a[href*="/reader/"]') ??
            item.querySelector('a[href*="/user/"]');
        final narrator = SourceParserHelpers.normalizeWhitespace(
          readerLink?.text ?? '',
        );
        alternatives.add(
          BookSearchResult(
            ref: SourceBookRef(
              sourceId: sourceId,
              sourceBookId: sourceBookId,
              sourceUri: itemUri,
            ),
            sourceName: sourceName,
            title: _firstNonEmpty([
              SourceParserHelpers.normalizeWhitespace(bookLink?.text ?? ''),
              title,
            ]),
            author: authors.join(', '),
            narrator: narrator,
            series: series,
            seriesNumber: seriesNumber,
            isFull: null,
            isFree: true,
            accessType: AccessType.free,
          ),
        );
      }
    }
    return _dedupeSearchResults(alternatives);
  }

  static List<BookSearchResult> _dedupeSearchResults(
    Iterable<BookSearchResult> results,
  ) {
    final byKey = <String, BookSearchResult>{};
    for (final result in results) {
      final key = '${result.sourceId}:${result.sourceBookId}';
      final existing = byKey[key];
      if (existing == null ||
          ((existing.narrator ?? '').trim().isEmpty &&
              (result.narrator ?? '').trim().isNotEmpty)) {
        byKey[key] = result;
      }
    }
    return List.unmodifiable(byKey.values);
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
    final raw = _firstNonEmpty([_string(item['url']), _string(item['file'])]);
    final uri = SourceParserHelpers.safeResolveUri(sourceBaseUri, raw);
    if (uri == null || !_isAllowedMediaUri(uri)) {
      return '';
    }
    return uri.toString();
  }

  static bool _isAllowedMediaUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final isKnigavuhe =
        host == 'knigavuhe.org' || host.endsWith('.knigavuhe.org');
    if (isKnigavuhe) {
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
    final seconds = _seconds(
      item['duration'] ?? item['duration_float'] ?? item['time'],
    );
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

  static String _idSegment(String sourceBookId) {
    return sourceBookId
        .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .toLowerCase();
  }

  static String _refererForSourceBookId(String sourceBookId) {
    final normalized = sourceBookId.endsWith('/')
        ? sourceBookId
        : '$sourceBookId/';
    return sourceBaseUri.resolve(normalized).toString();
  }

  static List<String> _people(Object root, String selector) {
    return _unique([
      for (final link in _querySelectorAll(root, selector))
        SourceParserHelpers.normalizeWhitespace(link.text),
    ]);
  }

  static List<String> _metaBlockLinks(
    Object root, {
    required List<String> classNeedles,
    required List<String> labelNeedles,
  }) {
    return _unique([
      for (final block in _matchingMetaBlocks(
        root,
        classNeedles: classNeedles,
        labelNeedles: labelNeedles,
      ))
        for (final link in block.querySelectorAll('a'))
          SourceParserHelpers.normalizeWhitespace(link.text),
    ]);
  }

  static String _metaBlockText(
    Object root, {
    required List<String> classNeedles,
    required List<String> labelNeedles,
  }) {
    return _firstNonEmpty([
      for (final block in _matchingMetaBlocks(
        root,
        classNeedles: classNeedles,
        labelNeedles: labelNeedles,
      ))
        SourceParserHelpers.normalizeWhitespace(block.text),
    ]);
  }

  static List<dom.Element> _matchingMetaBlocks(
    Object root, {
    required List<String> classNeedles,
    required List<String> labelNeedles,
  }) {
    final blocks = <dom.Element>[];
    for (final block in _querySelectorAll(
      root,
      '.bookkitem_meta_block, .bookitem_meta_block, .book_info_line',
    )) {
      final classText = [
        block.attributes['class'] ?? '',
        for (final child in block.querySelectorAll('[class]'))
          child.attributes['class'] ?? '',
      ].join(' ').toLowerCase();
      final normalizedText = SourceParserHelpers.normalizeTitle(block.text);
      final classMatches = classNeedles.any(classText.contains);
      final labelMatches = labelNeedles
          .map(SourceParserHelpers.normalizeTitle)
          .any(normalizedText.contains);
      if (classMatches || labelMatches) {
        blocks.add(block);
      }
    }
    return blocks;
  }

  static List<String> _unique(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final normalized = SourceParserHelpers.normalizeWhitespace(value);
      final key = SourceParserHelpers.normalizeTitle(normalized);
      if (normalized.isNotEmpty && seen.add(key)) {
        result.add(normalized);
      }
    }
    return result;
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
