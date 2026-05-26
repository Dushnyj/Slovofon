import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';
import 'book_cover.dart';
import '../icons/app_icons.dart';

enum BookCardDownloadState {
  none,
  queued,
  downloading,
  downloaded,
  paused,
  failed,
}

class BookCard extends StatelessWidget {
  const BookCard({
    required this.book,
    this.onTap,
    this.onPlay,
    this.onDownloadPressed,
    this.yearLabel,
    this.isFavorite = false,
    this.downloadState = BookCardDownloadState.none,
    this.downloadProgress = 0,
    super.key,
  });

  final AudioBook book;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onDownloadPressed;
  final String? yearLabel;
  final bool isFavorite;
  final BookCardDownloadState downloadState;
  final double downloadProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final boundedProgress = book.progress.clamp(0, 1).toDouble();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                    title: book.title,
                    progress: boundedProgress,
                    width: 62,
                    height: 88,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _InfoChip(
                              iconAsset: AppIconAssets.bookAuthor,
                              label: book.author,
                            ),
                            _InfoChip(
                              iconAsset: AppIconAssets.bookNarrator,
                              label: book.narrator,
                            ),
                            _InfoChip(
                              iconAsset: AppIconAssets.bookDuration,
                              label: book.durationLabel,
                            ),
                            if (yearLabel != null)
                              _InfoChip(
                                iconAsset: AppIconAssets.bookYear,
                                label: yearLabel!,
                              ),
                            _InfoChip(
                              iconAsset: AppIconAssets.bookSource,
                              label: book.sourceName,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CardActions(
                    isFavorite: isFavorite,
                    downloadState: downloadState,
                    downloadProgress: downloadProgress,
                    onDownloadPressed: onDownloadPressed,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: boundedProgress > 0
                        ? LinearProgressIndicator(
                            value: boundedProgress,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(999),
                          )
                        : Divider(
                            height: 5,
                            thickness: 5,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                  ),
                  if (boundedProgress > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      '${(boundedProgress * 100).round()}%',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton.filled(
                    tooltip: strings.play,
                    onPressed: onPlay ?? () {},
                    icon: const AppIcon(AppIconAssets.playerPlay),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: strings.details,
                    onPressed: onTap,
                    icon: const AppIcon(AppIconAssets.systemInfo),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.isFavorite,
    required this.downloadState,
    required this.downloadProgress,
    this.onDownloadPressed,
  });

  final bool isFavorite;
  final BookCardDownloadState downloadState;
  final double downloadProgress;
  final VoidCallback? onDownloadPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        IconButton(
          tooltip: isFavorite ? strings.removeFavorite : strings.addFavorite,
          onPressed: () {},
          style: isFavorite
              ? IconButton.styleFrom(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                )
              : null,
          icon: AppIcon(
            AppIconAssets.bookFavorite,
            color: isFavorite
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        _DownloadIconButton(
          state: downloadState,
          progress: downloadProgress,
          onPressed: onDownloadPressed,
        ),
      ],
    );
  }
}

class _DownloadIconButton extends StatelessWidget {
  const _DownloadIconButton({
    required this.state,
    required this.progress,
    this.onPressed,
  });

  final BookCardDownloadState state;
  final double progress;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final boundedProgress = progress.clamp(0, 1).toDouble();

    final iconAsset = switch (state) {
      BookCardDownloadState.downloaded => AppIconAssets.deleteDownload,
      BookCardDownloadState.downloading => AppIconAssets.pauseDownload,
      BookCardDownloadState.paused => AppIconAssets.resumeDownload,
      BookCardDownloadState.failed => AppIconAssets.downloadRetry,
      BookCardDownloadState.queued => AppIconAssets.downloadQueued,
      BookCardDownloadState.none => AppIconAssets.download,
    };
    final tooltip = switch (state) {
      BookCardDownloadState.downloaded => strings.deleteDownloaded,
      BookCardDownloadState.downloading => strings.pauseDownload,
      BookCardDownloadState.paused => strings.resumeDownload,
      BookCardDownloadState.failed => strings.retry,
      BookCardDownloadState.queued => strings.download,
      BookCardDownloadState.none => strings.download,
    };

    if (state == BookCardDownloadState.downloading) {
      return SizedBox.square(
        dimension: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: boundedProgress,
              strokeWidth: 3,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              icon: AppIcon(iconAsset, size: 20),
            ),
          ],
        ),
      );
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: AppIcon(
        iconAsset,
        color: state == BookCardDownloadState.downloaded
            ? colorScheme.error
            : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(iconAsset, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
