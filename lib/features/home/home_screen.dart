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
import '../../ui/components/book_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';
import '../shared/playback_resume.dart';

final _homeListeningHistoryProvider =
    FutureProvider<List<_StoredListeningEntry>>((ref) async {
      final persistence = ref.watch(playbackPersistenceStoreProvider);
      final progressSnapshots =
          await persistence?.loadProgress() ??
          const <PlaybackProgressSnapshot>[];
      if (progressSnapshots.isEmpty) {
        return const [];
      }

      final storage = ref.watch(downloadStorageProvider);
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
    final playbackController = ref.watch(playbackControllerProvider);
    final downloadManager = ref.watch(downloadManagerProvider);
    final libraryStore = ref.watch(libraryStoreProvider);
    final history = ref.watch(_homeListeningHistoryProvider);
    final visibilityStore = ref.watch(homeListeningVisibilityStoreProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
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
                    return _SourceSearchCard(strings: strings);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(title: strings.continueListening),
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HistoryBookCard(
                            entry: entry,
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
                          ),
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
  });

  final _HomeListeningEntry entry;
  final PlaybackController playbackController;
  final DownloadManager downloadManager;
  final LibraryStore libraryStore;
  final HomeListeningVisibilityStore visibilityStore;
  final List<PlaybackProgressSnapshot> progressSnapshots;
  final VoidCallback onProgressChanged;

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
        yearLabel: book.publishedYear?.toString(),
        isFavorite: libraryStore.isFavorite(audioBook),
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

class _SourceSearchCard extends StatelessWidget {
  const _SourceSearchCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
