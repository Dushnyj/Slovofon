import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/deep_links/app_deep_links.dart';

const _channel = MethodChannel('com.slovofon.app/windows_activation');
const _linkA = 'slovofon://book?source=izib&book=4331';
const _linkB = 'slovofon://book?source=akniga&book=Белые%20ночи';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;

  Future<void> notify() async {
    final completed = Completer<void>();
    await messenger.handlePlatformMessage(
      _channel.name,
      _channel.codec.encodeMethodCall(const MethodCall('activationAvailable')),
      (_) => completed.complete(),
    );
    await completed.future;
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    _channel.setMethodCallHandler(null);
  });

  test('initial URI preserves source and Unicode book argument', () async {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      expect(call.method, 'getInitialArguments');
      return [_linkB];
    });
    final source = WindowsActivationDeepLinkSource();
    expect(await source.getInitialLink(), Uri.parse(_linkB));
  });

  test(
    'initial non-book, multiple and malformed arguments do not navigate',
    () async {
      for (final arguments in <Object?>[
        null,
        [],
        ['--delete'],
        ['https://example.com'],
        [_linkA, '--anything'],
        [123],
        ['slovofon://book?source=izib&book=%FF'],
        ['slovofon://book?source=izib&book=a\u0000b'],
        ['a' * 65537],
      ]) {
        messenger.setMockMethodCallHandler(_channel, (_) async => arguments);
        expect(
          await WindowsActivationDeepLinkSource().getInitialLink(),
          isNull,
        );
      }
    },
  );

  test(
    'early repeated launches are drained on subscription in FIFO order',
    () async {
      var queue = <List<String>>[
        [_linkA],
        [_linkB],
      ];
      var calls = 0;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'stopListening') return null;
        expect(call.method, 'takePendingActivations');
        calls++;
        final pending = queue;
        queue = [];
        return pending;
      });
      final received = <Uri>[];
      final subscription = WindowsActivationDeepLinkSource().links.listen(
        received.add,
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, [Uri.parse(_linkA), Uri.parse(_linkB)]);
      await notify();
      await Future<void>.delayed(Duration.zero);
      expect(
        received,
        hasLength(2),
        reason: 'No duplicate when the queue is empty.',
      );
      expect(calls, 2);
      await subscription.cancel();
    },
  );

  test(
    'concurrent notification retries drain without reordering activations',
    () async {
      final first = Completer<Object?>();
      var drains = 0;
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'stopListening') return null;
        drains++;
        return drains == 1
            ? first.future
            : [
                [_linkB],
              ];
      });
      final received = <Uri>[];
      final subscription = WindowsActivationDeepLinkSource().links.listen(
        received.add,
      );
      await Future<void>.delayed(Duration.zero);
      await notify();
      first.complete([
        [_linkA],
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(received, [Uri.parse(_linkA), Uri.parse(_linkB)]);
      expect(drains, 2);
      await subscription.cancel();
    },
  );

  test(
    'shortcut and unsupported arguments leave the current book untouched',
    () async {
      messenger.setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'stopListening') return null;
        return [
          [],
          ['--anything'],
          ['https://example.com'],
          [_linkA],
        ];
      });
      final received = <Uri>[];
      final subscription = WindowsActivationDeepLinkSource().links.listen(
        received.add,
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, [Uri.parse(_linkA)]);
      await subscription.cancel();
    },
  );

  test('cancel unregisters handler and late drain cannot navigate', () async {
    final pending = Completer<Object?>();
    var stopped = false;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'stopListening') {
        stopped = true;
        return null;
      }
      return pending.future;
    });
    final received = <Uri>[];
    final subscription = WindowsActivationDeepLinkSource().links.listen(
      received.add,
    );
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    pending.complete([
      [_linkA],
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isTrue);
    expect(received, isEmpty);
  });

  test(
    'older runner falls back to app_links initial and live source',
    () async {
      messenger.setMockMethodCallHandler(_channel, null);
      final fallback = _Fallback();
      final source = WindowsActivationDeepLinkSource(fallback: fallback);
      expect(await source.getInitialLink(), Uri.parse(_linkA));
      final received = <Uri>[];
      final subscription = source.links.listen(received.add);
      await Future<void>.delayed(Duration.zero);
      fallback.controller.add(Uri.parse(_linkB));
      await Future<void>.delayed(Duration.zero);
      expect(received, [Uri.parse(_linkB)]);
      await subscription.cancel();
      await fallback.controller.close();
    },
  );

  test(
    'replacing the listener stops the old bridge before enabling the new',
    () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(_channel, (call) async {
        calls.add(call.method);
        return call.method == 'takePendingActivations' ? [] : null;
      });
      final old = WindowsActivationDeepLinkSource().links.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      final cancelled = old.cancel();
      final replacement = WindowsActivationDeepLinkSource().links.listen(
        (_) {},
      );
      await cancelled;
      await Future<void>.delayed(Duration.zero);
      expect(calls, [
        'takePendingActivations',
        'stopListening',
        'takePendingActivations',
      ]);
      await replacement.cancel();
    },
  );
}

class _Fallback implements AppDeepLinkSource {
  final controller = StreamController<Uri>();

  @override
  Future<Uri?> getInitialLink() async => Uri.parse(_linkA);

  @override
  Stream<Uri> get links => controller.stream;
}
