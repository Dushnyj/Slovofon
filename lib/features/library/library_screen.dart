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
import '../../services/sources/source_catalog_provider.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/state_placeholder.dart';
import '../../ui/icons/app_icons.dart';
import '../../sources/sources.dart';
import '../shared/download_ui_state.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _selectedShelf = 0;
  final _playLoadingKeys = <String>{};
  final _downloadLoadingKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final libraryStore = ref.watch(libraryStoreProvider);
    final playbackController = ref.watch(playbackControllerProvider);
    final downloadManager = ref.watch(downloadManagerProvider);
    final shelves = [
      strings.all,
      strings.listening,
      strings.favorites,
      strings.later,
      strings.downloaded,
      strings.finished,
      strings.bookmarks,
      strings.history,
    ];
    final selected = shelves[_selectedShelf];
    final entries = _entriesForShelf(strings, selected, libraryStore);

    return ListenableBuilder(
      listenable: playbackController,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(strings.library)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < shelves.length; index++)
                  ChoiceChip(
                    selected: index == _selectedShelf,
                    label: Text(shelves[index]),
                    onSelected: (_) => setState(() => _selectedShelf = index),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: selected,
              subtitle: strings.booksCount(entries.length),
            ),
            if (entries.isEmpty) ...[
              StatePlaceholder.empty(
                title: strings.emptyLibrary,
                message: strings.libraryIzibMessage,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.center,
                child: FilledButton.icon(
                  onPressed: () => context.go('/search'),
                  icon: const AppIcon(AppIconAssets.navSearch),
                  label: Text(strings.openSearch),
                ),
              ),
            ] else
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LibraryBookCard(
                    entry: entry,
                    playbackController: playbackController,
                    downloadManager: downloadManager,
                    isPlayLoading: _playLoadingKeys.contains(
                      _bookKey(entry.book),
                    ),
                    isDownloadLoading: _downloadLoadingKeys.contains(
                      _bookKey(entry.book),
                    ),
                    onPlay: () => _playEntry(entry.book),
                    onDownload: () => _downloadEntry(entry.book),
                    onFavoritePressed: () => ref
                        .read(libraryStoreProvider)
                        .toggleFavorite(entry.book),
                    onTap: () => _openSourceBook(context, entry.book),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  List<LibraryBookEntry> _entriesForShelf(
    AppStrings strings,
    String selected,
    LibraryStore libraryStore,
  ) {
    if (selected == strings.favorites || selected == strings.all) {
      return libraryStore.favorites;
    }
    return const [];
  }

  Future<void> _playEntry(AudioBook book) async {
    final key = _bookKey(book);
    final playbackController = ref.read(playbackControllerProvider);
    if (_playbackMatchesBook(playbackController.state.book, book)) {
      await playbackController.togglePlayPause();
      return;
    }

    if (_playLoadingKeys.contains(key)) {
      return;
    }

    setState(() => _playLoadingKeys.add(key));
    try {
      final playbackBook = await _loadPlaybackBook(book);
      if (playbackBook != null) {
        await playbackController.loadBook(playbackBook, autoPlay: true);
      }
    } finally {
      if (mounted) {
        setState(() => _playLoadingKeys.remove(key));
      }
    }
  }

  Future<void> _downloadEntry(AudioBook book) async {
    final key = _bookKey(book);
    if (_downloadLoadingKeys.contains(key)) {
      return;
    }

    final downloadManager = ref.read(downloadManagerProvider);
    final existingBook = _downloadBookForAudioBook(downloadManager, book);
    if (existingBook != null &&
        downloadStateForBook(downloadManager, existingBook) !=
            BookCardDownloadState.none) {
      await runBookCardDownloadAction(downloadManager, existingBook);
      return;
    }

    setState(() => _downloadLoadingKeys.add(key));
    try {
      final playbackBook = await _loadPlaybackBook(book);
      if (playbackBook != null) {
        await runBookCardDownloadAction(downloadManager, playbackBook);
      }
    } finally {
      if (mounted) {
        setState(() => _downloadLoadingKeys.remove(key));
      }
    }
  }

  Future<AudioPlaybackBook?> _loadPlaybackBook(AudioBook book) async {
    final sourceBookId = book.sourceBookId;
    if (sourceBookId == null || sourceBookId.isEmpty) {
      return null;
    }
    final snapshot = await ref
        .read(sourceCatalogServiceProvider)
        .loadBook(
          SourceBookRef(sourceId: book.sourceId, sourceBookId: sourceBookId),
        );
    return snapshot.playbackBook;
  }

  void _openSourceBook(BuildContext context, AudioBook book) {
    final sourceBookId = book.sourceBookId;
    if (sourceBookId == null || sourceBookId.isEmpty) {
      return;
    }
    unawaited(context.push('/source-book/${book.sourceId}/$sourceBookId'));
  }
}

class _LibraryBookCard extends StatelessWidget {
  const _LibraryBookCard({
    required this.entry,
    required this.playbackController,
    required this.downloadManager,
    required this.isPlayLoading,
    required this.isDownloadLoading,
    required this.onPlay,
    required this.onDownload,
    required this.onFavoritePressed,
    required this.onTap,
  });

  final LibraryBookEntry entry;
  final PlaybackController playbackController;
  final DownloadManager downloadManager;
  final bool isPlayLoading;
  final bool isDownloadLoading;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onFavoritePressed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = playbackController.state;
    final book = entry.book;
    final isCurrentBook = _playbackMatchesBook(state.book, book);
    final downloadBook = _downloadBookForAudioBook(downloadManager, book);

    return BookCard(
      book: book,
      yearLabel: book.year?.toString(),
      isFavorite: entry.isFavorite,
      isCurrentBook: isCurrentBook,
      isPlaying: state.isPlaying,
      isPlaybackLoading:
          isCurrentBook &&
          (state.status == AudioPlaybackStatus.loading ||
              state.status == AudioPlaybackStatus.buffering),
      isPlayLoading: isPlayLoading,
      isDownloadLoading: isDownloadLoading,
      downloadState: downloadBook == null
          ? BookCardDownloadState.none
          : downloadStateForBook(downloadManager, downloadBook),
      downloadProgress: downloadBook == null
          ? 0
          : downloadProgressForBook(downloadManager, downloadBook),
      onPlay: onPlay,
      onDownloadPressed: onDownload,
      onFavoritePressed: onFavoritePressed,
      onTap: onTap,
    );
  }
}

String _bookKey(AudioBook book) {
  return '${book.sourceId}:${book.sourceBookId ?? book.id}';
}

bool _playbackMatchesBook(AudioPlaybackBook? playbackBook, AudioBook book) {
  if (playbackBook == null || playbackBook.sourceId != book.sourceId) {
    return false;
  }

  return playbackBook.sourceBookId == book.sourceBookId ||
      playbackBook.id == book.id ||
      playbackBook.versionId == book.sourceBookId;
}

AudioPlaybackBook? _downloadBookForAudioBook(
  DownloadManager manager,
  AudioBook book,
) {
  for (final task in manager.tasks) {
    final taskBook = manager.bookForTask(task.id);
    if (_playbackMatchesBook(taskBook, book)) {
      return taskBook;
    }
  }
  return null;
}
