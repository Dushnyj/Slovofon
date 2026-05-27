import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/akniga/akniga_client.dart';
import 'package:slovofon/sources/akniga/akniga_security.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('AknigaClient', () {
    test('searchBooksHtml requests the expected HTML search endpoint', () async {
      final transport = RecordingAknigaTransport(
        getResponses: const ['<html>ok</html>'],
      );
      final client = AknigaClient(transport: transport);

      final html = await client.searchBooksHtml(query: 'метро', page: 2);

      expect(html, '<html>ok</html>');
      expect(transport.getRequests, hasLength(1));
      final request = transport.getRequests.single;
      expect(
        request.uri.toString(),
        'https://akniga.org/search/books/page2/?q=%D0%BC%D0%B5%D1%82%D1%80%D0%BE',
      );
      expect(request.headers['Accept-Language'], contains('ru-RU'));
      expect(request.headers['Referer'], 'https://akniga.org/');
    });

    test('extractSecurityKey parses the LiveStreet key from page script', () {
      const html =
          "var PATH_ROOT='https://akniga.org/',"
          "LIVESTREET_SECURITY_KEY = 'abc123',LANGUAGE='ru';";

      expect(AknigaClient.extractSecurityKey(html), 'abc123');
    });

    test('ajaxBidTracks posts encrypted form and decodes track list', () async {
      final transport = RecordingAknigaTransport(
        getResponses: const ["LIVESTREET_SECURITY_KEY = 'live-key';"],
        postResponses: [
          jsonEncode({
            'bStateError': false,
            'aItems': jsonEncode([
              {
                'id': '501',
                'title': '001',
                'mp3': 'https://r1.akniga.club/books/metro/001.mp3',
              },
            ]),
          }),
        ],
      );
      final client = AknigaClient(
        transport: transport,
        securityEncoder: AknigaSecurityEncoder(
          saltFactory: () => const [0, 1, 2, 3, 4, 5, 6, 7],
        ),
      );

      final tracks = await client.ajaxBidTracks(
        bookId: '777',
        referer: Uri.parse('https://akniga.org/metro-2033'),
      );

      expect(tracks, hasLength(1));
      expect(tracks.single['id'], '501');
      expect(transport.postRequests, hasLength(1));
      final request = transport.postRequests.single;
      expect(request.uri.toString(), 'https://akniga.org/ajax/bid/777');
      expect(request.headers['X-Requested-With'], 'XMLHttpRequest');
      expect(request.headers['Origin'], 'https://akniga.org');
      expect(request.headers['Referer'], 'https://akniga.org/metro-2033');

      final form = Uri.splitQueryString(request.body);
      expect(form['bid'], '777');
      expect(form['security_ls_key'], 'live-key');
      expect(
        jsonDecode(form['hash']!) as Map<String, Object?>,
        containsPair('s', '0001020304050607'),
      );
    });

    test('ajaxBidTracks maps source ajax errors to SourceException', () async {
      final transport = RecordingAknigaTransport(
        postResponses: [
          jsonEncode({'bStateError': true}),
        ],
      );
      final client = AknigaClient(transport: transport);

      await expectLater(
        client.ajaxBidTracks(
          bookId: '777',
          referer: Uri.parse('https://akniga.org/metro-2033'),
          securityKey: 'live-key',
        ),
        throwsA(
          isA<SourceException>()
              .having((error) => error.sourceId, 'sourceId', 'akniga')
              .having((error) => error.kind, 'kind', SourceErrorKind.api)
              .having(
                (error) => error.message,
                'message',
                isNot(contains('live-key')),
              ),
        ),
      );
    });

    test('DartIoAknigaTransport keeps cookies between page and ajax', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));
      final receivedPostCookie = <String>[];

      server.listen((request) async {
        if (request.method == 'GET') {
          request.response.cookies.add(Cookie('akniga_session', 'abc123'));
          request.response.statusCode = HttpStatus.ok;
          request.response.write("LIVESTREET_SECURITY_KEY = 'live-key';");
        } else {
          receivedPostCookie.add(
            request.headers.value(HttpHeaders.cookieHeader) ?? '',
          );
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'bStateError': false, 'aItems': <Object?>[]}),
          );
        }
        await request.response.close();
      });

      final baseUri = Uri.parse(
        'http://${server.address.address}:${server.port}/',
      );
      final client = AknigaClient(
        baseUri: baseUri,
        transport: DartIoAknigaTransport(timeout: const Duration(seconds: 2)),
      );

      await client.ajaxBidTracks(
        bookId: '777',
        referer: baseUri.resolve('book'),
      );

      expect(receivedPostCookie.single, contains('akniga_session=abc123'));
    });
  });
}

class RecordingAknigaTransport implements AknigaTransport {
  RecordingAknigaTransport({
    this.getResponses = const [],
    this.postResponses = const [],
  });

  final List<String> getResponses;
  final List<String> postResponses;
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
      statusCode: 200,
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
