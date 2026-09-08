import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/izib/izib_graphql_client.dart';
import 'package:slovofon/sources/source_metadata_transport.dart';
import 'package:slovofon/sources/source_search_cancellation.dart';
import 'package:slovofon/sources/yakniga/yakniga_graphql_client.dart';

void main() {
  test(
    'cancellation listeners detach and operations do not leak their zone',
    () async {
      final cancellation = SourceSearchCancellation();
      var called = false;
      final remove = cancellation.addListener(() => called = true);
      expect(
        await cancellation.run(() async => SourceSearchCancellation.current),
        cancellation,
      );
      expect(SourceSearchCancellation.current, isNull);
      remove();
      cancellation.cancel();
      cancellation.cancel();
      expect(called, isFalse);
      expect(
        () => cancellation.run(() async => 1),
        throwsA(isA<SourceSearchCancelled>()),
      );
    },
  );

  for (final kind in ['html', 'izib', 'yakniga']) {
    test(
      '$kind search cancellation force-closes only its own native client',
      () async {
        final cancellation = SourceSearchCancellation();
        final client = _WaitingHttpClient();
        final uri = Uri.parse('https://fixture.invalid/search');
        final future = cancellation.run<Object?>(
          () => switch (kind) {
            'html' => SourceMetadataTransport(
              policy: const SourceMetadataPolicy(
                sourceId: 'fixture',
                hosts: {'fixture.invalid'},
              ),
              timeout: const Duration(seconds: 8),
              httpClientFactory: () => client,
            ).send(uri, headers: const {}),
            'izib' => DartIoIzibGraphQlTransport(
              httpClientFactory: () => client,
            ).post(uri, body: '{}', headers: const {}),
            _ => DartIoYaknigaGraphQlTransport(
              httpClientFactory: () => client,
            ).post(uri, body: '{}', headers: const {}),
          },
        );
        final expected = expectLater(
          future,
          throwsA(isA<SourceSearchCancelled>()),
        );
        await client.opened.future;
        cancellation.cancel();
        await expected;
        expect(client.forceClosed, isTrue);
      },
    );
  }
}

class _WaitingHttpClient extends Fake implements HttpClient {
  @override
  Duration? connectionTimeout;
  final opened = Completer<void>();
  final request = Completer<HttpClientRequest>();
  bool forceClosed = false;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) {
    if (!opened.isCompleted) opened.complete();
    return request.future;
  }

  @override
  Future<HttpClientRequest> postUrl(Uri uri) => openUrl('POST', uri);

  @override
  void close({bool force = false}) {
    forceClosed = forceClosed || force;
    if (!request.isCompleted) {
      request.completeError(const SocketException('closed fixture client'));
    }
  }
}
