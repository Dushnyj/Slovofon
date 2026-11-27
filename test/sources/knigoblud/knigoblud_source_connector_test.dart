import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/knigoblud/knigoblud_client.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('KnigobludSourceConnector', () {
    test('declares HTML direct-audio capabilities and media allowlist', () {
      final connector = KnigobludSourceConnector();

      expect(connector.id, 'knigoblud');
      expect(connector.name, 'Knigoblud');
      expect(connector.host, 'https://www.knigoblud.club');
      expect(connector.capabilities.supportsSearch, isTrue);
      expect(connector.capabilities.supportsDetails, isTrue);
      expect(connector.capabilities.supportsChapters, isTrue);
      expect(connector.capabilities.supportsDirectAudio, isTrue);
      expect(connector.capabilities.supportsDownload, isTrue);
      expect(connector.capabilities.requiresSpecialHeaders, isTrue);
      expect(connector.capabilities.hasHtmlParser, isTrue);
      expect(
        connector.mediaPolicy.allowsMetadataHost('knigoblud.club'),
        isTrue,
      );
      expect(
        connector.mediaPolicy.allowsCoverHost('r7.audioknigi.xyz'),
        isTrue,
      );
      expect(
        connector.mediaPolicy.allowsMediaHost('r4.audioknigi.xyz'),
        isTrue,
      );
      expect(connector.mediaPolicy.allowsMediaHost('litres.ru'), isTrue);
    });

    test('search maps HTML results through the source contract', () async {
      final client = FakeKnigobludClient(searchHtml: _searchHtml);
      final connector = KnigobludSourceConnector(client: client);

      final results = await connector.search(
        const SearchRequest(query: 'дыхание зоны', page: 1),
      );

      expect(results, hasLength(1));
      expect(results.single.sourceId, 'knigoblud');
      expect(
        results.single.sourceBookId,
        '09a908a6-0ff5-4080-b607-fc3ca3684672',
      );
      expect(results.single.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(client.calls, ['search:дыхание зоны:1']);
    });

    test(
      'keeps the live-style next page and roles parsed by the worker',
      () async {
        final connector = KnigobludSourceConnector(
          client: FakeKnigobludClient(searchHtml: _searchHtml),
        );

        final page = await connector.searchPage(
          const SearchRequest(query: 'дыхание зоны'),
        );

        expect(page.results.single.authors, ['Николай Грошев']);
        expect(page.results.single.narrators, ['Тимофей Зобнин']);
        expect(page.nextPage, 2);
        expect(page.limited, isFalse);
      },
    );

    test(
      'recognizes the native no-results page as a valid empty search',
      () async {
        final connector = KnigobludSourceConnector(
          client: FakeKnigobludClient(
            searchHtml: '''
          <div class="pageContent">
            <div class="EmptyBlock">По словосочетанию <b>нет совпадений</b> ничего не найдено!</div>
          </div>
        ''',
          ),
        );

        final page = await connector.searchPage(
          const SearchRequest(query: 'нет совпадений'),
        );

        expect(page.results, isEmpty);
        expect(page.nextPage, isNull);
        expect(page.limited, isFalse);
      },
    );

    test('an unknown HTML layout is not treated as an empty search', () async {
      final connector = KnigobludSourceConnector(
        client: FakeKnigobludClient(
          searchHtml: '<main>Сервис недоступен</main>',
        ),
      );

      await expectLater(
        connector.searchPage(const SearchRequest(query: 'метро')),
        throwsA(
          isA<SourceException>().having(
            (e) => e.kind,
            'kind',
            SourceErrorKind.parser,
          ),
        ),
      );

      final health = await connector.checkHealth();
      expect(health.status, SourceHealthStatus.structureChanged);
    });

    test(
      'details, chapters, tracks, and media resolution use page data',
      () async {
        final client = FakeKnigobludClient(bookPageHtml: _bookHtml);
        final connector = KnigobludSourceConnector(
          client: client,
          clock: () => DateTime.utc(2026, 5, 27, 12),
        );
        final ref = SourceBookRef(
          sourceId: 'knigoblud',
          sourceBookId: '09a908a6-0ff5-4080-b607-fc3ca3684672',
          sourceUri: Uri.parse(
            'https://www.knigoblud.club/09a908a6-0ff5-4080-b607-fc3ca3684672',
          ),
        );

        final details = await connector.getBookDetails(ref);
        final chapters = await connector.getChapters(ref);
        final tracks = await connector.getAudioTracks(ref);
        final media = await connector.resolveMedia(
          chapters.first,
          MediaResolvePurpose.playback,
        );

        expect(details.version.title, 'S.T.A.L.K.E.R. Дыхание зоны');
        expect(chapters, hasLength(2));
        expect(tracks, hasLength(2));
        expect(tracks.first.mediaRef, chapters.first.streamRef);
        expect(
          media.mediaSource.uri.toString(),
          'https://r4.audioknigi.xyz/2f9a5d7ff98284fc/audio/01-prolog.mp3',
        );
        expect(media.mediaSource.headers['Referer'], ref.sourceUri.toString());
        expect(media.supportsRange, isTrue);
        expect(client.calls, ['book:09a908a6-0ff5-4080-b607-fc3ca3684672']);
      },
    );

    test('health reports parser failures without throwing', () async {
      final connector = KnigobludSourceConnector(
        client: FakeKnigobludClient(
          error: const SourceException(
            sourceId: 'knigoblud',
            kind: SourceErrorKind.parser,
            message: 'layout changed',
          ),
        ),
      );

      final health = await connector.checkHealth();

      expect(health.sourceId, 'knigoblud');
      expect(health.status, SourceHealthStatus.structureChanged);
      expect(health.message, 'layout changed');
    });
  });
}

class FakeKnigobludClient implements KnigobludClient {
  FakeKnigobludClient({
    this.searchHtml = '',
    this.bookPageHtml = '',
    this.error,
  });

  final String searchHtml;
  final String bookPageHtml;
  final SourceException? error;
  final calls = <String>[];

  @override
  Uri get baseUri => KnigobludClient.defaultBaseUri;

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

const _searchHtml = '''
<html><body>
  <div class="bookListItem">
    <a class="bookListItemCoverNameText" href="/09a908a6-0ff5-4080-b607-fc3ca3684672">
      S.T.A.L.K.E.R. Дыхание зоны
    </a>
    <div class="bookListItemMetaBlock">
      <span>✍️</span><a href="/author">Николай Грошев</a>
      <span>🎙️</span><a href="/reader">Тимофей Зобнин</a>
    </div>
  </div>
  <div class="PageNavPageButtons">
    <a class="PageNavButton _page" href="/search?q=дыхание+зоны&amp;page=2" data-page="2">2</a>
  </div>
</body></html>
''';

const _bookHtml = '''
<html><body>
  <h1 class="BookTitle">S.T.A.L.K.E.R. Дыхание зоны</h1>
  <script>
  KB.playerInit({
    "uuid":"09a908a6-0ff5-4080-b607-fc3ca3684672",
    "blocked":false,
    "playlist":[
      {"fileId":1655617,"title":"01-prolog","duration":1246,"src":"https:\\/\\/r4.audioknigi.xyz\\/2f9a5d7ff98284fc\\/audio\\/01-prolog.mp3"},
      {"fileId":1655618,"title":"02-glava","duration":60,"src":"https:\\/\\/r4.audioknigi.xyz\\/2f9a5d7ff98284fc\\/audio\\/02-glava.mp3"}
    ]
  });
  </script>
</body></html>
''';
