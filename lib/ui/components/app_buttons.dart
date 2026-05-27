import 'package:flutter/material.dart';

import '../icons/app_icons.dart';

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
    super.key,
  });

  final String tooltip;
  final String iconAsset;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double iconSize;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: Size.square(buttonSize),
        fixedSize: Size.square(buttonSize),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
        backgroundColor: backgroundColor ?? Colors.transparent,
        foregroundColor: foregroundColor ?? colorScheme.onSurfaceVariant,
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
      ),
      icon: AppIcon(iconAsset, size: iconSize),
    );
  }
}
