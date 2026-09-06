import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final innoSource = File(
    'installer/windows/inno/Slovofon.iss',
  ).readAsStringSync();
  final setup = _innoSection(innoSource, 'Setup');

  group('Windows Setup distribution contracts', () {
    test('keeps the approved identity and native Windows uninstall entry', () {
      expect(setup['appid'], '{{C8CE9579-9F96-40B5-A58C-9726E9F76F89}');
      expect(setup['uninstallable'], 'yes');
      expect(setup['uninstalldisplayname'], '{#AppName}');
      expect(setup['uninstalldisplayicon'], r'{app}\Slovofon.exe');
      expect(setup['apppublisherurl'], 'https://github.com/Dushnyj/Slovofon');
      expect(
        setup['appsupporturl'],
        'https://github.com/Dushnyj/Slovofon/issues',
      );
      expect(
        setup['appupdatesurl'],
        'https://github.com/Dushnyj/Slovofon/releases',
      );
    });

    test(
      'offers install scope and folder without enabling desktop by default',
      () {
        expect(setup['privilegesrequired'], 'lowest');
        expect(setup['privilegesrequiredoverridesallowed'], contains('dialog'));
        expect(
          setup['privilegesrequiredoverridesallowed'],
          contains('commandline'),
        );
        expect(setup['defaultdirname'], r'{autopf}\Slovofon');
        expect(setup['disabledirpage'], 'no');
        final desktop = _innoLines(
          innoSource,
          'Tasks',
        ).singleWhere((line) => line.contains('Name: "desktopicon"'));
        expect(desktop, contains('unchecked'));
        expect(_innoLines(innoSource, 'Icons'), isNotEmpty);
      },
    );

    test(
      'requests graceful close and avoids forced restart and broad deletion',
      () {
        expect(setup['closeapplications'], 'yes');
        expect(setup['restartapplications'], 'no');
        expect(setup['changesassociations'], 'no');
        expect(setup['changesenvironment'], 'no');
        expect(_innoLines(innoSource, 'UninstallDelete'), isEmpty);
        expect(_innoLines(innoSource, 'InstallDelete'), isEmpty);
        expect(innoSource, isNot(contains('DelTree(')));
        expect(innoSource, isNot(contains('taskkill')));
      },
    );

    test('guards downgrade and mixing MSI or another installation scope', () {
      expect(innoSource, contains('GetInstallConflict'));
      expect(innoSource, contains('CheckInstalledVersion'));
      expect(innoSource, contains('IsMsiProductInstalled'));
      expect(innoSource, contains('9C9D9F71-5A2B-4F6D-8C58-9D4C8D2F8B8C'));
      expect(innoSource, contains('DisplayVersion'));
      expect(innoSource, contains('HKCU'));
      expect(innoSource, contains('HKLM64'));
    });

    test(
      'drops Flutter build number from the EXE fallback version comparison',
      () {
        // Flutter's fixed Windows FileVersion is MAJOR.MINOR.PATCH.BUILD. The
        // Setup version is the public three-part version: reinstalling 0.0.7+7
        // must not look like a downgrade from 0.0.7.7 to 0.0.7.0.
        expect(innoSource, contains("ExistingVersion[LastDot] <> '.'"));
        expect(innoSource, contains('Copy(ExistingVersion, 1, LastDot - 1)'));
        expect(
          innoSource,
          isNot(contains('CheckInstalledVersion(ExistingVersion)')),
        );
      },
    );
  });

  group(
    'real WiX source generation without installing anything',
    () {
      late Directory fixture;
      late Directory bundle;
      late Map<String, dynamic> snapshot;
      late Map<String, dynamic> uiSnapshot;
      final generator = File(
        'tools/windows/New-WixInstallerSource.ps1',
      ).absolute.path;
      final icon = File('windows/runner/resources/app_icon.ico').absolute.path;

      Future<ProcessResult> generate({
        String version = '0.0.7',
        String? source,
        String? output,
      }) => Process.run('pwsh', [
        '-NoProfile',
        '-NonInteractive',
        '-File',
        generator,
        '-SourceDir',
        source ?? bundle.path,
        '-OutputPath',
        output ?? p.join(fixture.path, 'output', 'Slovofon.wxs'),
        '-ProductVersion',
        version,
        '-IconPath',
        icon,
      ]);

      setUpAll(() async {
        fixture = await Directory.systemTemp.createTemp(
          'slovofon-installer-test-',
        );
        // Windows CI can expose TEMP through an 8.3 alias (e.g. RUNNER~1),
        // while PowerShell enumerates the same files using their long paths.
        // Canonicalize before deriving any paths so containment and relative
        // component-identity assertions compare the same filesystem spelling.
        fixture = Directory(await fixture.resolveSymbolicLinks());
        bundle = await Directory(
          p.join(fixture.path, 'bundle & пробел'),
        ).create();
        // Minimal, synthetic PE headers are parsed by the runtime validator only.
        // They cannot launch the application, install a product or access data.
        for (final name in [
          'Slovofon.exe',
          'msvcp140.dll',
          'vcruntime140.dll',
          'vcruntime140_1.dll',
        ]) {
          await File(p.join(bundle.path, name)).writeAsBytes(_peFixture());
        }
        await File(p.join(bundle.path, 'debug.pdb')).writeAsString('excluded');
        final assets = await Directory(
          p.join(bundle.path, 'data', 'тест & assets'),
        ).create(recursive: true);
        await File(
          p.join(assets.path, 'book & text.txt'),
        ).writeAsString('fixture');
        final result = await generate();
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        snapshot = await _snapshot(
          p.join(fixture.path, 'output', 'Slovofon.wxs'),
        );
        uiSnapshot = await _snapshot(
          File('installer/windows/wix/SlovofonUI.wxi').absolute.path,
        );
      });

      tearDownAll(() async {
        // Delete only the exact fresh fixture directory, never a computed bundle
        // path, a repository directory, or any installed/user application data.
        final target = await fixture.resolveSymbolicLinks();
        final parent = await Directory.systemTemp.resolveSymbolicLinks();
        if (!p.equals(p.dirname(target), parent) ||
            !p.basename(target).startsWith('slovofon-installer-test-')) {
          throw StateError(
            'Refusing to remove a fixture outside its temp parent',
          );
        }
        await fixture.delete(recursive: true);
      });

      test('keeps product identity and rollback-safe major upgrades', () {
        final package = snapshot['package'] as Map<String, dynamic>;
        expect(package['Name'], 'Slovofon');
        expect(package['Manufacturer'], 'Slovofon Team');
        expect(package['Version'], '0.0.7');
        expect(package['Scope'], 'perMachine');
        expect(package['UpgradeCode'], '9C9D9F71-5A2B-4F6D-8C58-9D4C8D2F8B8C');
        final upgrade = snapshot['majorUpgrade'] as Map<String, dynamic>;
        expect(upgrade['Schedule'], 'afterInstallInitialize');
        expect(upgrade['IgnoreLanguage'], 'yes');
        expect(upgrade['DowngradeErrorMessage'], isNotEmpty);
        expect(upgrade['AllowDowngrades'], isNot('yes'));
      });

      test(
        'formats the launch target before invoking the unelevated action',
        () {
          final actions = (snapshot['customActions'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          final setTarget = actions.singleWhere(
            (action) => action['Id'] == 'SetSlovofonLaunchTarget',
          );
          expect(setTarget['Property'], 'WixUnelevatedShellExecTarget');
          expect(setTarget['Value'], r'[INSTALLFOLDER]Slovofon.exe');
          final launch = actions.singleWhere(
            (action) => action['Id'] == 'LaunchSlovofon',
          );
          expect(launch['BinaryRef'], 'Wix4UtilCA_X64');
          expect(launch['DllEntry'], 'WixUnelevatedShellExec');
          expect(launch['Execute'], 'immediate');
          expect(launch['Impersonate'], 'yes');
          expect(launch['Return'], 'ignore');
          final properties = snapshot['properties'] as Map<String, dynamic>;
          expect(
            properties.containsKey('WixUnelevatedShellExecTarget'),
            isFalse,
          );
          expect(
            properties.containsKey('WIXUI_EXITDIALOGOPTIONALCHECKBOX'),
            isFalse,
            reason: 'Launching must remain opt-in, not checked by default.',
          );
          expect(
            (snapshot['executeActions'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .where(
                  (action) => [
                    'SetSlovofonLaunchTarget',
                    'LaunchSlovofon',
                  ].contains(action['Action']),
                ),
            isEmpty,
            reason: 'Silent installs and removals must not launch the app.',
          );
        },
      );

      test('Finish launches only by consent and always closes afterward', () {
        final events =
            (uiSnapshot['publishes'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .where(
                  (event) =>
                      event['Dialog'] == 'ExitDialog' &&
                      event['Control'] == 'Finish',
                )
                .toList()
              ..sort(
                (left, right) => int.parse(
                  left['Order'] as String,
                ).compareTo(int.parse(right['Order'] as String)),
              );
        expect(events.map((event) => '${event['Event']}:${event['Value']}'), [
          'DoAction:SetSlovofonLaunchTarget',
          'DoAction:LaunchSlovofon',
          'EndDialog:Return',
        ]);
        expect(events.map((event) => event['Order']), ['1', '2', '3']);
        expect(
          events[1]['Condition'],
          'WIXUI_EXITDIALOGOPTIONALCHECKBOX = "1" AND NOT Installed '
          'AND REMOVE <> "ALL" AND NOT ReplacedInUseFiles '
          'AND NOT MsiSystemRebootPending',
          reason: 'Removing only DesktopFeature must not block opt-in launch.',
        );
        expect(events.last['Condition'], anyOf(isNull, '1'));
      });

      test(
        'GenerateOnly preview isolates identities and blocks all execution',
        () async {
          final previewScript = File(
            'tools/windows/New-MsiInstallerPreview.ps1',
          ).absolute.path;
          final result = await Process.run(
            'pwsh',
            [
              '-NoProfile',
              '-NonInteractive',
              '-Command',
              r"$ErrorActionPreference = 'Stop'; [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); "
                  '\$preview = & ${_quote(previewScript)} -GenerateOnly '
                  '-WixCompiler ${_quote(p.join(fixture.path, 'not-installed-wix.exe'))} 6>\$null; '
                  '\$preview | ConvertTo-Json -Compress',
            ],
            stdoutEncoding: utf8,
            stderrEncoding: utf8,
          );
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );
          final preview =
              jsonDecode('${result.stdout}') as Map<String, dynamic>;
          final directory = Directory(preview['Directory'] as String);
          // Delete only this newly generated, exact GUID-named fixture. Never
          // clean the artifacts parent or any other installer-preview output.
          final canonical = await directory.resolveSymbolicLinks();
          final parent = await Directory(
            'artifacts/installer-preview',
          ).resolveSymbolicLinks();
          if (!p.equals(p.dirname(canonical), parent) ||
              !RegExp(r'^[a-f0-9]{32}$').hasMatch(p.basename(canonical))) {
            throw StateError(
              'Preview output escaped its expected fixture parent',
            );
          }
          try {
            final source = preview['Source'] as String;
            expect(p.isWithin(directory.path, source), isTrue);
            expect(File(preview['Msi'] as String).existsSync(), isFalse);
            final generated = await _snapshot(source);
            final package = generated['package'] as Map<String, dynamic>;
            final realPackage = snapshot['package'] as Map<String, dynamic>;
            for (final identity in ['ProductCode', 'UpgradeCode']) {
              expect(package[identity], isNotEmpty);
              expect(package[identity], isNot(realPackage[identity]));
            }
            for (final key in ['components', 'componentSearches']) {
              final realGuids = (snapshot[key] as List<dynamic>)
                  .cast<Map<String, dynamic>>()
                  .map((node) => (node['Guid'] as String).toLowerCase())
                  .toSet();
              final isolated = (generated[key] as List<dynamic>)
                  .cast<Map<String, dynamic>>();
              expect(isolated, isNotEmpty);
              expect(
                isolated
                    .map((node) => (node['Guid'] as String).toLowerCase())
                    .toSet(),
                hasLength(isolated.length),
                reason: 'Preview identities must also be mutually unique.',
              );
              expect(
                isolated.every(
                  (node) => !realGuids.contains(
                    (node['Guid'] as String).toLowerCase(),
                  ),
                ),
                isTrue,
              );
            }
            final registryKeys = (generated['registryKeys'] as List<dynamic>)
                .cast<String>();
            expect(
              registryKeys.any((key) => key.startsWith(r'Software\Slovofon\')),
              isFalse,
            );
            expect(
              registryKeys.any(
                (key) => key.contains('{C8CE9579-9F96-40B5-A58C-9726E9F76F89}'),
              ),
              isFalse,
            );
            final directoryNodes = (generated['directories'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
            expect(
              directoryNodes.singleWhere(
                (node) => node['Id'] == 'INSTALLFOLDER',
              )['Name'],
              'SlovofonInstallerPreview',
            );
            final guard = (generated['customActions'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .singleWhere((node) => node['Id'] == 'BlockPreviewExecution');
            expect(guard['Error'], contains('Installation is disabled'));
            expect(guard['DllEntry'], isNull);
            final guards = (generated['executeActions'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .where((node) => node['Action'] == 'BlockPreviewExecution')
                .toList();
            expect(guards, hasLength(3));
            expect(
              guards.map((node) => node['Sequence']),
              unorderedEquals([
                'InstallExecuteSequence',
                'AdminExecuteSequence',
                'AdvertiseExecuteSequence',
              ]),
            );
            for (final guard in guards) {
              expect(guard['Before'], 'CostInitialize');
              expect(guard['Condition'], '1');
            }
          } finally {
            await Directory(canonical).delete(recursive: true);
          }
        },
      );

      test(
        'registers discoverable uninstall metadata and MSI installation marker',
        () {
          final properties = snapshot['properties'] as Map<String, dynamic>;
          expect(properties['ARPPRODUCTICON'], isNotEmpty);
          expect(properties['ARPINSTALLLOCATION'], '[INSTALLFOLDER]');
          expect(properties['ARPSYSTEMCOMPONENT'], isNull);
          expect(
            properties['ARPHELPLINK'],
            'https://github.com/Dushnyj/Slovofon/issues',
          );
          expect(
            properties['ARPURLINFOABOUT'],
            'https://github.com/Dushnyj/Slovofon',
          );
          expect(
            properties['ARPURLUPDATEINFO'],
            'https://github.com/Dushnyj/Slovofon/releases',
          );
          final marker = (snapshot['registry'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .where((entry) => entry['Key'] == r'Software\Slovofon\Installer');
          final values = {
            for (final entry in marker) entry['Name']: entry['Value'],
          };
          expect(values['Type'], 'msi');
          expect(values['InstallLocation'], '[INSTALLFOLDER]');
          expect(values['Version'], isNotEmpty);
          expect(values['ProductCode'], '[ProductCode]');
          expect(marker.every((entry) => entry['Root'] == 'HKLM'), isTrue);
        },
      );

      test('harvests escaped bundle names, not symbols or user data', () {
        final files = (snapshot['files'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(files, hasLength(5));
        final sources = files.map((file) => file['Source'] as String).toList();
        expect(
          sources.any((source) => source.endsWith('book & text.txt')),
          isTrue,
        );
        expect(sources.any((source) => source.endsWith('.pdb')), isFalse);
        expect(
          sources.every((source) => p.isWithin(bundle.path, source)),
          isTrue,
        );
        expect(snapshot['removeFiles'], isEmpty);
        final directories = (snapshot['standardDirectories'] as List<dynamic>);
        expect(directories, contains('ProgramFiles64Folder'));
        expect(directories, isNot(contains('AppDataFolder')));
        expect(directories, isNot(contains('LocalAppDataFolder')));
        expect(directories, isNot(contains('PersonalFolder')));
      });

      test(
        'preserves file component identities across absolute build paths',
        () async {
          final otherBundle = await Directory(
            p.join(fixture.path, 'second bundle'),
          ).create();
          await for (final entry in bundle.list(
            recursive: true,
            followLinks: false,
          )) {
            final relative = p.relative(entry.path, from: bundle.path);
            if (entry is Directory) {
              await Directory(
                p.join(otherBundle.path, relative),
              ).create(recursive: true);
            } else if (entry is File) {
              final destination = File(p.join(otherBundle.path, relative));
              await destination.parent.create(recursive: true);
              await entry.copy(destination.path);
            }
          }
          final otherOutput = p.join(
            fixture.path,
            'output',
            'Slovofon-second.wxs',
          );
          final result = await generate(
            source: otherBundle.path,
            output: otherOutput,
          );
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );
          final other = await _snapshot(otherOutput);
          List<String> identities(Map<String, dynamic> document, String root) =>
              (document['files'] as List<dynamic>)
                  .cast<Map<String, dynamic>>()
                  .map(
                    (file) =>
                        '${p.relative(file['Source'] as String, from: root)}|'
                        '${file['Id']}|${file['ComponentId']}|${file['ComponentGuid']}',
                  )
                  .toList()
                ..sort();
          expect(
            identities(other, otherBundle.path),
            identities(snapshot, bundle.path),
          );
        },
      );

      test(
        'rejects invalid or XML-injecting MSI versions before writing source',
        () async {
          for (final version in [
            '0.0',
            '0.0.7.1',
            '256.0.1',
            '0.256.1',
            '0.0.65536',
            '0.0.-1',
            '0.0.7" />',
          ]) {
            final output = p.join(
              fixture.path,
              'invalid',
              '${version.hashCode}.wxs',
            );
            final result = await generate(version: version, output: output);
            expect(
              result.exitCode,
              isNot(0),
              reason: 'Accepted invalid version: $version',
            );
            expect(File(output).existsSync(), isFalse, reason: version);
          }
        },
      );

      test('rejects generated output inside the payload directory', () async {
        final output = p.join(bundle.path, 'generated.wxs');
        final result = await generate(output: output);
        expect(result.exitCode, isNot(0));
        expect(File(output).existsSync(), isFalse);
      });

      test(
        'rejects junction traversal instead of harvesting an external tree',
        () async {
          final external = await Directory(
            p.join(fixture.path, 'not part of bundle'),
          ).create();
          final sentinel = await File(
            p.join(external.path, 'must-stay.txt'),
          ).writeAsString('not part of the installer');
          final junction = p.join(bundle.path, 'linked directory');
          final create = await Process.run('pwsh', [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'New-Item -ItemType Junction -Path ${_quote(junction)} '
                '-Target ${_quote(external.path)} -ErrorAction Stop | Out-Null',
          ]);
          expect(create.exitCode, 0, reason: '${create.stderr}');
          try {
            final output = p.join(fixture.path, 'junction-output.wxs');
            final result = await generate(output: output);
            expect(result.exitCode, isNot(0));
            expect(File(output).existsSync(), isFalse);
            expect(await sentinel.readAsString(), 'not part of the installer');
          } finally {
            // Remove only the junction entry, not recursively and not its target.
            // Both paths were constructed within this exact fresh temp fixture.
            if (!p.isWithin(fixture.path, junction) ||
                !p.isWithin(fixture.path, external.path)) {
              throw StateError('Junction path escaped the temporary fixture');
            }
            final remove = await Process.run('pwsh', [
              '-NoProfile',
              '-NonInteractive',
              '-Command',
              'Remove-Item -LiteralPath ${_quote(junction)} -Force -ErrorAction Stop',
            ]);
            expect(remove.exitCode, 0, reason: '${remove.stderr}');
            expect(await sentinel.readAsString(), 'not part of the installer');
          }
        },
      );
    },
    skip: !Platform.isWindows
        ? 'The generator requires Windows PowerShell tooling.'
        : false,
  );
}

Map<String, String> _innoSection(String source, String section) => {
  for (final line in _innoLines(source, section))
    if (line.contains('='))
      line.substring(0, line.indexOf('=')).trim().toLowerCase(): line
          .substring(line.indexOf('=') + 1)
          .trim(),
};

List<String> _innoLines(String source, String section) {
  var active = false;
  final lines = <String>[];
  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trim();
    if (line.startsWith('[') && line.endsWith(']')) {
      active = line.toLowerCase() == '[${section.toLowerCase()}]';
    } else if (active &&
        line.isNotEmpty &&
        !line.startsWith(';') &&
        !line.startsWith('#')) {
      lines.add(line);
    }
  }
  return lines;
}

Future<Map<String, dynamic>> _snapshot(String file) async {
  final quotedPath = _quote(file);
  final result = await Process.run(
    'pwsh',
    [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r"$ErrorActionPreference = 'Stop'; [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); "
          '[xml] \$document = Get-Content -LiteralPath $quotedPath -Raw; '
          r'''
function Attributes($node) {
  $result = @{}
  if ($null -ne $node) { foreach ($attribute in $node.Attributes) { $result[$attribute.Name] = $attribute.Value } }
  return $result
}

$properties = @{}
foreach ($node in $document.SelectNodes("//*[local-name()='Property']")) { $properties[$node.GetAttribute('Id')] = $node.GetAttribute('Value') }
foreach ($node in $document.SelectNodes("//*[local-name()='SetProperty']")) { $properties[$node.GetAttribute('Id')] = $node.GetAttribute('Value') }
$files = @(foreach ($node in $document.SelectNodes("//*[local-name()='File']")) {
  $item = Attributes $node
  $item['ComponentId'] = $node.ParentNode.GetAttribute('Id')
  $item['ComponentGuid'] = $node.ParentNode.GetAttribute('Guid')
  $item
})
@{
  package = Attributes $document.SelectSingleNode("//*[local-name()='Package']")
  majorUpgrade = Attributes $document.SelectSingleNode("//*[local-name()='MajorUpgrade']")
  properties = $properties
  files = $files
  components = @(foreach ($node in $document.SelectNodes("//*[local-name()='Component']")) { Attributes $node })
  componentSearches = @(foreach ($node in $document.SelectNodes("//*[local-name()='ComponentSearch']")) { Attributes $node })
  directories = @(foreach ($node in $document.SelectNodes("//*[local-name()='Directory']")) { Attributes $node })
  registryKeys = @(foreach ($node in $document.SelectNodes("//*[@Key]")) { $node.GetAttribute('Key') })
  customActions = @(foreach ($node in $document.SelectNodes("//*[local-name()='CustomAction']")) { Attributes $node })
  publishes = @(foreach ($node in $document.SelectNodes("//*[local-name()='Publish']")) { Attributes $node })
  executeActions = @(foreach ($node in $document.SelectNodes("//*[local-name()='InstallExecuteSequence' or local-name()='AdminExecuteSequence' or local-name()='AdvertiseExecuteSequence']/*[local-name()='Custom']")) {
    $item = Attributes $node
    $item['Sequence'] = $node.ParentNode.LocalName
    $item
  })
  registry = @(foreach ($node in $document.SelectNodes("//*[local-name()='RegistryValue']")) {
    $item = Attributes $node
    if ($node.ParentNode.LocalName -eq 'RegistryKey') {
      foreach ($key in @('Root', 'Key')) {
        if (-not $item.ContainsKey($key)) { $item[$key] = $node.ParentNode.GetAttribute($key) }
      }
    }
    $item
  })
  removeFiles = @(foreach ($node in $document.SelectNodes("//*[local-name()='RemoveFile']")) { Attributes $node })
  standardDirectories = @(foreach ($node in $document.SelectNodes("//*[local-name()='StandardDirectory']")) { $node.GetAttribute('Id') })
} | ConvertTo-Json -Depth 8 -Compress
''',
    ],
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  return jsonDecode('${result.stdout}') as Map<String, dynamic>;
}

String _quote(String value) => "'${value.replaceAll("'", "''")}'";

Uint8List _peFixture() {
  final bytes = Uint8List(1024);
  final header = ByteData.sublistView(bytes);
  header.setUint16(0, 0x5a4d, Endian.little);
  header.setUint32(0x3c, 0x80, Endian.little);
  header.setUint32(0x80, 0x4550, Endian.little);
  header.setUint16(0x84, 0x8664, Endian.little);
  header.setUint16(0x94, 0xf0, Endian.little);
  header.setUint16(0x98, 0x20b, Endian.little);
  return bytes;
}
