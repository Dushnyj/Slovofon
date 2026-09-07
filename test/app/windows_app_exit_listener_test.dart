import 'dart:async';

import 'package:flutter/foundation.dart';
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
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets(
    'Windows platform exit waits for actual controller native disposal',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final engine = ShutdownTestEngine([])..disposeGate = Completer<void>();
      final controller = PlaybackController(engine: engine);
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: controller.shutdown,
          child: const SizedBox(),
        ),
      );
      var firstCompleted = false;
      final first = _platformExit(tester).then((value) {
        firstCompleted = true;
        return value;
      });
      final second = _platformExit(tester);
      await tester.pump();
      expect(engine.disposals, 1);
      expect(firstCompleted, isFalse);
      engine.disposeGate!.complete();
      await tester.pump();
      expect(await first, 'exit');
      expect(await second, 'exit');
      expect(engine.disposals, 1);
      controller.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed shutdown cancels platform exit and the next request retries',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
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
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform does not tear down background audio on lifecycle exit',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
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
    );
  }
}
