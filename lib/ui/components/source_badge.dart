import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';

class SourceBadge extends StatelessWidget {
  const SourceBadge({
    required this.sourceId,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
    super.key,
  });

  final String sourceId;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final color = sourceColorForId(sourceId, Theme.of(context).colorScheme);

    return Text(
      context.strings.sourceDisplayName(sourceId),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
    );
  }
}

Color sourceColorForId(String sourceId, ColorScheme colorScheme) {
  final dark = colorScheme.brightness == Brightness.dark;
  return switch (sourceId) {
    'izib' => dark ? const Color(0xFFD0A2FF) : const Color(0xFF7B4FB1),
    'akniga' => dark ? const Color(0xFF4ADE80) : const Color(0xFF167A44),
    'yakniga' => dark ? const Color(0xFF2DD4BF) : const Color(0xFF008278),
    'knigavuhe' => dark ? const Color(0xFF38BDF8) : const Color(0xFF176B9A),
    'knigoblud' => dark ? const Color(0xFF93B7FF) : const Color(0xFF315F9E),
    'baza_knig' => dark ? const Color(0xFFFBBF24) : const Color(0xFFA16207),
    _ => colorScheme.primary,
  };
}

Color sourceContainerColorForId(String sourceId, ColorScheme colorScheme) {
  final color = sourceColorForId(sourceId, colorScheme);
  final alpha = colorScheme.brightness == Brightness.dark ? 0.22 : 0.13;
  return Color.alphaBlend(
    color.withValues(alpha: alpha),
    colorScheme.surfaceContainer,
  );
}

Color sourceOnContainerColorForId(String sourceId, ColorScheme colorScheme) {
  final container = sourceContainerColorForId(sourceId, colorScheme);
  return AppColorTokens.readableOn(container);
}
