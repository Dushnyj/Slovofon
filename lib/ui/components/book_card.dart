import '../motion/app_motion.dart';
import '../motion/motion_tooltip.dart';
import '../motion/motion_progress_indicator.dart';
import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../app/localization/duration_label.dart';
import '../../domain/models/audio_book.dart';
import '../adaptive/desktop_layout.dart';
import '../adaptive/television_layout.dart';
import '../icons/app_icons.dart';
import 'book_cover.dart';
import 'book_fragment_badge.dart';
import 'download_action_button.dart';
import 'source_badge.dart';
import 'responsive_tile_grid.dart';
import 'television_book_card.dart';

export 'download_action_button.dart';

enum DesktopBookPresentation { card, result, row, feature }

class BookCard extends StatelessWidget {
  const BookCard({
    required this.book,
    this.onTap,
    this.onPlay,
    this.onFavoritePressed,
    this.onDownloadPressed,
    this.onLaterPressed,
    this.yearLabel,
    this.isFavorite = false,
    this.isLater = false,
    this.downloadState = BookCardDownloadState.none,
    this.downloadProgress = 0,
    this.isPlayLoading = false,
    this.isPlaybackLoading = false,
    this.isCurrentBook = false,
    this.isPlaying = false,
    this.isDownloadLoading = false,
    this.desktopPresentation = DesktopBookPresentation.card,
    super.key,
  });

  final AudioBook book;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onFavoritePressed;
  final VoidCallback? onDownloadPressed;
  final VoidCallback? onLaterPressed;
  final String? yearLabel;
  final bool isFavorite;
  final bool isLater;
  final BookCardDownloadState downloadState;
  final double downloadProgress;
  final bool isPlayLoading;
  final bool isPlaybackLoading;
  final bool isCurrentBook;
  final bool isPlaying;
  final bool isDownloadLoading;
  final DesktopBookPresentation desktopPresentation;

  @override
  Widget build(BuildContext context) {
    final isDesktopLayout = isDesktopTileLayout(context);

    if (TelevisionLayout.isActive(context)) {
      return TelevisionBookCard(card: this);
    }

    if (DesktopLayout.isActive(context)) {
      return _WindowsBookCard(card: this);
    }

    final card = Card(
      child: InkWell(
        hoverDuration: AppMotion.of(context).duration(
          full: const Duration(milliseconds: 50),
          reduced: const Duration(milliseconds: 40),
        ),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: _PortableBookCardLayout(
          key: isDesktopLayout
              ? const ValueKey('book-card-desktop-tile')
              : null,
          card: this,
          wide: isDesktopLayout,
        ),
      ),
    );

    if (!isDesktopLayout) {
      return card;
    }

    // On a wide touch device the grid already grows its columns with text.
    // Do not squeeze those larger cells back into the 420 dp default tile.
    // Windows and television have returned through their own branches above.
    if (MediaQuery.textScalerOf(context).scale(14) > 14) {
      return card;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: card,
      ),
    );
  }
}

class _WindowsBookCard extends StatefulWidget {
  const _WindowsBookCard({required this.card});
  final BookCard card;

  @override
  State<_WindowsBookCard> createState() => _WindowsBookCardState();
}

class _WindowsBookCardState extends State<_WindowsBookCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final book = card.book;
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final pausedAction = card.isCurrentBook && card.isPlaying;
    final loading =
        !pausedAction && (card.isPlayLoading || card.isPlaybackLoading);
    final progress = book.progress.clamp(0, 1).toDouble();
    final preferences = DesktopPreferences.maybeOf(context);
    final compact = preferences?.compactCards ?? false;
    final coverWidth = compact ? 76.0 : 96.0;
    final showPercent = preferences?.showPercentOnCovers ?? true;
    final percentInFlow = _needsCoverMetadataFooter(
      context,
      book,
      coverWidth,
      showSource: false,
      showPercent: showPercent,
    );
    return AnimatedContainer(
      key: const ValueKey('book-card-desktop-tile'),
      duration: DesktopLayout.motionDuration(context),
      // Reserve the same inset for resting and focused borders.
      padding: EdgeInsets.all(_focused || card.isCurrentBook ? 0 : 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused || card.isCurrentBook
              ? scheme.primary
              : _hovered
              ? scheme.outline
              : scheme.outlineVariant,
          width: _focused || card.isCurrentBook ? 2 : 1,
        ),
      ),
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverDuration: AppMotion.of(context).duration(
            full: const Duration(milliseconds: 50),
            reduced: const Duration(milliseconds: 40),
          ),
          onTap: card.onTap,
          onHover: (value) => setState(() => _hovered = value),
          onFocusChange: (value) => setState(() => _focused = value),
          child: Padding(
            padding: EdgeInsets.all(
              compact
                  ? 12
                  : card.desktopPresentation == DesktopBookPresentation.feature
                  ? 24
                  : 16,
            ),
            child: card.desktopPresentation == DesktopBookPresentation.result
                ? _WindowsSearchResultContent(card: card)
                : card.desktopPresentation != DesktopBookPresentation.card
                ? _WindowsWorkspaceBookContent(card: card)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BookCover(
                            title: book.title,
                            imageUrl: book.coverUrl,
                            progress: progress,
                            width: coverWidth,
                            height: compact ? 108 : 136,
                            showProgressPercent: showPercent && !percentInFlow,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _DesktopBookCardBody(
                              strings: strings,
                              book: book,
                              yearLabel: card.yearLabel,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (preferences?.showSourceOnCards ?? true)
                            SourceBadge(sourceId: book.sourceId),
                          if (percentInFlow)
                            Text(
                              '${(progress * 100).round()}%',
                              key: const ValueKey('book-card-footer-percent'),
                              style: _cardPercentStyle(context),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _FavoriteActionButton(
                                buttonKey: ValueKey(
                                  'book-card-favorite-${book.sourceId}-${book.sourceBookId}',
                                ),
                                isFavorite: card.isFavorite,
                                onPressed: card.onFavoritePressed,
                              ),
                              DownloadActionButton(
                                buttonKey: ValueKey(
                                  'book-card-download-${book.sourceId}-${book.sourceBookId}',
                                ),
                                state: card.downloadState,
                                progress: card.downloadProgress,
                                isResolving: card.isDownloadLoading,
                                size: 40,
                                onPressed: card.onDownloadPressed,
                              ),
                              if (card.onLaterPressed != null)
                                _BookLaterMenu(card: card),
                              const SizedBox(width: 8),
                              FilledButton(
                                key: ValueKey(
                                  'book-card-play-${book.sourceId}-${book.sourceBookId}',
                                ),
                                onPressed: loading ? null : card.onPlay,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(44, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                child: AppTooltip(
                                  message: pausedAction
                                      ? strings.pause
                                      : strings.play,
                                  child: loading
                                      ? SizedBox.square(
                                          key: const ValueKey(
                                            'book-card-play-loading',
                                          ),
                                          dimension: 20,
                                          child: AppCircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        )
                                      : Semantics(
                                          label: pausedAction
                                              ? strings.pause
                                              : strings.play,
                                          child: AppIcon(
                                            pausedAction
                                                ? AppIconAssets.playerPause
                                                : AppIconAssets.playerPlay,
                                            size: 20,
                                            color: card.onPlay == null
                                                ? scheme.onSurfaceVariant
                                                : scheme.onPrimary,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Wide rows have separate metadata and playback zones, not a stretched tile.
/// Search results prioritize the narration and its actions over catalog facts.
/// A result remains a row on a desktop instead of a stretched mobile tile.
class _WindowsSearchResultContent extends StatelessWidget {
  const _WindowsSearchResultContent({required this.card});

  final BookCard card;

  @override
  Widget build(BuildContext context) {
    final book = card.book;
    final theme = Theme.of(context);
    final preferences = DesktopPreferences.maybeOf(context);
    final compact = preferences?.compactCards ?? false;
    final strings = context.strings;
    final coverWidth = compact ? 52.0 : 64.0;
    final showPercent = preferences?.showPercentOnCovers ?? true;
    final percentInFlow = _needsCoverMetadataFooter(
      context,
      book,
      coverWidth,
      showSource: false,
      showPercent: showPercent,
    );
    final facts = Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        if (book.author.trim().isNotEmpty)
          _DesktopMetaChip(
            iconAsset: AppIconAssets.bookAuthor,
            label: book.author,
          ),
        if (book.durationLabel.trim().isNotEmpty)
          _DesktopMetaChip(
            iconAsset: AppIconAssets.bookDuration,
            label: context.strings.formatDurationLabel(book.durationLabel),
          ),
        if (book.chapterCount > 0)
          _DesktopMetaChip(
            iconAsset: AppIconAssets.playerChapters,
            label: strings.chaptersCount(book.chapterCount),
          ),
        if (_seriesLabel(book.seriesTitle, book.seriesNumber)
            case final String series)
          _DesktopMetaChip(iconAsset: AppIconAssets.bookSeries, label: series),
        if (_trimOrNull(card.yearLabel) ?? book.year?.toString()
            case final String year)
          _DesktopMetaChip(iconAsset: AppIconAssets.bookYear, label: year),
        if (_ratingLabel(context.strings, book.ratingValue)
            case final String rating)
          _DesktopMetaChip(iconAsset: AppIconAssets.bookRating, label: rating),
      ],
    );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (book.isFragment) const BookFragmentBadge(),
        if (book.narrator.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          _WorkspaceBookPerson(
            icon: AppIconAssets.bookNarrator,
            value: book.narrator,
          ),
        ],
        if (percentInFlow) ...[
          const SizedBox(height: 6),
          Text(
            '${(book.progress.clamp(0, 1) * 100).round()}%',
            key: const ValueKey('book-card-footer-percent'),
            style: _cardPercentStyle(context),
          ),
        ],
      ],
    );
    final cover = BookCover(
      title: book.title,
      imageUrl: book.coverUrl,
      progress: book.progress.clamp(0, 1),
      width: coverWidth,
      height: compact ? 74 : 92,
      showProgressPercent: showPercent && !percentInFlow,
    );
    final actions = _WindowsResultActions(card: card);
    final showSource = preferences?.showSourceOnCards ?? true;

    return LayoutBuilder(
      builder: (context, constraints) {
        final factor = DesktopLayout.workspaceScaleFactor(context);
        if (constraints.maxWidth >= 640 * factor) {
          return Row(
            key: const ValueKey('desktop-search-result-row'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              cover,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 8), facts],
                ),
              ),
              const SizedBox(width: 20),
              SizedBox(
                width: card.onLaterPressed == null ? 136 : 176,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showSource) ...[
                      SourceBadge(sourceId: book.sourceId, maxLines: 2),
                      const SizedBox(height: 12),
                    ],
                    actions,
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          key: const ValueKey('desktop-search-result-stacked'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                const SizedBox(width: 16),
                Expanded(child: identity),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                if (showSource)
                  SourceBadge(sourceId: book.sourceId, maxLines: 2),
                actions,
              ],
            ),
            if (!compact) ...[const SizedBox(height: 12), facts],
          ],
        );
      },
    );
  }
}

class _WindowsResultActions extends StatelessWidget {
  const _WindowsResultActions({required this.card});
  final BookCard card;

  @override
  Widget build(BuildContext context) {
    final book = card.book;
    final strings = context.strings;
    final paused = card.isCurrentBook && card.isPlaying;
    final loading = !paused && (card.isPlayLoading || card.isPlaybackLoading);
    final label = paused ? strings.pause : strings.play;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        _FavoriteActionButton(
          buttonKey: ValueKey(
            'book-card-favorite-${book.sourceId}-${book.sourceBookId}',
          ),
          isFavorite: card.isFavorite,
          onPressed: card.onFavoritePressed,
        ),
        DownloadActionButton(
          buttonKey: ValueKey(
            'book-card-download-${book.sourceId}-${book.sourceBookId}',
          ),
          state: card.downloadState,
          progress: card.downloadProgress,
          isResolving: card.isDownloadLoading,
          size: 36,
          onPressed: card.onDownloadPressed,
        ),
        if (card.onLaterPressed != null) _BookLaterMenu(card: card),
        AppTooltip(
          message: label,
          child: FilledButton(
            key: ValueKey(
              'book-card-play-${book.sourceId}-${book.sourceBookId}',
            ),
            onPressed: loading ? null : card.onPlay,
            style: FilledButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: loading
                ? const SizedBox.square(
                    key: ValueKey('book-card-play-loading'),
                    dimension: 20,
                    child: AppCircularProgressIndicator(strokeWidth: 2),
                  )
                : AppIcon(
                    paused
                        ? AppIconAssets.playerPause
                        : AppIconAssets.playerPlay,
                    size: 20,
                    semanticsLabel: label,
                  ),
          ),
        ),
      ],
    );
  }
}

class _BookLaterMenu extends StatelessWidget {
  const _BookLaterMenu({required this.card});
  final BookCard card;

  @override
  Widget build(BuildContext context) => PopupMenuButton<bool>(
    popUpAnimationStyle: AppMotion.of(context).hasSpatialMotion
        ? AppMotion.of(context).dialogAnimationStyle
        : AnimationStyle.noAnimation,
    key: ValueKey(
      'book-card-more-${card.book.sourceId}-${card.book.sourceBookId}',
    ),
    tooltip: context.strings.bookActions,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 180, maxWidth: 320),
    icon: const AppIcon(AppIconAssets.systemMore, size: 20),
    onSelected: (_) => card.onLaterPressed?.call(),
    itemBuilder: (context) => [
      PopupMenuItem(
        value: true,
        child: Text(
          card.isLater
              ? context.strings.removeFromLater
              : context.strings.addToLater,
        ),
      ),
    ],
  );
}

class _WindowsWorkspaceBookContent extends StatelessWidget {
  const _WindowsWorkspaceBookContent({required this.card});
  final BookCard card;

  @override
  Widget build(BuildContext context) {
    final book = card.book;
    final strings = context.strings;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preferences = DesktopPreferences.maybeOf(context);
    final compact = preferences?.compactCards ?? false;
    final featured =
        card.desktopPresentation == DesktopBookPresentation.feature;
    final progress = book.progress.clamp(0, 1).toDouble();
    final paused = card.isCurrentBook && card.isPlaying;
    final loading = !paused && (card.isPlayLoading || card.isPlaybackLoading);
    final description = book.description?.trim();
    final coverWidth = featured
        ? (compact || MediaQuery.sizeOf(context).height < 760 ? 132.0 : 184.0)
        : (compact ? 60.0 : 72.0);
    final showPercent = preferences?.showPercentOnCovers ?? true;
    final percentInFlow = _needsCoverMetadataFooter(
      context,
      book,
      coverWidth,
      showSource: false,
      showPercent: showPercent,
    );

    final metadata = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preferences?.showSourceOnCards ?? true) ...[
          SourceBadge(sourceId: book.sourceId, maxLines: 2),
          SizedBox(height: featured ? 8 : 4),
        ],
        Text(
          book.title,
          style:
              (featured
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
        ),
        SizedBox(height: featured ? 12 : 8),
        if (book.isFragment) const BookFragmentBadge(),
        if (featured && book.author.trim().isNotEmpty)
          _WorkspaceBookPerson(
            icon: AppIconAssets.bookAuthor,
            value: book.author,
          ),
        if (featured && book.narrator.trim().isNotEmpty)
          _WorkspaceBookPerson(
            icon: AppIconAssets.bookNarrator,
            value: book.narrator,
          ),
        if (!featured)
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (book.author.trim().isNotEmpty)
                _DesktopMetaChip(
                  iconAsset: AppIconAssets.bookAuthor,
                  label: book.author,
                  textStyle: theme.textTheme.bodyMedium,
                ),
              if (book.narrator.trim().isNotEmpty)
                _DesktopMetaChip(
                  iconAsset: AppIconAssets.bookNarrator,
                  label: book.narrator,
                  textStyle: theme.textTheme.bodyMedium,
                ),
            ],
          ),
        if (featured &&
            _seriesLabel(book.seriesTitle, book.seriesNumber) != null)
          _WorkspaceBookPerson(
            icon: AppIconAssets.bookSeries,
            value: _seriesLabel(book.seriesTitle, book.seriesNumber)!,
          ),
        SizedBox(height: featured ? 10 : 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            if (!featured)
              if (_seriesLabel(book.seriesTitle, book.seriesNumber)
                  case final String series)
                _DesktopMetaChip(
                  iconAsset: AppIconAssets.bookSeries,
                  label: series,
                ),
            if (book.durationLabel.trim().isNotEmpty)
              _DesktopMetaChip(
                iconAsset: AppIconAssets.bookDuration,
                label: context.strings.formatDurationLabel(book.durationLabel),
              ),
            if (book.chapterCount > 0)
              _DesktopMetaChip(
                iconAsset: AppIconAssets.playerChapters,
                label: strings.chaptersCount(book.chapterCount),
              ),
            if (_trimOrNull(card.yearLabel) ?? book.year?.toString()
                case final String year)
              _DesktopMetaChip(iconAsset: AppIconAssets.bookYear, label: year),
            if (_ratingLabel(context.strings, book.ratingValue)
                case final String rating)
              _DesktopMetaChip(
                iconAsset: AppIconAssets.bookRating,
                label: rating,
              ),
          ],
        ),
        if (featured &&
            !compact &&
            MediaQuery.sizeOf(context).height >= 850 &&
            description != null &&
            description.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ],
    );

    final playback = Column(
      key: const ValueKey('desktop-book-playback-zone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              strings.bookProgress,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (!showPercent || percentInFlow)
              Text(
                '${(progress * 100).round()}%',
                key: const ValueKey('book-card-footer-percent'),
                style: theme.textTheme.labelLarge,
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AppLinearProgressIndicator(value: progress, minHeight: 5),
        ),
        SizedBox(height: featured ? 18 : 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: ValueKey(
                'book-card-play-${book.sourceId}-${book.sourceBookId}',
              ),
              onPressed: loading ? null : card.onPlay,
              style: FilledButton.styleFrom(minimumSize: const Size(108, 44)),
              icon: loading
                  ? const SizedBox.square(
                      key: ValueKey('book-card-play-loading'),
                      dimension: 18,
                      child: AppCircularProgressIndicator(strokeWidth: 2),
                    )
                  : AppIcon(
                      paused
                          ? AppIconAssets.playerPause
                          : AppIconAssets.playerPlay,
                      size: 20,
                    ),
              label: Text(paused ? strings.pause : strings.play),
            ),
            _FavoriteActionButton(
              buttonKey: ValueKey(
                'book-card-favorite-${book.sourceId}-${book.sourceBookId}',
              ),
              isFavorite: card.isFavorite,
              onPressed: card.onFavoritePressed,
            ),
            DownloadActionButton(
              buttonKey: ValueKey(
                'book-card-download-${book.sourceId}-${book.sourceBookId}',
              ),
              state: card.downloadState,
              progress: card.downloadProgress,
              isResolving: card.isDownloadLoading,
              size: 44,
              onPressed: card.onDownloadPressed,
            ),
            if (card.onLaterPressed != null) _BookLaterMenu(card: card),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final factor = DesktopLayout.workspaceScaleFactor(context);
        final cover = BookCover(
          title: book.title,
          imageUrl: book.coverUrl,
          progress: progress,
          width: coverWidth,
          height: coverWidth * 1.42,
          showProgressPercent: showPercent && !percentInFlow,
        );
        if (featured) {
          final information = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [metadata, const SizedBox(height: 24), playback],
          );
          // Keep listening controls next to the cover, with the metadata they
          // belong to, rather than stretching a second row below the artwork.
          if (constraints.maxWidth >= coverWidth + 28 + 320 * factor) {
            return Row(
              key: const ValueKey('desktop-feature-book-content'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                const SizedBox(width: 28),
                Expanded(child: information),
              ],
            );
          }
          return Column(
            key: const ValueKey('desktop-feature-book-content'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: AlignmentDirectional.centerStart, child: cover),
              const SizedBox(height: 20),
              information,
            ],
          );
        }
        final sideBySide = constraints.maxWidth >= 760 * factor;
        final bookHeading = constraints.maxWidth >= coverWidth + 260 * factor
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cover,
                  SizedBox(width: featured ? 28 : 20),
                  Expanded(child: metadata),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [cover, const SizedBox(height: 20), metadata],
              );
        // Collection rows align their controls at the right edge when there is
        // enough room, and reflow instead of shrinking the requested text size.
        if (!sideBySide) {
          return Column(
            key: const ValueKey('desktop-book-row-content'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [bookHeading, const SizedBox(height: 16), playback],
          );
        }
        return Row(
          key: const ValueKey('desktop-book-row-content'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: bookHeading),
            const SizedBox(width: 24),
            SizedBox(width: 300 * factor, child: playback),
          ],
        );
      },
    );
  }
}

class _WorkspaceBookPerson extends StatelessWidget {
  const _WorkspaceBookPerson({required this.icon, required this.value});
  final String icon;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppIcon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _PortableBookCardLayout extends StatelessWidget {
  const _PortableBookCardLayout({
    required this.card,
    required this.wide,
    super.key,
  });

  final BookCard card;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final book = card.book;
    final preferences = DesktopPreferences.maybeOf(context);
    final compact = preferences?.compactCards ?? false;
    final showSource = preferences?.showSourceOnCards ?? true;
    final showPercent = preferences?.showPercentOnCovers ?? true;
    final coverWidth = wide ? (compact ? 72.0 : 84.0) : (compact ? 56.0 : 66.0);
    final footer = _needsCoverMetadataFooter(
      context,
      book,
      coverWidth,
      showSource: showSource,
      showPercent: showPercent,
    );

    return Padding(
      padding: EdgeInsets.all(wide ? (compact ? 8 : 10) : (compact ? 6 : 8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: coverWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BookCover(
                      title: book.title,
                      progress: book.progress.clamp(0, 1).toDouble(),
                      imageUrl: book.coverUrl,
                      width: coverWidth,
                      height: wide
                          ? (compact ? 102 : 118)
                          : (compact ? 80 : 94),
                      showProgressPercent: showPercent && !footer,
                    ),
                    if (showSource && !footer) ...[
                      SizedBox(height: wide ? 6 : 4),
                      SourceBadge(
                        sourceId: book.sourceId,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: wide ? 14 : 9),
              Expanded(
                child: wide
                    ? _DesktopBookCardBody(
                        strings: context.strings,
                        book: book,
                        yearLabel: card.yearLabel,
                      )
                    : _BookCardBody(book: book, yearLabel: card.yearLabel),
              ),
            ],
          ),
          if (footer)
            _BookCardMetadataFooter(
              book: book,
              showSource: showSource,
              showPercent: showPercent,
            ),
          const SizedBox(height: 4),
          // Keep every action touch-sized without squeezing the book metadata.
          // A wrapping footer also works on a narrow phone at large text sizes.
          _PortableBookCardActions(card: card),
        ],
      ),
    );
  }
}

class _PortableBookCardActions extends StatelessWidget {
  const _PortableBookCardActions({required this.card});
  final BookCard card;

  @override
  Widget build(BuildContext context) {
    final book = card.book;
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final paused = card.isCurrentBook && card.isPlaying;
    final loading = !paused && (card.isPlayLoading || card.isPlaybackLoading);
    return Wrap(
      key: const ValueKey('book-card-portable-actions'),
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FavoriteActionButton(
          buttonKey: ValueKey(
            'book-card-favorite-${book.sourceId}-${book.sourceBookId}',
          ),
          isFavorite: card.isFavorite,
          onPressed: card.onFavoritePressed,
          size: 48,
        ),
        DownloadActionButton(
          buttonKey: ValueKey(
            'book-card-download-${book.sourceId}-${book.sourceBookId}',
          ),
          state: card.downloadState,
          progress: card.downloadProgress,
          isResolving: card.isDownloadLoading,
          size: 48,
          onPressed: card.onDownloadPressed,
        ),
        if (card.onLaterPressed != null) _BookLaterMenu(card: card),
        if (loading)
          SizedBox.square(
            dimension: 48,
            child: Center(
              child: SizedBox.square(
                key: const ValueKey('book-card-play-loading'),
                dimension: 22,
                child: AppCircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: colors.primary,
                ),
              ),
            ),
          )
        else
          _CardIconButton(
            buttonKey: ValueKey(
              'book-card-play-${book.sourceId}-${book.sourceBookId}',
            ),
            tooltip: paused ? strings.pause : strings.play,
            iconAsset: paused
                ? AppIconAssets.playerPause
                : AppIconAssets.playerPlay,
            onPressed: card.onPlay,
            foregroundColor: colors.primary,
            size: 48,
            iconSize: 25,
          ),
      ],
    );
  }
}

String _cardSourceName(BuildContext context, AudioBook book) {
  final localized = context.strings.sourceDisplayName(book.sourceId);
  return localized == book.sourceId && book.sourceName.trim().isNotEmpty
      ? book.sourceName.trim()
      : localized;
}

TextStyle? _cardSourceStyle(BuildContext context, AudioBook book) =>
    Theme.of(context).textTheme.labelSmall?.copyWith(
      color: sourceColorForId(book.sourceId, Theme.of(context).colorScheme),
      fontWeight: FontWeight.w800,
      height: 1.05,
    );

TextStyle? _cardPercentStyle(BuildContext context) => Theme.of(
  context,
).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800);

bool _needsCoverMetadataFooter(
  BuildContext context,
  AudioBook book,
  double coverWidth, {
  required bool showSource,
  required bool showPercent,
}) {
  double width(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final result = painter.width;
    painter.dispose();
    return result;
  }

  return (showSource &&
          width(
                _cardSourceName(context, book),
                _cardSourceStyle(context, book),
              ) >
              coverWidth) ||
      (showPercent &&
          book.progress > 0 &&
          width(
                    '${(book.progress.clamp(0, 1) * 100).round()}%',
                    _cardPercentStyle(context),
                  ) +
                  16 >
              coverWidth - 2);
}

/// Readable metadata that outgrows a small cover moves into the card's flow.
/// Neither the app's font scale nor the space for title/author is reduced.
class _BookCardMetadataFooter extends StatelessWidget {
  const _BookCardMetadataFooter({
    required this.book,
    required this.showSource,
    required this.showPercent,
  });
  final AudioBook book;
  final bool showSource;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('book-card-metadata-footer'),
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          if (showSource)
            Text(
              _cardSourceName(context, book),
              key: const ValueKey('book-card-footer-source'),
              style: _cardSourceStyle(context, book),
            ),
          if (showPercent && book.progress > 0)
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '${(book.progress.clamp(0, 1) * 100).round()}%',
                  key: const ValueKey('book-card-footer-percent'),
                  maxLines: 1,
                  softWrap: false,
                  style: _cardPercentStyle(
                    context,
                  )?.copyWith(color: colors.onPrimaryContainer),
                ),
              ),
            ),
        ],
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
    final author = _shortPeopleLabel(context.strings, book.author);
    final narrator = _shortPeopleLabel(context.strings, book.narrator);
    final series = _seriesLabel(book.seriesTitle, book.seriesNumber);
    final rating = _ratingLabel(context.strings, book.ratingValue);
    final effectiveYear = _trimOrNull(yearLabel) ?? book.year?.toString();
    final duration = _trimOrNull(
      context.strings.formatDurationLabel(book.durationLabel),
    );

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
        if (book.isFragment) const BookFragmentBadge(),
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

class _DesktopBookCardBody extends StatelessWidget {
  const _DesktopBookCardBody({
    required this.strings,
    required this.book,
    required this.yearLabel,
  });

  final AppStrings strings;
  final AudioBook book;
  final String? yearLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final author = _shortPeopleLabel(context.strings, book.author);
    final narrator = _shortPeopleLabel(context.strings, book.narrator);
    final series = _seriesLabel(book.seriesTitle, book.seriesNumber);
    final rating = _ratingLabel(context.strings, book.ratingValue);
    final effectiveYear = _trimOrNull(yearLabel) ?? book.year?.toString();
    final duration = _trimOrNull(
      context.strings.formatDurationLabel(book.durationLabel),
    );
    final chapterCount = book.chapterCount > 0
        ? strings.chaptersCount(book.chapterCount)
        : null;
    final metadata = <Widget>[
      if (author != null)
        _DesktopMetaChip(iconAsset: AppIconAssets.bookAuthor, label: author),
      if (narrator != null)
        _DesktopMetaChip(
          iconAsset: AppIconAssets.bookNarrator,
          label: narrator,
        ),
      if (series != null)
        _DesktopMetaChip(iconAsset: AppIconAssets.bookSeries, label: series),
      if (duration != null)
        _DesktopMetaChip(
          iconAsset: AppIconAssets.bookDuration,
          label: duration,
        ),
      if (chapterCount != null)
        _DesktopMetaChip(
          iconAsset: AppIconAssets.playerChapters,
          label: chapterCount,
        ),
      if (effectiveYear != null)
        _DesktopMetaChip(
          iconAsset: AppIconAssets.bookYear,
          label: effectiveYear,
        ),
      if (rating != null)
        _DesktopMetaChip(iconAsset: AppIconAssets.bookRating, label: rating),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 8),
        if (book.isFragment) const BookFragmentBadge(),
        Wrap(spacing: 8, runSpacing: 8, children: metadata),
      ],
    );
  }
}

class _FavoriteActionButton extends StatelessWidget {
  const _FavoriteActionButton({
    required this.isFavorite,
    required this.onPressed,
    this.buttonKey,
    this.size = 38,
  });

  final bool isFavorite;
  final double size;
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
      size: size,
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
        Flexible(child: Text(label)),
      ],
    );
  }
}

// ignore: unused_element
class _DesktopInlineMeta extends StatelessWidget {
  const _DesktopInlineMeta({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          AppIcon(iconAsset, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _DesktopMetaChip extends StatelessWidget {
  const _DesktopMetaChip({
    required this.iconAsset,
    required this.label,
    this.textStyle,
  });

  final String iconAsset;
  final String label;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (DesktopLayout.isActive(context)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(iconAsset, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (textStyle ?? textTheme.labelMedium)?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(iconAsset, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
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

    return AppTooltip(
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

String? _shortPeopleLabel(AppStrings strings, String value) {
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
  return strings.peopleAndOthers(people.take(2).join(', '));
}

String? _ratingLabel(AppStrings strings, double? value) {
  if (value == null || value <= 0) {
    return null;
  }
  final rounded = double.parse(value.clamp(0, 5).toStringAsFixed(1));
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return strings.ratingOutOfFive(text);
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
