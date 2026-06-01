import 'package:flutter_test/flutter_test.dart';
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

const _searchHtml = '''
<html><body>
  <div class="short">
    <a class="short-title" href="/fantastika-fentezii/7411-dyhanie-zony-nikolay-groshev.html">
      Дыхание зоны (S.T.A.L.K.E.R.)
    </a>
  </div>
</body></html>
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
