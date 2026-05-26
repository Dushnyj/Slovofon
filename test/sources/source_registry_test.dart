import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/audio_track.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('SourceRegistry', () {
    test('rejects duplicate connector ids', () {
      final connector = _FakeSourceConnector(id: 'yakniga');

      expect(
        () => SourceRegistry([connector, connector]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('search aggregates enabled source results and failures', () async {
      final ok = _FakeSourceConnector(
        id: 'yakniga',
        results: const [
          BookSearchResult(
            ref: SourceBookRef(sourceId: 'yakniga', sourceBookId: 'book-1'),
            sourceName: 'Yakniga',
            title: 'Метро 2033',
          ),
        ],
      );
      final failing = _FakeSourceConnector(
        id: 'izib',
        failure: const SourceException(
          sourceId: 'izib',
          kind: SourceErrorKind.network,
          message: 'offline',
        ),
      );

      final response = await SourceRegistry([
        ok,
        failing,
      ]).search(const SearchRequest(query: 'метро'));

      expect(response.results, hasLength(1));
      expect(response.results.single.sourceId, 'yakniga');
      expect(response.failures, hasLength(1));
      expect(response.failures.single.sourceId, 'izib');
      expect(response.failures.single.kind, SourceErrorKind.network);
      expect(response.hasPartialFailures, isTrue);
    });

    test('search only calls requested enabled sources', () async {
      final yakniga = _FakeSourceConnector(id: 'yakniga');
      final izib = _FakeSourceConnector(id: 'izib');
      final registry = SourceRegistry(
        [yakniga, izib],
        enabledSourceIds: {'yakniga', 'izib'},
      );

      await registry.search(
        const SearchRequest(query: 'пикник', sourceIds: {'izib'}),
      );

      expect(yakniga.searchCalls, 0);
      expect(izib.searchCalls, 1);
    });

    test('unknown connector access throws a source exception', () {
      final registry = SourceRegistry([_FakeSourceConnector(id: 'yakniga')]);

      expect(
        () => registry.connectorById('missing'),
        throwsA(
          isA<SourceException>()
              .having((error) => error.sourceId, 'sourceId', 'missing')
              .having((error) => error.kind, 'kind', SourceErrorKind.notFound),
        ),
      );
    });
  });
}

class _FakeSourceConnector implements SourceConnector {
  _FakeSourceConnector({
    required this.id,
    this.results = const [],
    this.failure,
  });

  @override
  final String id;

  final List<BookSearchResult> results;
  final SourceException? failure;
  int searchCalls = 0;

  @override
  String get name => id;

  @override
  String get host => '$id.example.test';

  @override
  String get color => '#3355AA';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsDetails: true,
    supportsChapters: true,
    supportsDirectAudio: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy => SourceMediaPolicy(
    metadataHosts: {'$id.example.test'},
    mediaHosts: {'media.$id.example.test'},
    coverHosts: {'covers.$id.example.test'},
  );

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) {
    throw UnsupportedError('not used in registry tests');
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) {
    throw UnsupportedError('not used in registry tests');
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) {
    throw UnsupportedError('not used in registry tests');
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) {
    throw UnsupportedError('not used in registry tests');
  }

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    searchCalls += 1;
    final activeFailure = failure;
    if (activeFailure != null) {
      throw activeFailure;
    }
    return results;
  }
}
