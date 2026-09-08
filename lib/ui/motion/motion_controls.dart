import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../icons/app_icons.dart';
import 'app_motion.dart';

/// Material's discrete thumb interpolates with a private fixed-duration
/// controller. Non-spatial modes keep quantization/keyboard steps in the input
/// layer and use the continuous (immediate-position) renderer instead.
class AppSlider extends StatelessWidget {
  const AppSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.semanticFormatterCallback,
    this.focusNode,
    this.autofocus = false,
    super.key,
  }) : assert(max >= min),
       assert(divisions == null || divisions > 0),
       assert(value >= min && value <= max);
  final double value, min, max;
  final int? divisions;
  final String? label;
  final ValueChanged<double>? onChanged, onChangeStart, onChangeEnd;
  final Color? activeColor, inactiveColor, thumbColor;
  final SemanticFormatterCallback? semanticFormatterCallback;
  final FocusNode? focusNode;
  final bool autofocus;

  double _quantize(double input) => divisions == null || max == min
      ? input
      : min +
            (((input - min) / (max - min) * divisions!).round() / divisions!) *
                (max - min);

  @override
  Widget build(BuildContext context) {
    final spatial = AppMotion.of(context).hasSpatialMotion;
    void change(double input) =>
        onChanged?.call(_quantize(input.clamp(min, max)));
    void step(int direction) {
      final next = _quantize(
        (value + direction * (max - min) / divisions!).clamp(min, max),
      );
      onChangeStart?.call(value);
      onChanged?.call(next);
      onChangeEnd?.call(next);
    }

    Widget slider = _MotionSliderFocus(
      externalFocusNode: focusNode,
      onKey: (node, event) {
        if (spatial ||
            divisions == null ||
            onChanged == null ||
            (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
          return KeyEventResult.ignored;
        }
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final directional =
            MediaQuery.navigationModeOf(context) == NavigationMode.directional;
        final direction = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowRight => rtl ? -1 : 1,
          LogicalKeyboardKey.arrowLeft => rtl ? 1 : -1,
          LogicalKeyboardKey.arrowUp when !directional => 1,
          LogicalKeyboardKey.arrowDown when !directional => -1,
          _ => 0,
        };
        if (direction == 0) return KeyEventResult.ignored;
        step(direction);
        return KeyEventResult.handled;
      },
      builder: (node) => Slider(
        value: value,
        min: min,
        max: max,
        divisions: spatial ? divisions : null,
        label: label,
        onChanged: onChanged == null ? null : change,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd == null
            ? null
            : (input) => onChangeEnd!(_quantize(input)),
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        thumbColor: thumbColor,
        semanticFormatterCallback: semanticFormatterCallback,
        focusNode: node,
        autofocus: autofocus,
      ),
    );
    if (!spatial) {
      slider = SliderTheme(
        data: SliderTheme.of(context).copyWith(
          overlayShape: SliderComponentShape.noOverlay,
          showValueIndicator: ShowValueIndicator.never,
        ),
        child: slider,
      );
      if (divisions != null && onChanged != null && max > min) {
        String format(double input) =>
            semanticFormatterCallback?.call(input) ??
            '${((input - min) / (max - min) * 100).round()}%';
        slider = Semantics(
          slider: true,
          enabled: true,
          value: format(value),
          increasedValue: format(
            _quantize((value + (max - min) / divisions!).clamp(min, max)),
          ),
          decreasedValue: format(
            _quantize((value - (max - min) / divisions!).clamp(min, max)),
          ),
          onIncrease: value < max ? () => step(1) : null,
          onDecrease: value > min ? () => step(-1) : null,
          child: ExcludeSemantics(
            // The stepped accessible node above replaces the continuous
            // renderer. Keep its never-shown value portal under the same
            // exclusion, rather than grafting an orphan into the root overlay.
            child: Theme.of(context).platform == TargetPlatform.windows
                ? IgnoreBaseline(
                    // A slider has no text baseline. Do not query its deferred
                    // decorative portal during a Full -> Reduced/Off layout.
                    child: Overlay.wrap(
                      alwaysSizeToContent: true,
                      clipBehavior: Clip.none,
                      child: slider,
                    ),
                  )
                : slider,
          ),
        );
      }
    }

    return Theme.of(context).platform == TargetPlatform.windows
        ? _WindowsSliderRouteGate(child: slider)
        : slider;
  }
}

/// Material Slider opens a value-indicator portal even before its bubble is
/// painted. A newly pushed Windows route is first measured offstage; creating
/// that portal then sends native semantics a child without its hidden parent.
/// Defer only this invisible measurement, not the real slider's accessibility.
class _WindowsSliderRouteGate extends StatefulWidget {
  const _WindowsSliderRouteGate({required this.child});
  final Widget child;
  @override
  State<_WindowsSliderRouteGate> createState() =>
      _WindowsSliderRouteGateState();
}

class _WindowsSliderRouteGateState extends State<_WindowsSliderRouteGate> {
  ModalRoute<dynamic>? _route;
  bool _offstage = false;
  bool _checkPending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (_route != next) {
      _route?.animation?.removeListener(_refresh);
      _route = next;
      _route?.animation?.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted && _offstage != (_route?.offstage ?? false)) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _route?.animation?.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _offstage = _route?.offstage ?? false;
    if (!_offstage) return widget.child;
    if (!_checkPending) {
      _checkPending = true;
      // offstage is not an InheritedModel aspect. With zero-duration routes,
      // both proxy animations can also be 1; check once after hero measurement.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkPending = false;
        _refresh();
      });
    }
    return const LimitedBox(
      maxWidth: 192,
      child: SizedBox(height: kMinInteractiveDimension, width: double.infinity),
    );
  }
}

/// The tile owns focus in every mode. Replacing only the decorative check mark
/// avoids re-keying the interactive tile (and losing TV focus on each toggle).
class AppCheckboxListTile extends StatelessWidget {
  const AppCheckboxListTile({
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.visualDensity,
    this.focusNode,
    this.contentPadding,
    super.key,
  });
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Widget? title, subtitle;
  final VisualDensity? visualDensity;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.of(context).hasSpatialMotion) {
      return CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        visualDensity: visualDensity,
        focusNode: focusNode,
        contentPadding: contentPadding,
      );
    }
    final colors = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    final selected = value == true;
    final interactiveStates = <WidgetState>{
      if (selected) WidgetState.selected,
      if (!enabled) WidgetState.disabled,
    };
    final theme = CheckboxTheme.of(context);
    final fill =
        theme.fillColor?.resolve(interactiveStates) ??
        (selected ? colors.primary : colors.surface);
    final foreground =
        theme.checkColor?.resolve(interactiveStates) ?? colors.onPrimary;
    final outline = theme.side?.color ?? colors.onSurfaceVariant;
    final mark = AppMotion.of(context).hasSpatialMotion
        ? Checkbox(value: value, onChanged: onChanged)
        : SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: selected ? fill : colors.surface.withValues(alpha: 0),
                  border: selected
                      ? null
                      : Border.all(color: outline, width: 2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: selected
                    ? AppIcon(
                        AppIconAssets.systemCheck,
                        size: 16,
                        color: foreground,
                      )
                    : null,
              ),
            ),
          );
    return MergeSemantics(
      child: Semantics(
        checked: selected,
        enabled: enabled,
        child: ListTile(
          title: title,
          subtitle: subtitle,
          visualDensity: visualDensity,
          focusNode: focusNode,
          contentPadding: contentPadding,
          enabled: enabled,
          onTap: enabled ? () => onChanged!(!selected) : null,
          trailing: ExcludeFocus(
            child: ExcludeSemantics(child: IgnorePointer(child: mark)),
          ),
        ),
      ),
    );
  }
}

class AppSwitchListTile extends StatelessWidget {
  const AppSwitchListTile({
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.visualDensity,
    this.focusNode,
    this.contentPadding,
    this.dense,
    super.key,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title, subtitle, secondary;
  final VisualDensity? visualDensity;
  final FocusNode? focusNode;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    if (motion.hasSpatialMotion) {
      return SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        visualDensity: visualDensity,
        focusNode: focusNode,
        contentPadding: contentPadding,
        dense: dense,
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final states = <WidgetState>{
      if (value) WidgetState.selected,
      if (onChanged == null) WidgetState.disabled,
    };
    final track =
        theme.switchTheme.trackColor?.resolve(states) ??
        (value ? colors.primary : colors.surfaceContainerHighest);
    final thumb =
        theme.switchTheme.thumbColor?.resolve(states) ??
        (value ? colors.onPrimary : colors.outline);
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        enabled: onChanged != null,
        child: ListTile(
          title: title,
          subtitle: subtitle,
          leading: secondary,
          visualDensity: visualDensity,
          focusNode: focusNode,
          contentPadding: contentPadding,
          dense: dense,
          enabled: onChanged != null,
          onTap: onChanged == null ? null : () => onChanged!(!value),
          trailing: ExcludeSemantics(
            child: SizedBox(
              width: 52,
              height: 48,
              child: Center(
                child: AnimatedContainer(
                  duration: motion.duration(),
                  width: 52,
                  height: 32,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: track,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: value ? track : colors.outline,
                      width: 2,
                    ),
                  ),
                  child: Align(
                    alignment: value
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: thumb,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 20),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionSliderFocus extends StatefulWidget {
  const _MotionSliderFocus({
    this.externalFocusNode,
    required this.onKey,
    required this.builder,
  });
  final FocusNode? externalFocusNode;
  final FocusOnKeyEventCallback onKey;
  final Widget Function(FocusNode) builder;
  @override
  State<_MotionSliderFocus> createState() => _MotionSliderFocusState();
}

class _MotionSliderFocusState extends State<_MotionSliderFocus> {
  late FocusNode _node;
  FocusOnKeyEventCallback? _previousHandler;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _node = widget.externalFocusNode ?? FocusNode();
    _previousHandler = _node.onKeyEvent;
    _node.onKeyEvent = _handleKey;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final result = widget.onKey(node, event);
    return result == KeyEventResult.ignored
        ? (_previousHandler?.call(node, event) ?? result)
        : result;
  }

  void _detach(FocusNode? external) {
    if (_node.onKeyEvent == _handleKey) _node.onKeyEvent = _previousHandler;
    if (external == null) _node.dispose();
  }

  @override
  void didUpdateWidget(_MotionSliderFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalFocusNode != oldWidget.externalFocusNode) {
      _detach(oldWidget.externalFocusNode);
      _attach();
    }
  }

  @override
  void dispose() {
    _detach(widget.externalFocusNode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_node);
}
