import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/settings/android_download_network.dart';

const _networkChannel = MethodChannel('com.slovofon.app/download_network');

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

  testWidgets(
    'the application subscription receives every handoff without a UI watcher',
    (tester) async {
      final fixture = _NetworkFixture();
      try {
        await tester.pump();
        for (final wifi in [true, false, true]) {
          fixture.events.add(
            AndroidDownloadNetworkState(
              connected: true,
              wifi: wifi,
              wifiOnly: true,
            ),
          );
          await tester.pump();
          expect(
            fixture.queue.networkGate,
            wifi
                ? DownloadNetworkGate.allowed
                : DownloadNetworkGate.wifiRequired,
          );
        }
      } finally {
        fixture.dispose();
      }
    },
  );

  testWidgets(
    'an eligible default Wi-Fi snapshot unblocks the queue if the event is missed',
    (tester) async {
      final fixture = _NetworkFixture();
      final calls = <String>[];
      var wifi = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _networkChannel,
        (call) async {
          calls.add(call.method);
          return {'connected': true, 'wifi': wifi, 'wifiOnly': true};
        },
      );
      try {
        await tester.pump();
        fixture.events.add(
          const AndroidDownloadNetworkState(
            connected: true,
            wifi: false,
            wifiOnly: true,
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        expect(fixture.queue.networkGate, DownloadNetworkGate.wifiRequired);
        expect(calls, isEmpty, reason: 'No polling without a queued download.');

        fixture.queue.enqueue();
        await tester.pump(const Duration(seconds: 3, milliseconds: 1));
        await tester.pump();
        expect(calls, ['refresh']);
        expect(fixture.queue.networkGate, DownloadNetworkGate.wifiRequired);

        wifi = true; // Android changed network but did not publish an event.
        await tester.pump(const Duration(seconds: 3, milliseconds: 1));
        await tester.pump();
        expect(calls, ['refresh', 'refresh']);
        expect(fixture.queue.networkGate, DownloadNetworkGate.allowed);

        await tester.pump(const Duration(seconds: 6));
        expect(calls, [
          'refresh',
          'refresh',
        ], reason: 'Reconciliation stops after recovery.');
      } finally {
        fixture.dispose();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _networkChannel,
          null,
        );
      }
    },
  );

  testWidgets(
    'a late Wi-Fi snapshot cannot override a newer disconnect event',
    (tester) async {
      final fixture = _NetworkFixture();
      final pending = Completer<Map<String, bool>>();
      var probes = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _networkChannel,
        (_) {
          probes++;
          return pending.future;
        },
      );
      try {
        await tester.pump();
        fixture.events.add(
          const AndroidDownloadNetworkState(
            connected: true,
            wifi: false,
            wifiOnly: true,
          ),
        );
        fixture.queue.enqueue();
        await tester.pump(const Duration(seconds: 3, milliseconds: 1));
        await tester.pump();
        expect(probes, 1);
        fixture.events.add(
          const AndroidDownloadNetworkState(
            connected: false,
            wifi: false,
            wifiOnly: true,
          ),
        );
        await tester.pump();
        pending.complete({'connected': true, 'wifi': true, 'wifiOnly': true});
        await tester.pump();
        expect(fixture.queue.networkGate, DownloadNetworkGate.offline);
      } finally {
        fixture.dispose();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          _networkChannel,
          null,
        );
      }
    },
  );
}

class _NetworkFixture {
  _NetworkFixture() {
    _container = ProviderContainer(
      overrides: [
        downloadManagerProvider.overrideWith((_) => queue),
        androidDownloadNetworkProvider.overrideWith((_) => events.stream),
      ],
    );
    _subscription = subscribeToAndroidDownloadNetwork(_container);
  }

  final queue = _Queue();
  final events = StreamController<AndroidDownloadNetworkState>();
  late final ProviderContainer _container;
  late final ProviderSubscription<void> _subscription;

  void dispose() {
    _subscription.close();
    _container.dispose();
    unawaited(events.close());
  }
}

class _Queue extends ChangeNotifier implements DownloadManager {
  @override
  DownloadNetworkGate networkGate = DownloadNetworkGate.offline;

  @override
  List<DownloadTask> tasks = const [];

  void enqueue() {
    tasks = [
      DownloadTask(
        id: 'chapter',
        bookId: 'book',
        bookVersionId: 'version',
        sourceId: 'source',
        type: DownloadTaskType.chapter,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
    notifyListeners();
  }

  @override
  void setNetworkGate(DownloadNetworkGate gate) {
    if (networkGate == gate) return;
    networkGate = gate;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
