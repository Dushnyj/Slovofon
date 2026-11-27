import 'dart:io';
import 'dart:typed_data';

import '../../core/network/media_request_policy.dart';

/// Best-effort cover fetches must not hold book metadata refresh indefinitely
/// or accumulate an unbounded response in memory.
class SourceCoverClient {
  const SourceCoverClient({
    this.maxBytes = 8 * 1024 * 1024,
    this.totalTimeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 5),
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory;

  final int maxBytes;
  final Duration totalTimeout;
  final Duration idleTimeout;
  final HttpClient Function()? _httpClientFactory;

  Future<Uint8List?> load(Uri uri, {MediaRequestPolicy? policy}) async {
    final requestPolicy = policy ?? MediaRequestPolicy.sameOrigin(uri);
    if (!requestPolicy.allows(uri) || maxBytes <= 0) return null;
    HttpClient? active;
    var finished = false;
    try {
      return await (() async {
        var destination = uri;
        for (var hop = 0; hop <= 5 && !finished; hop++) {
          final client = (_httpClientFactory ?? HttpClient.new)()
            ..connectionTimeout = idleTimeout;
          active = client;
          final request = await client.getUrl(destination).timeout(idleTimeout);
          request.followRedirects = false;
          final response = await request.close().timeout(idleTimeout);
          if (_redirects.contains(response.statusCode)) {
            final next = requestPolicy.resolveRedirect(
              destination,
              response.headers.value(HttpHeaders.locationHeader),
            );
            if (next == null || hop == 5) return null;
            active = null;
            client.close(force: true);
            destination = next;
            continue;
          }
          return _read(response);
        }
        return null;
      })().timeout(totalTimeout);
    } on Object {
      // Cover failures must not prevent persistence of the playable book.
      return null;
    } finally {
      // Also terminates the actual pending socket/body after a total timeout.
      finished = true;
      active?.close(force: true);
    }
  }

  static const _redirects = {301, 302, 303, 307, 308};

  Future<Uint8List?> _read(HttpClientResponse response) async {
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.contentLength > maxBytes) {
      return null;
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(idleTimeout)) {
      if (bytes.length + chunk.length > maxBytes) return null;
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }
}
