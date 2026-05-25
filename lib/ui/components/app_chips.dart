import 'package:flutter/material.dart';

import '../../app/theme/app_color_tokens.dart';
import '../icons/app_icons.dart';

class SourceChip extends StatelessWidget {
  const SourceChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = AppColorTokens.readableOn(color);

    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: foreground),
      avatar: AppIcon(AppIconAssets.bookSource, size: 16, color: foreground),
      backgroundColor: color,
      side: BorderSide(color: color),
    );
  }
}

class AccessChip extends StatelessWidget {
  const AccessChip({required this.label, required this.iconAsset, super.key});

  final String label;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      label: Text(label),
      avatar: AppIcon(
        iconAsset,
        size: 16,
        color: colorScheme.onSecondaryContainer,
      ),
      backgroundColor: colorScheme.secondaryContainer,
      labelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
      side: BorderSide(color: colorScheme.secondaryContainer),
    );
  }
}
