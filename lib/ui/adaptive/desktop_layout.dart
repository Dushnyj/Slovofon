import 'package:flutter/material.dart';

/// Windows presentation stays desktop even on a small, high-DPI work area.
/// Width controls the desktop arrangement, not the choice of platform shell.
abstract final class DesktopLayout {
  static bool isActive(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.windows;

  static EdgeInsets pagePadding(BuildContext context) => isActive(context)
      ? (MediaQuery.sizeOf(context).width < 900
            ? const EdgeInsets.all(16)
            : const EdgeInsets.fromLTRB(32, 24, 32, 24))
      : const EdgeInsets.all(16);

  /// Grow layout minimums with text, without changing the user's text scaler.
  static double workspaceScaleFactor(BuildContext context) =>
      (1 + 0.3 * (MediaQuery.textScalerOf(context).scale(14) / 14 - 1)).clamp(
        1.0,
        2.0,
      );

  static Duration motionDuration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 160);
}

/// Related content shares the window rather than leaving an unused right half.
/// This is a box layout for scrollable pages; long chapter lists use slivers.
class DesktopWorkspaceColumns extends StatelessWidget {
  const DesktopWorkspaceColumns({
    required this.primary,
    required this.secondary,
    this.secondaryWidth = 340,
    this.minimumPrimaryWidth = 560,
    this.secondaryFirst = false,
    this.gap = 24,
    super.key,
  });

  final Widget primary;
  final Widget secondary;
  final double secondaryWidth;
  final double minimumPrimaryWidth;
  final bool secondaryFirst;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final factor = DesktopLayout.workspaceScaleFactor(context);
      final sideWidth = secondaryWidth * factor;
      if (constraints.maxWidth <
          minimumPrimaryWidth * factor + sideWidth + gap) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: secondaryFirst
              ? [secondary, SizedBox(height: gap), primary]
              : [primary, SizedBox(height: gap), secondary],
        );
      }
      final main = Expanded(child: primary);
      final side = SizedBox(width: sideWidth, child: secondary);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: secondaryFirst
            ? [side, SizedBox(width: gap), main]
            : [main, SizedBox(width: gap), side],
      );
    },
  );
}

/// Card preferences derived from the existing settings store. The historical
/// name is retained, but shared mobile cards use the same presentation settings.
class DesktopPreferences extends InheritedWidget {
  const DesktopPreferences({
    required this.compactCards,
    required this.showSourceOnCards,
    required this.showPercentOnCovers,
    required super.child,
    super.key,
  });
  final bool compactCards;
  final bool showSourceOnCards;
  final bool showPercentOnCovers;

  static DesktopPreferences? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopPreferences>();

  @override
  bool updateShouldNotify(DesktopPreferences oldWidget) =>
      compactCards != oldWidget.compactCards ||
      showSourceOnCards != oldWidget.showSourceOnCards ||
      showPercentOnCovers != oldWidget.showPercentOnCovers;
}

class DesktopPageHeader extends StatelessWidget {
  const DesktopPageHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottomSpacing = 24,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (trailing == null) return heading;
          if (constraints.maxWidth < 720 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 16), trailing!],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 24),
              trailing!,
            ],
          );
        },
      ),
    );
  }
}
