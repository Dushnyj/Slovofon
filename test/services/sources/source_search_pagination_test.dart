import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  test('pages accumulate past 50 after a page with no local matches', () async {
    final connector = _Paged('books', (request) {
      final page = request.page;
      return SourceSearchPage(
        results: [
          if (page == 3) _book('books', '1-0', title: 'Метро 1.0'),
          for (var i = 0; i < 20; i++)
            _book(
              'books',
              '$page-$i',
              title: page == 2 ? 'Постороннее $i' : 'Метро $page.$i',
            ),
        ],
        nextPage: page < 4 ? page + 1 : null,
      );
    });
    final service = _service([connector]);
    const query = SearchRequest(query: 'Метро', kind: SearchKind.title);
    final publishedCounts = <int>[];
    final partial = await service.search(
      query,
      onUpdate: (update) => publishedCounts.add(update.results.length),
    );
    expect(partial.results, hasLength(40));
    expect(publishedCounts, [20, 40]);
    expect(partial.hasMore, isTrue);
    expect(partial.isPartial, isTrue);

    final complete = await service.search(
      query.copyWith(continuation: partial.continuation),
    );
    expect(complete.results, hasLength(60));
    expect(complete.hasMore, isFalse);
    expect(complete.isPartial, isFalse);
    expect(connector.calls.map((call) => call.page), [1, 2, 3, 4]);
  });

  test('retry resumes only the failed lane and keeps other pages', () async {
    final cursor = _Cursor();
    var failSecondPage = true;
    final flaky = _Paged('flaky', (request) {
      if (request.page == 2) {
        expect(request.sourceCursor, same(cursor));
        if (failSecondPage) {
          failSecondPage = false;
          throw const SourceException(
            sourceId: 'flaky',
            kind: SourceErrorKind.network,
            message: 'temporary failure',
          );
        }
      }
      return SourceSearchPage(
        results: [_book('flaky', '${request.page}', title: 'Метро')],
        nextPage: request.page == 1 ? 2 : null,
        nextCursor: request.page == 1 ? cursor : null,
        usedRequestedScope: true,
      );
    });
    final stable = _Paged(
      'stable',
      (request) => SourceSearchPage(
        results: [_book('stable', '${request.page}', title: 'Метро')],
        nextPage: request.page == 4 ? null : request.page + 1,
        usedRequestedScope: true,
      ),
    );
    final service = _service([flaky, stable]);
    const query = SearchRequest(query: 'Метро', kind: SearchKind.title);
    final first = await service.search(query);
    expect(first.results, hasLength(4));
    expect(first.failures.single.sourceId, 'flaky');
    expect(first.retryContinuation, isNotNull);
    expect(first.continuation, isNotNull);

    final retried = await service.search(
      query.copyWith(continuation: first.retryContinuation),
    );
    expect(retried.results, hasLength(5));
    expect(retried.failures, isEmpty);
    expect(retried.retryContinuation, isNull);
    expect(stable.calls.map((call) => call.page), [1, 2, 3]);
    expect(flaky.calls.map((call) => call.page), [1, 2, 2]);
    final done = await service.search(
      query.copyWith(continuation: retried.continuation),
    );
    expect(done.results, hasLength(6));
    expect(done.isPartial, isFalse);
    expect(stable.calls.map((call) => call.page), [1, 2, 3, 4]);
  });

  test(
    'repeating upstream page is limited, without an endless continuation',
    () async {
      final connector = _Paged(
        'repeat',
        (request) => SourceSearchPage(
          results: [_book('repeat', 'same', title: 'Метро')],
          nextPage: request.page + 1,
        ),
      );
      final response = await _service([
        connector,
      ]).search(const SearchRequest(query: 'Метро'));
      expect(response.results.single.sourceBookId, 'same');
      expect(response.hasMore, isFalse);
      expect(response.limitedSourceIds, {'repeat'});
      expect(connector.calls.map((call) => call.page), [1, 2]);
    },
  );

  test(
    'one successful source does not suppress the other source fallback',
    () async {
      final first = _Paged(
        'first',
        (request) => SourceSearchPage(
          results: [_book('first', 'edition', title: 'Дыхание зоны')],
        ),
      );
      final second = _Paged(
        'second',
        (request) => SourceSearchPage(
          results: request.query == 'зоны'
              ? [_book('second', 'edition', title: 'Дыхание зоны')]
              : [_book('second', 'sparse', title: 'Совсем другая книга')],
        ),
      );
      final response = await _service([first, second]).search(
        const SearchRequest(query: 'дыхание зоны', kind: SearchKind.title),
      );
      expect(response.results.map((book) => book.sourceId), [
        'first',
        'second',
      ]);
      expect(first.calls.map((call) => call.query), ['дыхание зоны']);
      expect(second.calls.map((call) => call.query), [
        'дыхание зоны',
        'дыхание',
        'зоны',
      ]);
    },
  );

  test(
    'all fields match one version and person mode rejects split names',
    () async {
      final connector = _Paged(
        'books',
        (_) => SourceSearchPage(
          results: [
            _book(
              'books',
              'target',
              title: 'Во мрак',
              author: 'Андрей Дьяков',
              narrators: ['Сергей Кузнецов'],
              series: 'Вселенная «Метро 2033»',
              genres: ['Постапокалиптика'],
            ),
            _book(
              'books',
              'wrong',
              title: 'Во мрак',
              author: 'Андрей Дьяков',
              narrators: ['Сергей Иванов', 'Иван Кузнецов'],
              series: 'Метро 2033',
              genres: ['Постапокалиптика'],
            ),
            _book(
              'books',
              'another-version',
              title: 'Во мрак',
              author: 'Андрей Дьяков',
              narrators: ['Другой Исполнитель'],
              series: 'Метро 2033',
            ),
          ],
        ),
      );
      final service = _service([connector]);
      for (final person in ['Кузнецов Сергей', 'Сергей Кузнецов']) {
        final response = await service.search(
          SearchRequest(query: person, kind: SearchKind.narrator),
        );
        expect(response.results.single.sourceBookId, 'target');
      }
      const mixed = 'Во мрак Андрей Дьяков Кузнецов Сергей Метро 2033';
      connector.calls.clear();
      final response = await service.search(const SearchRequest(query: mixed));
      expect(connector.calls.first.query, mixed);
      expect(connector.calls.map((call) => call.query), contains('метро 2033'));
      expect(response.results.single.sourceBookId, 'target');
    },
  );

  test(
    'later duplicate can fill missing metadata without replacing a title',
    () async {
      final connector = _Paged(
        'books',
        (request) => SourceSearchPage(
          results: request.page == 1
              ? [_book('books', 'same', title: 'Во мрак')]
              : [
                  _book(
                    'books',
                    'same',
                    title: 'Оригинальная подпись',
                    narrators: ['Сергей Кузнецов'],
                  ),
                  _book('books', 'other', title: 'Не то'),
                ],
          nextPage: request.page == 1 ? 2 : null,
          usedRequestedScope: true,
        ),
      );
      final response = await _service([connector]).search(
        const SearchRequest(
          query: 'Сергей Кузнецов',
          kind: SearchKind.narrator,
        ),
      );
      expect(response.results.single.sourceBookId, 'same');
      expect(response.results.single.title, 'Во мрак');
      expect(response.results.single.narrators, ['Сергей Кузнецов']);
    },
  );

  test('Unicode genres retain non-Russian characters', () async {
    final connector = _Paged(
      'books',
      (_) => SourceSearchPage(
        results: [
          _book(
            'books',
            'hit',
            title: 'Book 1',
            genres: ['Українська фантастика'],
          ),
          _book(
            'books',
            'miss',
            title: 'Book 2',
            genres: ['Украинская фантастика'],
          ),
        ],
      ),
    );
    final response = await _service([
      connector,
    ]).search(const SearchRequest(query: 'українська', kind: SearchKind.genre));
    expect(response.results.single.sourceBookId, 'hit');
  });
}

SourceCatalogService _service(List<SourceConnector> connectors) =>
    SourceCatalogService(
      registry: SourceRegistry(connectors),
      searchEnrichmentLimit: 0,
    );

BookSearchResult _book(
  String source,
  String id, {
  required String title,
  String? author,
  List<String> narrators = const [],
  String? series,
  List<String> genres = const [],
}) => BookSearchResult(
  ref: SourceBookRef(sourceId: source, sourceBookId: id),
  sourceName: source,
  title: title,
  author: author,
  narrator: narrators.isEmpty ? null : narrators.join(', '),
  narrators: narrators,
  series: series,
  genres: genres,
);

class _Paged implements SourceConnector, PagedSourceConnector {
  _Paged(this.id, this._page);

  @override
  final String id;
  final SourceSearchPage Function(SearchRequest request) _page;
  final calls = <SearchRequest>[];

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(supportsSearch: true);

  @override
  Future<SourceSearchPage> searchPage(SearchRequest request) async {
    calls.add(request);
    return _page(request);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cursor implements SourceSearchPageCursor {}
