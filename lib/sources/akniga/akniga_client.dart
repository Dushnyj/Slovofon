import 'dart:convert';
import 'dart:io';

import '../source_models.dart';
import 'akniga_security.dart';

abstract interface class AknigaTransport {
  Future<AknigaTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  });

  Future<AknigaTransportResponse> post(
    Uri uri, {
    required List<int> bodyBytes,
    required Map<String, String> headers,
  });
}

class AknigaTransportResponse {
  const AknigaTransportResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class DartIoAknigaTransport implements AknigaTransport {
  DartIoAknigaTransport({
    Duration timeout = const Duration(seconds: 12),
    HttpClient Function()? httpClientFactory,
  }) : _timeout = timeout,
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Duration _timeout;
  final HttpClient Function() _httpClientFactory;
  final _cookiesByHost = <String, Map<String, Cookie>>{};

  @override
  Future<AknigaTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    return _send(uri, method: 'GET', headers: headers);
  }

  @override
  Future<AknigaTransportResponse> post(
    Uri uri, {
    required List<int> bodyBytes,
    required Map<String, String> headers,
  }) async {
    return _send(uri, method: 'POST', headers: headers, bodyBytes: bodyBytes);
  }

  Future<AknigaTransportResponse> _send(
    Uri uri, {
    required String method,
    required Map<String, String> headers,
    List<int> bodyBytes = const [],
  }) async {
    final client = _httpClientFactory();
    client.connectionTimeout = _timeout;

    try {
      final request = await client.openUrl(method, uri).timeout(_timeout);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.cookies.addAll(_cookiesFor(uri));
      if (bodyBytes.isNotEmpty) {
        request.contentLength = bodyBytes.length;
        request.add(bodyBytes);
      }

      final response = await request.close().timeout(_timeout);
      _storeCookies(uri, response.cookies);
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      return AknigaTransportResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }

  List<Cookie> _cookiesFor(Uri uri) {
    final now = DateTime.now().toUtc();
    final jar = _cookiesByHost[_cookieKey(uri)];
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
    final jar = _cookiesByHost.putIfAbsent(_cookieKey(uri), () => {});
    for (final cookie in cookies) {
      if (cookie.expires != null && !cookie.expires!.isAfter(now)) {
        jar.remove(cookie.name);
      } else {
        jar[cookie.name] = cookie;
      }
    }
  }

  static String _cookieKey(Uri uri) {
    return uri.host.toLowerCase();
  }
}

class AknigaClient {
  AknigaClient({
    AknigaTransport? transport,
    AknigaSecurityEncoder? securityEncoder,
    Uri? baseUri,
  }) : _transport = transport ?? DartIoAknigaTransport(),
       _securityEncoder = securityEncoder ?? AknigaSecurityEncoder(),
       baseUri = baseUri ?? defaultBaseUri;

  static final defaultBaseUri = Uri.parse('https://akniga.org/');
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/125.0 Safari/537.36';

  final AknigaTransport _transport;
  final AknigaSecurityEncoder _securityEncoder;
  final Uri baseUri;

  Future<String> searchBooksHtml({required String query, int page = 1}) async {
    final normalizedPage = page < 1 ? 1 : page;
    final uri = baseUri.replace(
      path: '/search/books/page$normalizedPage/',
      queryParameters: {'q': query},
    );
    return _getText(uri, referer: baseUri.toString());
  }

  Future<String> homeHtml() {
    return _getText(baseUri);
  }

  Future<String> bookHtml(SourceBookRef ref) {
    final uri = ref.sourceUri ?? baseUri.resolve(ref.sourceBookId);
    return _getText(uri, referer: baseUri.toString());
  }

  Future<List<Map<String, Object?>>> ajaxBidTracks({
    required String bookId,
    required Uri referer,
    String? securityKey,
  }) async {
    final normalizedBookId = bookId.trim();
    if (!RegExp(r'^\d{1,20}$').hasMatch(normalizedBookId)) {
      throw const SourceException(
        sourceId: 'akniga',
        kind: SourceErrorKind.parser,
        message: 'Akniga book id is invalid.',
      );
    }

    final key = securityKey ?? extractSecurityKey(await homeHtml());
    final body = _securityEncoder.securityBody(
      bookId: normalizedBookId,
      securityKey: key,
    );
    final response = await _transport.post(
      baseUri.resolve('/ajax/bid/$normalizedBookId'),
      bodyBytes: utf8.encode(body),
      headers: {
        ..._htmlHeaders(referer: referer.toString()),
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Origin': _origin(baseUri),
        'X-Requested-With': 'XMLHttpRequest',
      },
    );
    _throwIfBadStatus(response, 'Akniga ajax/bid');

    final payload = _decodeJsonObject(response.body);
    if (payload['bStateError'] == true) {
      throw const SourceException(
        sourceId: 'akniga',
        kind: SourceErrorKind.api,
        message: 'Akniga ajax/bid returned an error.',
      );
    }

    final rawItems = payload['aItems'];
    final items = rawItems is String ? jsonDecode(rawItems) : rawItems;
    if (items is! List) {
      throw const SourceException(
        sourceId: 'akniga',
        kind: SourceErrorKind.parser,
        message: 'Akniga ajax/bid returned no track list.',
      );
    }

    return [
      for (final item in items)
        if (item is Map) item.cast<String, Object?>(),
    ];
  }

  static String extractSecurityKey(String html) {
    final patterns = [
      RegExp(r"LIVESTREET_SECURITY_KEY\s*=\s*'([^']+)'"),
      RegExp(r'LIVESTREET_SECURITY_KEY\s*=\s*"([^"]+)"'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null) {
        return match.group(1)!;
      }
    }

    throw const SourceException(
      sourceId: 'akniga',
      kind: SourceErrorKind.parser,
      message: 'Akniga security key was not found.',
    );
  }

  Future<String> _getText(Uri uri, {String? referer}) async {
    final response = await _transport.get(
      uri,
      headers: _htmlHeaders(referer: referer),
    );
    _throwIfBadStatus(response, 'Akniga page');
    return response.body;
  }

  static Map<String, String> mediaHeaders({required String referer}) {
    return {
      'User-Agent': userAgent,
      'Accept': 'audio/mpeg,audio/*,*/*;q=0.8',
      'Referer': referer,
    };
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

  static Map<String, Object?> _decodeJsonObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    } on Object catch (error) {
      throw SourceException(
        sourceId: 'akniga',
        kind: SourceErrorKind.parser,
        message: 'Akniga returned invalid JSON.',
        cause: error,
      );
    }

    throw const SourceException(
      sourceId: 'akniga',
      kind: SourceErrorKind.parser,
      message: 'Akniga returned invalid payload.',
    );
  }

  static void _throwIfBadStatus(
    AknigaTransportResponse response,
    String context,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw SourceException(
      sourceId: 'akniga',
      kind: SourceErrorKind.network,
      message: '$context returned HTTP ${response.statusCode}.',
    );
  }

  static String _origin(Uri uri) {
    return '${uri.scheme}://${uri.host}';
  }
}
