import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/download_task.dart';
import '../downloads/download_manager.dart';
import '../downloads/download_manager_provider.dart';

const _downloadNetworkChannel = MethodChannel(
  'com.slovofon.app/download_network',
);
const _refreshInterval = Duration(seconds: 3);

/// The Android-only preference is stored in app-private settings. The stream
/// publishes the actual default network, not merely a nearby Wi-Fi connection.
final androidDownloadNetworkProvider =
    StreamProvider<AndroidDownloadNetworkState>(
      (ref) => const EventChannel(
        'com.slovofon.app/download_network_events',
      ).receiveBroadcastStream().map(AndroidDownloadNetworkState.fromEvent),
    );

/// Keep this subscription for the lifetime of the application container. A
/// one-time read would pause Riverpod's event subscription immediately.
ProviderSubscription<void> subscribeToAndroidDownloadNetwork(
  ProviderContainer container,
) => container.listen(_androidDownloadNetworkBindingProvider, (_, _) {});

final _androidDownloadNetworkBindingProvider = Provider<void>((ref) {
  final manager = ref.read(downloadManagerProvider);
  Timer? recoveryTimer;
  var eventRevision = 0;
  var reading = false;
  var disposed = false;

  Future<void> refreshBlockedQueue() async {
    if (reading) return;
    final revision = eventRevision;
    reading = true;
    try {
      final snapshot = await _downloadNetworkChannel
          .invokeMethod<Object?>('refresh')
          .timeout(_refreshInterval);
      // The push path takes precedence if it got a new status while the
      // request was in flight. A missing answer must not unblock downloads.
      if (disposed || eventRevision != revision || snapshot is! Map) return;
      manager.setNetworkGate(
        AndroidDownloadNetworkState.fromEvent(snapshot).downloadGate,
      );
    } on PlatformException {
      // Retry on the next tick if there are still downloads waiting.
    } on MissingPluginException {
      // Keep the current gate if the native channel is unavailable.
    } on TimeoutException {
      // Don't accumulate in-flight requests while Android is suspended.
    } finally {
      reading = false;
    }
  }

  void refreshTimerForQueue() {
    final waiting =
        manager.networkGate != DownloadNetworkGate.allowed &&
        manager.tasks.any((task) => task.status == DownloadTaskStatus.queued);
    if (waiting) {
      // Some Android builds miss the return-to-Wi-Fi callback. Reconcile only
      // while a queue is blocked, not continuously on an idle phone.
      recoveryTimer ??= Timer.periodic(
        _refreshInterval,
        (_) => unawaited(refreshBlockedQueue()),
      );
    } else {
      recoveryTimer?.cancel();
      recoveryTimer = null;
    }
  }

  ref.listen(androidDownloadNetworkProvider, (_, next) {
    final revision = ++eventRevision;
    final gate = next.asData?.value.downloadGate ?? DownloadNetworkGate.offline;
    // A ready snapshot can be delivered during provider initialization.
    // Notify the manager after Riverpod has finished that build.
    scheduleMicrotask(() {
      if (!disposed && eventRevision == revision) manager.setNetworkGate(gate);
    });
  }, fireImmediately: true);
  manager.addListener(refreshTimerForQueue);
  refreshTimerForQueue();
  ref.onDispose(() {
    disposed = true;
    recoveryTimer?.cancel();
    manager.removeListener(refreshTimerForQueue);
  });
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
    await _downloadNetworkChannel.invokeMethod<Object?>('setWifiOnly', enabled);
  }
}
