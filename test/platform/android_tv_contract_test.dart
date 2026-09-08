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
    final launcherActivity = RegExp(
      r'<activity\b[^>]*android:name="\.MainActivity"[^>]*>',
    ).firstMatch(manifest)?.group(0);
    expect(launcherActivity, isNotNull);
    expect(launcherActivity, contains('android:label="@string/app_name"'));
    expect(launcherActivity, contains('android:icon="@mipmap/ic_launcher"'));
    expect(launcherActivity, contains('android:banner="@drawable/tv_banner"'));
    expect(manifest, isNot(contains('android:screenOrientation=')));
  });

  test('native banners preserve approved emblem and localized wordmarks', () {
    for (final variant in [
      ('drawable', 'Slovofon'),
      ('drawable-ru', 'Словофон'),
      ('drawable-v26', 'Slovofon'),
      ('drawable-ru-v26', 'Словофон'),
    ]) {
      final banner = File(
        'android/app/src/main/res/${variant.$1}/tv_banner.xml',
      ).readAsStringSync();
      expect(banner, contains('Product name: ${variant.$2}.'));
      expect(banner, contains('android:viewportWidth="320"'));
      expect(banner, contains('android:viewportHeight="180"'));
      // 160x90 dp = 320x180 px at xhdpi, not the previous oversized 320x180 dp.
      expect(banner, contains('android:width="160dp"'));
      expect(banner, contains('android:height="90dp"'));
      expect(banner, contains('assets/app/slovofon_icon.png'));
      expect(banner, contains('android:src="@drawable/tv_launcher_emblem"'));
      expect(banner, contains('android:fillColor="#071F32"'));
      expect(banner, isNot(contains('android_adaptive_icon_foreground.svg')));
      expect(banner, isNot(contains('M84,132')));
      expect(banner, isNot(contains('android:width="320dp"')));
      if (variant.$1.endsWith('-v26')) {
        expect(banner, contains('android:insetLeft="2.5%"'));
        expect(banner, contains('android:insetRight="57.5%"'));
      } else {
        // API 24-25 InsetDrawable cannot inflate fractional values.
        expect(banner, isNot(contains('<inset')));
        expect(banner, contains('android:width="64dp"'));
      }
      // Outlined localized wordmark: no dynamic/system-font dependency at runtime.
      expect(RegExp('<path\\b').allMatches(banner).length, 2);
      expect(banner, isNot(contains('android:src="http')));
    }
  });

  test('TV emblem is prefiltered from master at each 64dp density', () {
    for (final density in {
      'mdpi': 64,
      'hdpi': 96,
      'xhdpi': 128,
      'xxhdpi': 192,
      'xxxhdpi': 256,
    }.entries) {
      final bytes = File(
        'android/app/src/main/res/drawable-${density.key}/tv_launcher_emblem.png',
      ).readAsBytesSync();
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      int dimension(int offset) =>
          bytes[offset] * 0x1000000 +
          bytes[offset + 1] * 0x10000 +
          bytes[offset + 2] * 0x100 +
          bytes[offset + 3];
      expect(dimension(16), density.value);
      expect(dimension(20), density.value);
    }
    final generator = File(
      'android/tools/Generate-TvBanner.ps1',
    ).readAsStringSync();
    expect(generator, contains('assets/app/slovofon_icon.png'));
    expect(generator, contains('HighQualityBicubic'));
    expect(generator, contains('Stale TV emblem:'));
    expect(
      File(
        'android/app/src/main/res/drawable-nodpi/ic_launcher_emblem.png',
      ).readAsBytesSync(),
      File('assets/app/slovofon_icon.png').readAsBytesSync(),
      reason: 'Phone adaptive icon must continue to use the unchanged master.',
    );
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
