import 'dart:convert';
import 'dart:collection';
import 'package:slovofon/services/deep_links/slovofon_deep_link.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/sources/akniga/akniga_client.dart';
import 'package:slovofon/sources/knigavuhe/knigavuhe_client.dart';
import 'package:slovofon/sources/knigavuhe/knigavuhe_mapper.dart';
import 'package:slovofon/sources/knigoblud/knigoblud_mapper.dart';
import 'package:slovofon/sources/yakniga/yakniga_mapper.dart';

class LocalAkniga implements AknigaTransport {
  int getCalls = 0, postCalls = 0;
  String token = 'old';
  @override
  Future<AknigaTransportResponse> get(
    Uri u, {
    required Map<String, String> headers,
  }) async {
    getCalls++;
    return const AknigaTransportResponse(
      statusCode: 200,
      body:
          '''<article data-bid="1"><h1 class="caption__article-main">Книга</h1></article><script>LIVESTREET_SECURITY_KEY='fixture';</script>''',
    );
  }

  @override
  Future<AknigaTransportResponse> post(
    Uri u, {
    required List<int> bodyBytes,
    required Map<String, String> headers,
  }) async {
    postCalls++;
    return AknigaTransportResponse(
      statusCode: 200,
      body: jsonEncode({
        'aItems': [
          {'id': 1, 'mp3': 'https://akniga.org/audio.mp3?token=$token'},
        ],
      }),
    );
  }
}

class PurposeAknigaConnector extends AknigaSourceConnector {
  PurposeAknigaConnector({required super.client});
  final purposes = <MediaResolvePurpose>[];
  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) {
    purposes.add(purpose);
    return super.resolveMedia(chapter, purpose);
  }
}

class LocalKnigavuhe implements KnigavuheTransport {
  LocalKnigavuhe({this.resultCount = 1});
  final int resultCount;
  int searchCalls = 0, detailCalls = 0;
  Uri? lastUri;
  @override
  Future<KnigavuheTransportResponse> get(
    Uri u, {
    required Map<String, String> headers,
  }) async {
    lastUri = u;
    if (u.path == '/search/') {
      searchCalls++;
      return KnigavuheTransportResponse(
        statusCode: 200,
        body: List.generate(
          resultCount,
          (i) =>
              '<div class="bookkitem"><a class="bookkitem_name" href="/book/${i + 1}-test/">Метро 2033</a></div>',
        ).join(),
      );
    }
    detailCalls++;
    return const KnigavuheTransportResponse(
      statusCode: 200,
      body:
          '''<h1>Метро 2033</h1><div class="book_genre"><a>Фантастика</a></div>''',
    );
  }
}

void main() {
  test(
    'deep link absolute book ID cannot bypass metadata host allowlist',
    () async {
      final target = Uri.parse('http://127.0.0.1:8080/fixture');
      final deepLink = slovofonBookDeepLink(
        sourceId: 'knigavuhe',
        sourceBookId: target.toString(),
      );
      final location = sourceBookLocationFromDeepLink(deepLink)!;
      final sourceBookId = Uri.decodeComponent(
        Uri.parse(location).pathSegments.last,
      );
      final t = LocalKnigavuhe();
      final c = KnigavuheSourceConnector(client: KnigavuheClient(transport: t));
      expect(c.mediaPolicy.allowsMetadataHost(target.host), isFalse);
      await expectLater(
        c.getBookDetails(
          SourceBookRef(sourceId: 'knigavuhe', sourceBookId: sourceBookId),
        ),
        throwsA(isA<SourceException>()),
      );
      expect(t.lastUri, isNull);
    },
  );
  test('Akniga successful temporary media cache expires', () async {
    final t = LocalAkniga();
    var now = DateTime.utc(2026);
    final c = AknigaSourceConnector(
      client: AknigaClient(transport: t),
      clock: () => now,
    );
    const r = SourceBookRef(sourceId: 'akniga', sourceBookId: 'test.html');
    final first = await c.getChapters(r);
    t.token = 'fresh';
    now = now.add(const Duration(days: 2));
    final second = await c.getChapters(r);
    final media = await c.resolveMedia(
      second.single,
      MediaResolvePurpose.playback,
    );
    expect(t.getCalls, 2);
    expect(t.postCalls, 2);
    expect(second.single.streamRef, isNot(first.single.streamRef));
    expect(media.mediaSource.uri.query, 'token=fresh');
  });
  test('genre filter enriches sparse cards before rejecting them', () async {
    final t = LocalKnigavuhe();
    final c = KnigavuheSourceConnector(client: KnigavuheClient(transport: t));
    final service = SourceCatalogService(registry: SourceRegistry([c]));
    final response = await service.search(
      const SearchRequest(query: 'Фантастика', kinds: {SearchKind.genre}),
    );
    expect(t.searchCalls, 1);
    expect(t.detailCalls, 1);
    expect(response.results, hasLength(1));
    final details = await c.getBookDetails(
      const SourceBookRef(sourceId: 'knigavuhe', sourceBookId: 'book/1-test'),
    );
    expect(details.version.genres, contains('Фантастика'));
  });
  test('LitRes trial is marked as a fragment by both mappers', () {
    const trial = 'https://www.litres.ru/get_mp3_trial/123.mp3';
    final k = KnigavuheMapper().bookDetails(
      '<h1>Книга</h1><script>BookPlayer([{"url":"$trial"}]);</script>',
      const SourceBookRef(sourceId: 'knigavuhe', sourceBookId: 'book/1-test'),
    );
    final b = KnigobludMapper().bookDetails(
      '<h1>Книга</h1><script>KB.playerInit({"playlist":[{"src":"$trial"}]});</script>',
      const SourceBookRef(sourceId: 'knigoblud', sourceBookId: 'test'),
    );
    for (final d in [k, b]) {
      expect(d.version.isFull, isFalse);
      expect(d.version.isFragment, isTrue);
      final service = SourceCatalogService(registry: SourceRegistry([]));
      expect(service.audioBookForDetails(d, 1).isFragment, isTrue);
    }
  });
  test('Yakniga reads the chapter collection once regardless of book size', () {
    final input = CountingBook({
      'id': 1,
      'title': 'Книга',
      'chapters': {
        'collection': List.generate(
          500,
          (i) => <String, Object?>{
            'id': i,
            'pos': 500 - i,
            'fileUrl': 'https://yakniga.org/$i.mp3',
            'name': 'Глава $i',
          },
        ),
      },
    });
    final result = YaknigaMapper().chapters(input);
    expect(input.chapterReads, 1);
    expect(result.length, 500);
    expect(result.first.sourceChapterId, '499');
  });
  test(
    'metadata filtering retains its explicit details request budget',
    () async {
      final t = LocalKnigavuhe(resultCount: 50);
      final service = SourceCatalogService(
        registry: SourceRegistry([
          KnigavuheSourceConnector(client: KnigavuheClient(transport: t)),
        ]),
        searchEnrichmentLimit: 3,
      );
      final response = await service.search(
        const SearchRequest(query: 'Фантастика', kinds: {SearchKind.genre}),
      );
      expect(t.detailCalls, 3);
      expect(response.results, hasLength(3));
    },
  );
  test('forced download refresh evicts tracks and is single-flight', () async {
    final t = LocalAkniga();
    final connector = PurposeAknigaConnector(
      client: AknigaClient(transport: t),
    );
    final service = SourceCatalogService(registry: SourceRegistry([connector]));
    const r = SourceBookRef(sourceId: 'akniga', sourceBookId: 'test.html');
    final first = await service.loadBook(r);
    t.token = 'fresh';
    final fresh = await Future.wait([
      service.refreshBookForDownloads(first.playbackBook),
      service.refreshBookForDownloads(first.playbackBook),
    ]);
    expect(t.getCalls, 2);
    expect(t.postCalls, 2);
    expect(fresh.first.chapters.single.mediaSource!.uri.query, 'token=fresh');
    expect(
      fresh.first.chapters.single.id,
      first.playbackBook.chapters.single.id,
    );
    t.token = 'playback-fresh';
    final playback = await service.refreshBookForPlayback(fresh.first);
    expect(t.postCalls, 3);
    expect(connector.purposes, [
      MediaResolvePurpose.playback,
      MediaResolvePurpose.download,
      MediaResolvePurpose.playback,
    ]);
    expect(
      playback.chapters.single.mediaSource!.uri.query,
      'token=playback-fresh',
    );
  });
}

class CountingBook extends MapBase<String, Object?> {
  CountingBook(this.valuesMap);
  final Map<String, Object?> valuesMap;
  int chapterReads = 0;
  @override
  Object? operator [](Object? key) {
    if (key == 'chapters') chapterReads++;
    return valuesMap[key];
  }

  @override
  void operator []=(String key, Object? value) => valuesMap[key] = value;
  @override
  Iterable<String> get keys => valuesMap.keys;
  @override
  void clear() => valuesMap.clear();
  @override
  Object? remove(Object? key) => valuesMap.remove(key);
}
