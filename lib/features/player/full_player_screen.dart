import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/chapter_tile.dart';
import '../../ui/icons/app_icons.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final book = activeMockBook;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.fullPlayer),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: strings.nowPlaying),
              Tab(text: strings.chapters),
              Tab(text: strings.bookmarks),
              Tab(text: strings.information),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NowPlayingPage(book: book),
            _ChaptersPage(book: book),
            _BookmarksPage(book: book),
            _InformationPage(book: book),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingPage extends StatelessWidget {
  const _NowPlayingPage({required this.book});

  final MockBook book;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Center(
          child: BookCover(
            title: book.title,
            progress: book.progress,
            width: 180,
            height: 250,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          book.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${book.author} · ${book.narrator}',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Text('${book.activeChapterTitle} · ${book.positionLabel}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: book.progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
        ),
        const SizedBox(height: 8),
        Text(book.remainingLabel, textAlign: TextAlign.end),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            const _ControlButton(
              tooltip: 'Previous',
              iconAsset: AppIconAssets.playerPreviousChapter,
            ),
            const _ControlButton(
              tooltip: 'Rewind 15',
              iconAsset: AppIconAssets.playerRewind15,
            ),
            FilledButton(
              onPressed: () {},
              child: const AppIcon(AppIconAssets.playerPlay, size: 28),
            ),
            const _ControlButton(
              tooltip: 'Forward 15',
              iconAsset: AppIconAssets.playerForward15,
            ),
            const _ControlButton(
              tooltip: 'Next',
              iconAsset: AppIconAssets.playerNextChapter,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const AppIcon(AppIconAssets.playerSpeed, size: 16),
              label: const Text('1.25x'),
              onPressed: () {},
            ),
            ActionChip(
              avatar: const AppIcon(AppIconAssets.playerSleepTimer, size: 16),
              label: Text(strings.sleepTimer),
              onPressed: () {},
            ),
            ActionChip(
              avatar: const AppIcon(AppIconAssets.playerBookmark, size: 16),
              label: Text(strings.bookmarks),
              onPressed: () {},
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final chapter in book.chapters)
          ChapterTile(
            index: chapter.index,
            title: chapter.title,
            durationLabel: chapter.durationLabel,
            progress: chapter.progress,
            isDownloaded: chapter.isDownloaded,
            isCurrent: chapter.isCurrent,
            onTap: () {},
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
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
        FilledButton.icon(
          onPressed: () => context.go('/book/${book.id}'),
          icon: const AppIcon(AppIconAssets.systemInfo),
          label: Text(strings.bookDetails),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.tooltip, required this.iconAsset});

  final String tooltip;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: () {},
      icon: AppIcon(iconAsset),
    );
  }
}
