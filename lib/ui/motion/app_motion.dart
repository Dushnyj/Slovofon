import 'package:flutter/material.dart';

import '../../domain/models/app_settings.dart';

/// One motion policy for touch, keyboard and remote-control interfaces.
/// Never freezes tickers: Off renders final states and uses zero durations.
@immutable
class AppMotion {
  const AppMotion(this.mode);

  factory AppMotion.resolve(
    AppAnimationsMode preference, {
    required bool systemReduceMotion,
  }) => AppMotion(
    preference == AppAnimationsMode.full && systemReduceMotion
        ? AppAnimationsMode.reduced
        : preference,
  );

  final AppAnimationsMode mode;
  bool get isOff => mode == AppAnimationsMode.off;
  bool get isReduced => mode == AppAnimationsMode.reduced;
  bool get hasSpatialMotion => mode == AppAnimationsMode.full;

  static AppMotion of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppMotionScope>()?.motion ??
      AppMotion.resolve(
        AppAnimationsMode.full,
        systemReduceMotion: MediaQuery.disableAnimationsOf(context),
      );

  Duration duration({
    Duration full = const Duration(milliseconds: 160),
    Duration reduced = const Duration(milliseconds: 80),
  }) => isOff ? Duration.zero : (isReduced ? reduced : full);

  Duration spatialDuration({
    Duration full = const Duration(milliseconds: 220),
  }) => hasSpatialMotion ? full : Duration.zero;

  Duration get themeDuration =>
      duration(full: const Duration(milliseconds: 200));
  Duration get routeDuration =>
      duration(full: const Duration(milliseconds: 220));
  static const curve = Curves.easeOutCubic;

  AnimationStyle get dialogAnimationStyle => AnimationStyle(
    duration: duration(full: const Duration(milliseconds: 180)),
    reverseDuration: duration(full: const Duration(milliseconds: 140)),
    curve: curve,
    reverseCurve: Curves.easeInCubic,
  );

  // Material bottom sheets animate their vertical offset. Reduced must not
  // move a large surface across the screen, even for a shorter duration.
  AnimationStyle get sheetAnimationStyle => AnimationStyle(
    duration: spatialDuration(full: const Duration(milliseconds: 240)),
    reverseDuration: spatialDuration(full: const Duration(milliseconds: 180)),
    curve: curve,
    reverseCurve: Curves.easeInCubic,
  );

  AnimationStyle get snackBarAnimationStyle => AnimationStyle(
    duration: spatialDuration(full: const Duration(milliseconds: 180)),
    reverseDuration: spatialDuration(full: const Duration(milliseconds: 120)),
  );

  /// Off draws focus/hover immediately rather than Material's private ink
  /// highlight fade. The geometry and state-layer colours are preserved.
  ButtonStyle buttonStyle(ButtonStyle? original, ColorScheme colors) {
    final style = original ?? const ButtonStyle();
    if (!isOff) return style.copyWith(animationDuration: duration());
    return style.copyWith(
      animationDuration: Duration.zero,
      overlayColor: WidgetStatePropertyAll(colors.primary.withValues(alpha: 0)),
      backgroundBuilder: (context, states, child) {
        final content =
            style.backgroundBuilder?.call(context, states, child) ??
            child ??
            const SizedBox.shrink();
        if (!states.contains(WidgetState.hovered) &&
            !states.contains(WidgetState.focused) &&
            !states.contains(WidgetState.pressed)) {
          return content;
        }
        final overlay =
            style.overlayColor?.resolve(states) ??
            colors.primary.withValues(
              alpha: states.contains(WidgetState.focused) ? .12 : .08,
            );
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: overlay,
            shape:
                style.shape?.resolve(states) ??
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: content,
        );
      },
    );
  }

  /// Platform themes are composed first; motion is applied last so that their
  /// button styles cannot accidentally restore the default 200 ms animation.
  ThemeData applyTheme(ThemeData theme) {
    ButtonStyle style(ButtonStyle? original) =>
        buttonStyle(original, theme.colorScheme);
    final transitions = AppPageTransitionsBuilder(this);
    return theme.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values) platform: transitions,
        },
      ),
      expansionTileTheme: theme.expansionTileTheme.copyWith(
        expansionAnimationStyle: AnimationStyle(
          duration: spatialDuration(),
          reverseDuration: spatialDuration(),
          curve: curve,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: style(theme.elevatedButtonTheme.style),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: style(theme.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: style(theme.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: style(theme.textButtonTheme.style),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: style(theme.iconButtonTheme.style),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: style(theme.menuButtonTheme.style),
      ),
      scrollbarTheme: isOff
          ? theme.scrollbarTheme.copyWith(
              thumbVisibility: const WidgetStatePropertyAll(true),
            )
          : theme.scrollbarTheme,
      splashFactory: hasSpatialMotion
          ? theme.splashFactory
          : NoSplash.splashFactory,
      // Keep selection/focus fills; only transient expanding ink is removed.
      splashColor: hasSpatialMotion
          ? theme.splashColor
          : theme.splashColor.withValues(alpha: 0),
      highlightColor: hasSpatialMotion
          ? theme.highlightColor
          : theme.highlightColor.withValues(alpha: 0),
      sliderTheme: hasSpatialMotion
          ? theme.sliderTheme
          : theme.sliderTheme.copyWith(
              overlayShape: SliderComponentShape.noOverlay,
            ),
    );
  }
}

class AppMotionScope extends InheritedWidget {
  const AppMotionScope({required this.motion, required super.child, super.key});
  final AppMotion motion;
  @override
  bool updateShouldNotify(AppMotionScope oldWidget) =>
      motion.mode != oldWidget.motion.mode;
}

extension MotionScaffoldMessenger on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showMotionSnackBar(
    SnackBar snackBar,
  ) => showSnackBar(_MotionSnackBar(snackBar));
}

/// Flutter shares one controller for a messenger's entire snackbar queue.
/// Passing a new animationStyle while another notice is visible disposes that
/// controller in the SDK, invalidating the visible notice and its timeout.
/// Reuse the controller instead, and apply policy only when this notice becomes
/// current. A queued notice must never alter or dismiss an unrelated one.
class _MotionSnackBar extends SnackBar {
  _MotionSnackBar(this.source, {super.animation, super.key})
    : super(
        content: source.content,
        backgroundColor: source.backgroundColor,
        elevation: source.elevation,
        margin: source.margin,
        padding: source.padding,
        width: source.width,
        shape: source.shape,
        hitTestBehavior: source.hitTestBehavior,
        behavior: source.behavior,
        action: source.action,
        actionOverflowThreshold: source.actionOverflowThreshold,
        showCloseIcon: source.showCloseIcon,
        closeIconColor: source.closeIconColor,
        duration: source.duration,
        persist: source.persist,
        onVisible: source.onVisible,
        dismissDirection: source.dismissDirection,
        clipBehavior: source.clipBehavior,
      );

  final SnackBar source;

  @override
  SnackBar withAnimation(Animation<double> newAnimation, {Key? fallbackKey}) =>
      _MotionSnackBar(
        source,
        animation: newAnimation,
        key: source.key ?? fallbackKey,
      );

  @override
  State<SnackBar> createState() => _MotionSnackBarState();
}

class _MotionSnackBarState extends State<_MotionSnackBar> {
  late final _SnackBarVisualAnimation _visualAnimation =
      _SnackBarVisualAnimation(widget.animation!);
  AppMotion? _motion;

  @override
  void initState() {
    super.initState();
    // A previously zero-duration queue controller can finish before the SDK
    // SnackBar State subscribes. Deliver the missed callback once after mount.
    if (widget.animation!.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.source.onVisible?.call();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = AppMotion.of(context);
    if (_motion?.mode == motion.mode) {
      return;
    }
    _motion = motion;
    _visualAnimation.animate = motion.hasSpatialMotion;
    // Completion notifies ScaffoldMessenger, so finalize outside its build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final animation = widget.animation;
      if (animation is! AnimationController) {
        return;
      }
      final style = _motion!.snackBarAnimationStyle;
      animation.duration = style.duration;
      animation.reverseDuration = style.reverseDuration;
      if (animation.isAnimating) {
        if (animation.status == AnimationStatus.reverse) {
          animation.reverse();
        } else {
          animation.forward();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      widget.source.withAnimation(_visualAnimation);
}

/// Keep the SDK lifecycle/status callbacks while rendering final geometry in
/// Reduced/Off, including the first frame before the controller is finalized.
class _SnackBarVisualAnimation extends ProxyAnimation {
  _SnackBarVisualAnimation(super.animation);
  bool animate = true;

  @override
  double get value => animate
      ? super.value
      : (status == AnimationStatus.reverse ||
                status == AnimationStatus.dismissed
            ? 0
            : 1);
}

/// PageTransitionsTheme supplies both the route controller duration and the
/// visuals. Reduced is opacity only; Full adds a restrained 12 dp reveal.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder(this.motion);
  final AppMotion motion;
  @override
  Duration get transitionDuration => motion.routeDuration;
  @override
  Duration get reverseTransitionDuration =>
      motion.duration(full: const Duration(milliseconds: 160));
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final current = AppMotion.of(context);
    final curved = current.isOff
        ? kAlwaysCompleteAnimation
        : animation.drive(CurveTween(curve: AppMotion.curve));
    final fade = FadeTransition(opacity: curved, child: child);
    return AnimatedBuilder(
      animation: curved,
      child: fade,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          current.hasSpatialMotion ? 12 * (1 - curved.value) : 0,
        ),
        child: child,
      ),
    );
  }
}

Future<T?> showMotionDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  TraversalEdgeBehavior? traversalEdgeBehavior,
  bool fullscreenDialog = false,
  bool? requestFocus,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push<T>(
    MotionDialogRoute<T>(
      context: context,
      builder: builder,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: barrierDismissible,
      barrierColor:
          barrierColor ??
          Theme.of(context).dialogTheme.barrierColor ??
          Theme.of(context).colorScheme.scrim.withValues(alpha: .54),
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior:
          traversalEdgeBehavior ?? TraversalEdgeBehavior.closedLoop,
      fullscreenDialog: fullscreenDialog,
      requestFocus: requestFocus,
    ),
  );
}

Future<T?> showMotionBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  String? barrierLabel,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  double scrollControlDisabledMaxHeightRatio = 9 / 16,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  bool? requestFocus,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push<T>(
    _MotionBottomSheetRoute<T>(
      hostContext: context,
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      backgroundColor: backgroundColor,
      barrierLabel: barrierLabel ?? localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      modalBarrierColor:
          barrierColor ?? Theme.of(context).bottomSheetTheme.modalBarrierColor,
      isScrollControlled: isScrollControlled,
      scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      anchorPoint: anchorPoint,
      requestFocus: requestFocus,
    ),
  );
}

/// Existing dialogs adopt a new setting too: choosing Off inside a Full-mode
/// dialog must not leave its closing animation at the old 150/180 ms default.
class MotionDialogRoute<T> extends DialogRoute<T> {
  MotionDialogRoute({
    required super.context,
    required super.builder,
    super.themes,
    super.barrierColor,
    super.barrierDismissible,
    super.barrierLabel,
    super.useSafeArea,
    super.settings,
    super.anchorPoint,
    super.traversalEdgeBehavior,
    super.fullscreenDialog,
    super.requestFocus,
  }) : _hostContext = context,
       super(animationStyle: AppMotion.of(context).dialogAnimationStyle);
  final BuildContext _hostContext;
  AppMotion get _motion =>
      (navigator?.context ?? _hostContext)
          .getInheritedWidgetOfExactType<AppMotionScope>()
          ?.motion ??
      const AppMotion(AppAnimationsMode.full);
  @override
  Duration get transitionDuration => _motion.dialogAnimationStyle.duration!;
  @override
  Duration get reverseTransitionDuration =>
      _motion.dialogAnimationStyle.reverseDuration!;
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final motion = AppMotion.of(context);
    controller?.duration = motion.dialogAnimationStyle.duration;
    controller?.reverseDuration = motion.dialogAnimationStyle.reverseDuration;
    return FadeTransition(
      opacity: motion.isOff
          ? kAlwaysCompleteAnimation
          : animation.drive(CurveTween(curve: AppMotion.curve)),
      child: child,
    );
  }
}

class _MotionBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _MotionBottomSheetRoute({
    required BuildContext hostContext,
    required super.builder,
    super.capturedThemes,
    super.backgroundColor,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    required super.isScrollControlled,
    super.scrollControlDisabledMaxHeightRatio,
    super.isDismissible,
    super.enableDrag,
    super.showDragHandle,
    super.useSafeArea,
    super.settings,
    super.anchorPoint,
    super.requestFocus,
  }) : _hostContext = hostContext,
       super(
         sheetAnimationStyle: AppMotion.of(hostContext).sheetAnimationStyle,
       );
  final BuildContext _hostContext;
  AppMotion get _motion =>
      (navigator?.context ?? _hostContext)
          .getInheritedWidgetOfExactType<AppMotionScope>()
          ?.motion ??
      const AppMotion(AppAnimationsMode.full);
  @override
  Duration get transitionDuration => _motion.sheetAnimationStyle.duration!;
  @override
  Duration get reverseTransitionDuration =>
      _motion.sheetAnimationStyle.reverseDuration!;
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Builder(
    builder: (context) {
      final motion = AppMotion.of(context);
      controller?.duration = motion.sheetAnimationStyle.duration;
      controller?.reverseDuration = motion.sheetAnimationStyle.reverseDuration;
      return super.buildPage(context, animation, secondaryAnimation);
    },
  );
}
