import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';

void main() {
  test('cancel interrupts a pending open and aborts a late request', () async {
    final http = _DeferredHttpClient();
    final client = DefaultDownloadClient(httpClient: http);
    final token = DownloadCancellationToken();
    final opening = client.open(
      AudioMediaSource.url(Uri.parse('https://example.test/chapter.mp3')),
      startByte: 0,
      cancellationToken: token,
    );
    final assertion = expectLater(
      opening,
      throwsA(isA<DownloadCanceledException>()),
    );
    token.cancel();
    await assertion.timeout(const Duration(seconds: 1));
    final request = _AbortableRequest();
    http.request.complete(request);
    await Future<void>.delayed(Duration.zero);
    expect(request.aborted, isTrue);
    client.close();
  });

  test(
    'cancel closes a response stream without waiting for another byte',
    () async {
      final server = await _server((request) async {
        request.response.bufferOutput = false;
        request.response.contentLength = -1;
        request.response.add([1]);
        await request.response.flush();
      });
      final client = DefaultDownloadClient();
      addTearDown(client.close);
      final token = DownloadCancellationToken();
      final response = await client.open(
        _source(server),
        startByte: 0,
        cancellationToken: token,
      );
      final received = <int>[];
      final firstByte = Completer<void>();
      final done = response.bytes.forEach((chunk) {
        received.addAll(chunk);
        if (!firstByte.isCompleted) firstByte.complete();
      });
      await firstByte.future.timeout(const Duration(seconds: 2));
      token.cancel();
      await done.timeout(const Duration(seconds: 1));
      expect(received, [1]);
    },
  );

  test(
    'headers timeout finishes a request whose server sends nothing',
    () async {
      final server = await _server((_) async {});
      final client = DefaultDownloadClient(
        connectionTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(client.close);
      await expectLater(
        client.open(
          _source(server),
          startByte: 0,
          cancellationToken: DownloadCancellationToken(),
        ),
        throwsA(
          isA<DownloadClientException>().having(
            (error) => error.message,
            'message',
            contains('timed out'),
          ),
        ),
      ).timeout(const Duration(seconds: 2));
    },
  );

  test('read timeout finishes a response stalled between chunks', () async {
    final server = await _server((request) async {
      request.response.bufferOutput = false;
      request.response.contentLength = -1;
      request.response.add([1]);
      await request.response.flush();
    });
    final client = DefaultDownloadClient(
      readTimeout: const Duration(milliseconds: 100),
    );
    addTearDown(client.close);
    final response = await client.open(
      _source(server),
      startByte: 0,
      cancellationToken: DownloadCancellationToken(),
    );
    await expectLater(
      response.bytes.drain<void>(),
      throwsA(
        isA<DownloadClientException>().having(
          (error) => error.message,
          'message',
          contains('read timed out'),
        ),
      ),
    ).timeout(const Duration(seconds: 2));
  });

  test(
    'server ignoring Range restarts at zero with the actual total length',
    () async {
      final server = await _server((request) async {
        expect(request.headers.value(HttpHeaders.rangeHeader), 'bytes=3-');
        expect(
          request.headers.value(HttpHeaders.acceptEncodingHeader),
          'identity',
        );
        request.response.contentLength = 6;
        request.response.add([1, 2, 3, 4, 5, 6]);
        await request.response.close();
      });
      final client = DefaultDownloadClient();
      addTearDown(client.close);
      final response = await client.open(
        _source(server),
        startByte: 3,
        cancellationToken: DownloadCancellationToken(),
      );
      expect(response.shouldAppend, isFalse);
      expect(response.totalBytes, 6);
      expect(await response.bytes.expand((chunk) => chunk).toList(), [
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    },
  );

  test('a mismatched Content-Range cannot corrupt the partial file', () async {
    final server = await _server((request) async {
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes 0-2/6',
      );
      request.response.contentLength = 3;
      request.response.add([1, 2, 3]);
      await request.response.close();
    });
    final client = DefaultDownloadClient();
    addTearDown(client.close);
    await expectLater(
      client.open(
        _source(server),
        startByte: 3,
        cancellationToken: DownloadCancellationToken(),
      ),
      throwsA(
        isA<DownloadClientException>().having(
          (error) => error.message,
          'message',
          contains('byte range'),
        ),
      ),
    );
  });
  for (final range in ['bytes 3-2/6', 'bytes 3-8/6', 'bytes 3-4/6']) {
    test('invalid range $range is rejected before reading media', () async {
      final server = await _server((request) async {
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(HttpHeaders.contentRangeHeader, range);
        request.response.contentLength = 3;
        request.response.add([4, 5, 6]);
        await request.response.close();
      });
      final client = DefaultDownloadClient();
      addTearDown(client.close);
      await expectLater(
        client.open(
          _source(server),
          startByte: 3,
          cancellationToken: DownloadCancellationToken(),
        ),
        throwsA(isA<DownloadClientException>()),
      );
    });
  }
}

Future<HttpServer> _server(Future<void> Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    unawaited(
      handler(request).catchError((Object error, StackTrace stack) {
        // Aborted requests are expected in cancellation tests, but assertion
        // failures must remain visible.
        if (error is! SocketException && error is! HttpException) {
          Error.throwWithStackTrace(error, stack);
        }
      }),
    );
  });
  addTearDown(() => server.close(force: true));
  return server;
}

AudioMediaSource _source(HttpServer server) => AudioMediaSource.url(
  Uri.parse('http://127.0.0.1:${server.port}/chapter.mp3'),
);

class _DeferredHttpClient extends Fake implements HttpClient {
  final request = Completer<HttpClientRequest>();
  @override
  Duration? connectionTimeout;
  @override
  Future<HttpClientRequest> getUrl(Uri url) => request.future;
}

class _AbortableRequest extends Fake implements HttpClientRequest {
  var aborted = false;
  @override
  void abort([Object? exception, StackTrace? stackTrace]) => aborted = true;
}
