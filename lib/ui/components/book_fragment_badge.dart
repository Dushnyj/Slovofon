import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../icons/app_icons.dart';

/// Access to a free sample is not access to the complete audiobook.
class BookFragmentBadge extends StatelessWidget {
  const BookFragmentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppIcon(
          AppIconAssets.bookFragment,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        Text(
          context.strings.bookFragment,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
