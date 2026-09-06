import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_version.dart';
import '../../app/project_links.dart';
import '../audio/playback_controller_provider.dart';
import 'update_client.dart';
import 'update_installer.dart';
import 'update_manifest.dart';
import 'update_preferences.dart';
import 'update_version.dart';
import 'windows_update_installation.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(
    client: const UpdateClient(),
    installer: PlatformUpdateInstaller(),
    preferences: FileUpdatePreferences(),
    beforeInstall: () => ref
        .read(playbackControllerProvider)
        .flushPlayback(requireSuccess: true),
  );
});

class UpdateService {
  UpdateService({
    required UpdateClient client,
    required PlatformUpdateInstaller installer,
    UpdateRuntimePlatform? runtimePlatform,
    String currentVersion = AppVersion.version,
    String currentBuild = AppVersion.buildNumber,
    UpdatePreferences? preferences,
    Future<void> Function()? beforeInstall,
    DateTime Function()? clock,
    this.automaticCheckInterval = const Duration(minutes: 30),
  }) : _client = client,
       _installer = installer,
       _runtimePlatform = runtimePlatform,
       _currentVersion = currentVersion,
       _currentBuild = currentBuild,
       _preferences = preferences ?? MemoryUpdatePreferences(),
       _beforeInstall = beforeInstall,
       _clock = clock ?? DateTime.now;

  final UpdateClient _client;
  final PlatformUpdateInstaller _installer;
  final UpdateRuntimePlatform? _runtimePlatform;
  final String _currentVersion;
  final String _currentBuild;
  final UpdatePreferences _preferences;
  final Future<void> Function()? _beforeInstall;
  final DateTime Function() _clock;
  final Duration automaticCheckInterval;
  Future<UpdateCheckResult>? _checkInFlight;
  DateTime? _lastAutomaticCheck;
  bool _installing = false;

  /// Startup/resume checks are throttled, unlike explicit checks in Settings.
  /// The foreground timer belongs to the UI lifecycle, not a background daemon.
  Future<UpdateCheckResult> checkForAutomaticUpdate() async {
    final now = _clock();
    final last = _lastAutomaticCheck;
    if (last != null &&
        !now.isBefore(last) &&
        now.difference(last) < automaticCheckInterval) {
      return const UpdateCheckResult.noUpdate();
    }
    _lastAutomaticCheck = now;
    return checkForUpdate();
  }

  Future<UpdateCheckResult> checkForUpdate({
    bool includeSkipped = false,
  }) async {
    final result = await _sharedCheck();
    final info = result.info;
    // Each caller applies its own policy after a shared network request:
    // a simultaneous manual check must still reveal a skipped release.
    if (!includeSkipped && info != null && !info.manifest.mandatory) {
      String? skipped;
      try {
        skipped = await _preferences.readSkippedVersion();
      } on Object {
        // Broken preferences cannot hide a valid update. Explicit save errors
        // are propagated by skip(), so the dialog never pretends to save them.
      }
      if (skipped == _skipKey(info)) return UpdateCheckResult.skipped(info);
    }
    return result;
  }

  Future<UpdateCheckResult> _sharedCheck() async {
    final pending = _checkInFlight;
    if (pending != null) return pending;
    final operation = _performCheck();
    _checkInFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_checkInFlight, operation)) _checkInFlight = null;
    }
  }

  Future<UpdateCheckResult> _performCheck() async {
    final platform = _runtimePlatform ?? _currentPlatform();
    if (platform == UpdateRuntimePlatform.unsupported) {
      return const UpdateCheckResult.unsupported();
    }

    final manifest = await _client.fetchManifest(
      Uri.parse(ProjectLinks.githubLatestRelease),
    );
    if (!manifest.isAvailable ||
        !isRemoteVersionNewer(
          currentVersion: _currentVersion,
          currentBuild: _currentBuild,
          remoteVersion: manifest.version,
          remoteBuild: manifest.build,
        )) {
      return const UpdateCheckResult.noUpdate();
    }

    final windowsInstallation = platform == UpdateRuntimePlatform.windows
        ? await _installer.windowsInstallation()
        : null;
    final asset = _selectAsset(
      manifest.assets,
      platform,
      manifest.version!,
      windowsInstallation,
    );
    if (asset == null) {
      return const UpdateCheckResult.unsupported();
    }

    return UpdateCheckResult.available(
      UpdateInfo(
        manifest: manifest,
        asset: asset,
        windowsInstallation: windowsInstallation,
      ),
    );
  }

  Future<void> skip(UpdateInfo info) async {
    await _preferences.saveSkippedVersion(_skipKey(info));
  }

  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(int downloadedBytes, int? totalBytes)? onProgress,
  }) async {
    if (info.requiresManualDownload) {
      throw const UpdateInstallException('Installation type is unknown');
    }
    if (_installing) {
      throw const UpdateInstallException('An update is already in progress');
    }
    _installing = true;
    try {
      await _installer.ensureReadyToInstall();
      final update = await _client.downloadAsset(
        info.asset,
        onProgress: onProgress,
      );
      if (info.asset.platform == UpdateAssetPlatform.windows &&
          !info.isPortableUpdate) {
        // The interactive installer may ask Windows to close the application.
        // Persist the latest position before handing control to it.
        try {
          await _beforeInstall?.call();
        } on Object {
          // Do not launch an installer which may close this process if the
          // playback checkpoint could not be saved. Keep storage details out
          // of the UI and classify this as preparation, not a network failure.
          throw const UpdateInstallException(
            'Could not save playback before starting the installer',
          );
        }
      }
      await _installer.install(update);
    } finally {
      _installing = false;
    }
  }

  String _skipKey(UpdateInfo info) => '${info.version}+${info.build ?? ''}';
}

class UpdateInfo {
  const UpdateInfo({
    required this.manifest,
    required this.asset,
    this.windowsInstallation,
  });

  final UpdateManifest manifest;
  final UpdateAsset asset;
  final WindowsUpdateInstallation? windowsInstallation;

  String get version => manifest.version!;
  int? get build => manifest.build;
  bool get isPortableUpdate => asset.kind == UpdateAssetKind.portable;
  bool get requiresManualDownload =>
      windowsInstallation?.kind == WindowsInstallKind.unknown;
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
  String version,
  WindowsUpdateInstallation? windowsInstallation,
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
      return asset.kind == UpdateAssetKind.apk &&
          asset.arch == 'universal' &&
          asset.fileName == 'Slovofon-v$version-android-universal-release.apk';
    });
  }

  if (platform == UpdateRuntimePlatform.windows) {
    final kinds = switch (windowsInstallation?.kind) {
      WindowsInstallKind.setup => [UpdateAssetKind.installer],
      WindowsInstallKind.msi => [UpdateAssetKind.msi],
      WindowsInstallKind.portable => [UpdateAssetKind.portable],
      // Metadata is still useful for an explicit release-page fallback. This
      // context is never passed to the launcher as an automatic installation.
      WindowsInstallKind.unknown || null => [
        UpdateAssetKind.portable,
        UpdateAssetKind.msi,
        UpdateAssetKind.installer,
      ],
    };
    for (final kind in kinds) {
      final suffix = switch (kind) {
        UpdateAssetKind.msi => 'msi.msi',
        UpdateAssetKind.portable => 'portable.zip',
        _ => 'setup.exe',
      };
      final asset = _firstAsset(platformAssets, (asset) {
        return asset.kind == kind &&
            asset.arch == 'x64' &&
            asset.fileName == 'Slovofon-v$version-windows-x64-$suffix';
      });
      if (asset != null) return asset;
    }
    return null;
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
