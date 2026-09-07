import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../adaptive/desktop_layout.dart';
import '../adaptive/television_layout.dart';
import '../icons/app_icons.dart';
import 'book_card.dart';
import 'book_cover.dart';
import 'book_fragment_badge.dart';
import 'playback_source_label.dart';

/// Compact audiobook identity, not a movie poster. All available metadata stays
/// in the reading flow, with one remote stop opening the full book details.
class TelevisionBookCard extends StatefulWidget {
  const TelevisionBookCard({required this.card, super.key});
  final BookCard card;

  @override
  State<TelevisionBookCard> createState() => _TelevisionBookCardState();
}

class _TelevisionBookCardState extends State<TelevisionBookCard> {
  final _detailsFocus = FocusNode(debugLabel: 'TV book details');

  @override
  void dispose() {
    _detailsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final book = card.book;
    final theme = Theme.of(context);
    final strings = context.strings;
    final preferences = DesktopPreferences.maybeOf(context);
    final showSource = preferences?.showSourceOnCards ?? true;
    final showPercent = preferences?.showPercentOnCovers ?? true;
    final progress = book.progress.clamp(0, 1).toDouble();
    final activate =
        card.onTap ??
        (card.isPlayLoading || card.isPlaybackLoading ? null : card.onPlay);
    final metadataStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.2,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final author = _metadataValue(book.author);
    final narrator = _metadataValue(book.narrator);
    final seriesTitle = _metadataValue(book.seriesTitle);
    final seriesNumber = book.seriesNumber;
    final series = seriesTitle == null
        ? null
        : seriesNumber != null && seriesNumber.isFinite && seriesNumber > 0
        ? '$seriesTitle #${_numberLabel(seriesNumber)}'
        : seriesTitle;
    final duration = _metadataValue(book.durationLabel);
    final year =
        _metadataValue(card.yearLabel) ??
        (book.year != null && book.year! > 0 ? '${book.year}' : null);
    final ratingValue = book.ratingValue;
    final rating =
        ratingValue != null && ratingValue.isFinite && ratingValue > 0
        ? '${_numberLabel(double.parse(ratingValue.clamp(0, 5).toStringAsFixed(1)))} / 5'
        : null;

    Widget metadata(String icon, String value, String role) =>
        _TelevisionMetadata(
          icon: icon,
          value: value,
          role: role,
          style: metadataStyle,
        );
    final secondary = <Widget>[
      if (duration != null)
        metadata(AppIconAssets.bookDuration, duration, strings.sortByDuration),
      if (book.chapterCount > 0)
        metadata(
          AppIconAssets.playerChapters,
          strings.chaptersCount(book.chapterCount),
          strings.chapters,
        ),
      if (year != null)
        metadata(AppIconAssets.bookYear, year, strings.sortByYear),
      if (rating != null)
        metadata(AppIconAssets.bookRating, rating, strings.sortByRating),
    ];

    return TelevisionFocusFrame(
      key: ValueKey('tv-book-${book.sourceId}-${book.id}'),
      radius: 10,
      showRestingOutline: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          focusNode: _detailsFocus,
          onTap: activate,
          // Focus is an outline, not a tint over colored source metadata.
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BookCover(
                            title: book.title,
                            imageUrl: book.coverUrl,
                            width: 48,
                            height: 72,
                            showProgressPercent: false,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  book.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                                if (book.isFragment) const BookFragmentBadge(),
                                if (author != null) ...[
                                  const SizedBox(height: 2),
                                  metadata(
                                    AppIconAssets.bookAuthor,
                                    author,
                                    strings.searchByAuthor,
                                  ),
                                ],
                                if (narrator != null) ...[
                                  const SizedBox(height: 2),
                                  metadata(
                                    AppIconAssets.bookNarrator,
                                    narrator,
                                    strings.searchByNarrator,
                                  ),
                                ],
                                if (series != null) ...[
                                  const SizedBox(height: 2),
                                  metadata(
                                    AppIconAssets.bookSeries,
                                    series,
                                    strings.series,
                                  ),
                                ],
                                if (secondary.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 2,
                                    children: secondary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (showSource || (showPercent && progress > 0)) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showSource)
                              Expanded(
                                child: PlaybackSourceLabel(
                                  sourceId: book.sourceId,
                                  sourceName: book.sourceName,
                                  maxLines: null,
                                  textStyle: metadataStyle,
                                ),
                              )
                            else
                              const Spacer(),
                            if (showPercent && progress > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${(progress * 100).round()}%',
                                style: metadataStyle,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (progress > 0)
                  LinearProgressIndicator(value: progress, minHeight: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TelevisionMetadata extends StatelessWidget {
  const _TelevisionMetadata({
    required this.icon,
    required this.value,
    required this.role,
    required this.style,
  });

  final String icon, value, role;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$role: $value',
    excludeSemantics: true,
    child: Tooltip(
      message: value,
      excludeFromSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AppIcon(icon, size: 12, color: style?.color),
          ),
          const SizedBox(width: 4),
          Flexible(child: Text(value, style: style)),
        ],
      ),
    ),
  );
}

String? _metadataValue(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty || text == '-' || text == '—'
      ? null
      : text;
}

String _numberLabel(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
