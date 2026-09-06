import 'dart:convert';
import 'dart:io';

import '../source_models.dart';
import '../source_response_reader.dart';

const yaknigaSearchBooksQuery = '''query Search(\$term: String!) {
  search(autocomplete: true, term: \$term) {
    __typename
    ... on Book {
      id
      title
      aliasName
      authorAlias
      authorName
      cover110
      cover180
      duration
      chaptersCount
      copyrightBlock
      rating
      price
      publishDate
      description
      readers { id name aliasName __typename }
      authors { id name aliasName __typename }
      series { id name aliasName __typename }
      genres {
        collection { id name aliasName __typename }
        __typename
      }
      __typename
    }
  }
}''';

const yaknigaBookQuery =
    '''query Book(\$id: ID, \$aliasName: String, \$authorAliasName: String) {
  book(id: \$id, aliasName: \$aliasName, authorAliasName: \$authorAliasName) {
    id
    title
    aliasName
    authorAlias
    authorName
    cover110
    cover180
    cover360
    duration
    chaptersCount
    copyrightBlock
    rating
    price
    publishDate
    description
    summary
    summaryShort
    readers { id name aliasName __typename }
    authors { id name aliasName __typename }
    series { id name aliasName __typename }
    genres {
      collection { id name aliasName __typename }
      __typename
    }
    chapters {
      collection {
        id
        name
        duration
        fileUrl
        pos
        __typename
      }
      __typename
    }
    __typename
  }
}''';

abstract interface class YaknigaGraphQlTransport {
  Future<YaknigaGraphQlTransportResponse> post(
    Uri uri, {
    required String body,
    required Map<String, String> headers,
  });
}

class YaknigaGraphQlTransportResponse {
  const YaknigaGraphQlTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class DartIoYaknigaGraphQlTransport implements YaknigaGraphQlTransport {
  DartIoYaknigaGraphQlTransport({
    Duration timeout = const Duration(seconds: 10),
    this.maxResponseBytes = 8 * 1024 * 1024,
    HttpClient Function()? httpClientFactory,
  }) : _timeout = timeout,
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Duration _timeout;
  final int maxResponseBytes;
  final HttpClient Function() _httpClientFactory;

  @override
  Future<YaknigaGraphQlTransportResponse> post(
    Uri uri, {
    required String body,
    required Map<String, String> headers,
  }) async {
    final client = _httpClientFactory();
    client.connectionTimeout = _timeout;

    try {
      final request = await client.postUrl(uri).timeout(_timeout);
      // API redirects are errors, not permission to send source headers to
      // another endpoint outside this connector's fixed GraphQL URL.
      request.followRedirects = false;
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final bodyBytes = utf8.encode(body);
      request.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close().timeout(_timeout);
      final responseBody = await readSourceResponseBody(
        response,
        sourceId: 'yakniga',
        maxBytes: maxResponseBytes,
      ).timeout(_timeout);

      return YaknigaGraphQlTransportResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}

class YaknigaGraphQlClient {
  YaknigaGraphQlClient({YaknigaGraphQlTransport? transport, Uri? apiUri})
    : _transport = transport ?? DartIoYaknigaGraphQlTransport(),
      apiUri = apiUri ?? defaultApiUri;

  static final defaultApiUri = Uri.parse('https://yakniga.org/graphql');
  static final defaultBaseUri = Uri.parse('https://yakniga.org/');
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/125.0 Safari/537.36';

  final YaknigaGraphQlTransport _transport;
  final Uri apiUri;

  static String graphQlBody({
    required String operationName,
    required Map<String, Object?> variables,
    required String query,
  }) {
    return jsonEncode({
      'operationName': operationName,
      'variables': variables,
      'query': query,
    });
  }

  Future<Map<String, Object?>> execute({
    required String operationName,
    required Map<String, Object?> variables,
    required String query,
  }) async {
    final body = graphQlBody(
      operationName: operationName,
      variables: _withoutNulls(variables),
      query: query,
    );

    late final YaknigaGraphQlTransportResponse response;
    try {
      response = await _transport.post(
        apiUri,
        body: body,
        headers: graphQlHeaders(),
      );
    } on SourceException {
      rethrow;
    } on Object catch (error) {
      throw SourceException(
        sourceId: 'yakniga',
        kind: SourceErrorKind.network,
        message: 'Yakniga API request failed.',
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SourceException(
        sourceId: 'yakniga',
        kind: SourceErrorKind.network,
        message: 'Yakniga API returned HTTP ${response.statusCode}.',
      );
    }

    final payload = _decodePayload(response.body);
    final errors = payload['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw SourceException(
        sourceId: 'yakniga',
        kind: SourceErrorKind.api,
        message: _safeGraphQlErrorMessage(errors),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, Object?>) {
      throw const SourceException(
        sourceId: 'yakniga',
        kind: SourceErrorKind.parser,
        message: 'Yakniga API returned no data.',
      );
    }

    return data;
  }

  Future<Map<String, Object?>> searchBooks({required String term}) {
    return execute(
      operationName: 'Search',
      variables: {'term': term},
      query: yaknigaSearchBooksQuery,
    );
  }

  Future<Map<String, Object?>> book({
    String? id,
    String? aliasName,
    String? authorAliasName,
  }) {
    return execute(
      operationName: 'Book',
      variables: {
        'id': id,
        'aliasName': aliasName,
        'authorAliasName': authorAliasName,
      },
      query: yaknigaBookQuery,
    );
  }

  static Map<String, String> graphQlHeaders() {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Accept-Language': 'ru-RU,ru;q=0.9,en;q=0.7',
      'Origin': 'https://yakniga.org',
      'Referer': 'https://yakniga.org/',
      'User-Agent': userAgent,
    };
  }

  static Map<String, String> mediaHeaders({required String referer}) {
    return {
      'User-Agent': userAgent,
      'Accept': 'audio/mpeg,audio/*,*/*;q=0.8',
      'Referer': referer,
    };
  }

  static Map<String, Object?> _decodePayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    } on Object catch (error) {
      throw SourceException(
        sourceId: 'yakniga',
        kind: SourceErrorKind.parser,
        message: 'Yakniga API returned invalid JSON.',
        cause: error,
      );
    }

    throw const SourceException(
      sourceId: 'yakniga',
      kind: SourceErrorKind.parser,
      message: 'Yakniga API returned invalid payload.',
    );
  }

  static String _safeGraphQlErrorMessage(List<Object?> errors) {
    final messages = <String>[];
    for (final error in errors) {
      if (error is Map<String, Object?>) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          messages.add(message.trim());
        }
      }
    }

    return messages.isEmpty
        ? 'Yakniga API returned an error.'
        : messages.join('; ');
  }

  static Map<String, Object?> _withoutNulls(Map<String, Object?> values) {
    return {
      for (final entry in values.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }
}
