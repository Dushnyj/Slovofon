import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app_version.dart';

void main() {
  test('AppVersion matches VERSION and pubspec build metadata', () {
    final publicVersion = File('VERSION').readAsStringSync().trim();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final pubspecVersion = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(pubspecVersion, isNotNull);
    expect(AppVersion.version, publicVersion);
    expect(AppVersion.version, pubspecVersion!.group(1));
    expect(AppVersion.buildNumber, pubspecVersion.group(2));
  });
}
