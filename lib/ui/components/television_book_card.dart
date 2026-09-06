import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/localization/app_strings.dart';
import '../adaptive/desktop_layout.dart';
import '../adaptive/television_layout.dart';
import '../icons/app_icons.dart';
import 'book_card.dart';
import 'book_cover.dart';
import 'book_fragment_badge.dart';
import 'playback_source_label.dart';

/// Shares callbacks and models with phone/desktop cards, but uses a readable
/// TV shelf tile and explicit remote actions instead of hover or long-press.
class TelevisionBookCard extends StatefulWidget {
  const TelevisionBookCard({required this.card, super.key});
  final BookCard card;
  @override
  State<TelevisionBookCard> createState() => _TelevisionBookCardState();
}

class _TelevisionBookCardState extends State<TelevisionBookCard> {
  final _detailsFocus = FocusNode(debugLabel: 'TV book details');
  final _actionsFocus = FocusNode(
    debugLabel: 'TV book actions',
    canRequestFocus: false,
    skipTraversal: true,
  );
  @override
  void dispose() {
    _detailsFocus.dispose();
    _actionsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final book = card.book;
    final strings = context.strings;
    final theme = Theme.of(context);
    final preferences = DesktopPreferences.maybeOf(context);
    final showSource = preferences?.showSourceOnCards ?? true;
    final showPercent = preferences?.showPercentOnCovers ?? true;
    return TelevisionFocusFrame(
      key: ValueKey('tv-book-${book.sourceId}-${book.id}'),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  final first = _actionsFocus.traversalDescendants.firstOrNull;
                  if (first != null) {
                    first.requestFocus();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: InkWell(
                focusNode: _detailsFocus,
                onTap: card.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookCover(
                        title: book.title,
                        imageUrl: book.coverUrl,
                        width: 64,
                        height: 96,
                        showProgressPercent: false,
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (book.isFragment) const BookFragmentBadge(),
                            Text(
                              book.author,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            if (book.narrator.isNotEmpty)
                              Text(
                                book.narrator,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              children: [
                                if (showSource)
                                  PlaybackSourceLabel(
                                    sourceId: book.sourceId,
                                    sourceName: book.sourceName,
                                    textStyle: theme.textTheme.labelMedium,
                                  ),
                                if (book.durationLabel.isNotEmpty)
                                  Text(
                                    book.durationLabel,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                if (showPercent && book.progress > 0)
                                  Text(
                                    '${(book.progress.clamp(0, 1) * 100).round()}%',
                                    style: theme.textTheme.labelMedium,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Focus(
              focusNode: _actionsFocus,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowUp &&
                    card.onTap != null) {
                  _detailsFocus.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (card.onPlay != null)
                      FilledButton.icon(
                        onPressed: card.isPlayLoading || card.isPlaybackLoading
                            ? null
                            : card.onPlay,
                        icon: AppIcon(
                          card.isCurrentBook && card.isPlaying
                              ? AppIconAssets.playerPause
                              : AppIconAssets.playerPlay,
                        ),
                        label: Text(
                          card.isCurrentBook && card.isPlaying
                              ? strings.pause
                              : strings.play,
                        ),
                      ),
                    if (card.onFavoritePressed != null)
                      IconButton(
                        tooltip: card.isFavorite
                            ? strings.removeFavorite
                            : strings.addFavorite,
                        onPressed: card.onFavoritePressed,
                        icon: AppIcon(
                          card.isFavorite
                              ? AppIconAssets.bookFavoriteFilled
                              : AppIconAssets.bookFavorite,
                        ),
                      ),
                    if (card.onLaterPressed != null)
                      IconButton(
                        tooltip: card.isLater
                            ? strings.removeFromLater
                            : strings.addToLater,
                        onPressed: card.onLaterPressed,
                        icon: const AppIcon(AppIconAssets.playerSleepTimer),
                      ),
                    if (card.onDownloadPressed != null)
                      DownloadActionButton(
                        state: card.downloadState,
                        onPressed: card.onDownloadPressed,
                        progress: card.downloadProgress,
                        isResolving: card.isDownloadLoading,
                        size: 40,
                      ),
                  ],
                ),
              ),
            ),
            if (book.progress > 0)
              LinearProgressIndicator(
                value: book.progress.clamp(0, 1),
                minHeight: 3,
              ),
          ],
        ),
      ),
    );
  }
}
