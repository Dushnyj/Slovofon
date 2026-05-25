import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../shared/mock_book_card_state.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final startedBooks = stage3MockBooks
        .where((book) => book.progress > 0 && !book.isFinished)
        .toList();
    final downloadedBooks = stage3MockBooks
        .where((book) => book.downloadStatus == MockDownloadStatus.downloaded)
        .toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              SectionHeader(
                title: strings.continueListening,
                subtitle: strings.mockDataNotice,
              ),
              _ContinueCard(book: activeMockBook),
              const SizedBox(height: 20),
              SectionHeader(title: strings.startedBooks),
              for (final book in startedBooks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookCard(
                    book: book.toAudioBook(),
                    yearLabel: '${book.year}',
                    isFavorite: book.isFavorite,
                    downloadState: mockDownloadStateFor(book.downloadStatus),
                    downloadProgress:
                        book.downloadStatus == MockDownloadStatus.downloading
                        ? 0.48
                        : book.progress,
                    onPlay: () => context.go('/player'),
                    onTap: () => context.go('/book/${book.id}'),
                  ),
                ),
              const SizedBox(height: 8),
              SectionHeader(title: strings.offlineDownloads),
              if (downloadedBooks.isEmpty)
                Text(
                  strings.emptyDownloads,
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final book in downloadedBooks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BookCard(
                      book: book.toAudioBook(),
                      yearLabel: '${book.year}',
                      isFavorite: book.isFavorite,
                      downloadState: mockDownloadStateFor(book.downloadStatus),
                      downloadProgress: book.progress,
                      onPlay: () => context.go('/player'),
                      onTap: () => context.go('/book/${book.id}'),
                    ),
                  ),
              const SizedBox(height: 8),
              SectionHeader(title: strings.recommended),
              for (final book in stage3MockBooks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookCard(
                    book: book.toAudioBook(),
                    yearLabel: '${book.year}',
                    isFavorite: book.isFavorite,
                    downloadState: mockDownloadStateFor(book.downloadStatus),
                    downloadProgress: book.progress,
                    onPlay: () => context.go('/player'),
                    onTap: () => context.go('/book/${book.id}'),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.book});

  final MockBook book;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go('/book/${book.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              BookCover(
                title: book.title,
                progress: book.progress,
                width: 92,
                height: 128,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${book.author} · ${book.narrator}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ContinueMeta(
                          iconAsset: AppIconAssets.bookDuration,
                          label: book.durationLabel,
                        ),
                        _ContinueMeta(
                          iconAsset: AppIconAssets.bookYear,
                          label: '${book.year}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${book.activeChapterTitle} · ${book.positionLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: book.progress,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(book.progress * 100).round()}%',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: strings.continuePlayback,
                          onPressed: () => context.go('/player'),
                          icon: const AppIcon(AppIconAssets.playerPlay),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    tooltip: book.isFavorite
                        ? strings.removeFavorite
                        : strings.addFavorite,
                    onPressed: () {},
                    icon: AppIcon(
                      AppIconAssets.bookFavorite,
                      color: book.isFavorite
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip:
                        book.downloadStatus == MockDownloadStatus.downloaded
                        ? strings.deleteDownloaded
                        : strings.download,
                    onPressed: () {},
                    icon: AppIcon(
                      book.downloadStatus == MockDownloadStatus.downloaded
                          ? AppIconAssets.deleteDownload
                          : AppIconAssets.download,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContinueMeta extends StatelessWidget {
  const _ContinueMeta({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(iconAsset, size: 15, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
