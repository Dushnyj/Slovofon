import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/mock_audio_playback.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../ui/components/app_bar_text.dart';
import '../../ui/adaptive/desktop_layout.dart';
import '../../ui/adaptive/desktop_book_details_layout.dart';
import '../../ui/adaptive/slovofon_shell.dart';
import '../../ui/adaptive/television_layout.dart';
import '../../ui/adaptive/television_shell.dart';
import '../../ui/components/app_buttons.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/chapter_tile.dart';
import '../../ui/components/download_action_button.dart';
import '../../ui/components/download_status_chip.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';

class BookDetailsScreen extends ConsumerWidget {
  const BookDetailsScreen({required this.book, super.key});

  final MockBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final desktop = DesktopLayout.isActive(context);
    final television = TelevisionLayout.isActive(context);
    final colorScheme = Theme.of(context).colorScheme;
    final downloadManager = ref.watch(downloadManagerProvider);
    final playbackBook = mockAudioPlaybackBook(book);
    final bookDownloadState = downloadStateForBook(
      downloadManager,
      playbackBook,
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (desktop || television)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('legacy-details-play'),
              onPressed: () => unawaited(context.push('/player')),
              icon: const AppIcon(AppIconAssets.playerPlay),
              label: Text(
                book.progress > 0 ? strings.continuePlayback : strings.play,
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          AppIconActionButton(
            tooltip: book.progress > 0
                ? strings.continuePlayback
                : strings.play,
            onPressed: () => unawaited(context.push('/player')),
            iconAsset: AppIconAssets.playerPlay,
            foregroundColor: colorScheme.primary,
          ),
        DownloadActionButton(
          state: bookDownloadState,
          progress: downloadProgressForBook(downloadManager, playbackBook),
          onPressed: () =>
              runBookCardDownloadAction(downloadManager, playbackBook),
        ),
        AppIconActionButton(
          tooltip: strings.bookmarks,
          onPressed: () {},
          iconAsset: AppIconAssets.playerBookmark,
        ),
        AppIconActionButton(
          tooltip: strings.share,
          onPressed: () {},
          iconAsset: AppIconAssets.systemShare,
        ),
      ],
    );
    final bodyChildren = <Widget>[
      if (desktop)
        SectionHeader(title: strings.description)
      else
        const SizedBox(height: 16),
      Text(
        book.description,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 20),
      SectionHeader(title: strings.chapters),
      for (final (index, chapter) in book.chapters.indexed)
        Builder(
          builder: (context) {
            final audioChapter = playbackBook.chapters.firstWhere(
              (audioChapter) => audioChapter.index == chapter.index,
            );
            return ChapterTile(
              index: index + 1,
              title: chapter.title,
              durationLabel: chapter.durationLabel,
              progress: chapter.progress,
              isDownloaded: isChapterDownloaded(downloadManager, audioChapter),
              downloadState: downloadStateForChapter(
                downloadManager,
                audioChapter,
              ),
              downloadProgress: downloadProgressForChapter(
                downloadManager,
                audioChapter,
              ),
              isCurrent: chapter.isCurrent,
              onTap: () => unawaited(context.push('/player')),
              onDownloadPressed: () => runChapterCardDownloadAction(
                downloadManager,
                playbackBook,
                audioChapter,
              ),
            );
          },
        ),
      const SizedBox(height: 20),
      SectionHeader(title: strings.otherVersions),
      for (final version in book.versions)
        Card(
          child: ListTile(
            leading: const AppIcon(AppIconAssets.bookSource),
            title: Text('${version.sourceName} · ${version.narrator}'),
            subtitle: Text('${version.durationLabel} · ${version.accessLabel}'),
          ),
        ),
      const SizedBox(height: 20),
      SectionHeader(title: desktop ? strings.information : 'Information'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _InfoPill(label: book.sourceName),
          _InfoPill(label: book.genre),
          _InfoPill(label: '${book.year}'),
          _InfoPill(label: 'Audio ${book.audioYear}'),
          _InfoPill(label: book.series),
          DownloadStatusChip(status: book.downloadStatus),
        ],
      ),
    ];
    final content = desktop || television
        ? DesktopBookDetailsLayout(
            key: const ValueKey('desktop-legacy-details-content'),
            summary: DesktopBookSummary(
              coverBuilder: (width) => BookCover(
                title: book.title,
                progress: book.progress,
                width: width,
                height: width * 1.4,
                showProgressPercent: false,
              ),
              metadata: _BookHeaderDetails(
                book: book,
                section: _BookHeaderSection.identity,
              ),
              details: _BookHeaderDetails(
                book: book,
                section: _BookHeaderSection.facts,
              ),
              actions: actions,
            ),
            contentSlivers: [SliverList.list(children: bodyChildren)],
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 640;
                  final coverWidth = compact ? 112.0 : 148.0;
                  final cover = BookCover(
                    title: book.title,
                    progress: book.progress,
                    width: coverWidth,
                    height: compact ? 156 : 206,
                  );
                  final details = _BookHeaderDetails(book: book);

                  if (compact) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        cover,
                        const SizedBox(width: 16),
                        Expanded(child: details),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cover,
                      const SizedBox(width: 24),
                      Expanded(child: details),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              actions,
              ...bodyChildren,
            ],
          );
    if (television) {
      return TelevisionStandaloneShell(
        title: strings.bookDetails,
        selectedIndex: 2,
        child: content,
      );
    }
    final screen = Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarToolbarHeight(context),
        title: preserveAppBarTextScale(context, Text(strings.bookDetails)),
      ),
      body: content,
    );
    return desktop
        ? DesktopStandaloneShell(selectedIndex: 2, child: screen)
        : screen;
  }
}

enum _BookHeaderSection { all, identity, facts }

class _BookHeaderDetails extends StatelessWidget {
  const _BookHeaderDetails({
    required this.book,
    this.section = _BookHeaderSection.all,
  });

  final MockBook book;
  final _BookHeaderSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final identity = section != _BookHeaderSection.facts;
    final facts = section != _BookHeaderSection.identity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (identity) ...[
          Text(
            book.title,
            style: Theme.of(context).textTheme.headlineSmall,
            maxLines: DesktopLayout.isActive(context) ? null : 3,
            overflow: DesktopLayout.isActive(context)
                ? TextOverflow.visible
                : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],
        if (facts) ...[
          Text(
            book.author,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (identity) Text('${book.narrator} · ${book.durationLabel}'),
        if (facts) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: book.progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          Text('${(book.progress * 100).round()}% · ${book.remainingLabel}'),
        ],
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}
