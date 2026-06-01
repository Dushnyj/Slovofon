import 'dart:io';

import 'package:flutter/services.dart';

import 'update_client.dart';

class PlatformUpdateInstaller {
  static const _androidChannel = MethodChannel(
    'com.slovofon.app/update_installer',
  );

  Future<void> install(DownloadedUpdate update) async {
    if (Platform.isAndroid) {
      return _installAndroidApk(update);
    }
    if (Platform.isWindows) {
      return _launchWindowsInstaller(update);
    }
    throw const UpdateInstallException('Updates are not supported here');
  }

  Future<void> _installAndroidApk(DownloadedUpdate update) async {
    final canInstall =
        await _androidChannel.invokeMethod<bool>('canInstallApks') ?? true;
    if (!canInstall) {
      await _androidChannel.invokeMethod<void>('openInstallSettings');
      throw const UpdateInstallPermissionRequired();
    }
    await _androidChannel.invokeMethod<void>('installApk', {
      'path': update.file.path,
    });
  }

  Future<void> _launchWindowsInstaller(DownloadedUpdate update) async {
    await Process.start(
      update.file.path,
      const [],
      mode: ProcessStartMode.detached,
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
