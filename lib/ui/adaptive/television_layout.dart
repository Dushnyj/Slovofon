import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/app_motion.dart';
import 'television_focus.dart';

/// A device capability, not a width breakpoint: a large tablet is not a TV.
class TelevisionLayout extends InheritedWidget {
  const TelevisionLayout({
    required this.enabled,
    required super.child,
    super.key,
  });
  final bool enabled;
  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TelevisionLayout>()?.enabled ??
      false;
  @override
  bool updateShouldNotify(TelevisionLayout oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Keeps the actual full-screen viewport and maps the remote centre key to the
/// same activation action as Enter. Routes own their content padding; media
/// keys stay native.
class TelevisionViewport extends StatefulWidget {
  const TelevisionViewport({required this.child, super.key});
  final Widget child;
  @override
  State<TelevisionViewport> createState() => _TelevisionViewportState();
}

class _TelevisionViewportState extends State<TelevisionViewport> {
  @override
  void initState() {
    super.initState();
    TelevisionFocusHighlight.acquire();
  }

  @override
  void dispose() {
    TelevisionFocusHighlight.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: MediaQuery(
        data: media.copyWith(
          // Left/right edit a slider; up/down leave it. Preserve real viewport,
          // safe areas, DPR and the system/user text scaler without shrinking.
          navigationMode: NavigationMode.directional,
        ),
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          },
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Clear focus boundary without layout jumps or an extra remote stop. Scrolling
/// the focused tile into view is essential in long lists operated without touch.
class TelevisionFocusFrame extends StatefulWidget {
  const TelevisionFocusFrame({
    required this.child,
    this.radius = 16,
    this.showRestingOutline = true,
    super.key,
  });
  final Widget child;
  final double radius;
  final bool showRestingOutline;
  @override
  State<TelevisionFocusFrame> createState() => _TelevisionFocusFrameState();
}

class _TelevisionFocusFrameState extends State<TelevisionFocusFrame> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (focused) {
      setState(() => _focused = focused);
      if (focused) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted && _focused) {
            // Reveal the complete frame in either direction. End-only
            // alignment leaves the top border cut when moving upwards.
            await Scrollable.ensureVisible(
              context,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
            );
            if (!mounted || !context.mounted || !_focused) return;
            await Scrollable.ensureVisible(
              context,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          }
        });
      }
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        animationDuration: AppMotion.of(context).duration(),
        // Ink from ListTile (selected, focus, hover and press) must paint on
        // this same rounded surface, not on a distant rectangular ancestor.
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.radius),
          side: BorderSide(
            width: _focused ? 2 : (widget.showRestingOutline ? 1 : 0),
            color: _focused
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant.withValues(
                    alpha: widget.showRestingOutline ? 1 : 0,
                  ),
          ),
        ),
        child: widget.child,
      ),
    ),
  );
}
