import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../ui/components/download_status_chip.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.downloads)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.item});

  final MockDownloadItem item;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;

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
                          '${item.chapterTitle} · ${item.sizeLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  DownloadStatusChip(status: item.status),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: item.progress.clamp(0, 1).toDouble(),
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const AppIcon(AppIconAssets.downloadRetry),
                    label: const Text('Retry'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const AppIcon(AppIconAssets.deleteDownload),
                    label: Text(strings.deleteDownloaded),
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
