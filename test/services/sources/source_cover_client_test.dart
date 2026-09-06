import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/sources/source_cover_client.dart';

void main() {
  Future<Uri> serve(Future<void> Function(HttpRequest) handler) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      try {
        await handler(request);
      } on HttpException {
        // Size/time budgets intentionally disconnect an unfinished response.
      } on SocketException {
        // Only this synthetic loopback request is ever opened.
      }
    });
    return Uri.parse('http://127.0.0.1:${server.port}/cover');
  }

  test('cover accepts bounded bytes at the exact limit', () async {
    final uri = await serve((request) async {
      request.response.contentLength = 4;
      request.response.add([1, 2, 3, 4]);
      await request.response.close();
    });
    expect(await const SourceCoverClient(maxBytes: 4).load(uri), [1, 2, 3, 4]);
  });

  test(
    'cover rejects a declared oversized body before waiting for it',
    () async {
      final uri = await serve((request) async {
        request.response.contentLength = 5;
        request.response.add([1]);
        await request.response.flush();
      });
      expect(await const SourceCoverClient(maxBytes: 4).load(uri), isNull);
    },
  );

  test('cover bounds chunked responses without Content-Length', () async {
    final uri = await serve((request) async {
      request.response.add([1, 2, 3, 4, 5]);
      await request.response.close();
    });
    expect(await const SourceCoverClient(maxBytes: 4).load(uri), isNull);
  });

  test('cover body idle timeout releases an unfinished response', () async {
    final uri = await serve((request) async {
      request.response.add([1]);
      await request.response.flush();
    });
    final stopwatch = Stopwatch()..start();
    final result = await const SourceCoverClient(
      idleTimeout: Duration(milliseconds: 100),
      totalTimeout: Duration(seconds: 2),
    ).load(uri);
    expect(result, isNull);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('cover total budget stops an active slow response', () async {
    final timers = <Timer>[];
    addTearDown(() {
      for (final timer in timers) {
        timer.cancel();
      }
    });
    final uri = await serve((request) async {
      request.response.add([1]);
      await request.response.flush();
      timers.add(
        Timer.periodic(const Duration(milliseconds: 20), (timer) {
          try {
            request.response.add([1]);
            unawaited(
              request.response.flush().catchError((Object _) {
                timer.cancel();
              }),
            );
          } on StateError {
            timer.cancel();
          }
        }),
      );
    });
    final stopwatch = Stopwatch()..start();
    final result = await const SourceCoverClient(
      idleTimeout: Duration(seconds: 1),
      totalTimeout: Duration(milliseconds: 150),
    ).load(uri);
    expect(result, isNull);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
  });

  test('cover error response remains best effort', () async {
    final uri = await serve((request) async {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
    expect(await const SourceCoverClient().load(uri), isNull);
  });

  test('cover invalid scheme does not open a client', () async {
    var calls = 0;
    final client = SourceCoverClient(
      httpClientFactory: () {
        calls++;
        return HttpClient();
      },
    );
    expect(await client.load(Uri.parse('file:///fixture')), isNull);
    expect(calls, 0);
  });
}
