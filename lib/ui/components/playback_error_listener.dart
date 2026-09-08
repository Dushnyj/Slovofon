import '../motion/app_motion.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_strings.dart';
import '../../features/shared/source_access_error_text.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller.dart';
import '../../services/audio/playback_controller_provider.dart';

/// Presents playback failures for every route, including commands received
/// outside the player screen. Controller ticks never rebuild [child].
class PlaybackErrorListener extends ConsumerStatefulWidget {
  const PlaybackErrorListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PlaybackErrorListener> createState() =>
      _PlaybackErrorListenerState();
}

typedef _PlaybackErrorIdentity = (String?, String?, String?, int, String?);

class _PlaybackErrorListenerState extends ConsumerState<PlaybackErrorListener> {
  PlaybackController? _controller;
  ProviderSubscription<PlaybackController>? _subscription;
  _PlaybackErrorIdentity? _lastError;
  int _notificationGeneration = 0;
  _PlaybackErrorNotice? _notice;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(
      playbackControllerProvider,
      (_, next) => _attach(next),
      fireImmediately: true,
    );
  }

  void _attach(PlaybackController controller) {
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_onPlaybackChanged);
    _controller = controller;
    _lastError = null;
    final generation = ++_notificationGeneration;
    if (_notice != null) {
      _afterFrame(() {
        if (mounted && generation == _notificationGeneration) _closeSnackBar();
      });
    }
    controller.addListener(_onPlaybackChanged);
    _onPlaybackChanged();
  }

  void _onPlaybackChanged() {
    final controller = _controller;
    if (controller == null) return;
    final state = controller.state;
    if (state.status != AudioPlaybackStatus.error) {
      if (_lastError == null) return;
      _lastError = null;
      final generation = ++_notificationGeneration;
      _afterFrame(() {
        if (mounted && generation == _notificationGeneration) {
          _closeSnackBar();
        }
      });
      return;
    }

    final identity = _identity(state);
    if (_lastError == identity) return;
    _lastError = identity;
    final generation = ++_notificationGeneration;
    _afterFrame(() {
      if (!mounted ||
          generation != _notificationGeneration ||
          !identical(controller, _controller) ||
          controller.state.status != AudioPlaybackStatus.error ||
          _identity(controller.state) != identity) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null || !messenger.mounted) return;
      final strings = context.strings;
      final policyMessage = sourceAccessErrorText(
        strings,
        code: state.errorMessage,
      );
      _closeSnackBar();
      final notice = _PlaybackErrorNotice(messenger);
      _notice = notice;
      final snackBar = messenger.showMotionSnackBar(
        SnackBar(
          // Let ScaffoldMessenger assign a unique SnackBar key, so each notice
          // receives its own onVisible callback even when messages replace it.
          content: Text(
            policyMessage ?? strings.savedBookPlaybackError,
            key: const ValueKey('playback-error-snackbar'),
          ),
          onVisible: notice.onVisible,
          action: policyMessage == null && state.hasBook
              ? SnackBarAction(
                  label: strings.retry,
                  onPressed: () => unawaited(_retry(controller, identity)),
                )
              : null,
        ),
      );
      notice.controller = snackBar;
      unawaited(
        snackBar.closed.then((_) {
          notice.closed = true;
          if (identical(_notice, notice)) _notice = null;
        }),
      );
    });
  }

  Future<void> _retry(
    PlaybackController controller,
    _PlaybackErrorIdentity identity,
  ) async {
    if (!mounted ||
        !identical(controller, _controller) ||
        controller.state.status != AudioPlaybackStatus.error ||
        _identity(controller.state) != identity) {
      return;
    }
    try {
      // play() is the controller's retry path when its current status is error.
      await controller.play();
    } catch (_) {
      // Persistence/engine exceptions never become raw UI messages. If the
      // controller still reports the failed operation, offer its safe message.
      if (mounted && identical(controller, _controller)) {
        _lastError = null;
        _onPlaybackChanged();
      }
    }
  }

  _PlaybackErrorIdentity _identity(AudioPlaybackState state) => (
    state.book?.sourceId,
    state.book?.id,
    state.book?.versionId,
    state.chapterIndex,
    state.errorMessage,
  );

  void _afterFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
    // A native/audio callback can arrive with no frame scheduled. Listening
    // without rebuilding the route must still wake the notification frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _closeSnackBar() {
    final notice = _notice;
    _notice = null;
    notice?.cancel();
  }

  @override
  void dispose() {
    _notificationGeneration++;
    _subscription?.close();
    _controller?.removeListener(_onPlaybackChanged);
    final notice = _notice;
    // Dispose can happen while the framework is building the replacement tree.
    // Close only our notification after that frame, never an unrelated one.
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notice.cancel();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// ScaffoldFeatureController.close() may only close the *current* snackbar.
/// Another feature's message can be ahead of this one in the shared queue.
/// A canceled queued notice waits until it becomes visible before closing;
/// it must never dismiss that unrelated message or assert during teardown.
class _PlaybackErrorNotice {
  _PlaybackErrorNotice(this.messenger);

  final ScaffoldMessengerState messenger;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
  bool closed = false;
  bool _visible = false;
  bool _canceled = false;
  bool _closing = false;

  void cancel() {
    _canceled = true;
    _closeIfVisible();
  }

  void onVisible() {
    _visible = true;
    if (_canceled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _closeIfVisible());
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  void _closeIfVisible() {
    if (_visible && !closed && !_closing && messenger.mounted) {
      _closing = true;
      controller?.close();
    }
  }
}
