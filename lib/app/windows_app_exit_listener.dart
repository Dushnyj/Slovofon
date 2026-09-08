import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Handles the main runner's WM_CLOSE bridge and Flutter's framework exit API.
/// The explicit bridge is needed because Windows MediaPlayer owns a hidden
/// top-level HWND, preventing Flutter's last-window-only exit callback.
/// This is deliberately not registered on Android: hiding its activity must
/// not tear down background playback. Forced termination/session-end is not a
/// cancelable WM_CLOSE and cannot be made safe by a Dart lifecycle callback.
class WindowsAppExitListener extends StatefulWidget {
  const WindowsAppExitListener({
    required this.onExitRequested,
    required this.child,
    this.onExitReady,
    this.retryOnlyOnFailure = false,
    super.key,
  });

  final Future<void> Function() onExitRequested;

  /// Runs after successful checkpoints and after [child] has been unmounted.
  /// The lifecycle channel remains alive while database isolates are closed.
  final Future<void> Function()? onExitReady;

  /// True when a participant has irreversibly quiesced native resources.
  /// A failed close then offers only retry, never re-enables dead services.
  final bool retryOnlyOnFailure;
  final Widget child;

  static bool isClosing(BuildContext context) =>
      context
          .findAncestorStateOfType<_WindowsAppExitListenerState>()
          ?._closing ??
      false;

  /// Capture resolved presentation under MaterialApp, before its provider
  /// subtree is released. No BuildContext or provider reference is retained.
  static void capturePresentation(
    BuildContext context, {
    required String errorTitle,
    required String errorMessage,
    required String retryLabel,
    required String pendingLabel,
  }) {
    final state = context
        .findAncestorStateOfType<_WindowsAppExitListenerState>();
    if (state == null || state._listener == null) return;
    state._presentation = _ExitPresentation(
      theme: Theme.of(context),
      mediaQuery: MediaQuery.of(context),
      direction: Directionality.of(context),
      errorTitle: errorTitle,
      errorMessage: errorMessage,
      retryLabel: retryLabel,
      pendingLabel: pendingLabel,
    );
  }

  @override
  State<WindowsAppExitListener> createState() => _WindowsAppExitListenerState();
}

class _WindowsAppExitListenerState extends State<WindowsAppExitListener> {
  static const _nativeChannel = MethodChannel(
    'com.slovofon.app/windows_lifecycle',
  );
  AppLifecycleListener? _listener;
  Future<AppExitResponse>? _pendingExit;
  bool _closing = false;
  bool _released = false;
  bool _failed = false;
  _ExitPresentation? _presentation;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _nativeChannel.setMethodCallHandler(_handleNativeMethod);
      _listener = AppLifecycleListener(onExitRequested: _requestExit);
    }
  }

  Future<bool> _handleNativeMethod(MethodCall call) async {
    if (call.method != 'requestExit') throw MissingPluginException();
    final response = await _requestExit();
    return mounted && response == AppExitResponse.exit;
  }

  Future<AppExitResponse> _requestExit() {
    final pending = _pendingExit;
    if (pending != null) return pending;
    if (mounted) {
      setState(() {
        _closing = true;
        _failed = false;
      });
    }
    return _pendingExit = _prepareExit();
  }

  Future<void> _retryExit() async {
    try {
      // The previous WM_CLOSE already received cancel. Start a new *native*
      // cancelable request; merely awaiting _requestExit would discard its
      // result in this button callback and leave an empty window alive.
      await ServicesBinding.instance.exitApplication(AppExitType.cancelable);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'slovofon lifecycle',
          context: ErrorDescription('while retrying Windows application exit'),
        ),
      );
    }
  }

  Future<AppExitResponse> _prepareExit() async {
    try {
      if (!_released) {
        await Future<void>.sync(widget.onExitRequested);
        if (widget.onExitReady != null && mounted) {
          setState(() => _released = true);
          // Unmount producers before closing Drift, not during VM teardown.
          // Minimized/hidden Windows disables ordinary scheduled frames. The
          // final unmount still needs one frame, without showing the window.
          WidgetsBinding.instance.scheduleForcedFrame();
          await WidgetsBinding.instance.endOfFrame;
        }
      }
      await widget.onExitReady?.call();
      return mounted ? AppExitResponse.exit : AppExitResponse.cancel;
    } catch (error, stack) {
      _pendingExit = null;
      if (mounted) {
        setState(() {
          _closing = widget.retryOnlyOnFailure || _released;
          _failed = true;
        });
      }
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
    if (_listener != null) _nativeChannel.setMethodCallHandler(null);
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_listener == null) return widget.child;
    final application = Semantics(
      blockUserActions: _closing,
      child: ExcludeFocus(
        excluding: _closing,
        child: AbsorbPointer(
          absorbing: _closing,
          child: _released ? const SizedBox.expand() : widget.child,
        ),
      ),
    );
    final presentation = _presentation;
    // Keep the provider subtree at the same element position when a pending
    // overlay appears; changing this root from Semantics to Stack would dispose
    // and recreate the entire app before its checkpoints had completed.
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        application,
        if ((widget.retryOnlyOnFailure || _released) &&
            _closing &&
            presentation != null)
          _ExitOverlay(
            presentation: presentation,
            failed: _failed,
            retry: _retryExit,
          ),
      ],
    );
  }
}

class _ExitPresentation {
  const _ExitPresentation({
    required this.theme,
    required this.mediaQuery,
    required this.direction,
    required this.errorTitle,
    required this.errorMessage,
    required this.retryLabel,
    required this.pendingLabel,
  });
  final ThemeData theme;
  final MediaQueryData mediaQuery;
  final TextDirection direction;
  final String errorTitle;
  final String errorMessage;
  final String retryLabel;
  final String pendingLabel;
}

class _ExitOverlay extends StatelessWidget {
  const _ExitOverlay({
    required this.presentation,
    required this.failed,
    required this.retry,
  });
  final _ExitPresentation presentation;
  final bool failed;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final colors = presentation.theme.colorScheme;
    return Shortcuts(
      shortcuts: WidgetsApp.defaultShortcuts,
      child: Actions(
        actions: WidgetsApp.defaultActions,
        child: Theme(
          data: presentation.theme,
          child: MediaQuery(
            data: presentation.mediaQuery,
            child: Directionality(
              textDirection: presentation.direction,
              child: FocusScope(
                autofocus: true,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ModalBarrier(
                      dismissible: false,
                      color: colors.scrim.withValues(alpha: .6),
                    ),
                    SafeArea(
                      minimum: const EdgeInsets.all(24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Semantics(
                            scopesRoute: true,
                            explicitChildNodes: true,
                            child: Material(
                              color: colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      failed
                                          ? presentation.errorTitle
                                          : presentation.pendingLabel,
                                      style: presentation
                                          .theme
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    if (failed) ...[
                                      const SizedBox(height: 12),
                                      Text(presentation.errorMessage),
                                      const SizedBox(height: 20),
                                      FilledButton(
                                        autofocus: true,
                                        onPressed: retry,
                                        child: Text(presentation.retryLabel),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
