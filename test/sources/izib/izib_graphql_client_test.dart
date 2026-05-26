import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/izib/izib_graphql_client.dart';
import 'package:slovofon/sources/izib/izib_signer.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('IzibGraphQlClient', () {
    test('builds compact GraphQL bodies in the expected field order', () {
      final body = IzibGraphQlClient.graphQlBody(
        operationName: 'booksSearch',
        variables: const {'q': 'метро', 'offset': 0, 'count': 20},
        query: 'query booksSearch',
      );

      expect(
        body,
        '{"operationName":"booksSearch","variables":{"q":"метро","offset":0,"count":20},"query":"query booksSearch"}',
      );
      expect(jsonDecode(body), isA<Map<String, Object?>>());
    });

    test(
      'generates per-body SIGN headers without exposing the value',
      () async {
        final transport = RecordingIzibTransport(
          responseJson: const {'data': <String, Object?>{}},
        );
        final signer = IzibSigner();
        final client = IzibGraphQlClient(transport: transport, signer: signer);

        await client.execute(
          operationName: 'booksSearch',
          variables: const {'q': 'метро', 'offset': 0, 'count': 20},
          query: 'query booksSearch',
        );

        expect(transport.requests, hasLength(1));
        final request = transport.requests.single;
        expect(request.uri, IzibGraphQlClient.defaultApiUri);
        expect(request.headers['Accept'], 'application/json');
        expect(request.headers['Content-Type'], 'application/json');
        expect(request.headers['User-Agent'], contains('com.izimobile'));
        expect(request.headers['SIGN'], isNotEmpty);
        expect(request.headers['SIGN'], signer.sign(request.body));
        expect(request.headers['SIGN'], isNot(contains('метро')));
      },
    );

    test('maps GraphQL errors to safe SourceException messages', () async {
      final transport = RecordingIzibTransport(
        responseJson: const {
          'errors': [
            {'message': 'GraphQL failed'},
          ],
        },
      );
      final client = IzibGraphQlClient(transport: transport);

      await expectLater(
        client.execute(
          operationName: 'bookQuery',
          variables: const {'id': 2033},
          query: 'query bookQuery',
        ),
        throwsA(
          isA<SourceException>()
              .having((error) => error.sourceId, 'sourceId', 'izib')
              .having((error) => error.kind, 'kind', SourceErrorKind.api)
              .having(
                (error) => error.message,
                'message',
                isNot(contains('SIGN')),
              ),
        ),
      );
    });

    test('searchBooks sends booksSearch variables and returns data', () async {
      final transport = RecordingIzibTransport(
        responseJson: const {
          'data': {
            'booksSearch': {'items': []},
          },
        },
      );
      final client = IzibGraphQlClient(transport: transport);

      final data = await client.searchBooks(
        query: 'метро',
        offset: 20,
        count: 10,
      );
      final requestBody =
          jsonDecode(transport.requests.single.body) as Map<String, Object?>;
      final variables = requestBody['variables']! as Map<String, Object?>;

      expect(data['booksSearch'], isA<Map<String, Object?>>());
      expect(requestBody['operationName'], 'booksSearch');
      expect(variables, {'q': 'метро', 'offset': 20, 'count': 10});
    });
  });
}

class RecordingIzibTransport implements IzibGraphQlTransport {
  RecordingIzibTransport({required this.responseJson, this.statusCode = 200});

  final Map<String, Object?> responseJson;
  final int statusCode;
  final requests = <RecordedIzibRequest>[];

  @override
  Future<IzibGraphQlTransportResponse> post(
    Uri uri, {
    required String body,
    required Map<String, String> headers,
  }) async {
    requests.add(
      RecordedIzibRequest(
        uri: uri,
        body: body,
        headers: Map.unmodifiable(headers),
      ),
    );
    return IzibGraphQlTransportResponse(
      statusCode: statusCode,
      body: jsonEncode(responseJson),
    );
  }
}

class RecordedIzibRequest {
  const RecordedIzibRequest({
    required this.uri,
    required this.body,
    required this.headers,
  });

  final Uri uri;
  final String body;
  final Map<String, String> headers;
}
