import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';
import '../../services/audio/audio_persistence.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/home/home_listening_visibility_store.dart';
import '../../services/library/library_store.dart';
import '../../ui/adaptive/desktop_layout.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/responsive_tile_grid.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';
import '../shared/playback_resume.dart';

final _homeListeningHistoryProvider =
    FutureProvider<List<_StoredListeningEntry>>((ref) async {
      final storage = ref.watch(downloadStorageProvider);
      final progressSnapshots = await ref.watch(
        playbackProgressSnapshotsProvider.future,
      );
      if (progressSnapshots.isEmpty) {
        return const [];
      }

      final books = await storage.readAllMetadata();
      final booksByVersionId = {for (final book in books) book.versionId: book};

      final entries = <_StoredListeningEntry>[];
      for (final progress in progressSnapshots) {
        final book = booksByVersionId[progress.bookVersionId];
        if (book == null) {
          continue;
        }
        entries.add(_StoredListeningEntry(book: book, progress: progress));
      }
      return entries;
    });

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final desktop = DesktopLayout.isActive(context);
    final playbackController = ref.watch(playbackControllerProvider);
    final downloadManager = ref.watch(downloadManagerProvider);
    final libraryStore = ref.watch(libraryStoreProvider);
    final history = ref.watch(_homeListeningHistoryProvider);
    final visibilityStore = ref.watch(homeListeningVisibilityStoreProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: desktop
              ? DesktopLayout.pagePadding(context)
              : const EdgeInsets.fromLTRB(16, 18, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (desktop) DesktopPageHeader(title: strings.home),
              ListenableBuilder(
                listenable: playbackController,
                builder: (context, _) {
                  final state = playbackController.state;
                  final entries = _homeEntries(
                    state: state,
                    storedEntries:
                        history.asData?.value ??
                        const <_StoredListeningEntry>[],
                    visibilityStore: visibilityStore,
                  );

                  if (entries.isEmpty) {
                    final prompt = _SourceSearchCard(strings: strings);
                    return desktop
                        ? DesktopWorkspaceColumns(
                            key: const ValueKey('desktop-home-workspace'),
                            primary: KeyedSubtree(
                              key: const ValueKey('desktop-home-search-prompt'),
                              child: prompt,
                            ),
                            secondary: const _HomeCollectionLinks(),
                          )
                        : prompt;
                  }

                  Widget historyCard(
                    _HomeListeningEntry entry, {
                    DesktopBookPresentation presentation =
                        DesktopBookPresentation.card,
                  }) => _HistoryBookCard(
                    entry: entry,
                    desktopPresentation: presentation,
                    playbackController: playbackController,
                    downloadManager: downloadManager,
                    libraryStore: libraryStore,
                    visibilityStore: visibilityStore,
                    progressSnapshots:
                        history.asData?.value
                            .map((entry) => entry.progress)
                            .toList() ??
                        const <PlaybackProgressSnapshot>[],
                    onProgressChanged: () {
                      ref.invalidate(playbackProgressSnapshotsProvider);
                      ref.invalidate(_homeListeningHistoryProvider);
                    },
                  );

                  if (desktop) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(title: strings.continueListening),
                        const SizedBox(height: 16),
                        DesktopWorkspaceColumns(
                          key: const ValueKey('desktop-home-workspace'),
                          primary: KeyedSubtree(
                            key: const ValueKey('desktop-home-feature'),
                            child: historyCard(
                              entries.first,
                              presentation: DesktopBookPresentation.feature,
                            ),
                          ),
                          secondary:
                              entries.first.isCurrent &&
                                  state.book!.chapters.isNotEmpty
                              ? _HomeChapterRail(controller: playbackController)
                              : const _HomeCollectionLinks(),
                        ),
                        if (entries.length > 1) ...[
                          const SizedBox(height: 24),
                          SectionHeader(title: strings.startedBooks),
                          const SizedBox(height: 12),
                          for (final entry in entries.skip(1)) ...[
                            historyCard(
                              entry,
                              presentation: DesktopBookPresentation.row,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(title: strings.continueListening),
                      const SizedBox(height: 12),
                      ResponsiveTileGrid(
                        children: [
                          for (final entry in entries) historyCard(entry),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _HistoryBookCard extends StatelessWidget {
  const _HistoryBookCard({
    required this.entry,
    required this.playbackController,
    required this.downloadManager,
    required this.libraryStore,
    required this.visibilityStore,
    required this.progressSnapshots,
    required this.onProgressChanged,
    this.desktopPresentation = DesktopBookPresentation.card,
  });

  final _HomeListeningEntry entry;
  final PlaybackController playbackController;
  final DownloadManager downloadManager;
  final LibraryStore libraryStore;
  final HomeListeningVisibilityStore visibilityStore;
  final List<PlaybackProgressSnapshot> progressSnapshots;
  final VoidCallback onProgressChanged;
  final DesktopBookPresentation desktopPresentation;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final book = entry.book;
    final audioBook = _audioBookForPlayback(book, entry.progressValue);

    return Dismissible(
      key: ValueKey('home-history-${entry.key}'),
      direction: DismissDirection.endToStart,
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 18),
            child: AppIcon(
              AppIconAssets.systemTrash,
              color: colorScheme.onErrorContainer,
              size: 28,
            ),
          ),
        ),
      ),
      onDismissed: (_) {
        unawaited(visibilityStore.hide(entry.key));
      },
      child: BookCard(
        book: audioBook,
        desktopPresentation: desktopPresentation,
        yearLabel: book.publishedYear?.toString(),
        isFavorite: libraryStore.isFavorite(audioBook),
        isLater: libraryStore.isLater(audioBook),
        onLaterPressed: () async {
          try {
            await libraryStore.toggleLater(audioBook);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.strings.libraryActionError)),
              );
            }
          }
        },
        isCurrentBook: entry.isCurrent,
        isPlaying: entry.isPlaying,
        isPlaybackLoading: entry.isPlaybackLoading,
        downloadState: downloadStateForBook(downloadManager, book),
        downloadProgress: downloadProgressForBook(downloadManager, book),
        onFavoritePressed: () => libraryStore.toggleFavorite(audioBook),
        onDownloadPressed: () =>
            runBookCardDownloadAction(downloadManager, book),
        onPlay: () async {
          if (entry.isCurrent) {
            await playbackController.togglePlayPause();
          } else {
            final playbackBook = await downloadManager.offlinePlaybackBook(
              book,
            );
            final resumePoint = playbackResumePointForBook(
              playbackBook,
              progressSnapshots,
            );
            await playbackController.loadBook(
              playbackBook,
              chapterIndex: resumePoint.chapterIndex,
              position: resumePoint.position,
              autoPlay: true,
            );
            await visibilityStore.show(entry.key);
            onProgressChanged();
          }
          if (context.mounted) {
            await context.push('/player');
          }
        },
        onTap: () => _openBook(context, book),
      ),
    );
  }
}

class _HomeChapterRail extends StatelessWidget {
  const _HomeChapterRail({required this.controller});
  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final state = controller.state;
    final book = state.book!;
    final start = state.chapterIndex.clamp(0, book.chapters.length - 1);
    final chapters = book.chapters.skip(start).take(3).toList();
    return Card(
      key: const ValueKey('desktop-home-chapter-rail'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.currentAndNextChapters,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.chapterPosition(start + 1, book.chapters.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < chapters.length; index++) ...[
              Material(
                color: index == 0
                    ? theme.colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  key: ValueKey('home-chapter-${chapters[index].id}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  title: Text(
                    chapters[index].title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: index == 0
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      index == 0
                          ? '${state.isPlaying ? strings.nowPlaying : strings.paused} · ${_formatDuration(chapters[index].duration)}'
                          : _formatDuration(chapters[index].duration),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: index == 0
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  onTap: () =>
                      unawaited(controller.playChapterAt(start + index)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => context.push('/player?tab=chapters'),
              icon: const AppIcon(AppIconAssets.playerChapters, size: 18),
              label: Text(strings.allChapters),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCollectionLinks extends StatelessWidget {
  const _HomeCollectionLinks();
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Card(
      key: const ValueKey('desktop-home-collection-links'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              leading: const AppIcon(AppIconAssets.navLibrary),
              title: Text(strings.library),
              subtitle: Text(strings.homeLibraryShortcutMessage),
              onTap: () => context.go('/library'),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const AppIcon(AppIconAssets.navDownloads),
              title: Text(strings.downloads),
              subtitle: Text(strings.homeDownloadsShortcutMessage),
              onTap: () => context.go('/downloads'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceSearchCard extends StatelessWidget {
  const _SourceSearchCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final desktop = DesktopLayout.isActive(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(desktop ? 28 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: const AppIcon(AppIconAssets.navSearch),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.realSourceHomeTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.realSourceHomeMessage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/search'),
              icon: const AppIcon(AppIconAssets.navSearch),
              label: Text(strings.openSearch),
            ),
          ],
        ),
      ),
    );
  }
}

AudioBook _audioBookForPlayback(AudioPlaybackBook book, double progress) {
  return AudioBook(
    id: book.id,
    sourceBookId: book.sourceBookId,
    title: book.title,
    author: book.author,
    narrator: book.narrator,
    sourceId: book.sourceId,
    sourceName: book.sourceName,
    durationLabel: _formatDuration(book.totalDuration),
    chapterCount: book.chapters.length,
    progress: progress,
    access: BookAccess.unknown,
    isFragment: book.isFragment,
    coverUrl: book.coverUrl,
    description: book.description,
    seriesTitle: book.seriesTitle,
    seriesNumber: book.seriesNumber,
    ratingValue: book.ratingValue,
    ratingCount: book.ratingCount,
    year: book.publishedYear,
  );
}

void _openBook(BuildContext context, AudioPlaybackBook book) {
  final sourceBookId = book.sourceBookId;
  if (sourceBookId != null && sourceBookId.isNotEmpty) {
    unawaited(
      context.push(
        '/source-book/${book.sourceId}/${Uri.encodeComponent(sourceBookId)}',
      ),
    );
    return;
  }

  unawaited(context.push('/player'));
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return minutes > 0 ? '$hours ч $minutes мин' : '$hours ч';
  }
  return '$minutes мин';
}

List<_HomeListeningEntry> _homeEntries({
  required AudioPlaybackState state,
  required List<_StoredListeningEntry> storedEntries,
  required HomeListeningVisibilityStore visibilityStore,
}) {
  final entriesByKey = <String, _HomeListeningEntry>{};
  for (final stored in storedEntries) {
    final key = homeListeningBookKeyFor(stored.book);
    if (visibilityStore.isHidden(key)) {
      continue;
    }
    entriesByKey[key] = _HomeListeningEntry.fromStored(stored, key: key);
  }

  final activeBook = state.book;
  if (activeBook != null) {
    final key = homeListeningBookKeyFor(activeBook);
    if (!visibilityStore.isHidden(key)) {
      entriesByKey[key] = _HomeListeningEntry.fromActive(
        book: activeBook,
        state: state,
        key: key,
      );
    }
  }

  final entries = entriesByKey.values.toList();
  entries.sort((left, right) {
    if (left.isCurrent != right.isCurrent) {
      return left.isCurrent ? -1 : 1;
    }
    return right.lastPlayedAt.compareTo(left.lastPlayedAt);
  });
  return entries;
}

class _StoredListeningEntry {
  const _StoredListeningEntry({required this.book, required this.progress});

  final AudioPlaybackBook book;
  final PlaybackProgressSnapshot progress;
}

class _HomeListeningEntry {
  const _HomeListeningEntry({
    required this.book,
    required this.key,
    required this.progressValue,
    required this.lastPlayedAt,
    required this.isCurrent,
    required this.isPlaying,
    required this.isPlaybackLoading,
  });

  factory _HomeListeningEntry.fromStored(
    _StoredListeningEntry stored, {
    required String key,
  }) {
    return _HomeListeningEntry(
      book: stored.book,
      key: key,
      progressValue: (stored.progress.percent / 100).clamp(0, 1).toDouble(),
      lastPlayedAt: stored.progress.lastPlayedAt,
      isCurrent: false,
      isPlaying: false,
      isPlaybackLoading: false,
    );
  }

  factory _HomeListeningEntry.fromActive({
    required AudioPlaybackBook book,
    required AudioPlaybackState state,
    required String key,
  }) {
    return _HomeListeningEntry(
      book: book,
      key: key,
      progressValue: state.bookProgress,
      lastPlayedAt: DateTime.now(),
      isCurrent: true,
      isPlaying: state.isPlaying,
      isPlaybackLoading:
          state.status == AudioPlaybackStatus.loading ||
          state.status == AudioPlaybackStatus.buffering,
    );
  }

  final AudioPlaybackBook book;
  final String key;
  final double progressValue;
  final DateTime lastPlayedAt;
  final bool isCurrent;
  final bool isPlaying;
  final bool isPlaybackLoading;
}
