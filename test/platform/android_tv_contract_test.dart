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
      expect(banner, contains('android:src="@drawable/ic_launcher_emblem"'));
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
