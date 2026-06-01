import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_version.dart';
import '../../app/project_links.dart';
import 'update_client.dart';
import 'update_installer.dart';
import 'update_manifest.dart';
import 'update_preferences.dart';
import 'update_version.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(
    client: const UpdateClient(),
    installer: PlatformUpdateInstaller(),
    preferences: LazyFileUpdatePreferencesStore(),
  );
});

class UpdateService {
  const UpdateService({
    required UpdateClient client,
    required PlatformUpdateInstaller installer,
    required UpdatePreferencesStore preferences,
  }) : _client = client,
       _installer = installer,
       _preferences = preferences;

  final UpdateClient _client;
  final PlatformUpdateInstaller _installer;
  final UpdatePreferencesStore _preferences;

  Future<UpdateCheckResult> checkForUpdate({
    bool includeSkipped = false,
  }) async {
    final platform = _currentPlatform();
    if (platform == _RuntimePlatform.unsupported) {
      return const UpdateCheckResult.unsupported();
    }

    final manifest = await _client.fetchManifest(
      Uri.parse(ProjectLinks.updatesStableManifest),
    );
    if (!manifest.isAvailable ||
        !isRemoteVersionNewer(
          currentVersion: AppVersion.version,
          currentBuild: AppVersion.buildNumber,
          remoteVersion: manifest.version,
          remoteBuild: manifest.build,
        )) {
      return const UpdateCheckResult.noUpdate();
    }

    final asset = _selectAsset(manifest.assets, platform);
    if (asset == null) {
      return const UpdateCheckResult.unsupported();
    }

    final info = UpdateInfo(manifest: manifest, asset: asset);
    final skipped = await _preferences.loadSkippedUpdate();
    if (!includeSkipped &&
        !manifest.mandatory &&
        skipped != null &&
        skipped.matches(version: manifest.version!, build: manifest.build)) {
      return UpdateCheckResult.skipped(info);
    }
    return UpdateCheckResult.available(info);
  }

  Future<void> skip(UpdateInfo info) {
    return _preferences.saveSkippedUpdate(
      SkippedUpdate(version: info.version, build: info.build),
    );
  }

  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(int downloadedBytes, int? totalBytes)? onProgress,
  }) async {
    final update = await _client.downloadAsset(
      info.asset,
      onProgress: onProgress,
    );
    await _installer.install(update);
  }
}

class UpdateInfo {
  const UpdateInfo({required this.manifest, required this.asset});

  final UpdateManifest manifest;
  final UpdateAsset asset;

  String get version => manifest.version!;
  int? get build => manifest.build;
}

enum UpdateCheckStatus { noUpdate, available, skipped, unsupported }

class UpdateCheckResult {
  const UpdateCheckResult._(this.status, this.info);

  const UpdateCheckResult.noUpdate() : this._(UpdateCheckStatus.noUpdate, null);
  const UpdateCheckResult.unsupported()
    : this._(UpdateCheckStatus.unsupported, null);
  const UpdateCheckResult.available(UpdateInfo info)
    : this._(UpdateCheckStatus.available, info);
  const UpdateCheckResult.skipped(UpdateInfo info)
    : this._(UpdateCheckStatus.skipped, info);

  final UpdateCheckStatus status;
  final UpdateInfo? info;
}

enum _RuntimePlatform { android, windows, unsupported }

_RuntimePlatform _currentPlatform() {
  if (Platform.isAndroid) {
    return _RuntimePlatform.android;
  }
  if (Platform.isWindows) {
    return _RuntimePlatform.windows;
  }
  return _RuntimePlatform.unsupported;
}

UpdateAsset? _selectAsset(List<UpdateAsset> assets, _RuntimePlatform platform) {
  final platformAssets = switch (platform) {
    _RuntimePlatform.android =>
      assets
          .where((asset) => asset.platform == UpdateAssetPlatform.android)
          .toList(),
    _RuntimePlatform.windows =>
      assets
          .where((asset) => asset.platform == UpdateAssetPlatform.windows)
          .toList(),
    _RuntimePlatform.unsupported => const <UpdateAsset>[],
  };

  if (platform == _RuntimePlatform.android) {
    return _firstAsset(platformAssets, (asset) {
          return asset.kind == UpdateAssetKind.apk && asset.arch == 'universal';
        }) ??
        _firstAsset(
          platformAssets,
          (asset) => asset.kind == UpdateAssetKind.apk,
        );
  }

  if (platform == _RuntimePlatform.windows) {
    return _firstAsset(
          platformAssets,
          (asset) => asset.kind == UpdateAssetKind.installer,
        ) ??
        _firstAsset(
          platformAssets,
          (asset) => asset.kind == UpdateAssetKind.msix,
        ) ??
        _firstAsset(
          platformAssets,
          (asset) => asset.kind == UpdateAssetKind.portable,
        );
  }
  return null;
}

UpdateAsset? _firstAsset(
  List<UpdateAsset> assets,
  bool Function(UpdateAsset asset) test,
) {
  for (final asset in assets) {
    if (test(asset)) {
      return asset;
    }
  }
  return null;
}
