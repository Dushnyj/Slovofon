import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one APK remains launchable on both phones and Android TV', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final feature in [
      'android.software.leanback',
      'android.hardware.touchscreen',
    ]) {
      final tag = RegExp(
        '<uses-feature\\b[^>]*android:name="$feature"[^>]*/>',
      ).firstMatch(manifest)?.group(0);
      expect(tag, isNotNull, reason: feature);
      expect(tag, contains('android:required="false"'), reason: feature);
    }
    expect(manifest, contains('android.intent.category.LAUNCHER'));
    expect(manifest, contains('android.intent.category.LEANBACK_LAUNCHER'));
    expect(manifest, contains('android:banner="@drawable/tv_banner"'));
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, isNot(contains('android:screenOrientation=')));
  });

  test('native banners preserve product names and existing book artwork', () {
    for (final variant in [
      ('drawable', 'Slovofon'),
      ('drawable-ru', 'Словофон'),
    ]) {
      final banner = File(
        'android/app/src/main/res/${variant.$1}/tv_banner.xml',
      ).readAsStringSync();
      expect(banner, contains('Product name: ${variant.$2}.'));
      expect(banner, contains('android:viewportWidth="320"'));
      expect(banner, contains('android:viewportHeight="180"'));
      expect(banner, contains('android_adaptive_icon_foreground.svg'));
      expect(banner, contains('<group'));
      // Outlined localized wordmark: no dynamic/system-font dependency at runtime.
      expect(RegExp('<path\\b').allMatches(banner).length, 6);
      expect(banner, isNot(contains('android:src="http')));
    }
  });

  test(
    'TV profile channel is available before the app-level Dart entrypoint',
    () {
      final engine = File(
        'android/app/src/main/kotlin/com/slovofon/app/SlovofonFlutterEngine.kt',
      ).readAsStringSync();
      final registration = engine.indexOf(
        'SlovofonDeviceProfileChannel.attach(',
      );
      final entrypoint = engine.indexOf('executeDartEntrypoint(');
      expect(registration, greaterThanOrEqualTo(0));
      expect(entrypoint, greaterThan(registration));
      final profile = File(
        'android/app/src/main/kotlin/com/slovofon/app/SlovofonDeviceProfile.kt',
      ).readAsStringSync();
      expect(profile, contains('com.slovofon.app/device_profile'));
      expect(profile, contains('"getDeviceProfile"'));
      expect(
        profile,
        contains('UI_MODE_TYPE_TELEVISION || hasLeanbackFeature'),
      );
      expect(profile, contains('PackageManager.FEATURE_LEANBACK'));
      expect(profile, contains('Context.UI_MODE_SERVICE'));
      expect(profile, contains('applicationContext'));
    },
  );
}
