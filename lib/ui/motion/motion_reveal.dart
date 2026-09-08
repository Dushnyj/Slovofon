import 'package:flutter/material.dart';

import 'app_motion.dart';

/// A branch change reveals the new content without replacing/re-keying its
/// navigator or scroll state. Playback progress updates do not retrigger it.
class AppContentReveal extends StatefulWidget {
  const AppContentReveal({
    required this.changeKey,
    required this.child,
    super.key,
  });
  final Object changeKey;
  final Widget child;
  @override
  State<AppContentReveal> createState() => _AppContentRevealState();
}

class _AppContentRevealState extends State<AppContentReveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: 1);
  AppMotion? _motion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motion = AppMotion.of(context);
    _controller.duration = _motion!.duration(
      full: const Duration(milliseconds: 180),
    );
    if (_motion!.isOff) _controller.value = 1;
  }

  @override
  void didUpdateWidget(AppContentReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.changeKey != oldWidget.changeKey) {
      if (_motion!.isOff) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _motion!.isOff
            ? 1.0
            : AppMotion.curve.transform(_controller.value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(
              0,
              _motion!.hasSpatialMotion ? 8 * (1 - progress) : 0,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
