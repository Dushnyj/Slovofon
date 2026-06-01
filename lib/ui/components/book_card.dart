import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';
import '../icons/app_icons.dart';
import 'book_cover.dart';
import 'download_action_button.dart';
import 'source_badge.dart';

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
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final boundedProgress = book.progress.clamp(0, 1).toDouble();
    final showPause = isCurrentBook && isPlaying;
    final showPlayLoading = !showPause && (isPlayLoading || isPlaybackLoading);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 66,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BookCover(
                      title: book.title,
                      progress: boundedProgress,
                      imageUrl: book.coverUrl,
                      width: 66,
                      height: 94,
                    ),
                    const SizedBox(height: 4),
                    SourceBadge(
                      sourceId: book.sourceId,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _BookCardBody(book: book, yearLabel: yearLabel),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 36,
                height: 112,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _FavoriteActionButton(
                      buttonKey: ValueKey(
                        'book-card-favorite-${book.sourceId}-${book.sourceBookId}',
                      ),
                      isFavorite: isFavorite,
                      onPressed: onFavoritePressed,
                    ),
                    DownloadActionButton(
                      buttonKey: ValueKey(
                        'book-card-download-${book.sourceId}-${book.sourceBookId}',
                      ),
                      state: downloadState,
                      progress: downloadProgress,
                      isResolving: isDownloadLoading,
                      size: 38,
                      onPressed: onDownloadPressed,
                    ),
                    if (showPlayLoading)
                      SizedBox.square(
                        dimension: 34,
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
                      _CardIconButton(
                        buttonKey: ValueKey(
                          'book-card-play-${book.sourceId}-${book.sourceBookId}',
                        ),
                        tooltip: showPause ? strings.pause : strings.play,
                        iconAsset: showPause
                            ? AppIconAssets.playerPause
                            : AppIconAssets.playerPlay,
                        onPressed: onPlay,
                        foregroundColor: colorScheme.primary,
                        size: 34,
                        iconSize: 25,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCardBody extends StatelessWidget {
  const _BookCardBody({required this.book, required this.yearLabel});

  final AudioBook book;
  final String? yearLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final author = _shortPeopleLabel(book.author);
    final narrator = _shortPeopleLabel(book.narrator);
    final series = _seriesLabel(book.seriesTitle, book.seriesNumber);
    final rating = _ratingLabel(book.ratingValue);
    final effectiveYear = _trimOrNull(yearLabel) ?? book.year?.toString();
    final duration = _trimOrNull(book.durationLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 6),
        if (author != null)
          _MetaLine(iconAsset: AppIconAssets.bookAuthor, label: author),
        if (narrator != null)
          _MetaLine(iconAsset: AppIconAssets.bookNarrator, label: narrator),
        if (series != null)
          _MetaLine(iconAsset: AppIconAssets.bookSeries, label: series),
        const SizedBox(height: 5),
        DefaultTextStyle.merge(
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.1,
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              if (duration != null)
                _InlineMeta(
                  iconAsset: AppIconAssets.bookDuration,
                  label: duration,
                ),
              if (effectiveYear != null)
                _InlineMeta(
                  iconAsset: AppIconAssets.bookYear,
                  label: effectiveYear,
                ),
              if (rating != null)
                _InlineMeta(iconAsset: AppIconAssets.bookRating, label: rating),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoriteActionButton extends StatelessWidget {
  const _FavoriteActionButton({
    required this.isFavorite,
    required this.onPressed,
    this.buttonKey,
  });

  final bool isFavorite;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;

    return _CardIconButton(
      buttonKey: buttonKey,
      tooltip: isFavorite ? strings.removeFavorite : strings.addFavorite,
      iconAsset: isFavorite
          ? AppIconAssets.bookFavoriteFilled
          : AppIconAssets.bookFavorite,
      onPressed: onPressed,
      foregroundColor: isFavorite
          ? colorScheme.error
          : colorScheme.onSurfaceVariant,
      size: 38,
      iconSize: 25,
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          AppIcon(iconAsset, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(iconAsset, size: 13, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.tooltip,
    required this.iconAsset,
    required this.onPressed,
    required this.foregroundColor,
    this.size = 38,
    this.iconSize = 24,
    this.buttonKey,
  });

  final String tooltip;
  final String iconAsset;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final double size;
  final double iconSize;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final disabledColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.32);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: GestureDetector(
          key: buttonKey,
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Center(
              child: AppIcon(
                iconAsset,
                size: iconSize,
                color: enabled ? foregroundColor : disabledColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _shortPeopleLabel(String value) {
  final people = value
      .split(RegExp(r'\s*,\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (people.isEmpty) {
    return null;
  }
  if (people.length <= 2) {
    return people.join(', ');
  }
  return '${people.take(2).join(', ')} и др.';
}

String? _ratingLabel(double? value) {
  if (value == null || value <= 0) {
    return null;
  }
  final rounded = double.parse(value.clamp(0, 5).toStringAsFixed(1));
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return '$text из 5';
}

String? _seriesLabel(String? title, double? number) {
  final cleanedTitle = _trimOrNull(title);
  if (cleanedTitle == null) {
    return null;
  }
  final numberLabel = _seriesNumberLabel(number);
  return numberLabel == null ? cleanedTitle : '$cleanedTitle #$numberLabel';
}

String? _seriesNumberLabel(double? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == '-' || trimmed == '—') {
    return null;
  }
  return trimmed;
}
