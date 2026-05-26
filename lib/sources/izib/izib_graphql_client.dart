import 'dart:convert';
import 'dart:io';

import '../source_models.dart';
import 'izib_signer.dart';

const izibBookCommonFragment = '''fragment BookCommon on Book {
  id
  name
  urlName
  defaultPoster
  defaultPosterMain
  totalDuration
  plays
  views
  comments
  likes
  dislikes
  posters
  publishTs
  aboutBb
  serieIndex
  genre { id name booksCount __typename }
  authors { id name surname booksCount __typename }
  readers { id name surname booksCount __typename }
  serie { id name booksCount __typename }
  __typename
}''';

const izibFileFragment = '''fragment File on BookFile {
  id
  index
  title
  fileName
  duration
  url
  size
  __typename
}''';

const izibSearchBooksQuery =
    '''query booksSearch(\$q: String!, \$offset: Int, \$count: Int) {
  booksSearch(q: \$q, offset: \$offset, count: \$count) {
    count
    items {
      ...BookCommon
      __typename
    }
    __typename
  }
}

$izibBookCommonFragment
''';

const izibBookQuery =
    '''query bookQuery(\$id: Int!) {
  book(id: \$id) {
    ...BookCommon
    favored
    files {
      full {
        ...File
        __typename
      }
      mobile {
        ...File
        __typename
      }
      __typename
    }
    __typename
  }
}

$izibBookCommonFragment

$izibFileFragment
''';

abstract interface class IzibGraphQlTransport {
  Future<IzibGraphQlTransportResponse> post(
    Uri uri, {
    required String body,
    required Map<String, String> headers,
  });
}

class IzibGraphQlTransportResponse {
  const IzibGraphQlTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

class DartIoIzibGraphQlTransport implements IzibGraphQlTransport {
  DartIoIzibGraphQlTransport({
    Duration timeout = const Duration(seconds: 8),
    HttpClient Function()? httpClientFactory,
  }) : _timeout = timeout,
       _httpClientFactory = httpClientFactory ?? HttpClient.new;

  final Duration _timeout;
  final HttpClient Function() _httpClientFactory;

  @override
  Future<IzibGraphQlTransportResponse> post(
    Uri uri, {
    required String body,
    required Map<String, String> headers,
  }) async {
    final client = _httpClientFactory();
    client.connectionTimeout = _timeout;

    try {
      final request = await client.postUrl(uri).timeout(_timeout);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.write(body);

      final response = await request.close().timeout(_timeout);
      final responseBody = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);

      return IzibGraphQlTransportResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}

class IzibGraphQlClient {
  IzibGraphQlClient({
    IzibGraphQlTransport? transport,
    IzibSigner? signer,
    Uri? apiUri,
  }) : _transport = transport ?? DartIoIzibGraphQlTransport(),
       _signer = signer ?? IzibSigner(),
       apiUri = apiUri ?? defaultApiUri;

  static final defaultApiUri = Uri.parse('https://api.izib.uk/graphql/');

  final IzibGraphQlTransport _transport;
  final IzibSigner _signer;
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
      variables: variables,
      query: query,
    );

    late final IzibGraphQlTransportResponse response;
    try {
      response = await _transport.post(
        apiUri,
        body: body,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'SIGN': _signer.sign(body),
          'User-Agent': 'com.izimobile/1.11 Android',
        },
      );
    } on SourceException {
      rethrow;
    } on Object catch (error) {
      throw SourceException(
        sourceId: 'izib',
        kind: SourceErrorKind.network,
        message: 'Izib API request failed.',
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SourceException(
        sourceId: 'izib',
        kind: SourceErrorKind.network,
        message: 'Izib API returned HTTP ${response.statusCode}.',
      );
    }

    final payload = _decodePayload(response.body);
    final errors = payload['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw SourceException(
        sourceId: 'izib',
        kind: SourceErrorKind.api,
        message: _safeGraphQlErrorMessage(errors),
      );
    }

    final data = payload['data'];
    if (data is! Map<String, Object?>) {
      throw const SourceException(
        sourceId: 'izib',
        kind: SourceErrorKind.parser,
        message: 'Izib API returned no data.',
      );
    }

    return data;
  }

  Future<Map<String, Object?>> searchBooks({
    required String query,
    required int offset,
    required int count,
  }) {
    return execute(
      operationName: 'booksSearch',
      variables: {'q': query, 'offset': offset, 'count': count},
      query: izibSearchBooksQuery,
    );
  }

  Future<Map<String, Object?>> book({required int id}) {
    return execute(
      operationName: 'bookQuery',
      variables: {'id': id},
      query: izibBookQuery,
    );
  }

  static Map<String, Object?> _decodePayload(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    } on Object catch (error) {
      throw SourceException(
        sourceId: 'izib',
        kind: SourceErrorKind.parser,
        message: 'Izib API returned invalid JSON.',
        cause: error,
      );
    }

    throw const SourceException(
      sourceId: 'izib',
      kind: SourceErrorKind.parser,
      message: 'Izib API returned invalid payload.',
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
        ? 'Izib API returned an error.'
        : messages.join('; ');
  }
}
