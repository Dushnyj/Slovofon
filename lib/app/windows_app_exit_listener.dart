import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Uses Flutter's Windows WM_CLOSE / System.requestAppExit handshake.
/// This is deliberately not registered on Android: hiding its activity must
/// not tear down background playback. Forced termination/session-end is not a
/// cancelable WM_CLOSE and cannot be made safe by a Dart lifecycle callback.
class WindowsAppExitListener extends StatefulWidget {
  const WindowsAppExitListener({
    required this.onExitRequested,
    required this.child,
    super.key,
  });

  final Future<void> Function() onExitRequested;
  final Widget child;

  @override
  State<WindowsAppExitListener> createState() => _WindowsAppExitListenerState();
}

class _WindowsAppExitListenerState extends State<WindowsAppExitListener> {
  AppLifecycleListener? _listener;
  Future<AppExitResponse>? _pendingExit;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _listener = AppLifecycleListener(onExitRequested: _requestExit);
    }
  }

  Future<AppExitResponse> _requestExit() => _pendingExit ??= _prepareExit();

  Future<AppExitResponse> _prepareExit() async {
    try {
      await Future<void>.sync(widget.onExitRequested);
      return AppExitResponse.exit;
    } catch (error, stack) {
      _pendingExit = null;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'slovofon lifecycle',
          context: ErrorDescription('while preparing Windows application exit'),
        ),
      );
      return AppExitResponse.cancel;
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
