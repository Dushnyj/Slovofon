import 'dart:io';
import 'dart:typed_data';

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

  Future<List<int>?> load(Uri uri) async {
    if ((uri.scheme != 'http' && uri.scheme != 'https') || maxBytes <= 0) {
      return null;
    }
    final client = (_httpClientFactory ?? HttpClient.new)()
      ..connectionTimeout = idleTimeout;
    try {
      return await _read(client, uri).timeout(totalTimeout);
    } on Object {
      // Cover failures must not prevent persistence of the playable book.
      return null;
    } finally {
      // Also terminates the actual pending socket/body after a total timeout.
      client.close(force: true);
    }
  }

  Future<List<int>?> _read(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri).timeout(idleTimeout);
    final response = await request.close().timeout(idleTimeout);
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
