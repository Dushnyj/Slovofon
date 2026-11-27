import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/baza_knig/baza_knig_client.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('BazaKnigSourceConnector', () {
    test('declares HTML direct-audio capabilities and media allowlist', () {
      final connector = BazaKnigSourceConnector();

      expect(connector.id, 'baza_knig');
      expect(connector.name, 'Baza Knig');
      expect(connector.host, 'https://baza-knig.top');
      expect(connector.capabilities.supportsSearch, isTrue);
      expect(connector.capabilities.supportsDetails, isTrue);
      expect(connector.capabilities.supportsChapters, isTrue);
      expect(connector.capabilities.supportsDirectAudio, isTrue);
      expect(connector.capabilities.supportsDownload, isTrue);
      expect(connector.capabilities.requiresSpecialHeaders, isTrue);
      expect(connector.capabilities.hasHtmlParser, isTrue);
      expect(connector.mediaPolicy.allowsMetadataHost('baza-knig.top'), isTrue);
      expect(connector.mediaPolicy.allowsCoverHost('baza-knig.top'), isTrue);
      expect(connector.mediaPolicy.allowsMediaHost('1s.abooka.casa'), isTrue);
      expect(connector.mediaPolicy.allowsMediaHost('archive.org'), isTrue);
    });

    test('search maps HTML results through the source contract', () async {
      final client = FakeBazaKnigClient(searchHtml: _searchHtml);
      final connector = BazaKnigSourceConnector(client: client);

      final results = await connector.search(
        const SearchRequest(query: 'дыхание зоны', page: 1),
      );

      expect(results, hasLength(1));
      expect(results.single.sourceId, 'baza_knig');
      expect(
        results.single.sourceBookId,
        'fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
      );
      expect(results.single.title, 'Дыхание зоны (S.T.A.L.K.E.R.)');
      expect(client.calls, ['search:дыхание зоны:1']);
    });

    test(
      'native header and pager forms preserve UTF-8 and pagination',
      () async {
        const query = 'Дыхание зоны & метро';
        final transport = _SearchTransport(
          respond: (uri) => BazaKnigTransportResponse(
            statusCode: 200,
            body: _nativeSearchHtml(
              query,
              next: uri.path == '/' ? '2' : null,
              range: uri.path == '/'
                  ? (first: 1, last: 55, total: 81)
                  : (first: 56, last: 81, total: 81),
              card: uri.path == '/' ? _searchCardHtml : _secondSearchCardHtml,
            ),
            finalUri: uri,
          ),
        );
        final connector = BazaKnigSourceConnector(
          client: BazaKnigClient(transport: transport),
        );

        final first = await connector.searchPage(
          const SearchRequest(query: query),
        );
        expect(first.results.single.title, 'Дыхание зоны (S.T.A.L.K.E.R.)');
        expect(first.limited, isFalse);
        expect(first.nextPage, 2);

        final last = await connector.searchPage(
          SearchRequest(query: query, page: first.nextPage!),
        );
        expect(last.results.single.title, 'Метро 2033');
        expect(last.nextPage, isNull);
        expect(last.limited, isFalse);
        expect(transport.posts.map((post) => post.uri.toString()), [
          'https://baza-knig.top/',
          'https://baza-knig.top/index.php?do=search',
        ]);
        for (final post in transport.posts) {
          expect(
            post.headers['Content-Type'],
            'application/x-www-form-urlencoded',
          );
          expect(post.form['story'], query);
          expect(post.form['do'], 'search');
          expect(post.form['subaction'], 'search');
        }
        expect(transport.posts.first.form['titleonly'], '3');
        expect(transport.posts.last.form['search_start'], '2');
        expect(transport.posts.last.form['result_from'], '56');
        expect(transport.posts.last.form['full_search'], '0');
      },
    );

    test('the native no-match form is a complete empty search', () async {
      final connector = BazaKnigSourceConnector(
        client: FakeBazaKnigClient(
          searchHtml: _nativeSearchHtml('нет такой книги'),
        ),
      );
      final page = await connector.searchPage(
        const SearchRequest(query: 'нет такой книги'),
      );
      expect(page.results, isEmpty);
      expect(page.nextPage, isNull);
      expect(page.limited, isFalse);
    });

    test('a malformed native next page is limited, not complete', () async {
      final connector = BazaKnigSourceConnector(
        client: FakeBazaKnigClient(
          searchHtml: _nativeSearchHtml('метро', next: '9'),
        ),
      );
      final page = await connector.searchPage(
        const SearchRequest(query: 'метро'),
      );
      expect(page.nextPage, isNull);
      expect(page.limited, isTrue);
    });

    test(
      'a missing next action is incomplete when the range has more',
      () async {
        final connector = BazaKnigSourceConnector(
          client: FakeBazaKnigClient(
            searchHtml: _nativeSearchHtml(
              'метро',
              range: (first: 56, last: 110, total: 112),
              card: _secondSearchCardHtml,
            ),
          ),
        );
        final page = await connector.searchPage(
          const SearchRequest(query: 'метро', page: 2),
        );
        expect(page.results.single.title, 'Метро 2033');
        expect(page.nextPage, isNull);
        expect(page.limited, isTrue);
      },
    );

    for (final (name, response) in [
      (
        'redirected back to page one',
        _nativeSearchHtml(
          'метро',
          next: '2',
          range: (first: 1, last: 55, total: 81),
          withCard: true,
        ),
      ),
      (
        'different query',
        _nativeSearchHtml(
          'сторонний запрос',
          range: (first: 56, last: 81, total: 81),
          withCard: true,
        ),
      ),
      ('home page cards', _searchHtml),
      ('unverified empty page', _nativeSearchHtml('метро')),
      (
        'a range but no recognized cards',
        _nativeSearchHtml('метро', range: (first: 56, last: 81, total: 81)),
      ),
    ]) {
      test('pager rejects an HTTP 200 with $name', () async {
        final connector = BazaKnigSourceConnector(
          client: FakeBazaKnigClient(searchHtml: response),
        );
        await expectLater(
          connector.searchPage(const SearchRequest(query: 'метро', page: 2)),
          throwsA(
            isA<SourceException>().having(
              (error) => error.kind,
              'kind',
              SourceErrorKind.parser,
            ),
          ),
        );
      });
    }

    test(
      'HTTP 429 is reported as rate limited in search and diagnostics',
      () async {
        final connector = BazaKnigSourceConnector(
          client: BazaKnigClient(
            transport: _SearchTransport(
              respond: (uri) => BazaKnigTransportResponse(
                statusCode: 429,
                body: '',
                finalUri: uri,
              ),
            ),
          ),
        );
        await expectLater(
          connector.searchPage(const SearchRequest(query: 'метро')),
          throwsA(
            isA<SourceException>().having(
              (error) => error.kind,
              'kind',
              SourceErrorKind.rateLimited,
            ),
          ),
        );
        expect(
          (await connector.checkHealth()).status,
          SourceHealthStatus.rateLimited,
        );
      },
    );

    test(
      'page two 302 to a site check is restricted rather than empty',
      () async {
        final transport = _SearchTransport(
          respond: (uri) => uri.path == '/'
              ? BazaKnigTransportResponse(
                  statusCode: 200,
                  body: _nativeSearchHtml('метро', next: '2', withCard: true),
                  finalUri: uri,
                )
              : BazaKnigTransportResponse(
                  statusCode: 302,
                  body: '<title>302 Found</title>',
                  finalUri: uri,
                  redirectLocation: uri.resolve('/bk-chal'),
                ),
        );
        final connector = BazaKnigSourceConnector(
          client: BazaKnigClient(transport: transport),
        );
        final first = await connector.searchPage(
          const SearchRequest(query: 'метро'),
        );
        expect(first.results, hasLength(1));
        await expectLater(
          connector.searchPage(
            SearchRequest(query: 'метро', page: first.nextPage!),
          ),
          throwsA(
            isA<SourceException>().having(
              (error) => error.kind,
              'kind',
              SourceErrorKind.accessRestricted,
            ),
          ),
        );
      },
    );

    test(
      'catalog keeps first-page results and retries restricted page only on demand',
      () async {
        const query = 'дыхание зоны';
        final transport = _SearchTransport(
          respond: (uri) => uri.path == '/'
              ? BazaKnigTransportResponse(
                  statusCode: 200,
                  body: _nativeSearchHtml(query, next: '2', withCard: true),
                  finalUri: uri,
                )
              : BazaKnigTransportResponse(
                  statusCode: 302,
                  body: '<title>302 Found</title>',
                  finalUri: uri,
                  redirectLocation: uri.resolve('/bk-chal'),
                ),
        );
        final catalog = SourceCatalogService(
          registry: SourceRegistry([
            BazaKnigSourceConnector(client: transport.client),
          ]),
          searchEnrichmentLimit: 0,
        );
        const request = SearchRequest(query: query);
        final response = await catalog.search(request);
        expect(response.results.single.title, 'Дыхание зоны (S.T.A.L.K.E.R.)');
        expect(response.failures.single.kind, SourceErrorKind.accessRestricted);
        expect(response.sourceStatuses.single.failedPage, 2);
        expect(response.hasMore, isFalse);
        expect(response.retryContinuation, isNotNull);
        expect(transport.posts.map((post) => post.uri.path), [
          '/',
          '/index.php',
        ]);

        final repeated = await catalog.search(
          request.copyWith(continuation: response.retryContinuation),
        );
        expect(repeated.results.single.title, response.results.single.title);
        expect(repeated.failures.single.kind, SourceErrorKind.accessRestricted);
        expect(repeated.sourceStatuses.single.failedPage, 2);
        expect(transport.posts.map((post) => post.uri.path), [
          '/',
          '/index.php',
          '/index.php',
        ]);
      },
    );

    test(
      'a 200 interstitial document is not a successful empty search',
      () async {
        final connector = BazaKnigSourceConnector(
          client: _SearchTransport(
            respond: (uri) => BazaKnigTransportResponse(
              statusCode: 200,
              body: '<script>const bk_challenge = true;</script>',
              finalUri: uri,
            ),
          ).client,
        );
        await expectLater(
          connector.searchPage(const SearchRequest(query: 'метро')),
          throwsA(
            isA<SourceException>().having(
              (error) => error.kind,
              'kind',
              SourceErrorKind.accessRestricted,
            ),
          ),
        );
        expect(
          (await connector.checkHealth()).status,
          SourceHealthStatus.unavailable,
        );
      },
    );

    test(
      'details, chapters, tracks, and media resolution use page data',
      () async {
        final client = FakeBazaKnigClient(bookPageHtml: _bookHtml);
        final connector = BazaKnigSourceConnector(
          client: client,
          clock: () => DateTime.utc(2026, 5, 27, 12),
        );
        final ref = SourceBookRef(
          sourceId: 'baza_knig',
          sourceBookId:
              'fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
          sourceUri: Uri.parse(
            'https://baza-knig.top/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
          ),
        );

        final details = await connector.getBookDetails(ref);
        final chapters = await connector.getChapters(ref);
        final tracks = await connector.getAudioTracks(ref);
        final media = await connector.resolveMedia(
          chapters.first,
          MediaResolvePurpose.playback,
        );

        expect(details.version.title, 'Дыхание зоны (S.T.A.L.K.E.R.)');
        expect(chapters, hasLength(1));
        expect(tracks.single.mediaRef, chapters.single.streamRef);
        expect(
          media.mediaSource.uri.toString(),
          'https://1s.abooka.casa/audioknigi/7411/2/0-vstuplenie.mp3',
        );
        expect(media.mediaSource.headers['Referer'], ref.sourceUri.toString());
        expect(media.supportsRange, isTrue);
        expect(client.calls, [
          'book:fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        ]);
      },
    );

    test('health reports parser failures without throwing', () async {
      final connector = BazaKnigSourceConnector(
        client: FakeBazaKnigClient(
          error: const SourceException(
            sourceId: 'baza_knig',
            kind: SourceErrorKind.parser,
            message: 'layout changed',
          ),
        ),
      );

      final health = await connector.checkHealth();

      expect(health.sourceId, 'baza_knig');
      expect(health.status, SourceHealthStatus.structureChanged);
      expect(health.message, 'layout changed');
    });

    test('book HTML cache drops failed futures so retry can refetch', () async {
      final client = FlakyBazaKnigClient(bookPageHtml: _bookHtml);
      final connector = BazaKnigSourceConnector(client: client);
      final ref = SourceBookRef(
        sourceId: 'baza_knig',
        sourceBookId:
            'fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        sourceUri: Uri.parse(
          'https://baza-knig.top/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        ),
      );

      await expectLater(
        connector.getBookDetails(ref),
        throwsA(isA<SourceException>()),
      );

      final details = await connector.getBookDetails(ref);

      expect(details.version.title, 'Дыхание зоны (S.T.A.L.K.E.R.)');
      expect(client.calls, [
        'book:fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
        'book:fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html',
      ]);
    });
  });
}

class _SearchTransport implements BazaKnigTransport {
  _SearchTransport({required this.respond});

  final BazaKnigTransportResponse Function(Uri uri) respond;
  final posts =
      <({Uri uri, Map<String, String> headers, Map<String, String> form})>[];

  BazaKnigClient get client => BazaKnigClient(transport: this);

  @override
  Future<BazaKnigTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async => throw StateError('The search must not use GET');

  @override
  Future<BazaKnigTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required List<int> bodyBytes,
  }) async {
    posts.add((
      uri: uri,
      headers: headers,
      form: Uri.splitQueryString(utf8.decode(bodyBytes)),
    ));
    return respond(uri);
  }
}

class FakeBazaKnigClient implements BazaKnigClient {
  FakeBazaKnigClient({
    this.searchHtml = '',
    this.bookPageHtml = '',
    this.error,
  });

  final String searchHtml;
  final String bookPageHtml;
  final SourceException? error;
  final calls = <String>[];

  @override
  Uri get baseUri => BazaKnigClient.defaultBaseUri;

  @override
  Future<String> searchBooksHtml({required String query, int page = 1}) async {
    calls.add('search:$query:$page');
    if (error != null) {
      throw error!;
    }
    return searchHtml;
  }

  @override
  Future<String> bookHtml(SourceBookRef ref) async {
    calls.add('book:${ref.sourceBookId}');
    if (error != null) {
      throw error!;
    }
    return bookPageHtml;
  }
}

class FlakyBazaKnigClient implements BazaKnigClient {
  FlakyBazaKnigClient({required this.bookPageHtml});

  final String bookPageHtml;
  final calls = <String>[];
  var _failed = false;

  @override
  Uri get baseUri => BazaKnigClient.defaultBaseUri;

  @override
  Future<String> searchBooksHtml({required String query, int page = 1}) {
    throw UnimplementedError();
  }

  @override
  Future<String> bookHtml(SourceBookRef ref) async {
    calls.add('book:${ref.sourceBookId}');
    if (!_failed) {
      _failed = true;
      throw const SourceException(
        sourceId: 'baza_knig',
        kind: SourceErrorKind.network,
        message: 'offline',
      );
    }
    return bookPageHtml;
  }
}

String _nativeSearchHtml(
  String query, {
  String? next,
  bool withCard = false,
  ({int first, int last, int total})? range,
  String? card,
}) =>
    '''
<div id="dle-content">
  <form id="fullsearch" method="post" action="https://baza-knig.top/index.php?do=search">
    <input name="story" value="${htmlEscape.convert(query)}">
    <input name="do" value="search">
    <input name="subaction" value="search">
    <input name="search_start" value="0">
    <input name="result_from" value="1">
    <input name="full_search" value="0">
    ${range == null ? '' : '<div><b>Результаты</b><br>По Вашему запросу найдено ${range.total} ответов (Результаты запроса ${range.first} - ${range.last}) :</div>'}
  </form>
  ${card ?? (withCard ? _searchCardHtml : '')}
  ${next == null ? '' : '<a id="nextlink" onclick="javascript:list_submit($next); return(false)" href="#">Следующая страница</a>'}
</div>
''';

const _searchHtml = '<html><body>$_searchCardHtml</body></html>';

const _searchCardHtml = '''
  <div class="short">
    <a class="short-title" href="/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html">
      Дыхание зоны (S.T.A.L.K.E.R.)
    </a>
  </div>
''';

const _secondSearchCardHtml = '''
  <div class="short">
    <a class="short-title" href="/fantastika-fentezii/1234-metro-2033.html">
      Метро 2033
    </a>
  </div>
''';

const _bookHtml = '''
<html><body>
  <h1 class="full-title">Дыхание зоны (S.T.A.L.K.E.R.)</h1>
  <script>
  new Playerjs({ id:"player2", file:[
    {"title":"0-vstuplenie","file":"https:\\/\\/1s.abooka.casa\\/audioknigi\\/7411\\/2\\/0-vstuplenie.mp3"}
  ]});
  </script>
</body></html>
''';
