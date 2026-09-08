import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  test(
    'fast source is published before slow source, with final failures',
    () async {
      final slow = Completer<List<BookSearchResult>>();
      final first = Completer<SourceSearchResponse>();
      final service = SourceCatalogService(
        registry: SourceRegistry([
          _Connector('slow', (_) => slow.future),
          _Connector('fast', (_) async => [_book('fast')]),
        ]),
        searchEnrichmentLimit: 0,
      );
      var finished = false;
      final finalResult = service
          .search(
            const SearchRequest(query: 'book'),
            onUpdate: (response) {
              if (response.results.isNotEmpty && !first.isCompleted) {
                first.complete(response);
              }
            },
          )
          .then((response) {
            finished = true;
            return response;
          });

      expect((await first.future).results.single.sourceId, 'fast');
      expect(finished, isFalse);
      slow.completeError(
        const SourceException(
          sourceId: 'slow',
          kind: SourceErrorKind.network,
          message: 'offline fixture',
        ),
      );
      final result = await finalResult;
      expect(result.results.single.sourceId, 'fast');
      expect(result.failures.single.sourceId, 'slow');
      expect(result.hasPartialFailures, isTrue);
    },
  );

  test(
    'ready search cards do not wait for shared metadata enrichment',
    () async {
      final details = Completer<BookVersionDetails>();
      final started = Completer<void>();
      final first = Completer<SourceSearchResponse>();
      final book = _book('one');
      final service = SourceCatalogService(
        registry: SourceRegistry([
          _Connector(
            'one',
            (_) async => [book],
            details: (_) {
              started.complete();
              return details.future;
            },
          ),
        ]),
      );
      final result = service.search(
        const SearchRequest(query: 'book'),
        onUpdate: (response) {
          if (response.results.isNotEmpty && !first.isCompleted) {
            first.complete(response);
          }
        },
      );
      expect((await first.future).results.single.duration, isNull);
      await started.future;
      details.complete(_details(book));
      expect((await result).results.single.duration, const Duration(hours: 2));
    },
  );

  test(
    'cancellation stops a pending operation and ignores late completion',
    () async {
      final pending = Completer<List<BookSearchResult>>();
      final started = Completer<void>();
      final cancellation = SourceSearchCancellation();
      var aborted = false;
      var updates = 0;
      final service = SourceCatalogService(
        registry: SourceRegistry([
          _Connector('one', (_) {
            SourceSearchCancellation.current!.addListener(() => aborted = true);
            started.complete();
            return pending.future;
          }),
        ]),
      );
      final result = service.search(
        const SearchRequest(query: 'book name'),
        cancellation: cancellation,
        onUpdate: (_) => updates++,
      );
      final expectation = expectLater(
        result,
        throwsA(isA<SourceSearchCancelled>()),
      );
      await started.future;
      cancellation.cancel();
      await expectation;
      expect(aborted, isTrue);
      pending.complete([_book('one')]);
      await Future<void>.value();
      expect(updates, 0);
    },
  );

  testWidgets(
    'overall deadline returns ready results without waiting forever',
    (tester) async {
      final pending = Completer<List<BookSearchResult>>();
      var aborted = false;
      SourceSearchResponse? finalResult;
      final service = SourceCatalogService(
        registry: SourceRegistry([
          _Connector('fast', (_) async => [_book('fast')]),
          _Connector('slow', (_) {
            SourceSearchCancellation.current!.addListener(() => aborted = true);
            return pending.future;
          }),
        ]),
        searchTimeout: const Duration(milliseconds: 40),
        searchEnrichmentLimit: 0,
      );
      unawaited(
        service.search(const SearchRequest(query: 'book')).then((value) {
          finalResult = value;
        }),
      );
      await tester.pump();
      expect(finalResult, isNull);
      await tester.pump(const Duration(milliseconds: 40));
      expect(aborted, isTrue);
      expect(finalResult!.results.single.sourceId, 'fast');
      expect(finalResult!.failures.single.sourceId, 'slow');
      expect(
        finalResult!.failures.single.message,
        contains('overall time budget'),
      );
      pending.complete(const []);
      await tester.pump();
    },
  );

  test(
    'cancelled enrichment consumer does not cancel another cache consumer',
    () async {
      final details = Completer<BookVersionDetails>();
      final started = Completer<void>();
      var loads = 0;
      final book = _book('one');
      final service = SourceCatalogService(
        registry: SourceRegistry([
          _Connector(
            'one',
            (_) async => [book],
            details: (_) {
              loads++;
              if (!started.isCompleted) started.complete();
              return details.future;
            },
          ),
        ]),
      );
      final cancellation = SourceSearchCancellation();
      final first = service.search(
        const SearchRequest(query: 'book'),
        cancellation: cancellation,
      );
      final firstExpectation = expectLater(
        first,
        throwsA(isA<SourceSearchCancelled>()),
      );
      await started.future;
      final second = service.search(const SearchRequest(query: 'book'));
      cancellation.cancel();
      await firstExpectation;
      details.complete(_details(book));
      expect((await second).results.single.duration, const Duration(hours: 2));
      expect(loads, 1);
    },
  );

  testWidgets(
    'fallback shares the original deadline instead of restarting it',
    (tester) async {
      final primary = Completer<List<BookSearchResult>>();
      final pending = Completer<List<BookSearchResult>>();
      final queries = <String>[];
      SourceSearchResponse? finalResult;
      final service = SourceCatalogService(
        registry: SourceRegistry([
          _Connector('one', (request) {
            queries.add(request.query);
            return switch (request.query) {
              'book name' => primary.future,
              'book' => Future.value([_book('one', title: 'Book Name')]),
              _ => pending.future,
            };
          }),
        ]),
        searchTimeout: const Duration(milliseconds: 40),
        searchEnrichmentLimit: 0,
      );
      unawaited(
        service
            .search(
              const SearchRequest(query: 'book name', kind: SearchKind.title),
            )
            .then((value) => finalResult = value),
      );
      await tester.pump(const Duration(milliseconds: 10));
      primary.complete(const []);
      await tester.pump();
      expect(queries, ['book name', 'book', 'name']);
      await tester.pump(const Duration(milliseconds: 29));
      expect(finalResult, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(finalResult!.results.single.title, 'Book Name');
      expect(
        finalResult!.failures.single.message,
        contains('overall time budget'),
      );
      pending.complete(const []);
      await tester.pump();
    },
  );

  test(
    'fallback partial snapshots preserve strict filtering and final sorting',
    () async {
      final slow = Completer<List<BookSearchResult>>();
      final visible = Completer<SourceSearchResponse>();
      final queries = <String>[];
      final service = SourceCatalogService(
        registry: SourceRegistry([
          _Connector('one', (request) {
            queries.add(request.query);
            return switch (request.query) {
              'book name' => Future.value(const []),
              'book' => Future.value([
                _book('one', title: 'Book Name Z'),
                _book('one', title: 'Unrelated'),
              ]),
              _ => slow.future,
            };
          }),
        ]),
        searchEnrichmentLimit: 0,
      );
      final result = service.search(
        const SearchRequest(
          query: 'book name',
          kind: SearchKind.title,
          sort: SearchSort.title,
        ),
        onUpdate: (response) {
          if (response.results.isNotEmpty && !visible.isCompleted) {
            visible.complete(response);
          }
          expect(
            response.results.any((book) => book.title == 'Unrelated'),
            isFalse,
          );
        },
      );
      expect((await visible.future).results.single.title, 'Book Name Z');
      slow.complete([_book('one', title: 'Book Name A')]);
      expect((await result).results.map((book) => book.title), [
        'Book Name A',
        'Book Name Z',
      ]);
      expect(queries, ['book name', 'book', 'name']);
    },
  );
}

BookSearchResult _book(String sourceId, {String title = 'Book'}) =>
    BookSearchResult(
      ref: SourceBookRef(sourceId: sourceId, sourceBookId: title),
      sourceName: sourceId,
      title: title,
    );

BookVersionDetails _details(BookSearchResult book) => BookVersionDetails(
  ref: book.ref,
  version: BookVersion(
    id: 'version',
    bookId: 'book',
    sourceId: book.sourceId,
    sourceBookId: book.sourceBookId,
    title: book.title,
    normalizedTitle: 'book',
    durationMs: const Duration(hours: 2).inMilliseconds,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
);

class _Connector implements SourceConnector {
  _Connector(this.id, this._search, {this.details});
  @override
  final String id;
  final Future<List<BookSearchResult>> Function(SearchRequest) _search;
  final Future<BookVersionDetails> Function(SourceBookRef)? details;
  @override
  SourceCapabilities get capabilities => SourceCapabilities(
    supportsSearch: true,
    supportsDetails: details != null,
  );
  @override
  Future<List<BookSearchResult>> search(SearchRequest request) =>
      _search(request);
  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) => details!(ref);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
