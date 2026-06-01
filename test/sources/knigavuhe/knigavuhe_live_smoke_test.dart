import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  final runLive = Platform.environment['SLOVOFON_LIVE_SOURCE_TESTS'] == '1';

  test(
    'live Knigavuhe search, details, chapters, and media resolution work',
    () async {
      final connector = KnigavuheSourceConnector();

      final results = await connector.search(
        const SearchRequest(query: 'дыхание зоны', page: 1),
      );
      expect(results, isNotEmpty);

      final first = results.firstWhere(
        (result) => result.title.toLowerCase().contains('дыхание зоны'),
        orElse: () => results.first,
      );
      final details = await connector.getBookDetails(first.ref);
      final chapters = await connector.getChapters(first.ref);
      final tracks = await connector.getAudioTracks(first.ref);
      final media = await connector.resolveMedia(
        chapters.first,
        MediaResolvePurpose.probe,
      );

      expect(details.version.title, isNotEmpty);
      expect(chapters, isNotEmpty);
      expect(tracks, hasLength(chapters.length));
      expect(media.mediaSource.uri, isNotNull);
      expect(media.mediaSource.headers['Referer'], contains('knigavuhe.org'));
    },
    skip: runLive ? false : 'Set SLOVOFON_LIVE_SOURCE_TESTS=1 to run.',
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test(
    'live Knigavuhe details expose year and vote-based rating for Дыхание зоны',
    () async {
      final connector = KnigavuheSourceConnector();

      for (final ref in [
        SourceBookRef(
          sourceId: 'knigavuhe',
          sourceBookId: 'book/8996-stalker-dykhanie-zony',
          sourceUri: Uri.parse(
            'https://knigavuhe.org/book/8996-stalker-dykhanie-zony/',
          ),
        ),
        SourceBookRef(
          sourceId: 'knigavuhe',
          sourceBookId: 'book/29141-stalker-dykhanie-zony-1',
          sourceUri: Uri.parse(
            'https://knigavuhe.org/book/29141-stalker-dykhanie-zony-1/',
          ),
        ),
      ]) {
        final details = await connector.getBookDetails(ref);

        expect(details.version.publishedYear, isNotNull);
        expect(details.version.ratingValue, isNotNull);
        expect(details.version.ratingCount, greaterThan(0));
      }
    },
    skip: runLive ? false : 'Set SLOVOFON_LIVE_SOURCE_TESTS=1 to run.',
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
