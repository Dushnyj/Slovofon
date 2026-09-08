import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/windows_app_exit_listener.dart';
import 'package:slovofon/services/audio/playback_controller.dart';

import '../services/audio/playback_shutdown_test.dart' show ShutdownTestEngine;

const _nativeChannel = MethodChannel('com.slovofon.app/windows_lifecycle');

Future<Object?> _nativeExit(
  WidgetTester tester, {
  String method = 'requestExit',
}) async {
  final response = await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage(
        _nativeChannel.name,
        _nativeChannel.codec.encodeMethodCall(MethodCall(method)),
        null,
      );
  return response == null
      ? null
      : _nativeChannel.codec.decodeEnvelope(response);
}

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
    'Windows native close and framework exit await the same native disposal',
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
      // Exercise the runner's channel and framework API together. This covers
      // Dart's side of the bridge; actual HWND delivery has separate native QA.
      await tester.runAsync(() async {
        var firstCompleted = false;
        var secondCompleted = false;
        var frameworkCompleted = false;
        final first = _nativeExit(tester).then((value) {
          firstCompleted = true;
          return value;
        });
        final second = _nativeExit(tester).then((value) {
          secondCompleted = true;
          return value;
        });
        final framework = _platformExit(tester).then((value) {
          frameworkCompleted = true;
          return value;
        });
        try {
          await engine.disposalStarted.future.timeout(
            const Duration(seconds: 5),
          );
          expect(engine.disposals, 1);
          expect(firstCompleted, isFalse);
          expect(secondCompleted, isFalse);
          expect(frameworkCompleted, isFalse);
        } finally {
          engine.disposeGate!.complete();
        }
        expect(
          await Future.wait([
            first,
            second,
            framework,
          ]).timeout(const Duration(seconds: 5)),
          [true, true, 'exit'],
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
    'native close cancels on shutdown failure and permits retry',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: () async {
            if (++attempts == 1) throw StateError('checkpoint failed');
          },
          child: const SizedBox(),
        ),
      );
      final first = _nativeExit(tester);
      await tester.pump();
      expect(await first, isFalse);
      expect(tester.takeException(), isStateError);
      final second = _nativeExit(tester);
      await tester.pump();
      expect(await second, isTrue);
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'native handler exists only while the Windows listener is mounted',
    (tester) async {
      expect(await _nativeExit(tester), isNull);
      var calls = 0;
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: () async => calls++,
          child: const SizedBox(),
        ),
      );
      final unsupported = _nativeExit(tester, method: 'unknown');
      await tester.pump();
      expect(await unsupported, isNull);
      expect(calls, 0);
      await tester.pumpWidget(const SizedBox());
      expect(await _nativeExit(tester), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'late native response after listener disposal cannot approve close',
    (tester) async {
      final gate = Completer<void>();
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: () => gate.future,
          child: const SizedBox(),
        ),
      );
      final response = _nativeExit(tester);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pump();
      expect(await response, isFalse);
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
        expect(await _nativeExit(tester), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
