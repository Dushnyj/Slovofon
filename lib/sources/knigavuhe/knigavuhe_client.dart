import 'dart:convert';
import 'dart:io';

import '../source_models.dart';

abstract interface class KnigavuheTransport {
  Future<KnigavuheTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  });
}

class KnigavuheTransportResponse {
  const KnigavuheTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class DartIoKnigavuheTransport implements KnigavuheTransport {
  DartIoKnigavuheTransport({
    Duration timeout = const Duration(seconds: 12),
    HttpClient Function()? httpClientFactory,
  }) : _timeout = timeout,
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Duration _timeout;
  final HttpClient Function() _httpClientFactory;
  final _cookiesByHost = <String, Map<String, Cookie>>{};

  @override
  Future<KnigavuheTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final client = _httpClientFactory();
    client.connectionTimeout = _timeout;

    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.cookies.addAll(_cookiesFor(uri));

      final response = await request.close().timeout(_timeout);
      _storeCookies(uri, response.cookies);
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      return KnigavuheTransportResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }

  List<Cookie> _cookiesFor(Uri uri) {
    final now = DateTime.now().toUtc();
    final jar = _cookiesByHost[uri.host.toLowerCase()];
    if (jar == null || jar.isEmpty) {
      return const [];
    }
    return [
      for (final cookie in jar.values)
        if (cookie.expires == null || cookie.expires!.isAfter(now)) cookie,
    ];
  }

  void _storeCookies(Uri uri, List<Cookie> cookies) {
    if (cookies.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc();
    final jar = _cookiesByHost.putIfAbsent(uri.host.toLowerCase(), () => {});
    for (final cookie in cookies) {
      if (cookie.expires != null && !cookie.expires!.isAfter(now)) {
        jar.remove(cookie.name);
      } else {
        jar[cookie.name] = cookie;
      }
    }
  }
}

class KnigavuheClient {
  KnigavuheClient({KnigavuheTransport? transport, Uri? baseUri})
    : _transport = transport ?? DartIoKnigavuheTransport(),
      baseUri = baseUri ?? defaultBaseUri;

  static final defaultBaseUri = Uri.parse('https://knigavuhe.org/');
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/125.0 Safari/537.36';

  final KnigavuheTransport _transport;
  final Uri baseUri;

  Future<String> searchBooksHtml({required String query, int page = 1}) {
    final normalizedPage = page < 1 ? 1 : page;
    final uri = baseUri.replace(
      path: '/search/',
      queryParameters: {'q': query, 'page': '$normalizedPage'},
    );
    return _getText(uri, referer: baseUri.toString());
  }

  Future<String> bookHtml(SourceBookRef ref) {
    final uri = ref.sourceUri ?? baseUri.resolve(ref.sourceBookId);
    return _getText(uri, referer: baseUri.toString());
  }

  static Map<String, String> mediaHeaders({required String referer}) {
    return {
      'User-Agent': userAgent,
      'Accept': 'audio/mpeg,audio/*,*/*;q=0.8',
      'Referer': referer,
    };
  }

  Future<String> _getText(Uri uri, {String? referer}) async {
    final response = await _transport.get(
      uri,
      headers: _htmlHeaders(referer: referer),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }

    throw SourceException(
      sourceId: 'knigavuhe',
      kind: SourceErrorKind.network,
      message: 'Knigavuhe page returned HTTP ${response.statusCode}.',
    );
  }

  static Map<String, String> _htmlHeaders({String? referer}) {
    return {
      'User-Agent': userAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'ru-RU,ru;q=0.9,en;q=0.7',
      if (referer != null && referer.isNotEmpty) 'Referer': referer,
    };
  }
}
