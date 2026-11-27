import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart' as just_audio;

import '../../core/network/media_request_policy.dart';
import 'audio_engine.dart';
import 'audio_state.dart';

/// Supplies validated bytes to the existing just_audio loopback. The native
/// decoder never receives a remote URI or its headers, including on a seek.
// ignore: experimental_member_use
final class VerifiedStreamAudioSource extends just_audio.StreamAudioSource {
  VerifiedStreamAudioSource(
    AudioMediaSource source, {
    required MediaRequestPolicy policy,
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 15),
  }) : _source = source,
       _clientFactory = clientFactory ?? HttpClient.new,
       _policy = policy;

  AudioMediaSource? _source;
  final HttpClient Function() _clientFactory;
  final MediaRequestPolicy _policy;
  final Duration timeout;
  final _active = <HttpClient>{};
  bool _closed = false;

  static const _redirects = {301, 302, 303, 307, 308};
  static const _maximumRedirects = 5;
  static final _rangePattern = RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$');

  void close() {
    _closed = true;
    // just_audio can keep the old route registered until player disposal.
    // A retired local route must not retain or serve the remote URL/headers.
    _source = null;
    for (final client in _active.toList()) {
      _release(client);
    }
  }

  void _release(HttpClient client) {
    if (_active.remove(client)) client.close(force: true);
  }

  @override
  // ignore: experimental_member_use
  Future<just_audio.StreamAudioResponse> request([int? start, int? end]) async {
    final source = _source;
    if (source == null) {
      throw const AudioEngineException('Media request is not allowed.');
    }
    final initial = source.uri;
    final firstByte = start ?? 0;
    if (_closed ||
        !_policy.allows(initial) ||
        firstByte < 0 ||
        (end != null && end <= firstByte)) {
      throw const AudioEngineException('Media request is not allowed.');
    }

    HttpClient? activeClient;
    final budget = Stopwatch()..start();
    Duration remaining() {
      final duration = timeout - budget.elapsed;
      if (duration <= Duration.zero) {
        throw TimeoutException('Media request timed out.');
      }
      return duration;
    }

    try {
      var uri = initial;
      for (var hop = 0; hop <= _maximumRedirects && !_closed; hop++) {
        final client = _clientFactory()
          ..connectionTimeout = remaining()
          ..autoUncompress = false;
        activeClient = client;
        _active.add(client);
        final request = await client.getUrl(uri).timeout(remaining());
        if (_closed) break;
        request.followRedirects = false;
        _policy
            .headersForHop(initial, uri, source.headers)
            .forEach(request.headers.set);
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        if (start != null || end != null) {
          final lastByte = end == null ? '' : (end - 1).toString();
          request.headers.set(
            HttpHeaders.rangeHeader,
            'bytes=$firstByte-$lastByte',
          );
        }
        final response = await request.close().timeout(remaining());
        if (_closed) break;
        if (_redirects.contains(response.statusCode)) {
          final next = _policy.resolveRedirect(
            uri,
            response.headers.value(HttpHeaders.locationHeader),
          );
          if (next == null || hop == _maximumRedirects) break;
          // This request owns its client, so do not consume an unbounded
          // redirect response just to keep a connection alive.
          _release(client);
          activeClient = null;
          uri = next;
          continue;
        }

        final partial = response.statusCode == HttpStatus.partialContent;
        if (!partial &&
            (response.statusCode != HttpStatus.ok || firstByte > 0)) {
          break;
        }
        final encoding = response.headers.value(
          HttpHeaders.contentEncodingHeader,
        );
        if (encoding != null && encoding.toLowerCase() != 'identity') break;
        final type = response.headers.contentType?.mimeType;
        if (type != null &&
            !type.startsWith('audio/') &&
            !type.startsWith('video/') &&
            type != 'application/ogg' &&
            type != 'application/octet-stream') {
          break;
        }

        int? offset;
        int? length = response.contentLength < 0
            ? null
            : response.contentLength;
        int? total;
        if (partial) {
          final header = response.headers.value(HttpHeaders.contentRangeHeader);
          final match = header == null
              ? null
              : _rangePattern.firstMatch(header);
          if (match == null) break;
          final startAt = int.tryParse(match[1]!);
          final last = int.tryParse(match[2]!);
          total = int.tryParse(match[3]!);
          if (startAt != firstByte ||
              last == null ||
              last < firstByte ||
              (end != null && last >= end) ||
              (total != null && last >= total)) {
            break;
          }
          final rangeLength = last - firstByte + 1;
          if (length != null && length != rangeLength) break;
          length = rangeLength;
          offset = startAt;
        }

        final ranges =
            partial ||
            (start == null &&
                end == null &&
                response.headers
                        .value(HttpHeaders.acceptRangesHeader)
                        ?.toLowerCase() ==
                    'bytes');
        // ignore: experimental_member_use
        return just_audio.StreamAudioResponse(
          rangeRequestsSupported: ranges,
          sourceLength: partial ? total : null,
          contentLength: length,
          offset: offset,
          contentType: type ?? 'application/octet-stream',
          stream: _readBody(client, response, length),
        );
      }
    } on Object {
      // just_audio prints request errors; don't pass on URI-containing
      // platform/network exceptions or source headers.
    }
    if (activeClient != null) _release(activeClient);
    throw const AudioEngineException('Media request failed.');
  }

  Stream<List<int>> _readBody(
    HttpClient client,
    HttpClientResponse response,
    int? length,
  ) async* {
    var transferred = 0;
    try {
      await for (final bytes in response.timeout(timeout)) {
        transferred += bytes.length;
        if (length != null && transferred > length) {
          throw const AudioEngineException('Invalid media length.');
        }
        yield bytes;
      }
      if (length != null && length != transferred) {
        throw const AudioEngineException('Incomplete media response.');
      }
    } on Object {
      throw const AudioEngineException('Media stream interrupted.');
    } finally {
      _release(client);
    }
  }
}
