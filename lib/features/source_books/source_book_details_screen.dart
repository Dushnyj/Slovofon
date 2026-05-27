import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/book_version.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/sources/source_catalog_provider.dart';
import '../../services/sources/source_catalog_service.dart';
import '../../sources/sources.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/chapter_tile.dart';
import '../../ui/components/app_buttons.dart';
import '../../ui/components/download_action_button.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';

class SourceBookDetailsScreen extends ConsumerStatefulWidget {
  const SourceBookDetailsScreen({required this.ref, super.key});

  final SourceBookRef ref;

  @override
  ConsumerState<SourceBookDetailsScreen> createState() {
    return _SourceBookDetailsScreenState();
  }
}

class _SourceBookDetailsScreenState
    extends ConsumerState<SourceBookDetailsScreen> {
  late Future<SourceBookSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = ref
        .read(sourceCatalogServiceProvider)
        .loadBook(widget.ref);
  }

  @override
  void didUpdateWidget(SourceBookDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ref != widget.ref) {
      _snapshotFuture = ref
          .read(sourceCatalogServiceProvider)
          .loadBook(widget.ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 450) {
          unawaited(Navigator.of(context).maybePop());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(strings.bookDetails)),
        body: SafeArea(
          top: false,
          child: FutureBuilder<SourceBookSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _DetailsError(message: snapshot.error.toString());
              }

              final book = snapshot.data!;
              return _SourceBookDetailsBody(snapshot: book);
            },
          ),
        ),
      ),
    );
  }
}

class _SourceBookDetailsBody extends ConsumerStatefulWidget {
  const _SourceBookDetailsBody({required this.snapshot});

  final SourceBookSnapshot snapshot;

  @override
  ConsumerState<_SourceBookDetailsBody> createState() {
    return _SourceBookDetailsBodyState();
  }
}

class _SourceBookDetailsBodyState
    extends ConsumerState<_SourceBookDetailsBody> {
  static const _collapsedChapterCount = 5;

  bool _showAllChapters = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final downloadManager = ref.watch(downloadManagerProvider);
    final snapshot = widget.snapshot;
    final details = snapshot.details;
    final version = details.version;
    final playbackBook = snapshot.playbackBook;
    final bookDownloadState = downloadStateForBook(
      downloadManager,
      playbackBook,
    );
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final visibleChapterCount =
        _showAllChapters || snapshot.chapters.length <= _collapsedChapterCount
        ? snapshot.chapters.length
        : _collapsedChapterCount;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + bottomInset),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final cover = BookCover(
              title: version.title,
              imageUrl: version.coverUrl,
              width: compact ? 112 : 148,
              height: compact ? 156 : 206,
            );
            final header = _SourceHeaderDetails(snapshot: snapshot);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cover,
                SizedBox(width: compact ? 16 : 24),
                Expanded(child: header),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppIconActionButton(
              tooltip: strings.play,
              onPressed: () => _play(context, ref, 0),
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
        ),
        if ((version.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            version.description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        SectionHeader(title: strings.chapters),
        for (var index = 0; index < visibleChapterCount; index++)
          Builder(
            builder: (context) {
              final sourceChapter = snapshot.chapters[index];
              final audioChapter = playbackBook.chapters[index];
              return ChapterTile(
                index: sourceChapter.index,
                title: sourceChapter.title,
                durationLabel: _formatShortDuration(
                  Duration(milliseconds: sourceChapter.durationMs ?? 0),
                ),
                progress: 0,
                isDownloaded: isChapterDownloaded(
                  downloadManager,
                  audioChapter,
                ),
                downloadState: downloadStateForChapter(
                  downloadManager,
                  audioChapter,
                ),
                downloadProgress: downloadProgressForChapter(
                  downloadManager,
                  audioChapter,
                ),
                isCurrent: index == 0,
                onTap: () => _play(context, ref, index),
                onDownloadPressed: () => runChapterCardDownloadAction(
                  downloadManager,
                  playbackBook,
                  audioChapter,
                ),
              );
            },
          ),
        if (snapshot.chapters.length > _collapsedChapterCount)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _showAllChapters = !_showAllChapters);
              },
              icon: AppIcon(
                _showAllChapters
                    ? AppIconAssets.systemClose
                    : AppIconAssets.systemMore,
                size: 18,
              ),
              label: Text(
                _showAllChapters
                    ? strings.collapseChapters
                    : strings.showMoreChapters(
                        snapshot.chapters.length - _collapsedChapterCount,
                      ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        SectionHeader(title: strings.otherVersions),
        Card(
          child: ListTile(
            leading: const AppIcon(AppIconAssets.bookSource),
            title: Text(
              '${playbackBook.sourceName} · ${playbackBook.narrator}',
            ),
            subtitle: Text(
              '${snapshot.audioBook.durationLabel} · ${_accessLabel(context, version.accessType)}',
            ),
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(title: strings.information),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoPill(label: playbackBook.sourceName),
            if (playbackBook.genre != null)
              _InfoPill(label: playbackBook.genre!),
            if (playbackBook.publishedYear != null)
              _InfoPill(label: '${playbackBook.publishedYear}'),
            if (version.seriesTitle != null)
              _InfoPill(label: version.seriesTitle!),
            _InfoPill(label: _downloadStateLabel(context, bookDownloadState)),
          ],
        ),
      ],
    );
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    int chapterIndex,
  ) async {
    final playback = ref.read(playbackControllerProvider);
    await playback.loadBook(
      widget.snapshot.playbackBook,
      chapterIndex: chapterIndex,
      autoPlay: true,
    );
    if (context.mounted) {
      await context.push('/player');
    }
  }
}

String _downloadStateLabel(BuildContext context, BookCardDownloadState state) {
  final strings = context.strings;
  return switch (state) {
    BookCardDownloadState.downloaded => strings.downloaded,
    BookCardDownloadState.downloading => strings.downloading,
    BookCardDownloadState.queued => strings.queued,
    BookCardDownloadState.paused => strings.paused,
    BookCardDownloadState.failed => strings.failed,
    BookCardDownloadState.none => strings.download,
  };
}

class _SourceHeaderDetails extends StatelessWidget {
  const _SourceHeaderDetails({required this.snapshot});

  final SourceBookSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final version = snapshot.details.version;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          version.title,
          style: Theme.of(context).textTheme.headlineSmall,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          version.authors.join(', '),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${version.narrators.join(', ')} · ${snapshot.audioBook.durationLabel}',
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: 0,
          minHeight: 6,
          borderRadius: BorderRadius.circular(999),
        ),
        const SizedBox(height: 8),
        Text(
          '${snapshot.chapters.length} глав · ${snapshot.playbackBook.sourceName}',
        ),
      ],
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
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

String _formatShortDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (duration.inHours > 0) {
    return '${duration.inHours} ч ${minutes.remainder(60)} мин';
  }
  return '$minutes мин';
}

String _accessLabel(BuildContext context, AccessType accessType) {
  final strings = context.strings;
  return switch (accessType) {
    AccessType.free => strings.free,
    AccessType.paid => strings.paid,
    AccessType.subscription => strings.subscription,
    AccessType.unknown => strings.unknown,
  };
}
