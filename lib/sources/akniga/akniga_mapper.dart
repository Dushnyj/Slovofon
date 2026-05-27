import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../domain/models/audio_track.dart';
import '../../domain/models/book.dart';
import '../../domain/models/book_version.dart';
import '../../domain/models/chapter.dart';
import '../source_models.dart';
import '../source_parser_helpers.dart';

class AknigaMapper {
  AknigaMapper({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const sourceId = 'akniga';
  static const sourceName = 'Akniga';
  static final sourceBaseUri = Uri.parse('https://akniga.org/');

  final DateTime Function() _clock;

  List<BookSearchResult> searchResults(String html, {Uri? pageUri}) {
    final document = html_parser.parse(html);
    return [
      for (final item in document.querySelectorAll(
        '.content__main__articles--item',
      ))
        ?_searchResult(item, pageUri: pageUri),
    ];
  }

  BookVersionDetails bookDetails(String html, SourceBookRef ref) {
    final document = html_parser.parse(html);
    final now = _clock();
    final sourceUri = ref.sourceUri ?? sourceBaseUri.resolve(ref.sourceBookId);
    final slug = _slugFromUri(sourceUri) ?? ref.sourceBookId;
    final bid = bookIdFromHtml(html);
    final authors = _peopleForIcon(document, 'icon--author');
    final jsonLd = _jsonLdAudiobook(document);
    final rawTitle = _text(document, '.caption__article-main').isNotEmpty
        ? _text(document, '.caption__article-main')
        : _string(jsonLd['name']);
    final title = _titleWithoutAuthorPrefix(rawTitle, authors);
    final description = _description(document).isNotEmpty
        ? _description(document)
        : _string(jsonLd['description']);
    final duration = _duration(document);
    final isFree = jsonLd['isAccessibleForFree'] is bool
        ? jsonLd['isAccessibleForFree'] as bool
        : bid.isNotEmpty;
    final genres = _splitLabels(
      _text(document, '.section__title span').isNotEmpty
          ? _text(document, '.section__title span')
          : _text(document, '.section__title'),
    );

    return BookVersionDetails(
      ref: SourceBookRef(
        sourceId: sourceId,
        sourceBookId: slug,
        sourceUri: sourceUri,
      ),
      book: Book(
        id: 'akniga-book-$slug',
        normalizedTitle: SourceParserHelpers.normalizeTitle(title),
        displayTitle: title,
        authors: authors,
        seriesTitle: _series(document),
        year: _yearLabel(document, ['Год издания', 'Год публикации']),
        bestCoverUrl: _coverUri(document, jsonLd)?.toString(),
        bestDescription: description,
        createdAt: now,
        updatedAt: now,
      ),
      version: BookVersion(
        id: 'akniga-$slug',
        bookId: 'akniga-book-$slug',
        sourceId: sourceId,
        sourceBookId: slug,
        sourceUrl: sourceUri.toString(),
        title: title,
        normalizedTitle: SourceParserHelpers.normalizeTitle(title),
        authors: authors,
        narrators: _narrators(document, jsonLd),
        seriesTitle: _series(document),
        genres: genres,
        description: description,
        coverUrl: _coverUri(document, jsonLd)?.toString(),
        durationMs: duration?.inMilliseconds,
        durationText: _durationText(duration),
        publishedYear: _yearLabel(document, ['Год издания', 'Год публикации']),
        audioYear: _yearLabel(document, ['Год озвучки']),
        ratingValue: _rating(document),
        ratingCount: _ratingCount(document),
        accessType: isFree ? AccessType.free : AccessType.paid,
        playbackAccess: bid.isEmpty
            ? PlaybackAccess.none
            : PlaybackAccess.streamAndDownload,
        isFull: bid.isNotEmpty && !_isFragment(document),
        isFragment: _isFragment(document),
        isPaid: !isFree,
        isAccessibleForFree: isFree,
        canStream: bid.isNotEmpty,
        canDownload: bid.isNotEmpty,
        rawSourceDataJson: jsonEncode({
          'bid': bid,
          'sourceUrl': sourceUri.toString(),
        }),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  List<Chapter> chapters(
    String html,
    SourceBookRef ref,
    List<Map<String, Object?>> trackItems,
  ) {
    final sourceUri = ref.sourceUri ?? sourceBaseUri.resolve(ref.sourceBookId);
    final slug = _slugFromUri(sourceUri) ?? ref.sourceBookId;
    final now = _clock();
    final durations = _chapterDurations(trackItems);

    return [
      for (var index = 0; index < trackItems.length; index++)
        if (_mediaUrl(trackItems[index]) case final mediaUrl
            when mediaUrl.isNotEmpty)
          Chapter(
            id: 'akniga-$slug-chapter-${_trackId(trackItems[index], index)}',
            bookVersionId: 'akniga-$slug',
            sourceId: sourceId,
            sourceBookId: slug,
            sourceChapterId: _trackId(trackItems[index], index),
            index: index + 1,
            title: _trackTitle(trackItems[index], index),
            normalizedTitle: SourceParserHelpers.normalizeTitle(
              _trackTitle(trackItems[index], index),
            ),
            durationMs: durations[index] <= 0 ? null : durations[index] * 1000,
            streamRef: mediaUrl,
            cachedStreamUrl: mediaUrl,
            audioFormat: _audioFormat(mediaUrl),
            mimeType: _mimeType(_audioFormat(mediaUrl)),
            rawSourceDataJson: jsonEncode(trackItems[index]),
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
            _mediaHeadersForSlug(chapter.sourceBookId ?? ''),
          ),
          format: chapter.audioFormat,
          mimeType: chapter.mimeType,
          rawSourceDataJson: chapter.rawSourceDataJson,
        ),
    ];
  }

  String bookIdFromHtml(String html) {
    final document = html_parser.parse(html);
    return _attr(document, 'article[data-bid]', 'data-bid').isNotEmpty
        ? _attr(document, 'article[data-bid]', 'data-bid')
        : _attr(document, '.bookpage--chapters[data-bid]', 'data-bid');
  }

  static Map<String, String> mediaHeadersForRef(SourceBookRef ref) {
    final uri = ref.sourceUri ?? sourceBaseUri.resolve(ref.sourceBookId);
    return _mediaHeaders(uri.toString());
  }

  BookSearchResult? _searchResult(dom.Element item, {Uri? pageUri}) {
    final rawUrl = _attr(item, '.content__article-main-link', 'href').isNotEmpty
        ? _attr(item, '.content__article-main-link', 'href')
        : _attr(item, 'a[href]', 'href');
    final sourceUri = SourceParserHelpers.safeResolveUri(sourceBaseUri, rawUrl);
    final slug = _slugFromUri(sourceUri);
    if (sourceUri == null || slug == null || slug.isEmpty) {
      return null;
    }

    final authors = _peopleForIcon(item, 'icon--author');
    final rawTitle = _text(item, '.caption__article-main').isNotEmpty
        ? _text(item, '.caption__article-main')
        : _text(item, '.caption__article-preview');
    final title = _titleWithoutAuthorPrefix(rawTitle, authors);
    if (title.isEmpty) {
      return null;
    }

    final duration = SourceParserHelpers.parseDuration(
      _text(item, '.link__action--label--time'),
    );
    final isFragment =
        item.querySelector('[href="https://akniga.org/paid/"]') != null ||
        _text(item, '.caption__article-preview').contains('Фрагмент');

    return BookSearchResult(
      ref: SourceBookRef(
        sourceId: sourceId,
        sourceBookId: slug,
        sourceUri: sourceUri,
      ),
      sourceName: sourceName,
      title: title,
      author: authors.join(', '),
      narrator: _peopleForIcon(item, 'icon--performer').join(', '),
      series: _text(item, '.book-series a'),
      coverUri: _coverUri(item, const {}),
      duration: duration,
      year: _searchResultYear(item),
      isFull: !isFragment,
      isFree: !isFragment,
      accessType: isFragment ? AccessType.unknown : AccessType.free,
    );
  }

  static String? _slugFromUri(Uri? uri) {
    if (uri == null) {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? null : segments.last;
  }

  static List<int> _chapterDurations(List<Map<String, Object?>> items) {
    final times = [for (final item in items) _seconds(item['time'])];
    final cumulative =
        times.length > 1 &&
        Iterable<int>.generate(
          times.length - 1,
        ).every((index) => times[index + 1] >= times[index]);

    final durations = <int>[];
    var previousEnd = 0;
    for (var index = 0; index < items.length; index++) {
      final explicit = _seconds(items[index]['duration']);
      final duration = explicit > 0
          ? explicit
          : cumulative
          ? (times[index] - previousEnd).clamp(0, 1 << 31)
          : times[index];
      durations.add(duration);
      if (cumulative) {
        previousEnd = times[index];
      }
    }
    return durations;
  }

  static String _mediaUrl(Map<String, Object?> item) {
    return _firstNonEmpty([
      _string(item['mp3']),
      _string(item['url']),
      _string(item['file']),
    ]);
  }

  static String _trackTitle(Map<String, Object?> item, int index) {
    return _firstNonEmpty([
      _string(item['title']),
      _string(item['titleonly']),
      'Глава ${index + 1}',
    ]);
  }

  static String _trackId(Map<String, Object?> item, int index) {
    return _firstNonEmpty([
      _string(item['id']),
      _string(item['chapterId']),
      '${index + 1}',
    ]);
  }

  static Duration? _duration(dom.Document document) {
    final combined = SourceParserHelpers.normalizeWhitespace(
      '${_text(document, '.hours')} ${_text(document, '.minutes')}',
    );
    return SourceParserHelpers.parseDuration(combined) ??
        _isoDuration(_string(_jsonLdAudiobook(document)['duration']));
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

  static Duration? _isoDuration(String value) {
    final match = RegExp(
      r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    return Duration(
      hours: int.tryParse(match.group(1) ?? '') ?? 0,
      minutes: int.tryParse(match.group(2) ?? '') ?? 0,
      seconds: int.tryParse(match.group(3) ?? '') ?? 0,
    );
  }

  static Uri? _coverUri(Object root, Map<String, Object?> jsonLd) {
    final value = _firstNonEmpty([
      _attr(root, '.cover__wrapper--image img', 'src'),
      _attr(
        root,
        '.container__remaining-width.article--cover.pull-left img',
        'data-src',
      ),
      _attr(root, 'img.topic', 'data-src'),
      _attr(root, 'img.topic', 'src'),
      _string(jsonLd['image']),
    ]);
    return SourceParserHelpers.safeResolveUri(sourceBaseUri, value);
  }

  static int? _searchResultYear(Object root) {
    final value = _firstNonEmpty([
      _text(root, '.link__action--label--year'),
      _text(root, '.link__action--label--date'),
      _text(root, '.content__article--year'),
      _labelValue(root, 'Год издания'),
      _labelValue(root, 'Год публикации'),
    ]);
    return SourceParserHelpers.parseYear(value);
  }

  static List<String> _narrators(
    dom.Document document,
    Map<String, Object?> jsonLd,
  ) {
    final fromPage = _firstNonEmpty([
      _text(document, '.link__reader'),
      _peopleForIcon(document, 'icon--performer').join(', '),
    ]);
    if (fromPage.isNotEmpty) {
      return _splitPeople(fromPage);
    }

    return _splitPeople(_personName(jsonLd['readBy']));
  }

  static String _description(dom.Document document) {
    for (final block in document.querySelectorAll(
      '.description__article-main',
    )) {
      final caption = _text(block, '.content__main__book--item--caption');
      if (caption.toLowerCase().startsWith('описание')) {
        final clone = block.clone(true);
        for (final node in clone.querySelectorAll(
          '.content__main__book--item--caption',
        )) {
          node.remove();
        }
        return SourceParserHelpers.normalizeWhitespace(clone.text);
      }
    }
    return '';
  }

  static List<String> _peopleForIcon(Object root, String iconClass) {
    final names = <String>[];
    final seen = <String>{};
    for (final block in _querySelectorAll(root, '.link__action')) {
      if (_querySelector(block, '.$iconClass') == null) {
        continue;
      }
      for (final link in _querySelectorAll(block, 'a[href]')) {
        final name = SourceParserHelpers.normalizeWhitespace(link.text);
        final key = SourceParserHelpers.normalizeTitle(name);
        if (name.isNotEmpty && seen.add(key)) {
          names.add(name);
        }
      }
    }
    if (names.isNotEmpty) {
      return names;
    }

    return [
      for (final link in _querySelectorAll(root, '.about-author a[href]'))
        SourceParserHelpers.normalizeWhitespace(link.text),
    ].where((value) => value.isNotEmpty).toList();
  }

  static String _titleWithoutAuthorPrefix(
    String rawTitle,
    List<String> authors,
  ) {
    final title = SourceParserHelpers.normalizeWhitespace(rawTitle);
    final match = RegExp(r'^(.{2,180}?)\s*[–—-]\s*(.+)$').firstMatch(title);
    if (match == null || authors.isEmpty) {
      return title;
    }

    final prefixPeople = _splitPeople(match.group(1)!);
    final allKnown = prefixPeople.every((prefix) {
      final normalizedPrefix = SourceParserHelpers.normalizeTitle(prefix);
      return authors.any(
        (author) =>
            SourceParserHelpers.normalizeTitle(author) == normalizedPrefix,
      );
    });

    return allKnown
        ? SourceParserHelpers.normalizeWhitespace(match.group(2)!)
        : title;
  }

  static String _series(Object root) {
    final raw = _text(root, '.link__series[href]').isNotEmpty
        ? _text(root, '.link__series[href]')
        : _text(root, '.book-series a');
    return SourceParserHelpers.normalizeWhitespace(
      raw.replaceFirst(RegExp(r'\(\d+(?:[.,]\d+)*\)\s*$'), ''),
    );
  }

  static int? _yearLabel(Object root, List<String> labels) {
    for (final label in labels) {
      final value = _labelValue(root, label);
      final year = SourceParserHelpers.parseYear(value);
      if (year != null) {
        return year;
      }
    }
    return null;
  }

  static String _labelValue(Object root, String label) {
    final normalizedLabel = SourceParserHelpers.normalizeTitle(label);
    for (final caption in _querySelectorAll(
      root,
      '.content__main__book--item--caption',
    )) {
      final captionText = SourceParserHelpers.normalizeWhitespace(caption.text);
      if (!SourceParserHelpers.normalizeTitle(
        captionText,
      ).startsWith(normalizedLabel)) {
        continue;
      }
      final block = caption.parent;
      if (block == null) {
        continue;
      }
      final clone = block.clone(true);
      for (final node in clone.querySelectorAll(
        '.content__main__book--item--caption',
      )) {
        node.remove();
      }
      return SourceParserHelpers.normalizeWhitespace(clone.text);
    }
    return '';
  }

  static double? _rating(dom.Document document) {
    final likes = _voteCount(document, '1');
    final dislikes = _voteCount(document, '-1');
    final total = likes + dislikes;
    if (total <= 0) {
      return null;
    }
    return double.parse(((likes / total) * 5).toStringAsFixed(1));
  }

  static int? _ratingCount(dom.Document document) {
    final total = _voteCount(document, '1') + _voteCount(document, '-1');
    return total <= 0 ? null : total;
  }

  static int _voteCount(dom.Document document, String value) {
    return _humanCount(
      _text(
        document,
        '.ls-vote-item[data-vote-value="$value"] .counter-number',
      ),
    );
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

  static bool _isFragment(dom.Document document) {
    final text = document.body?.text ?? document.documentElement?.text ?? '';
    return RegExp(
      r'Фрагмент|Слушать полностью|Купить аудиокнигу|ЛитРес',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static Map<String, Object?> _jsonLdAudiobook(dom.Document document) {
    for (final script in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      try {
        final decoded = jsonDecode(script.text);
        final items =
            decoded is Map<String, Object?> && decoded['@graph'] is List
            ? decoded['@graph'] as List
            : [decoded];
        for (final item in items) {
          if (item is! Map<String, Object?>) {
            continue;
          }
          final type = item['@type'];
          if (type == 'Audiobook' ||
              (type is List && type.contains('Audiobook'))) {
            return item;
          }
        }
      } on Object {
        continue;
      }
    }
    return const {};
  }

  static String _personName(Object? value) {
    if (value is String) {
      return SourceParserHelpers.normalizeWhitespace(value);
    }
    if (value is List) {
      return value.map(_personName).where((name) => name.isNotEmpty).join(', ');
    }
    if (value is Map<String, Object?>) {
      return _string(value['name']);
    }
    return '';
  }

  static List<String> _splitPeople(String value) {
    return value
        .split(RegExp(r'\s*,\s*'))
        .map(SourceParserHelpers.normalizeWhitespace)
        .where((item) => item.isNotEmpty)
        .toList();
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

  static Map<String, String> _mediaHeadersForSlug(String slug) {
    return _mediaHeaders(sourceBaseUri.resolve(slug).toString());
  }

  static Map<String, String> _mediaHeaders(String referer) {
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/125.0 Safari/537.36',
      'Accept': 'audio/mpeg,audio/*,*/*;q=0.8',
      'Referer': referer,
    };
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
