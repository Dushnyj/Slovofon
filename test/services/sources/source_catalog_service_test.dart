import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/audio_track.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/services/sources/source_settings_store.dart';
import 'package:slovofon/sources/izib/izib_graphql_client.dart';
import 'package:slovofon/sources/knigoblud/knigoblud_mapper.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('SourceCatalogService', () {
    test('default registry enables all real source connectors', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = container.read(sourceRegistryProvider);

      expect(
        registry.enabledSourceIds,
        containsAll({'izib', 'akniga', 'yakniga'}),
      );
      expect(registry.connectorById('izib'), isA<IzibSourceConnector>());
      expect(registry.connectorById('akniga'), isA<AknigaSourceConnector>());
      expect(registry.connectorById('yakniga'), isA<YaknigaSourceConnector>());
      expect(
        registry.connectorById('knigavuhe'),
        isA<KnigavuheSourceConnector>(),
      );
      expect(
        registry.connectorById('knigoblud'),
        isA<KnigobludSourceConnector>(),
      );
      expect(
        registry.connectorById('baza_knig'),
        isA<BazaKnigSourceConnector>(),
      );
    });

    test('source settings drive the enabled search registry', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(sourceSettingsStoreProvider).setEnabledSources({
        'izib',
      });

      final registry = container.read(sourceRegistryProvider);

      expect(registry.enabledSourceIds, {'izib'});
      expect(registry.enabledConnectors.map((connector) => connector.id), [
        'izib',
      ]);
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

    test('source registry searches enabled connectors concurrently', () async {
      final stopwatch = Stopwatch()..start();
      final first = _DelayedSearchConnector(
        id: 'first',
        delay: const Duration(milliseconds: 120),
        stopwatch: stopwatch,
      );
      final second = _DelayedSearchConnector(
        id: 'second',
        delay: Duration.zero,
        stopwatch: stopwatch,
      );

      await SourceRegistry([
        first,
        second,
      ]).search(const SearchRequest(query: 'дыхание зоны'));

      expect(second.startedAtMs, lessThan(80));
    });

    test('maps card metadata from source search results', () {
      final service = SourceCatalogService(
        registry: SourceRegistry([_FilteringSourceConnector()]),
      );

      final book = service.audioBookForSearchResult(
        const BookSearchResult(
          ref: SourceBookRef(sourceId: 'akniga', sourceBookId: 'half-life'),
          sourceName: 'Akniga',
          title: 'S.T.A.L.K.E.R. Полураспад',
          author: 'Александр Зорич',
          narrator: 'Чайцын Александр',
          series: 'S.T.A.L.K.E.R.',
          duration: Duration(hours: 11, minutes: 49),
          year: 2019,
          ratingValue: 4.4,
          ratingCount: 154,
          accessType: AccessType.free,
        ),
      );

      expect(book.seriesTitle, 'S.T.A.L.K.E.R.');
      expect(book.ratingValue, 4.4);
      expect(book.ratingCount, 154);
      expect(book.year, 2019);
      expect(book.durationLabel, '11 ч 49 мин');
    });

    test('search enriches sparse source cards with details metadata', () async {
      final service = SourceCatalogService(
        registry: SourceRegistry([_EnrichingSourceConnector()]),
      );

      final response = await service.search(
        const SearchRequest(query: 'дыхание зоны', sourceIds: {'knigavuhe'}),
      );

      expect(response.results, hasLength(1));
      final result = response.results.single;
      expect(result.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(result.author, 'Николай Грошев');
      expect(result.narrator, 'Олег Шубин');
      expect(result.series, 'Велес');
      expect(result.seriesNumber, 1);
      expect(result.duration, const Duration(hours: 17, minutes: 20));
      expect(result.year, 2020);
      expect(result.ratingValue, 4.4);
      expect(result.ratingCount, 1014);
    });

    test('search uses cached details enrichment on repeated queries', () async {
      final connector = _CountingEnrichingSourceConnector();
      final service = SourceCatalogService(
        registry: SourceRegistry([connector]),
      );

      await service.search(
        const SearchRequest(query: 'дыхание зоны', sourceIds: {'knigavuhe'}),
      );
      await service.search(
        const SearchRequest(query: 'дыхание зоны', sourceIds: {'knigavuhe'}),
      );

      expect(connector.detailsCalls, 1);
    });

    test(
      'other narration fallback has a distinct three-token budget',
      () async {
        final connector = _CountingNarrationSearchConnector();
        final service = SourceCatalogService(
          registry: SourceRegistry([connector]),
        );
        final alternatives = await service.findOtherNarrations(
          _sourceSnapshot(
            sourceId: 'izib',
            sourceName: 'Izib',
            sourceBookId: 'fixture',
            title: 'Один один два три четыре пять шесть',
            author: 'Автор',
            narrator: 'Чтец',
          ),
        );
        expect(alternatives, isEmpty);
        expect(connector.queries, [
          'один один два три четыре пять шесть',
          'один',
          'два',
          'три',
        ]);
      },
    );

    test(
      'finds other narrations across sources by title and reordered author',
      () async {
        final service = SourceCatalogService(
          registry: SourceRegistry([
            const _NarrationSourceConnector(
              id: 'knigavuhe',
              name: 'Knigavuhe',
              results: [
                BookSearchResult(
                  ref: SourceBookRef(
                    sourceId: 'knigavuhe',
                    sourceBookId: 'book/8996-stalker-dykhanie-zony',
                  ),
                  sourceName: 'Knigavuhe',
                  title: 'S.T.A.L.K.E.R. Дыхание зоны',
                  author: 'Николай Грошев',
                  narrator: 'Тимофей Зобнин',
                  series: 'Велес',
                  seriesNumber: 1,
                ),
              ],
            ),
            const _NarrationSourceConnector(
              id: 'akniga',
              name: 'Akniga',
              results: [
                BookSearchResult(
                  ref: SourceBookRef(
                    sourceId: 'akniga',
                    sourceBookId: 'groshev-nikolay-dyhanie-zony',
                  ),
                  sourceName: 'Akniga',
                  title: 'Дыхание зоны',
                  author: 'Грошев Николай',
                  narrator: 'Олег Шубин',
                  series: 'Велес',
                  seriesNumber: 1,
                ),
                BookSearchResult(
                  ref: SourceBookRef(
                    sourceId: 'akniga',
                    sourceBookId: 'unrelated',
                  ),
                  sourceName: 'Akniga',
                  title: 'Дыхание зоны отчуждения',
                  author: 'Другой Автор',
                  narrator: 'Олег Шубин',
                ),
              ],
            ),
          ]),
        );
        final snapshot = _sourceSnapshot(
          sourceId: 'knigavuhe',
          sourceName: 'Knigavuhe',
          sourceBookId: 'book/8996-stalker-dykhanie-zony',
          title: 'S.T.A.L.K.E.R. Дыхание зоны',
          author: 'Николай Грошев',
          narrator: 'Тимофей Зобнин',
          series: 'Велес',
          seriesNumber: 1,
        );

        final alternatives = await service.findOtherNarrations(snapshot);

        expect(alternatives, hasLength(1));
        expect(alternatives.single.sourceId, 'akniga');
        expect(
          alternatives.single.sourceBookId,
          'groshev-nikolay-dyhanie-zony',
        );
        expect(alternatives.single.narrator, 'Олег Шубин');
      },
    );

    test(
      'other narrations preserve separated Knigoblud search roles',
      () async {
        final searchResults = KnigobludMapper().searchResults(
          File(
            'test/sources/knigoblud/fixtures/search_combined_people.html',
          ).readAsStringSync(),
        );
        final service = SourceCatalogService(
          registry: SourceRegistry([
            _NarrationSourceConnector(
              id: 'knigoblud',
              name: 'Knigoblud',
              results: searchResults,
            ),
          ]),
        );
        final alternatives = await service.findOtherNarrations(
          _sourceSnapshot(
            sourceId: 'izib',
            sourceName: 'Izib',
            sourceBookId: 'poluraspad',
            title: 'S.T.A.L.K.E.R. Полураспад',
            author: 'Александр Зорич',
            narrator: 'Чайцын Александр (Алекс)',
          ),
        );

        expect(alternatives, hasLength(1));
        expect(alternatives.single.sourceId, 'knigoblud');
        expect(alternatives.single.author, 'Александр Зорич');
        expect(alternatives.single.narrator, 'Чайцын Александр (Алекс)');
      },
    );

    test('search does not wait forever for slow details enrichment', () async {
      final service = SourceCatalogService(
        registry: SourceRegistry([_SlowEnrichingSourceConnector()]),
        searchEnrichmentTimeout: Duration.zero,
      );

      final response = await service.search(
        const SearchRequest(query: 'дыхание зоны', sourceIds: {'knigavuhe'}),
      );

      expect(response.results, hasLength(1));
      expect(response.results.single.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(response.results.single.author, isNull);
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

    test(
      'search skips token fallbacks when the full query already matches',
      () async {
        final connector = _CountingSourceConnector();
        final service = SourceCatalogService(
          registry: SourceRegistry([connector]),
        );

        final response = await service.search(
          const SearchRequest(query: 'дыхание зоны', sourceIds: {'izib'}),
        );

        expect(response.results, hasLength(1));
        expect(connector.queries, ['дыхание зоны']);
      },
    );

    test(
      'search filters by multiple selected fields and selected sources',
      () async {
        final service = SourceCatalogService(
          registry: SourceRegistry([
            _FilteringSourceConnector(),
            _SecondaryFilteringSourceConnector(),
          ]),
        );

        final response = await service.search(
          const SearchRequest(
            query: 'зорич',
            kinds: {SearchKind.author, SearchKind.series},
            sourceIds: {'second'},
          ),
        );

        expect(response.results, hasLength(1));
        expect(response.results.single.sourceId, 'second');
        expect(response.results.single.series, 'Александр Зорич');
      },
    );

    test('search filters by genre', () async {
      final service = SourceCatalogService(
        registry: SourceRegistry([_GenreFilteringSourceConnector()]),
      );

      final response = await service.search(
        const SearchRequest(query: 'постап', kinds: {SearchKind.genre}),
      );

      expect(response.results, hasLength(1));
      expect(response.results.single.title, 'Дыхание зоны');
    });

    test('search applies selected sort order after filtering', () async {
      final service = SourceCatalogService(
        registry: SourceRegistry([_SortingSourceConnector()]),
      );

      final byRating = await service.search(
        const SearchRequest(query: 'дыхание', sort: SearchSort.rating),
      );
      expect(byRating.results.map((result) => result.sourceBookId), [
        'rating-best',
        'rating-mid',
        'rating-missing',
      ]);

      final byYear = await service.search(
        const SearchRequest(query: 'дыхание', sort: SearchSort.year),
      );
      expect(byYear.results.map((result) => result.sourceBookId), [
        'rating-mid',
        'rating-best',
        'rating-missing',
      ]);
    });

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

    test(
      'uses total book duration when source chapters have no durations',
      () async {
        final service = SourceCatalogService(
          registry: SourceRegistry([_ZeroChapterDurationConnector()]),
        );

        final snapshot = await service.loadBook(
          const SourceBookRef(sourceId: 'baza_knig', sourceBookId: 'period'),
        );

        expect(
          snapshot.playbackBook.totalDuration,
          const Duration(hours: 11, minutes: 21, seconds: 32),
        );
        expect(
          snapshot.playbackBook.chapters.map((chapter) => chapter.duration),
          everyElement(greaterThan(Duration.zero)),
        );
      },
    );
  });
}

class _DelayedSearchConnector extends _FilteringSourceConnector {
  _DelayedSearchConnector({
    required this.id,
    required this.delay,
    required this.stopwatch,
  });

  @override
  final String id;
  final Duration delay;
  final Stopwatch stopwatch;
  int? startedAtMs;

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    startedAtMs = stopwatch.elapsedMilliseconds;
    await Future<void>.delayed(delay);
    return const [];
  }
}

class _EnrichingSourceConnector implements SourceConnector {
  @override
  String get id => 'knigavuhe';

  @override
  String get name => 'Knigavuhe';

  @override
  String get host => 'https://knigavuhe.org';

  @override
  String get color => '#2f7f86';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsDetails: true,
    supportsRating: true,
    supportsSeries: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'knigavuhe.org'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return const [
      BookSearchResult(
        ref: SourceBookRef(
          sourceId: 'knigavuhe',
          sourceBookId: 'book/29141-stalker-dykhanie-zony-1',
        ),
        sourceName: 'Knigavuhe',
        title: 'S.T.A.L.K.E.R. Дыхание зоны',
      ),
    ];
  }

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final now = DateTime.utc(2026, 5, 29);
    return BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: 'knigavuhe-book-29141-stalker-dykhanie-zony-1',
        bookId: 'knigavuhe-book-book-29141-stalker-dykhanie-zony-1',
        sourceId: 'knigavuhe',
        sourceBookId: ref.sourceBookId,
        title: 'S.T.A.L.K.E.R. Дыхание зоны',
        normalizedTitle: 's t a l k e r dyhanie zony',
        authors: const ['Николай Грошев'],
        narrators: const ['Олег Шубин'],
        seriesTitle: 'Велес',
        seriesNumber: 1,
        durationMs: const Duration(hours: 17, minutes: 20).inMilliseconds,
        durationText: '17 ч 20 мин',
        publishedYear: 2020,
        ratingValue: 4.4,
        ratingCount: 1014,
        accessType: AccessType.free,
        createdAt: now,
        updatedAt: now,
      ),
    );
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

class _CountingEnrichingSourceConnector extends _EnrichingSourceConnector {
  int detailsCalls = 0;

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) {
    detailsCalls += 1;
    return super.getBookDetails(ref);
  }
}

class _SlowEnrichingSourceConnector extends _EnrichingSourceConnector {
  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) {
    return Completer<BookVersionDetails>().future;
  }
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

class _CountingSourceConnector extends _FilteringSourceConnector {
  final queries = <String>[];

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    queries.add(request.query);
    return request.query == 'дыхание зоны'
        ? [
            const BookSearchResult(
              ref: SourceBookRef(sourceId: 'izib', sourceBookId: '18590'),
              sourceName: 'Izib',
              title: 'S.T.A.L.K.E.R. Дыхание зоны',
            ),
          ]
        : const [];
  }
}

class _SecondaryFilteringSourceConnector extends _FilteringSourceConnector {
  @override
  String get id => 'second';

  @override
  String get name => 'Second';

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return const [
      BookSearchResult(
        ref: SourceBookRef(sourceId: 'second', sourceBookId: 'series-hit'),
        sourceName: 'Second',
        title: 'Полураспад',
        author: 'Елена Котова',
        series: 'Александр Зорич',
      ),
      BookSearchResult(
        ref: SourceBookRef(sourceId: 'second', sourceBookId: 'title-miss'),
        sourceName: 'Second',
        title: 'Зорич',
        author: 'Другой Автор',
      ),
    ];
  }
}

class _GenreFilteringSourceConnector extends _FilteringSourceConnector {
  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return const [
      BookSearchResult(
        ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'genre-hit'),
        sourceName: 'Izib',
        title: 'Дыхание зоны',
        genres: ['Постапокалипсис', 'S.T.A.L.K.E.R.'],
      ),
      BookSearchResult(
        ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'genre-miss'),
        sourceName: 'Izib',
        title: 'Полураспад',
        genres: ['Фантастика'],
      ),
    ];
  }
}

class _SortingSourceConnector extends _FilteringSourceConnector {
  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    return const [
      BookSearchResult(
        ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'rating-mid'),
        sourceName: 'Izib',
        title: 'Дыхание третье',
        year: 2024,
        duration: Duration(hours: 8),
        ratingValue: 4.1,
        ratingCount: 90,
      ),
      BookSearchResult(
        ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'rating-best'),
        sourceName: 'Izib',
        title: 'Дыхание первое',
        year: 2020,
        duration: Duration(hours: 12),
        ratingValue: 4.8,
        ratingCount: 300,
      ),
      BookSearchResult(
        ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'rating-missing'),
        sourceName: 'Izib',
        title: 'Дыхание второе',
      ),
    ];
  }
}

class _ZeroChapterDurationConnector implements SourceConnector {
  @override
  String get id => 'baza_knig';

  @override
  String get name => 'Baza Knig';

  @override
  String get host => 'https://baza-knig.top';

  @override
  String get color => '#8a6f28';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsDetails: true,
    supportsChapters: true,
    supportsDirectAudio: true,
  );

  @override
  SourceMediaPolicy get mediaPolicy =>
      const SourceMediaPolicy(mediaHosts: {'archive.org'});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async =>
      const [];

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final now = DateTime.utc(2026, 5, 29);
    return BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: 'baza-knig-period',
        bookId: 'baza-knig-book-period',
        sourceId: 'baza_knig',
        sourceBookId: ref.sourceBookId,
        title: 'Период полураспада',
        normalizedTitle: 'period poluraspada',
        authors: const ['Котова Елена'],
        narrators: const ['Луганская Лариса'],
        durationMs: const Duration(
          hours: 11,
          minutes: 21,
          seconds: 32,
        ).inMilliseconds,
        durationText: '11 ч 21 мин',
        accessType: AccessType.free,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async {
    final now = DateTime.utc(2026, 5, 29);
    return [
      for (var index = 0; index < 3; index++)
        Chapter(
          id: 'chapter-$index',
          bookVersionId: 'baza-knig-period',
          sourceId: 'baza_knig',
          sourceBookId: ref.sourceBookId,
          sourceChapterId: '$index',
          index: index + 1,
          title: 'Глава ${index + 1}',
          normalizedTitle: 'glava ${index + 1}',
          streamRef: 'https://archive.org/download/period/$index.mp3',
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async => const [];

  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async {
    return ResolvedMedia(
      sourceId: id,
      chapterId: chapter.id,
      mediaSource: AudioMediaSource.url(Uri.parse(chapter.streamRef!)),
      resolvedAt: DateTime.utc(2026, 5, 29),
    );
  }

  @override
  Future<SourceHealth> checkHealth() async {
    return SourceHealth.working(sourceId: id);
  }
}

class _CountingNarrationSearchConnector extends _NarrationSourceConnector {
  _CountingNarrationSearchConnector()
    : super(id: 'izib', name: 'Izib', results: const []);

  final queries = <String>[];

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async {
    queries.add(request.query);
    return const [];
  }
}

class _NarrationSourceConnector implements SourceConnector {
  const _NarrationSourceConnector({
    required this.id,
    required this.name,
    required this.results,
  });

  @override
  final String id;

  @override
  final String name;

  final List<BookSearchResult> results;

  @override
  String get host => 'https://example.com/$id';

  @override
  String get color => '#445577';

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(supportsSearch: true, supportsDetails: true);

  @override
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy();

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async => results;

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    final result = results.firstWhere(
      (result) => result.sourceBookId == ref.sourceBookId,
    );
    final now = DateTime.utc(2026, 5, 29);
    return BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: '${result.sourceId}-${result.sourceBookId}',
        bookId: '${result.sourceId}-book-${result.sourceBookId}',
        sourceId: result.sourceId,
        sourceBookId: result.sourceBookId,
        title: result.title,
        normalizedTitle: result.title,
        authors: result.author == null ? const [] : [result.author!],
        narrators: result.narrator == null ? const [] : [result.narrator!],
        seriesTitle: result.series,
        seriesNumber: result.seriesNumber,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async => const [];

  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async => const [];

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

SourceBookSnapshot _sourceSnapshot({
  required String sourceId,
  required String sourceName,
  required String sourceBookId,
  required String title,
  required String author,
  required String narrator,
  String? series,
  double? seriesNumber,
}) {
  final now = DateTime.utc(2026, 5, 29);
  final details = BookVersionDetails(
    ref: SourceBookRef(sourceId: sourceId, sourceBookId: sourceBookId),
    version: BookVersion(
      id: '$sourceId-$sourceBookId',
      bookId: '$sourceId-book-$sourceBookId',
      sourceId: sourceId,
      sourceBookId: sourceBookId,
      title: title,
      normalizedTitle: title,
      authors: [author],
      narrators: [narrator],
      seriesTitle: series,
      seriesNumber: seriesNumber,
      createdAt: now,
      updatedAt: now,
    ),
  );
  return SourceBookSnapshot(
    details: details,
    chapters: const [],
    audioBook: AudioBook(
      id: details.version.bookId,
      sourceBookId: sourceBookId,
      title: title,
      author: author,
      narrator: narrator,
      sourceId: sourceId,
      sourceName: sourceName,
      durationLabel: '—',
      chapterCount: 0,
      progress: 0,
      access: BookAccess.unknown,
    ),
    playbackBook: AudioPlaybackBook(
      id: details.version.bookId,
      versionId: details.version.id,
      sourceId: sourceId,
      sourceBookId: sourceBookId,
      title: title,
      author: author,
      narrator: narrator,
      sourceName: sourceName,
      chapters: const [],
      seriesTitle: series,
      seriesNumber: seriesNumber,
    ),
  );
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
