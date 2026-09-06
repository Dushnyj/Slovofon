import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_manifest.dart';
import 'package:slovofon/services/updates/windows_update_installation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.slovofon.app/windows_update');
  const androidChannel = MethodChannel('com.slovofon.app/update_installer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(androidChannel, null);
  });

  group('read-only Windows installation context', () {
    test('missing native bridge is unknown, never assumed Setup', () async {
      final installer = PlatformUpdateInstaller(operatingSystem: 'windows');
      expect(
        (await installer.windowsInstallation()).kind,
        WindowsInstallKind.unknown,
      );
    });

    test('native detection failure is unknown', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'not_available');
      });
      expect(
        (await PlatformUpdateInstaller(
          operatingSystem: 'windows',
        ).windowsInstallation()).kind,
        WindowsInstallKind.unknown,
      );
    });

    test('non-responsive detection times out without assuming Setup', () async {
      final installer = PlatformUpdateInstaller(
        operatingSystem: 'windows',
        installationInfoTimeout: const Duration(milliseconds: 1),
        windowsInstallationProvider: () =>
            Completer<WindowsUpdateInstallation>().future,
      );
      expect(
        (await installer.windowsInstallation()).kind,
        WindowsInstallKind.unknown,
      );
    });

    test(
      'native context preserves current directory and explicit scope',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getInstallationInfo');
          expect(call.arguments, isNull);
          return {
            'kind': 'setup',
            'scope': 'machine',
            'directory': r'D:\My Apps\Словофон',
            'systemDirectory': r'C:\Windows\System32',
            'windowsDirectory': r'C:\Windows',
          };
        });
        final context = await PlatformUpdateInstaller(
          operatingSystem: 'windows',
        ).windowsInstallation();
        expect(context.kind, WindowsInstallKind.setup);
        expect(context.scope, WindowsInstallScope.machine);
        expect(context.directory, r'D:\My Apps\Словофон');
        expect(context.systemDirectory, r'C:\Windows\System32');
        expect(context.windowsDirectory, r'C:\Windows');
      },
    );

    for (final raw in <Object?>[
      null,
      'setup',
      {},
      {'kind': 'setup', 'directory': r'C:\Slovofon'},
      {'kind': 'setup', 'scope': 'user', 'directory': r'.\Slovofon'},
      {'kind': 'msi', 'directory': r'C:\Slovofon" /silent'},
      {'kind': 'other', 'directory': r'C:\Slovofon'},
      {'kind': 'portable', 'directory': 123},
    ]) {
      test('malformed platform context fails closed: $raw', () {
        expect(
          WindowsUpdateInstallation.fromPlatformValue(raw).kind,
          WindowsInstallKind.unknown,
        );
      });
    }

    test('portable and MSI context do not inherit Setup scope', () {
      for (final kind in ['portable', 'msi']) {
        final context = WindowsUpdateInstallation.fromPlatformValue({
          'kind': kind,
          'scope': 'machine',
          'directory': r'E:\Slovofon',
        });
        expect(context.kind.name, kind);
        expect(context.scope, isNull);
      }
    });

    test('other platforms never invoke Windows detection', () async {
      final installer = PlatformUpdateInstaller(
        operatingSystem: 'android',
        windowsInstallationProvider: () async =>
            throw StateError('Windows detection must not run on Android'),
      );
      expect(
        (await installer.windowsInstallation()).kind,
        WindowsInstallKind.unknown,
      );
    });
  });

  group('Windows update launch', () {
    for (final scope in WindowsInstallScope.values) {
      test('Setup preserves ${scope.name} scope and exact directory', () async {
        final launches = <_Launch>[];
        final installer = _installer(
          _installation(WindowsInstallKind.setup, scope: scope),
          launches,
        );
        final update = _update(UpdateAssetKind.installer);

        await installer.install(update);

        expect(launches, hasLength(1));
        expect(launches.single.executable, update.file.path);
        expect(launches.single.arguments, [
          scope == WindowsInstallScope.user ? '/CURRENTUSER' : '/ALLUSERS',
          r'/DIR=D:\My Apps\Словофон',
        ]);
      });
    }

    test(
      'MSI launches absolute system msiexec, interactive without reboot',
      () async {
        final launches = <_Launch>[];
        final installer = _installer(
          _installation(WindowsInstallKind.msi),
          launches,
        );
        final update = _update(UpdateAssetKind.msi);

        await installer.install(update);

        expect(launches, hasLength(1));
        expect(launches.single.executable, r'C:\Windows\System32\msiexec.exe');
        expect(launches.single.arguments, [
          '/i',
          update.file.path,
          '/norestart',
        ]);
      },
    );

    test(
      'portable ZIP only reveals containing folder; does not execute ZIP',
      () async {
        final launches = <_Launch>[];
        final installer = _installer(
          _installation(WindowsInstallKind.portable),
          launches,
        );

        await installer.install(_update(UpdateAssetKind.portable));

        expect(launches, hasLength(1));
        expect(launches.single.executable, r'C:\Windows\explorer.exe');
        expect(launches.single.arguments, [r'C:\Temp\Slovofon update']);
      },
    );

    for (final installationKind in WindowsInstallKind.values) {
      for (final assetKind in [
        UpdateAssetKind.installer,
        UpdateAssetKind.msi,
        UpdateAssetKind.portable,
        UpdateAssetKind.apk,
        UpdateAssetKind.msix,
      ]) {
        final matches = switch (installationKind) {
          WindowsInstallKind.setup => assetKind == UpdateAssetKind.installer,
          WindowsInstallKind.msi => assetKind == UpdateAssetKind.msi,
          WindowsInstallKind.portable => assetKind == UpdateAssetKind.portable,
          WindowsInstallKind.unknown => false,
        };
        if (matches) continue;
        test(
          '${installationKind.name} rejects ${assetKind.name} with no launch',
          () async {
            final launches = <_Launch>[];
            final installer = _installer(
              _installation(installationKind),
              launches,
            );
            await expectLater(
              installer.install(_update(assetKind)),
              throwsA(isA<UpdateInstallException>()),
            );
            expect(launches, isEmpty);
          },
        );
      }
    }

    test('scope-less or malformed Setup cannot launch', () async {
      for (final context in [
        const WindowsUpdateInstallation(
          kind: WindowsInstallKind.setup,
          directory: r'D:\Slovofon',
        ),
        const WindowsUpdateInstallation(
          kind: WindowsInstallKind.setup,
          scope: WindowsInstallScope.user,
          directory: r'D:\Slovofon" /SILENT',
        ),
      ]) {
        final launches = <_Launch>[];
        await expectLater(
          _installer(
            context,
            launches,
          ).install(_update(UpdateAssetKind.installer)),
          throwsA(isA<UpdateInstallException>()),
        );
        expect(launches, isEmpty);
      }
    });

    test('platform, architecture, filename and extension must match', () async {
      for (final update in [
        _update(
          UpdateAssetKind.installer,
          platform: UpdateAssetPlatform.android,
        ),
        _update(UpdateAssetKind.installer, arch: 'arm64'),
        _update(UpdateAssetKind.installer, fileName: 'different-setup.exe'),
        _update(UpdateAssetKind.installer, filePath: r'C:\Temp\setup.msi'),
      ]) {
        final launches = <_Launch>[];
        await expectLater(
          _installer(
            _installation(WindowsInstallKind.setup),
            launches,
          ).install(update),
          throwsA(isA<UpdateInstallException>()),
        );
        expect(launches, isEmpty);
      }
    });

    test(
      'installation context is resolved again immediately before launch',
      () async {
        var reads = 0;
        final launches = <_Launch>[];
        final installer = PlatformUpdateInstaller(
          operatingSystem: 'windows',
          windowsInstallationProvider: () async => ++reads == 1
              ? _installation(WindowsInstallKind.setup)
              : _installation(WindowsInstallKind.portable),
          windowsProcessLauncher: (executable, arguments) async {
            launches.add(_Launch(executable, arguments));
          },
        );
        expect(
          (await installer.windowsInstallation()).kind,
          WindowsInstallKind.setup,
        );

        await expectLater(
          installer.install(_update(UpdateAssetKind.installer)),
          throwsA(isA<UpdateInstallException>()),
        );

        expect(reads, 2);
        expect(launches, isEmpty);
      },
    );

    test(
      'process start failure propagates instead of reporting successful install',
      () async {
        final installer = PlatformUpdateInstaller(
          operatingSystem: 'windows',
          windowsInstallationProvider: () async =>
              _installation(WindowsInstallKind.setup),
          windowsProcessLauncher: (executable, arguments) async {
            throw ProcessException(executable, arguments, 'Launch denied', 5);
          },
        );
        await expectLater(
          installer.install(_update(UpdateAssetKind.installer)),
          throwsA(isA<ProcessException>()),
        );
      },
    );

    test('missing system directory cannot fall back to PATH msiexec', () async {
      final launches = <_Launch>[];
      await expectLater(
        _installer(
          const WindowsUpdateInstallation(
            kind: WindowsInstallKind.msi,
            directory: r'D:\Slovofon',
          ),
          launches,
        ).install(_update(UpdateAssetKind.msi)),
        throwsA(isA<UpdateInstallException>()),
      );
      expect(launches, isEmpty);
    });
  });

  group('existing Android installer bridge', () {
    test(
      'APK installation still uses the native permission and install flow',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(androidChannel, (call) async {
          calls.add(call);
          return call.method == 'canInstallApks' ? true : null;
        });
        final update = _update(
          UpdateAssetKind.apk,
          platform: UpdateAssetPlatform.android,
        );

        await PlatformUpdateInstaller(
          operatingSystem: 'android',
        ).install(update);

        expect(calls.map((call) => call.method), [
          'canInstallApks',
          'installApk',
        ]);
        expect(calls.last.arguments, {'path': update.file.path});
      },
    );

    test(
      'denied APK permission opens Android settings without launching APK',
      () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(androidChannel, (call) async {
          calls.add(call);
          return call.method == 'canInstallApks' ? false : null;
        });

        await expectLater(
          PlatformUpdateInstaller(operatingSystem: 'android').install(
            _update(UpdateAssetKind.apk, platform: UpdateAssetPlatform.android),
          ),
          throwsA(isA<UpdateInstallPermissionRequired>()),
        );

        expect(calls.map((call) => call.method), [
          'canInstallApks',
          'openInstallSettings',
        ]);
      },
    );
  });
}

WindowsUpdateInstallation _installation(
  WindowsInstallKind kind, {
  WindowsInstallScope scope = WindowsInstallScope.user,
}) => WindowsUpdateInstallation(
  kind: kind,
  scope: kind == WindowsInstallKind.setup ? scope : null,
  directory: r'D:\My Apps\Словофон',
  systemDirectory: r'C:\Windows\System32',
  windowsDirectory: r'C:\Windows',
);

PlatformUpdateInstaller _installer(
  WindowsUpdateInstallation installation,
  List<_Launch> launches,
) => PlatformUpdateInstaller(
  operatingSystem: 'windows',
  windowsInstallationProvider: () async => installation,
  windowsProcessLauncher: (executable, arguments) async {
    launches.add(_Launch(executable, arguments));
  },
);

DownloadedUpdate _update(
  UpdateAssetKind kind, {
  UpdateAssetPlatform platform = UpdateAssetPlatform.windows,
  String arch = 'x64',
  String? fileName,
  String? filePath,
}) {
  final suffix = switch (kind) {
    UpdateAssetKind.installer => 'setup.exe',
    UpdateAssetKind.msi => 'msi.msi',
    UpdateAssetKind.portable => 'portable.zip',
    UpdateAssetKind.apk => 'release.apk',
    UpdateAssetKind.msix => 'msix.msix',
    _ => 'unknown.bin',
  };
  final name = 'Slovofon-v1.2.4-windows-x64-$suffix';
  return DownloadedUpdate(
    file: File(filePath ?? 'C:\\Temp\\Slovofon update\\$name'),
    asset: UpdateAsset(
      platform: platform,
      arch: arch,
      kind: kind,
      url: Uri.parse('https://example.test/$name'),
      fileName: fileName ?? name,
      sha256: 'a' * 64,
      size: 1,
    ),
  );
}

class _Launch {
  const _Launch(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}
