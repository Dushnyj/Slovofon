import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/mock_audio_playback.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../domain/models/download_task.dart';
import '../../services/audio/audio_persistence.dart';
import '../../services/audio/playback_controller.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/audio/audio_state.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/home/home_listening_visibility_store.dart';
import '../../services/library/library_store.dart';
import '../../services/sources/source_book_cache.dart';
import '../../services/sources/source_catalog_provider.dart';
import '../../sources/sources.dart';
import '../../ui/components/app_buttons.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/download_action_button.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/source_badge.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';
import '../shared/playback_resume.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final manager = ref.watch(downloadManagerProvider);
    final playbackController = ref.watch(playbackControllerProvider);
    final progressSnapshots =
        ref.watch(playbackProgressSnapshotsProvider).value ??
        const <PlaybackProgressSnapshot>[];
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
                playbackController: playbackController,
                progressSnapshots: progressSnapshots,
              ),
              _DownloadSection(
                title: strings.queuedDownloads,
                groups: queued,
                manager: manager,
                playbackController: playbackController,
                progressSnapshots: progressSnapshots,
              ),
              _DownloadSection(
                title: strings.failedDownloads,
                groups: failed,
                manager: manager,
                playbackController: playbackController,
                progressSnapshots: progressSnapshots,
              ),
              _DownloadSection(
                title: strings.completedDownloads,
                groups: completed,
                manager: manager,
                playbackController: playbackController,
                progressSnapshots: progressSnapshots,
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
    required this.playbackController,
    required this.progressSnapshots,
  });

  final String title;
  final List<_DownloadBookGroup> groups;
  final DownloadManager manager;
  final PlaybackController playbackController;
  final List<PlaybackProgressSnapshot> progressSnapshots;

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
            child: _DownloadBookTile(
              group: group,
              manager: manager,
              playbackController: playbackController,
              progressSnapshots: progressSnapshots,
            ),
          ),
      ],
    );
  }
}

class _DownloadBookTile extends ConsumerWidget {
  const _DownloadBookTile({
    required this.group,
    required this.manager,
    required this.playbackController,
    required this.progressSnapshots,
  });

  final _DownloadBookGroup group;
  final DownloadManager manager;
  final PlaybackController playbackController;
  final List<PlaybackProgressSnapshot> progressSnapshots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final playbackBook = group.playbackBook;
    final playbackState = playbackController.state;
    final isCurrentBook = _playbackMatchesBook(
      playbackState.book,
      playbackBook,
    );
    final progress = group.progress;
    final listeningProgress = isCurrentBook
        ? playbackState.bookProgress
        : _progressForBook(playbackBook, progressSnapshots);
    final year = playbackBook.publishedYear ?? group.mockBook?.year;
    final duration = _formatDuration(playbackBook.totalDuration);
    final author = _shortPeopleLabel(playbackBook.author);
    final narrator = _shortPeopleLabel(playbackBook.narrator);
    final series = _trimOrNull(playbackBook.seriesTitle);
    final rating = _ratingLabel(playbackBook.ratingValue);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(
              title: playbackBook.title,
              progress: listeningProgress,
              imageUrl: playbackBook.coverUrl,
              width: 58,
              height: 82,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playbackBook.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (author != null)
                    _DownloadMetaLine(
                      iconAsset: AppIconAssets.bookAuthor,
                      label: author,
                    ),
                  if (narrator != null)
                    _DownloadMetaLine(
                      iconAsset: AppIconAssets.bookNarrator,
                      label: narrator,
                    ),
                  if (series != null)
                    _DownloadMetaLine(
                      iconAsset: AppIconAssets.bookSeries,
                      label: series,
                    ),
                  const SizedBox(height: 5),
                  DefaultTextStyle.merge(
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.1,
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (duration != '0 мин')
                          _InlineDownloadMeta(
                            iconAsset: AppIconAssets.bookDuration,
                            label: duration,
                          ),
                        if (year != null)
                          _InlineDownloadMeta(
                            iconAsset: AppIconAssets.bookYear,
                            label: '$year',
                          ),
                        if (rating != null)
                          _InlineDownloadMeta(
                            iconAsset: AppIconAssets.bookRating,
                            label: rating,
                          ),
                        _InlineDownloadMeta(
                          iconAsset: AppIconAssets.bookSource,
                          label: strings.sourceDisplayName(
                            playbackBook.sourceId,
                          ),
                          color: sourceColorForId(
                            playbackBook.sourceId,
                            colorScheme,
                          ),
                        ),
                        _InlineDownloadMeta(
                          iconAsset: _statusIcon(group.displayStatus),
                          label: _statusLabel(strings, group.displayStatus),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${strings.downloadChaptersProgress(group.completedCount, group.totalChapterCount)} · ${_groupSizeLabel(context, group)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 8),
                  _DownloadBookActions(
                    group: group,
                    manager: manager,
                    isCurrentBook: isCurrentBook,
                    isPlaying: playbackState.isPlaying,
                    isPlaybackLoading:
                        isCurrentBook &&
                        (playbackState.status == AudioPlaybackStatus.loading ||
                            playbackState.status ==
                                AudioPlaybackStatus.buffering),
                    onPlay: () {
                      unawaited(_playBookFromDownloads(context, ref, group));
                    },
                    onInfo: () => _openSourceBook(context, group.playbackBook),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          for (final chapter in group.playbackBook.chapters)
            _DownloadChapterRow(
              chapter: chapter,
              task: group.taskForChapter(chapter),
              manager: manager,
              playbackBook: playbackBook,
              onPlay: () {
                unawaited(
                  _playBookFromDownloads(context, ref, group, chapter: chapter),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DownloadMetaLine extends StatelessWidget {
  const _DownloadMetaLine({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          AppIcon(iconAsset, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineDownloadMeta extends StatelessWidget {
  const _InlineDownloadMeta({
    required this.iconAsset,
    required this.label,
    this.color,
  });

  final String iconAsset;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = color ?? colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(iconAsset, size: 13, color: foreground),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: color == null
              ? null
              : TextStyle(color: foreground, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _DownloadBookActions extends StatelessWidget {
  const _DownloadBookActions({
    required this.group,
    required this.manager,
    required this.isCurrentBook,
    required this.isPlaying,
    required this.isPlaybackLoading,
    required this.onPlay,
    required this.onInfo,
  });

  final _DownloadBookGroup group;
  final DownloadManager manager;
  final bool isCurrentBook;
  final bool isPlaying;
  final bool isPlaybackLoading;
  final VoidCallback onPlay;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final status = group.displayStatus;
    final colorScheme = Theme.of(context).colorScheme;

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
          DownloadActionButton(
            state: _bookDownloadState(status),
            progress: group.progress,
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
        const SizedBox(width: 8),
        if (isPlaybackLoading)
          SizedBox.square(
            dimension: 44,
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: colorScheme.primary,
                ),
              ),
            ),
          )
        else
          AppIconActionButton(
            tooltip: isCurrentBook && isPlaying ? strings.pause : strings.play,
            iconAsset: isCurrentBook && isPlaying
                ? AppIconAssets.playerPause
                : AppIconAssets.playerPlay,
            onPressed: onPlay,
            foregroundColor: isCurrentBook ? colorScheme.primary : null,
          ),
        const SizedBox(width: 8),
        AppIconActionButton(
          tooltip: strings.bookDetails,
          iconAsset: AppIconAssets.systemInfo,
          onPressed: onInfo,
        ),
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
    await manager.enqueueMissingChapters(group.playbackBook);
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
    await manager.enqueueMissingChapters(group.playbackBook);
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
    required this.chapter,
    required this.task,
    required this.manager,
    required this.playbackBook,
    required this.onPlay,
  });

  final AudioPlaybackChapter chapter;
  final DownloadTask? task;
  final DownloadManager manager;
  final AudioPlaybackBook playbackBook;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = (task?.progress ?? 0).clamp(0, 1).toDouble();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPlay,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primaryContainer,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${chapter.index}',
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _chapterMeta(context, task, chapter),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        if (task?.status == DownloadTaskStatus.running &&
                            (task?.speedBytesPerSecond ?? 0) > 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${_formatBytes(task!.speedBytesPerSecond)}/s',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(999),
                          backgroundColor: colorScheme.surfaceContainerHigh,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DownloadActionButton(
                    state: downloadStateForTask(task),
                    progress: progress,
                    onPressed: () => runChapterCardDownloadAction(
                      manager,
                      playbackBook,
                      chapter,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _chapterMeta(
    BuildContext context,
    DownloadTask? task,
    AudioPlaybackChapter chapter,
  ) {
    final parts = <String>[
      _formatDuration(chapter.duration),
      if (task == null) context.strings.download else _sizeLabel(context, task),
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

  DownloadTask? taskForChapter(AudioPlaybackChapter chapter) {
    for (final task in tasks) {
      if (task.chapterId == chapter.id) {
        return task;
      }
    }
    return null;
  }

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
    if (completedCount < totalChapterCount) {
      return _DownloadBookSection.active;
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
    if (completedCount < totalChapterCount) {
      return DownloadTaskStatus.paused;
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
    if (tasks.isEmpty || totalChapterCount <= 0) {
      return 0;
    }
    final summed = tasks.fold<double>(
      0,
      (sum, task) => sum + task.progress.clamp(0, 1).toDouble(),
    );
    return (summed / totalChapterCount).clamp(0, 1).toDouble();
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

Future<void> _playBookFromDownloads(
  BuildContext context,
  WidgetRef ref,
  _DownloadBookGroup group, {
  AudioPlaybackChapter? chapter,
}) async {
  final manager = ref.read(downloadManagerProvider);
  final playbackController = ref.read(playbackControllerProvider);
  final strings = context.strings;

  try {
    final freshBook = await _freshBookForDownloads(ref, group, chapter);
    final playbackBook = await manager.offlinePlaybackBook(freshBook);
    if (playbackBook.chapters.isEmpty) {
      return;
    }

    if (_playbackMatchesBook(playbackController.state.book, playbackBook)) {
      if (chapter == null) {
        await playbackController.togglePlayPause();
      } else {
        final chapterIndex = _chapterIndex(playbackBook, chapter);
        if (chapterIndex == playbackController.state.chapterIndex) {
          await playbackController.togglePlayPause();
        } else {
          await playbackController.playChapterAt(chapterIndex);
        }
      }
      return;
    }

    final snapshots =
        await ref.read(playbackPersistenceStoreProvider)?.loadProgress() ??
        const <PlaybackProgressSnapshot>[];
    final resumePoint = playbackResumePointForBook(playbackBook, snapshots);
    final targetChapterIndex = chapter == null
        ? resumePoint.chapterIndex
        : _chapterIndex(playbackBook, chapter);
    final targetPosition =
        chapter != null && targetChapterIndex != resumePoint.chapterIndex
        ? Duration.zero
        : resumePoint.position;

    await playbackController.loadBook(
      playbackBook,
      chapterIndex: targetChapterIndex,
      position: targetPosition,
      autoPlay: true,
    );
    await ref
        .read(homeListeningVisibilityStoreProvider)
        .show(homeListeningBookKeyFor(playbackBook));
    ref.invalidate(playbackProgressSnapshotsProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${strings.play}: $error')));
    }
  }
}

Future<AudioPlaybackBook> _freshBookForDownloads(
  WidgetRef ref,
  _DownloadBookGroup group,
  AudioPlaybackChapter? chapter,
) async {
  final book = group.playbackBook;
  final sourceBookId = book.sourceBookId;
  if (sourceBookId == null || sourceBookId.isEmpty) {
    return book;
  }

  final task = chapter == null ? null : group.taskForChapter(chapter);
  final needsNetworkMedia =
      task == null || task.status != DownloadTaskStatus.completed;
  if (!needsNetworkMedia &&
      group.displayStatus == DownloadTaskStatus.completed) {
    return book;
  }

  try {
    final snapshot = await ref
        .read(sourceCatalogServiceProvider)
        .loadBook(
          SourceBookRef(sourceId: book.sourceId, sourceBookId: sourceBookId),
        );
    unawaited(
      SourceBookCache(
        downloadStorage: ref.read(downloadStorageProvider),
        downloadManager: ref.read(downloadManagerProvider),
        libraryStore: ref.read(libraryStoreProvider),
      ).refresh(snapshot).catchError((Object error, StackTrace stackTrace) {
        debugPrint('Failed to cache source book metadata: $error');
        return snapshot;
      }),
    );
    return snapshot.playbackBook;
  } catch (_) {
    return book;
  }
}

int _chapterIndex(AudioPlaybackBook book, AudioPlaybackChapter chapter) {
  final byId = book.chapters.indexWhere((item) => item.id == chapter.id);
  if (byId >= 0) {
    return byId;
  }
  return (chapter.index - 1).clamp(0, book.chapters.length - 1);
}

void _openSourceBook(BuildContext context, AudioPlaybackBook book) {
  final sourceBookId = book.sourceBookId;
  if (sourceBookId == null || sourceBookId.isEmpty) {
    unawaited(context.push('/player'));
    return;
  }
  unawaited(
    context.push(
      '/source-book/${book.sourceId}/${Uri.encodeComponent(sourceBookId)}',
    ),
  );
}

bool _playbackMatchesBook(
  AudioPlaybackBook? activeBook,
  AudioPlaybackBook book,
) {
  if (activeBook == null || activeBook.sourceId != book.sourceId) {
    return false;
  }
  return activeBook.sourceBookId == book.sourceBookId ||
      activeBook.versionId == book.versionId ||
      activeBook.id == book.id;
}

double _progressForBook(
  AudioPlaybackBook book,
  List<PlaybackProgressSnapshot> snapshots,
) {
  for (final snapshot in snapshots) {
    if (snapshot.bookVersionId == book.versionId ||
        snapshot.bookId == book.id) {
      return (snapshot.percent / 100).clamp(0, 1).toDouble();
    }
  }
  return 0;
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

String? _shortPeopleLabel(String value) {
  final people = value
      .split(RegExp(r'\s*,\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (people.isEmpty) {
    return null;
  }
  if (people.length <= 2) {
    return people.join(', ');
  }
  return '${people.take(2).join(', ')} и др.';
}

String? _ratingLabel(double? value) {
  if (value == null || value <= 0) {
    return null;
  }
  final rounded = double.parse(value.clamp(0, 5).toStringAsFixed(1));
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return '$text из 5';
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == '-' || trimmed == '—') {
    return null;
  }
  return trimmed;
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
