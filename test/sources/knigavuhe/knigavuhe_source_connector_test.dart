import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/knigavuhe/knigavuhe_client.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('KnigavuheSourceConnector', () {
    test('declares HTML direct-audio capabilities and media allowlist', () {
      final connector = KnigavuheSourceConnector();

      expect(connector.id, 'knigavuhe');
      expect(connector.name, 'Knigavuhe');
      expect(connector.host, 'https://knigavuhe.org');
      expect(connector.capabilities.supportsSearch, isTrue);
      expect(connector.capabilities.supportsDetails, isTrue);
      expect(connector.capabilities.supportsChapters, isTrue);
      expect(connector.capabilities.supportsDirectAudio, isTrue);
      expect(connector.capabilities.supportsDownload, isTrue);
      expect(connector.capabilities.requiresSpecialHeaders, isTrue);
      expect(connector.capabilities.hasHtmlParser, isTrue);
      expect(connector.mediaPolicy.allowsMetadataHost('knigavuhe.org'), isTrue);
      expect(connector.mediaPolicy.allowsCoverHost('s5.knigavuhe.org'), isTrue);
      expect(
        connector.mediaPolicy.allowsMediaHost('s12.knigavuhe.org'),
        isTrue,
      );
      expect(connector.mediaPolicy.allowsMediaHost('litres.ru'), isTrue);
    });

    test('search maps HTML results through the source contract', () async {
      final client = FakeKnigavuheClient(searchHtml: _searchHtml);
      final connector = KnigavuheSourceConnector(client: client);

      final results = await connector.search(
        const SearchRequest(query: 'дыхание зоны', page: 1),
      );

      expect(results, hasLength(1));
      expect(results.single.sourceId, 'knigavuhe');
      expect(results.single.sourceBookId, 'book/8996-stalker-dykhanie-zony');
      expect(results.single.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(client.calls, ['search:дыхание зоны:1']);
    });

    test(
      'details, chapters, tracks, and media resolution use page data',
      () async {
        final client = FakeKnigavuheClient(bookPageHtml: _bookHtml);
        final connector = KnigavuheSourceConnector(
          client: client,
          clock: () => DateTime.utc(2026, 5, 27, 12),
        );
        final ref = SourceBookRef(
          sourceId: 'knigavuhe',
          sourceBookId: 'book/8996-stalker-dykhanie-zony',
          sourceUri: Uri.parse(
            'https://knigavuhe.org/book/8996-stalker-dykhanie-zony/',
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
        expect(chapters, hasLength(1));
        expect(tracks.single.mediaRef, chapters.single.streamRef);
        expect(
          media.mediaSource.uri.toString(),
          'https://s12.knigavuhe.org/1/audio/8996/01-prolog.mp3',
        );
        expect(media.mediaSource.headers['Referer'], ref.sourceUri.toString());
        expect(media.supportsRange, isTrue);
        expect(client.calls, ['book:book/8996-stalker-dykhanie-zony']);
      },
    );

    test('health reports parser failures without throwing', () async {
      final connector = KnigavuheSourceConnector(
        client: FakeKnigavuheClient(
          error: const SourceException(
            sourceId: 'knigavuhe',
            kind: SourceErrorKind.parser,
            message: 'layout changed',
          ),
        ),
      );

      final health = await connector.checkHealth();

      expect(health.sourceId, 'knigavuhe');
      expect(health.status, SourceHealthStatus.structureChanged);
      expect(health.message, 'layout changed');
    });
  });
}

class FakeKnigavuheClient implements KnigavuheClient {
  FakeKnigavuheClient({
    this.searchHtml = '',
    this.bookPageHtml = '',
    this.error,
  });

  final String searchHtml;
  final String bookPageHtml;
  final SourceException? error;
  final calls = <String>[];

  @override
  Uri get baseUri => KnigavuheClient.defaultBaseUri;

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
  <div class="bookkitem">
    <a class="bookkitem_name" href="/book/8996-stalker-dykhanie-zony/">
      S.T.A.L.K.E.R. Дыхание зоны
    </a>
    <div class="bookkitem_author"><a>Николай Грошев</a></div>
    <div class="bookkitem_performer"><a>Тимофей Зобнин</a></div>
  </div>
</body></html>
''';

const _bookHtml = '''
<html><body>
  <div class="book_title">
    <h1 class="book_title_elem book_title_name">S.T.A.L.K.E.R. Дыхание зоны</h1>
    <div class="book_title_elem"><span>автор</span><a>Николай Грошев</a></div>
    <div class="book_title_elem"><span>читает</span><a>Тимофей Зобнин</a></div>
  </div>
  <script>
  new BookPlayer(8996, [
    {"id":874852,"title":"0.1 prolog","url":"https:\\/\\/s12.knigavuhe.org\\/1\\/audio\\/8996\\/01-prolog.mp3","duration":1246}
  ]);
  </script>
</body></html>
''';
