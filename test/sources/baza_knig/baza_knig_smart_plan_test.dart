import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/baza_knig/baza_knig_smart_plan.dart';
import 'package:slovofon/sources/source_models.dart';

const _author = 'j.x.autor;p.title';
const _reader = 'j.x.ispolnitel;x.ispolnitel2;x.ispolnitel3';

void main() {
  test('selected fields map to the published filter names', () {
    const cases = {
      SearchKind.title: 'nazvanie',
      SearchKind.author: _author,
      SearchKind.narrator: _reader,
      SearchKind.series: 'cikl',
    };
    for (final entry in cases.entries) {
      final plans = BazaKnigSmartPlan.forRequest(
        SearchRequest(query: '  Точный запрос  ', kinds: {entry.key}),
      );
      expect(plans.first.filters, {entry.value: 'Точный запрос'});
      expect(plans.first.usedRequestedScope, isTrue);
      expect(plans.first.catalogUri, isNull);
    }
  });

  test(
    'person search covers both orders without treating title as a person',
    () {
      const queries = ['Олег Шубин', 'Шубин Олег'];
      for (final query in queries) {
        final plans = BazaKnigSmartPlan.forRequest(
          SearchRequest(query: query, kind: SearchKind.narrator),
        );
        expect(
          plans.map((plan) => plan.filters[_reader]),
          unorderedEquals(queries),
        );
        expect(plans.every((plan) => plan.filters.length == 1), isTrue);
      }
      expect(
        BazaKnigSmartPlan.forRequest(
          const SearchRequest(query: 'Война и мир', kind: SearchKind.title),
        ).single.filters,
        {'nazvanie': 'Война и мир'},
      );
    },
  );

  test(
    'genre uses confirmed public catalogue links and ignores another host',
    () {
      final catalog = Uri.parse('https://baza-knig.top/metro-2033i/');
      const strict = SearchRequest(query: 'Метро 2033', kind: SearchKind.genre);
      expect(BazaKnigSmartPlan.mayUseGenres(strict), isTrue);
      expect(BazaKnigSmartPlan.forRequest(strict), isEmpty);
      final exact = BazaKnigSmartPlan.forRequest(
        strict,
        genres: {'Метро 2033': catalog},
      ).single;
      expect(exact.catalogUri, catalog);
      expect(exact.usedRequestedScope, isTrue);
      final uncertain = BazaKnigSmartPlan.forRequest(
        const SearchRequest(query: 'фантаст', kind: SearchKind.genre),
        genres: {
          'Фантастика, фэнтези': Uri.parse(
            'https://baza-knig.top/fantastika-fentezii/',
          ),
          'Фантастика': Uri.parse('https://not-baza.example/fiction/'),
        },
      ).single;
      expect(uncertain.catalogUri?.host, 'baza-knig.top');
      expect(uncertain.usedRequestedScope, isFalse);
    },
  );

  test('bounded title probes can discover metadata for a long mixed query', () {
    const request = SearchRequest(query: 'Имя нам Легион Шубин Меж двух миров');
    final before = BazaKnigSmartPlan.forRequest(request);
    expect(before.map((scope) => scope.filters['nazvanie']), [
      'Имя нам Легион',
      'Имя нам',
      request.query,
    ]);
    expect(
      before.every((scope) => scope.isTitleProbe && !scope.usedRequestedScope),
      isTrue,
    );

    final after = BazaKnigSmartPlan.forRequest(
      request,
      seeds: [
        _book(
          'Имя нам Легион. Том 16',
          narrators: ['Шубин Олег'],
          series: 'Меж двух миров',
        ),
        _book(
          'Имя нам Легион. Том 17',
          narrators: ['Шубин Олег'],
          series: 'Меж двух миров',
        ),
      ],
    );
    expect(after.first.filters, {
      'nazvanie': 'Имя нам Легион',
      _reader: 'Шубин',
      'cikl': 'Меж двух миров',
    });
    expect(after.where((scope) => scope.filters.length == 3), hasLength(1));
    expect(after.first.usedRequestedScope, isFalse);
  });

  test(
    'series from known metadata can coexist with a separate public genre',
    () {
      final genre = Uri.parse('https://baza-knig.top/metro-2033i/');
      final scopes = BazaKnigSmartPlan.forRequest(
        const SearchRequest(
          query: 'Во мрак Андрей Дьяков Кузнецов Сергей Метро 2033',
        ),
        seeds: [
          _book(
            'Во мрак (Метро 2033)',
            authors: ['Дьяков Андрей'],
            narrators: ['Кузнецов Сергей'],
            series: 'К свету',
          ),
        ],
        genres: {'Метро 2033': genre},
      );
      expect(scopes.first.filters, {
        'nazvanie': 'Во мрак',
        _author: 'Дьяков Андрей',
        _reader: 'Кузнецов Сергей',
      });
      expect(scopes.any((scope) => scope.catalogUri == genre), isTrue);
      expect(scopes.every((scope) => !scope.usedRequestedScope), isTrue);
    },
  );

  test(
    'does not create a mixed scope from different editions or unselected roles',
    () {
      const query = 'Город туманов Борис Чёрный';
      final separate = BazaKnigSmartPlan.forRequest(
        const SearchRequest(query: query),
        seeds: [
          _book('Город туманов'),
          _book('Другая книга', narrators: ['Чёрный Борис']),
        ],
      );
      expect(separate.every((scope) => scope.filters.length == 1), isTrue);

      final authorOrSeries = BazaKnigSmartPlan.forRequest(
        const SearchRequest(
          query: query,
          kinds: {SearchKind.author, SearchKind.series},
        ),
        seeds: [
          _book('Город туманов', narrators: ['Чёрный Борис']),
        ],
      );
      expect(
        authorOrSeries.expand((scope) => scope.filters.keys),
        everyElement(isIn([_author, 'cikl'])),
      );
    },
  );

  test('a complete known person can supplement an unrestricted query', () {
    final plans = BazaKnigSmartPlan.forRequest(
      const SearchRequest(query: 'Олег Шубин'),
      seeds: [
        _book('Другая книга', narrators: ['Шубин Олег']),
      ],
    );
    expect(plans.first.filters, {_reader: 'Шубин Олег'});
    expect(plans.first.usedRequestedScope, isFalse);
  });
}

BookSearchResult _book(
  String title, {
  List<String> authors = const [],
  List<String> narrators = const [],
  String? series,
}) => BookSearchResult(
  ref: SourceBookRef(sourceId: 'baza_knig', sourceBookId: title),
  sourceName: 'Baza Knig',
  title: title,
  authors: authors,
  narrators: narrators,
  series: series,
);
