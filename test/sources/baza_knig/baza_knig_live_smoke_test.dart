import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  final runLive = Platform.environment['SLOVOFON_LIVE_SOURCE_TESTS'] == '1';

  test(
    'live Baza Knig search, details, chapters, and media resolution work when audio is exposed',
    () async {
      final connector = BazaKnigSourceConnector();

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
      expect(media.mediaSource.headers['Referer'], contains('baza-knig.top'));
    },
    skip: runLive ? false : 'Set SLOVOFON_LIVE_SOURCE_TESTS=1 to run.',
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
