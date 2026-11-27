import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/settings/android_download_network.dart';

void main() {
  test(
    'download gate prioritizes offline and requires active Wi-Fi only on opt-in',
    () {
      DownloadNetworkGate gate({
        required bool connected,
        bool wifi = false,
        bool only = false,
      }) => AndroidDownloadNetworkState.fromEvent({
        'connected': connected,
        'wifi': wifi,
        'wifiOnly': only,
      }).downloadGate;
      expect(
        gate(connected: false, wifi: true, only: true),
        DownloadNetworkGate.offline,
      );
      expect(
        gate(connected: true, only: true),
        DownloadNetworkGate.wifiRequired,
      );
      expect(
        gate(connected: true, wifi: true, only: true),
        DownloadNetworkGate.allowed,
      );
      expect(gate(connected: true), DownloadNetworkGate.allowed);
    },
  );
}
