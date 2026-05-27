import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';
import 'app_buttons.dart';
import 'book_cover.dart';
import 'download_action_button.dart';
import '../icons/app_icons.dart';

export 'download_action_button.dart';

class BookCard extends StatelessWidget {
  const BookCard({
    required this.book,
    this.onTap,
    this.onPlay,
    this.onFavoritePressed,
    this.onDownloadPressed,
    this.yearLabel,
    this.isFavorite = false,
    this.downloadState = BookCardDownloadState.none,
    this.downloadProgress = 0,
    this.isPlayLoading = false,
    this.isPlaybackLoading = false,
    this.isCurrentBook = false,
    this.isPlaying = false,
    this.isDownloadLoading = false,
    super.key,
  });

  final AudioBook book;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onDownloadPressed;
  final String? yearLabel;
  final bool isFavorite;
  final BookCardDownloadState downloadState;
  final double downloadProgress;
  final bool isPlayLoading;
  final bool isPlaybackLoading;
  final bool isCurrentBook;
  final bool isPlaying;
  final bool isDownloadLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final boundedProgress = book.progress.clamp(0, 1).toDouble();
    final showPause = isCurrentBook && isPlaying;
    final showPlayLoading = !showPause && (isPlayLoading || isPlaybackLoading);

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
                    imageUrl: book.coverUrl,
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
                    isDownloadLoading: isDownloadLoading,
                    onFavoritePressed: onFavoritePressed,
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
                  if (showPlayLoading)
                    SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: SizedBox.square(
                          key: const ValueKey('book-card-play-loading'),
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    )
                  else
                    AppIconActionButton(
                      tooltip: showPause ? strings.pause : strings.play,
                      iconAsset: showPause
                          ? AppIconAssets.playerPause
                          : AppIconAssets.playerPlay,
                      onPressed: onPlay,
                      foregroundColor: colorScheme.primary,
                    ),
                  const SizedBox(width: 8),
                  AppIconActionButton(
                    tooltip: strings.details,
                    onPressed: onTap,
                    iconAsset: AppIconAssets.systemInfo,
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

class _FavoriteActionButton extends StatelessWidget {
  const _FavoriteActionButton({
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;

    return AppIconActionButton(
      tooltip: isFavorite ? strings.removeFavorite : strings.addFavorite,
      iconAsset: isFavorite
          ? AppIconAssets.bookFavoriteFilled
          : AppIconAssets.bookFavorite,
      onPressed: onPressed,
      foregroundColor: isFavorite
          ? colorScheme.error
          : colorScheme.onSurfaceVariant,
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.isFavorite,
    required this.downloadState,
    required this.downloadProgress,
    required this.isDownloadLoading,
    this.onFavoritePressed,
    this.onDownloadPressed,
  });

  final bool isFavorite;
  final BookCardDownloadState downloadState;
  final double downloadProgress;
  final bool isDownloadLoading;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onDownloadPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FavoriteActionButton(
          isFavorite: isFavorite,
          onPressed: onFavoritePressed,
        ),
        const SizedBox(height: 4),
        DownloadActionButton(
          state: downloadState,
          progress: downloadProgress,
          isResolving: isDownloadLoading,
          onPressed: onDownloadPressed,
        ),
      ],
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
