import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  final runLive = Platform.environment['SLOVOFON_LIVE_SOURCE_TESTS'] == '1';

  test(
    'live Baza Knig public search form returns actual first-page cards',
    () async {
      final page = await BazaKnigSourceConnector().searchPage(
        const SearchRequest(query: 'метро'),
      );
      expect(page.results, isNotEmpty);
      expect(
        page.results.every((result) => result.sourceId == 'baza_knig'),
        isTrue,
      );
    },
    skip: runLive ? false : 'Set SLOVOFON_LIVE_SOURCE_TESTS=1 to run.',
    timeout: const Timeout(Duration(seconds: 25)),
  );

  test(
    'live Baza Knig public title filter returns different second-page cards',
    () async {
      const request = SearchRequest(query: 'Метро', kind: SearchKind.title);
      final connector = BazaKnigSourceConnector();
      final first = await connector.searchPage(request);
      expect(first.results, isNotEmpty);
      expect(first.nextPage, 2, reason: 'Look for the filter\'s second page.');
      expect(first.nextCursor, isNotNull);

      final last = await connector.searchPage(
        request.copyWith(page: first.nextPage, sourceCursor: first.nextCursor),
      );
      final firstIds = first.results.map((book) => book.sourceBookId).toSet();
      expect(last.results, isNotEmpty);
      expect(
        last.results.any((book) => !firstIds.contains(book.sourceBookId)),
        isTrue,
        reason: 'A restarted search is not a successful second page.',
      );
    },
    skip: runLive ? false : 'Set SLOVOFON_LIVE_SOURCE_TESTS=1 to run.',
    timeout: const Timeout(Duration(seconds: 45)),
  );

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
