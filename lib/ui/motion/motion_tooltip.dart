import 'package:flutter/material.dart';

import 'app_motion.dart';

/// Uses Flutter's own hover/long-press, positioning, dismissal and accessibility
/// machinery, with explicit animation durations rather than private defaults.
class AppTooltip extends StatelessWidget {
  const AppTooltip({
    required this.message,
    required this.child,
    this.excludeFromSemantics = false,
    this.waitDuration,
    super.key,
  });
  final String message;
  final Widget child;
  final bool excludeFromSemantics;
  final Duration? waitDuration;

  @override
  Widget build(BuildContext context) {
    // IndexedSemantics (a ListView item) may otherwise absorb adjacent portal
    // anchors into one node and discard all but the first traversal parent.
    // Keep each tooltip addressable without removing labels or button actions.
    // This is an app-side boundary, not an SDK patch or accessibility opt-out.
    return Semantics(container: true, child: _buildTooltip(context));
  }

  Widget _buildTooltip(BuildContext context) {
    final motion = AppMotion.of(context);
    if (message.isEmpty || !TooltipVisibility.of(context)) return child;
    final theme = Theme.of(context);
    final tooltip = theme.tooltipTheme;
    final desktop = switch (theme.platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
    return RawTooltip(
      semanticsTooltip: excludeFromSemantics ? null : message,
      hoverDelay: waitDuration ?? tooltip.waitDuration ?? Duration.zero,
      touchDelay: tooltip.showDuration ?? const Duration(milliseconds: 1500),
      dismissDelay: tooltip.exitDuration ?? const Duration(milliseconds: 100),
      triggerMode: tooltip.triggerMode ?? TooltipTriggerMode.longPress,
      enableFeedback: tooltip.enableFeedback ?? true,
      ignorePointer: true,
      positionDelegate: motion.hasSpatialMotion
          ? (position) => positionDependentBox(
              size: position.overlaySize,
              childSize: position.tooltipSize,
              target: position.target,
              verticalOffset: tooltip.verticalOffset ?? 24,
              preferBelow: tooltip.preferBelow ?? true,
            )
          : null,
      animationStyle: AnimationStyle(
        duration: motion.duration(full: const Duration(milliseconds: 150)),
        reverseDuration: motion.duration(
          full: const Duration(milliseconds: 75),
        ),
        curve: motion.hasSpatialMotion ? Curves.fastOutSlowIn : AppMotion.curve,
      ),
      tooltipBuilder: (context, animation) {
        final body = Container(
          constraints:
              tooltip.constraints ??
              BoxConstraints(
                minHeight: motion.hasSpatialMotion ? (desktop ? 24 : 32) : 0,
                maxWidth: MediaQuery.sizeOf(context).width - 32,
              ),
          margin: tooltip.margin ?? EdgeInsets.zero,
          padding:
              tooltip.padding ??
              (motion.hasSpatialMotion
                  ? EdgeInsets.symmetric(
                      horizontal: desktop ? 8 : 16,
                      vertical: 4,
                    )
                  : const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          decoration:
              tooltip.decoration ??
              BoxDecoration(
                color: theme.colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(6),
              ),
          child: Text(
            message,
            style:
                tooltip.textStyle ??
                theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                ),
            textAlign: tooltip.textAlign ?? TextAlign.start,
          ),
        );
        // The persistent trigger retains semanticsTooltip and RawTooltip's
        // accessibility announcement. This duplicate painted bubble has no
        // action; exposing its fading Text separately leaves detached native
        // nodes when a kept-alive route becomes offstage during hover.
        final visual = ExcludeSemantics(child: body);
        return motion.isOff
            ? visual
            : FadeTransition(opacity: animation, child: visual);
      },
      child: child,
    );
  }
}

/// Keeps the real Material IconButton as the interactive child, while moving
/// its tooltip to the policy-aware wrapper. Icon size/padding/semantics and
/// focus nodes are forwarded unchanged. The outer key remains on this button.
class AppIconButton extends IconButton {
  const AppIconButton({
    super.key,
    super.iconSize,
    super.visualDensity,
    super.padding,
    super.alignment,
    super.splashRadius,
    super.color,
    super.focusColor,
    super.hoverColor,
    super.highlightColor,
    super.splashColor,
    super.disabledColor,
    required super.onPressed,
    super.onHover,
    super.onLongPress,
    super.mouseCursor,
    super.focusNode,
    super.autofocus,
    super.tooltip,
    super.enableFeedback,
    super.constraints,
    super.style,
    super.isSelected,
    super.selectedIcon,
    super.statesController,
    required super.icon,
  }) : _filled = false;
  const AppIconButton.filled({
    super.key,
    super.iconSize,
    super.visualDensity,
    super.padding,
    super.alignment,
    super.splashRadius,
    super.color,
    super.focusColor,
    super.hoverColor,
    super.highlightColor,
    super.splashColor,
    super.disabledColor,
    required super.onPressed,
    super.onHover,
    super.onLongPress,
    super.mouseCursor,
    super.focusNode,
    super.autofocus,
    super.tooltip,
    super.enableFeedback,
    super.constraints,
    super.style,
    super.isSelected,
    super.selectedIcon,
    super.statesController,
    required super.icon,
  }) : _filled = true,
       super.filled();
  final bool _filled;

  // Give the actual Material button an accessible name, not only its
  // non-interactive tooltip anchor. The decorative SVG cannot duplicate it.
  Widget _namedIcon(Widget child) => tooltip == null || tooltip!.isEmpty
      ? child
      : Semantics(label: tooltip, excludeSemantics: true, child: child);
  @override
  Widget build(BuildContext context) {
    final create = _filled ? IconButton.filled : IconButton.new;
    final button = create(
      iconSize: iconSize,
      visualDensity: visualDensity,
      padding: padding,
      alignment: alignment,
      splashRadius: splashRadius,
      color: color,
      focusColor: focusColor,
      hoverColor: hoverColor,
      highlightColor: highlightColor,
      splashColor: splashColor,
      disabledColor: disabledColor,
      onPressed: onPressed,
      onHover: onHover,
      onLongPress: onLongPress,
      mouseCursor: mouseCursor,
      focusNode: focusNode,
      autofocus: autofocus,
      enableFeedback: enableFeedback,
      constraints: constraints,
      style: AppMotion.of(
        context,
      ).buttonStyle(style, Theme.of(context).colorScheme),
      isSelected: isSelected,
      selectedIcon: selectedIcon == null ? null : _namedIcon(selectedIcon!),
      statesController: statesController,
      icon: _namedIcon(icon),
    );
    // AppTooltip owns an independent portal anchor. MergeSemantics outside it
    // makes Flutter serialize that anchor as an orphan even though its data is
    // merged into the button. Keep the ordinary button action node and tooltip
    // anchor intact; the tooltip boundary also handles viewport clipping.
    return tooltip == null
        ? button
        : AppTooltip(message: tooltip!, child: button);
  }
}
