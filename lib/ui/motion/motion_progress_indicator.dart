import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import 'app_motion.dart';

/// An indeterminate operation remains visible with motion disabled, but does
/// not keep a repeating ticker alive. The static arc is not a fake percentage:
/// its child progress semantics are excluded for an indeterminate operation.
class AppCircularProgressIndicator extends CircularProgressIndicator {
  const AppCircularProgressIndicator({
    super.value,
    super.strokeWidth = 4,
    super.color,
    super.backgroundColor,
    super.valueColor,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  @override
  State<CircularProgressIndicator> createState() => _MotionCircularState();
}

class _MotionCircularState extends State<CircularProgressIndicator> {
  @override
  Widget build(BuildContext context) {
    final stationary = AppMotion.of(context).isOff && widget.value == null;
    final indicator = CircularProgressIndicator(
      value: stationary ? .72 : widget.value,
      strokeWidth: widget.strokeWidth,
      color: widget.color,
      backgroundColor: widget.backgroundColor,
      valueColor: widget.valueColor,
      semanticsLabel: widget.semanticsLabel,
      semanticsValue: widget.semanticsValue,
    );
    if (!stationary) return indicator;
    return Semantics(
      label: widget.semanticsLabel ?? context.strings.loading,
      value: widget.semanticsValue,
      child: ExcludeSemantics(child: indicator),
    );
  }
}

class AppLinearProgressIndicator extends LinearProgressIndicator {
  const AppLinearProgressIndicator({
    super.value,
    super.minHeight,
    super.color,
    super.backgroundColor,
    super.valueColor,
    super.borderRadius,
    super.semanticsLabel,
    super.semanticsValue,
    super.key,
  });

  @override
  State<LinearProgressIndicator> createState() => _MotionLinearState();
}

class _MotionLinearState extends State<LinearProgressIndicator> {
  @override
  Widget build(BuildContext context) {
    final stationary = AppMotion.of(context).isOff && widget.value == null;
    if (stationary) {
      final colors = Theme.of(context).colorScheme;
      return Semantics(
        label: widget.semanticsLabel ?? context.strings.loading,
        value: widget.semanticsValue,
        child: ExcludeSemantics(
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
            child: SizedBox(
              height: widget.minHeight ?? 4,
              child: ColoredBox(
                color: widget.backgroundColor ?? colors.surfaceContainerHighest,
                child: Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: .28,
                    child: ColoredBox(
                      color: widget.color ?? colors.primary,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final indicator = LinearProgressIndicator(
      value: widget.value,
      minHeight: widget.minHeight,
      color: widget.color,
      backgroundColor: widget.backgroundColor,
      valueColor: widget.valueColor,
      borderRadius: widget.borderRadius,
      semanticsLabel: widget.semanticsLabel,
      semanticsValue: widget.semanticsValue,
    );
    return indicator;
  }
}
