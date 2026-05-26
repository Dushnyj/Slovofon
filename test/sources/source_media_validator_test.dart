import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('SourceMediaValidator', () {
    const policy = SourceMediaPolicy(
      mediaHosts: {'media.example.test'},
      metadataHosts: {'example.test'},
      coverHosts: {'covers.example.test'},
    );

    test('allows http media URLs from the source allowlist', () {
      final media = ResolvedMedia(
        sourceId: 'yakniga',
        mediaSource: AudioMediaSource.url(
          Uri.parse('https://cdn.media.example.test/books/1.mp3'),
        ),
        resolvedAt: DateTime.utc(2026, 5, 26),
      );

      final validated = SourceMediaValidator.validateResolvedMedia(
        policy,
        media,
        MediaResolvePurpose.playback,
      );

      expect(validated, same(media));
    });

    test('rejects media URLs outside the source allowlist', () {
      final media = ResolvedMedia(
        sourceId: 'yakniga',
        mediaSource: AudioMediaSource.url(
          Uri.parse('https://evil.example.test/books/1.mp3'),
        ),
        resolvedAt: DateTime.utc(2026, 5, 26),
      );

      expect(
        () => SourceMediaValidator.validateResolvedMedia(
          policy,
          media,
          MediaResolvePurpose.download,
        ),
        throwsA(
          isA<SourceException>().having(
            (error) => error.kind,
            'kind',
            SourceErrorKind.mediaValidation,
          ),
        ),
      );
    });

    test('rejects URLs with credentials', () {
      final media = ResolvedMedia(
        sourceId: 'yakniga',
        mediaSource: AudioMediaSource.url(
          Uri.parse('https://user:pass@media.example.test/books/1.mp3'),
        ),
        resolvedAt: DateTime.utc(2026, 5, 26),
      );

      expect(
        () => SourceMediaValidator.validateResolvedMedia(
          policy,
          media,
          MediaResolvePurpose.playback,
        ),
        throwsA(isA<SourceException>()),
      );
    });

    test('rejects non-http URL schemes', () {
      final media = ResolvedMedia(
        sourceId: 'yakniga',
        mediaSource: AudioMediaSource.url(
          Uri.parse('ftp://media.example.test/books/1.mp3'),
        ),
        resolvedAt: DateTime.utc(2026, 5, 26),
      );

      expect(
        () => SourceMediaValidator.validateResolvedMedia(
          policy,
          media,
          MediaResolvePurpose.probe,
        ),
        throwsA(isA<SourceException>()),
      );
    });

    test('requires explicit permission for local asset media', () {
      final media = ResolvedMedia(
        sourceId: 'mock',
        mediaSource: AudioMediaSource.asset(
          'assets/audio/stage4_mock_chapter.wav',
        ),
        resolvedAt: DateTime.utc(2026, 5, 26),
      );

      expect(
        () => SourceMediaValidator.validateResolvedMedia(
          policy,
          media,
          MediaResolvePurpose.playback,
        ),
        throwsA(isA<SourceException>()),
      );

      final validated = SourceMediaValidator.validateResolvedMedia(
        const SourceMediaPolicy(allowLocalMedia: true),
        media,
        MediaResolvePurpose.playback,
      );

      expect(validated, same(media));
    });
  });
}
