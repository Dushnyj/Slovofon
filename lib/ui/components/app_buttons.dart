import '../motion/motion_tooltip.dart';
import 'package:flutter/material.dart';
import '../adaptive/television_layout.dart';

import '../icons/app_icons.dart';
import '../motion/app_motion.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    required this.label,
    required this.onPressed,
    this.iconAsset,
    super.key,
  });

  final String label;
  final String? iconAsset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (iconAsset == null) {
      return FilledButton(onPressed: onPressed, child: Text(label));
    }

    return FilledButton.icon(
      onPressed: onPressed,
      icon: AppIcon(iconAsset!),
      label: Text(label),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    required this.label,
    required this.onPressed,
    this.iconAsset,
    super.key,
  });

  final String label;
  final String? iconAsset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (iconAsset == null) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: AppIcon(iconAsset!),
      label: Text(label),
    );
  }
}

class AppQuietButton extends StatelessWidget {
  const AppQuietButton({
    required this.label,
    required this.onPressed,
    this.iconAsset,
    super.key,
  });

  final String label;
  final String? iconAsset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (iconAsset == null) {
      return TextButton(onPressed: onPressed, child: Text(label));
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: AppIcon(iconAsset!),
      label: Text(label),
    );
  }
}

class AppIconActionButton extends StatelessWidget {
  const AppIconActionButton({
    required this.tooltip,
    required this.iconAsset,
    required this.onPressed,
    this.foregroundColor,
    this.backgroundColor,
    this.iconSize = 24,
    this.buttonSize = 44,
    this.buttonKey,
    super.key,
  });

  final String tooltip;
  final String iconAsset;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double iconSize;
  final double buttonSize;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    if (TelevisionLayout.isActive(context)) {
      return AppIconButton(
        key: buttonKey,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: AppIcon(iconAsset, size: iconSize < 20 ? 20 : iconSize),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    return AppIconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      style:
          IconButton.styleFrom(
            minimumSize: Size.square(buttonSize),
            fixedSize: Size.square(buttonSize),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const CircleBorder(),
            backgroundColor: backgroundColor ?? Colors.transparent,
            foregroundColor: foregroundColor ?? colorScheme.primary,
            overlayColor: Colors.transparent,
            disabledForegroundColor: colorScheme.onSurface.withValues(
              alpha: 0.38,
            ),
          ).copyWith(
            animationDuration: AppMotion.of(context).duration(),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return backgroundColor ?? Colors.transparent;
              }
              if (states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)) {
                return colorScheme.primary;
              }
              if (states.contains(WidgetState.hovered)) {
                return colorScheme.secondaryContainer;
              }
              return backgroundColor ?? Colors.transparent;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return colorScheme.onSurface.withValues(alpha: 0.38);
              }
              if (states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)) {
                return colorScheme.onPrimary;
              }
              if (states.contains(WidgetState.hovered)) {
                return colorScheme.onSecondaryContainer;
              }
              return foregroundColor ?? colorScheme.primary;
            }),
          ),
      icon: AppIcon(iconAsset, size: iconSize),
    );
  }
}
