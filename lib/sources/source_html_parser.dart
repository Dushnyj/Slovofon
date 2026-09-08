import '../domain/models/chapter.dart';
import 'akniga/akniga_mapper.dart';
import 'baza_knig/baza_knig_mapper.dart';
import 'knigavuhe/knigavuhe_mapper.dart';
import 'knigoblud/knigoblud_mapper.dart';
import 'source_models.dart';
import 'source_parser_worker.dart';

enum _HtmlOperation { search, details, chapters, bookId }

class SourceHtmlParser {
  static Future<List<BookSearchResult>> search(String sourceId, String html) =>
      _run(sourceId, html, _HtmlOperation.search);

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
  }) => SourceParserWorker.shared.run<T>(
    _parseHtml,
    _HtmlInput(sourceId, html, operation, ref, now ?? DateTime.now(), tracks),
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
  );

  final String sourceId;
  final String html;
  final _HtmlOperation operation;
  final SourceBookRef? ref;
  final DateTime now;
  final List<Map<String, Object?>> tracks;
}

Object? _parseHtml(Object? message) {
  final input = message! as _HtmlInput;
  final html = input.html;
  final ref = input.ref;
  final now = input.now;
  switch (input.sourceId) {
    case 'akniga':
      final mapper = AknigaMapper(clock: () => now);
      return switch (input.operation) {
        _HtmlOperation.search => mapper.searchResults(html),
        _HtmlOperation.details => mapper.bookDetails(html, ref!),
        _HtmlOperation.chapters => mapper.chapters(html, ref!, input.tracks),
        _HtmlOperation.bookId => mapper.bookIdFromHtml(html),
      };
    case 'knigavuhe':
      final mapper = KnigavuheMapper(clock: () => now);
      return switch (input.operation) {
        _HtmlOperation.search => mapper.searchResults(html),
        _HtmlOperation.details => mapper.bookDetails(html, ref!),
        _HtmlOperation.chapters => mapper.chapters(html, ref!),
        _HtmlOperation.bookId => throw StateError('Unsupported parser task.'),
      };
    case 'knigoblud':
      final mapper = KnigobludMapper(clock: () => now);
      return switch (input.operation) {
        _HtmlOperation.search => mapper.searchResults(html),
        _HtmlOperation.details => mapper.bookDetails(html, ref!),
        _HtmlOperation.chapters => mapper.chapters(html, ref!),
        _HtmlOperation.bookId => throw StateError('Unsupported parser task.'),
      };
    case 'baza_knig':
      final mapper = BazaKnigMapper(clock: () => now);
      return switch (input.operation) {
        _HtmlOperation.search => mapper.searchResults(html),
        _HtmlOperation.details => mapper.bookDetails(html, ref!),
        _HtmlOperation.chapters => mapper.chapters(html, ref!),
        _HtmlOperation.bookId => throw StateError('Unsupported parser task.'),
      };
    default:
      throw StateError('Unknown HTML source: ${input.sourceId}');
  }
}
