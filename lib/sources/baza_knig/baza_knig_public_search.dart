import 'package:html/parser.dart' as html_parser;

import '../source_models.dart';
import '../source_parser_worker.dart';
import '../source_search_text.dart';
import 'baza_knig_mapper.dart';

class BazaKnigPublicSearchPage {
  const BazaKnigPublicSearchPage(this.results, this.next, this.limited);

  final List<BookSearchResult> results;
  final Uri? next;
  final bool limited;
}

/// The public filter form's URL and ordinary category links. Neither is a
/// continuation of the separately submitted free-text search form.
abstract final class BazaKnigPublicSearch {
  static const filterFields = {
    'nazvanie',
    'cikl',
    'j.x.autor;p.title',
    'j.x.ispolnitel;x.ispolnitel2;x.ispolnitel3',
  };
  static final _category = RegExp(r'^[a-z0-9][a-z0-9-]{0,79}$');
  static final _unsafeValue = RegExp(r'[/\\\u0000-\u001F\u007F]');

  static Uri? filterUri(Uri base, Map<String, String> filters) {
    if (filters.isEmpty ||
        filters.keys.any((key) => !filterFields.contains(key)) ||
        filters.values.any((value) => !_validValue(value))) {
      return null;
    }
    final ordered = filters.keys.toList()..sort();
    // The public form encodes spaces as '+' and has this default ordering.
    // It can include paid titles: do not add the site's hide-paid checkbox.
    final segments = [
      for (final key in ordered)
        '$key=${Uri.encodeQueryComponent(filters[key]!)}',
      'sort=news_read',
      'order=desc',
    ];
    return base.resolve('/f/${segments.join('/')}/');
  }

  static bool sameOrigin(Uri base, Uri uri) =>
      uri.scheme == base.scheme &&
      uri.host == base.host &&
      uri.port == base.port &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;

  static bool isPublicPath(Uri uri) =>
      uri.path == '/' || _identity(uri) != null;

  static bool isGenreCatalogue(Uri base, Uri uri) {
    final identity = _identity(uri);
    return sameOrigin(base, uri) &&
        identity != null &&
        identity.mode == 'genre' &&
        identity.page == 1;
  }

  static Future<Map<String, Uri>> parseGenres(String html, Uri root) =>
      SourceParserWorker.shared.run<Map<String, Uri>>(_parseGenres, (
        html,
        root,
      ), debugLabel: 'baza-knig-public-categories');

  static Future<BazaKnigPublicSearchPage> parsePage(String html, Uri uri) =>
      SourceParserWorker.shared.run<BazaKnigPublicSearchPage>(
        _parsePublicPage,
        (html, uri),
        debugLabel: 'baza-knig-public-search',
      );

  static bool _validValue(String value) =>
      value.trim().isNotEmpty &&
      value.length <= 160 &&
      !_unsafeValue.hasMatch(value);

  static Uri? _publicLink(Uri base, String? href) {
    if (href == null || href.isEmpty) return null;
    try {
      final uri = base.resolve(href);
      return sameOrigin(base, uri) && _identity(uri) != null ? uri : null;
    } on FormatException {
      return null;
    }
  }

  /// Returns the logical scope and page from an advertised link. In filter
  /// paths values use form encoding, but scope names and keys remain literal.
  static ({String mode, String scope, int page})? _identity(Uri uri) {
    final parts = uri.path.split('/').skip(1).toList();
    if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
    var page = 1;
    if (parts.length >= 3 && parts[parts.length - 2] == 'page') {
      final pageText = parts.last;
      page = int.tryParse(pageText) ?? 0;
      if (page <= 1 || page.toString() != pageText) return null;
      parts.removeRange(parts.length - 2, parts.length);
    }
    if (parts.length == 1 &&
        parts.single != 'bk-chal' &&
        _category.hasMatch(parts.single)) {
      return (mode: 'genre', scope: parts.single, page: page);
    }
    if (parts.length < 4 || parts.first != 'f') return null;
    final fields = <String, String>{};
    for (final part in parts.skip(1)) {
      final separator = part.indexOf('=');
      if (separator <= 0) return null;
      final key = part.substring(0, separator);
      if (fields.containsKey(key)) return null;
      final String value;
      try {
        value = Uri.decodeQueryComponent(part.substring(separator + 1));
      } on FormatException {
        return null;
      } on ArgumentError {
        return null;
      }
      if (key == 'sort'
          ? value != 'news_read'
          : key == 'order'
          ? value != 'desc'
          : !filterFields.contains(key) || !_validValue(value)) {
        return null;
      }
      fields[key] = value;
    }
    if (fields['sort'] != 'news_read' || fields['order'] != 'desc') return null;
    final keys = fields.keys.toList()..sort();
    return (
      mode: 'filter',
      scope: keys
          .map((key) => '$key=${Uri.encodeQueryComponent(fields[key]!)}')
          .join('/'),
      page: page,
    );
  }
}

Map<String, Uri> _parseGenres(Object? message) {
  final (html, root) = message! as (String, Uri);
  final document = html_parser.parse(html);
  final sections = <String, Uri>{};
  for (final anchor in document.querySelectorAll('.left-menu-items a[href]')) {
    final uri = BazaKnigPublicSearch._publicLink(
      root,
      anchor.attributes['href'],
    );
    final name = SourceSearchText.normalize(anchor.text);
    if (name.isNotEmpty &&
        uri != null &&
        BazaKnigPublicSearch.isGenreCatalogue(root, uri)) {
      sections.putIfAbsent(name, () => uri);
    }
  }
  return sections;
}

BazaKnigPublicSearchPage _parsePublicPage(Object? message) {
  final (html, uri) = message! as (String, Uri);
  final document = html_parser.parse(html);
  final current = BazaKnigPublicSearch._identity(uri);
  final canonical = BazaKnigPublicSearch._publicLink(
    uri,
    document.querySelector('link[rel="canonical"]')?.attributes['href'],
  );
  final content = document.querySelector('#dle-content');
  if (current == null ||
      content == null ||
      canonical == null ||
      BazaKnigPublicSearch._identity(canonical) != current) {
    throw BazaKnigMapper.searchPageMismatch;
  }
  final rawCards = content.querySelectorAll('.short');
  final results = BazaKnigMapper().searchCards(rawCards, assumeFree: false);
  if (results.isEmpty) {
    if (rawCards.isEmpty &&
        current.page == 1 &&
        content
                .querySelector('.full-info')
                ?.text
                .toLowerCase()
                .contains('по данному запросу не найдено') ==
            true) {
      return const BazaKnigPublicSearchPage([], null, false);
    }
    throw BazaKnigMapper.searchPageMismatch;
  }
  final navigator = content.querySelector('.page-nav');
  final activePages = navigator
      ?.querySelectorAll('.navigation > span')
      .map((element) => int.tryParse(element.text.trim()))
      .nonNulls
      .toList();
  if ((navigator != null || current.page > 1) &&
      (activePages == null ||
          activePages.length != 1 ||
          activePages.single != current.page)) {
    throw BazaKnigMapper.searchPageMismatch;
  }
  Uri? next;
  var laterPageAdvertised = false;
  for (final anchor in navigator?.querySelectorAll('a[href]') ?? const []) {
    final number = int.tryParse(anchor.text.trim());
    laterPageAdvertised |=
        (number != null && number > current.page) ||
        anchor.querySelector('.pnext') != null;
    final link = BazaKnigPublicSearch._publicLink(
      uri,
      anchor.attributes['href'],
    );
    if (link == null) continue;
    final candidate = BazaKnigPublicSearch._identity(link);
    if (candidate != null &&
        candidate.mode == current.mode &&
        candidate.scope == current.scope &&
        candidate.page == current.page + 1) {
      next = link;
      break;
    }
  }
  final count = int.tryParse(
    RegExp(
          r'(\d+)\s+новост',
          caseSensitive: false,
        ).firstMatch(document.querySelector('title')?.text ?? '')?.group(1) ??
        '',
  );
  final missing =
      rawCards.length != results.length ||
      (next == null &&
          (laterPageAdvertised ||
              (current.mode == 'filter' &&
                  current.page == 1 &&
                  count != null &&
                  count > rawCards.length)));
  return BazaKnigPublicSearchPage(results, next, missing);
}
