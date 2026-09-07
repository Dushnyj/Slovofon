import 'package:flutter/material.dart';

import '../../app/theme/app_color_tokens.dart';
import 'download_action_button.dart';

class ChapterTile extends StatelessWidget {
  const ChapterTile({
    required this.index,
    required this.title,
    required this.durationLabel,
    required this.progress,
    required this.onTap,
    this.isDownloaded = false,
    this.isCurrent = false,
    this.downloadState = BookCardDownloadState.none,
    this.downloadProgress = 0,
    this.onDownloadPressed,
    super.key,
  });

  /// Human-readable one-based position in the displayed chapter list.
  /// A source's raw chapter index is an identifier/order hint, not this label.
  final int index;
  final String title;
  final String durationLabel;
  final double progress;
  final bool isDownloaded;
  final bool isCurrent;
  final BookCardDownloadState downloadState;
  final double downloadProgress;
  final VoidCallback? onTap;
  final VoidCallback? onDownloadPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final boundedProgress = progress.clamp(0, 1).toDouble();

    return Card(
      color: isCurrent ? tokens.selected : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 38,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? colorScheme.primary
                        : colorScheme.primaryContainer,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$index',
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: isCurrent
                                    ? colorScheme.onPrimary
                                    : colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      durationLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (boundedProgress > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: boundedProgress,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ],
                  ],
                ),
              ),
              DownloadActionButton(
                state: isDownloaded
                    ? BookCardDownloadState.downloaded
                    : downloadState,
                progress: downloadProgress,
                onPressed: onDownloadPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
