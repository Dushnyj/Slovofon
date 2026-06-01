import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/sources/yakniga/yakniga_graphql_client.dart';

void main() {
  group('YaknigaGraphQlClient', () {
    test('builds GraphQL bodies in the expected field order', () {
      final body = YaknigaGraphQlClient.graphQlBody(
        operationName: 'Search',
        variables: const {'term': 'дыхание зоны'},
        query: 'query Search',
      );

      expect(
        body,
        '{"operationName":"Search","variables":{"term":"дыхание зоны"},"query":"query Search"}',
      );
      expect(jsonDecode(body), isA<Map<String, Object?>>());
    });

    test('searchBooks posts public GraphQL request headers', () async {
      final transport = RecordingYaknigaTransport(
        responseJson: const {
          'data': {'search': <Object?>[]},
        },
      );
      final client = YaknigaGraphQlClient(transport: transport);

      final data = await client.searchBooks(term: 'полураспад');

      expect(data['search'], isA<List<Object?>>());
      expect(transport.requests, hasLength(1));
      final request = transport.requests.single;
      expect(request.uri, YaknigaGraphQlClient.defaultApiUri);
      expect(request.headers['Accept'], 'application/json');
      expect(request.headers['Content-Type'], 'application/json');
      expect(request.headers['Origin'], 'https://yakniga.org');
      expect(request.headers['Referer'], 'https://yakniga.org/');
      expect(request.headers['User-Agent'], contains('Mozilla/5.0'));

      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body['operationName'], 'Search');
      expect(body['variables'], {'term': 'полураспад'});
      expect(body['query'], contains('search(autocomplete: true'));
    });

    test('book posts id variables and returns data', () async {
      final transport = RecordingYaknigaTransport(
        responseJson: const {
          'data': {
            'book': {'id': '50148'},
          },
        },
      );
      final client = YaknigaGraphQlClient(transport: transport);

      final data = await client.book(id: '50148');
      final body =
          jsonDecode(transport.requests.single.body) as Map<String, Object?>;

      expect(data['book'], isA<Map<String, Object?>>());
      expect(body['operationName'], 'Book');
      expect(body['variables'], {'id': '50148'});
      expect(body['query'], contains('chapters'));
      expect(body['query'], contains('fileUrl'));
    });

    test('maps GraphQL errors to safe SourceException messages', () async {
      final transport = RecordingYaknigaTransport(
        responseJson: const {
          'errors': [
            {'message': 'GraphQL failed'},
          ],
        },
      );
      final client = YaknigaGraphQlClient(transport: transport);

      await expectLater(
        client.searchBooks(term: 'метро'),
        throwsA(
          isA<SourceException>()
              .having((error) => error.sourceId, 'sourceId', 'yakniga')
              .having((error) => error.kind, 'kind', SourceErrorKind.api)
              .having(
                (error) => error.message,
                'message',
                isNot(contains('User-Agent')),
              ),
        ),
      );
    });

    test('DartIoYaknigaGraphQlTransport posts UTF-8 request bodies', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));

      final receivedBody = server.first.then((request) async {
        final body = await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"data":{}}');
        await request.response.close();
        return body;
      });

      const body = '{"term":"дыхание зоны"}';
      final transport = DartIoYaknigaGraphQlTransport(
        timeout: const Duration(seconds: 2),
      );
      final response = await transport.post(
        Uri.parse('http://${server.address.address}:${server.port}/graphql'),
        body: body,
        headers: const {'Content-Type': 'application/json'},
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(await receivedBody, body);
    });
  });
}

class RecordingYaknigaTransport implements YaknigaGraphQlTransport {
  RecordingYaknigaTransport({
    required this.responseJson,
    this.statusCode = 200,
  });

  final Map<String, Object?> responseJson;
  final int statusCode;
  final requests = <RecordedYaknigaRequest>[];

  @override
  Future<YaknigaGraphQlTransportResponse> post(
    Uri uri, {
    required String body,
    required Map<String, String> headers,
  }) async {
    requests.add(
      RecordedYaknigaRequest(
        uri: uri,
        body: body,
        headers: Map.unmodifiable(headers),
      ),
    );
    return YaknigaGraphQlTransportResponse(
      statusCode: statusCode,
      body: jsonEncode(responseJson),
    );
  }
}

class RecordedYaknigaRequest {
  const RecordedYaknigaRequest({
    required this.uri,
    required this.body,
    required this.headers,
  });

  final Uri uri;
  final String body;
  final Map<String, String> headers;
}
