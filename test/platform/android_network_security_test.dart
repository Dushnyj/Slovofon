import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android allows just_audio localhost proxy for request headers', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final config = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(config, contains('cleartextTrafficPermitted="true"'));
    expect(
      config,
      contains('<domain includeSubdomains="false">127.0.0.1</domain>'),
    );
    expect(
      config,
      contains('<domain includeSubdomains="false">localhost</domain>'),
    );
  });

  test('Android declares Slovofon book deep link intent filter', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
    expect(manifest, contains('android:value="false"'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android:scheme="slovofon"'));
    expect(manifest, contains('android:host="book"'));
  });
}
