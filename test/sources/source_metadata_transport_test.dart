import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/akniga/akniga_client.dart';
import 'package:slovofon/sources/baza_knig/baza_knig_client.dart';
import 'package:slovofon/sources/knigavuhe/knigavuhe_client.dart';
import 'package:slovofon/sources/knigoblud/knigoblud_client.dart';
import 'package:slovofon/sources/source_metadata_transport.dart';
import 'package:slovofon/sources/source_models.dart';

typedef _Get =
    Future<Object> Function(Uri uri, {required Map<String, String> headers});

void main() {
  final policies = [
    AknigaClient.metadataPolicy,
    BazaKnigClient.metadataPolicy,
    KnigavuheClient.metadataPolicy,
    KnigobludClient.metadataPolicy,
  ];
  for (final policy in policies) {
    test(
      '${policy.sourceId} rejects unsafe ref representations and accepts source URLs',
      () {
        final base = Uri.parse('https://${policy.hosts.first}/');
        for (final bad in [
          'http://127.0.0.1/fixture',
          '//${base.host}/book',
          'https://${base.host}.invalid/book',
          'file:///fixture',
          'https://user:password@${base.host}/book',
          'ftp://${base.host}/book',
        ]) {
          expect(
            () => policy.bookUri(
              base,
              SourceBookRef(sourceId: policy.sourceId, sourceBookId: bad),
            ),
            throwsA(isA<SourceException>()),
          );
        }
        expect(
          policy.bookUri(
            base,
            SourceBookRef(sourceId: policy.sourceId, sourceBookId: 'book/42'),
          ),
          base.resolve('book/42'),
        );
        expect(
          policy.bookUri(
            base,
            SourceBookRef(
              sourceId: policy.sourceId,
              sourceBookId: base.resolve('book/42').toString(),
            ),
          ),
          base.resolve('book/42'),
        );
        expect(
          () => policy.bookUri(
            base,
            SourceBookRef(
              sourceId: policy.sourceId,
              sourceBookId: 'book/42',
              sourceUri: Uri.parse('https://outside.invalid/book'),
            ),
          ),
          throwsA(isA<SourceException>()),
        );
      },
    );
  }

  const fixturePolicy = SourceMetadataPolicy(
    sourceId: 'fixture',
    hosts: {'127.0.0.1'},
  );
  final transports = <String, _Get Function()>{
    'akniga': () => DartIoAknigaTransport(policy: fixturePolicy).get,
    'baza_knig': () => DartIoBazaKnigTransport(policy: fixturePolicy).get,
    'knigavuhe': () => DartIoKnigavuheTransport(policy: fixturePolicy).get,
    'knigoblud': () => DartIoKnigobludTransport(policy: fixturePolicy).get,
  };
  for (final entry in transports.entries) {
    test(
      '${entry.key} validates before initial request and every redirect',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final base = Uri.parse('http://127.0.0.1:${server.port}/');
        final paths = <String>[];
        server.listen((request) async {
          paths.add(request.uri.path);
          final target = switch (request.uri.path) {
            '/allowed' => '/done',
            '/blocked' => 'http://localhost:${server.port}/forbidden',
            '/credentials' =>
              'http://user:pass@127.0.0.1:${server.port}/forbidden',
            '/scheme' => 'file:///forbidden',
            '/loop' => '/loop',
            _ => null,
          };
          if (target != null) {
            request.response.statusCode = 302;
            request.response.headers.set(HttpHeaders.locationHeader, target);
          } else {
            request.response.write('fixture');
          }
          await request.response.close();
        });
        final get = entry.value();
        await expectLater(
          get(base.replace(host: 'localhost'), headers: const {}),
          throwsA(isA<SourceException>()),
        );
        expect(paths, isEmpty);
        await get(base.resolve('allowed'), headers: const {});
        expect(paths, ['/allowed', '/done']);
        for (final path in ['blocked', 'credentials', 'scheme']) {
          await expectLater(
            get(base.resolve(path), headers: const {}),
            throwsA(isA<SourceException>()),
          );
        }
        expect(paths, isNot(contains('/forbidden')));
        await expectLater(
          get(base.resolve('loop'), headers: const {}),
          throwsA(isA<SourceException>()),
        );
        expect(paths.where((path) => path == '/loop'), hasLength(6));
      },
    );
  }

  test(
    'Akniga POST follows safe 303 as GET without forwarding the body',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final base = Uri.parse('http://127.0.0.1:${server.port}/');
      final methods = <String>[];
      final bodyLengths = <int>[];
      server.listen((request) async {
        methods.add(request.method);
        bodyLengths.add(
          await request.fold<int>(0, (sum, chunk) => sum + chunk.length),
        );
        if (request.uri.path == '/safe' || request.uri.path == '/blocked') {
          request.response.statusCode = 303;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            request.uri.path == '/safe'
                ? '/done'
                : 'http://localhost:${server.port}/forbidden',
          );
        } else {
          request.response.write('fixture');
        }
        await request.response.close();
      });
      final transport = DartIoAknigaTransport(policy: fixturePolicy);
      await transport.post(
        base.resolve('safe'),
        bodyBytes: [1, 2, 3],
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      );
      expect(methods, ['POST', 'GET']);
      expect(bodyLengths, [3, 0]);
      await expectLater(
        transport.post(
          base.resolve('blocked'),
          bodyBytes: [4],
          headers: const {},
        ),
        throwsA(isA<SourceException>()),
      );
      expect(methods, ['POST', 'GET', 'POST']);
    },
  );

  test(
    'Akniga alias Domain session reaches apex POST, host-only stays scoped',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final observed = <String, List<String>>{};
      server.listen((request) async {
        final host = request.headers.host!;
        observed['$host${request.uri.path}'] = [
          for (final cookie in request.cookies)
            '${cookie.name}=${cookie.value}',
        ];
        if (host == 'akniga.org' && request.uri.path == '/') {
          request.response.cookies.add(
            Cookie('apexOnly', 'fixture')..path = '/',
          );
          request.response.statusCode = 302;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            'http://www.akniga.org/book',
          );
        } else if (request.uri.path == '/book') {
          request.response.cookies.addAll([
            Cookie('session', 'fixture')
              ..domain = '.akniga.org'
              ..path = '/',
            Cookie('aliasOnly', 'fixture')..path = '/',
            Cookie('wrongIssuer', 'fixture')
              ..domain = 'sibling.akniga.org'
              ..path = '/',
            Cookie('outsideSource', 'fixture')
              ..domain = 'org'
              ..path = '/',
          ]);
        }
        request.response.write('fixture');
        await request.response.close();
      });
      final transport = DartIoAknigaTransport(
        httpClientFactory: () => _loopbackClient(server.port),
      );
      await transport.get(Uri.parse('http://akniga.org/'), headers: const {});
      await transport.post(
        Uri.parse('http://akniga.org/ajax/bid/1'),
        headers: const {},
        bodyBytes: const [],
      );
      await transport.get(
        Uri.parse('http://child.www.akniga.org/check'),
        headers: const {},
      );
      await transport.get(
        Uri.parse('http://sibling.akniga.org/check'),
        headers: const {},
      );
      expect(observed['www.akniga.org/book'], isEmpty);
      expect(
        observed['akniga.org/ajax/bid/1'],
        unorderedEquals(['apexOnly=fixture', 'session=fixture']),
      );
      expect(observed['child.www.akniga.org/check'], ['session=fixture']);
      expect(observed['sibling.akniga.org/check'], ['session=fixture']);
    },
  );

  test(
    'metadata cookies preserve paths and never send Secure over HTTP',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final observed = <String, List<String>>{};
      server.listen((request) async {
        observed[request.uri.path] = [
          for (final cookie in request.cookies)
            '${cookie.name}=${cookie.value}',
        ];
        if (request.uri.path == '/books/set') {
          request.response.cookies.addAll([
            Cookie('defaultPath', 'fixture'),
            Cookie('same', 'root')..path = '/',
            Cookie('same', 'books')..path = '/books',
            Cookie('secure', 'fixture')
              ..path = '/'
              ..secure = true,
          ]);
        }
        await request.response.close();
      });
      final transport = SourceMetadataTransport(
        policy: AknigaClient.metadataPolicy,
        timeout: const Duration(seconds: 2),
        httpClientFactory: () => _loopbackClient(server.port),
      );
      for (final path in ['/books/set', '/books/chapter', '/bookshelf', '/']) {
        await transport.send(
          Uri.parse('http://akniga.org$path'),
          headers: const {},
        );
      }
      expect(
        observed['/books/chapter'],
        unorderedEquals(['defaultPath=fixture', 'same=books', 'same=root']),
      );
      expect(
        observed['/books/chapter']!.indexOf('same=books'),
        lessThan(observed['/books/chapter']!.indexOf('same=root')),
      );
      expect(observed['/bookshelf'], ['same=root']);
      expect(observed['/'], ['same=root']);
    },
  );

  test(
    'metadata cookie Max-Age overrides Expires, expires and deletes by scope',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var now = DateTime.utc(2026, 1, 1);
      final observed = <String, List<String>>{};
      server.listen((request) async {
        observed[request.uri.path] = [
          for (final cookie in request.cookies)
            '${cookie.name}=${cookie.value}',
        ];
        if (request.uri.path == '/set') {
          request.response.cookies.addAll([
            Cookie('short', 'fixture')
              ..path = '/'
              ..maxAge = 10
              ..expires = DateTime.utc(2020),
            Cookie('expired', 'fixture')
              ..path = '/'
              ..expires = DateTime.utc(2020),
            Cookie('session', 'fixture')..path = '/',
            Cookie('same', 'root')..path = '/',
            Cookie('same', 'books')..path = '/books',
          ]);
        } else if (request.uri.path == '/delete') {
          request.response.cookies.addAll([
            Cookie('session', 'fixture')
              ..path = '/'
              ..maxAge = -1,
            Cookie('same', 'fixture')
              ..path = '/books'
              ..maxAge = 0
              ..expires = DateTime.utc(2030),
          ]);
        }
        await request.response.close();
      });
      final transport = SourceMetadataTransport(
        policy: AknigaClient.metadataPolicy,
        timeout: const Duration(seconds: 2),
        httpClientFactory: () => _loopbackClient(server.port),
        clock: () => now,
      );
      Future<void> get(String path) async {
        await transport.send(
          Uri.parse('http://akniga.org$path'),
          headers: const {},
        );
      }

      await get('/set');
      await get('/fresh');
      expect(
        observed['/fresh'],
        unorderedEquals(['short=fixture', 'session=fixture', 'same=root']),
      );
      now = now.add(const Duration(seconds: 11));
      await get('/expired');
      expect(
        observed['/expired'],
        unorderedEquals(['session=fixture', 'same=root']),
      );
      await get('/delete');
      await get('/books/chapter');
      expect(observed['/books/chapter'], ['same=root']);
    },
  );
}

// The logical source host is only used for URI/cookie semantics. Every socket
// goes to this test's local fixture; no external DNS, proxy or source is used.
HttpClient _loopbackClient(int port) {
  final client = HttpClient();
  client.findProxy = (_) => 'DIRECT';
  client.connectionFactory = (_, _, _) =>
      Socket.startConnect(InternetAddress.loopbackIPv4, port);
  return client;
}
