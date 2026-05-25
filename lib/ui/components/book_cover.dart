import 'package:flutter/material.dart';

import '../../app/theme/app_color_tokens.dart';
import '../icons/app_icons.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    required this.title,
    this.progress = 0,
    this.width = 76,
    this.height = 104,
    this.showProgressPercent = true,
    super.key,
  });

  final String title;
  final double progress;
  final double width;
  final double height;
  final bool showProgressPercent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final boundedProgress = progress.clamp(0, 1).toDouble();
    final initials = title
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AppIcon(
                    AppIconAssets.bookFull,
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.44,
                    ),
                  ),
                ),
              ),
              Center(
                child: boundedProgress > 0 && showProgressPercent
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.scrim.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            '${(boundedProgress * 100).round()}%',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      )
                    : Text(
                        initials,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (boundedProgress > 0)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: LinearProgressIndicator(
                    value: boundedProgress,
                    minHeight: 6,
                    color: tokens.success,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
