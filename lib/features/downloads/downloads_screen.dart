import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/mock_audio_playback.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../domain/models/download_task.dart';
import '../../services/audio/audio_state.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../ui/components/app_buttons.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/download_action_button.dart';
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
    final groups = _downloadBookGroups(tasks, manager);
    final active = groups
        .where((group) => group.section == _DownloadBookSection.active)
        .toList();
    final queued = groups
        .where((group) => group.section == _DownloadBookSection.queued)
        .toList();
    final failed = groups
        .where((group) => group.section == _DownloadBookSection.failed)
        .toList();
    final completed = groups
        .where((group) => group.section == _DownloadBookSection.completed)
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
            if (groups.isEmpty)
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
                groups: active,
                manager: manager,
              ),
              _DownloadSection(
                title: strings.queuedDownloads,
                groups: queued,
                manager: manager,
              ),
              _DownloadSection(
                title: strings.failedDownloads,
                groups: failed,
                manager: manager,
              ),
              _DownloadSection(
                title: strings.completedDownloads,
                groups: completed,
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
    required this.groups,
    required this.manager,
  });

  final String title;
  final List<_DownloadBookGroup> groups;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        SectionHeader(title: title),
        for (final group in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DownloadBookTile(group: group, manager: manager),
          ),
      ],
    );
  }
}

class _DownloadBookTile extends StatelessWidget {
  const _DownloadBookTile({required this.group, required this.manager});

  final _DownloadBookGroup group;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final playbackBook = group.playbackBook;
    final progress = group.progress;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: BookCover(
          title: playbackBook.title,
          progress: group.mockBook?.progress ?? 0,
          imageUrl: playbackBook.coverUrl,
          width: 58,
          height: 80,
        ),
        title: Text(
          playbackBook.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playbackBook.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MetaPill(
                    iconAsset: AppIconAssets.bookNarrator,
                    label: playbackBook.narrator,
                  ),
                  if (playbackBook.publishedYear != null ||
                      group.mockBook != null)
                    _MetaPill(
                      iconAsset: AppIconAssets.bookYear,
                      label:
                          playbackBook.publishedYear?.toString() ??
                          '${group.mockBook!.year}',
                    ),
                  _MetaPill(
                    iconAsset: AppIconAssets.bookSource,
                    label: playbackBook.sourceName,
                  ),
                  _StatusPill(status: group.displayStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${strings.downloadChaptersProgress(group.completedCount, group.totalChapterCount)} · ${_groupSizeLabel(context, group)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 8),
              _DownloadBookActions(group: group, manager: manager),
            ],
          ),
        ),
        children: [
          for (final task in group.tasks)
            _DownloadChapterRow(
              task: task,
              manager: manager,
              playbackBook: playbackBook,
            ),
        ],
      ),
    );
  }
}

class _DownloadBookActions extends StatelessWidget {
  const _DownloadBookActions({required this.group, required this.manager});

  final _DownloadBookGroup group;
  final DownloadManager manager;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final status = group.displayStatus;

    return Row(
      children: [
        if (status == DownloadTaskStatus.running ||
            status == DownloadTaskStatus.queued) ...[
          AppIconActionButton(
            tooltip: strings.pauseDownload,
            iconAsset: AppIconAssets.pauseDownload,
            onPressed: () => _pauseBook(group, manager),
          ),
          const SizedBox(width: 8),
          DownloadActionButton(
            state: _bookDownloadState(status),
            progress: group.progress,
            onPressed: () => manager.cancelAndDeleteBook(group.playbackBook),
          ),
        ] else ...[
          AppIconActionButton(
            tooltip: _primaryTooltip(strings, status),
            iconAsset: _primaryIcon(status),
            onPressed: () => _runPrimary(group, manager),
          ),
          if (status != DownloadTaskStatus.completed) ...[
            const SizedBox(width: 8),
            AppIconActionButton(
              tooltip: strings.deleteDownloaded,
              iconAsset: AppIconAssets.deleteDownload,
              onPressed: () => manager.cancelAndDeleteBook(group.playbackBook),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _runPrimary(
    _DownloadBookGroup group,
    DownloadManager manager,
  ) async {
    return switch (group.displayStatus) {
      DownloadTaskStatus.running => _pauseBook(group, manager),
      DownloadTaskStatus.queued => _pauseBook(group, manager),
      DownloadTaskStatus.paused => _resumeBook(group, manager),
      DownloadTaskStatus.failed => _retryBook(group, manager),
      DownloadTaskStatus.completed => manager.cancelAndDeleteBook(
        group.playbackBook,
      ),
      DownloadTaskStatus.canceled => manager.enqueueMissingChapters(
        group.playbackBook,
      ),
    };
  }

  Future<void> _pauseBook(
    _DownloadBookGroup group,
    DownloadManager manager,
  ) async {
    for (final task in group.tasks) {
      if (task.status == DownloadTaskStatus.running ||
          task.status == DownloadTaskStatus.queued) {
        await manager.pause(task.id);
      }
    }
  }

  Future<void> _resumeBook(
    _DownloadBookGroup group,
    DownloadManager manager,
  ) async {
    for (final task in group.tasks) {
      if (task.status == DownloadTaskStatus.completed) {
        continue;
      }
      final chapter = chapterForTask(group.playbackBook, task);
      if (chapter != null) {
        await manager.resumeChapter(group.playbackBook, chapter);
      }
    }
  }

  Future<void> _retryBook(
    _DownloadBookGroup group,
    DownloadManager manager,
  ) async {
    for (final task in group.tasks) {
      if (task.status != DownloadTaskStatus.failed) {
        continue;
      }
      final chapter = chapterForTask(group.playbackBook, task);
      if (chapter != null) {
        await manager.retryChapter(group.playbackBook, chapter);
      }
    }
  }

  String _primaryIcon(DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.completed => AppIconAssets.deleteDownload,
      DownloadTaskStatus.running => AppIconAssets.pauseDownload,
      DownloadTaskStatus.queued => AppIconAssets.pauseDownload,
      DownloadTaskStatus.paused => AppIconAssets.resumeDownload,
      DownloadTaskStatus.failed => AppIconAssets.downloadRetry,
      DownloadTaskStatus.canceled => AppIconAssets.download,
    };
  }

  String _primaryTooltip(AppStrings strings, DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.completed => strings.deleteDownloaded,
      DownloadTaskStatus.running => strings.pauseDownload,
      DownloadTaskStatus.queued => strings.pauseDownload,
      DownloadTaskStatus.paused => strings.resumeDownload,
      DownloadTaskStatus.failed => strings.retry,
      DownloadTaskStatus.canceled => strings.download,
    };
  }

  BookCardDownloadState _bookDownloadState(DownloadTaskStatus status) {
    return switch (status) {
      DownloadTaskStatus.running => BookCardDownloadState.downloading,
      DownloadTaskStatus.queued => BookCardDownloadState.queued,
      DownloadTaskStatus.paused => BookCardDownloadState.paused,
      DownloadTaskStatus.failed => BookCardDownloadState.failed,
      DownloadTaskStatus.completed => BookCardDownloadState.downloaded,
      DownloadTaskStatus.canceled => BookCardDownloadState.none,
    };
  }
}

class _DownloadChapterRow extends StatelessWidget {
  const _DownloadChapterRow({
    required this.task,
    required this.manager,
    required this.playbackBook,
  });

  final DownloadTask task;
  final DownloadManager manager;
  final AudioPlaybackBook playbackBook;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final chapter = chapterForTask(playbackBook, task);
    final progress = task.progress.clamp(0, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: Text('${chapter?.index ?? '-'}'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter?.title ?? strings.chapters,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _chapterMeta(context, task, chapter),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (task.status == DownloadTaskStatus.running &&
                        task.speedBytesPerSecond > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${_formatBytes(task.speedBytesPerSecond)}/s',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              DownloadActionButton(
                state: downloadStateForTask(task),
                progress: progress,
                onPressed: chapter == null
                    ? null
                    : () => runChapterCardDownloadAction(
                        manager,
                        playbackBook,
                        chapter,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _chapterMeta(
    BuildContext context,
    DownloadTask task,
    AudioPlaybackChapter? chapter,
  ) {
    final parts = <String>[
      if (chapter != null) _formatDuration(chapter.duration),
      _sizeLabel(context, task),
    ];
    return parts.join(' · ');
  }
}

enum _DownloadBookSection { active, queued, failed, completed }

class _DownloadBookGroup {
  const _DownloadBookGroup({
    required this.playbackBook,
    required this.tasks,
    this.mockBook,
  });

  final AudioPlaybackBook playbackBook;
  final List<DownloadTask> tasks;
  final MockBook? mockBook;

  _DownloadBookSection get section {
    if (tasks.any(
      (task) =>
          task.status == DownloadTaskStatus.running ||
          task.status == DownloadTaskStatus.paused,
    )) {
      return _DownloadBookSection.active;
    }
    if (tasks.any((task) => task.status == DownloadTaskStatus.failed)) {
      return _DownloadBookSection.failed;
    }
    if (tasks.any((task) => task.status == DownloadTaskStatus.queued)) {
      return _DownloadBookSection.queued;
    }
    return _DownloadBookSection.completed;
  }

  DownloadTaskStatus get displayStatus {
    if (tasks.any((task) => task.status == DownloadTaskStatus.running)) {
      return DownloadTaskStatus.running;
    }
    if (tasks.any((task) => task.status == DownloadTaskStatus.paused)) {
      return DownloadTaskStatus.paused;
    }
    if (tasks.any((task) => task.status == DownloadTaskStatus.failed)) {
      return DownloadTaskStatus.failed;
    }
    if (tasks.any((task) => task.status == DownloadTaskStatus.queued)) {
      return DownloadTaskStatus.queued;
    }
    return DownloadTaskStatus.completed;
  }

  int get completedCount {
    return tasks
        .where((task) => task.status == DownloadTaskStatus.completed)
        .length;
  }

  int get totalChapterCount {
    return playbackBook.chapters.isEmpty
        ? tasks.length
        : playbackBook.chapters.length;
  }

  double get progress {
    if (tasks.isEmpty) {
      return 0;
    }
    final summed = tasks.fold<double>(
      0,
      (sum, task) => sum + task.progress.clamp(0, 1).toDouble(),
    );
    return (summed / tasks.length).clamp(0, 1).toDouble();
  }
}

List<_DownloadBookGroup> _downloadBookGroups(
  List<DownloadTask> tasks,
  DownloadManager manager,
) {
  final byBook = <String, List<DownloadTask>>{};
  for (final task in tasks) {
    final key = '${task.sourceId}:${task.bookVersionId}';
    byBook.putIfAbsent(key, () => []).add(task);
  }

  final groups = <_DownloadBookGroup>[];
  for (final entry in byBook.entries) {
    final groupTasks = [...entry.value];
    final firstTask = groupTasks.first;
    final mockBook = _mockBookByIdOrNull(firstTask.bookId);
    final playbackBook =
        _attachedBookForTasks(manager, groupTasks) ??
        (mockBook == null
            ? _fallbackPlaybackBook(firstTask)
            : mockAudioPlaybackBook(mockBook));
    groupTasks.sort((left, right) {
      final leftChapter = chapterForTask(playbackBook, left);
      final rightChapter = chapterForTask(playbackBook, right);
      final leftIndex = leftChapter?.index ?? 1 << 30;
      final rightIndex = rightChapter?.index ?? 1 << 30;
      return leftIndex.compareTo(rightIndex);
    });
    groups.add(
      _DownloadBookGroup(
        playbackBook: playbackBook,
        tasks: List.unmodifiable(groupTasks),
        mockBook: mockBook,
      ),
    );
  }

  groups.sort((left, right) {
    final section = left.section.index.compareTo(right.section.index);
    if (section != 0) {
      return section;
    }
    return left.playbackBook.title.compareTo(right.playbackBook.title);
  });
  return groups;
}

AudioPlaybackBook? _attachedBookForTasks(
  DownloadManager manager,
  List<DownloadTask> tasks,
) {
  for (final task in tasks) {
    final book = manager.bookForTask(task.id);
    if (book != null) {
      return book;
    }
  }
  return null;
}

String _groupSizeLabel(BuildContext context, _DownloadBookGroup group) {
  final strings = context.strings;
  final allTotalsKnown =
      group.tasks.every(
        (task) => task.totalBytes != null && task.totalBytes! > 0,
      ) &&
      group.tasks.length >= group.totalChapterCount;
  final totalBytes = group.tasks.fold<int>(
    0,
    (sum, task) => sum + (task.totalBytes ?? 0),
  );
  final downloadedBytes = group.tasks.fold<int>(
    0,
    (sum, task) => sum + task.downloadedBytes,
  );
  if (!allTotalsKnown || totalBytes <= 0) {
    return '${_formatBytes(downloadedBytes)} / ${strings.calculatingTotalSize}';
  }
  return '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}';
}

String _formatDuration(Duration duration) {
  if (duration <= Duration.zero) {
    return '0 мин';
  }
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes > 0 ? '$hours ч $minutes мин' : '$hours ч';
  }
  return '$minutes мин';
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

MockBook? _mockBookByIdOrNull(String id) {
  for (final book in stage3MockBooks) {
    if (book.id == id) {
      return book;
    }
  }
  return null;
}

AudioPlaybackBook _fallbackPlaybackBook(DownloadTask task) {
  return AudioPlaybackBook(
    id: task.bookId,
    versionId: task.bookVersionId,
    sourceId: task.sourceId,
    title: task.bookId,
    author: '',
    narrator: '',
    sourceName: task.sourceId,
    chapters: const [],
  );
}
