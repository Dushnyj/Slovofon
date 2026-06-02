import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_version.dart';
import '../../app/project_links.dart';
import 'update_client.dart';
import 'update_installer.dart';
import 'update_manifest.dart';
import 'update_version.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(
    client: const UpdateClient(),
    installer: PlatformUpdateInstaller(),
  );
});

class UpdateService {
  UpdateService({
    required UpdateClient client,
    required PlatformUpdateInstaller installer,
    UpdateRuntimePlatform? runtimePlatform,
  }) : _client = client,
       _installer = installer,
       _runtimePlatform = runtimePlatform;

  final UpdateClient _client;
  final PlatformUpdateInstaller _installer;
  final UpdateRuntimePlatform? _runtimePlatform;
  final Set<String> _skippedInSession = <String>{};

  Future<UpdateCheckResult> checkForUpdate({
    bool includeSkipped = false,
  }) async {
    final platform = _runtimePlatform ?? _currentPlatform();
    if (platform == UpdateRuntimePlatform.unsupported) {
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
    if (!includeSkipped &&
        !manifest.mandatory &&
        _skippedInSession.contains(_skipKey(info))) {
      return UpdateCheckResult.skipped(info);
    }
    return UpdateCheckResult.available(info);
  }

  Future<void> skip(UpdateInfo info) async {
    _skippedInSession.add(_skipKey(info));
  }

  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(int downloadedBytes, int? totalBytes)? onProgress,
  }) async {
    await _installer.ensureReadyToInstall();
    final update = await _client.downloadAsset(
      info.asset,
      onProgress: onProgress,
    );
    await _installer.install(update);
  }

  String _skipKey(UpdateInfo info) => '${info.version}+${info.build ?? ''}';
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

enum UpdateRuntimePlatform { android, windows, unsupported }

UpdateRuntimePlatform _currentPlatform() {
  if (Platform.isAndroid) {
    return UpdateRuntimePlatform.android;
  }
  if (Platform.isWindows) {
    return UpdateRuntimePlatform.windows;
  }
  return UpdateRuntimePlatform.unsupported;
}

UpdateAsset? _selectAsset(
  List<UpdateAsset> assets,
  UpdateRuntimePlatform platform,
) {
  final platformAssets = switch (platform) {
    UpdateRuntimePlatform.android =>
      assets
          .where((asset) => asset.platform == UpdateAssetPlatform.android)
          .toList(),
    UpdateRuntimePlatform.windows =>
      assets
          .where((asset) => asset.platform == UpdateAssetPlatform.windows)
          .toList(),
    UpdateRuntimePlatform.unsupported => const <UpdateAsset>[],
  };

  if (platform == UpdateRuntimePlatform.android) {
    return _firstAsset(platformAssets, (asset) {
          return asset.kind == UpdateAssetKind.apk && asset.arch == 'universal';
        }) ??
        _firstAsset(
          platformAssets,
          (asset) => asset.kind == UpdateAssetKind.apk,
        );
  }

  if (platform == UpdateRuntimePlatform.windows) {
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
