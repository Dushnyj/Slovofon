import '../motion/motion_tooltip.dart';
import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import 'source_badge.dart';

/// Source metadata for the current playback version, independent of card prefs.
class PlaybackSourceLabel extends StatelessWidget {
  const PlaybackSourceLabel({
    required this.sourceId,
    required this.sourceName,
    this.maxLines = 2,
    this.textStyle,
    super.key,
  });

  final String sourceId;
  final String sourceName;
  final int? maxLines;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final localized = strings.sourceDisplayName(sourceId);
    final name = localized == sourceId && sourceName.trim().isNotEmpty
        ? sourceName.trim()
        : localized;
    final theme = Theme.of(context);

    return AppTooltip(
      message: name,
      excludeFromSemantics: true,
      child: Text(
        name,
        maxLines: maxLines,
        overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
        style: (textStyle ?? theme.textTheme.labelMedium)?.copyWith(
          color: sourceColorForId(sourceId, theme.colorScheme),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
