import 'dart:convert';
import 'dart:io';

import '../source_metadata_transport.dart';
import '../source_models.dart';
import 'baza_knig_search_pager.dart';

abstract interface class BazaKnigTransport {
  Future<BazaKnigTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  });

  Future<BazaKnigTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required List<int> bodyBytes,
  });
}

class BazaKnigTransportResponse {
  const BazaKnigTransportResponse({
    required this.statusCode,
    required this.body,
    this.finalUri,
    this.redirectLocation,
  });

  final int statusCode;
  final String body;
  final Uri? finalUri;
  final Uri? redirectLocation;
}

class DartIoBazaKnigTransport implements BazaKnigTransport {
  DartIoBazaKnigTransport({
    Duration timeout = const Duration(seconds: 12),
    HttpClient Function()? httpClientFactory,
    SourceMetadataPolicy policy = BazaKnigClient.metadataPolicy,
  }) : _transport = SourceMetadataTransport(
         policy: policy,
         timeout: timeout,
         httpClientFactory: httpClientFactory,
       );

  final SourceMetadataTransport _transport;

  @override
  Future<BazaKnigTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async => _map(await _transport.send(uri, headers: headers));

  @override
  Future<BazaKnigTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required List<int> bodyBytes,
  }) async => _map(
    await _transport.send(
      uri,
      method: 'POST',
      headers: headers,
      bodyBytes: bodyBytes,
    ),
  );

  static BazaKnigTransportResponse _map(SourceMetadataResponse response) =>
      BazaKnigTransportResponse(
        statusCode: response.statusCode,
        body: response.body,
        finalUri: response.finalUri,
        redirectLocation: response.redirectLocation,
      );
}

class BazaKnigClient {
  BazaKnigClient({
    BazaKnigTransport? transport,
    Uri? baseUri,
    SourceMetadataPolicy policy = metadataPolicy,
  }) : _transport = transport ?? DartIoBazaKnigTransport(policy: policy),
       baseUri = baseUri ?? defaultBaseUri,
       _policy = policy;

  static final defaultBaseUri = Uri.parse('https://baza-knig.top/');
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/125.0 Safari/537.36';

  final BazaKnigTransport _transport;
  static const metadataPolicy = SourceMetadataPolicy(
    sourceId: 'baza_knig',
    hosts: {'baza-knig.top', 'www.baza-knig.top'},
  );
  final SourceMetadataPolicy _policy;
  final Uri baseUri;

  Future<String> searchBooksHtml({required String query, int page = 1}) {
    final normalizedPage = page < 1 ? 1 : page;
    final firstPage = normalizedPage == 1;
    final root = baseUri.resolve('/');
    // Submit the site's public header form, then the fullsearch pager form.
    // The POST body is not replayed when the site responds with a 302 check.
    final uri = firstPage ? root : root.resolve('index.php?do=search');
    return _requestHtml(
      uri,
      referer: root.toString(),
      form: {
        'story': query,
        'do': 'search',
        'subaction': 'search',
        if (firstPage) 'titleonly': '3',
        if (!firstPage) ...{
          'search_start': '$normalizedPage',
          'result_from': '${bazaKnigSearchPageStart(normalizedPage)}',
          'full_search': '0',
        },
      },
    );
  }

  Future<String> bookHtml(SourceBookRef ref) {
    final uri = _policy.bookUri(baseUri, ref);
    return _requestHtml(uri, referer: baseUri.toString());
  }

  static Map<String, String> mediaHeaders({required String referer}) {
    return {
      'User-Agent': userAgent,
      'Accept': 'audio/mpeg,audio/*,*/*;q=0.8',
      'Referer': referer,
    };
  }

  Future<String> _requestHtml(
    Uri uri, {
    String? referer,
    Map<String, String>? form,
  }) async {
    _policy.validate(uri);
    final headers = _htmlHeaders(referer: referer);
    final response = form == null
        ? await _transport.get(uri, headers: headers)
        : await _transport.post(
            uri,
            headers: {
              ...headers,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            bodyBytes: utf8.encode(Uri(queryParameters: form).query),
          );
    if (form != null &&
        (_isSearchCheck(response.finalUri) ||
            _isSearchCheck(response.redirectLocation))) {
      throw const SourceException(
        sourceId: 'baza_knig',
        kind: SourceErrorKind.accessRestricted,
        message:
            'Baza Knig returned an interstitial instead of search results.',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }

    throw SourceException(
      sourceId: 'baza_knig',
      kind: response.statusCode == HttpStatus.tooManyRequests
          ? SourceErrorKind.rateLimited
          : SourceErrorKind.network,
      message: 'Baza Knig page returned HTTP ${response.statusCode}.',
    );
  }

  bool _isSearchCheck(Uri? uri) {
    if (uri == null || (uri.path != '/bk-chal' && uri.path != '/bk-chal/')) {
      return false;
    }
    try {
      _policy.validate(uri);
      return true;
    } on SourceException {
      return false;
    }
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
