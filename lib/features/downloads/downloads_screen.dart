import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            SectionHeader(
              title: strings.downloads,
              subtitle: 'Local mock queue with all download states.',
            ),
            for (final item in stage3MockDownloads)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DownloadTile(item: item),
              ),
          ],
        ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.item});

  final MockDownloadItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = item.progress.clamp(0, 1).toDouble();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go('/book/${item.book.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                    title: item.book.title,
                    progress: item.book.progress,
                    width: 58,
                    height: 80,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _MetaPill(
                              iconAsset: AppIconAssets.bookNarrator,
                              label: item.book.narrator,
                            ),
                            _MetaPill(
                              iconAsset: AppIconAssets.bookYear,
                              label: '${item.book.year}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.chapterTitle} · ${item.sizeLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _DownloadActions(item: item),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadActions extends StatelessWidget {
  const _DownloadActions({required this.item});

  final MockDownloadItem item;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final progress = item.progress.clamp(0, 1).toDouble();

    return Column(
      children: [
        if (item.status == MockDownloadStatus.downloading)
          Tooltip(
            message: strings.pauseDownload,
            child: SizedBox.square(
              dimension: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          )
        else
          IconButton.outlined(
            tooltip: _primaryTooltip(strings, item.status),
            onPressed: () {},
            icon: AppIcon(_primaryIcon(item.status)),
          ),
        if (item.status != MockDownloadStatus.downloaded) ...[
          const SizedBox(height: 4),
          IconButton(
            tooltip: _secondaryTooltip(strings, item.status),
            onPressed: () {},
            icon: AppIcon(_secondaryIcon(item.status)),
          ),
        ],
      ],
    );
  }

  String _primaryIcon(MockDownloadStatus status) {
    return switch (status) {
      MockDownloadStatus.downloaded => AppIconAssets.deleteDownload,
      MockDownloadStatus.downloading => AppIconAssets.pauseDownload,
      MockDownloadStatus.queued => AppIconAssets.download,
      MockDownloadStatus.paused => AppIconAssets.resumeDownload,
      MockDownloadStatus.failed => AppIconAssets.downloadRetry,
    };
  }

  String _secondaryIcon(MockDownloadStatus status) {
    return switch (status) {
      MockDownloadStatus.downloading => AppIconAssets.systemClose,
      MockDownloadStatus.downloaded => AppIconAssets.systemInfo,
      MockDownloadStatus.queued => AppIconAssets.systemClose,
      MockDownloadStatus.paused => AppIconAssets.deleteDownload,
      MockDownloadStatus.failed => AppIconAssets.deleteDownload,
    };
  }

  String _primaryTooltip(AppStrings strings, MockDownloadStatus status) {
    return switch (status) {
      MockDownloadStatus.downloaded => strings.deleteDownloaded,
      MockDownloadStatus.downloading => strings.pauseDownload,
      MockDownloadStatus.queued => strings.download,
      MockDownloadStatus.paused => strings.resumeDownload,
      MockDownloadStatus.failed => strings.retry,
    };
  }

  String _secondaryTooltip(AppStrings strings, MockDownloadStatus status) {
    return switch (status) {
      MockDownloadStatus.downloading => strings.cancelDownload,
      MockDownloadStatus.downloaded => strings.details,
      MockDownloadStatus.queued => strings.cancelDownload,
      MockDownloadStatus.paused => strings.deleteDownloaded,
      MockDownloadStatus.failed => strings.deleteDownloaded,
    };
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 168),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(iconAsset, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
