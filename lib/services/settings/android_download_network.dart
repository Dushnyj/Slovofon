import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/download_manager.dart';
import '../downloads/download_manager_provider.dart';

/// The Android-only preference is stored in app-private settings. The stream
/// publishes the actual default network, not merely a nearby Wi-Fi connection.
final androidDownloadNetworkProvider =
    StreamProvider<AndroidDownloadNetworkState>(
      (ref) => const EventChannel(
        'com.slovofon.app/download_network_events',
      ).receiveBroadcastStream().map(AndroidDownloadNetworkState.fromEvent),
    );

final androidDownloadNetworkBindingProvider = Provider<void>((ref) {
  final manager = ref.read(downloadManagerProvider);
  ref.listen(androidDownloadNetworkProvider, (_, next) {
    manager.setNetworkGate(
      next.asData?.value.downloadGate ?? DownloadNetworkGate.offline,
    );
  }, fireImmediately: true);
});

class AndroidDownloadNetworkState {
  const AndroidDownloadNetworkState({
    required this.connected,
    required this.wifi,
    required this.wifiOnly,
  });

  factory AndroidDownloadNetworkState.fromEvent(Object? event) {
    final values = event as Map<Object?, Object?>;
    return AndroidDownloadNetworkState(
      connected: values['connected'] == true,
      wifi: values['wifi'] == true,
      wifiOnly: values['wifiOnly'] == true,
    );
  }

  final bool connected;
  final bool wifi;
  final bool wifiOnly;

  DownloadNetworkGate get downloadGate => !connected
      ? DownloadNetworkGate.offline
      : wifiOnly && !wifi
      ? DownloadNetworkGate.wifiRequired
      : DownloadNetworkGate.allowed;

  static Future<void> setWifiOnly(bool enabled) async {
    await const MethodChannel(
      'com.slovofon.app/download_network',
    ).invokeMethod<Object?>('setWifiOnly', enabled);
  }
}
