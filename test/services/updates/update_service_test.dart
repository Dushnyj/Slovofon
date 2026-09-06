import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/project_links.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_manifest.dart';
import 'package:slovofon/services/updates/update_service.dart';

void main() {
  group('UpdateService GitHub release checks', () {
    test(
      'every check fetches the repository GitHub latest release endpoint',
      () async {
        final client = _FakeClient([_manifest()]);
        final service = _service(client);

        await service.checkForUpdate();
        await service.checkForUpdate(includeSkipped: true);

        final endpoint = Uri.parse(
          'https://api.github.com/repos/Dushnyj/Slovofon/releases/latest',
        );
        expect(Uri.parse(ProjectLinks.githubLatestRelease), endpoint);
        expect(client.fetchedUris, [endpoint, endpoint]);
        expect(client.downloadedAssets, isEmpty);
      },
    );

    test(
      'later checks observe newly published releases without a permanent cache',
      () async {
        final client = _FakeClient([
          _manifest(status: 'no_release', version: null, assets: []),
          _manifest(version: '1.2.4'),
          _manifest(version: '1.2.5'),
        ]);
        final service = _service(client);

        expect(
          (await service.checkForUpdate()).status,
          UpdateCheckStatus.noUpdate,
        );
        final firstRelease = await service.checkForUpdate();
        expect(firstRelease.status, UpdateCheckStatus.available);
        expect(firstRelease.info?.version, '1.2.4');
        final nextRelease = await service.checkForUpdate();
        expect(nextRelease.status, UpdateCheckStatus.available);
        expect(nextRelease.info?.version, '1.2.5');
        expect(client.fetchedUris, hasLength(3));
      },
    );

    for (final platform in [
      UpdateRuntimePlatform.android,
      UpdateRuntimePlatform.windows,
    ]) {
      for (final remote in [
        (version: '1.2.3', build: 7),
        (version: '1.2.3', build: 6),
        (version: '1.2.2', build: 999),
      ]) {
        test(
          '${platform.name}: current/older ${remote.version}+${remote.build} is noUpdate',
          () async {
            final client = _FakeClient([
              _manifest(version: remote.version, build: remote.build),
            ]);
            final result = await _service(
              client,
              platform: platform,
            ).checkForUpdate();

            expect(result.status, UpdateCheckStatus.noUpdate);
            expect(result.info, isNull);
            expect(client.fetchedUris, hasLength(1));
          },
        );
      }

      test(
        '${platform.name}: newer public version with no build is available',
        () async {
          final client = _FakeClient([
            _manifest(version: '1.2.4', build: null),
          ]);
          final result = await _service(
            client,
            platform: platform,
          ).checkForUpdate();

          expect(result.status, UpdateCheckStatus.available);
          expect(result.info?.version, '1.2.4');
          expect(
            result.info?.asset.fileName,
            platform == UpdateRuntimePlatform.android
                ? 'Slovofon-v1.2.4-android-universal-release.apk'
                : 'Slovofon-v1.2.4-windows-x64-setup.exe',
          );
        },
      );

      test(
        '${platform.name}: equal public version with newer build is available',
        () async {
          final result = await _service(
            _FakeClient([_manifest(version: '1.2.3', build: 8)]),
            platform: platform,
          ).checkForUpdate();
          expect(result.status, UpdateCheckStatus.available);
          expect(result.info?.build, 8);
        },
      );

      test(
        '${platform.name}: a newer release without assets is unsupported, not current',
        () async {
          final manifest = _manifest(assets: []);
          expect(manifest.isAvailable, isTrue);

          final result = await _service(
            _FakeClient([manifest]),
            platform: platform,
          ).checkForUpdate();
          expect(result.status, UpdateCheckStatus.unsupported);
          expect(result.info, isNull);
        },
      );

      test(
        '${platform.name}: only the other platform installer is unsupported',
        () async {
          final assets = platform == UpdateRuntimePlatform.android
              ? [_windowsAsset()]
              : [_androidAsset()];
          final result = await _service(
            _FakeClient([_manifest(assets: assets)]),
            platform: platform,
          ).checkForUpdate();
          expect(result.status, UpdateCheckStatus.unsupported);
        },
      );
    }

    test(
      'unsupported runtime performs zero release/download/installer calls',
      () async {
        final client = _FakeClient([_manifest()])
          ..fetchFailure = const UpdateClientException('must not fetch');
        final installer = _FakeInstaller([]);
        final result = await _service(
          client,
          platform: UpdateRuntimePlatform.unsupported,
          installer: installer,
        ).checkForUpdate();

        expect(result.status, UpdateCheckStatus.unsupported);
        expect(client.fetchedUris, isEmpty);
        expect(client.downloadedAssets, isEmpty);
        expect(installer.events, isEmpty);
      },
    );

    test(
      'release lookup errors propagate and a later check can recover',
      () async {
        const failure = UpdateClientException('GitHub unavailable');
        final client = _FakeClient([_manifest()])..fetchFailure = failure;
        final service = _service(client);
        await expectLater(service.checkForUpdate(), throwsA(same(failure)));

        client.fetchFailure = null;
        expect(
          (await service.checkForUpdate()).status,
          UpdateCheckStatus.available,
        );
        expect(client.fetchedUris, hasLength(2));
      },
    );
  });

  group('UpdateService installer selection', () {
    final androidRejected = <String, UpdateAsset>{
      'arbitrary arm64 ABI': _androidAsset(
        arch: 'arm64-v8a',
        fileName: 'Slovofon-v1.2.4-android-arm64-v8a-release.apk',
      ),
      'x86 APK': _androidAsset(
        arch: 'x86_64',
        fileName: 'Slovofon-v1.2.4-android-x86_64-release.apk',
      ),
      'wrong architecture despite matching name': _androidAsset(
        arch: 'arm64-v8a',
      ),
      'AAB despite matching name': _androidAsset(kind: UpdateAssetKind.aab),
      'filename from another release tag': _androidAsset(
        fileName: 'Slovofon-v1.2.5-android-universal-release.apk',
      ),
      'arbitrary APK name': _androidAsset(fileName: 'app-release.apk'),
    };
    for (final entry in androidRejected.entries) {
      test('Android rejects ${entry.key} instead of falling back', () async {
        final result = await _service(
          _FakeClient([
            _manifest(assets: [entry.value]),
          ]),
        ).checkForUpdate();
        expect(result.status, UpdateCheckStatus.unsupported);
      });
    }

    final windowsRejected = <String, UpdateAsset>{
      'portable ZIP': _windowsAsset(
        kind: UpdateAssetKind.portable,
        fileName: 'Slovofon-v1.2.4-windows-x64-portable.zip',
      ),
      'MSIX': _windowsAsset(
        kind: UpdateAssetKind.msix,
        fileName: 'Slovofon-v1.2.4-windows-x64-msix.msix',
      ),
      'wrong architecture despite matching name': _windowsAsset(arch: 'arm64'),
      'wrong kind despite matching name': _windowsAsset(
        kind: UpdateAssetKind.portable,
      ),
      'filename from another release tag': _windowsAsset(
        fileName: 'Slovofon-v1.2.5-windows-x64-setup.exe',
      ),
      'arbitrary executable': _windowsAsset(fileName: 'setup.exe'),
    };
    for (final entry in windowsRejected.entries) {
      test('Windows rejects ${entry.key} instead of launching it', () async {
        final result = await _service(
          _FakeClient([
            _manifest(assets: [entry.value]),
          ]),
          platform: UpdateRuntimePlatform.windows,
        ).checkForUpdate();
        expect(result.status, UpdateCheckStatus.unsupported);
      });
    }

    test(
      'Android selects the exact universal APK after incompatible assets',
      () async {
        final expected = _androidAsset();
        final result = await _service(
          _FakeClient([
            _manifest(
              assets: [...androidRejected.values, _windowsAsset(), expected],
            ),
          ]),
        ).checkForUpdate();
        expect(result.status, UpdateCheckStatus.available);
        expect(result.info?.asset, same(expected));
      },
    );

    test(
      'Windows selects exact x64 setup EXE after ZIP/MSIX/wrong-arch assets',
      () async {
        final expected = _windowsAsset();
        final result = await _service(
          _FakeClient([
            _manifest(
              assets: [...windowsRejected.values, _androidAsset(), expected],
            ),
          ]),
          platform: UpdateRuntimePlatform.windows,
        ).checkForUpdate();
        expect(result.status, UpdateCheckStatus.available);
        expect(result.info?.asset, same(expected));
      },
    );
  });

  group('UpdateService session skip', () {
    test(
      'automatic checks skip this release but manual checks include it',
      () async {
        final client = _FakeClient([_manifest()]);
        final service = _service(client);
        final available = await service.checkForUpdate();
        await service.skip(available.info!);

        final automatic = await service.checkForUpdate();
        expect(automatic.status, UpdateCheckStatus.skipped);
        expect(automatic.info?.version, available.info?.version);
        expect(
          (await service.checkForUpdate(includeSkipped: true)).status,
          UpdateCheckStatus.available,
        );
        expect(client.fetchedUris, hasLength(3));
      },
    );

    test('skip belongs only to the current service session', () async {
      final client = _FakeClient([_manifest()]);
      final firstSession = _service(client);
      await firstSession.skip((await firstSession.checkForUpdate()).info!);
      expect(
        (await firstSession.checkForUpdate()).status,
        UpdateCheckStatus.skipped,
      );

      final nextSession = _service(client);
      expect(
        (await nextSession.checkForUpdate()).status,
        UpdateCheckStatus.available,
      );
    });

    test('skipping one version does not hide a later GitHub release', () async {
      final service = _service(
        _FakeClient([_manifest(version: '1.2.4'), _manifest(version: '1.2.5')]),
      );
      await service.skip((await service.checkForUpdate()).info!);
      final newer = await service.checkForUpdate();
      expect(newer.status, UpdateCheckStatus.available);
      expect(newer.info?.version, '1.2.5');
    });

    test(
      'mandatory release remains available even if it was skipped',
      () async {
        final service = _service(_FakeClient([_manifest(mandatory: true)]));
        await service.skip((await service.checkForUpdate()).info!);
        expect(
          (await service.checkForUpdate()).status,
          UpdateCheckStatus.available,
        );
      },
    );
  });

  group('UpdateService download and install ordering', () {
    test(
      'permission readiness completes before downloading, then installation receives verified result',
      () async {
        final events = <String>[];
        final readiness = Completer<void>();
        final installer = _FakeInstaller(events)..readiness = readiness.future;
        final client = _FakeClient([_manifest()], events: events);
        final service = _service(client, installer: installer);
        final info = (await service.checkForUpdate()).info!;
        final progress = <(int, int?)>[];

        final operation = service.downloadAndInstall(
          info,
          onProgress: (downloaded, total) => progress.add((downloaded, total)),
        );
        await Future<void>.delayed(Duration.zero);
        expect(events, ['ensureReady']);
        expect(client.downloadedAssets, isEmpty);
        expect(installer.installedUpdates, isEmpty);

        readiness.complete();
        await operation;
        expect(events, ['ensureReady', 'download', 'install']);
        expect(client.downloadedAssets, [same(info.asset)]);
        expect(
          installer.installedUpdates.single,
          same(client.lastDownloadedUpdate),
        );
        expect(progress, [(3, 8), (8, 8)]);
      },
    );

    test(
      'permission denial prevents both downloading and installation',
      () async {
        final events = <String>[];
        const denial = UpdateInstallPermissionRequired();
        final installer = _FakeInstaller(events)..readinessFailure = denial;
        final client = _FakeClient([_manifest()], events: events);
        final service = _service(client, installer: installer);
        final info = (await service.checkForUpdate()).info!;

        await expectLater(
          service.downloadAndInstall(info),
          throwsA(same(denial)),
        );
        expect(events, ['ensureReady']);
        expect(client.downloadedAssets, isEmpty);
        expect(installer.installedUpdates, isEmpty);
      },
    );

    test('download or checksum failure never invokes the installer', () async {
      final events = <String>[];
      const failure = UpdateClientException(
        'Downloaded asset checksum mismatch',
      );
      final client = _FakeClient([_manifest()], events: events)
        ..downloadFailure = failure;
      final installer = _FakeInstaller(events);
      final service = _service(client, installer: installer);
      final info = (await service.checkForUpdate()).info!;

      await expectLater(
        service.downloadAndInstall(info),
        throwsA(same(failure)),
      );
      expect(events, ['ensureReady', 'download']);
      expect(installer.installedUpdates, isEmpty);
    });
  });
}

UpdateService _service(
  _FakeClient client, {
  UpdateRuntimePlatform platform = UpdateRuntimePlatform.android,
  _FakeInstaller? installer,
}) => UpdateService(
  client: client,
  installer: installer ?? _FakeInstaller([]),
  runtimePlatform: platform,
  currentVersion: '1.2.3',
  currentBuild: '7',
);

UpdateManifest _manifest({
  String? version = '1.2.4',
  int? build = 8,
  String status = 'available',
  bool mandatory = false,
  List<UpdateAsset>? assets,
}) => UpdateManifest(
  schema: 1,
  app: 'slovofon',
  channel: 'stable',
  status: status,
  version: version,
  build: build,
  publishedAt: DateTime.utc(2026, 9, 5),
  mandatory: mandatory,
  releaseUrl: 'https://github.com/Dushnyj/Slovofon/releases/tag/v$version',
  releaseNotes: 'Synthetic fixture release',
  assets:
      assets ??
      [
        _androidAsset(
          fileName: 'Slovofon-v$version-android-universal-release.apk',
        ),
        _windowsAsset(fileName: 'Slovofon-v$version-windows-x64-setup.exe'),
      ],
);

UpdateAsset _androidAsset({
  String arch = 'universal',
  UpdateAssetKind kind = UpdateAssetKind.apk,
  String fileName = 'Slovofon-v1.2.4-android-universal-release.apk',
}) => _asset(UpdateAssetPlatform.android, arch, kind, fileName);

UpdateAsset _windowsAsset({
  String arch = 'x64',
  UpdateAssetKind kind = UpdateAssetKind.installer,
  String fileName = 'Slovofon-v1.2.4-windows-x64-setup.exe',
}) => _asset(UpdateAssetPlatform.windows, arch, kind, fileName);

UpdateAsset _asset(
  UpdateAssetPlatform platform,
  String arch,
  UpdateAssetKind kind,
  String fileName,
) => UpdateAsset(
  platform: platform,
  arch: arch,
  kind: kind,
  url: Uri.parse(
    'https://github.com/Dushnyj/Slovofon/releases/download/v1.2.4/$fileName',
  ),
  fileName: fileName,
  sha256: List.filled(64, 'a').join(),
  size: 8,
);

/// Service-boundary fake: never opens a socket, creates a file or runs an EXE.
class _FakeClient extends UpdateClient {
  _FakeClient(this.manifests, {List<String>? events}) : events = events ?? [];

  final List<UpdateManifest> manifests;
  final List<String> events;
  final fetchedUris = <Uri>[];
  final downloadedAssets = <UpdateAsset>[];
  Object? fetchFailure;
  Object? downloadFailure;
  DownloadedUpdate? lastDownloadedUpdate;
  int _manifestIndex = 0;

  @override
  Future<UpdateManifest> fetchManifest(Uri uri) async {
    fetchedUris.add(uri);
    final failure = fetchFailure;
    if (failure != null) throw failure;
    final index = _manifestIndex.clamp(0, manifests.length - 1);
    _manifestIndex++;
    return manifests[index];
  }

  @override
  Future<DownloadedUpdate> downloadAsset(
    UpdateAsset asset, {
    void Function(int downloadedBytes, int? totalBytes)? onProgress,
  }) async {
    events.add('download');
    downloadedAssets.add(asset);
    final failure = downloadFailure;
    if (failure != null) throw failure;
    onProgress?.call(3, 8);
    onProgress?.call(8, 8);
    return lastDownloadedUpdate = DownloadedUpdate(
      file: File('synthetic-update-not-created'),
      asset: asset,
    );
  }
}

class _FakeInstaller extends PlatformUpdateInstaller {
  _FakeInstaller(this.events);

  final List<String> events;
  final installedUpdates = <DownloadedUpdate>[];
  Future<void>? readiness;
  Object? readinessFailure;

  @override
  Future<void> ensureReadyToInstall() async {
    events.add('ensureReady');
    await readiness;
    final failure = readinessFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> install(DownloadedUpdate update) async {
    events.add('install');
    installedUpdates.add(update);
  }
}
