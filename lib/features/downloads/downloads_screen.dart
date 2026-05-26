import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/mock_audio_playback.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../domain/models/download_task.dart';
import '../../services/audio/audio_state.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final manager = ref.watch(downloadManagerProvider);
    final tasks = manager.tasks
        .where((task) => task.status != DownloadTaskStatus.canceled)
        .toList();
    final active = tasks
        .where(
          (task) =>
              task.status == DownloadTaskStatus.running ||
              task.status == DownloadTaskStatus.paused,
        )
        .toList();
    final queued = tasks
        .where((task) => task.status == DownloadTaskStatus.queued)
        .toList();
    final completed = tasks
        .where((task) => task.status == DownloadTaskStatus.completed)
        .toList();
    final failed = tasks
        .where((task) => task.status == DownloadTaskStatus.failed)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            SectionHeader(
              title: strings.downloads,
              subtitle: strings.downloadsQueueSubtitle,
            ),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  strings.emptyDownloads,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else ...[
              _DownloadSection(
                title: strings.activeDownloads,
                tasks: active,
                manager: manager,
              ),
              _DownloadSection(
                title: strings.queuedDownloads,
                tasks: queued,
                manager: manager,
              ),
              _DownloadSection(
                title: strings.failedDownloads,
                tasks: failed,
                manager: manager,
              ),
              _DownloadSection(
                title: strings.completedDownloads,
                tasks: completed,
                manager: manager,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DownloadSection extends StatelessWidget {
  const _DownloadSection({
    required this.title,
    required this.tasks,
    required this.manager,
  });

  final String title;
  final List<DownloadTask> tasks;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SectionHeader(title: title),
        for (final task in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DownloadTile(task: task, manager: manager),
          ),
      ],
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.task, required this.manager});

  final DownloadTask task;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final book = mockBookById(task.bookId);
    final playbackBook = mockAudioPlaybackBook(book);
    final chapter = chapterForTask(playbackBook, task);
    final progress = task.progress.clamp(0, 1).toDouble();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go('/book/${book.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                    title: book.title,
                    progress: book.progress,
                    width: 58,
                    height: 80,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          book.author,
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
                              label: book.narrator,
                            ),
                            _MetaPill(
                              iconAsset: AppIconAssets.bookYear,
                              label: '${book.year}',
                            ),
                            _MetaPill(
                              iconAsset: AppIconAssets.bookSource,
                              label: book.sourceName,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${chapter?.title ?? strings.chapters} · ${_sizeLabel(context, task)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        if (task.status == DownloadTaskStatus.running &&
                            task.speedBytesPerSecond > 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${_formatBytes(task.speedBytesPerSecond)}/s',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _DownloadActions(
                    task: task,
                    manager: manager,
                    playbackBook: playbackBook,
                    chapter: chapter,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 8),
              _StatusPill(status: task.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadActions extends StatelessWidget {
  const _DownloadActions({
    required this.task,
    required this.manager,
    required this.playbackBook,
    required this.chapter,
  });

  final DownloadTask task;
  final DownloadManager manager;
  final AudioPlaybackBook playbackBook;
  final AudioPlaybackChapter? chapter;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final progress = task.progress.clamp(0, 1).toDouble();

    return Column(
      children: [
        if (task.status == DownloadTaskStatus.running)
          Tooltip(
            message: strings.pauseDownload,
            child: SizedBox.square(
              dimension: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(value: progress, strokeWidth: 4),
                  IconButton(
                    tooltip: strings.pauseDownload,
                    onPressed: () => manager.pause(task.id),
                    icon: const AppIcon(AppIconAssets.pauseDownload, size: 18),
                  ),
                ],
              ),
            ),
          )
        else
          IconButton.outlined(
            tooltip: _primaryTooltip(strings, task.status),
            onPressed: chapter == null
                ? null
                : () =>
                      _runPrimaryAction(manager, playbackBook, chapter!, task),
            icon: AppIcon(_primaryIcon(task.status)),
          ),
        if (task.status != DownloadTaskStatus.completed) ...[
          const SizedBox(height: 4),
          IconButton(
            tooltip: _secondaryTooltip(strings, task.status),
            onPressed: chapter == null
                ? null
                : () => _runSecondaryAction(
                    manager,
                    playbackBook,
                    chapter!,
                    task,
                  ),
            icon: AppIcon(_secondaryIcon(task.status)),
          ),
        ],
      ],
    );
  }

  Future<void> _runPrimaryAction(
    DownloadManager manager,
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
    DownloadTask task,
  ) {
    return switch (task.status) {
      DownloadTaskStatus.completed => manager.deleteChapter(book, chapter),
      DownloadTaskStatus.paused => manager.resumeChapter(book, chapter),
      DownloadTaskStatus.failed => manager.retryChapter(book, chapter),
      DownloadTaskStatus.queued => manager.resumeChapter(book, chapter),
      DownloadTaskStatus.running => manager.pause(task.id),
      DownloadTaskStatus.canceled => manager.enqueueChapter(book, chapter),
    };
  }

  Future<void> _runSecondaryAction(
    DownloadManager manager,
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
    DownloadTask task,
  ) {
    return switch (task.status) {
      DownloadTaskStatus.running => manager.cancel(task.id),
      DownloadTaskStatus.queued => manager.cancel(task.id),
      DownloadTaskStatus.paused => manager.deleteChapter(book, chapter),
      DownloadTaskStatus.failed => manager.deleteChapter(book, chapter),
      DownloadTaskStatus.completed => manager.deleteChapter(book, chapter),
      DownloadTaskStatus.canceled => manager.deleteChapter(book, chapter),
    };
  }

  String _primaryIcon(DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.completed => AppIconAssets.deleteDownload,
      DownloadTaskStatus.running => AppIconAssets.pauseDownload,
      DownloadTaskStatus.queued => AppIconAssets.resumeDownload,
      DownloadTaskStatus.paused => AppIconAssets.resumeDownload,
      DownloadTaskStatus.failed => AppIconAssets.downloadRetry,
      DownloadTaskStatus.canceled => AppIconAssets.download,
    };
  }

  String _secondaryIcon(DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.running => AppIconAssets.systemClose,
      DownloadTaskStatus.queued => AppIconAssets.systemClose,
      DownloadTaskStatus.paused => AppIconAssets.deleteDownload,
      DownloadTaskStatus.failed => AppIconAssets.deleteDownload,
      DownloadTaskStatus.completed => AppIconAssets.systemInfo,
      DownloadTaskStatus.canceled => AppIconAssets.deleteDownload,
    };
  }

  String _primaryTooltip(AppStrings strings, DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.completed => strings.deleteDownloaded,
      DownloadTaskStatus.running => strings.pauseDownload,
      DownloadTaskStatus.queued => strings.resumeDownload,
      DownloadTaskStatus.paused => strings.resumeDownload,
      DownloadTaskStatus.failed => strings.retry,
      DownloadTaskStatus.canceled => strings.download,
    };
  }

  String _secondaryTooltip(AppStrings strings, DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.running => strings.cancelDownload,
      DownloadTaskStatus.queued => strings.cancelDownload,
      DownloadTaskStatus.paused => strings.deleteDownloaded,
      DownloadTaskStatus.failed => strings.deleteDownloaded,
      DownloadTaskStatus.completed => strings.details,
      DownloadTaskStatus.canceled => strings.deleteDownloaded,
    };
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final DownloadTaskStatus status;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            _statusIcon(status),
            size: 15,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            _statusLabel(strings, status),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _statusIcon(DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.completed => AppIconAssets.downloaded,
      DownloadTaskStatus.running => AppIconAssets.downloading,
      DownloadTaskStatus.queued => AppIconAssets.downloadQueued,
      DownloadTaskStatus.paused => AppIconAssets.pauseDownload,
      DownloadTaskStatus.failed => AppIconAssets.downloadError,
      DownloadTaskStatus.canceled => AppIconAssets.systemClose,
    };
  }

  String _statusLabel(AppStrings strings, DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.completed => strings.downloaded,
      DownloadTaskStatus.running => strings.downloading,
      DownloadTaskStatus.queued => strings.queued,
      DownloadTaskStatus.paused => strings.paused,
      DownloadTaskStatus.failed => strings.failed,
      DownloadTaskStatus.canceled => strings.cancel,
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

String _sizeLabel(BuildContext context, DownloadTask task) {
  final strings = context.strings;
  final total = task.totalBytes;
  if (total == null || total <= 0) {
    return task.downloadedBytes <= 0
        ? strings.unknownSize
        : _formatBytes(task.downloadedBytes);
  }
  return '${_formatBytes(task.downloadedBytes)} / ${_formatBytes(total)}';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }
  final mib = kib / 1024;
  if (mib < 1024) {
    return '${mib.toStringAsFixed(1)} MB';
  }
  final gib = mib / 1024;
  return '${gib.toStringAsFixed(1)} GB';
}
