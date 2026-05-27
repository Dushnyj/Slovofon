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
import '../../ui/components/book_card.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/chapter_tile.dart';
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

        return Scaffold(
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
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final book = state.book!;
    final currentChapter = state.currentChapter!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
      children: [
        Center(
          child: BookCover(
            title: book.title,
            progress: state.bookProgress,
            imageUrl: book.coverUrl,
            width: 176,
            height: 246,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          book.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 5),
        Text(
          '${book.author} · ${book.narrator}',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
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
            IconButton.outlined(
              tooltip: strings.downloadBook,
              onPressed: () => toggleBookDownload(downloadManager, book),
              icon: AppIcon(
                downloadStateForBook(downloadManager, book) ==
                        BookCardDownloadState.downloaded
                    ? AppIconAssets.deleteDownload
                    : AppIconAssets.download,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChaptersPage extends StatelessWidget {
  const _ChaptersPage({required this.state, required this.downloadManager});

  final AudioPlaybackState state;
  final DownloadManager downloadManager;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final book = state.book!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        Text(
          strings.chapters,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        for (final chapter in book.chapters)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ChapterTile(
              index: chapter.index,
              title: chapter.title,
              durationLabel: _formatShortDuration(context, chapter.duration),
              progress: _chapterProgress(state, chapter),
              isDownloaded: isChapterDownloaded(downloadManager, chapter),
              isCurrent: chapter.id == state.currentChapter?.id,
              onTap: () {},
              onDownloadPressed: () =>
                  toggleChapterDownload(downloadManager, book, chapter),
            ),
          ),
      ],
    );
  }
}

double _chapterProgress(
  AudioPlaybackState state,
  AudioPlaybackChapter chapter,
) {
  if (chapter.id == state.currentChapter?.id) {
    return state.chapterProgress;
  }

  return chapter.index < (state.currentChapter?.index ?? 0) ? 1 : 0;
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
                context.push('/source-book/${book.sourceId}/$sourceBookId'),
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

class _PlayerChrome extends StatelessWidget {
  const _PlayerChrome({
    required this.state,
    required this.service,
    required this.controller,
  });

  final AudioPlaybackState state;
  final PlaybackController service;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final currentChapter = state.currentChapter;

    return Material(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlayerDots(controller: controller),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: state.chapterProgress,
                onChanged: (value) {
                  final duration = state.chapterDuration;
                  service.seek(
                    Duration(
                      milliseconds: (duration.inMilliseconds * value).round(),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Text(
                  _formatPlaybackDuration(state.position),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Spacer(),
                _SleepTimerPill(
                  label: _formatPlaybackDuration(
                    state.sleepTimerRemaining ?? Duration.zero,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatShortDuration(
                    context,
                    currentChapter?.duration ?? Duration.zero,
                  ),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ControlIcon(
                  tooltip: '${state.speed.toStringAsFixed(2)}x',
                  iconAsset: AppIconAssets.playerSpeed,
                  onPressed: () =>
                      service.setSpeed(state.speed == 1.25 ? 1 : 1.25),
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
                  onPressed: () =>
                      service.setSleepTimer(const Duration(minutes: 90)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
  const _SleepTimerPill({required this.label});

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
