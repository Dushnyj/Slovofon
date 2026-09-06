import 'dart:io';

import '../source_models.dart';
import '../source_metadata_transport.dart';

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
    SourceMetadataPolicy policy = KnigavuheClient.metadataPolicy,
  }) : _transport = SourceMetadataTransport(
         policy: policy,
         timeout: timeout,
         httpClientFactory: httpClientFactory,
       );

  final SourceMetadataTransport _transport;

  @override
  Future<KnigavuheTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    final response = await _transport.send(uri, headers: headers);
    return KnigavuheTransportResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
  }
}

class KnigavuheClient {
  KnigavuheClient({
    KnigavuheTransport? transport,
    Uri? baseUri,
    SourceMetadataPolicy policy = metadataPolicy,
  }) : _transport = transport ?? DartIoKnigavuheTransport(policy: policy),
       baseUri = baseUri ?? defaultBaseUri,
       _policy = policy;

  static final defaultBaseUri = Uri.parse('https://knigavuhe.org/');
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/125.0 Safari/537.36';

  final KnigavuheTransport _transport;
  static const metadataPolicy = SourceMetadataPolicy(
    sourceId: 'knigavuhe',
    hosts: {'knigavuhe.org', 'www.knigavuhe.org'},
  );
  final SourceMetadataPolicy _policy;
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
    final uri = _policy.bookUri(baseUri, ref);
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
    _policy.validate(uri);
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
