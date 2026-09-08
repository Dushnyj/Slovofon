import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final guard = File('tools/release/ReleaseGuard.ps1').absolute.path;
  final runtimeCheck = File(
    'tools/windows/Assert-WindowsRuntime.ps1',
  ).absolute.path;

  Future<ProcessResult> powershell(String command) => Process.run('pwsh', [
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    r"$ErrorActionPreference = 'Stop'; " + command,
  ]);

  String quote(String value) => "'${value.replaceAll("'", "''")}'";

  test(
    'GitHub Actions contains only explicitly triggered release workflow',
    () {
      final workflows = Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where((file) => RegExp(r'\.ya?ml$').hasMatch(file.path))
          .map((file) => file.uri.pathSegments.last)
          .toList();
      expect(workflows, ['release.yml']);
      final workflow = File(
        '.github/workflows/release.yml',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final start = workflow.indexOf('\non:\n');
      final end = workflow.indexOf('\npermissions:\n');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final triggers = workflow.substring(start, end);
      expect(
        RegExp(
          r'^  ([a-z_]+):',
          multiLine: true,
        ).allMatches(triggers).map((match) => match.group(1)).toList(),
        ['workflow_dispatch', 'push'],
      );
      final push = triggers
          .substring(triggers.indexOf('  push:\n'))
          .trimRight();
      expect(push, '  push:\n    tags:\n      - "v*"');
    },
  );

  test('release checks execute native updater and close regression suites', () {
    final workflow = File(
      '.github/workflows/release.yml',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final start = workflow.indexOf('  checks:\n');
    final end = workflow.indexOf('  android-release:\n');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final checks = workflow.substring(start, end);
    expect(checks, contains('runs-on: ubuntu-24.04'));
    expect(checks, contains('run: flutter test'));
    expect(checks, contains('shell: bash'));
    expect(checks, isNot(contains('continue-on-error:')));
    for (final suite in ['policy', 'task']) {
      expect(
        checks,
        contains('windows/runner/tests/windows_installation_${suite}_test.cpp'),
      );
      expect(
        checks,
        contains(
          '-o "\$RUNNER_TEMP/windows-installation-$suite-test"\n'
          '          "\$RUNNER_TEMP/windows-installation-$suite-test"',
        ),
        reason: 'The compiled $suite suite must execute, not just compile.',
      );
    }
    expect(
      checks,
      contains('windows/runner/tests/windows_close_request_test.cpp'),
    );
    expect(
      checks,
      contains(
        '-o "\$RUNNER_TEMP/windows-close-request-test"\n'
        '          "\$RUNNER_TEMP/windows-close-request-test"',
      ),
      reason: 'The native lifecycle suite must execute, not just compile.',
    );
    expect(
      RegExp(
        r'c\+\+ -std=c\+\+17 -Wall -Wextra -Werror -UNDEBUG',
      ).allMatches(checks),
      hasLength(3),
    );
    expect(checks, contains('-Werror -UNDEBUG -pthread'));
  });

  test('release runs Windows-only installer contracts before packaging', () {
    final workflow = File(
      '.github/workflows/release.yml',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final start = workflow.indexOf('  windows-release:\n');
    final end = workflow.indexOf('  publish-release:\n');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final windows = workflow.substring(start, end);
    expect(windows, contains('runs-on: windows-2022'));
    const command =
        'run: flutter test test/platform/windows_installer_contract_test.dart '
        'test/platform/installer_update_url_test.dart';
    final contractTest = windows.indexOf(command);
    final build = windows.indexOf('run: flutter build windows --release');
    expect(contractTest, greaterThanOrEqualTo(0));
    expect(build, greaterThanOrEqualTo(0));
    expect(build, lessThan(contractTest));
    expect(
      windows.indexOf('      - name: Install packaging tools'),
      greaterThan(contractTest),
    );
    expect(windows, isNot(contains('continue-on-error:')));
  });

  test('release packaging pins and verifies the official Inno compiler', () async {
    final workflow = File('.github/workflows/release.yml').readAsStringSync();
    final start = workflow.indexOf('      - name: Install packaging tools');
    final end = workflow.indexOf('      - name: Prepare Windows portable ZIP');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final step = workflow.substring(start, end);
    expect(step, contains('id: packaging'));
    expect(step, isNot(contains('choco install innosetup')));
    expect(
      step,
      contains(
        'https://github.com/jrsoftware/issrc/releases/download/'
        'is-6_7_2/innosetup-6.7.2.exe',
      ),
    );
    expect(
      step,
      contains('Get-FileHash -LiteralPath \$innoSetup -Algorithm SHA256'),
    );
    expect(
      step,
      contains(
        "if (\$hash -ine '9f27f8386e554eb093336a1ca5c2dcacb7dbf04ab020889491d7ac53c38a12ff')",
      ),
    );
    expect(step, contains("throw 'Inno Setup SHA-256 mismatch;"));
    expect(
      step.indexOf('SHA-256 mismatch'),
      lessThan(step.indexOf('Start-Process')),
    );
    for (final flag in [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CURRENTUSER',
      '/PORTABLE=1',
      '/TASKS=""',
      '-WindowStyle Hidden -Wait -PassThru',
    ]) {
      expect(step, contains(flag));
    }
    expect(
      workflow,
      contains('-InnoCompiler "\${{ steps.packaging.outputs.inno_compiler }}"'),
    );

    // Parse the actual workflow script without downloading/installing anything.
    final script = step
        .substring(step.indexOf('        run: |') + '        run: |'.length)
        .split('\n')
        .map(
          (line) => line.startsWith('          ') ? line.substring(10) : line,
        )
        .join('\n');
    final encoded = base64.encode(utf8.encode(script));
    final result = await powershell('''
\$source = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encoded'))
\$tokens = \$null
\$errors = \$null
[Management.Automation.Language.Parser]::ParseInput(\$source, [ref]\$tokens, [ref]\$errors) | Out-Null
if (\$errors.Count -gt 0) { throw (\$errors | Out-String) }
''');
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test(
    'release guard resolves annotated and lightweight refs, failing closed',
    () async {
      final sha = '1' * 40;
      final other = '2' * 40;
      final tagObject = '3' * 40;
      final scenarios = [
        {'refs': '', 'required': false, 'expected': 'missing'},
        {'refs': '', 'required': true, 'expected': 'rejected'},
        {
          'refs': '$sha\trefs/tags/v0.0.6',
          'required': false,
          'expected': 'matched',
        },
        {
          'refs': '$other\trefs/tags/v0.0.6',
          'required': false,
          'expected': 'rejected',
        },
        {
          'refs': '$tagObject\trefs/tags/v0.0.6\n$sha\trefs/tags/v0.0.6^{}',
          'required': true,
          'expected': 'matched',
        },
        {
          'refs': '$tagObject\trefs/tags/v0.0.6\n$other\trefs/tags/v0.0.6^{}',
          'required': false,
          'expected': 'rejected',
        },
        {
          'refs': '$sha\trefs/tags/v0.0.7',
          'required': false,
          'expected': 'rejected',
        },
        {
          'refs': '$sha\trefs/tags/v0.0.6^{}',
          'required': false,
          'expected': 'rejected',
        },
        {'refs': 'malformed', 'required': false, 'expected': 'rejected'},
      ];
      final encoded = base64.encode(utf8.encode(jsonEncode(scenarios)));
      final result = await powershell('''
. ${quote(guard)}
\$cases = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$encoded')) | ConvertFrom-Json
\$outcomes = foreach (\$case in \$cases) {
  try {
    \$found = Assert-ReleaseTagSnapshot -Tag v0.0.6 -ExpectedCommit '$sha' -RemoteRefs \$case.refs -RequireTag:\$case.required
    if (\$found) { 'matched' } else { 'missing' }
  } catch { 'rejected' }
}
ConvertTo-Json -InputObject @(\$outcomes) -Compress
''');
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        jsonDecode('${result.stdout}'.trim()),
        scenarios.map((entry) => entry['expected']).toList(),
      );
    },
  );

  test(
    'remote tag lookup failure prevents the guarded publication callback',
    () async {
      final result = await powershell('''
. ${quote(guard)}
function git { \$global:LASTEXITCODE = 128; return '' }
\$published = \$false
try {
  Assert-RemoteReleaseTag -Tag v0.0.6 -ExpectedCommit '${'1' * 40}' | Out-Null
  \$published = \$true
} catch { }
if (\$published) { throw 'Publication was reached after failed remote lookup.' }
exit 0
''');
      expect(result.exitCode, 0, reason: '${result.stderr}');
    },
  );

  group('app-local Windows CRT import validation', () {
    late Directory fixture;
    setUp(() async {
      fixture = await Directory.systemTemp.createTemp(
        'slovofon-runtime-contract-',
      );
    });
    tearDown(() async {
      await fixture.delete(recursive: true);
    });

    Future<void> binary(String name, List<String> imports) =>
        File('${fixture.path}/$name').writeAsBytes(_peFixture(imports));

    Future<ProcessResult> check() => powershell(
      '& ${quote(runtimeCheck)} -BundleDir ${quote(fixture.path)}',
    );

    test('rejects a missing runtime referenced by the executable', () async {
      await binary('Slovofon.exe', ['KERNEL32.dll', 'MSVCP140.dll']);
      final result = await check();
      expect(result.exitCode, isNot(0));
      expect('${result.stderr}', contains('Slovofon.exe -> MSVCP140.dll'));
    });

    test('accepts complete runtime closure, not just the main EXE', () async {
      await binary('Slovofon.exe', ['MSVCP140.dll']);
      await binary('MSVCP140.dll', ['VCRUNTIME140_1.dll']);
      final incomplete = await check();
      expect(incomplete.exitCode, isNot(0));
      expect(
        '${incomplete.stderr}',
        contains('MSVCP140.dll -> VCRUNTIME140_1.dll'),
      );
      await binary('VCRUNTIME140_1.dll', ['KERNEL32.dll']);
      final complete = await check();
      expect(complete.exitCode, 0, reason: '${complete.stderr}');
    });

    test(
      'checks native plugin imports and rejects malformed binaries',
      () async {
        await binary('Slovofon.exe', ['KERNEL32.dll']);
        await binary('audio_plugin.dll', ['VCRUNTIME140.dll']);
        expect((await check()).exitCode, isNot(0));
        await binary('VCRUNTIME140.dll', []);
        expect((await check()).exitCode, 0);
        await File(
          '${fixture.path}/audio_plugin.dll',
        ).writeAsString('not a PE');
        expect((await check()).exitCode, isNot(0));
      },
    );
  });
}

// Minimal PE32+ image with real import descriptors, RVAs and a section table.
// The validator must follow those tables, rather than find arbitrary DLL text.
Uint8List _peFixture(List<String> imports) {
  final bytes = Uint8List(4096);
  final data = ByteData.sublistView(bytes);
  void u16(int offset, int value) =>
      data.setUint16(offset, value, Endian.little);
  void u32(int offset, int value) =>
      data.setUint32(offset, value, Endian.little);
  u16(0, 0x5a4d);
  u32(0x3c, 0x80);
  u32(0x80, 0x4550);
  u16(0x84, 0x8664);
  u16(0x86, 1);
  u16(0x94, 0xf0);
  u16(0x98, 0x20b);
  u32(0x98 + 112 + 8, imports.isEmpty ? 0 : 0x1000);
  const section = 0x98 + 0xf0;
  u32(section + 12, 0x1000);
  u32(section + 16, 0xe00);
  u32(section + 20, 0x200);
  var nameOffset = 0x600;
  for (var index = 0; index < imports.length; index++) {
    u32(0x200 + index * 20 + 12, 0x1000 + nameOffset - 0x200);
    final name = ascii.encode(imports[index]);
    bytes.setRange(nameOffset, nameOffset + name.length, name);
    nameOffset += name.length + 1;
  }
  return bytes;
}
