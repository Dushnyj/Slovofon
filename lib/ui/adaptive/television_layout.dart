import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
class TelevisionViewport extends StatelessWidget {
  const TelevisionViewport({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final horizontal = media.size.width * .04;
    final vertical = media.size.height * .04;
    final insets = EdgeInsets.symmetric(
      horizontal: horizontal,
      vertical: vertical,
    );
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: insets,
        child: MediaQuery(
          data: media.copyWith(
            size: Size(
              media.size.width - horizontal * 2,
              media.size.height - vertical * 2,
            ),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
            },
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: child,
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
    super.key,
  });
  final Widget child;
  final double radius;
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
          width: 3,
          color: _focused
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(3), child: widget.child),
    ),
  );
}
