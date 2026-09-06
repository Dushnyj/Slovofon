import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/core/platform/app_device_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AppDeviceProfile.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final television in [false, true]) {
    test(
      'native profile preserves device capabilities: TV=$television',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getDeviceProfile');
          expect(call.arguments, isNull);
          return <String, Object>{
            'isTelevision': television,
            'uiModeType': television ? 4 : 1,
            'hasLeanbackFeature': television,
            'hasTouchscreen': !television,
          };
        });
        final profile = await AppDeviceProfile.detect(
          platform: TargetPlatform.android,
        );
        expect(profile.isTelevision, television);
        expect(profile.uiModeType, television ? 4 : 1);
        expect(profile.hasLeanbackFeature, television);
        expect(profile.hasTouchscreen, !television);
      },
    );
  }

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.iOS,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ]) {
    test('$platform never queries the Android channel', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return {'isTelevision': true};
      });
      final profile = await AppDeviceProfile.detect(platform: platform);
      expect(profile.isTelevision, isFalse);
      expect(profile.hasTouchscreen, isNull);
      expect(calls, 0);
    });
  }

  test('missing embedding channel is a safe non-TV default', () async {
    final profile = await AppDeviceProfile.detect(
      platform: TargetPlatform.android,
    );
    expect(profile.isTelevision, isFalse);
    expect(profile.uiModeType, isNull);
  });

  test('platform failure does not prevent startup', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    final profile = await AppDeviceProfile.detect(
      platform: TargetPlatform.android,
    );
    expect(profile.isTelevision, isFalse);
  });

  for (final payload in <Object?>[
    null,
    'television',
    [true],
    {
      'isTelevision': 'true',
      'uiModeType': '4',
      'hasLeanbackFeature': 1,
      'hasTouchscreen': 'false',
    },
  ]) {
    test(
      'malformed profile is not inferred from display-like values: $payload',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async => payload);
        final profile = await AppDeviceProfile.detect(
          platform: TargetPlatform.android,
        );
        expect(profile.isTelevision, isFalse);
        expect(profile.uiModeType, isNull);
        expect(profile.hasLeanbackFeature, isFalse);
        expect(profile.hasTouchscreen, isNull);
      },
    );
  }

  testWidgets('unresponsive optional channel has a bounded startup wait', (
    tester,
  ) async {
    final reply = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (call) => reply.future);
    final result = AppDeviceProfile.detect(platform: TargetPlatform.android);
    await tester.pump(const Duration(seconds: 3));
    expect((await result).isTelevision, isFalse);
    reply.complete(null);
    await tester.pump();
  });

  test('bootstrap override supplies TV without changing target platform', () {
    final container = ProviderContainer(
      overrides: [
        appDeviceProfileProvider.overrideWithValue(
          const AppDeviceProfile(isTelevision: true, hasTouchscreen: false),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(appDeviceProfileProvider).isTelevision, isTrue);
  });
}
