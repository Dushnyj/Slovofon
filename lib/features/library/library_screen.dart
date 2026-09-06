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
import '../../services/library/library_metadata.dart';
import '../../services/library/library_shelves.dart';
import '../../services/bookmarks/bookmark_store.dart';
import '../../services/sources/source_book_cache.dart';
import '../../services/sources/source_catalog_provider.dart';
import '../../services/sources/source_catalog_service.dart';
import '../../ui/components/app_bar_text.dart';
import '../../ui/adaptive/desktop_layout.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/filter_picker_sheet.dart';
import '../../ui/components/responsive_tile_grid.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/state_placeholder.dart';
import '../../ui/icons/app_icons.dart';
import '../../sources/sources.dart';
import '../shared/download_ui_state.dart';
import '../shared/playback_resume.dart';

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
    final desktop = DesktopLayout.isActive(context);
    final libraryStore = ref.watch(libraryStoreProvider);
    final bookmarkStore = ref.watch(bookmarkStoreProvider);
    final playbackController = ref.watch(playbackControllerProvider);
    final downloadManager = ref.watch(downloadManagerProvider);
    final metadata = ref.watch(libraryPlaybackBooksProvider);
    final progress = ref.watch(playbackProgressSnapshotsProvider);
    final progressSnapshots =
        progress.asData?.value ?? const <PlaybackProgressSnapshot>[];
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
    final shelf = LibraryShelf.values[_selectedShelf];

    return ListenableBuilder(
      listenable: playbackController,
      builder: (context, _) {
        final catalog = projectLibraryShelves(
          favorites: libraryStore.favorites,
          later: libraryStore.later,
          metadata: [
            ...?metadata.asData?.value,
            for (final task in downloadManager.tasks)
              if (downloadManager.bookForTask(task.id) != null)
                downloadManager.bookForTask(task.id)!,
          ],
          progress: progressSnapshots,
          downloads: downloadManager.tasks,
          bookmarks: bookmarkStore.entries,
          current: playbackController.state,
        );
        final entries = catalog
            .where((entry) => entry.shelves.contains(shelf))
            .toList();
        final isBookmarks = shelf == LibraryShelf.bookmarks;
        final empty = isBookmarks
            ? bookmarkStore.entries.isEmpty
            : entries.isEmpty;
        final usesMetadata =
            shelf != LibraryShelf.favorites &&
            shelf != LibraryShelf.later &&
            !isBookmarks;
        final failed =
            (isBookmarks
                ? bookmarkStore.error != null
                : libraryStore.error != null ||
                      ((shelf == LibraryShelf.later ||
                              shelf == LibraryShelf.all) &&
                          libraryStore.laterError != null)) ||
            (usesMetadata && (metadata.hasError || progress.hasError));
        final loading =
            !libraryStore.isLoaded ||
            (isBookmarks && !bookmarkStore.isLoaded) ||
            (usesMetadata && (metadata.isLoading || progress.isLoading));
        final count = isBookmarks
            ? bookmarkStore.entries.length
            : entries.length;
        final emptyCopy = _emptyCopy(strings, shelf);
        return Scaffold(
          appBar: desktop
              ? null
              : AppBar(
                  toolbarHeight: appBarToolbarHeight(context),
                  title: preserveAppBarTextScale(
                    context,
                    Text(strings.library),
                  ),
                ),
          body: ListView(
            padding: desktop
                ? DesktopLayout.pagePadding(context)
                : const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (desktop) ...[
                DesktopPageHeader(
                  title: strings.library,
                  trailing: Text(
                    isBookmarks
                        ? '${strings.bookmarks}: $count'
                        : strings.booksCount(count),
                    key: const ValueKey('desktop-library-count'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      key: const ValueKey('desktop-library-shelves'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var index = 0; index < shelves.length; index++)
                          ChoiceChip(
                            label: Text(shelves[index]),
                            selected: index == _selectedShelf,
                            onSelected: (_) =>
                                setState(() => _selectedShelf = index),
                          ),
                      ],
                    ),
                  ),
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    avatar: const AppIcon(AppIconAssets.systemFilter, size: 16),
                    label: Text('${strings.filter}: $selected'),
                    onPressed: () => _pickShelf(context, shelves),
                  ),
                ),
              const SizedBox(height: 16),
              SectionHeader(
                title: selected,
                subtitle: desktop
                    ? null
                    : (isBookmarks ? '$count' : strings.booksCount(count)),
              ),
              if (failed) ...[
                StatePlaceholder.error(title: strings.libraryLoadError),
                Center(
                  child: TextButton(
                    onPressed: () {
                      unawaited(libraryStore.load());
                      unawaited(bookmarkStore.load());
                      ref.invalidate(libraryPlaybackBooksProvider);
                      ref.invalidate(playbackProgressSnapshotsProvider);
                    },
                    child: Text(strings.retry),
                  ),
                ),
              ],
              if (empty && loading && !failed)
                StatePlaceholder.loading(title: strings.library)
              else if (empty && !failed) ...[
                StatePlaceholder.empty(
                  title: emptyCopy.$1,
                  message: emptyCopy.$2,
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
              ] else if (isBookmarks)
                _LibraryCollection(
                  children: [
                    for (final bookmark in bookmarkStore.entries)
                      _LibraryBookmarkTile(
                        bookmark: bookmark,
                        onPlay: () => _jumpToBookmark(bookmark),
                        onRemove: () => _removeBookmark(bookmark),
                      ),
                  ],
                )
              else
                _LibraryCollection(
                  children: [
                    for (final item in entries)
                      _LibraryBookCard(
                        key: ValueKey('library-book-${_bookKey(item.book)}'),
                        entry: item.cardEntry,
                        playbackController: playbackController,
                        downloadManager: downloadManager,
                        isPlayLoading: _playLoadingKeys.contains(
                          _bookKey(item.book),
                        ),
                        isDownloadLoading: _downloadLoadingKeys.contains(
                          _bookKey(item.book),
                        ),
                        isLater: libraryStore.isLater(item.book),
                        onLaterPressed: () => _libraryAction(
                          () => libraryStore.toggleLater(item.book),
                        ),
                        onPlay: () =>
                            _libraryAction(() => _playEntry(item.book)),
                        onDownload: () =>
                            _libraryAction(() => _downloadEntry(item.book)),
                        onFavoritePressed: () => _libraryAction(
                          () => libraryStore.toggleFavorite(item.book),
                        ),
                        onTap: () => _openSourceBook(context, item.book),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  (String, String) _emptyCopy(AppStrings strings, LibraryShelf shelf) =>
      switch (shelf) {
        LibraryShelf.all => (
          strings.emptyLibrary,
          strings.librarySourcesMessage,
        ),
        LibraryShelf.listening => (
          strings.emptyListeningShelf,
          strings.emptyListeningShelfMessage,
        ),
        LibraryShelf.favorites => (
          strings.emptyFavoritesShelf,
          strings.emptyFavoritesShelfMessage,
        ),
        LibraryShelf.later => (
          strings.emptyLaterShelf,
          strings.emptyLaterShelfMessage,
        ),
        LibraryShelf.downloaded => (
          strings.emptyDownloadedShelf,
          strings.emptyDownloadedShelfMessage,
        ),
        LibraryShelf.finished => (
          strings.emptyFinishedShelf,
          strings.emptyFinishedShelfMessage,
        ),
        LibraryShelf.bookmarks => (
          strings.emptyBookmarksShelf,
          strings.emptyBookmarksShelfMessage,
        ),
        LibraryShelf.history => (
          strings.emptyHistoryShelf,
          strings.emptyHistoryShelfMessage,
        ),
      };

  Future<void> _libraryAction(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.libraryActionError)),
        );
      }
    }
  }

  Future<void> _removeBookmark(PlaybackBookmark bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.strings.deleteBookmark),
        content: Text(context.strings.deleteBookmarkDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.deleteBookmarkAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _libraryAction(
        () => ref.read(bookmarkStoreProvider).remove(bookmark.id),
      );
    }
  }

  Future<void> _jumpToBookmark(PlaybackBookmark bookmark) async {
    final controller = ref.read(playbackControllerProvider);
    try {
      var book = controller.state.book?.versionId == bookmark.bookVersionId
          ? controller.state.book
          : bookmark.book;
      if (book == null) throw StateError('Bookmark metadata unavailable');
      if (controller.state.book?.versionId != bookmark.bookVersionId) {
        book = await _loadPlaybackBook(libraryCardBook(book)) ?? book;
        if (!mounted) return;
        final index = book.chapters.indexWhere(
          (c) => c.id == bookmark.chapterId,
        );
        if (index < 0) throw StateError('Bookmark chapter unavailable');
        await controller.loadBook(
          book,
          chapterIndex: index,
          position: Duration(milliseconds: bookmark.positionMs),
          autoPlay: true,
        );
      } else {
        final index = book.chapters.indexWhere(
          (c) => c.id == bookmark.chapterId,
        );
        if (index < 0) throw StateError('Bookmark chapter unavailable');
        await controller.seekChapterAt(
          index,
          Duration(milliseconds: bookmark.positionMs),
        );
      }
      if (mounted) await context.push('/player');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.bookmarkUnavailable)),
        );
      }
    }
  }

  Future<void> _pickShelf(BuildContext context, List<String> shelves) async {
    final next = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var draft = _selectedShelf;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FilterPickerSheet(
              options: [
                RadioGroup<int>(
                  groupValue: draft,
                  onChanged: (value) {
                    if (value != null) {
                      setModalState(() => draft = value);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < shelves.length; index++)
                        RadioListTile<int>(
                          value: index,
                          visualDensity: VisualDensity.compact,
                          title: Text(shelves[index]),
                        ),
                    ],
                  ),
                ),
              ],
              action: FilledButton(
                onPressed: () => Navigator.of(context).pop(draft),
                child: Text(context.strings.apply),
              ),
            );
          },
        );
      },
    );
    if (next != null && mounted) {
      setState(() => _selectedShelf = next);
    }
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
        final progressSnapshots =
            await ref.read(playbackPersistenceStoreProvider)?.loadProgress() ??
            const [];
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
        await ref
            .read(homeListeningVisibilityStoreProvider)
            .show(homeListeningBookKeyFor(playbackBook));
        ref.invalidate(playbackProgressSnapshotsProvider);
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
      final metadata = await ref.read(libraryPlaybackBooksProvider.future);
      for (final cached in metadata) {
        if (cached.id == book.id &&
            cached.sourceId == book.sourceId &&
            cached.chapters.isNotEmpty) {
          return ref.read(downloadManagerProvider).offlinePlaybackBook(cached);
        }
      }
      return null;
    }
    final downloadManager = ref.read(downloadManagerProvider);
    try {
      final snapshot = await ref
          .read(sourceCatalogServiceProvider)
          .loadBook(
            SourceBookRef(sourceId: book.sourceId, sourceBookId: sourceBookId),
          );
      _cacheSnapshot(snapshot);
      return downloadManager.offlinePlaybackBook(snapshot.playbackBook);
    } catch (_) {
      for (final cachedBook
          in await ref.read(downloadStorageProvider).readAllMetadata()) {
        if (cachedBook.sourceId == book.sourceId &&
            cachedBook.sourceBookId == sourceBookId) {
          return downloadManager.offlinePlaybackBook(cachedBook);
        }
      }
      rethrow;
    }
  }

  void _cacheSnapshot(SourceBookSnapshot snapshot) {
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
  }

  void _openSourceBook(BuildContext context, AudioBook book) {
    final sourceBookId = book.sourceBookId;
    if (sourceBookId == null || sourceBookId.isEmpty) {
      unawaited(context.push('/book/${Uri.encodeComponent(book.id)}'));
      return;
    }
    unawaited(
      context.push(
        '/source-book/${book.sourceId}/${Uri.encodeComponent(sourceBookId)}',
      ),
    );
  }
}

class _LibraryCollection extends StatelessWidget {
  const _LibraryCollection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!DesktopLayout.isActive(context)) {
      return ResponsiveTileGrid(children: children);
    }
    return Column(
      key: const ValueKey('desktop-library-rows'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
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
    required this.isLater,
    required this.onLaterPressed,
    required this.onTap,
    super.key,
  });

  final LibraryBookEntry entry;
  final PlaybackController playbackController;
  final DownloadManager downloadManager;
  final bool isPlayLoading;
  final bool isDownloadLoading;
  final VoidCallback onPlay;
  final VoidCallback onDownload;
  final VoidCallback onFavoritePressed;
  final bool isLater;
  final VoidCallback onLaterPressed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = playbackController.state;
    var book = entry.book;
    final isCurrentBook = _playbackMatchesBook(state.book, book);
    if (isCurrentBook && state.bookProgress > book.progress) {
      book = book.copyWith(progress: state.bookProgress);
    }
    final downloadBook = _downloadBookForAudioBook(downloadManager, book);

    return BookCard(
      book: book,
      desktopPresentation: DesktopLayout.isActive(context)
          ? DesktopBookPresentation.row
          : DesktopBookPresentation.card,
      yearLabel: book.year?.toString(),
      isFavorite: entry.isFavorite,
      isLater: isLater,
      onLaterPressed: onLaterPressed,
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

class _LibraryBookmarkTile extends StatelessWidget {
  const _LibraryBookmarkTile({
    required this.bookmark,
    required this.onPlay,
    required this.onRemove,
  });
  final PlaybackBookmark bookmark;
  final VoidCallback onPlay;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final book = bookmark.book;
    final position = Duration(milliseconds: bookmark.positionMs);
    final time =
        '${position.inMinutes}:${position.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    return Card(
      key: ValueKey('library-bookmark-${bookmark.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book?.title ?? bookmark.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${bookmark.title} · $time',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (book != null)
              Text(
                '${book.author} · ${book.sourceName}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (bookmark.note != null) ...[
              const SizedBox(height: 8),
              Text(bookmark.note!),
            ],
            if (book == null) ...[
              const SizedBox(height: 8),
              Text(context.strings.bookmarkUnavailable),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: book == null ? null : onPlay,
                  icon: const AppIcon(AppIconAssets.playerPlay),
                  label: Text(context.strings.play),
                ),
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const AppIcon(AppIconAssets.systemTrash),
                  label: Text(context.strings.deleteBookmarkAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
