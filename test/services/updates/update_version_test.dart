import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/updates/update_manifest.dart';
import 'package:slovofon/services/updates/update_version.dart';

void main() {
  group('UpdateVersion', () {
    test('detects newer semantic version without build number', () {
      expect(
        isRemoteVersionNewer(
          currentVersion: '0.4.0',
          currentBuild: '10',
          remoteVersion: '0.4.1',
          remoteBuild: null,
        ),
        isTrue,
      );
    });

    test('uses build number when semantic version is equal', () {
      expect(
        isRemoteVersionNewer(
          currentVersion: '0.4.0',
          currentBuild: '10',
          remoteVersion: '0.4.0',
          remoteBuild: 11,
        ),
        isTrue,
      );
    });

    test('does not downgrade when remote build is older', () {
      expect(
        isRemoteVersionNewer(
          currentVersion: '0.4.0',
          currentBuild: '10',
          remoteVersion: '0.4.0',
          remoteBuild: 9,
        ),
        isFalse,
      );
    });
  });

  group('UpdateManifest', () {
    test('parses available manifest assets', () {
      final manifest = UpdateManifest.fromJson({
        'schema': 2,
        'app': 'slovofon',
        'channel': 'stable',
        'status': 'available',
        'version': '0.4.1',
        'build': 11,
        'published_at': '2026-06-01T12:00:00Z',
        'mandatory': false,
        'release_notes': 'Fixes',
        'assets': [
          {
            'platform': 'android',
            'arch': 'universal',
            'kind': 'apk',
            'url': 'https://slovofon-updates.duckdns.org/v1/files/app.apk',
            'file_name': 'app.apk',
            'sha256': 'a' * 64,
            'size': 123,
          },
        ],
      });

      expect(manifest.isAvailable, isTrue);
      expect(manifest.version, '0.4.1');
      expect(manifest.assets.single.platform, UpdateAssetPlatform.android);
      expect(manifest.assets.single.kind, UpdateAssetKind.apk);
    });
  });
}
