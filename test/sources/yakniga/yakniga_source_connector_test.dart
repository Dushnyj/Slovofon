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

    test('unsupported search pages do not call the autocomplete API', () async {
      final client = FakeYaknigaClient();
      final connector = YaknigaSourceConnector(client: client);
      expect(
        await connector.search(const SearchRequest(query: 'книга', page: 2)),
        isEmpty,
      );
      expect(client.calls, isEmpty);
    });

    test(
      'reader scope expands autocomplete and advances its typed cursor',
      () async {
        final client = FakeYaknigaClient(
          responses: [
            {
              'search': [
                for (var i = 0; i < 20; i++) {..._book(), 'id': '$i'},
                {
                  '__typename': 'Reader',
                  'name': 'Кузнецов Сергей',
                  'aliasName': 'kuznetsov-sergey',
                },
              ],
            },
            _page(1, next: 2, id: '62685'),
            _page(2, id: 'later'),
          ],
        );
        final connector = YaknigaSourceConnector(client: client);
        const request = SearchRequest(
          query: 'Сергей Кузнецов',
          kind: SearchKind.narrator,
        );

        final first = await connector.searchPage(request);
        expect(
          first.results.map((book) => book.sourceBookId),
          contains('62685'),
        );
        expect(first.usedRequestedScope, isTrue);
        expect(first.limited, isFalse);
        expect(first.nextPage, 2);
        final second = await connector.searchPage(
          request.copyWith(
            page: first.nextPage,
            sourceCursor: first.nextCursor,
          ),
        );
        expect(second.results.single.sourceBookId, 'later');
        expect(second.nextPage, isNull);
        expect(client.calls, [
          'search:Сергей Кузнецов',
          'scoped:narrator:kuznetsov-sergey:1:20',
          'scoped:narrator:kuznetsov-sergey:2:20',
        ]);
      },
    );

    test('capped autocomplete without a scoped match is partial', () async {
      final connector = YaknigaSourceConnector(
        client: FakeYaknigaClient(
          responses: [
            {
              'search': [
                for (var i = 0; i < 20; i++) {..._book(), 'id': '$i'},
              ],
            },
          ],
        ),
      );
      final page = await connector.searchPage(
        const SearchRequest(query: 'метро'),
      );
      expect(page.results, hasLength(20));
      expect(page.limited, isTrue);
      expect(page.nextPage, isNull);
    });

    for (final (type, kind) in [
      ('Series', SearchKind.series),
      ('Genre', SearchKind.genre),
    ]) {
      test('one-word global $type uses the exact catalogue only', () async {
        final client = FakeYaknigaClient(
          responses: [
            _suggestions([
              _entity(type, 'МЕТРО', 'metro'),
              _entity(type, 'Метро 2033', 'metro-2033'),
              _entity('Reader', 'Метро', 'similarly-named-reader'),
            ]),
            _page(1, next: 3, id: 'first-catalogue'),
            _page(3, id: 'later-catalogue'),
          ],
        );
        final connector = YaknigaSourceConnector(client: client);
        const request = SearchRequest(query: 'метро');

        final first = await connector.searchPage(request);

        expect(first.results, hasLength(21));
        expect(first.results.last.sourceBookId, 'first-catalogue');
        expect(first.limited, isTrue);
        expect(first.usedRequestedScope, isFalse);
        expect(first.nextPage, 2);
        expect(first.nextCursor, isNotNull);

        final later = await connector.searchPage(
          request.copyWith(
            page: first.nextPage,
            sourceCursor: first.nextCursor,
          ),
        );

        expect(later.results.single.sourceBookId, 'later-catalogue');
        expect(later.nextPage, isNull);
        expect(client.calls, [
          'search:метро',
          'scoped:${kind.name}:metro:1:20',
          'scoped:${kind.name}:metro:3:20',
        ]);
      });
    }

    test(
      'cycle and genre keep independent cursors even with the same alias',
      () async {
        final client = FakeYaknigaClient(
          responses: [
            _suggestions([
              _entity('Genre', 'Метро 2033', 'metro-2033'),
              _entity('Series', 'Метро 2033', 'metro-2033'),
              _entity('Series', 'Мир Метро 2033', 'mir-metro-2033'),
            ]),
            _page(1, next: 3, id: 'series-first'),
            _page(1, next: 2, id: 'genre-first'),
            _page(3, id: 'series-last'),
            _page(2, next: 4, id: 'genre-middle'),
            _page(4, id: 'genre-last'),
          ],
        );
        final connector = YaknigaSourceConnector(client: client);
        const request = SearchRequest(query: 'метро 2033');

        final first = await connector.searchPage(request);
        expect(first.limited, isTrue);
        expect(
          first.results.map((x) => x.sourceBookId),
          containsAll(['series-first', 'genre-first']),
        );

        final second = await connector.searchPage(
          request.copyWith(
            page: first.nextPage,
            sourceCursor: first.nextCursor,
          ),
        );
        expect(second.results.map((x) => x.sourceBookId), [
          'series-last',
          'genre-middle',
        ]);
        expect(second.nextPage, 3);

        final third = await connector.searchPage(
          request.copyWith(
            page: second.nextPage,
            sourceCursor: second.nextCursor,
          ),
        );
        expect(third.results.single.sourceBookId, 'genre-last');
        expect(third.nextPage, isNull);
        expect(client.calls, [
          'search:метро 2033',
          'scoped:series:metro-2033:1:20',
          'scoped:genre:metro-2033:1:20',
          'scoped:series:metro-2033:3:20',
          'scoped:genre:metro-2033:2:20',
          'scoped:genre:metro-2033:4:20',
        ]);
      },
    );

    test(
      'strict genre is covered by its catalogue, not a same-named cycle',
      () async {
        final client = FakeYaknigaClient(
          responses: [
            _suggestions([
              _entity('Series', 'Метро 2033', 'series-metro-2033'),
              _entity('Genre', 'Метро 2033', 'genre-metro-2033'),
            ]),
            _page(1, next: 2, id: 'genre-first'),
            _page(2, id: 'genre-last'),
          ],
        );
        final connector = YaknigaSourceConnector(client: client);
        const request = SearchRequest(
          query: 'Метро 2033',
          kind: SearchKind.genre,
        );

        final first = await connector.searchPage(request);
        expect(first.usedRequestedScope, isTrue);
        expect(first.limited, isFalse);
        expect(first.results.last.sourceBookId, 'genre-first');

        final second = await connector.searchPage(
          request.copyWith(
            page: first.nextPage,
            sourceCursor: first.nextCursor,
          ),
        );
        expect(second.results.single.sourceBookId, 'genre-last');
        expect(second.nextPage, isNull);
        expect(client.calls, [
          'search:Метро 2033',
          'scoped:genre:genre-metro-2033:1:20',
          'scoped:genre:genre-metro-2033:2:20',
        ]);
      },
    );

    test(
      'a long mixed query does not open unrelated suggested catalogues',
      () async {
        const query = 'Во мрак Андрей Дьяков Кузнецов Сергей Метро 2033';
        final client = FakeYaknigaClient(
          responses: [
            {
              'search': [
                {..._book(), 'id': '62685', 'title': 'Во мрак'},
                _entity('Author', 'Андрей Дьяков', 'andrey-dyakov'),
                _entity('Reader', 'Кузнецов Сергей', 'kuznetsov-sergey'),
                _entity('Genre', 'Метро 2033', 'metro-2033'),
                _entity(
                  'Series',
                  'Вселенная Метро 2033',
                  'vselennaya-metro-2033',
                ),
              ],
            },
          ],
        );
        final connector = YaknigaSourceConnector(client: client);

        final page = await connector.searchPage(
          const SearchRequest(query: query),
        );

        expect(page.results.single.sourceBookId, '62685');
        expect(page.nextPage, isNull);
        expect(page.usedRequestedScope, isFalse);
        expect(client.calls, ['search:$query']);
      },
    );

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
  Future<Map<String, Object?>> scopedBooks({
    required SearchKind kind,
    required String alias,
    required int page,
    required int pageSize,
  }) async {
    calls.add('scoped:${kind.name}:$alias:$page:$pageSize');
    if (error != null) throw error!;
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

Map<String, Object?> _entity(String type, String name, String aliasName) => {
  '__typename': type,
  'name': name,
  'aliasName': aliasName,
};

Map<String, Object?> _suggestions(List<Map<String, Object?>> entities) => {
  'search': [
    for (var i = 0; i < 20; i++) {..._book(), 'id': '$i'},
    ...entities,
  ],
};

Map<String, Object?> _page(int page, {int? next, required String id}) => {
  'entity': {
    'books': {
      'metadata': {
        'currentPage': page,
        'nextPage': next,
        'totalPages': next ?? page,
      },
      'collection': [
        {..._book(), 'id': id, 'title': 'Во мрак'},
      ],
    },
  },
};

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
