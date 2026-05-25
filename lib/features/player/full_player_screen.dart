import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/chapter_tile.dart';
import '../../ui/icons/app_icons.dart';

class FullPlayerScreen extends StatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen>
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
    final book = activeMockBook;

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
              child: TabBarView(
                controller: _tabs,
                children: [
                  _NowPlayingPage(book: book),
                  _ChaptersPage(book: book),
                  _BookmarksPage(book: book),
                  _InformationPage(book: book),
                ],
              ),
            ),
            _PlayerChrome(book: book, controller: _tabs),
          ],
        ),
      ),
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
  const _NowPlayingPage({required this.book});

  final MockBook book;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final currentChapter = book.chapters.firstWhere(
      (chapter) => chapter.isCurrent,
      orElse: () => book.chapters.first,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
      children: [
        Center(
          child: BookCover(
            title: book.title,
            progress: book.progress,
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
                '${currentChapter.index}/${book.chapterCount} · ${book.activeChapterTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: strings.downloadBook,
              onPressed: () {},
              icon: const AppIcon(AppIconAssets.download),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChaptersPage extends StatelessWidget {
  const _ChaptersPage({required this.book});

  final MockBook book;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

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
              durationLabel: chapter.durationLabel,
              progress: chapter.progress,
              isDownloaded: chapter.isDownloaded,
              isCurrent: chapter.isCurrent,
              onTap: () {},
              onDownloadPressed: () {},
            ),
          ),
      ],
    );
  }
}

class _BookmarksPage extends StatelessWidget {
  const _BookmarksPage({required this.book});

  final MockBook book;

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
        for (final bookmark in book.bookmarks)
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
  const _InformationPage({required this.book});

  final MockBook book;

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
          subtitle: Text('${book.genre} · ${book.durationLabel}'),
        ),
        ListTile(
          leading: const AppIcon(AppIconAssets.bookAuthor),
          title: Text(book.author),
          subtitle: Text(book.narrator),
        ),
        ListTile(
          leading: const AppIcon(AppIconAssets.bookYear),
          title: Text('${book.year} / audio ${book.audioYear}'),
          subtitle: Text(book.ratingLabel),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton.filled(
            tooltip: strings.bookDetails,
            onPressed: () => context.go('/book/${book.id}'),
            icon: const AppIcon(AppIconAssets.systemInfo),
          ),
        ),
      ],
    );
  }
}

class _PlayerChrome extends StatelessWidget {
  const _PlayerChrome({required this.book, required this.controller});

  final MockBook book;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final currentChapter = book.chapters.firstWhere(
      (chapter) => chapter.isCurrent,
      orElse: () => book.chapters.first,
    );

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
                value: book.progress.clamp(0, 1).toDouble(),
                onChanged: (_) {},
              ),
            ),
            Row(
              children: [
                Text(
                  book.positionLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Spacer(),
                const _SleepTimerPill(label: '1:30:00'),
                const Spacer(),
                Text(
                  currentChapter.durationLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _ControlIcon(
                  tooltip: '1.25x',
                  iconAsset: AppIconAssets.playerSpeed,
                ),
                _ControlIcon(
                  tooltip: strings.previousChapter,
                  iconAsset: AppIconAssets.playerPreviousChapter,
                ),
                _ControlIcon(
                  tooltip: strings.rewind15,
                  iconAsset: AppIconAssets.playerRewind15,
                ),
                IconButton.filled(
                  tooltip: strings.play,
                  iconSize: 34,
                  onPressed: () {},
                  icon: const AppIcon(AppIconAssets.playerPlay, size: 34),
                ),
                _ControlIcon(
                  tooltip: strings.forward15,
                  iconAsset: AppIconAssets.playerForward15,
                ),
                _ControlIcon(
                  tooltip: strings.nextChapter,
                  iconAsset: AppIconAssets.playerNextChapter,
                ),
                _ControlIcon(
                  tooltip: strings.sleepTimer,
                  iconAsset: AppIconAssets.playerSleepTimer,
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
  const _ControlIcon({required this.tooltip, required this.iconAsset});

  final String tooltip;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () {},
      icon: AppIcon(iconAsset),
    );
  }
}
