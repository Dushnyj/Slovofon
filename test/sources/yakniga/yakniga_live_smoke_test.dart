import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  final runLive = Platform.environment['SLOVOFON_LIVE_SOURCE_TESTS'] == '1';

  test(
    'Yakniga live search matches the narrator in both orders and the full metadata query',
    () async {
      final service = SourceCatalogService(
        registry: SourceRegistry([YaknigaSourceConnector()]),
        searchEnrichmentLimit: 0,
      );
      for (final query in ['Кузнецов Сергей', 'Сергей Кузнецов']) {
        final response = await service.search(
          SearchRequest(query: query, kind: SearchKind.narrator),
        );
        expect(response.failures, isEmpty);
        expect(
          response.results.map((book) => book.sourceBookId),
          contains('62685'),
        );
      }
      final response = await service.search(
        const SearchRequest(
          query: 'Во мрак Андрей Дьяков Кузнецов Сергей Метро 2033',
        ),
      );
      expect(response.failures, isEmpty);
      expect(
        response.results.map((book) => book.sourceBookId),
        contains('62685'),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: runLive
        ? false
        : 'Set SLOVOFON_LIVE_SOURCE_TESTS=1 to probe Yakniga network.',
  );

  test(
    'Yakniga live smoke finds a playable book and validates media URL',
    () async {
      final connector = YaknigaSourceConnector();

      final results = await connector.search(
        const SearchRequest(query: 'дыхание зоны', pageSize: 10),
      );
      expect(results, isNotEmpty);

      final result = results.firstWhere(
        (item) => item.title.toLowerCase().contains('дыхание'),
        orElse: () => results.first,
      );
      final details = await connector.getBookDetails(result.ref);
      final chapters = await connector.getChapters(result.ref);
      final media = await connector.resolveMedia(
        chapters.first,
        MediaResolvePurpose.probe,
      );

      expect(details.version.canStream, isTrue);
      expect(chapters, isNotEmpty);
      expect(media.mediaSource.uri.scheme, anyOf('http', 'https'));
      expect(
        connector.mediaPolicy.allowsMediaHost(media.mediaSource.uri.host),
        isTrue,
      );
    },
    skip: runLive
        ? false
        : 'Set SLOVOFON_LIVE_SOURCE_TESTS=1 to probe Yakniga network.',
  );
}
