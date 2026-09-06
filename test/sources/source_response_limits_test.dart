import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/izib/izib_graphql_client.dart';
import 'package:slovofon/sources/source_metadata_transport.dart';
import 'package:slovofon/sources/source_models.dart';
import 'package:slovofon/sources/yakniga/yakniga_graphql_client.dart';

void main() {
  Future<Uri> serve(Future<void> Function(HttpRequest) handler) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      try {
        await handler(request);
      } on HttpException {
        // The client deliberately disconnects oversized fixture responses.
      } on SocketException {
        // No external connections or source credentials are used.
      }
    });
    return Uri.parse('http://127.0.0.1:${server.port}/metadata');
  }

  for (final transport in ['html', 'izib', 'yakniga']) {
    Future<String> read(Uri uri, int maximum) async {
      switch (transport) {
        case 'html':
          final result = await SourceMetadataTransport(
            policy: const SourceMetadataPolicy(
              sourceId: 'fixture',
              hosts: {'127.0.0.1'},
            ),
            timeout: const Duration(seconds: 2),
            maxResponseBytes: maximum,
          ).send(uri, headers: const {});
          return result.body;
        case 'izib':
          final result = await DartIoIzibGraphQlTransport(
            timeout: const Duration(seconds: 2),
            maxResponseBytes: maximum,
          ).post(uri, body: '{}', headers: const {});
          return result.body;
        default:
          final result = await DartIoYaknigaGraphQlTransport(
            timeout: const Duration(seconds: 2),
            maxResponseBytes: maximum,
          ).post(uri, body: '{}', headers: const {});
          return result.body;
      }
    }

    test(
      '$transport metadata retains multibyte UTF8 at exact byte budget',
      () async {
        final bytes = utf8.encode('Книга');
        final uri = await serve((request) async {
          request.response.contentLength = bytes.length;
          // Split a Cyrillic code point across network chunks.
          request.response.add(bytes.sublist(0, 1));
          await request.response.flush();
          request.response.add(bytes.sublist(1));
          await request.response.close();
        });
        expect(await read(uri, bytes.length), 'Книга');
      },
    );

    test('$transport metadata rejects oversized declared length', () async {
      final uri = await serve((request) async {
        request.response.contentLength = 5;
        request.response.add([1]);
        await request.response.flush();
      });
      await expectLater(read(uri, 4), throwsA(isA<SourceException>()));
    });

    test('$transport metadata rejects oversized chunked body', () async {
      final uri = await serve((request) async {
        request.response.add(utf8.encode('12345'));
        await request.response.close();
      });
      await expectLater(read(uri, 4), throwsA(isA<SourceException>()));
    });

    test(
      '$transport metadata caps decompressed bytes, not compressed length',
      () async {
        final compressed = gzip.encode(List.filled(4096, 65));
        expect(compressed.length, lessThan(512));
        final uri = await serve((request) async {
          request.response.headers.set(
            HttpHeaders.contentEncodingHeader,
            'gzip',
          );
          request.response.contentLength = compressed.length;
          request.response.add(compressed);
          await request.response.close();
        });
        await expectLater(read(uri, 512), throwsA(isA<SourceException>()));
      },
    );

    test(
      '$transport metadata still times out on an incomplete small body',
      () async {
        final uri = await serve((request) async {
          request.response.add([65]);
          await request.response.flush();
        });
        await expectLater(read(uri, 512), throwsA(isA<TimeoutException>()));
      },
    );
  }
}
