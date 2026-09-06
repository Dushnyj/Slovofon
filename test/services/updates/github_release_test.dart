import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/updates/github_release.dart';
import 'package:slovofon/services/updates/update_manifest.dart';

const _version = '0.0.6';
const _tag = 'v$_version';
const _repository = 'https://github.com/Dushnyj/Slovofon';
const _downloadBase = '$_repository/releases/download/$_tag';
const _androidName = 'Slovofon-$_tag-android-universal-release.apk';
const _windowsName = 'Slovofon-$_tag-windows-x64-setup.exe';
const _msiName = 'Slovofon-$_tag-windows-x64-msi.msi';
const _portableName = 'Slovofon-$_tag-windows-x64-portable.zip';
const _windowsPackages = {
  _windowsName: UpdateAssetKind.installer,
  _msiName: UpdateAssetKind.msi,
  _portableName: UpdateAssetKind.portable,
};
final _androidHash = 'ab' * 32;
final _windowsHash = 'cd' * 32;

void main() {
  group('GitHubRelease normalization', () {
    test('normalized manifest availability does not require an installer', () {
      expect(
        UpdateManifest.fromJson({
          'status': 'available',
          'version': _version,
          'assets': <Object?>[],
        }).isAvailable,
        isTrue,
      );
      expect(
        UpdateManifest.fromJson({'status': 'available'}).isAvailable,
        isFalse,
      );
      expect(
        UpdateManifest.fromJson({
          'status': 'no_release',
          'version': _version,
        }).isAvailable,
        isFalse,
      );
    });

    test('normalizes both supported installers without inventing a build', () {
      final release = GitHubRelease.fromJson(_release());
      final manifest = release.toManifest();

      expect(
        GitHubRelease.latestApiUrl,
        'https://api.github.com/repos/Dushnyj/Slovofon/releases/latest',
      );
      expect(release.version, _version);
      expect(release.tag, _tag);
      expect(release.needsChecksums, isFalse);
      expect(manifest.schema, 1);
      expect(manifest.app, 'slovofon');
      expect(manifest.channel, 'stable');
      expect(manifest.status, 'available');
      expect(manifest.isAvailable, isTrue);
      expect(manifest.version, _version);
      expect(manifest.build, isNull);
      expect(manifest.mandatory, isFalse);
      expect(manifest.publishedAt, DateTime.utc(2026, 9, 5, 12));
      expect(manifest.releaseNotes, 'Fixture release notes');
      expect(manifest.releaseUrl, '$_repository/releases/tag/$_tag');
      expect(manifest.assets, hasLength(2));

      final android = manifest.assets[0];
      expect(android.platform, UpdateAssetPlatform.android);
      expect(android.arch, 'universal');
      expect(android.kind, UpdateAssetKind.apk);
      expect(android.url.toString(), '$_downloadBase/$_androidName');
      expect(android.fileName, _androidName);
      expect(android.sha256, _androidHash);
      expect(android.hasValidChecksum, isTrue);
      expect(android.size, 1234);

      final windows = manifest.assets[1];
      expect(windows.platform, UpdateAssetPlatform.windows);
      expect(windows.arch, 'x64');
      expect(windows.kind, UpdateAssetKind.installer);
      expect(windows.url.toString(), '$_downloadBase/$_windowsName');
      expect(windows.fileName, _windowsName);
      expect(windows.sha256, _windowsHash);
      expect(windows.size, 5678);
      expect(() => release.assets.clear(), throwsUnsupportedError);
      expect(() => manifest.assets.clear(), throwsUnsupportedError);
    });

    test('normalizes exact Windows distribution kinds without fallback', () {
      final release = GitHubRelease.fromJson(
        _release(
          assets: [
            for (final name in _windowsPackages.keys)
              _asset(name: name, digest: 'sha256:$_windowsHash', size: 5678),
          ],
        ),
      );
      final manifest = release.toManifest();
      expect(manifest.assets, hasLength(3));
      expect(release.needsChecksums, isFalse);
      for (final asset in manifest.assets) {
        expect(asset.platform, UpdateAssetPlatform.windows);
        expect(asset.arch, 'x64');
        expect(asset.kind, _windowsPackages[asset.fileName]);
        expect(asset.url.toString(), '$_downloadBase/${asset.fileName}');
        expect(asset.sha256, _windowsHash);
        expect(asset.size, 5678);
      }
    });

    test('in-memory manifest preserves the MSI package kind', () {
      final asset = UpdateAsset.fromJson({
        'platform': 'windows',
        'arch': 'x64',
        'kind': 'msi',
        'url': '$_downloadBase/$_msiName',
        'file_name': _msiName,
        'sha256': _windowsHash,
        'size': 5678,
      });
      expect(asset.kind, UpdateAssetKind.msi);
      expect(asset.platform, UpdateAssetPlatform.windows);
      expect(asset.arch, 'x64');
      expect(asset.hasValidChecksum, isTrue);
    });

    test(
      'keeps a stable release available when no installers are supported',
      () {
        final release = GitHubRelease.fromJson(
          _release(
            assets: [
              _asset(name: 'Slovofon-$_tag-windows-arm64-portable.zip'),
              _asset(name: 'Slovofon-$_tag-windows-x64-msix.msix'),
              _asset(name: 'Slovofon-$_tag-android-arm64-v8a-release.apk'),
              _asset(name: 'Slovofon-$_tag-android-tv-universal-release.apk'),
              _asset(name: 'Slovofon-$_tag-android-release.aab'),
              _asset(name: 'README.txt'),
            ],
          ),
        );
        final manifest = release.toManifest();
        expect(release.needsChecksums, isFalse);
        expect(manifest.isAvailable, isTrue);
        expect(manifest.version, _version);
        expect(manifest.assets, isEmpty);
      },
    );

    test('an empty assets list still identifies an existing release', () {
      final manifest = GitHubRelease.fromJson(
        _release(assets: []),
      ).toManifest();
      expect(manifest.isAvailable, isTrue);
      expect(manifest.assets, isEmpty);
    });

    test('nullable release date and notes remain nullable', () {
      final manifest = GitHubRelease.fromJson(
        _release()
          ..['published_at'] = null
          ..['body'] = null,
      ).toManifest();
      expect(manifest.publishedAt, isNull);
      expect(manifest.releaseNotes, isNull);
    });

    for (final entry in <String, Object?>{
      'invalid date': 'not-a-date',
      'numeric date': 123,
    }.entries) {
      test('rejects ${entry.key}', () {
        expect(
          () => GitHubRelease.fromJson(
            _release()..['published_at'] = entry.value,
          ),
          throwsFormatException,
        );
      });
    }
    test('rejects non-string release notes', () {
      expect(
        () => GitHubRelease.fromJson(_release()..['body'] = []),
        throwsFormatException,
      );
    });
  });

  group('stable version and release identity', () {
    for (final field in ['draft', 'prerelease']) {
      for (final value in <Object?>[true, null, 'false', 0]) {
        test('rejects $field=$value without an explicit false boolean', () {
          expect(
            () => GitHubRelease.fromJson(_release()..[field] = value),
            throwsFormatException,
          );
        });
      }
    }
    for (final tag in <Object?>[
      null,
      6,
      '',
      '0.0.6',
      'V0.0.6',
      'v0.0',
      'v0.0.6.1',
      'v0.0.6-beta.1',
      'v0.0.6+6',
      'v00.0.6',
      'v0.00.6',
      'v0.0.06',
      'v-1.0.0',
      'v1000000000.0.6',
      'v0.999999999999999999999999.6',
      'v0.0.999999999999999999999999',
      'v0.0.6\n',
      ' v0.0.6',
    ]) {
      test('rejects malformed or unsupported stable tag ${tag.toString()}', () {
        final json = _release()
          ..['tag_name'] = tag
          ..['html_url'] = '$_repository/releases/tag/$tag';
        expect(() => GitHubRelease.fromJson(json), throwsFormatException);
      });
    }
    for (final url in <Object?>[
      null,
      6,
      'https://github.com/Other/Slovofon/releases/tag/$_tag',
      'https://github.com/Dushnyj/Other/releases/tag/$_tag',
      '$_repository/releases/tag/v0.0.7',
      '$_repository/releases/tag/$_tag?download=1',
      '$_repository/releases/tag/$_tag#notes',
      'http://github.com/Dushnyj/Slovofon/releases/tag/$_tag',
    ]) {
      test('rejects an unbound release html_url $url', () {
        expect(
          () => GitHubRelease.fromJson(_release()..['html_url'] = url),
          throwsFormatException,
        );
      });
    }
  });

  group('asset identity and validation', () {
    test(
      'installer identity helper accepts only supported canonical names',
      () {
        final android = GitHubRelease.installerIdentity(_androidName)!;
        expect(android.version, _version);
        expect(android.platform, UpdateAssetPlatform.android);
        expect(android.arch, 'universal');
        expect(android.kind, UpdateAssetKind.apk);
        for (final entry in _windowsPackages.entries) {
          final windows = GitHubRelease.installerIdentity(entry.key)!;
          expect(windows.version, _version);
          expect(windows.platform, UpdateAssetPlatform.windows);
          expect(windows.arch, 'x64');
          expect(windows.kind, entry.value);
        }
        for (final name in [
          'Slovofon-v00.0.6-android-universal-release.apk',
          'Slovofon-v0.0.1000000000-windows-x64-setup.exe',
          'Slovofon-v0.0.6-android-arm64-v8a-release.apk',
          'Slovofon-v0.0.6-windows-arm64-portable.zip',
          'Slovofon-v0.0.6-windows-x64-msix.msix',
          'Slovofon-v0.0.6-windows-x64-setup.msi',
          'Slovofon-v0.0.6-windows-x64-msi.exe',
          'Slovofon-v0.0.6-windows-x64-portable.exe',
          'Slovofon-v0.0.6-windows-x64-msi.msi.exe',
          'Slovofon-v0.0.6-windows-x64-portable.zip.exe',
          'Slovofon-v0.0.6-windows-x64-setup.exe.apk',
          'slovofon-v0.0.6-windows-x64-setup.exe',
          '../$_androidName',
        ]) {
          expect(GitHubRelease.installerIdentity(name), isNull, reason: name);
        }
      },
    );

    test(
      'URL helper validates installer and checksum against supplied version',
      () {
        for (final name in [
          _androidName,
          ..._windowsPackages.keys,
          'SHA256SUMS.txt',
        ]) {
          expect(
            () => GitHubRelease.validateAssetUrl(
              Uri.parse('$_downloadBase/$name'),
              name: name,
              version: _version,
            ),
            returnsNormally,
          );
          expect(
            () => GitHubRelease.validateAssetUrl(
              Uri.parse('$_downloadBase/$name'),
              name: name,
              version: '0.0.7',
            ),
            throwsFormatException,
          );
        }
      },
    );

    for (final name in [_msiName, _portableName]) {
      test('strict metadata identity, URL, size and hash for $name', () {
        for (final url in [
          '$_repository/releases/download/v0.0.7/$name',
          'https://github.com/other/Slovofon/releases/download/$_tag/$name',
          '$_downloadBase/$_windowsName',
          '$_downloadBase/$name?download=1',
          '$_downloadBase/$name#fragment',
          '$_downloadBase/unused/../$name',
          '$_downloadBase/${name.replaceFirst('-', '%2D')}',
          'https://release-assets.githubusercontent.com/$name',
        ]) {
          expect(
            () => GitHubRelease.fromJson(
              _release(
                assets: [_asset(name: name)..['browser_download_url'] = url],
              ),
            ),
            throwsFormatException,
            reason: url,
          );
        }
        for (final fields in <Map<String, Object?>>[
          {'name': name.replaceFirst(_version, '0.0.7')},
          {'size': 0},
          {'size': -1},
          {'size': 1234.0},
          {'size': '1234'},
          {'state': 'new'},
          {'digest': 'sha256:${'g' * 64}'},
          {'digest': 'sha512:$_windowsHash'},
        ]) {
          expect(
            () => GitHubRelease.fromJson(
              _release(assets: [_asset(name: name)..addAll(fields)]),
            ),
            throwsFormatException,
            reason: fields.toString(),
          );
        }
      });
    }

    for (final url in <Object?>[
      null,
      6,
      'https://github.com/Other/Slovofon/releases/download/$_tag/$_androidName',
      'https://github.com/Dushnyj/Other/releases/download/$_tag/$_androidName',
      '$_repository/releases/download/v0.0.7/$_androidName',
      '$_downloadBase/$_windowsName',
      '$_downloadBase/../$_androidName',
      '$_downloadBase/%2e%2e/$_androidName',
      '$_downloadBase/unused/../$_androidName',
      '$_downloadBase/unused/%2e%2e/$_androidName',
      '$_downloadBase/./$_androidName',
      '$_downloadBase/Slovofon%2Dv0.0.6-android-universal-release.apk',
      '$_downloadBase/sub%2f$_androidName',
      '$_downloadBase/sub%5c$_androidName',
      'https://user:password@github.com/Dushnyj/Slovofon/releases/download/$_tag/$_androidName',
      'http://github.com/Dushnyj/Slovofon/releases/download/$_tag/$_androidName',
      'https://github.com:8443/Dushnyj/Slovofon/releases/download/$_tag/$_androidName',
      'https://github.com.evil.test/Dushnyj/Slovofon/releases/download/$_tag/$_androidName',
      'https://release-assets.githubusercontent.com/$_androidName',
      '$_downloadBase/$_androidName?download=1',
      '$_downloadBase/$_androidName#fragment',
    ]) {
      test('rejects an unbound installer URL $url', () {
        expect(
          () => GitHubRelease.fromJson(
            _release(assets: [_asset()..['browser_download_url'] = url]),
          ),
          throwsFormatException,
        );
      });
    }
    for (final name in [
      '../$_androidName',
      '..\\$_androidName',
      '/$_androidName',
      'C:\\$_androidName',
      'sub/$_androidName',
      'sub\\$_androidName',
      'sub%2f$_androidName',
      'sub%5c$_androidName',
      'Slovofon..apk',
      'Slovofon.apk:payload.exe',
      'Slovofon.apk\n',
    ]) {
      test('rejects unsafe filename $name even for an unsupported asset', () {
        expect(
          () => GitHubRelease.fromJson(_release(assets: [_asset(name: name)])),
          throwsFormatException,
        );
      });
    }
    test('rejects a supported installer named for a different version', () {
      expect(
        () => GitHubRelease.fromJson(
          _release(
            assets: [
              _asset(name: 'Slovofon-v0.0.7-android-universal-release.apk'),
            ],
          ),
        ),
        throwsFormatException,
      );
    });
    for (final state in <Object?>[null, 'new', 'open', 'starter', true]) {
      test('rejects non-uploaded supported asset state $state', () {
        expect(
          () => GitHubRelease.fromJson(
            _release(assets: [_asset()..['state'] = state]),
          ),
          throwsFormatException,
        );
      });
    }
    for (final size in <Object?>[null, 0, -1, 1.5, 1234.0, '1234', true]) {
      test(
        'rejects non-positive or non-integer size $size (${size.runtimeType})',
        () {
          expect(
            () => GitHubRelease.fromJson(
              _release(assets: [_asset()..['size'] = size]),
            ),
            throwsFormatException,
          );
        },
      );
    }
    for (final assets in <Object?>[
      null,
      {},
      'assets',
      [null],
      [6],
      [{}],
    ]) {
      test('rejects malformed asset container $assets', () {
        expect(
          () => GitHubRelease.fromJson(_release()..['assets'] = assets),
          throwsFormatException,
        );
      });
    }
    test('rejects more than 100 assets before processing them', () {
      expect(
        () => GitHubRelease.fromJson(
          _release(
            assets: [
              for (var index = 0; index < 101; index++)
                _asset(name: 'README-$index.txt'),
            ],
          ),
        ),
        throwsFormatException,
      );
    });
    for (final name in [_androidName, 'SHA256SUMS.txt', 'README.txt']) {
      test('rejects duplicate asset name $name', () {
        expect(
          () => GitHubRelease.fromJson(
            _release(
              assets: [
                _asset(name: name),
                _asset(name: name),
              ],
            ),
          ),
          throwsFormatException,
        );
      });
    }
  });

  group('SHA256 digest and fallback contracts', () {
    for (final name in [_msiName, _portableName]) {
      test('requires an exact same-release SHA256SUMS entry for $name', () {
        final release = GitHubRelease.fromJson(
          _release(assets: [_asset(name: name, digest: null)]),
        );
        expect(release.needsChecksums, isTrue);
        expect(release.toManifest, throwsFormatException);
        expect(
          () => release.toManifest(checksums: {_windowsName: _windowsHash}),
          throwsFormatException,
        );
        final manifest = release.toManifest(
          checksums: GitHubRelease.parseChecksums('$_windowsHash  $name\n'),
        );
        expect(manifest.assets.single.fileName, name);
        expect(manifest.assets.single.kind, _windowsPackages[name]);
        expect(manifest.assets.single.sha256, _windowsHash);
      });
    }
    test('normalizes uppercase API hashes', () {
      final manifest = GitHubRelease.fromJson(
        _release(
          assets: [_asset(digest: 'sha256:${_androidHash.toUpperCase()}')],
        ),
      ).toManifest();
      expect(manifest.assets.single.sha256, _androidHash);
    });
    for (final omit in [false, true]) {
      test(
        'missing API digest requires a checksum (${omit ? 'absent' : 'null'})',
        () {
          final installer = _asset(digest: null);
          if (omit) installer.remove('digest');
          final release = GitHubRelease.fromJson(_release(assets: [installer]));
          expect(release.needsChecksums, isTrue);
          expect(release.checksumAsset, isNull);
          expect(release.toManifest, throwsFormatException);
        },
      );
    }
    test(
      'uses same-release SHA256SUMS for only the missing installer digest',
      () {
        final release = GitHubRelease.fromJson(
          _release(
            assets: [
              _asset(digest: null),
              _asset(name: _windowsName, digest: 'sha256:$_windowsHash'),
              _asset(name: 'SHA256SUMS.txt', digest: null, size: 250),
            ],
          ),
        );
        expect(release.needsChecksums, isTrue);
        expect(release.checksumAsset?.name, 'SHA256SUMS.txt');
        expect(
          release.checksumAsset?.url.toString(),
          '$_downloadBase/SHA256SUMS.txt',
        );
        final manifest = release.toManifest(
          checksums: GitHubRelease.parseChecksums(
            '$_androidHash  $_androidName\n',
          ),
        );
        expect(manifest.assets, hasLength(2));
        expect(manifest.assets[0].sha256, _androidHash);
        expect(manifest.assets[1].sha256, _windowsHash);
      },
    );
    test('a SHA256SUMS asset from another tag is rejected', () {
      expect(
        () => GitHubRelease.fromJson(
          _release(
            assets: [
              _asset(digest: null),
              _asset(name: 'SHA256SUMS.txt')
                ..['browser_download_url'] =
                    '$_repository/releases/download/v0.0.7/SHA256SUMS.txt',
            ],
          ),
        ),
        throwsFormatException,
      );
    });
    for (final digest in <Object?>[
      '',
      _androidHash,
      'sha1:$_androidHash',
      'SHA256:$_androidHash',
      'sha256:${'a' * 63}',
      'sha256:${'a' * 65}',
      'sha256:${'g' * 64}',
      'sha256:$_androidHash\n',
      ' sha256:$_androidHash',
      123,
      {},
    ]) {
      test(
        'rejects malformed present API digest $digest rather than fallback',
        () {
          expect(
            () => GitHubRelease.fromJson(
              _release(
                assets: [
                  _asset(digest: digest),
                  _asset(name: 'SHA256SUMS.txt', digest: null),
                ],
              ),
            ),
            throwsFormatException,
          );
        },
      );
    }
    for (final checksums in <Map<String, String>>[
      {},
      {_windowsName: _androidHash},
      {_androidName: ''},
      {_androidName: 'g' * 64},
      {_androidName: 'a' * 63},
    ]) {
      test('refuses absent or invalid fallback checksum $checksums', () {
        final release = GitHubRelease.fromJson(
          _release(assets: [_asset(digest: null)]),
        );
        expect(
          () => release.toManifest(checksums: checksums),
          throwsFormatException,
        );
      });
    }
  });

  group('strict SHA256SUMS parser', () {
    test(
      'accepts canonical and binary markers, BOM, CRLF, and uppercase hash',
      () {
        final checksums = GitHubRelease.parseChecksums(
          '\uFEFF${_androidHash.toUpperCase()}  $_androidName\r\n'
          '$_windowsHash *$_windowsName\r\n\r\n',
        );
        expect(checksums, {
          _androidName: _androidHash,
          _windowsName: _windowsHash,
        });
      },
    );
    test('an empty checksum file provides no hashes', () {
      expect(GitHubRelease.parseChecksums(''), isEmpty);
      final release = GitHubRelease.fromJson(
        _release(assets: [_asset(digest: null)]),
      );
      expect(
        () => release.toManifest(checksums: GitHubRelease.parseChecksums('')),
        throwsFormatException,
      );
    });
    for (final secondHash in [_androidHash, _windowsHash]) {
      test(
        'rejects duplicate checksum filename even with hash $secondHash',
        () {
          expect(
            () => GitHubRelease.parseChecksums(
              '$_androidHash  $_androidName\n$secondHash *$_androidName\n',
            ),
            throwsFormatException,
          );
        },
      );
    }
    for (final entry in [
      '$_androidHash $_androidName',
      '$_androidHash   $_androidName',
      '$_androidHash\t$_androidName',
      ' $_androidHash  $_androidName',
      '$_androidHash  $_androidName ',
      '${'a' * 63}  $_androidName',
      '${'a' * 65}  $_androidName',
      '${'g' * 64}  $_androidName',
      'SHA256 ($_androidName) = $_androidHash',
      '$_androidHash  ../$_androidName',
      '$_androidHash  ..\\$_androidName',
      '$_androidHash  sub/$_androidName',
      '$_androidHash  sub\\$_androidName',
      '$_androidHash  sub%2f$_androidName',
      '$_androidHash  /$_androidName',
      '$_androidHash  C:\\$_androidName',
      '$_androidHash  Slovofon..apk',
      '$_androidHash  Slovofon.apk:payload.exe',
      '# comment',
      ' ',
      '\uFEFF$_androidHash  $_androidName\n\uFEFF$_windowsHash  $_windowsName',
    ]) {
      test('rejects noncanonical or unsafe checksum line $entry', () {
        expect(
          () => GitHubRelease.parseChecksums(entry),
          throwsFormatException,
        );
      });
    }
    test('rejects more than 1000 checksum lines', () {
      expect(
        () => GitHubRelease.parseChecksums(
          [
            for (var index = 0; index < 1001; index++)
              '$_androidHash  README-$index.txt',
          ].join('\n'),
        ),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _release({List<Map<String, Object?>>? assets}) => {
  'id': 999999,
  'tag_name': _tag,
  'draft': false,
  'prerelease': false,
  'html_url': '$_repository/releases/tag/$_tag',
  'published_at': '2026-09-05T12:00:00Z',
  'body': 'Fixture release notes',
  'assets':
      assets ??
      [
        _asset(),
        _asset(name: _windowsName, digest: 'sha256:$_windowsHash', size: 5678),
      ],
};

Map<String, Object?> _asset({
  String name = _androidName,
  Object? digest =
      'sha256:abababababababababababababababababababababababababababababababab',
  int size = 1234,
}) => {
  'name': name,
  'browser_download_url': '$_downloadBase/$name',
  'state': 'uploaded',
  'size': size,
  'digest': digest,
};
