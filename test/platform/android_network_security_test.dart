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

  test('Android uses Slovofon Media3 session service for system playback', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('androidx.media3:media3-session'));
    expect(manifest, contains('android:name=".SlovofonMediaSessionService"'));
    expect(manifest, contains('androidx.media3.session.MediaSessionService'));
    expect(
      manifest,
      isNot(contains('com.ryanheise.audioservice.AudioService')),
    );
    expect(
      manifest,
      isNot(contains('com.ryanheise.audioservice.MediaButtonReceiver')),
    );
  });

  test(
    'Android Media3 notification exposes all compact audiobook controls',
    () {
      final provider = File(
        'android/app/src/main/kotlin/com/slovofon/app/'
        'SlovofonMediaNotificationProvider.kt',
      ).readAsStringSync();
      final buttons = File(
        'android/app/src/main/kotlin/com/slovofon/app/SlovofonMediaButtons.kt',
      ).readAsStringSync();
      final player = File(
        'android/app/src/main/kotlin/com/slovofon/app/'
        'SlovofonMediaSessionPlayer.kt',
      ).readAsStringSync();
      final service = File(
        'android/app/src/main/kotlin/com/slovofon/app/'
        'SlovofonMediaSessionService.kt',
      ).readAsStringSync();

      expect(buttons, contains('Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM'));
      expect(buttons, contains('Player.COMMAND_PLAY_PAUSE'));
      expect(buttons, contains('Player.COMMAND_STOP'));
      expect(buttons, contains('Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM'));
      expect(player, contains('Player.COMMAND_SEEK_BACK'));
      expect(player, contains('Player.COMMAND_SEEK_FORWARD'));
      expect(buttons, isNot(contains('CommandButton.ICON_REWIND')));
      expect(buttons, isNot(contains('CommandButton.ICON_FAST_FORWARD')));
      expect(buttons, contains('R.drawable.audio_service_rewind'));
      expect(buttons, contains('R.drawable.audio_service_forward'));
      expect(buttons, contains('CommandButton.ICON_STOP'));
      expect(buttons, contains('CommandButton.SLOT_BACK_SECONDARY'));
      expect(buttons, contains('CommandButton.SLOT_BACK'));
      expect(buttons, contains('CommandButton.SLOT_FORWARD'));
      expect(buttons, contains('CommandButton.SLOT_FORWARD_SECONDARY'));
      expect(provider, contains('override fun addNotificationActions'));
      expect(service, contains('setMediaButtonPreferences'));
      expect(buttons, contains('SessionCommand(ACTION_REWIND'));
      expect(buttons, contains('SessionCommand(ACTION_FORWARD'));
      expect(
        buttons,
        contains('CommandButton.SLOT_OVERFLOW'),
        reason: 'Stop remains available from notification overflow.',
      );
      expect(
        service,
        isNot(contains('setCustomLayout')),
        reason:
            'Custom layout strips legacy previous/next PlaybackState '
            'actions on Android system media cards.',
      );
      expect(
        provider,
        contains('val compactActions = IntArray(mediaButtons.size)'),
      );
      for (var index = 0; index <= 5; index += 1) {
        expect(buttons, contains('compactIndex = $index'));
      }
    },
  );
}
