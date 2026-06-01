import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../sources/source_models.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/chapter_tile.dart';
import '../../ui/components/source_badge.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';

class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Offset? _pointerDownPosition;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(playbackControllerProvider);
    final downloadManager = ref.watch(downloadManagerProvider);

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final state = service.state;
        final book = state.book;
        final mockBook = _mockBookForPlayback(book);

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _pointerDownPosition = event.position;
          },
          onPointerUp: (event) {
            final start = _pointerDownPosition;
            _pointerDownPosition = null;
            if (start == null || _tabs.index != 0) {
              return;
            }
            final delta = event.position - start;
            if (delta.dx > 120 && delta.dy.abs() < 90) {
              _close(context);
            }
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: context.strings.home,
                          onPressed: () => _close(context),
                          icon: const AppIcon(AppIconAssets.systemBack),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: context.strings.cancel,
                          onPressed: () => _close(context),
                          icon: const AppIcon(AppIconAssets.systemClose),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: book == null
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            controller: _tabs,
                            children: [
                              _NowPlayingPage(
                                state: state,
                                downloadManager: downloadManager,
                              ),
                              _ChaptersPage(
                                state: state,
                                service: service,
                                downloadManager: downloadManager,
                              ),
                              _BookmarksPage(book: mockBook),
                              _InformationPage(book: book, mockBook: mockBook),
                            ],
                          ),
                  ),
                  _PlayerChrome(
                    state: state,
                    service: service,
                    controller: _tabs,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

class _NowPlayingPage extends StatelessWidget {
  const _NowPlayingPage({required this.state, required this.downloadManager});

  final AudioPlaybackState state;
  final DownloadManager downloadManager;

  @override
  Widget build(BuildContext context) {
    final book = state.book!;
    final currentChapter = state.currentChapter!;
    final seriesLabel = _seriesLabel(book.seriesTitle, book.seriesNumber);
    final yearLabel = book.publishedYear?.toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final isCompact = constraints.maxHeight < 560;
        final coverRatio = textScale > 1.15
            ? (isCompact ? 0.34 : 0.42)
            : (isCompact ? 0.46 : 0.58);
        final scalePenalty = ((textScale - 1) * 120).clamp(0.0, 54.0);
        final coverHeight = (constraints.maxHeight * coverRatio - scalePenalty)
            .clamp(
              textScale > 1.15 ? 172.0 : (isCompact ? 218.0 : 282.0),
              textScale > 1.15 ? 258.0 : (isCompact ? 286.0 : 368.0),
            );
        final coverWidth = coverHeight * 0.715;
        final horizontalPadding = constraints.maxWidth < 380 ? 18.0 : 22.0;
        final gap = textScale > 1.15 ? 5.0 : 10.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            18,
          ),
          children: [
            Center(
              child: BookCover(
                title: book.title,
                progress: state.bookProgress,
                imageUrl: book.coverUrl,
                width: coverWidth,
                height: coverHeight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              book.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: gap),
            _LinkedPeopleMetaLine(
              iconAsset: AppIconAssets.bookAuthor,
              people: _splitPeople(book.author),
              searchKind: SearchKind.author,
            ),
            const SizedBox(height: 3),
            _LinkedPeopleMetaLine(
              iconAsset: AppIconAssets.bookNarrator,
              people: _splitPeople(book.narrator),
              searchKind: SearchKind.narrator,
            ),
            if (seriesLabel != null) ...[
              const SizedBox(height: 3),
              _LinkedMetaLine(
                iconAsset: AppIconAssets.bookSeries,
                label: seriesLabel,
                query: book.seriesTitle!,
                searchKind: SearchKind.series,
              ),
            ],
            if (yearLabel != null) ...[
              const SizedBox(height: 3),
              _PlainMetaLine(
                iconAsset: AppIconAssets.bookYear,
                label: yearLabel,
              ),
            ],
            SizedBox(height: gap),
            SourceBadge(sourceId: book.sourceId, textAlign: TextAlign.center),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '${currentChapter.index}/${book.chapters.length} · ${currentChapter.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 8),
                DownloadActionButton(
                  state: downloadStateForBook(downloadManager, book),
                  progress: downloadProgressForBook(downloadManager, book),
                  size: 40,
                  onPressed: () {
                    unawaited(runBookCardDownloadAction(downloadManager, book));
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LinkedPeopleMetaLine extends StatelessWidget {
  const _LinkedPeopleMetaLine({
    required this.iconAsset,
    required this.people,
    required this.searchKind,
  });

  final String iconAsset;
  final List<String> people;
  final SearchKind searchKind;

  @override
  Widget build(BuildContext context) {
    final visiblePeople = people.take(2).toList();
    if (visiblePeople.isEmpty) {
      return const SizedBox.shrink();
    }
    final hasMore = people.length > visiblePeople.length;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(iconAsset, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var index = 0; index < visiblePeople.length; index++) ...[
                _MetaTextLink(
                  label: visiblePeople[index],
                  query: visiblePeople[index],
                  searchKind: searchKind,
                ),
                if (index < visiblePeople.length - 1) const _MetaText(', '),
              ],
              if (hasMore) const _MetaText(' и др.'),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkedMetaLine extends StatelessWidget {
  const _LinkedMetaLine({
    required this.iconAsset,
    required this.label,
    required this.query,
    required this.searchKind,
  });

  final String iconAsset;
  final String label;
  final String query;
  final SearchKind searchKind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(iconAsset, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: _MetaTextLink(
            label: label,
            query: query,
            searchKind: searchKind,
          ),
        ),
      ],
    );
  }
}

class _PlainMetaLine extends StatelessWidget {
  const _PlainMetaLine({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(iconAsset, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(child: _MetaText(label)),
      ],
    );
  }
}

class _MetaTextLink extends StatelessWidget {
  const _MetaTextLink({
    required this.label,
    required this.query,
    required this.searchKind,
  });

  final String label;
  final String query;
  final SearchKind searchKind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: colorScheme.primary,
      ),
      onPressed: () => _openScopedSearch(context, query, searchKind),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }
}

class _ChaptersPage extends StatefulWidget {
  const _ChaptersPage({
    required this.state,
    required this.service,
    required this.downloadManager,
  });

  final AudioPlaybackState state;
  final PlaybackController service;
  final DownloadManager downloadManager;

  @override
  State<_ChaptersPage> createState() => _ChaptersPageState();
}

class _ChaptersPageState extends State<_ChaptersPage> {
  static const _chapterExtent = 96.0;

  late final ScrollController _controller;
  String? _lastBookVersionId;
  int? _lastChapterIndex;
  bool _showCurrentChapterButton = false;

  @override
  void initState() {
    super.initState();
    _lastBookVersionId = widget.state.book?.versionId;
    _lastChapterIndex = widget.state.chapterIndex;
    _controller = ScrollController(
      initialScrollOffset: _initialScrollOffset(widget.state.chapterIndex),
    )..addListener(_handleScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCurrentChapterButton();
    });
  }

  @override
  void didUpdateWidget(covariant _ChaptersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextBookVersionId = widget.state.book?.versionId;
    final nextChapterIndex = widget.state.chapterIndex;
    if (nextBookVersionId == _lastBookVersionId &&
        nextChapterIndex == _lastChapterIndex) {
      return;
    }
    _lastBookVersionId = nextBookVersionId;
    _lastChapterIndex = nextChapterIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) {
        return;
      }
      _controller.animateTo(
        _initialScrollOffset(nextChapterIndex),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      _syncCurrentChapterButton();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScrollChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final book = widget.state.book!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.chapters,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _controller,
                  itemExtent: _chapterExtent,
                  itemCount: book.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = book.chapters[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ChapterTile(
                        key: ValueKey('full-player-chapter-${chapter.id}'),
                        index: chapter.index,
                        title: chapter.title,
                        durationLabel: _formatShortDuration(
                          context,
                          chapter.duration,
                        ),
                        progress: widget.service.chapterProgressAt(index),
                        isDownloaded: isChapterDownloaded(
                          widget.downloadManager,
                          chapter,
                          book: book,
                        ),
                        downloadState: downloadStateForChapter(
                          widget.downloadManager,
                          chapter,
                          book: book,
                        ),
                        downloadProgress: downloadProgressForChapter(
                          widget.downloadManager,
                          chapter,
                          book: book,
                        ),
                        isCurrent:
                            chapter.id == widget.state.currentChapter?.id,
                        onTap: () => widget.service.playChapterAt(index),
                        onDownloadPressed: () => runChapterCardDownloadAction(
                          widget.downloadManager,
                          book,
                          chapter,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _showCurrentChapterButton
                        ? Center(
                            child: _CurrentChapterButton(
                              onPressed: _scrollToCurrentChapter,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _initialScrollOffset(int chapterIndex) {
    if (chapterIndex <= 0) {
      return 0;
    }
    return chapterIndex * _chapterExtent;
  }

  void _handleScrollChanged() {
    _syncCurrentChapterButton();
  }

  void _syncCurrentChapterButton() {
    if (!mounted) {
      return;
    }
    final shouldShow = _shouldShowCurrentChapterButton();
    if (shouldShow == _showCurrentChapterButton) {
      return;
    }
    setState(() => _showCurrentChapterButton = shouldShow);
  }

  bool _shouldShowCurrentChapterButton() {
    if (!_controller.hasClients) {
      return false;
    }
    final position = _controller.position;
    if (!position.hasViewportDimension) {
      return false;
    }
    final index = widget.state.chapterIndex;
    final itemTop = index * _chapterExtent;
    final itemBottom = itemTop + _chapterExtent;
    final viewportTop = _controller.offset;
    final viewportBottom = viewportTop + position.viewportDimension;
    return itemBottom < viewportTop + 6 || itemTop > viewportBottom - 6;
  }

  void _scrollToCurrentChapter() {
    if (!_controller.hasClients) {
      return;
    }
    _controller.animateTo(
      _initialScrollOffset(widget.state.chapterIndex),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }
}

class _CurrentChapterButton extends StatelessWidget {
  const _CurrentChapterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.88),
      elevation: 4,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: const ValueKey('full-player-current-chapter-button'),
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIconAssets.playerNextChapter,
                size: 17,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                context.strings.goToCurrentChapter,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarksPage extends StatelessWidget {
  const _BookmarksPage({required this.book});

  final MockBook? book;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        Text(
          strings.bookmarks,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (book == null || book!.bookmarks.isEmpty)
          Text(
            strings.emptyLibrary,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          for (final bookmark in book!.bookmarks)
            Card(
              child: ListTile(
                leading: const AppIcon(AppIconAssets.playerBookmark),
                title: Text(
                  '${bookmark.chapterTitle} · ${bookmark.positionLabel}',
                ),
                subtitle: Text(bookmark.note),
                trailing: const AppIcon(AppIconAssets.systemForward),
              ),
            ),
      ],
    );
  }
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({required this.book, required this.mockBook});

  final AudioPlaybackBook book;
  final MockBook? mockBook;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        Text(
          strings.information,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const AppIcon(AppIconAssets.bookSource),
          title: Text(book.sourceName),
          subtitle: Text(
            [
                  book.genre ?? mockBook?.genre,
                  _formatShortDuration(context, book.totalDuration),
                ]
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .join(' · '),
          ),
        ),
        ListTile(
          leading: const AppIcon(AppIconAssets.bookAuthor),
          title: Text(book.author),
          subtitle: Text(book.narrator),
        ),
        ListTile(
          leading: const AppIcon(AppIconAssets.bookYear),
          title: Text(
            [
              book.publishedYear?.toString() ?? mockBook?.year.toString(),
              if (mockBook != null) 'audio ${mockBook!.audioYear}',
            ].whereType<String>().join(' / '),
          ),
          subtitle: Text(mockBook?.ratingLabel ?? book.sourceUrl ?? ''),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton.filled(
            tooltip: strings.bookDetails,
            onPressed: () {
              final sourceBookId = book.sourceBookId;
              if (sourceBookId == null) {
                unawaited(context.push('/book/${book.id}'));
                return;
              }
              unawaited(
                context.push(
                  '/source-book/${book.sourceId}/${Uri.encodeComponent(sourceBookId)}',
                ),
              );
            },
            icon: const AppIcon(AppIconAssets.systemInfo),
          ),
        ),
      ],
    );
  }
}

MockBook? _mockBookForPlayback(AudioPlaybackBook? book) {
  if (book == null) {
    return null;
  }

  for (final mockBook in stage3MockBooks) {
    if (mockBook.id == book.id) {
      return mockBook;
    }
  }
  return null;
}

class _PlayerChrome extends StatefulWidget {
  const _PlayerChrome({
    required this.state,
    required this.service,
    required this.controller,
  });

  final AudioPlaybackState state;
  final PlaybackController service;
  final TabController controller;

  @override
  State<_PlayerChrome> createState() => _PlayerChromeState();
}

class _PlayerChromeState extends State<_PlayerChrome> {
  double? _dragProgress;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final service = widget.service;
    final currentChapter = state.currentChapter;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final timeRowHeight = (28 * textScale).clamp(28.0, 38.0);
    final sliderValue = (_dragProgress ?? state.chapterProgress)
        .clamp(0, 1)
        .toDouble();

    return Material(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlayerDots(controller: widget.controller),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: sliderValue,
                onChanged: (value) => setState(() => _dragProgress = value),
                onChangeEnd: (value) {
                  final duration = state.chapterDuration;
                  service.seek(
                    Duration(
                      milliseconds: (duration.inMilliseconds * value).round(),
                    ),
                  );
                  setState(() => _dragProgress = null);
                },
              ),
            ),
            SizedBox(
              height: timeRowHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatPlaybackDuration(state.position),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if ((state.sleepTimerRemaining ?? Duration.zero) >
                      Duration.zero)
                    _SleepTimerPill(
                      key: const ValueKey('sleep-timer-pill'),
                      label: _formatPlaybackDuration(
                        state.sleepTimerRemaining!,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatPlaybackDuration(
                        currentChapter?.duration ?? Duration.zero,
                      ),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ControlIcon(
                  tooltip: '${state.speed.toStringAsFixed(2)}x',
                  iconAsset: AppIconAssets.playerSpeed,
                  onPressed: () => _showSpeedSheet(context),
                ),
                _ControlIcon(
                  tooltip: strings.previousChapter,
                  iconAsset: AppIconAssets.playerPreviousChapter,
                  onPressed: service.previousChapter,
                ),
                _ControlIcon(
                  tooltip: strings.rewind15,
                  iconAsset: AppIconAssets.playerRewind15,
                  onPressed: () => service.skipBy(const Duration(seconds: -15)),
                ),
                IconButton.filled(
                  tooltip: state.isPlaying ? strings.pause : strings.play,
                  iconSize: 34,
                  onPressed: service.togglePlayPause,
                  icon: AppIcon(
                    state.isPlaying
                        ? AppIconAssets.playerPause
                        : AppIconAssets.playerPlay,
                    size: 34,
                  ),
                ),
                _ControlIcon(
                  tooltip: strings.forward15,
                  iconAsset: AppIconAssets.playerForward15,
                  onPressed: () => service.skipBy(const Duration(seconds: 15)),
                ),
                _ControlIcon(
                  tooltip: strings.nextChapter,
                  iconAsset: AppIconAssets.playerNextChapter,
                  onPressed: service.nextChapter,
                ),
                _ControlIcon(
                  tooltip: strings.sleepTimer,
                  iconAsset: AppIconAssets.playerSleepTimer,
                  onPressed: () => _showSleepTimerSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSpeedSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final speed in const [0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                ListTile(
                  leading: widget.state.speed == speed
                      ? const AppIcon(AppIconAssets.systemCheck)
                      : const SizedBox.square(dimension: 24),
                  title: Text('${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x'),
                  onTap: () => Navigator.of(context).pop(speed),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await widget.service.setSpeed(selected);
    }
  }

  Future<void> _showSleepTimerSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<_SleepTimerChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        const options = [
          _SleepTimerChoice.off(),
          _SleepTimerChoice.duration(Duration(minutes: 15)),
          _SleepTimerChoice.duration(Duration(minutes: 30)),
          _SleepTimerChoice.duration(Duration(minutes: 60)),
          _SleepTimerChoice.duration(Duration(minutes: 90)),
          _SleepTimerChoice.endOfChapter(),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                ListTile(
                  leading: option.kind == _SleepTimerChoiceKind.off
                      ? const AppIcon(AppIconAssets.systemClose)
                      : const AppIcon(AppIconAssets.playerSleepTimer),
                  title: Text(_sleepTimerOptionLabel(context, option)),
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) {
      return;
    }
    switch (selected.kind) {
      case _SleepTimerChoiceKind.off:
        widget.service.clearSleepTimer();
      case _SleepTimerChoiceKind.duration:
        widget.service.setSleepTimer(selected.duration!);
      case _SleepTimerChoiceKind.endOfChapter:
        widget.service.setSleepTimerToChapterEnd();
    }
  }
}

enum _SleepTimerChoiceKind { off, duration, endOfChapter }

class _SleepTimerChoice {
  const _SleepTimerChoice._(this.kind, this.duration);
  const _SleepTimerChoice.off() : this._(_SleepTimerChoiceKind.off, null);
  const _SleepTimerChoice.duration(Duration duration)
    : this._(_SleepTimerChoiceKind.duration, duration);
  const _SleepTimerChoice.endOfChapter()
    : this._(_SleepTimerChoiceKind.endOfChapter, null);

  final _SleepTimerChoiceKind kind;
  final Duration? duration;
}

class _PlayerDots extends StatefulWidget {
  const _PlayerDots({required this.controller});

  final TabController controller;

  @override
  State<_PlayerDots> createState() => _PlayerDotsState();
}

class _PlayerDotsState extends State<_PlayerDots> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(_PlayerDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChanged);
      widget.controller.addListener(_handleChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < widget.controller.length; index++)
          GestureDetector(
            onTap: () => widget.controller.animateTo(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: widget.controller.index == index ? 18 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: widget.controller.index == index
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );
  }

  void _handleChanged() => setState(() {});
}

class _SleepTimerPill extends StatelessWidget {
  const _SleepTimerPill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            AppIconAssets.playerSleepTimer,
            size: 16,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  const _ControlIcon({
    required this.tooltip,
    required this.iconAsset,
    this.onPressed,
  });

  final String tooltip;
  final String iconAsset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: AppIcon(iconAsset),
    );
  }
}

String _formatPlaybackDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }

  return '$minutes:$seconds';
}

void _openScopedSearch(BuildContext context, String query, SearchKind kind) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return;
  }
  context.push(
    Uri(
      path: '/scoped-search',
      queryParameters: {'q': trimmed, 'kind': kind.name, 'run': '1'},
    ).toString(),
  );
}

List<String> _splitPeople(String value) {
  return value
      .split(RegExp(r'\s*[,;]\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && part != '-' && part != '—')
      .toList();
}

String? _seriesLabel(String? title, double? number) {
  final cleanedTitle = title?.trim();
  if (cleanedTitle == null || cleanedTitle.isEmpty || cleanedTitle == '-') {
    return null;
  }
  final numberLabel = _seriesNumberLabel(number);
  return numberLabel == null ? cleanedTitle : '$cleanedTitle ($numberLabel)';
}

String? _seriesNumberLabel(double? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

String _sleepTimerOptionLabel(BuildContext context, _SleepTimerChoice choice) {
  final locale = Localizations.localeOf(context).languageCode;
  switch (choice.kind) {
    case _SleepTimerChoiceKind.off:
      return locale == 'ru' ? 'Отключить таймер' : 'Disable timer';
    case _SleepTimerChoiceKind.endOfChapter:
      return locale == 'ru' ? 'До конца главы' : 'Until chapter ends';
    case _SleepTimerChoiceKind.duration:
      final minutes = choice.duration!.inMinutes;
      return locale == 'ru' ? '$minutes мин' : '$minutes min';
  }
}

String _formatShortDuration(BuildContext context, Duration duration) {
  final locale = Localizations.localeOf(context).languageCode;
  final minutes = duration.inMinutes;
  final suffix = locale == 'ru' ? 'мин' : 'min';

  if (duration.inHours > 0) {
    final hoursSuffix = locale == 'ru' ? 'ч' : 'h';
    return '${duration.inHours} $hoursSuffix ${minutes.remainder(60)} $suffix';
  }

  return '$minutes $suffix';
}
