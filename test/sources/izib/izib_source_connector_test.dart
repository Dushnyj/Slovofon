import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/sources/izib/izib_graphql_client.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('IzibSourceConnector', () {
    test(
      'declares GraphQL, SIGN, details, chapters, and download capabilities',
      () {
        final connector = IzibSourceConnector(
          client: IzibGraphQlClient(transport: QueueIzibTransport([])),
        );

        expect(connector.id, 'izib');
        expect(connector.name, 'Izib');
        expect(connector.host, 'https://izib.uk');
        expect(connector.capabilities.supportsSearch, isTrue);
        expect(connector.capabilities.supportsDetails, isTrue);
        expect(connector.capabilities.supportsChapters, isTrue);
        expect(connector.capabilities.supportsDirectAudio, isTrue);
        expect(connector.capabilities.supportsDownload, isTrue);
        expect(connector.capabilities.hasGraphQlApi, isTrue);
        expect(connector.capabilities.hasApiSignature, isTrue);
        expect(connector.mediaPolicy.allowsMediaHost('audio.izib.uk'), isTrue);
      },
    );

    test('search maps GraphQL response through the source contract', () async {
      final connector = IzibSourceConnector(
        client: IzibGraphQlClient(
          transport: QueueIzibTransport([
            _fixtureText('izib_search_response.json'),
          ]),
        ),
      );

      final results = await connector.search(
        const SearchRequest(query: 'метро', page: 2, pageSize: 10),
      );

      expect(results, hasLength(1));
      expect(results.single.sourceId, 'izib');
      expect(results.single.sourceBookId, '2033');
      expect(results.single.title, 'Метро 2033');
    });

    test('details, chapters, tracks, and resolveMedia use API files', () async {
      final connector = IzibSourceConnector(
        client: IzibGraphQlClient(
          transport: QueueIzibTransport([
            _fixtureText('izib_book_response.json'),
            _fixtureText('izib_book_response.json'),
            _fixtureText('izib_book_response.json'),
          ]),
        ),
        clock: () => DateTime.utc(2026, 5, 26, 12),
      );
      const ref = SourceBookRef(sourceId: 'izib', sourceBookId: '2033');

      final details = await connector.getBookDetails(ref);
      final chapters = await connector.getChapters(ref);
      final tracks = await connector.getAudioTracks(ref);
      final media = await connector.resolveMedia(
        chapters.first,
        MediaResolvePurpose.playback,
      );
      final validated = SourceMediaValidator.validateResolvedMedia(
        connector.mediaPolicy,
        media,
        MediaResolvePurpose.playback,
      );

      expect(details.version.title, 'Метро 2033');
      expect(chapters, hasLength(2));
      expect(tracks, hasLength(2));
      expect(validated.mediaSource.type, AudioMediaSourceType.url);
      expect(
        validated.mediaSource.uri.toString(),
        'https://audio.izib.uk/books/2033/001.mp3',
      );
      expect(validated.supportsRange, isTrue);
    });

    test(
      'health check reports working for a successful API response',
      () async {
        final connector = IzibSourceConnector(
          client: IzibGraphQlClient(
            transport: QueueIzibTransport([
              jsonEncode({
                'data': {
                  'booksSearch': {'items': <Object?>[]},
                },
              }),
            ]),
          ),
          clock: () => DateTime.utc(2026, 5, 26, 12),
        );

        final health = await connector.checkHealth();

        expect(health.sourceId, 'izib');
        expect(health.status, SourceHealthStatus.working);
        expect(health.isUsable, isTrue);
      },
    );

    test('health check reports apiError without leaking SIGN', () async {
      final connector = IzibSourceConnector(
        client: IzibGraphQlClient(
          transport: QueueIzibTransport([
            jsonEncode({
              'errors': [
                {'message': 'bad request'},
              ],
            }),
          ]),
        ),
        clock: () => DateTime.utc(2026, 5, 26, 12),
      );

      final health = await connector.checkHealth();

      expect(health.status, SourceHealthStatus.apiError);
      expect(health.message, isNot(contains('SIGN')));
    });
  });
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
