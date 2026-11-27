import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/core/network/media_request_policy.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/verified_stream_audio_source.dart';

void main() {
  test(
    'verified decoder request retains exact range through trusted redirect',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final uri = Uri.http('127.0.0.1:${server.port}', '/audio');
      final requestedRanges = <String?>[];
      server.listen((request) async {
        requestedRanges.add(request.headers.value(HttpHeaders.rangeHeader));
        if (request.uri.path == '/audio') {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(HttpHeaders.locationHeader, '/bytes');
        } else {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.contentType = ContentType('audio', 'mpeg');
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 3-5/9',
          );
          request.response.contentLength = 3;
          request.response.add([3, 4, 5]);
        }
        await request.response.close();
      });
      final source = VerifiedStreamAudioSource(
        AudioMediaSource.url(uri),
        policy: MediaRequestPolicy.sameOrigin(uri),
      );
      addTearDown(source.close);

      final result = await source.request(3, 6);
      expect(result.offset, 3);
      expect(result.contentLength, 3);
      expect(result.sourceLength, 9);
      expect(result.rangeRequestsSupported, isTrue);
      expect(await result.stream.expand((bytes) => bytes).toList(), [3, 4, 5]);
      expect(requestedRanges, ['bytes=3-5', 'bytes=3-5']);
    },
  );

  test('mismatched byte range is not handed to the decoder', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final uri = Uri.http('127.0.0.1:${server.port}', '/audio');
    server.listen((request) async {
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes 0-2/9',
      );
      request.response.contentLength = 3;
      request.response.add([0, 1, 2]);
      await request.response.close();
    });
    final source = VerifiedStreamAudioSource(
      AudioMediaSource.url(uri),
      policy: MediaRequestPolicy.sameOrigin(uri),
    );
    addTearDown(source.close);
    await expectLater(
      source.request(3, 6),
      throwsA(isA<AudioEngineException>()),
    );
  });
}
