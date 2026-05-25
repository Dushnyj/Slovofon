import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/chapter_tile.dart';
import '../../ui/components/download_status_chip.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';

class BookDetailsScreen extends StatelessWidget {
  const BookDetailsScreen({required this.book, super.key});

  final MockBook book;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(strings.bookDetails)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 640;
              final cover = BookCover(
                title: book.title,
                progress: book.progress,
                width: compact ? 112 : 148,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconButton.filled(
                tooltip: book.progress > 0
                    ? strings.continuePlayback
                    : strings.play,
                onPressed: () => context.go('/player'),
                icon: const AppIcon(AppIconAssets.playerPlay),
              ),
              IconButton.outlined(
                tooltip: strings.download,
                onPressed: () {},
                icon: const AppIcon(AppIconAssets.download),
              ),
              IconButton.outlined(
                tooltip: strings.bookmarks,
                onPressed: () {},
                icon: const AppIcon(AppIconAssets.playerBookmark),
              ),
              IconButton.outlined(
                tooltip: strings.share,
                onPressed: () {},
                icon: const AppIcon(AppIconAssets.systemShare),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            book.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(title: strings.chapters),
          for (final chapter in book.chapters)
            ChapterTile(
              index: chapter.index,
              title: chapter.title,
              durationLabel: chapter.durationLabel,
              progress: chapter.progress,
              isDownloaded: chapter.isDownloaded,
              isCurrent: chapter.isCurrent,
              onTap: () => context.go('/player'),
            ),
          const SizedBox(height: 20),
          SectionHeader(title: strings.otherVersions),
          for (final version in book.versions)
            Card(
              child: ListTile(
                leading: const AppIcon(AppIconAssets.bookSource),
                title: Text('${version.sourceName} · ${version.narrator}'),
                subtitle: Text(
                  '${version.durationLabel} · ${version.accessLabel}',
                ),
              ),
            ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Information'),
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
        ],
      ),
    );
  }
}

class _BookHeaderDetails extends StatelessWidget {
  const _BookHeaderDetails({required this.book});

  final MockBook book;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.title,
          style: Theme.of(context).textTheme.headlineSmall,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          book.author,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text('${book.narrator} · ${book.durationLabel}'),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: book.progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(999),
        ),
        const SizedBox(height: 8),
        Text('${(book.progress * 100).round()}% · ${book.remainingLabel}'),
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
