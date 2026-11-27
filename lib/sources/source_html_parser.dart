import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../domain/models/chapter.dart';
import 'akniga/akniga_mapper.dart';
import 'baza_knig/baza_knig_mapper.dart';
import 'knigavuhe/knigavuhe_mapper.dart';
import 'knigoblud/knigoblud_mapper.dart';
import 'source_models.dart';
import 'source_parser_worker.dart';

enum _HtmlOperation { searchPage, details, chapters, bookId }

class SourceHtmlParser {
  static Future<SourceSearchPage> searchPage(
    String sourceId,
    String html,
    SearchRequest request,
  ) => _run(
    sourceId,
    html,
    _HtmlOperation.searchPage,
    page: request.page,
    query: request.query,
  );

  static SourceSearchPage parsedSearchPage(
    String sourceId,
    String html,
    List<BookSearchResult> results,
    int page,
    String query, {
    dom.Document? document,
  }) {
    if (sourceId == 'baza_knig' &&
        results.isEmpty &&
        (html.contains('/bk-chal') || html.contains('bk_challenge'))) {
      throw const SourceException(
        sourceId: 'baza_knig',
        kind: SourceErrorKind.accessRestricted,
        message:
            'Baza Knig returned an interstitial instead of search results.',
      );
    }
    final current = page < 1 ? 1 : page;
    final parsedDocument = document ?? html_parser.parse(html);
    if (sourceId == 'baza_knig') {
      final native = BazaKnigMapper.nativeSearchPagination(
        parsedDocument,
        current,
        query,
        hasResults: results.isNotEmpty,
      );
      if (native != null) {
        return SourceSearchPage(
          results: results,
          nextPage: native.nextPage,
          limited: native.limited,
        );
      }
      if (current > 1) throw BazaKnigMapper.searchPageMismatch;
    }
    final normalizedQuery = query.trim().toLowerCase();
    int? next;
    for (final anchor in parsedDocument.querySelectorAll('a[href]')) {
      final uri = Uri.tryParse(anchor.attributes['href'] ?? '');
      if (uri == null || !_paginationHost(sourceId, uri)) continue;
      late final Map<String, String> parameters;
      try {
        parameters = uri.queryParameters;
      } on FormatException {
        continue;
      }
      final candidateQuery =
          parameters[sourceId == 'baza_knig' ? 'story' : 'q'];
      if (candidateQuery?.trim().toLowerCase() != normalizedQuery) continue;
      final candidate = switch (sourceId) {
        'akniga' => RegExp(
          r'^/search/books/page(\d+)/?$',
        ).firstMatch(uri.path)?.group(1),
        'knigavuhe' || 'knigoblud' =>
          RegExp(r'^/search/?$').hasMatch(uri.path) || uri.path.isEmpty
              ? parameters['page']
              : null,
        'baza_knig' =>
          uri.path == '/index.php' && parameters['do'] == 'search'
              ? parameters['page']
              : null,
        _ => null,
      };
      final number = int.tryParse(candidate ?? '');
      if (number == current + 1) {
        next = number;
        break;
      }
    }
    if (results.isEmpty && next == null) {
      final recognizedEmpty = switch (sourceId) {
        'knigavuhe' => KnigavuheMapper.isKnownEmptySearchDocument(
          parsedDocument,
        ),
        'knigoblud' => KnigobludMapper.isKnownEmptySearchDocument(
          parsedDocument,
        ),
        _ => true,
      };
      if (!recognizedEmpty) {
        throw SourceException(
          sourceId: sourceId,
          kind: SourceErrorKind.parser,
          message:
              'Search response has no recognizable results or empty state.',
        );
      }
    }
    return SourceSearchPage(
      results: results,
      nextPage: next,
      // Without a recognized search form, absence of a Baza next link is
      // still not proof that the upstream response was complete.
      limited: sourceId == 'baza_knig' && next == null,
    );
  }

  static bool _paginationHost(String sourceId, Uri uri) {
    if (!uri.hasAuthority) return !uri.hasScheme;
    if (uri.hasScheme && uri.scheme != 'https' && uri.scheme != 'http') {
      return false;
    }
    return switch (sourceId) {
      'akniga' => uri.host == 'akniga.org' || uri.host == 'www.akniga.org',
      'knigavuhe' =>
        uri.host == 'knigavuhe.org' || uri.host == 'm.knigavuhe.org',
      'knigoblud' =>
        uri.host == 'www.knigoblud.club' || uri.host == 'knigoblud.club',
      'baza_knig' =>
        uri.host == 'baza-knig.top' || uri.host == 'www.baza-knig.top',
      _ => false,
    };
  }

  static Future<BookVersionDetails> details(
    String sourceId,
    String html,
    SourceBookRef ref,
    DateTime now,
  ) => _run(sourceId, html, _HtmlOperation.details, ref: ref, now: now);

  static Future<List<Chapter>> chapters(
    String sourceId,
    String html,
    SourceBookRef ref,
    DateTime now, {
    List<Map<String, Object?>> tracks = const [],
  }) => _run(
    sourceId,
    html,
    _HtmlOperation.chapters,
    ref: ref,
    now: now,
    tracks: tracks,
  );

  static Future<String> aknigaBookId(String html) =>
      _run('akniga', html, _HtmlOperation.bookId);

  static Future<T> _run<T>(
    String sourceId,
    String html,
    _HtmlOperation operation, {
    SourceBookRef? ref,
    DateTime? now,
    List<Map<String, Object?>> tracks = const [],
    int page = 1,
    String query = '',
  }) => SourceParserWorker.shared.run<T>(
    _parseHtml,
    _HtmlInput(
      sourceId,
      html,
      operation,
      ref,
      now ?? DateTime.now(),
      tracks,
      page,
      query,
    ),
    debugLabel: '$sourceId-${operation.name}-parser',
  );
}

class _HtmlInput {
  const _HtmlInput(
    this.sourceId,
    this.html,
    this.operation,
    this.ref,
    this.now,
    this.tracks,
    this.page,
    this.query,
  );

  final String sourceId;
  final String html;
  final _HtmlOperation operation;
  final SourceBookRef? ref;
  final DateTime now;
  final List<Map<String, Object?>> tracks;
  final int page;
  final String query;
}

Object? _parseHtml(Object? message) {
  final input = message! as _HtmlInput;
  final html = input.html;
  final ref = input.ref;
  final now = input.now;
  late final document = html_parser.parse(html);
  SourceSearchPage page(List<BookSearchResult> results) =>
      SourceHtmlParser.parsedSearchPage(
        input.sourceId,
        html,
        results,
        input.page,
        input.query,
        document: document,
      );
  switch (input.sourceId) {
    case 'akniga':
      final mapper = AknigaMapper(clock: () => now);
      return switch (input.operation) {
        _HtmlOperation.searchPage => page(mapper.searchDocument(document)),
        _HtmlOperation.details => mapper.bookDetails(html, ref!),
        _HtmlOperation.chapters => mapper.chapters(html, ref!, input.tracks),
        _HtmlOperation.bookId => mapper.bookIdFromHtml(html),
      };
    case 'knigavuhe':
      final mapper = KnigavuheMapper(clock: () => now);
      return switch (input.operation) {
        _HtmlOperation.searchPage => page(mapper.searchDocument(document)),
        _HtmlOperation.details => mapper.bookDetails(html, ref!),
        _HtmlOperation.chapters => mapper.chapters(html, ref!),
        _HtmlOperation.bookId => throw StateError('Unsupported parser task.'),
      };
    case 'knigoblud':
      final mapper = KnigobludMapper(clock: () => now);
      return switch (input.operation) {
        _HtmlOperation.searchPage => page(mapper.searchDocument(document)),
        _HtmlOperation.details => mapper.bookDetails(html, ref!),
        _HtmlOperation.chapters => mapper.chapters(html, ref!),
        _HtmlOperation.bookId => throw StateError('Unsupported parser task.'),
      };
    case 'baza_knig':
      final mapper = BazaKnigMapper(clock: () => now);
      return switch (input.operation) {
        _HtmlOperation.searchPage => page(mapper.searchDocument(document)),
        _HtmlOperation.details => mapper.bookDetails(html, ref!),
        _HtmlOperation.chapters => mapper.chapters(html, ref!),
        _HtmlOperation.bookId => throw StateError('Unsupported parser task.'),
      };
    default:
      throw StateError('Unknown HTML source: ${input.sourceId}');
  }
}
