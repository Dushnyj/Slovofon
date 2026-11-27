import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/sources/baza_knig/baza_knig_client.dart';
import 'package:slovofon/sources/baza_knig/baza_knig_public_search.dart';
import 'package:slovofon/sources/baza_knig/baza_knig_source_connector.dart';
import 'package:slovofon/sources/source_models.dart';

final _origin = BazaKnigClient.defaultBaseUri;

void main() {
  test(
    'title follows the published same-filter link without a paid flag',
    () async {
      const request = SearchRequest(query: 'Два слова', kind: SearchKind.title);
      final firstUri = _filter({'nazvanie': request.query});
      final nextUri = Uri.parse('${firstUri}page/2/');
      final transport = _FixtureTransport({
        firstUri: _fixture(firstUri, 1, 10001, next: nextUri.toString()),
        nextUri: _fixture(nextUri, 2, 10002),
      });
      final connector = _connector(transport);
      final first = await connector.searchPage(request);
      expect(first.usedRequestedScope, isTrue);
      expect(first.results.single.accessType, AccessType.unknown);
      expect(first.results.single.isFull, isNull);
      expect(first.results.single.isFree, isNull);
      expect(first.nextPage, 2);
      expect(firstUri.path, contains('+'));
      expect(firstUri.path, isNot(contains('litres')));
      final second = await connector.searchPage(
        request.copyWith(page: first.nextPage, sourceCursor: first.nextCursor),
      );
      expect(
        second.results.single.sourceBookId,
        isNot(first.results.single.sourceBookId),
      );
      expect(second.nextCursor, isNull);
      expect(transport.gets, [firstUri, nextUri]);
      expect(transport.posts, isEmpty);
    },
  );

  for (final (kind, field, term) in [
    (SearchKind.author, 'j.x.autor;p.title', 'Дьяков Андрей'),
    (
      SearchKind.narrator,
      'j.x.ispolnitel;x.ispolnitel2;x.ispolnitel3',
      'Шубин Олег',
    ),
    (SearchKind.series, 'cikl', 'Меж двух миров'),
  ]) {
    test('explicit $kind uses its public form field', () async {
      final uri = _filter({field: term});
      final transport = _FixtureTransport({uri: _fixture(uri, 1, 10001)});
      final page = await _connector(
        transport,
      ).searchPage(SearchRequest(query: term, kind: kind));
      expect(page.results, hasLength(1));
      expect(page.usedRequestedScope, isTrue);
      expect(transport.gets.single, uri);
      expect(transport.posts, isEmpty);
    });
  }

  test(
    'genre catalogue is taken from the public categories, not built',
    () async {
      const request = SearchRequest(
        query: 'Метро 2033',
        kind: SearchKind.genre,
      );
      final genre = _origin.resolve('/verified-category/');
      final second = genre.resolve('page/2/');
      final transport = _FixtureTransport({
        _origin:
            '<ul class="left-menu-items"><li><a href="/verified-category/">Метро 2033</a></li></ul>',
        genre: _fixture(genre, 1, 10001, next: 'page/2/'),
        second: _fixture(second, 2, 10002),
      });
      final connector = _connector(transport);
      final page = await connector.searchPage(request);
      expect(page.usedRequestedScope, isTrue);
      expect(page.nextPage, 2);
      final more = await connector.searchPage(
        request.copyWith(page: 2, sourceCursor: page.nextCursor),
      );
      expect(more.results.single.sourceBookId, contains('10002'));
      expect(transport.gets, [_origin, genre, second]);
      expect(transport.posts, isEmpty);
    },
  );

  test('genre may follow a permanent same-origin category alias once', () async {
    const request = SearchRequest(query: 'Метро 2033', kind: SearchKind.genre);
    final alias = _origin.resolve('/old-category/');
    final canonical = _origin.resolve('/current-category/');
    final second = canonical.resolve('page/2/');
    final transport = _FixtureTransport(
      {
        _origin:
            '<ul class="left-menu-items"><li><a href="/old-category/">Метро 2033</a></li></ul>',
        canonical: _fixture(canonical, 1, 10001, next: 'page/2/'),
        second: _fixture(second, 2, 10002),
      },
      redirects: {alias: (301, canonical)},
    );
    final connector = _connector(transport);
    final page = await connector.searchPage(request);
    final more = await connector.searchPage(
      request.copyWith(page: 2, sourceCursor: page.nextCursor),
    );
    expect(more.results.single.sourceBookId, contains('10002'));
    expect(transport.gets, [_origin, alias, canonical, second]);
    expect(transport.posts, isEmpty);
  });

  test('genre alias cannot follow a site check even on HTTP 301', () async {
    const request = SearchRequest(query: 'Метро 2033', kind: SearchKind.genre);
    final alias = _origin.resolve('/old-category/');
    final check = _origin.resolve('/bk-chal/');
    final transport = _FixtureTransport(
      {
        _origin:
            '<ul class="left-menu-items"><li><a href="/old-category/">Метро 2033</a></li></ul>',
        check: _fixture(check, 1, 10001),
      },
      redirects: {alias: (301, check)},
    );
    await expectLater(
      _connector(transport).searchPage(request),
      throwsA(
        isA<SourceException>().having(
          (error) => error.kind,
          'kind',
          SourceErrorKind.accessRestricted,
        ),
      ),
    );
    expect(transport.gets, [_origin, alias]);
    expect(transport.posts, isEmpty);
  });

  test('mixed derives combined fields from its initial title cards', () async {
    const request = SearchRequest(query: 'Имя нам Легион Шубин Меж двух миров');
    final title = _filter({'nazvanie': 'Имя нам Легион'});
    final combined = _filter({
      'nazvanie': 'Имя нам Легион',
      'j.x.ispolnitel;x.ispolnitel2;x.ispolnitel3': 'Шубин',
      'cikl': 'Меж двух миров',
    });
    final second = Uri.parse('${combined}page/2/');
    final transport = _FixtureTransport({
      _origin: '',
      title: _fixture(title, 1, 10001),
      combined: _fixture(combined, 1, 10001, next: second.toString()),
      second: _fixture(second, 2, 10002),
    });
    final connector = _connector(transport);
    final page = await connector.searchPage(request);
    expect(page.handlesQueryVariants, isTrue);
    expect(page.usedRequestedScope, isFalse);
    expect(page.results, hasLength(1));
    expect(transport.gets, [_origin, title, combined]);
    expect(transport.posts, [request.query]);
    final more = await connector.searchPage(
      request.copyWith(page: 2, sourceCursor: page.nextCursor),
    );
    expect(more.results.single.sourceBookId, contains('10002'));
    expect(transport.gets.last, second);
  });

  test(
    'ordinary search access check does not start a new structured scope',
    () async {
      const request = SearchRequest(query: 'Метро');
      final title = _filter({'nazvanie': 'Метро'});
      final second = Uri.parse('${title}page/2/');
      final transport = _FixtureTransport({
        _origin: '',
        title: _fixture(title, 1, 10001, next: second.toString()),
        second: _fixture(second, 2, 10002),
      }, blockOrdinary: true);
      final connector = _connector(transport);
      final page = await connector.searchPage(request);
      expect(page.limited, isTrue);
      expect(page.results.single.sourceBookId, contains('10001'));
      expect(transport.gets, [_origin, title]);
      final more = await connector.searchPage(
        request.copyWith(page: 2, sourceCursor: page.nextCursor),
      );
      expect(more.results.single.sourceBookId, contains('10002'));
      expect(transport.posts, ['Метро']);
      expect(transport.gets, [_origin, title, second]);
    },
  );

  for (final wrong in [
    'https://other.example/f/nazvanie=Метро/sort=news_read/order=desc/page/2/',
    'https://baza-knig.top/f/nazvanie=Другое/sort=news_read/order=desc/page/2/',
    'https://baza-knig.top/f/nazvanie=Метро/sort=news_read/order=desc/page/3/',
  ]) {
    test(
      'foreign, changed and skipped next links are not fetched: $wrong',
      () async {
        const request = SearchRequest(query: 'Метро', kind: SearchKind.title);
        final uri = _filter({'nazvanie': request.query});
        final transport = _FixtureTransport({
          uri: _fixture(uri, 1, 10001, next: wrong),
        });
        final page = await _connector(transport).searchPage(request);
        expect(page.results, hasLength(1));
        expect(page.limited, isTrue);
        expect(page.nextPage, isNull);
        expect(transport.gets, [uri]);
      },
    );
  }

  test(
    'different canonical returned instead of the advertised page is an error',
    () async {
      const request = SearchRequest(query: 'Метро', kind: SearchKind.title);
      final uri = _filter({'nazvanie': request.query});
      final second = Uri.parse('${uri}page/2/');
      final transport = _FixtureTransport({
        uri: _fixture(uri, 1, 10001, next: second.toString()),
        second: _fixture(uri, 1, 10001),
      });
      final connector = _connector(transport);
      final first = await connector.searchPage(request);
      await expectLater(
        connector.searchPage(
          request.copyWith(page: 2, sourceCursor: first.nextCursor),
        ),
        throwsA(
          isA<SourceException>().having(
            (e) => e.kind,
            'kind',
            SourceErrorKind.parser,
          ),
        ),
      );
    },
  );
}

Uri _filter(Map<String, String> fields) =>
    BazaKnigPublicSearch.filterUri(_origin, fields)!;

BazaKnigSourceConnector _connector(_FixtureTransport transport) =>
    BazaKnigSourceConnector(client: BazaKnigClient(transport: transport));

String _fixture(Uri uri, int page, int id, {String? next}) =>
    '''
<html><head><link rel="canonical" href="${htmlEscape.convert(uri.toString())}">
<title>Фильтр ${next == null ? 1 : 2} новостей</title></head><body>
  <div id="dle-content">
    <div class="short"><div class="short-title"><a href="/fantastika-fentezii/$id-example.html">Имя нам Легион. Том 16</a></div>
      <ul class="short-items">
        <li>Автор: <a href="/xfsearch/autor/example/">Дьяков Андрей</a></li>
        <li>Читает: <a href="/xfsearch/ispolnitel/example/">Шубин Олег</a></li>
        <li>Цикл: <a href="/xfsearch/cikl/example/">Меж двух миров</a> (16)</li>
        <li>Жанр: <a href="/verified-category/">Метро 2033</a></li>
      </ul>
    </div>
    <div class="page-nav"><div class="navigation"><span>$page</span>
      ${next == null ? '' : '<a href="${htmlEscape.convert(next)}">${page + 1}</a>'}
    </div></div>
  </div>
</body></html>
''';

class _FixtureTransport implements BazaKnigTransport {
  _FixtureTransport(
    this.responses, {
    this.blockOrdinary = false,
    this.redirects = const {},
  });

  final Map<Uri, String> responses;
  final Map<Uri, (int, Uri)> redirects;
  final bool blockOrdinary;
  final gets = <Uri>[];
  final posts = <String>[];

  @override
  Future<BazaKnigTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    bool followRedirects = true,
  }) async {
    expect(
      followRedirects,
      isFalse,
      reason:
          'Public search should not auto-follow foreign or unrelated routes.',
    );
    gets.add(uri);
    if (redirects[uri] case (final statusCode, final location)) {
      return BazaKnigTransportResponse(
        statusCode: statusCode,
        body: '',
        finalUri: uri,
        redirectLocation: location,
      );
    }
    return BazaKnigTransportResponse(
      statusCode: responses.containsKey(uri) ? 200 : 404,
      body: responses[uri] ?? '',
      finalUri: uri,
    );
  }

  @override
  Future<BazaKnigTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required List<int> bodyBytes,
  }) async {
    final query = Uri.splitQueryString(utf8.decode(bodyBytes))['story']!;
    posts.add(query);
    if (blockOrdinary) {
      return BazaKnigTransportResponse(
        statusCode: 302,
        body: '',
        redirectLocation: _origin.resolve('/bk-chal'),
      );
    }
    return BazaKnigTransportResponse(
      statusCode: 200,
      body:
          '''<div id="dle-content"><form id="fullsearch" method="post"
        action="https://baza-knig.top/index.php?do=search">
        <input name="story" value="${htmlEscape.convert(query)}">
        <input name="do" value="search"><input name="subaction" value="search">
        <input name="search_start" value="1"><input name="result_from" value="1">
        <input name="full_search" value="0">
      </form></div>''',
      finalUri: uri,
    );
  }
}
