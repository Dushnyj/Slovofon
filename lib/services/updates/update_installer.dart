import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'update_client.dart';
import 'update_manifest.dart';
import 'windows_update_installation.dart';

typedef WindowsUpdateProcessLauncher =
    Future<void> Function(String executable, List<String> arguments);

class PlatformUpdateInstaller {
  PlatformUpdateInstaller({
    Future<WindowsUpdateInstallation> Function()? windowsInstallationProvider,
    WindowsUpdateProcessLauncher? windowsProcessLauncher,
    String? operatingSystem,
    String? windowsDirectory,
    this.installationInfoTimeout = const Duration(seconds: 5),
  }) : _windowsInstallationProvider = windowsInstallationProvider,
       _windowsProcessLauncher =
           windowsProcessLauncher ?? _startDetachedWindowsProcess,
       _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _windowsDirectory = windowsDirectory;

  static const _androidChannel = MethodChannel(
    'com.slovofon.app/update_installer',
  );
  static const _windowsChannel = MethodChannel(
    'com.slovofon.app/windows_update',
  );

  final Future<WindowsUpdateInstallation> Function()?
  _windowsInstallationProvider;
  final WindowsUpdateProcessLauncher _windowsProcessLauncher;
  final String _operatingSystem;
  final String? _windowsDirectory;
  final Duration installationInfoTimeout;

  Future<WindowsUpdateInstallation> windowsInstallation() async {
    if (_operatingSystem != 'windows') {
      return const WindowsUpdateInstallation.unknown();
    }
    try {
      final provider = _windowsInstallationProvider;
      if (provider != null) {
        return await provider().timeout(installationInfoTimeout);
      }
      return WindowsUpdateInstallation.fromPlatformValue(
        await _windowsChannel
            .invokeMethod<Object?>('getInstallationInfo')
            .timeout(installationInfoTimeout),
      );
    } on MissingPluginException {
      return const WindowsUpdateInstallation.unknown();
    } on PlatformException {
      return const WindowsUpdateInstallation.unknown();
    } on TimeoutException {
      return const WindowsUpdateInstallation.unknown();
    }
  }

  Future<void> ensureReadyToInstall() async {
    if (_operatingSystem == 'android') {
      final canInstall =
          await _androidChannel.invokeMethod<bool>('canInstallApks') ?? true;
      if (!canInstall) {
        await _androidChannel.invokeMethod<void>('openInstallSettings');
        throw const UpdateInstallPermissionRequired();
      }
    }
  }

  Future<void> install(DownloadedUpdate update) async {
    if (_operatingSystem == 'android') {
      return _installAndroidApk(update);
    }
    if (_operatingSystem == 'windows') {
      return _launchWindowsInstaller(update);
    }
    throw const UpdateInstallException('Updates are not supported here');
  }

  Future<void> _installAndroidApk(DownloadedUpdate update) async {
    await ensureReadyToInstall();
    await _androidChannel.invokeMethod<void>('installApk', {
      'path': update.file.path,
    });
  }

  Future<void> _launchWindowsInstaller(DownloadedUpdate update) async {
    // Re-read at launch: cached metadata must not choose a different installer
    // after installation registration or the running-copy context changes.
    final installation = await windowsInstallation();
    final asset = update.asset;
    final expectedKind = switch (installation.kind) {
      WindowsInstallKind.setup => UpdateAssetKind.installer,
      WindowsInstallKind.msi => UpdateAssetKind.msi,
      WindowsInstallKind.portable => UpdateAssetKind.portable,
      WindowsInstallKind.unknown => null,
    };
    final expectedExtension = switch (installation.kind) {
      WindowsInstallKind.setup => '.exe',
      WindowsInstallKind.msi => '.msi',
      WindowsInstallKind.portable => '.zip',
      WindowsInstallKind.unknown => null,
    };
    final filePath = path.windows.isAbsolute(update.file.path)
        ? path.windows.normalize(update.file.path)
        : update.file.absolute.path;
    if (expectedKind == null ||
        asset.platform != UpdateAssetPlatform.windows ||
        asset.arch != 'x64' ||
        asset.kind != expectedKind ||
        path.windows.extension(filePath).toLowerCase() != expectedExtension ||
        path.windows.basename(filePath) != asset.fileName ||
        !_isAbsoluteWindowsPath(filePath) ||
        !_isAbsoluteWindowsPath(installation.directory)) {
      throw const UpdateInstallException(
        'Update does not match this Windows installation',
      );
    }

    switch (installation.kind) {
      case WindowsInstallKind.setup:
        final scopeArgument = switch (installation.scope) {
          WindowsInstallScope.user => '/CURRENTUSER',
          WindowsInstallScope.machine => '/ALLUSERS',
          null => null,
        };
        if (scopeArgument == null) {
          throw const UpdateInstallException(
            'Windows installation scope is unknown',
          );
        }
        // Interactive Inno Setup owns elevation and in-use-file handling. Do
        // not change scope, silently accept pages, stop this app or reboot it.
        await _windowsProcessLauncher(filePath, [
          scopeArgument,
          '/DIR=${installation.directory}',
        ]);
      case WindowsInstallKind.msi:
        final systemDirectory = _windowsDirectory == null
            ? installation.systemDirectory
            : path.windows.join(_windowsDirectory, 'System32');
        if (!_isAbsoluteWindowsPath(systemDirectory)) {
          throw const UpdateInstallException(
            'Windows system directory is unknown',
          );
        }
        await _windowsProcessLauncher(
          path.windows.join(systemDirectory!, 'msiexec.exe'),
          ['/i', filePath, '/norestart'],
        );
      case WindowsInstallKind.portable:
        final windowsDirectory =
            _windowsDirectory ?? installation.windowsDirectory;
        if (!_isAbsoluteWindowsPath(windowsDirectory)) {
          throw const UpdateInstallException('Windows directory is unknown');
        }
        // A running portable bundle is never overwritten. Only reveal the
        // verified ZIP for an explicit, manual extraction after app shutdown.
        await _windowsProcessLauncher(
          path.windows.join(windowsDirectory!, 'explorer.exe'),
          [path.windows.dirname(filePath)],
        );
      case WindowsInstallKind.unknown:
        throw const UpdateInstallException(
          'Windows installation type is unknown',
        );
    }
  }

  static bool _isAbsoluteWindowsPath(String? value) =>
      value != null &&
      path.windows.isAbsolute(value) &&
      !value.contains(RegExp(r'[\x00-\x1f"]'));

  static Future<void> _startDetachedWindowsProcess(
    String executable,
    List<String> arguments,
  ) async {
    // This confirms launch, not installation completion; errors propagate to
    // the service so the verified download can be retried rather than lost.
    await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
  }
}

class UpdateInstallException implements Exception {
  const UpdateInstallException(this.message);

  final String message;

  @override
  String toString() => message;
}

class UpdateInstallPermissionRequired extends UpdateInstallException {
  const UpdateInstallPermissionRequired()
    : super('APK install permission is required');
}
