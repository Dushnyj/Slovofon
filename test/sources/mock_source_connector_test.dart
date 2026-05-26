import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('MockSourceConnector', () {
    final connector = MockSourceConnector.yakniga();

    test('search maps existing mock books to source results', () async {
      final results = await connector.search(
        const SearchRequest(query: 'мастер'),
      );

      expect(results, hasLength(1));
      expect(results.single.sourceId, 'yakniga');
      expect(results.single.title, 'Мастер и Маргарита');
      expect(results.single.author, 'Михаил Булгаков');
      expect(results.single.narrator, 'Вячеслав Герасимов');
    });

    test('details and chapters map mock data to domain models', () async {
      const ref = SourceBookRef(
        sourceId: 'yakniga',
        sourceBookId: 'yakniga-master-and-margarita',
      );

      final details = await connector.getBookDetails(ref);
      final chapters = await connector.getChapters(ref);
      final tracks = await connector.getAudioTracks(ref);

      expect(details.version.sourceId, 'yakniga');
      expect(details.version.title, 'Мастер и Маргарита');
      expect(details.version.canStream, isTrue);
      expect(chapters, hasLength(3));
      expect(chapters.first.title, 'Никогда не разговаривайте с неизвестными');
      expect(
        chapters.first.durationMs,
        const Duration(minutes: 31).inMilliseconds,
      );
      expect(tracks, hasLength(3));
      expect(
        tracks.first.mediaRef,
        'asset:assets/audio/stage4_mock_chapter.wav',
      );
    });

    test(
      'resolveMedia returns the stage 4 asset and passes validation',
      () async {
        const ref = SourceBookRef(
          sourceId: 'yakniga',
          sourceBookId: 'yakniga-master-and-margarita',
        );
        final chapter = (await connector.getChapters(ref)).first;

        final media = await connector.resolveMedia(
          chapter,
          MediaResolvePurpose.playback,
        );
        final validated = SourceMediaValidator.validateResolvedMedia(
          connector.mediaPolicy,
          media,
          MediaResolvePurpose.playback,
        );

        expect(validated.mediaSource.type, AudioMediaSourceType.asset);
        expect(
          validated.mediaSource.assetPath,
          'assets/audio/stage4_mock_chapter.wav',
        );
      },
    );

    test('health check reports working without network access', () async {
      final health = await connector.checkHealth();

      expect(health.sourceId, 'yakniga');
      expect(health.status, SourceHealthStatus.working);
      expect(health.isUsable, isTrue);
    });
  });
}
