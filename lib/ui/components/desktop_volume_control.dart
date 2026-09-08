import '../motion/motion_tooltip.dart';
import '../motion/motion_controls.dart';
import '../motion/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../adaptive/television_layout.dart';
import '../icons/app_icons.dart';

class DesktopVolumeControl extends StatefulWidget {
  const DesktopVolumeControl({
    required this.volume,
    required this.onToggleMute,
    required this.onVolumeChanged,
    super.key,
  });

  final double volume;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;

  @override
  State<DesktopVolumeControl> createState() => _DesktopVolumeControlState();
}

class _DesktopVolumeControlState extends State<DesktopVolumeControl> {
  final _controller = MenuController();
  final _anchorFocus = FocusNode(debugLabel: 'desktop-volume-anchor');

  @override
  void dispose() {
    _anchorFocus.dispose();
    super.dispose();
  }

  void _returnFocus() {
    if (mounted && _anchorFocus.context != null) {
      _anchorFocus.requestFocus();
    }
  }

  void _close() {
    if (_controller.isOpen) {
      _controller.close();
      _returnFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final desktop = Theme.of(context).platform == TargetPlatform.windows;
    final television = TelevisionLayout.isActive(context);
    final iconColor = desktop ? colors.onSurfaceVariant : colors.primary;
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.escape): _close,
    };
    // Custom menu children are not MenuItemButtons: give their keyboard focus
    // an explicit initial target and scope Escape to this popover/its anchor.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (_controller.isOpen &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MenuAnchor(
        controller: _controller,
        childFocusNode: _anchorFocus,
        onClose: _returnFocus,
        alignmentOffset: const Offset(-176, -12),
        menuChildren: [
          CallbackShortcuts(
            bindings: shortcuts,
            child: _DesktopVolumePopover(
              volume: widget.volume,
              onToggleMute: widget.onToggleMute,
              onVolumeChanged: widget.onVolumeChanged,
            ),
          ),
        ],
        builder: (context, controller, child) => AppIconButton(
          tooltip: context.strings.volume,
          focusNode: _anchorFocus,
          // TV focus changes both the fill and foreground together. An
          // explicit primary-colored SVG would disappear on the primary fill.
          style: television
              ? null
              : IconButton.styleFrom(
                  minimumSize: Size.square(desktop ? 40 : 48),
                  fixedSize: Size.square(desktop ? 40 : 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  foregroundColor: iconColor,
                  hoverColor: colors.surfaceContainerHighest,
                  focusColor: colors.primary.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ).copyWith(
                  animationDuration: AppMotion.of(context).duration(),
                  side: WidgetStateProperty.resolveWith(
                    (states) => BorderSide(
                      color: states.contains(WidgetState.focused)
                          ? colors.primary
                          : colors.surfaceContainerLow,
                      width: 1.5,
                    ),
                  ),
                ),
          icon: AppIcon(
            widget.volume > 0
                ? AppIconAssets.playerVolume
                : AppIconAssets.playerVolumeOff,
            color: television ? null : iconColor,
            size: 21,
          ),
          onPressed: () => controller.isOpen ? _close() : controller.open(),
        ),
      ),
    );
  }
}

class _DesktopVolumePopover extends StatelessWidget {
  const _DesktopVolumePopover({
    required this.volume,
    required this.onToggleMute,
    required this.onVolumeChanged,
  });

  final double volume;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final strings = context.strings;
    final desktop = (Theme.of(context).platform == TargetPlatform.windows);
    final television = TelevisionLayout.isActive(context);
    final muteSize = desktop || television ? 40.0 : 48.0;
    final percentageStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: desktop || television
          ? colorScheme.onSurfaceVariant
          : tokens.onPlayerSurface.withValues(alpha: 0.74),
      fontWeight: FontWeight.w700,
      height: 1,
    );
    // Reserve the widest percentage at the actual accessibility scale. The
    // slider keeps its usable length and does not jump while volume changes.
    final percentagePainter = TextPainter(
      text: TextSpan(text: '100%', style: percentageStyle),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final percentageWidth = percentagePainter.width.ceilToDouble();
    final popoverWidth = (24 + muteSize + 16 + percentageWidth + 112)
        .clamp(220.0, double.infinity)
        .toDouble();
    percentagePainter.dispose();

    return Material(
      key: const ValueKey('desktop-volume-popover'),
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: popoverWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              AppIconButton(
                key: const ValueKey('desktop-volume-mute-button'),
                tooltip: volume > 0 ? strings.mute : strings.volume,
                onPressed: onToggleMute,
                style: television
                    ? null
                    : IconButton.styleFrom(
                        minimumSize: Size.square(muteSize),
                        fixedSize: Size.square(muteSize),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        foregroundColor: colorScheme.primary,
                      ),
                icon: AppIcon(
                  volume > 0
                      ? AppIconAssets.playerVolume
                      : AppIconAssets.playerVolumeOff,
                  color: television
                      ? null
                      : (Theme.of(context).platform == TargetPlatform.windows)
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: AppSlider(
                    key: const ValueKey('desktop-volume-slider'),
                    autofocus: true,
                    value: volume.clamp(0, 1).toDouble(),
                    onChanged: onVolumeChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: percentageWidth,
                child: Text(
                  '${(volume * 100).round()}%',
                  key: const ValueKey('desktop-volume-percentage'),
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  style: percentageStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
