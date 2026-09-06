import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/updates/github_release.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_manifest.dart';

const _name = 'Slovofon-v0.0.6-windows-x64-setup.exe';
const _windowsPackages = {
  _name: UpdateAssetKind.installer,
  'Slovofon-v0.0.6-windows-x64-msi.msi': UpdateAssetKind.msi,
  'Slovofon-v0.0.6-windows-x64-portable.zip': UpdateAssetKind.portable,
};
final _api = Uri.parse(GitHubRelease.latestApiUrl);
final _url = Uri.parse(
  'https://github.com/Dushnyj/Slovofon/releases/download/v0.0.6/',
).resolve(_name);
final _payload = utf8.encode('synthetic installer bytes; never executed');

UpdateAsset _asset({
  String? name,
  Uri? url,
  String? hash,
  int? size,
  UpdateAssetKind kind = UpdateAssetKind.installer,
  UpdateAssetPlatform platform = UpdateAssetPlatform.windows,
  String arch = 'x64',
}) => UpdateAsset(
  platform: platform,
  arch: arch,
  kind: kind,
  url: url ?? _url.resolve(name ?? _name),
  fileName: name ?? _name,
  sha256: hash ?? sha256.convert(_payload).toString(),
  size: size ?? _payload.length,
);

Map<String, Object?> _release({
  bool digest = true,
  String name = _name,
  List<Object?> extra = const [],
}) => {
  'tag_name': 'v0.0.6',
  'draft': false,
  'prerelease': false,
  'html_url': 'https://github.com/Dushnyj/Slovofon/releases/tag/v0.0.6',
  'published_at': '2026-06-01T12:00:00Z',
  'body': 'Fixture release',
  'assets': [
    {
      'name': name,
      'browser_download_url': _url.resolve(name).toString(),
      'state': 'uploaded',
      'size': _payload.length,
      if (digest) 'digest': 'sha256:${sha256.convert(_payload)}',
    },
    ...extra,
  ],
};

Future<void> _respond(
  HttpRequest request,
  List<int> bytes, {
  int? length,
}) async {
  if (length != null) request.response.contentLength = length;
  request.response.add(bytes);
  try {
    await request.response.close();
  } on HttpException {
    /* Truncation fixture. */
  }
}

void main() {
  group('Windows release distribution contracts', () {
    for (final package in _windowsPackages.entries) {
      final name = package.key;
      final kind = package.value;
      final url = _url.resolve(name);

      test(
        '$kind fetches and verifies only the exact package through CDN',
        () async {
          final cdn = Uri.parse(
            'https://release-assets.githubusercontent.com/assets/$name?signature=fixture',
          );
          final fixture = await _Fixture.start((request) async {
            if (request.uri.path.endsWith('/latest')) {
              return _respond(
                request,
                utf8.encode(jsonEncode(_release(name: name))),
              );
            }
            if (request.headers.host == 'github.com') {
              request.response.statusCode = 302;
              request.response.headers.set(HttpHeaders.locationHeader, cdn);
              return request.response.close();
            }
            await _respond(request, _payload, length: _payload.length);
          });
          final client = fixture.client();
          final manifest = await client.fetchManifest(_api);
          final asset = manifest.assets.single;
          expect(asset.kind, kind);
          expect(asset.platform, UpdateAssetPlatform.windows);
          expect(asset.arch, 'x64');
          expect(asset.url, url);
          expect(asset.fileName, name);
          expect(asset.sha256, sha256.convert(_payload).toString());
          final result = await client.downloadAsset(asset);
          expect(await result.file.readAsBytes(), _payload);
          expect(result.file.uri.pathSegments.last, name);
          expect(fixture.uris, [_api, url, cdn]);
        },
      );

      test('$kind fallback checksums are exact-name and mandatory', () async {
        var matching = true;
        final sumsUrl = _url.resolve('SHA256SUMS.txt');
        final fixture = await _Fixture.start((request) async {
          final checksumName = matching ? name : 'unrelated-installer.exe';
          final sums = utf8.encode(
            '${sha256.convert(_payload)}  $checksumName\n',
          );
          if (request.uri.path.endsWith('SHA256SUMS.txt')) {
            return _respond(request, sums);
          }
          await _respond(
            request,
            utf8.encode(
              jsonEncode(
                _release(
                  name: name,
                  digest: false,
                  extra: [
                    {
                      'name': 'SHA256SUMS.txt',
                      'state': 'uploaded',
                      'size': sums.length,
                      'digest': 'sha256:${sha256.convert(sums)}',
                      'browser_download_url': sumsUrl.toString(),
                    },
                  ],
                ),
              ),
            ),
          );
        });
        final asset = (await fixture.client().fetchManifest(
          _api,
        )).assets.single;
        expect(asset.kind, kind);
        expect(asset.sha256, sha256.convert(_payload).toString());
        expect(fixture.uris, [_api, sumsUrl]);
        matching = false;
        await expectLater(
          fixture.client().fetchManifest(_api),
          throwsA(isA<UpdateClientException>()),
        );
        expect(fixture.uris, [_api, sumsUrl, _api, sumsUrl]);
      });

      test(
        '$kind rejects mismatched identity before filesystem or HTTP',
        () async {
          var calls = 0;
          final client = UpdateClient(
            httpClientFactory: () {
              calls++;
              throw StateError('HTTP must not start');
            },
            temporaryDirectoryProvider: () async {
              calls++;
              throw StateError('disk must not be accessed');
            },
          );
          for (final asset in [
            for (final wrongKind in UpdateAssetKind.values.where(
              (value) => value != kind,
            ))
              _asset(name: name, kind: wrongKind),
            _asset(name: name, kind: kind, arch: 'arm64'),
            _asset(
              name: name,
              kind: kind,
              platform: UpdateAssetPlatform.android,
            ),
            _asset(name: name, kind: kind, hash: ''),
            _asset(name: name, kind: kind, hash: 'z' * 64),
            _asset(name: name, kind: kind, size: 0),
            _asset(name: name, kind: kind, size: 3 * 1024 * 1024 * 1024),
            _asset(
              name: name,
              kind: kind,
              url: url.replace(query: 'asset=other'),
            ),
            _asset(
              name: name,
              kind: kind,
              url: url.replace(fragment: 'other'),
            ),
            _asset(
              name: name,
              kind: kind,
              url: url.replace(host: 'other.test'),
            ),
            _asset(
              name: name,
              kind: kind,
              url: url.replace(path: url.path.replaceFirst('v0.0.6', 'v0.0.7')),
            ),
            _asset(name: name, kind: kind, url: _url.resolve('other.exe')),
          ]) {
            await expectLater(
              client.downloadAsset(asset),
              throwsA(isA<UpdateClientException>()),
            );
          }
          expect(calls, 0);
        },
      );

      test(
        '$kind rejects every disallowed redirect before following it',
        () async {
          var location = '';
          final fixture = await _Fixture.start((request) async {
            request.response.statusCode = 302;
            request.response.headers.set(HttpHeaders.locationHeader, location);
            await request.response.close();
          });
          for (final target in [
            'https://outside.test/$name',
            'https://release-assets.githubusercontent.com.evil.test/$name',
            'https://u:p@objects.githubusercontent.com/$name',
            'http://objects.githubusercontent.com/$name',
            'https://objects.githubusercontent.com:8443/$name',
            'https://objects.githubusercontent.com/$name#fragment',
            _url.resolve('other.exe').toString(),
          ]) {
            location = target;
            final before = fixture.uris.length;
            await expectLater(
              fixture.client().downloadAsset(_asset(name: name, kind: kind)),
              throwsA(isA<UpdateClientException>()),
            );
            expect(fixture.uris.length, before + 1);
            expect(fixture.uris.last, url);
            expect(await fixture.stagingEntries(), isEmpty);
          }
        },
      );

      test(
        '$kind rejects short, oversized and altered bytes without ready file',
        () async {
          List<int> payload = _payload;
          final fixture = await _Fixture.start(
            (request) => _respond(request, payload),
          );
          for (final bytes in [
            _payload.sublist(1),
            [..._payload, 1],
            List<int>.filled(_payload.length, 0),
          ]) {
            payload = bytes;
            await expectLater(
              fixture.client().downloadAsset(_asset(name: name, kind: kind)),
              throwsA(isA<UpdateClientException>()),
            );
            expect(await fixture.stagingEntries(), isEmpty);
          }
        },
      );
    }

    test(
      'an unrelated supported package without a checksum fails the release closed',
      () async {
        const android = 'Slovofon-v0.0.6-android-universal-release.apk';
        var missingName = android;
        final fixture = await _Fixture.start(
          (request) => _respond(
            request,
            utf8.encode(
              jsonEncode(
                _release(
                  extra: [
                    {
                      'name': missingName,
                      'state': 'uploaded',
                      'size': _payload.length,
                      'browser_download_url': _url
                          .resolve(missingName)
                          .toString(),
                    },
                  ],
                ),
              ),
            ),
          ),
        );
        for (final name in [
          android,
          ..._windowsPackages.keys.where((name) => name != _name),
        ]) {
          missingName = name;
          await expectLater(
            fixture.client().fetchManifest(_api),
            throwsA(isA<UpdateClientException>()),
          );
        }
        expect(fixture.uris, everyElement(_api));
      },
    );

    test('MSIX and arbitrary package names remain non-downloadable', () async {
      var calls = 0;
      final client = UpdateClient(
        httpClientFactory: () {
          calls++;
          throw StateError('HTTP must not start');
        },
        temporaryDirectoryProvider: () async {
          calls++;
          throw StateError('disk must not be accessed');
        },
      );
      for (final entry in {
        'Slovofon-v0.0.6-windows-x64-msix.msix': UpdateAssetKind.msix,
        'Slovofon-v0.0.6-windows-x64-setup.msi': UpdateAssetKind.msi,
        'Slovofon-v0.0.6-windows-x64-msi.exe': UpdateAssetKind.msi,
        'Slovofon-v0.0.6-windows-x64-portable.exe': UpdateAssetKind.portable,
        'installer.msi': UpdateAssetKind.msi,
        'portable.zip': UpdateAssetKind.portable,
      }.entries) {
        await expectLater(
          client.downloadAsset(_asset(name: entry.key, kind: entry.value)),
          throwsA(isA<UpdateClientException>()),
        );
      }
      expect(calls, 0);
    });
  });

  test(
    'transparent gzip preserves decoded asset and SHA256SUMS size/hash checks',
    () async {
      final sums = utf8.encode('${sha256.convert(_payload)}  $_name\n');
      final fixture = await _Fixture.start((request) async {
        if (request.uri.path.endsWith('/latest')) {
          return _respond(
            request,
            utf8.encode(
              jsonEncode(
                _release(
                  digest: false,
                  extra: [
                    {
                      'name': 'SHA256SUMS.txt',
                      'state': 'uploaded',
                      'size': sums.length,
                      'digest': 'sha256:${sha256.convert(sums)}',
                      'browser_download_url': _url
                          .resolve('SHA256SUMS.txt')
                          .toString(),
                    },
                  ],
                ),
              ),
            ),
          );
        }
        final bytes = request.uri.path.endsWith('SHA256SUMS.txt')
            ? sums
            : _payload;
        final encoded = gzip.encode(bytes);
        request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
        await _respond(request, encoded, length: encoded.length);
      });
      final client = fixture.client();
      final manifest = await client.fetchManifest(_api);
      final result = await client.downloadAsset(manifest.assets.single);
      expect(await result.file.readAsBytes(), _payload);
    },
  );

  test(
    'GitHub API digest maps installers without fetching SHA256SUMS and closes client',
    () async {
      final fixture = await _Fixture.start(
        (request) => _respond(request, utf8.encode(jsonEncode(_release()))),
      );
      final manifest = await fixture.client().fetchManifest(_api);
      expect(manifest.version, '0.0.6');
      expect(
        manifest.assets.single.sha256,
        sha256.convert(_payload).toString(),
      );
      expect(manifest.build, isNull);
      expect(fixture.uris, [_api]);
      expect(
        fixture.requests.single.headers.value(HttpHeaders.userAgentHeader),
        'Slovofon-Updater',
      );
      expect(
        fixture.requests.single.headers.value(HttpHeaders.acceptHeader),
        'application/vnd.github+json',
      );
      expect(
        fixture.requests.single.headers.value('X-GitHub-Api-Version'),
        '2022-11-28',
      );
      expect(fixture.clients.every((client) => client.closed), isTrue);
    },
  );

  test('latest API404 is no_release; 403/429/500 remain errors', () async {
    var status = 404;
    final fixture = await _Fixture.start((request) async {
      request.response.statusCode = status;
      await request.response.close();
    });
    expect((await fixture.client().fetchManifest(_api)).status, 'no_release');
    for (final code in [403, 429, 500]) {
      status = code;
      await expectLater(
        fixture.client().fetchManifest(_api),
        throwsA(isA<UpdateClientException>()),
      );
    }
  });

  test(
    'rejects noncanonical initial endpoints before creating HTTP client',
    () async {
      var calls = 0;
      final client = UpdateClient(
        httpClientFactory: () {
          calls++;
          throw StateError('network must not start');
        },
      );
      for (final text in [
        'http://api.github.com/repos/Dushnyj/Slovofon/releases/latest',
        'https://api.github.com/repos/other/Slovofon/releases/latest',
        'https://api.github.com/repos/Dushnyj/Slovofon/releases/latest?x=1',
        'https://u:p@api.github.com/repos/Dushnyj/Slovofon/releases/latest',
        'https://api.github.com.evil.test/repos/Dushnyj/Slovofon/releases/latest',
        'https://slovofon-updates.duckdns.org/stable.json',
        'http://127.0.0.1/latest',
      ]) {
        await expectLater(
          client.fetchManifest(Uri.parse(text)),
          throwsA(isA<UpdateClientException>()),
        );
      }
      expect(calls, 0);
    },
  );

  test(
    'missing API digest uses bounded same-release SHA256SUMS with its own digest',
    () async {
      final sums = utf8.encode('${sha256.convert(_payload)}  $_name\n');
      final sumsUrl = _url.resolve('SHA256SUMS.txt');
      final fixture = await _Fixture.start((request) async {
        if (request.uri.path.endsWith('SHA256SUMS.txt')) {
          return _respond(request, sums);
        }
        await _respond(
          request,
          utf8.encode(
            jsonEncode(
              _release(
                digest: false,
                extra: [
                  {
                    'name': 'SHA256SUMS.txt',
                    'browser_download_url': sumsUrl.toString(),
                    'size': sums.length,
                    'state': 'uploaded',
                    'digest': 'sha256:${sha256.convert(sums)}',
                  },
                ],
              ),
            ),
          ),
        );
      });
      final manifest = await fixture.client().fetchManifest(_api);
      expect(
        manifest.assets.single.sha256,
        sha256.convert(_payload).toString(),
      );
      expect(fixture.uris, [_api, sumsUrl]);
    },
  );

  test(
    'missing checksum, malformed API digest and checksum404 fail closed',
    () async {
      var mode = 'missing';
      final fixture = await _Fixture.start((request) async {
        if (request.uri.path.endsWith('SHA256SUMS.txt')) {
          request.response.statusCode = 404;
          return request.response.close();
        }
        final json = _release(digest: false);
        final assets = json['assets']! as List;
        if (mode == 'malformed') {
          (assets.single as Map)['digest'] = 'sha512:invalid';
        }
        if (mode == '404') {
          assets.add({
            'name': 'SHA256SUMS.txt',
            'state': 'uploaded',
            'size': 128,
            'browser_download_url': _url.resolve('SHA256SUMS.txt').toString(),
          });
        }
        await _respond(request, utf8.encode(jsonEncode(json)));
      });
      for (final value in ['missing', 'malformed', '404']) {
        mode = value;
        await expectLater(
          fixture.client().fetchManifest(_api),
          throwsA(isA<UpdateClientException>()),
        );
      }
      expect(fixture.uris.where((uri) => uri == _url), isEmpty);
    },
  );

  test(
    'metadata and checksum responses obey declared and streamed resource caps',
    () async {
      final fixture = await _Fixture.start(
        (request) => _respond(request, List.filled(100, 65)),
      );
      await expectLater(
        fixture.client(maxMetadataBytes: 32).fetchManifest(_api),
        throwsA(isA<UpdateClientException>()),
      );
      expect(fixture.clients.single.closed, isTrue);
    },
  );

  test(
    'valid CDN download is size/hash verified, progress bounded, own temp path',
    () async {
      final cdn = Uri.parse(
        'https://release-assets.githubusercontent.com/assets/fixture?signature=fixture',
      );
      final fixture = await _Fixture.start((request) async {
        if (request.headers.host == 'github.com') {
          request.response.statusCode = 302;
          request.response.headers.set(HttpHeaders.locationHeader, cdn);
          return request.response.close();
        }
        await _respond(request, _payload);
      });
      final progress = <(int, int?)>[];
      final result = await fixture.client().downloadAsset(
        _asset(),
        onProgress: (a, b) => progress.add((a, b)),
      );
      expect(await result.file.readAsBytes(), _payload);
      expect(result.file.uri.pathSegments.last, _name);
      expect(result.file.path, contains('slovofon-updates'));
      expect(result.file.parent.path, contains('update-'));
      expect(fixture.uris, [_url, cdn]);
      expect(progress.first, (0, _payload.length));
      expect(progress.last, (_payload.length, _payload.length));
      expect(progress.every((p) => p.$1 <= p.$2!), isTrue);
      expect(await File('${result.file.path}.part').exists(), isFalse);
      expect(fixture.clients.every((client) => client.closed), isTrue);
    },
  );

  test(
    'every redirect rejects external/credential/scheme/port/repository escape before request',
    () async {
      var next = '';
      final fixture = await _Fixture.start((request) async {
        request.response.statusCode = 302;
        request.response.headers.set(HttpHeaders.locationHeader, next);
        await request.response.close();
      });
      for (final target in [
        'https://evil.test/payload',
        'https://release-assets.githubusercontent.com.evil.test/payload',
        'https://u:p@release-assets.githubusercontent.com/payload',
        'http://release-assets.githubusercontent.com/payload',
        'https://release-assets.githubusercontent.com:8443/payload',
        'file:///fixture',
        'https://github.com/other/Slovofon/releases/download/v0.0.6/$_name',
        'https://github.com/Dushnyj/Slovofon/releases/download/v0.0.7/$_name',
      ]) {
        next = target;
        final count = fixture.uris.length;
        await expectLater(
          fixture.client().downloadAsset(_asset()),
          throwsA(isA<UpdateClientException>()),
        );
        expect(fixture.uris.length, count + 1);
      }
      expect(await fixture.stagingEntries(), isEmpty);
    },
  );

  test(
    'CDN to external redirect is rejected at the second hop; loops capped at five',
    () async {
      var loop = false;
      final fixture = await _Fixture.start((request) async {
        request.response.statusCode = 302;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          loop
              ? _url.toString()
              : request.headers.host == 'github.com'
              ? 'https://objects.githubusercontent.com/fixture'
              : 'https://outside.test/fixture',
        );
        await request.response.close();
      });
      await expectLater(
        fixture.client().downloadAsset(_asset()),
        throwsA(isA<UpdateClientException>()),
      );
      expect(fixture.uris.length, 2);
      loop = true;
      await expectLater(
        fixture.client().downloadAsset(_asset()),
        throwsA(isA<UpdateClientException>()),
      );
      expect(fixture.uris.length, 8);
    },
  );

  test(
    'public downloadAsset validates filename, binding, hash and size before disk/network',
    () async {
      var calls = 0;
      final client = UpdateClient(
        httpClientFactory: () {
          calls++;
          throw StateError('network');
        },
        temporaryDirectoryProvider: () async {
          calls++;
          throw StateError('disk');
        },
      );
      for (final asset in [
        _asset(name: '../$_name'),
        _asset(name: r'..\fixture.exe'),
        _asset(url: Uri.parse('https://outside.test/$_name')),
        _asset(url: _url.replace(query: 'url=evil')),
        _asset(
          url: _url.replace(path: _url.path.replaceAll('v0.0.6', 'v0.0.7')),
        ),
        _asset(hash: ''),
        _asset(size: 0),
        _asset(size: 3 * 1024 * 1024 * 1024),
      ]) {
        await expectLater(
          client.downloadAsset(asset),
          throwsA(isA<UpdateClientException>()),
        );
      }
      expect(calls, 0);
    },
  );

  test(
    'size/hash/callback failures remove only own partial and keep other files',
    () async {
      List<int> body = _payload;
      final fixture = await _Fixture.start(
        (request) => _respond(request, body),
      );
      final root = Directory(
        '${fixture.temp.path}${Platform.pathSeparator}slovofon-updates',
      );
      await root.create();
      final sentinel = await File(
        '${root.path}${Platform.pathSeparator}other-download.part',
      ).writeAsString('keep');
      for (final value in [
        _payload.sublist(1),
        [..._payload, 99],
        List.filled(_payload.length, 88),
      ]) {
        body = value;
        await expectLater(
          fixture.client().downloadAsset(_asset()),
          throwsA(isA<UpdateClientException>()),
        );
        expect(await fixture.stagingEntries(), [sentinel.path]);
      }
      body = _payload;
      await expectLater(
        fixture.client().downloadAsset(
          _asset(),
          onProgress: (_, _) => throw StateError('UI callback'),
        ),
        throwsStateError,
      );
      expect(await sentinel.readAsString(), 'keep');
      expect(await fixture.stagingEntries(), [sentinel.path]);
    },
  );

  test(
    'parallel downloads of the same asset never share or replace files',
    () async {
      final fixture = await _Fixture.start(
        (request) => _respond(request, _payload),
      );
      final client = fixture.client();
      final results = await Future.wait([
        client.downloadAsset(_asset()),
        client.downloadAsset(_asset()),
      ]);
      expect(results[0].file.path, isNot(results[1].file.path));
      for (final result in results) {
        expect(await result.file.readAsBytes(), _payload);
      }
    },
  );

  test(
    'idle and total trickle timeouts cancel response and clean own staging',
    () async {
      var trickle = false;
      final fixture = await _Fixture.start((request) async {
        try {
          for (var i = 0; i < _payload.length; i++) {
            request.response.add([_payload[i]]);
            await request.response.flush();
            await Future<void>.delayed(
              Duration(milliseconds: trickle ? 15 : 200),
            );
          }
          await request.response.close();
        } on Object {
          /* Client cancellation intentionally breaks local stream. */
        }
      });
      await expectLater(
        fixture
            .client(idleTimeout: const Duration(milliseconds: 60))
            .downloadAsset(_asset()),
        throwsA(isA<TimeoutException>()),
      );
      expect(await fixture.stagingEntries(), isEmpty);
      trickle = true;
      await expectLater(
        fixture
            .client(
              idleTimeout: const Duration(milliseconds: 100),
              downloadTimeout: const Duration(milliseconds: 120),
            )
            .downloadAsset(_asset()),
        throwsA(isA<TimeoutException>()),
      );
      expect(await fixture.stagingEntries(), isEmpty);
      expect(fixture.clients.every((client) => client.closed), isTrue);
    },
  );

  test(
    'header timeout closes connection and metadata redirects cannot choose another endpoint',
    () async {
      var redirect = false;
      final fixture = await _Fixture.start((request) async {
        if (redirect) {
          request.response.statusCode = 302;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            'https://api.github.com/repos/other/repo/releases/latest',
          );
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        try {
          await request.response.close();
        } on Object {
          /* Request timed out. */
        }
      });
      await expectLater(
        fixture
            .client(requestTimeout: const Duration(milliseconds: 50))
            .fetchManifest(_api),
        throwsA(isA<TimeoutException>()),
      );
      redirect = true;
      await expectLater(
        fixture.client().fetchManifest(_api),
        throwsA(isA<UpdateClientException>()),
      );
      expect(fixture.uris, [_api, _api]);
    },
  );
}

class _Fixture {
  _Fixture(this.server, this.temp);
  final HttpServer server;
  final Directory temp;
  final uris = <Uri>[];
  final requests = <HttpRequest>[];
  final clients = <_LoopbackClient>[];

  static Future<_Fixture> start(
    Future<void> Function(HttpRequest) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final temp = await Directory.systemTemp.createTemp('slovofon-update-test-');
    final fixture = _Fixture(server, temp);
    server.listen((request) async {
      fixture.requests.add(request);
      await handler(request);
    });
    addTearDown(() async {
      await server.close(force: true);
      final base =
          Directory.systemTemp.absolute.path.toLowerCase() +
          Platform.pathSeparator;
      if (!temp.absolute.path.toLowerCase().startsWith(base)) {
        throw StateError('Not own temp directory');
      }
      await temp.delete(recursive: true);
    });
    return fixture;
  }

  UpdateClient client({
    int maxMetadataBytes = 2 * 1024 * 1024,
    Duration requestTimeout = const Duration(seconds: 2),
    Duration idleTimeout = const Duration(seconds: 2),
    Duration downloadTimeout = const Duration(seconds: 10),
  }) => UpdateClient(
    httpClientFactory: () {
      final client = _LoopbackClient(server.port, uris);
      clients.add(client);
      return client;
    },
    temporaryDirectoryProvider: () async => temp,
    maxMetadataBytes: maxMetadataBytes,
    requestTimeout: requestTimeout,
    idleTimeout: idleTimeout,
    downloadTimeout: downloadTimeout,
  );

  Future<List<String>> stagingEntries() async {
    final root = Directory(
      '${temp.path}${Platform.pathSeparator}slovofon-updates',
    );
    if (!await root.exists()) return [];
    return root.list().map((entry) => entry.path).toList();
  }
}

// Logical HTTPS URIs exercise production guards; this fake alone maps approved
// requests to an HTTP loopback fixture. It does not resolve external hosts.
class _LoopbackClient implements HttpClient {
  _LoopbackClient(this.port, this.uris) {
    delegate.findProxy = (_) => 'DIRECT';
  }
  final int port;
  final List<Uri> uris;
  final delegate = HttpClient();
  bool closed = false;

  @override
  Future<HttpClientRequest> getUrl(Uri uri) async {
    uris.add(uri);
    final request = await delegate.getUrl(
      Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: port,
        path: uri.path,
        query: uri.hasQuery ? uri.query : null,
      ),
    );
    request.headers.host = uri.host;
    return request;
  }

  @override
  void close({bool force = false}) {
    closed = true;
    delegate.close(force: force);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
