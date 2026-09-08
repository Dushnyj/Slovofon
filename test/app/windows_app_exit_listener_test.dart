import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/windows_app_exit_listener.dart';
import 'package:slovofon/services/audio/playback_controller.dart';

import '../services/audio/playback_shutdown_test.dart' show ShutdownTestEngine;

Future<String> _platformExit(WidgetTester tester) async {
  final response = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(
        SystemChannels.platform.name,
        SystemChannels.platform.codec.encodeMethodCall(
          const MethodCall('System.requestAppExit', {'type': 'cancelable'}),
        ),
        null,
      );
  final value = SystemChannels.platform.codec.decodeEnvelope(response!);
  return (value as Map<Object?, Object?>)['response']! as String;
}

void main() {
  testWidgets(
    'Windows platform exit waits for actual controller native disposal',
    (tester) async {
      late ShutdownTestEngine engine;
      late PlaybackController controller;
      // Construct the controller's initial Future.value queues and the engine
      // gates in the same real async zone as the platform handshake below.
      // A completed Future still schedules late listeners in its creation zone;
      // creating it in FakeAsync makes shutdown's first queue await stall while
      // runAsync is waiting, because runAsync cannot flush the fake microtasks.
      await tester.runAsync(() async {
        engine = ShutdownTestEngine([])..disposeGate = Completer<void>();
        controller = PlaybackController(engine: engine);
      });
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: controller.shutdown,
          child: const SizedBox(),
        ),
      );
      // Drive the native lifecycle handshake with real microtasks, not an
      // arbitrary number of frame pumps or a longer fake-clock delay.
      await tester.runAsync(() async {
        var firstCompleted = false;
        var secondCompleted = false;
        final first = _platformExit(tester).then((value) {
          firstCompleted = true;
          return value;
        });
        final second = _platformExit(tester).then((value) {
          secondCompleted = true;
          return value;
        });
        try {
          await engine.disposalStarted.future.timeout(
            const Duration(seconds: 5),
          );
          expect(engine.disposals, 1);
          expect(firstCompleted, isFalse);
          expect(secondCompleted, isFalse);
        } finally {
          engine.disposeGate!.complete();
        }
        expect(
          await Future.wait([
            first,
            second,
          ]).timeout(const Duration(seconds: 5)),
          ['exit', 'exit'],
        );
        expect(engine.disposals, 1);
        expect(engine.events, ['dispose-start', 'dispose-end']);
      });
      controller.dispose();
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'failed shutdown cancels platform exit and the next request retries',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: () {
            attempts++;
            if (attempts == 1) throw StateError('checkpoint failed');
            return Future<void>.value();
          },
          child: const SizedBox(),
        ),
      );
      final first = _platformExit(tester);
      await tester.pump();
      expect(await first, 'cancel');
      expect(tester.takeException(), isStateError);
      final second = _platformExit(tester);
      await tester.pump();
      expect(await second, 'exit');
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform does not tear down background audio on lifecycle exit',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          WindowsAppExitListener(
            onExitRequested: () async => calls++,
            child: const SizedBox(),
          ),
        );
        final response = _platformExit(tester);
        await tester.pump();
        expect(await response, 'exit');
        expect(calls, 0);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
