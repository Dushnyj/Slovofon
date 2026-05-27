import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('Akniga live smoke', () {
    test(
      'loads search, details, chapters, and playable media from akniga.org',
      () async {
        final connector = AknigaSourceConnector();
        final results = await connector.search(
          const SearchRequest(query: 'метро', kind: SearchKind.title),
        );
        expect(results, isNotEmpty);

        Object? lastError;
        for (final result in results.take(5)) {
          try {
            final details = await connector.getBookDetails(result.ref);
            final chapters = await connector.getChapters(result.ref);
            if (chapters.isEmpty) {
              continue;
            }
            final media = await connector.resolveMedia(
              chapters.first,
              MediaResolvePurpose.playback,
            );

            expect(details.version.sourceId, 'akniga');
            expect(details.version.title, isNotEmpty);
            expect(media.mediaSource.type, AudioMediaSourceType.url);
            expect(
              media.mediaSource.headers['Referer'],
              contains('akniga.org'),
            );
            return;
          } on Object catch (error) {
            lastError = error;
          }
        }

        fail('No playable Akniga result found. Last error: $lastError');
      },
      skip: Platform.environment['SLOVOFON_LIVE_SOURCE_TESTS'] == '1'
          ? false
          : 'Set SLOVOFON_LIVE_SOURCE_TESTS=1 to run live source checks.',
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });
}
