import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Native device identity is independent of window size and text scale.
/// Bootstrap overrides this provider before runApp; tests may supply a TV.
final appDeviceProfileProvider = Provider<AppDeviceProfile>(
  (ref) => const AppDeviceProfile(),
);

@immutable
class AppDeviceProfile {
  const AppDeviceProfile({
    this.isTelevision = false,
    this.uiModeType,
    this.hasLeanbackFeature = false,
    this.hasTouchscreen,
  });

  final bool isTelevision;
  final int? uiModeType;
  final bool hasLeanbackFeature;
  final bool? hasTouchscreen;

  static const channelName = 'com.slovofon.app/device_profile';

  static Future<AppDeviceProfile> detect({
    MethodChannel channel = const MethodChannel(channelName),
    TargetPlatform? platform,
  }) async {
    if (kIsWeb ||
        (platform ?? defaultTargetPlatform) != TargetPlatform.android) {
      return const AppDeviceProfile();
    }
    try {
      final data = await channel
          .invokeMethod<Object?>('getDeviceProfile')
          .timeout(const Duration(seconds: 2));
      if (data is! Map<Object?, Object?>) {
        return const AppDeviceProfile();
      }
      final mode = data['uiModeType'];
      final touch = data['hasTouchscreen'];
      return AppDeviceProfile(
        isTelevision: data['isTelevision'] == true,
        uiModeType: mode is int ? mode : null,
        hasLeanbackFeature: data['hasLeanbackFeature'] == true,
        hasTouchscreen: touch is bool ? touch : null,
      );
    } on MissingPluginException {
      return const AppDeviceProfile();
    } on PlatformException {
      return const AppDeviceProfile();
    } on TimeoutException {
      // Old embeddings/test hosts may not implement the optional channel.
      // A failed capability query must not prevent ordinary phone startup.
      return const AppDeviceProfile();
    }
  }
}
