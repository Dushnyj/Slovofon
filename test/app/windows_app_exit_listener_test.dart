import 'dart:async';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show MaterialApp, Scaffold, FilledButton;
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
  final binding = _ExitProbeBinding();
  testWidgets(
    'hidden Windows still runs its final provider-unmount frame',
    (tester) async {
      var disposed = false;
      var closed = false;
      var disposedAtClose = false;
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: () async {},
          onExitReady: () async {
            disposedAtClose = disposed;
            closed = true;
          },
          child: _DisposeProbe(onDispose: () => disposed = true),
        ),
      );
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.lifecycle.name,
        SystemChannels.lifecycle.codec.encodeMessage(
          'AppLifecycleState.hidden',
        ),
        null,
      );
      expect(tester.binding.framesEnabled, isFalse);
      final response = _nativeExit(tester);
      await tester.pump();
      await tester.pump();
      expect(await response, isTrue);
      expect(closed, isTrue);
      expect(disposedAtClose, isTrue);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.lifecycle.name,
        SystemChannels.lifecycle.codec.encodeMessage(
          'AppLifecycleState.resumed',
        ),
        null,
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'irreversible close failure blocks app and exposes keyboard retry',
    (tester) async {
      var attempts = 0;
      var userActions = 0;
      var nativeRetryRequests = 0;
      var producerDisposals = 0;
      var producerInitializations = 0;
      binding.onExitRequested = (type, code) {
        nativeRetryRequests++;
        expectSync(type, AppExitType.cancelable);
        expectSync(code, 0);
      };
      addTearDown(() => binding.onExitRequested = null);
      await tester.pumpWidget(
        WindowsAppExitListener(
          retryOnlyOnFailure: true,
          onExitRequested: () async {
            if (++attempts == 1) throw StateError('private disk exception');
          },
          child: _DisposeProbe(
            onInit: () => producerInitializations++,
            onDispose: () => producerDisposals++,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  WindowsAppExitListener.capturePresentation(
                    context,
                    errorTitle: 'Ошибка',
                    errorMessage: 'Не удалось сохранить изменение',
                    retryLabel: 'Повторить',
                    pendingLabel: 'Загрузка',
                  );
                  return Scaffold(
                    body: FilledButton(
                      onPressed: () => userActions++,
                      child: const Text('Underlying action'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      final first = _nativeExit(tester);
      await tester.pump();
      expect(await first, isFalse);
      expect(tester.takeException(), isStateError);
      await tester.pumpAndSettle();
      expect(find.text('Ошибка'), findsOneWidget);
      expect(producerDisposals, 0);
      expect(producerInitializations, 1);
      expect(find.textContaining('private disk'), findsNothing);
      expect(
        tester
            .widget<AbsorbPointer>(find.byType(AbsorbPointer).first)
            .absorbing,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(nativeRetryRequests, 1);
      expect(attempts, 1);
      // The native System.exitApplication handler starts a fresh cancelable
      // System.requestAppExit handshake, whose exit reply actually quits Win32.
      final retried = _platformExit(tester);
      await tester.pumpAndSettle();
      expect(await retried, 'exit');
      expect(attempts, 2);
      expect(userActions, 0);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'unmounts producers only after checkpoint and awaits database close',
    (tester) async {
      final events = <String>[];
      final checkpoint = Completer<void>();
      final database = Completer<void>();
      var approved = false;
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: () async {
            events.add('checkpoint-start');
            await checkpoint.future;
            events.add('checkpoint-end');
          },
          onExitReady: () async {
            events.add('database-close-start');
            await database.future;
            events.add('database-close-end');
          },
          child: _DisposeProbe(
            onDispose: () => events.add('producers-disposed'),
          ),
        ),
      );
      final response = _nativeExit(tester).then((value) {
        approved = value == true;
      });
      await tester.pump();
      expect(events, ['checkpoint-start']);
      expect(find.byType(_DisposeProbe), findsOneWidget);
      expect(
        tester.widget<AbsorbPointer>(find.byType(AbsorbPointer)).absorbing,
        isTrue,
      );
      checkpoint.complete();
      await tester.pump();
      await tester.pump();
      expect(events, [
        'checkpoint-start',
        'checkpoint-end',
        'producers-disposed',
        'database-close-start',
      ]);
      expect(approved, isFalse);
      database.complete();
      await tester.pump();
      await response;
      expect(approved, isTrue);
      expect(events.last, 'database-close-end');
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'failed checkpoint keeps producers mounted and input available',
    (tester) async {
      var disposed = false;
      var databaseClosed = false;
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: () async => throw StateError('checkpoint failed'),
          onExitReady: () async => databaseClosed = true,
          child: _DisposeProbe(onDispose: () => disposed = true),
        ),
      );
      final response = _nativeExit(tester);
      await tester.pump();
      expect(await response, isFalse);
      expect(tester.takeException(), isStateError);
      expect(disposed, isFalse);
      expect(databaseClosed, isFalse);
      expect(
        tester.widget<AbsorbPointer>(find.byType(AbsorbPointer)).absorbing,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'database-close retry does not recreate or redrain producers',
    (tester) async {
      var checkpoints = 0;
      var disposals = 0;
      var closes = 0;
      await tester.pumpWidget(
        WindowsAppExitListener(
          onExitRequested: () async => checkpoints++,
          onExitReady: () async {
            if (++closes == 1) throw StateError('close failed');
          },
          child: _DisposeProbe(onDispose: () => disposals++),
        ),
      );
      final first = _nativeExit(tester);
      await tester.pump();
      await tester.pump();
      expect(await first, isFalse);
      expect(tester.takeException(), isStateError);
      final second = _nativeExit(tester);
      await tester.pump();
      expect(await second, isTrue);
      expect([checkpoints, disposals, closes], [1, 1, 2]);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

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

class _DisposeProbe extends StatefulWidget {
  const _DisposeProbe({
    required this.onDispose,
    this.onInit,
    this.child = const SizedBox(),
  });
  final VoidCallback onDispose;
  final VoidCallback? onInit;
  final Widget child;
  @override
  State<_DisposeProbe> createState() => _DisposeProbeState();
}

class _DisposeProbeState extends State<_DisposeProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The stock test binding intentionally returns cancel without ever sending
/// System.exitApplication to a platform channel. Observe its public native-exit
/// entry point instead of mistaking that test-only suppression for a UI failure.
class _ExitProbeBinding extends AutomatedTestWidgetsFlutterBinding {
  void Function(AppExitType type, int code)? onExitRequested;

  @override
  Future<AppExitResponse> exitApplication(
    AppExitType exitType, [
    int exitCode = 0,
  ]) {
    onExitRequested?.call(exitType, exitCode);
    return super.exitApplication(exitType, exitCode);
  }
}
