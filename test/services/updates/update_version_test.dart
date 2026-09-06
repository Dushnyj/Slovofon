import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_manifest.dart';
import 'package:slovofon/services/updates/update_service.dart';
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
            'url':
                'https://github.com/Dushnyj/Slovofon/releases/download/v0.4.1/Slovofon-v0.4.1-android-universal-release.apk',
            'file_name': 'Slovofon-v0.4.1-android-universal-release.apk',
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

  group('UpdateService', () {
    test('skips an update only for the current app session', () async {
      final manifest = _availableManifest(version: '99.0.0', build: 9900);
      final service = UpdateService(
        client: _FakeUpdateClient(manifest),
        installer: _NoopUpdateInstaller(),
        runtimePlatform: UpdateRuntimePlatform.android,
      );

      final firstCheck = await service.checkForUpdate();
      expect(firstCheck.status, UpdateCheckStatus.available);

      await service.skip(firstCheck.info!);

      final skippedCheck = await service.checkForUpdate();
      expect(skippedCheck.status, UpdateCheckStatus.skipped);

      final restartedService = UpdateService(
        client: _FakeUpdateClient(manifest),
        installer: _NoopUpdateInstaller(),
        runtimePlatform: UpdateRuntimePlatform.android,
      );

      final restartedCheck = await restartedService.checkForUpdate();
      expect(restartedCheck.status, UpdateCheckStatus.available);
    });
  });
}

UpdateManifest _availableManifest({
  required String version,
  required int build,
}) {
  return UpdateManifest.fromJson({
    'schema': 2,
    'app': 'slovofon',
    'channel': 'stable',
    'status': 'available',
    'version': version,
    'build': build,
    'published_at': '2026-06-02T12:00:00Z',
    'mandatory': false,
    'assets': [
      {
        'platform': 'android',
        'arch': 'universal',
        'kind': 'apk',
        'url':
            'https://github.com/Dushnyj/Slovofon/releases/download/v$version/Slovofon-v$version-android-universal-release.apk',
        'file_name': 'Slovofon-v$version-android-universal-release.apk',
        'sha256': 'a' * 64,
        'size': 123,
      },
    ],
  });
}

class _FakeUpdateClient extends UpdateClient {
  const _FakeUpdateClient(this.manifest);

  final UpdateManifest manifest;

  @override
  Future<UpdateManifest> fetchManifest(Uri uri) async => manifest;
}

class _NoopUpdateInstaller extends PlatformUpdateInstaller {
  @override
  Future<void> ensureReadyToInstall() async {}

  @override
  Future<void> install(DownloadedUpdate update) async {}
}
