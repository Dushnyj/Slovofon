import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/downloads/download_client.dart';

void main() {
  test(
    'strong ETag is scoped to URI and checked on a resumed response',
    () async {
      final seen = <(String?, String?)>[];
      final server = await _server((request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        seen.add((range, request.headers.value(HttpHeaders.ifRangeHeader)));
        request.response.headers.set(HttpHeaders.etagHeader, '"audio-v1"');
        if (range != null) {
          request.response
            ..statusCode = HttpStatus.partialContent
            ..headers.set(HttpHeaders.contentRangeHeader, 'bytes 3-5/6')
            ..add([4, 5, 6]);
        } else {
          request.response.add([1, 2, 3, 4, 5, 6]);
        }
        await request.response.close();
      });
      final client = DefaultDownloadClient();
      addTearDown(client.close);
      final source = _source(server);
      final seed = await client.openWithResume(
        source,
        startByte: 3,
        strongEntityTag: 'W/"audio-v1"',
        representationKey: null,
        cancellationToken: DownloadCancellationToken(),
      );
      expect(seed.shouldAppend, isFalse);
      expect(await seed.bytes.expand((c) => c).toList(), [1, 2, 3, 4, 5, 6]);
      final resumed = await client.openWithResume(
        source,
        startByte: 3,
        strongEntityTag: seed.strongEntityTag,
        representationKey: seed.representationKey,
        cancellationToken: DownloadCancellationToken(),
      );
      expect(resumed.shouldAppend, isTrue);
      expect(resumed.totalBytes, 6);
      expect(await resumed.bytes.expand((c) => c).toList(), [4, 5, 6]);
      final changedUrl = await client.openWithResume(
        AudioMediaSource.url(source.uri.replace(query: 'edition=2')),
        startByte: 3,
        strongEntityTag: seed.strongEntityTag,
        representationKey: seed.representationKey,
        cancellationToken: DownloadCancellationToken(),
      );
      expect(changedUrl.shouldAppend, isFalse);
      await changedUrl.bytes.drain<void>();
      expect(seen, [(null, null), ('bytes=3-', '"audio-v1"'), (null, null)]);
    },
  );

  for (final status in [
    HttpStatus.requestedRangeNotSatisfiable,
    HttpStatus.partialContent,
  ]) {
    test(
      'verified resume starts clean after 416 or changed ETag ($status)',
      () async {
        final seen = <String?>[];
        var initial = true;
        final server = await _server((request) async {
          final range = request.headers.value(HttpHeaders.rangeHeader);
          seen.add(range);
          request.response.headers.set(
            HttpHeaders.etagHeader,
            initial ? '"old"' : '"new"',
          );
          if (range != null) {
            request.response.statusCode = status;
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              status == HttpStatus.partialContent ? 'bytes 3-5/6' : 'bytes */6',
            );
            request.response.add([4, 5, 6]);
          } else {
            request.response.add(
              initial ? [1, 2, 3, 4, 5, 6] : [10, 11, 12, 13, 14, 15],
            );
          }
          await request.response.close();
        });
        final client = DefaultDownloadClient();
        addTearDown(client.close);
        final source = _source(server);
        final seed = await client.openWithResume(
          source,
          startByte: 0,
          strongEntityTag: null,
          representationKey: null,
          cancellationToken: DownloadCancellationToken(),
        );
        await seed.bytes.drain<void>();
        initial = false;
        final resumed = await client.openWithResume(
          source,
          startByte: 3,
          strongEntityTag: seed.strongEntityTag,
          representationKey: seed.representationKey,
          cancellationToken: DownloadCancellationToken(),
        );
        expect(resumed.shouldAppend, isFalse);
        expect(resumed.strongEntityTag, '"new"');
        expect(await resumed.bytes.expand((c) => c).toList(), [
          10,
          11,
          12,
          13,
          14,
          15,
        ]);
        expect(seen, [null, 'bytes=3-', null]);
      },
    );
  }

  test('redirects stay within the supplied request policy', () async {
    var otherOriginRequests = 0;
    final other = await _server((request) async {
      otherOriginRequests++;
      await request.response.close();
    });
    final server = await _server((request) async {
      if (request.uri.path == '/allowed') {
        request.response.add([7]);
        await request.response.close();
        return;
      }
      await request.response.redirect(
        request.uri.queryParameters['cross'] == 'yes'
            ? Uri.parse('http://127.0.0.1:${other.port}/unexpected')
            : Uri.parse('/allowed'),
      );
    });
    final client = DefaultDownloadClient();
    addTearDown(client.close);
    final source = _source(server);
    final allowed = await client.openWithResume(
      source,
      startByte: 0,
      strongEntityTag: null,
      representationKey: null,
      cancellationToken: DownloadCancellationToken(),
    );
    expect(await allowed.bytes.expand((c) => c).toList(), [7]);
    final cross = AudioMediaSource.url(source.uri.replace(query: 'cross=yes'));
    await expectLater(
      client.openWithResume(
        cross,
        startByte: 0,
        strongEntityTag: null,
        representationKey: null,
        cancellationToken: DownloadCancellationToken(),
      ),
      throwsA(
        isA<DownloadClientException>().having(
          (e) => e.code,
          'code',
          'media_redirect_denied',
        ),
      ),
    );
    expect(otherOriginRequests, 0);
  });

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
