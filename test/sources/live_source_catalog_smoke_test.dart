import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  final runLive = Platform.environment['SLOVOFON_LIVE_SOURCE_TESTS'] == '1';

  group('Live SourceCatalog playback path', () {
    for (final connector in <SourceConnector>[
      AknigaSourceConnector(),
      YaknigaSourceConnector(),
      KnigavuheSourceConnector(),
      KnigobludSourceConnector(),
      BazaKnigSourceConnector(),
    ]) {
      test(
        '${connector.id} loads Дыхание зоны through SourceCatalogService',
        () async {
          final service = SourceCatalogService(
            registry: SourceRegistry([connector]),
          );
          final response = await service.search(
            const SearchRequest(query: 'дыхание зоны', kind: SearchKind.title),
          );
          expect(response.results, isNotEmpty);

          final result = response.results.firstWhere(
            (item) => item.title.toLowerCase().contains('дыхание зоны'),
            orElse: () => response.results.first,
          );
          final snapshot = await service.loadBook(result.ref);

          expect(snapshot.audioBook.title, isNotEmpty);
          expect(snapshot.playbackBook.chapters, isNotEmpty);
          expect(
            snapshot.playbackBook.chapters.first.mediaSource?.uri,
            isNotNull,
          );
        },
        skip: runLive ? false : 'Set SLOVOFON_LIVE_SOURCE_TESTS=1 to run.',
        timeout: const Timeout(Duration(seconds: 90)),
      );
    }
  });
}
