import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
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
import '../../ui/adaptive/desktop_layout.dart';
import '../../ui/adaptive/television_layout.dart';
import '../../ui/components/app_buttons.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/book_fragment_badge.dart';
import '../../ui/components/download_action_button.dart';
import '../../ui/components/responsive_tile_grid.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/source_badge.dart';
import '../../ui/components/state_placeholder.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';
import '../shared/playback_resume.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final desktop = DesktopLayout.isActive(context);
    final television = TelevisionLayout.isActive(context);
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

    return ListenableBuilder(
      listenable: playbackController,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: desktop
                ? DesktopLayout.pagePadding(context)
                : television
                ? const EdgeInsets.fromLTRB(12, 4, 12, 16)
                : const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              if (desktop)
                DesktopPageHeader(
                  title: strings.downloads,
                  subtitle: groups.isEmpty
                      ? null
                      : strings.downloadsQueueSubtitle,
                  trailing: groups.isEmpty
                      ? null
                      : Text(
                          strings.booksCount(groups.length),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                )
              else if (!television)
                SectionHeader(
                  title: strings.downloads,
                  subtitle: strings.downloadsQueueSubtitle,
                ),
              if (desktop && groups.isNotEmpty)
                _DesktopDownloadSummary(
                  active: active.length,
                  queued: queued.length,
                  failed: failed.length,
                  completed: completed.length,
                ),
              if (groups.isEmpty && desktop)
                Card(
                  key: const ValueKey('desktop-downloads-empty'),
                  margin: const EdgeInsets.only(top: 16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    child: Column(
                      children: [
                        StatePlaceholder(
                          iconAsset: AppIconAssets.navDownloads,
                          title: strings.emptyDownloads,
                          message: strings.emptyDownloadsMessage,
                        ),
                        FilledButton.icon(
                          key: const ValueKey('desktop-downloads-empty-search'),
                          onPressed: () => context.go('/search'),
                          icon: const AppIcon(AppIconAssets.navSearch),
                          label: Text(strings.openSearch),
                        ),
                      ],
                    ),
                  ),
                )
              else if (groups.isEmpty)
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
      ),
    );
  }
}

class _DesktopDownloadSummary extends StatelessWidget {
  const _DesktopDownloadSummary({
    required this.active,
    required this.queued,
    required this.failed,
    required this.completed,
  });

  final int active;
  final int queued;
  final int failed;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final sections = [
      ('active', strings.activeDownloads, active),
      ('queued', strings.queuedDownloads, queued),
      ('failed', strings.failedDownloads, failed),
      ('completed', strings.completedDownloads, completed),
    ];
    return Card(
      key: const ValueKey('desktop-download-summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 28,
          runSpacing: 12,
          children: [
            for (final section in sections)
              Text.rich(
                key: ValueKey('desktop-download-count-${section.$1}'),
                TextSpan(
                  children: [
                    TextSpan(text: '${section.$2}  '),
                    TextSpan(
                      text: '${section.$3}',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
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

    final tiles = [
      for (final group in groups)
        _DownloadBookTile(
          group: group,
          manager: manager,
          playbackController: playbackController,
          progressSnapshots: progressSnapshots,
        ),
    ];
    final desktop = DesktopLayout.isActive(context);
    final television = TelevisionLayout.isActive(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: television ? 4 : 16),
        SectionHeader(
          title: title,
          subtitle: desktop ? context.strings.booksCount(groups.length) : null,
        ),
        if (desktop)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < tiles.length; index++) ...[
                tiles[index],
                if (index != tiles.length - 1) const SizedBox(height: 12),
              ],
            ],
          )
        else
          ResponsiveTileGrid(children: tiles),
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
    final year = playbackBook.publishedYear;
    final displayTitle = group.hasMetadata
        ? playbackBook.title
        : strings.downloadMetadataUnavailableTitle;
    final duration = _formatDuration(playbackBook.totalDuration);
    final author = _shortPeopleLabel(playbackBook.author);
    final narrator = _shortPeopleLabel(playbackBook.narrator);
    final series = _trimOrNull(playbackBook.seriesTitle);
    final rating = _ratingLabel(playbackBook.ratingValue);

    if (TelevisionLayout.isActive(context)) {
      return _TelevisionDownloadBookTile(
        group: group,
        manager: manager,
        playbackState: playbackState,
        isCurrentBook: isCurrentBook,
        onPlay: () => unawaited(_playBookFromDownloads(context, ref, group)),
        onInfo: () => _openSourceBook(context, group.playbackBook),
        chapters: [
          for (final chapter in playbackBook.chapters)
            _DownloadChapterRow(
              chapter: chapter,
              task: group.taskForChapter(chapter),
              manager: manager,
              playbackBook: playbackBook,
              onPlay: () => unawaited(
                _playBookFromDownloads(context, ref, group, chapter: chapter),
              ),
            ),
        ],
      );
    }

    if (DesktopLayout.isActive(context)) {
      return _DesktopDownloadBookTile(
        group: group,
        manager: manager,
        listeningProgress: listeningProgress,
        isCurrentBook: isCurrentBook,
        playbackState: playbackState,
        onPlay: () => unawaited(_playBookFromDownloads(context, ref, group)),
        onInfo: () => _openSourceBook(context, group.playbackBook),
        chapters: [
          for (final chapter in group.playbackBook.chapters)
            _DownloadChapterRow(
              chapter: chapter,
              task: group.taskForChapter(chapter),
              manager: manager,
              playbackBook: playbackBook,
              onPlay: () => unawaited(
                _playBookFromDownloads(context, ref, group, chapter: chapter),
              ),
            ),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(
              title: displayTitle,
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
                    displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (playbackBook.isFragment) const BookFragmentBadge(),
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
                  if (group.tasks.any(_isSourceDownloadDisabled)) ...[
                    const SizedBox(height: 8),
                    _DownloadPolicyMessage(
                      key: ValueKey(
                        'download-policy-book-${playbackBook.sourceId}-${playbackBook.versionId}',
                      ),
                    ),
                  ],
                  if (!group.hasMetadata) ...[
                    const SizedBox(height: 8),
                    _DownloadMetadataMessage(book: playbackBook),
                  ],
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

class _TelevisionDownloadBookTile extends StatelessWidget {
  const _TelevisionDownloadBookTile({
    required this.group,
    required this.manager,
    required this.playbackState,
    required this.isCurrentBook,
    required this.onPlay,
    required this.onInfo,
    required this.chapters,
  });

  final _DownloadBookGroup group;
  final DownloadManager manager;
  final AudioPlaybackState playbackState;
  final bool isCurrentBook;
  final VoidCallback onPlay;
  final VoidCallback onInfo;
  final List<Widget> chapters;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final book = group.playbackBook;
    final key = '${book.sourceId}:${book.versionId}';
    return TelevisionFocusFrame(
      key: ValueKey('tv-download-book-$key'),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                    title: book.title,
                    imageUrl: book.coverUrl,
                    width: 64,
                    height: 96,
                    showProgressPercent: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.hasMetadata
                              ? book.title
                              : strings.downloadMetadataUnavailableTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (book.isFragment) const BookFragmentBadge(),
                        if (book.author.isNotEmpty)
                          Text(
                            book.author,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        if (book.narrator.isNotEmpty)
                          Text(
                            book.narrator,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          strings.sourceDisplayName(book.sourceId),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: sourceColorForId(
                              book.sourceId,
                              theme.colorScheme,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_statusLabel(strings, group.displayStatus)} · '
                    '${_groupSizeLabel(context, group)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (group.tasks.any(_isSourceDownloadDisabled))
                    _DownloadPolicyMessage(
                      key: ValueKey(
                        'download-policy-book-${book.sourceId}-${book.versionId}',
                      ),
                    ),
                  if (!group.hasMetadata) _DownloadMetadataMessage(book: book),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: group.progress,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 6),
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
                    onPlay: onPlay,
                    onInfo: onInfo,
                  ),
                ],
              ),
            ),
            ExpansionTile(
              key: PageStorageKey('tv-download-chapters-$key'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              title: Text(
                strings.downloadChaptersProgress(
                  group.completedCount,
                  group.totalChapterCount,
                ),
                style: theme.textTheme.bodySmall,
              ),
              children: chapters,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopDownloadBookTile extends StatelessWidget {
  const _DesktopDownloadBookTile({
    required this.group,
    required this.manager,
    required this.listeningProgress,
    required this.isCurrentBook,
    required this.playbackState,
    required this.onPlay,
    required this.onInfo,
    required this.chapters,
  });

  final _DownloadBookGroup group;
  final DownloadManager manager;
  final double listeningProgress;
  final bool isCurrentBook;
  final AudioPlaybackState playbackState;
  final VoidCallback onPlay;
  final VoidCallback onInfo;
  final List<Widget> chapters;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final book = group.playbackBook;
    final preferences = DesktopPreferences.maybeOf(context);
    final compact = preferences?.compactCards ?? false;
    final showPercent = preferences?.showPercentOnCovers ?? true;
    final coverWidth = compact ? 72.0 : 88.0;
    final bookKey = '${book.sourceId}:${book.versionId}';
    final title = Text(
      group.hasMetadata ? book.title : strings.downloadMetadataUnavailableTitle,
      key: ValueKey('desktop-download-title-$bookKey'),
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
    Widget metadata({bool condensed = false}) => Row(
      key: ValueKey('desktop-download-metadata-$bookKey'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookCover(
          title: group.hasMetadata
              ? book.title
              : strings.downloadMetadataUnavailableTitle,
          imageUrl: book.coverUrl,
          width: condensed ? 56 : coverWidth,
          height: (condensed ? 56 : coverWidth) * 1.43,
          // The listening percentage belongs to the metadata at desktop text
          // sizes; do not squeeze enlarged text into the fixed-size artwork.
          showProgressPercent: false,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!condensed) title,
              if (book.isFragment) ...[
                const SizedBox(height: 6),
                const BookFragmentBadge(),
              ],
              for (final person in [
                if (!condensed)
                  (AppIconAssets.bookAuthor, _shortPeopleLabel(book.author)),
                (AppIconAssets.bookNarrator, _shortPeopleLabel(book.narrator)),
                if (!condensed)
                  (AppIconAssets.bookSeries, _trimOrNull(book.seriesTitle)),
              ])
                if (person.$2 != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _DesktopDownloadMeta(
                      iconAsset: person.$1,
                      label: person.$2!,
                    ),
                  ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (preferences?.showSourceOnCards ?? true)
                    Text(
                      strings.sourceDisplayName(book.sourceId),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: sourceColorForId(book.sourceId, scheme),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (book.totalDuration > Duration.zero)
                    Text(
                      _formatDuration(book.totalDuration),
                      style: theme.textTheme.labelMedium,
                    ),
                  if (!condensed && book.publishedYear != null)
                    Text(
                      '${book.publishedYear}',
                      style: theme.textTheme.labelMedium,
                    ),
                  if (!condensed && _ratingLabel(book.ratingValue) != null)
                    Text(
                      _ratingLabel(book.ratingValue)!,
                      style: theme.textTheme.labelMedium,
                    ),
                  if (showPercent && listeningProgress > 0)
                    Text(
                      '${strings.bookProgress}: '
                      '${(listeningProgress.clamp(0, 1) * 100).round()}%',
                      key: ValueKey('desktop-download-listening-$bookKey'),
                      style: theme.textTheme.labelMedium,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final transfer = Column(
      key: ValueKey('desktop-download-transfer-$bookKey'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DesktopDownloadMeta(
          iconAsset: _statusIcon(group.displayStatus),
          label: _statusLabel(strings, group.displayStatus),
          foreground: group.displayStatus == DownloadTaskStatus.failed
              ? scheme.error
              : scheme.primary,
        ),
        if (group.tasks.any(_isSourceDownloadDisabled)) ...[
          const SizedBox(height: 8),
          _DownloadPolicyMessage(
            key: ValueKey(
              'download-policy-book-${book.sourceId}-${book.versionId}',
            ),
          ),
        ],
        if (!group.hasMetadata) ...[
          const SizedBox(height: 8),
          _DownloadMetadataMessage(book: book),
        ],
        const SizedBox(height: 8),
        LinearProgressIndicator(
          key: ValueKey('desktop-download-progress-$bookKey'),
          value: group.progress,
          minHeight: 6,
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
                  playbackState.status == AudioPlaybackStatus.buffering),
          onPlay: onPlay,
          onInfo: onInfo,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              strings.downloadChaptersProgress(
                group.completedCount,
                group.totalChapterCount,
              ),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              _groupSizeLabel(context, group),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
    return Card(
      key: ValueKey('desktop-download-book-$bookKey'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('desktop-download-expansion-$bookKey'),
        tilePadding: EdgeInsets.all(compact ? 14 : 20),
        childrenPadding: EdgeInsets.fromLTRB(
          compact ? 14 : 20,
          0,
          compact ? 14 : 20,
          compact ? 14 : 20,
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final transferWidth = 260.0 * scale.clamp(1.0, 1.8);
            final metadataMinimum = coverWidth + 16 + 280 * scale;
            if (MediaQuery.sizeOf(context).height < 700 ||
                constraints.maxWidth < metadataMinimum + transferWidth + 32) {
              return Column(
                key: ValueKey('desktop-download-compact-$bookKey'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 12),
                  transfer,
                  const SizedBox(height: 12),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 8),
                  metadata(condensed: true),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: metadata()),
                const SizedBox(width: 32),
                SizedBox(width: transferWidth, child: transfer),
              ],
            );
          },
        ),
        children: chapters,
      ),
    );
  }
}

class _DesktopDownloadMeta extends StatelessWidget {
  const _DesktopDownloadMeta({
    required this.iconAsset,
    required this.label,
    this.foreground,
  });

  final String iconAsset;
  final String label;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final color = foreground ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppIcon(iconAsset, size: 16, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
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
        Flexible(
          child: Text(
            label,
            style: color == null
                ? null
                : TextStyle(color: foreground, fontWeight: FontWeight.w800),
          ),
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
    final television = TelevisionLayout.isActive(context);
    final buttonSize = television ? 40.0 : 48.0;
    final playButton = isPlaybackLoading
        ? SizedBox.square(
            dimension: buttonSize,
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
        : AppIconActionButton(
            buttonSize: buttonSize,
            tooltip: isCurrentBook && isPlaying ? strings.pause : strings.play,
            iconAsset: isCurrentBook && isPlaying
                ? AppIconAssets.playerPause
                : AppIconAssets.playerPlay,
            onPressed: group.hasMetadata ? onPlay : null,
            foregroundColor: isCurrentBook ? colorScheme.primary : null,
          );

    return Wrap(
      key: ValueKey(
        '${television ? 'tv' : 'mobile'}-download-actions-${group.playbackBook.versionId}',
      ),
      spacing: television ? 6 : 8,
      runSpacing: television ? 6 : 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Remote traversal should enter on listening, not destructive delete.
        if (television) playButton,
        if (status == DownloadTaskStatus.running ||
            status == DownloadTaskStatus.queued) ...[
          AppIconActionButton(
            buttonSize: buttonSize,
            tooltip: strings.pauseDownload,
            iconAsset: AppIconAssets.pauseDownload,
            onPressed: () => _pauseBook(group, manager),
          ),
          DownloadActionButton(
            size: buttonSize,
            state: _bookDownloadState(status),
            progress: group.progress,
            onPressed: () => manager.cancelAndDeleteBook(group.playbackBook),
          ),
        ] else ...[
          DownloadActionButton(
            size: buttonSize,
            state: _bookDownloadState(status),
            progress: group.progress,
            onPressed:
                group.hasMetadata || status == DownloadTaskStatus.completed
                ? () => _runPrimary(group, manager)
                : null,
          ),
          if (status != DownloadTaskStatus.completed) ...[
            AppIconActionButton(
              buttonSize: buttonSize,
              tooltip: strings.deleteDownloaded,
              iconAsset: AppIconAssets.deleteDownload,
              onPressed: () => manager.cancelAndDeleteBook(group.playbackBook),
            ),
          ],
        ],
        if (!television) playButton,
        AppIconActionButton(
          buttonSize: buttonSize,
          tooltip: strings.bookDetails,
          iconAsset: AppIconAssets.systemInfo,
          onPressed: group.hasMetadata ? onInfo : null,
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
    final task = this.task;
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
                        if (task != null &&
                            _isSourceDownloadDisabled(task)) ...[
                          const SizedBox(height: 4),
                          _DownloadPolicyMessage(
                            key: ValueKey('download-policy-task-${task.id}'),
                          ),
                        ],
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

bool _isSourceDownloadDisabled(DownloadTask task) =>
    task.errorCode == 'source_download_disabled';

/// Display only the stable policy category, never transport text or payloads.
class _DownloadPolicyMessage extends StatelessWidget {
  const _DownloadPolicyMessage({super.key});
  @override
  Widget build(BuildContext context) => Text(
    context.strings.sourceDownloadDisabled,
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
  );
}

class _DownloadMetadataMessage extends StatelessWidget {
  const _DownloadMetadataMessage({required this.book});
  final AudioPlaybackBook book;
  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey(
      'download-metadata-unavailable-${book.sourceId}-${book.versionId}',
    ),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.strings.downloadMetadataUnavailable,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: () => context.go('/search'),
        icon: const AppIcon(AppIconAssets.navSearch),
        label: Text(context.strings.openSearch),
      ),
    ],
  );
}

class _DownloadBookGroup {
  const _DownloadBookGroup({
    required this.playbackBook,
    required this.tasks,
    required this.hasMetadata,
  });

  final AudioPlaybackBook playbackBook;
  final List<DownloadTask> tasks;
  final bool hasMetadata;

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
    final attachedBook = _attachedBookForTasks(manager, groupTasks);
    final playbackBook = attachedBook ?? _fallbackPlaybackBook(firstTask);
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
        hasMetadata: attachedBook != null,
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
    final currentBook = playbackController.state.book;
    if (_playbackMatchesBook(currentBook, group.playbackBook)) {
      if (chapter == null) {
        await playbackController.togglePlayPause();
      } else {
        final chapterIndex = _chapterIndex(currentBook!, chapter);
        if (chapterIndex == playbackController.state.chapterIndex) {
          await playbackController.togglePlayPause();
        } else {
          await playbackController.playChapterAt(chapterIndex);
        }
      }
      return;
    }

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
  if (task?.status == DownloadTaskStatus.completed ||
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
