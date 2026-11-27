import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/core/network/media_request_policy.dart';
import 'package:slovofon/services/sources/source_cover_client.dart';
import 'package:slovofon/services/sources/source_cover_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final uri = Uri.https('i.izib.uk', '/cover.png');
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
    '/x8AAwMCAO+jMxoAAAAASUVORK5CYII=',
  );

  test(
    'visible cards retry after queue pressure without fetching stale cards',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'slovofon-cover-queue-',
      );
      addTearDown(() => root.delete(recursive: true));
      final client = _FixtureClient();
      final repository = SourceCoverRepository(
        client: client,
        cacheDirectory: () async => root,
        maxConcurrent: 1,
        maxQueued: 0,
      );
      var mounted = true;
      final first = repository.load('izib', uri);
      final stale = repository.load(
        'izib',
        uri.replace(path: '/stale.png'),
        waitWhile: () => mounted,
      );
      final visible = repository.load(
        'izib',
        uri.replace(path: '/visible.png'),
        waitWhile: () => true,
      );
      mounted = false;
      client.response.complete(png);
      expect(await first, png);
      expect(await stale, isNull);
      expect(await visible, png);
      expect(client.requests, 2);
    },
  );

  test(
    'duplicates coalesce and the validated disk entry survives a new cache',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'slovofon-cover-cache-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final client = _FixtureClient();
      final repository = SourceCoverRepository(
        client: client,
        cacheDirectory: () async => root,
      );
      final first = repository.load('izib', uri);
      final duplicate = repository.load('izib', uri);
      expect(identical(first, duplicate), isTrue);
      client.response.complete(png);

      expect(await first, png);
      expect(await duplicate, png);
      expect(client.requests, 1);
      final file = File.fromUri(repository.cachedArtworkUri('izib', uri)!);
      expect(await file.readAsBytes(), png);

      final unused = _FixtureClient();
      final restored = SourceCoverRepository(
        client: unused,
        cacheDirectory: () async => root,
      );
      expect(await restored.load('izib', uri), png);
      expect(unused.requests, 0);
      expect(restored.cachedArtworkUri('izib', uri), file.uri);
    },
  );

  test(
    'unknown scopes and invalid artwork never reach the disk handoff',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'slovofon-cover-cache-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final client = _FixtureClient();
      final repository = SourceCoverRepository(
        client: client,
        cacheDirectory: () async => root,
      );
      client.response.complete(Uint8List.fromList(utf8.encode('not an image')));

      expect(await repository.load('missing-source', uri), isNull);
      expect(client.requests, 0);
      expect(await repository.load('izib', uri), isNull);
      expect(repository.cachedArtworkUri('izib', uri), isNull);
      expect(client.requests, 1);
    },
  );
}

class _FixtureClient extends SourceCoverClient {
  int requests = 0;
  final response = Completer<Uint8List?>();

  @override
  Future<Uint8List?> load(Uri uri, {MediaRequestPolicy? policy}) {
    expect(policy?.allows(uri), isTrue);
    requests++;
    return response.future;
  }
}
