import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'source_models.dart';

/// Bounds decoded HTTP bytes before UTF-8/JSON/HTML parsing. HttpClient may
/// transparently decompress the wire body, so Content-Length alone is not a cap.
Future<String> readSourceResponseBody(
  HttpClientResponse response, {
  required String sourceId,
  required int maxBytes,
}) async {
  if (maxBytes <= 0 || response.contentLength > maxBytes) {
    throw SourceException(
      sourceId: sourceId,
      kind: SourceErrorKind.parser,
      message: 'Source metadata response exceeds the size limit.',
    );
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in response) {
    if (bytes.length + chunk.length > maxBytes) {
      throw SourceException(
        sourceId: sourceId,
        kind: SourceErrorKind.parser,
        message: 'Source metadata response exceeds the size limit.',
      );
    }
    bytes.add(chunk);
  }
  return utf8.decode(bytes.takeBytes());
}
