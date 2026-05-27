import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/library/library_store.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final playbackController = ref.watch(playbackControllerProvider);
    final downloadManager = ref.watch(downloadManagerProvider);
    final libraryStore = ref.watch(libraryStoreProvider);

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
                  final book = state.book;

                  if (book == null) {
                    return _SourceSearchCard(strings: strings);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: strings.continueListening,
                        subtitle: book.sourceName,
                      ),
                      _ActiveBookCard(
                        book: book,
                        state: state,
                        playbackController: playbackController,
                        downloadManager: downloadManager,
                        libraryStore: libraryStore,
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

class _ActiveBookCard extends StatelessWidget {
  const _ActiveBookCard({
    required this.book,
    required this.state,
    required this.playbackController,
    required this.downloadManager,
    required this.libraryStore,
  });

  final AudioPlaybackBook book;
  final AudioPlaybackState state;
  final PlaybackController playbackController;
  final DownloadManager downloadManager;
  final LibraryStore libraryStore;

  @override
  Widget build(BuildContext context) {
    final audioBook = _audioBookForPlayback(book, state.bookProgress);
    return BookCard(
      book: audioBook,
      yearLabel: book.publishedYear?.toString(),
      isFavorite: libraryStore.isFavorite(audioBook),
      isCurrentBook: true,
      isPlaying: state.isPlaying,
      isPlaybackLoading:
          state.status == AudioPlaybackStatus.loading ||
          state.status == AudioPlaybackStatus.buffering,
      downloadState: downloadStateForBook(downloadManager, book),
      downloadProgress: downloadProgressForBook(downloadManager, book),
      onFavoritePressed: () => libraryStore.toggleFavorite(audioBook),
      onDownloadPressed: () => runBookCardDownloadAction(downloadManager, book),
      onPlay: () async {
        await playbackController.togglePlayPause();
        if (context.mounted) {
          await context.push('/player');
        }
      },
      onTap: () => _openBook(context, book),
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
    year: book.publishedYear,
  );
}

void _openBook(BuildContext context, AudioPlaybackBook book) {
  final sourceBookId = book.sourceBookId;
  if (sourceBookId != null && sourceBookId.isNotEmpty) {
    unawaited(context.push('/source-book/${book.sourceId}/$sourceBookId'));
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
