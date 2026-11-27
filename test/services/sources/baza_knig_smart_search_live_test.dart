import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/baza_knig/baza_knig_client.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  final live = Platform.environment['SLOVOFON_LIVE_BAZA_SMART_TESTS'] == '1';
  const optIn = 'Set SLOVOFON_LIVE_BAZA_SMART_TESTS=1 to run.';

  test(
    'live title search follows the public link beyond the first page',
    () async {
      final transport = _RecordingTransport();
      final results = await _service(
        transport,
      ).search(const SearchRequest(query: 'Метро', kind: SearchKind.title));

      expect(results.failures, isEmpty);
      expect(results.results.length, greaterThan(33));
      expect(
        results.results.map((book) => book.sourceBookId).toSet(),
        hasLength(results.results.length),
      );
      expect(
        transport.gets.any(
          (uri) => uri.path.startsWith('/f/') && uri.path.endsWith('/page/2/'),
        ),
        isTrue,
      );
    },
    skip: live ? false : optIn,
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test(
    'live mixed search uses fields and matches one edition',
    () async {
      final transport = _RecordingTransport();
      final results = await _service(transport).search(
        const SearchRequest(query: 'Имя нам Легион Шубин Олег Меж двух миров'),
      );

      expect(results.failures, isEmpty);
      expect(results.results.length, greaterThan(1));
      for (final book in results.results) {
        expect(book.title.toLowerCase(), contains('имя нам легион'));
        expect(book.narrators.join(' ').toLowerCase(), contains('шубин'));
        expect(book.series?.toLowerCase(), contains('меж двух миров'));
      }
      expect(
        transport.gets.any(
          (uri) =>
              uri.path.startsWith('/f/') &&
              uri.pathSegments
                      .where(
                        (part) =>
                            part.startsWith('cikl=') ||
                            part.startsWith('j.x.ispolnitel;') ||
                            part.startsWith('nazvanie='),
                      )
                      .length >=
                  2,
        ),
        isTrue,
      );
    },
    skip: live ? false : optIn,
    timeout: const Timeout(Duration(seconds: 45)),
  );

  for (final (kind, query, pathSegment) in const [
    (SearchKind.author, 'Андрей Дьяков', 'j.x.autor;p.title='),
    (SearchKind.narrator, 'Олег Шубин', 'j.x.ispolnitel;'),
    (SearchKind.series, 'Меж двух миров', 'cikl='),
    (SearchKind.genre, 'Метро 2033', 'metro-2033i'),
  ]) {
    test(
      'live $kind scope uses its public route',
      () async {
        final transport = _RecordingTransport();
        final results = await _service(
          transport,
        ).search(SearchRequest(query: query, kind: kind));
        expect(results.failures, isEmpty);
        expect(results.results, isNotEmpty);
        expect(
          transport.gets.any(
            (uri) =>
                uri.pathSegments.any((part) => part.startsWith(pathSegment)),
          ),
          isTrue,
        );
      },
      skip: live ? false : optIn,
      timeout: const Timeout(Duration(seconds: 45)),
    );
  }
}

SourceCatalogService _service(BazaKnigTransport transport) =>
    SourceCatalogService(
      registry: SourceRegistry([
        BazaKnigSourceConnector(client: BazaKnigClient(transport: transport)),
      ]),
      searchEnrichmentLimit: 0,
    );

class _RecordingTransport implements BazaKnigTransport {
  final _inner = DartIoBazaKnigTransport();
  final gets = <Uri>[];

  @override
  Future<BazaKnigTransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    bool followRedirects = true,
  }) {
    gets.add(uri);
    return _inner.get(uri, headers: headers, followRedirects: followRedirects);
  }

  @override
  Future<BazaKnigTransportResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required List<int> bodyBytes,
  }) => _inner.post(uri, headers: headers, bodyBytes: bodyBytes);
}
