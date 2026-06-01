import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/sources/yakniga/yakniga_graphql_client.dart';

void main() {
  group('YaknigaSourceConnector', () {
    test('declares GraphQL direct-audio capabilities and media allowlist', () {
      final connector = YaknigaSourceConnector();

      expect(connector.id, 'yakniga');
      expect(connector.name, 'Yakniga');
      expect(connector.capabilities.hasGraphQlApi, isTrue);
      expect(connector.capabilities.supportsDirectAudio, isTrue);
      expect(connector.capabilities.supportsDownload, isTrue);
      expect(connector.capabilities.requiresSpecialHeaders, isTrue);
      expect(connector.mediaPolicy.allowsMetadataHost('yakniga.org'), isTrue);
      expect(connector.mediaPolicy.allowsMediaHost('yakniga.org'), isTrue);
      expect(connector.mediaPolicy.allowsCoverHost('yakniga.org'), isTrue);
    });

    test('search maps GraphQL search collection', () async {
      final client = FakeYaknigaClient(
        responses: [
          {
            'search': [_book()],
          },
        ],
      );
      final connector = YaknigaSourceConnector(client: client);

      final results = await connector.search(
        const SearchRequest(query: 'дыхание зоны', pageSize: 10),
      );

      expect(results, hasLength(1));
      expect(results.single.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(results.single.sourceBookId, '50148');
      expect(client.calls, ['search:дыхание зоны']);
    });

    test(
      'details, chapters, tracks, and media resolution use book API',
      () async {
        final client = FakeYaknigaClient(
          responses: [
            {'book': _book(chapters: true)},
          ],
        );
        final connector = YaknigaSourceConnector(
          client: client,
          clock: () => DateTime.utc(2026, 5, 27, 12),
        );
        const ref = SourceBookRef(sourceId: 'yakniga', sourceBookId: '50148');

        final details = await connector.getBookDetails(ref);
        final chapters = await connector.getChapters(ref);
        final tracks = await connector.getAudioTracks(ref);
        final media = await connector.resolveMedia(
          chapters.first,
          MediaResolvePurpose.playback,
        );

        expect(details.version.title, 'S.T.A.L.K.E.R. Дыхание зоны');
        expect(chapters, hasLength(1));
        expect(tracks.single.mediaRef, chapters.single.streamRef);
        expect(
          media.mediaSource.uri.toString(),
          'https://yakniga.org/files/sata1/books/50/50148/chapter_0.mp3',
        );
        expect(media.mediaSource.headers['Referer'], contains('yakniga.org'));
        expect(media.supportsRange, isTrue);
        expect(client.calls, ['book:50148']);
      },
    );

    test('health reports API failures without throwing', () async {
      final connector = YaknigaSourceConnector(
        client: FakeYaknigaClient(
          error: const SourceException(
            sourceId: 'yakniga',
            kind: SourceErrorKind.api,
            message: 'GraphQL failed',
          ),
        ),
      );

      final health = await connector.checkHealth();

      expect(health.sourceId, 'yakniga');
      expect(health.status, SourceHealthStatus.apiError);
      expect(health.message, 'GraphQL failed');
    });
  });
}

class FakeYaknigaClient implements YaknigaGraphQlClient {
  FakeYaknigaClient({this.responses = const [], this.error});

  final List<Map<String, Object?>> responses;
  final SourceException? error;
  final calls = <String>[];

  @override
  Uri get apiUri => YaknigaGraphQlClient.defaultApiUri;

  @override
  Future<Map<String, Object?>> execute({
    required String operationName,
    required Map<String, Object?> variables,
    required String query,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, Object?>> searchBooks({required String term}) async {
    calls.add('search:$term');
    if (error != null) {
      throw error!;
    }
    return responses[calls.length - 1];
  }

  @override
  Future<Map<String, Object?>> book({
    String? id,
    String? aliasName,
    String? authorAliasName,
  }) async {
    calls.add('book:${id ?? '$authorAliasName/$aliasName'}');
    if (error != null) {
      throw error!;
    }
    return responses[calls.length - 1];
  }
}

Map<String, Object?> _book({bool chapters = false}) {
  return {
    '__typename': 'Book',
    'id': '50148',
    'title': 'S.T.A.L.K.E.R. Дыхание зоны',
    'aliasName': 's-t-a-l-k-e-r-dyhanie-zony',
    'authorAlias': 'groshev-nikolay',
    'authorName': 'Грошев Николай',
    'cover180': '/covers/50148.webp',
    'duration': 64920,
    'chaptersCount': chapters ? 1 : 12,
    'rating': 8.25,
    'price': null,
    'publishDate': '2021-05-01T00:00:00+03:00',
    'description': 'Описание',
    'copyrightBlock': false,
    'readers': [
      {'id': '3551', 'name': 'Зобнин Тимофей', 'aliasName': 'zobnin-timofey'},
    ],
    'authors': [
      {'id': '6929', 'name': 'Грошев Николай', 'aliasName': 'groshev-nikolay'},
    ],
    'chapters': chapters
        ? {
            'collection': [
              {
                'id': '606684',
                'name': '0 вступление',
                'duration': 64,
                'fileUrl': '/files/sata1/books/50/50148/chapter_0.mp3',
                'pos': 0,
              },
            ],
          }
        : const {'collection': <Object?>[]},
  };
}
