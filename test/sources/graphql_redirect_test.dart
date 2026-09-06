import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/izib/izib_graphql_client.dart';
import 'package:slovofon/sources/source_models.dart';
import 'package:slovofon/sources/yakniga/yakniga_graphql_client.dart';

void main() {
  for (final source in ['izib', 'yakniga']) {
    for (final status in [301, 302, 303, 307, 308]) {
      test(
        '$source rejects HTTP $status without following API redirect',
        () async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          var receivedRequests = 0;
          var redirectedRequests = 0;
          var originalWasPost = false;
          var originalHadSignature = false;
          server.listen((request) async {
            receivedRequests++;
            if (request.uri.path == '/redirected') {
              redirectedRequests++;
              request.response.write('{"data":{}}');
            } else {
              originalWasPost = request.method == 'POST';
              originalHadSignature = request.headers.value('SIGN') != null;
              await request.drain<void>();
              request.response.statusCode = status;
              request.response.headers.set(
                HttpHeaders.locationHeader,
                '/redirected',
              );
            }
            await request.response.close();
          });
          final endpoint = Uri.parse('http://127.0.0.1:${server.port}/graphql');
          final operation = source == 'izib'
              ? IzibGraphQlClient(apiUri: endpoint).execute(
                  operationName: 'Fixture',
                  variables: const {},
                  query: 'query Fixture',
                )
              : YaknigaGraphQlClient(apiUri: endpoint).execute(
                  operationName: 'Fixture',
                  variables: const {},
                  query: 'query Fixture',
                );

          await expectLater(
            operation,
            throwsA(
              isA<SourceException>().having(
                (error) => error.kind,
                'kind',
                SourceErrorKind.network,
              ),
            ),
          );
          expect(originalWasPost, isTrue);
          expect(originalHadSignature, source == 'izib');
          expect(receivedRequests, 1);
          expect(redirectedRequests, 0);
        },
      );
    }
  }
}
