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
    super.key,
  });

  final String tooltip;
  final String iconAsset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: AppIcon(iconAsset),
    );
  }
}
