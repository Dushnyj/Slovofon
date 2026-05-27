import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/sources/akniga/akniga_client.dart';
import 'package:slovofon/sources/akniga/akniga_security.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('AknigaSourceConnector', () {
    test('declares HTML, ajax, headers, media, and download capabilities', () {
      final connector = AknigaSourceConnector(
        client: AknigaClient(transport: QueueAknigaTransport()),
      );

      expect(connector.id, 'akniga');
      expect(connector.name, 'Akniga');
      expect(connector.host, 'https://akniga.org');
      expect(connector.capabilities.supportsSearch, isTrue);
      expect(connector.capabilities.supportsDetails, isTrue);
      expect(connector.capabilities.supportsChapters, isTrue);
      expect(connector.capabilities.supportsDirectAudio, isTrue);
      expect(connector.capabilities.supportsDownload, isTrue);
      expect(connector.capabilities.requiresSpecialHeaders, isTrue);
      expect(connector.capabilities.hasHtmlParser, isTrue);
      expect(connector.capabilities.hasApiSignature, isTrue);
      expect(connector.mediaPolicy.allowsMediaHost('r2.akniga.club'), isTrue);
      expect(
        connector.mediaPolicy.allowsMediaHost('cdn.audioknigi.xyz'),
        isTrue,
      );
    });

    test('search maps HTML results through the source contract', () async {
      final connector = AknigaSourceConnector(
        client: AknigaClient(
          transport: QueueAknigaTransport(getResponses: [_searchHtml]),
        ),
      );

      final results = await connector.search(
        const SearchRequest(query: 'метро', page: 1),
      );

      expect(results, hasLength(1));
      expect(results.single.sourceId, 'akniga');
      expect(results.single.sourceBookId, 'metro-2033');
      expect(results.single.title, 'Метро 2033');
    });

    test(
      'details, chapters, tracks, and resolveMedia use ajax/bid tracks',
      () async {
        final transport = QueueAknigaTransport(
          getResponses: [_bookHtml],
          postResponses: [_ajaxTracksJson],
        );
        final connector = AknigaSourceConnector(
          client: AknigaClient(
            transport: transport,
            securityEncoder: AknigaSecurityEncoder(
              saltFactory: () => const [0, 1, 2, 3, 4, 5, 6, 7],
            ),
          ),
          clock: () => DateTime.utc(2026, 5, 27, 12),
        );
        final ref = SourceBookRef(
          sourceId: 'akniga',
          sourceBookId: 'metro-2033',
          sourceUri: Uri.parse('https://akniga.org/metro-2033'),
        );

        final details = await connector.getBookDetails(ref);
        final chapters = await connector.getChapters(ref);
        final tracks = await connector.getAudioTracks(ref);
        final media = await connector.resolveMedia(
          chapters.first,
          MediaResolvePurpose.playback,
        );

        expect(details.version.title, 'Метро 2033');
        expect(chapters, hasLength(2));
        expect(tracks, hasLength(2));
        expect(media.mediaSource.type, AudioMediaSourceType.url);
        expect(
          media.mediaSource.uri.toString(),
          'https://r1.akniga.club/books/metro/001.mp3',
        );
        expect(
          media.mediaSource.headers['Referer'],
          'https://akniga.org/metro-2033',
        );
        expect(media.supportsRange, isTrue);
        expect(transport.getRequests, hasLength(1));
        expect(transport.postRequests, hasLength(1));
        expect(
          Uri.splitQueryString(
            transport.postRequests.single.body,
          )['security_ls_key'],
          'live-key',
        );
      },
    );

    test('health check reports structureChanged for parser failures', () async {
      final connector = AknigaSourceConnector(
        client: AknigaClient(
          transport: QueueAknigaTransport(getStatusCodes: [500]),
        ),
        clock: () => DateTime.utc(2026, 5, 27, 12),
      );

      final health = await connector.checkHealth();

      expect(health.sourceId, 'akniga');
      expect(health.status, SourceHealthStatus.unavailable);
      expect(health.isUsable, isFalse);
    });
  });
}

class QueueAknigaTransport implements AknigaTransport {
  QueueAknigaTransport({
    this.getResponses = const [],
    this.postResponses = const [],
    this.getStatusCodes = const [],
  });

  final List<String> getResponses;
  final List<String> postResponses;
  final List<int> getStatusCodes;
  final getRequests = <RecordedAknigaGet>[];
  final postRequests = <RecordedAknigaPost>[];

  @override
  Future<AknigaTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    getRequests.add(
      RecordedAknigaGet(uri: uri, headers: Map.unmodifiable(headers)),
    );
    final index = getRequests.length - 1;
    return AknigaTransportResponse(
      statusCode: getStatusCodes.length > index ? getStatusCodes[index] : 200,
      body: getResponses.length > index ? getResponses[index] : '',
    );
  }

  @override
  Future<AknigaTransportResponse> post(
    Uri uri, {
    required List<int> bodyBytes,
    required Map<String, String> headers,
  }) async {
    postRequests.add(
      RecordedAknigaPost(
        uri: uri,
        body: utf8.decode(bodyBytes),
        headers: Map.unmodifiable(headers),
      ),
    );
    final index = postRequests.length - 1;
    return AknigaTransportResponse(
      statusCode: 200,
      body: postResponses.length > index ? postResponses[index] : '{}',
    );
  }
}

class RecordedAknigaGet {
  const RecordedAknigaGet({required this.uri, required this.headers});

  final Uri uri;
  final Map<String, String> headers;
}

class RecordedAknigaPost {
  const RecordedAknigaPost({
    required this.uri,
    required this.body,
    required this.headers,
  });

  final Uri uri;
  final String body;
  final Map<String, String> headers;
}

const _searchHtml = '''
<html><body>
  <div class="content__main__articles--item" data-bid="777">
    <a href="https://akniga.org/metro-2033" class="content__article-main-link">
      <h2 class="caption__article-main">Дмитрий Глуховский – Метро 2033</h2>
    </a>
    <img class="topic" data-src="/covers/metro-search.jpg">
    <span class="link__action">
      <svg class="icon--author"></svg><a href="/author/gluhovskiy/">Дмитрий Глуховский</a>
    </span>
    <span class="link__action">
      <svg class="icon--performer"></svg><a href="/performer/ivaschenko/">Петр Иващенко</a>
    </span>
    <span class="link__action--label--time">13 ч 6 мин</span>
  </div>
</body></html>
''';

const _bookHtml = '''
<html><body>
  <script>LIVESTREET_SECURITY_KEY = 'live-key';</script>
  <article data-bid="777">
    <h1 class="caption__article-main">Дмитрий Глуховский – Метро 2033</h1>
    <img class="topic" data-src="/covers/metro-details.jpg">
    <span class="link__action">
      <svg class="icon--author"></svg><a href="/author/gluhovskiy/">Дмитрий Глуховский</a>
    </span>
    <span class="link__action">
      <svg class="icon--performer"></svg><a href="/performer/ivaschenko/">Петр Иващенко</a>
    </span>
    <span class="hours">13 ч</span><span class="minutes">6 мин</span>
  </article>
</body></html>
''';

final _ajaxTracksJson = jsonEncode({
  'bStateError': false,
  'aItems': jsonEncode([
    {
      'id': '501',
      'title': 'Глава 01. Артем',
      'mp3': 'https://r1.akniga.club/books/metro/001.mp3',
      'duration': 1260,
      'time': 1260,
    },
    {
      'id': '502',
      'titleonly': '002',
      'file': 'https://cdn.audioknigi.xyz/books/metro/002.mp3',
      'time': 2503,
    },
  ]),
});
