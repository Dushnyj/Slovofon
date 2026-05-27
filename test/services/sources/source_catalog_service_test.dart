import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/audio_track.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/izib/izib_graphql_client.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('SourceCatalogService', () {
    test('default registry enables Izib and Akniga connectors', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(sourceRegistryProvider);

      expect(registry.enabledSourceIds, containsAll({'izib', 'akniga'}));
      expect(registry.connectorById('izib'), isA<IzibSourceConnector>());
      expect(registry.connectorById('akniga'), isA<AknigaSourceConnector>());
    });

    test('search returns Izib results through the source registry', () async {
      final service = SourceCatalogService(
        registry: SourceRegistry([
          IzibSourceConnector(
            client: IzibGraphQlClient(
              transport: QueueIzibTransport([
                _fixtureText('izib_search_response.json'),
              ]),
            ),
          ),
        ]),
      );

      final response = await service.search(
        const SearchRequest(query: 'метро', sourceIds: {'izib'}),
      );

      expect(response.failures, isEmpty);
      expect(response.results, hasLength(1));
      final result = response.results.single;
      expect(result.sourceId, 'izib');
      expect(result.sourceBookId, '2033');
      expect(result.title, 'Метро 2033');
      expect(
        result.coverUri.toString(),
        'https://izib.uk/covers/metro-2033.jpg',
      );
      expect(
        service.audioBookForSearchResult(result).coverUrl,
        contains('metro-2033'),
      );
    });

    test(
      'search keeps only results containing every query word prefix',
      () async {
        final service = SourceCatalogService(
          registry: SourceRegistry([_FilteringSourceConnector()]),
        );

        final response = await service.search(
          const SearchRequest(
            query: 'зоны дыхание',
            kind: SearchKind.title,
            sourceIds: {'izib'},
          ),
        );

        expect(response.results, hasLength(1));
        expect(response.results.single.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      },
    );

    test('loads Izib details and builds a playable book', () async {
      final service = SourceCatalogService(
        registry: SourceRegistry([
          IzibSourceConnector(
            client: IzibGraphQlClient(
              transport: QueueIzibTransport([
                _fixtureText('izib_book_response.json'),
                _fixtureText('izib_book_response.json'),
              ]),
            ),
          ),
        ]),
      );

      final snapshot = await service.loadBook(
        const SourceBookRef(sourceId: 'izib', sourceBookId: '2033'),
      );

      expect(snapshot.details.version.title, 'Метро 2033');
      expect(snapshot.details.version.sourceBookId, '2033');
      expect(snapshot.chapters, hasLength(2));
      expect(snapshot.audioBook.title, 'Метро 2033');
      expect(snapshot.audioBook.chapterCount, 2);
      expect(snapshot.audioBook.coverUrl, contains('metro-main'));

      final playbackBook = snapshot.playbackBook;
      expect(playbackBook.id, 'izib-book-2033');
      expect(playbackBook.sourceBookId, '2033');
      expect(playbackBook.title, 'Метро 2033');
      expect(playbackBook.coverUrl, contains('metro-main'));
      expect(
        playbackBook.totalDuration,
        const Duration(minutes: 41, seconds: 43),
      );
      expect(playbackBook.chapters, hasLength(2));
      expect(playbackBook.chapters.first.title, 'Глава 01. Артем');
      expect(
        playbackBook.chapters.first.mediaSource?.type,
        AudioMediaSourceType.url,
      );
      expect(
        playbackBook.chapters.first.mediaSource?.uri.toString(),
        'https://audio.izib.uk/books/2033/001.mp3',
      );
    });
  });
}

class _FilteringSourceConnector implements SourceConnector {
  @override
  String get id => 'izib';

  @override
  String get name => 'Izib';

  @override
  String get host => 'https://izib.uk';

  @override
  String get color => '#7d5a9d';

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(supportsSearch: true);

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'izib.uk'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return [
      const BookSearchResult(
        ref: SourceBookRef(sourceId: 'izib', sourceBookId: '18590'),
        sourceName: 'Izib',
        title: 'S.T.A.L.K.E.R. Дыхание зоны',
      ),
      const BookSearchResult(
        ref: SourceBookRef(sourceId: 'izib', sourceBookId: '42131'),
        sourceName: 'Izib',
        title: 'Контакт (часть первая)',
      ),
      const BookSearchResult(
        ref: SourceBookRef(sourceId: 'izib', sourceBookId: '43423'),
        sourceName: 'Izib',
        title: 'Огненный Дракон (часть первая)',
      ),
    ];
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) {
    throw UnimplementedError();
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) {
    throw UnimplementedError();
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) {
    throw UnimplementedError();
  }

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }
}

class QueueIzibTransport implements IzibGraphQlTransport {
  QueueIzibTransport(this.responses);

  final List<String> responses;

  @override
  Future<IzibGraphQlTransportResponse> post(
    Uri uri, {
    required String body,
    required Map<String, String> headers,
  }) async {
    if (responses.isEmpty) {
      throw StateError('No queued Izib response for $uri');
    }
    return IzibGraphQlTransportResponse(
      statusCode: 200,
      body: responses.removeAt(0),
    );
  }
}

String _fixtureText(String name) {
  return File('test/sources/izib/fixtures/$name').readAsStringSync();
}
