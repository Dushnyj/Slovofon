import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/audio/playback_controller_provider.dart';
import 'desktop_layout.dart';

/// App-local Windows keys, installed once around the Navigator by the app.
/// Native media keys remain owned by the operating system media session.
class WindowsPlaybackShortcuts extends ConsumerWidget {
  const WindowsPlaybackShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DesktopLayout.isActive(context)) return child;
    return Focus(
      debugLabel: 'Windows playback shortcuts',
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: (_, event) => _handleKey(ref, event),
      child: child,
    );
  }

  KeyEventResult _handleKey(WidgetRef ref, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext != null &&
        (focusedContext.widget is EditableText ||
            focusedContext.findAncestorWidgetOfExactType<EditableText>() !=
                null)) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    final command = switch (event.logicalKey) {
      LogicalKeyboardKey.space
          when !keyboard.isControlPressed &&
              !keyboard.isAltPressed &&
              !keyboard.isMetaPressed &&
              !keyboard.isShiftPressed =>
        _PlaybackKey.toggle,
      LogicalKeyboardKey.arrowLeft
          when keyboard.isControlPressed &&
              !keyboard.isAltPressed &&
              !keyboard.isMetaPressed &&
              !keyboard.isShiftPressed =>
        _PlaybackKey.rewind,
      LogicalKeyboardKey.arrowRight
          when keyboard.isControlPressed &&
              !keyboard.isAltPressed &&
              !keyboard.isMetaPressed &&
              !keyboard.isShiftPressed =>
        _PlaybackKey.forward,
      LogicalKeyboardKey.arrowLeft
          when keyboard.isAltPressed &&
              !keyboard.isControlPressed &&
              !keyboard.isMetaPressed &&
              !keyboard.isShiftPressed =>
        _PlaybackKey.previous,
      LogicalKeyboardKey.arrowRight
          when keyboard.isAltPressed &&
              !keyboard.isControlPressed &&
              !keyboard.isMetaPressed &&
              !keyboard.isShiftPressed =>
        _PlaybackKey.next,
      _ => null,
    };
    if (command == null) return KeyEventResult.ignored;

    // Space must still activate a focused button/checkbox, not unexpectedly
    // toggle audio while the user is operating another control or a dialog.
    if (command == _PlaybackKey.toggle && focusedContext != null) {
      final activate = Actions.maybeFind<ActivateIntent>(focusedContext);
      if (activate?.isEnabled(const ActivateIntent()) ?? false) {
        return KeyEventResult.ignored;
      }
    }

    final playback = ref.read(playbackControllerProvider);
    if (!playback.state.hasBook) return KeyEventResult.ignored;
    unawaited(switch (command) {
      _PlaybackKey.toggle => playback.togglePlayPause(),
      _PlaybackKey.rewind => playback.skipBy(const Duration(seconds: -15)),
      _PlaybackKey.forward => playback.skipBy(const Duration(seconds: 15)),
      _PlaybackKey.previous => playback.previousChapter(),
      _PlaybackKey.next => playback.nextChapter(),
    });
    return KeyEventResult.handled;
  }
}

enum _PlaybackKey { toggle, rewind, forward, previous, next }
