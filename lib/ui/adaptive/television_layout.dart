import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'television_focus.dart';
import 'television_metrics.dart';

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

/// Keeps all routes (including dialogs) away from overscan, and maps the remote
/// centre key to the same activation action as Enter. Media keys stay native.
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
    final insets = TelevisionMetrics.safeInsetsFor(media.size);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: insets,
        child: MediaQuery(
          data: media.copyWith(
            size: Size(
              media.size.width - insets.horizontal,
              media.size.height - insets.vertical,
            ),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            // Left/right edit a slider; up/down leave it. Keep the actual DPR
            // and system/user text scaler unchanged.
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _focused) {
            Scrollable.ensureVisible(
              context,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          }
        });
      }
    },
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(
          width: _focused ? 2 : (widget.showRestingOutline ? 1 : 0),
          color: _focused
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant.withValues(
                  alpha: widget.showRestingOutline ? 1 : 0,
                ),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(2), child: widget.child),
    ),
  );
}
