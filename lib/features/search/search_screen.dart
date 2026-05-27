import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';
import '../../domain/models/download_task.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/library/library_store.dart';
import '../../services/search/search_history_store.dart';
import '../../services/sources/source_catalog_provider.dart';
import '../../sources/sources.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/state_placeholder.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  SearchKind _kind = SearchKind.title;
  String _activeQuery = '';
  Future<SourceSearchResponse>? _searchFuture;
  List<SearchHistoryEntry> _history = const [];
  final _playLoadingIds = <String>{};
  final _downloadLoadingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final libraryStore = ref.watch(libraryStoreProvider);

    return CustomScrollView(
      slivers: [
        SliverAppBar(floating: true, title: Text(strings.search)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(14),
                    child: AppIcon(AppIconAssets.navSearch, size: 22),
                  ),
                  suffixIcon: IconButton(
                    key: const ValueKey('search-submit'),
                    tooltip: strings.search,
                    onPressed: _submitSearch,
                    icon: const AppIcon(AppIconAssets.navSearch),
                  ),
                  hintText: strings.searchHint,
                ),
              ),
              const SizedBox(height: 12),
              _SearchFilters(
                selectedKind: _kind,
                onKindChanged: (kind) => setState(() => _kind = kind),
              ),
              const SizedBox(height: 16),
              _SearchResults(
                query: _activeQuery,
                searchFuture: _searchFuture,
                libraryStore: libraryStore,
                playLoadingIds: _playLoadingIds,
                downloadLoadingIds: _downloadLoadingIds,
                history: _history,
                onHistoryTap: _runHistorySearch,
                onFavoriteToggle: _toggleFavorite,
                onPlayPressed: _playResult,
                onDownloadPressed: _downloadResult,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _loadHistory() async {
    final history = await ref.read(searchHistoryStoreProvider).load();
    if (mounted) {
      setState(() => _history = history);
    }
  }

  Future<void> _submitSearch([String? submittedQuery]) async {
    final query = (submittedQuery ?? _controller.text).trim();
    if (query.length < 2) {
      setState(() {
        _activeQuery = query;
        _searchFuture = null;
      });
      return;
    }

    final history = await ref
        .read(searchHistoryStoreProvider)
        .record(query, _kind);
    if (!mounted) {
      return;
    }

    setState(() {
      _history = history;
      _activeQuery = query;
      _searchFuture = ref
          .read(sourceCatalogServiceProvider)
          .search(SearchRequest(query: query, kind: _kind));
    });
  }

  void _runHistorySearch(SearchHistoryEntry entry) {
    _controller.text = entry.query;
    _controller.selection = TextSelection.collapsed(offset: entry.query.length);
    setState(() {
      _kind = entry.kind;
    });
    _submitSearch();
  }

  Future<void> _toggleFavorite(AudioBook book) async {
    final added = await ref.read(libraryStoreProvider).toggleFavorite(book);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? context.strings.favoriteAdded
              : context.strings.favoriteRemoved,
        ),
      ),
    );
  }

  Future<void> _playResult(BookSearchResult result) async {
    final id = _resultKey(result);
    final playbackController = ref.read(playbackControllerProvider);
    if (_playbackBookMatchesResult(playbackController.state.book, result)) {
      await playbackController.togglePlayPause();
      return;
    }

    if (_playLoadingIds.contains(id)) {
      return;
    }

    setState(() => _playLoadingIds.add(id));
    try {
      final snapshot = await ref
          .read(sourceCatalogServiceProvider)
          .loadBook(result.ref);
      await playbackController.loadBook(snapshot.playbackBook, autoPlay: true);
      if (mounted) {
        setState(() => _playLoadingIds.remove(id));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.strings.sourceSearchError}: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _playLoadingIds.remove(id));
      }
    }
  }

  Future<void> _downloadResult(BookSearchResult result) async {
    final id = _resultKey(result);
    if (_downloadLoadingIds.contains(id)) {
      return;
    }

    setState(() => _downloadLoadingIds.add(id));
    try {
      final downloadManager = ref.read(downloadManagerProvider);
      final existingBook = _playbackBookForResult(downloadManager, result);
      var added = false;
      if (existingBook != null &&
          _downloadStateForResult(downloadManager, result) !=
              BookCardDownloadState.none) {
        await runBookCardDownloadAction(downloadManager, existingBook);
      } else {
        final snapshot = await ref
            .read(sourceCatalogServiceProvider)
            .loadBook(result.ref);
        await runBookCardDownloadAction(downloadManager, snapshot.playbackBook);
        added = true;
      }
      if (mounted && added) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.downloadQueuedMessage)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.strings.download}: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadLoadingIds.remove(id));
      }
    }
  }
}

class _SearchFilters extends StatelessWidget {
  const _SearchFilters({
    required this.selectedKind,
    required this.onKindChanged,
  });

  final SearchKind selectedKind;
  final ValueChanged<SearchKind> onKindChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final options = [
      (SearchKind.title, strings.searchByTitle),
      (SearchKind.author, strings.searchByAuthor),
      (SearchKind.narrator, strings.searchByNarrator),
      (SearchKind.series, strings.searchBySeries),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            selected: selectedKind == option.$1,
            label: Text(option.$2),
            onSelected: (_) => onKindChanged(option.$1),
          ),
        FilterChip(
          selected: true,
          label: const Text('Izib'),
          onSelected: (_) {},
        ),
        FilterChip(
          selected: true,
          label: const Text('Akniga'),
          onSelected: (_) {},
        ),
        InputChip(
          avatar: const AppIcon(AppIconAssets.systemSort, size: 16),
          label: Text(strings.sortRelevance),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.searchFuture,
    required this.libraryStore,
    required this.playLoadingIds,
    required this.downloadLoadingIds,
    required this.history,
    required this.onHistoryTap,
    required this.onFavoriteToggle,
    required this.onPlayPressed,
    required this.onDownloadPressed,
  });

  final String query;
  final Future<SourceSearchResponse>? searchFuture;
  final LibraryStore libraryStore;
  final Set<String> playLoadingIds;
  final Set<String> downloadLoadingIds;
  final List<SearchHistoryEntry> history;
  final ValueChanged<SearchHistoryEntry> onHistoryTap;
  final Future<void> Function(AudioBook book) onFavoriteToggle;
  final ValueChanged<BookSearchResult> onPlayPressed;
  final ValueChanged<BookSearchResult> onDownloadPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final future = searchFuture;
    final downloadManager = ref.watch(downloadManagerProvider);
    final playbackController = ref.watch(playbackControllerProvider);

    if (query.isEmpty) {
      return _SearchHistory(history: history, onTap: onHistoryTap);
    }

    if (future == null) {
      return StatePlaceholder.empty(
        title: strings.searchShortQueryTitle,
        message: strings.searchShortQueryMessage,
      );
    }

    return ListenableBuilder(
      listenable: playbackController,
      builder: (context, _) => FutureBuilder<SourceSearchResponse>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return StatePlaceholder.loading(title: strings.searchingSources);
          }

          if (snapshot.hasError) {
            return StatePlaceholder.error(
              title: strings.sourceSearchError,
              message: snapshot.error.toString(),
            );
          }

          final response = snapshot.data;
          final results = response?.results ?? const <BookSearchResult>[];
          if (results.isEmpty) {
            if (response?.failures.isNotEmpty == true) {
              return StatePlaceholder.error(
                title: strings.sourceSearchError,
                message: response!.failures
                    .map((failure) => '${failure.sourceId}: ${failure.message}')
                    .join('\n'),
              );
            }

            return StatePlaceholder.empty(
              title: strings.noSearchResults,
              message: strings.filteredNoSearchResults,
            );
          }

          final catalog = ref.read(sourceCatalogServiceProvider);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: strings.sourceResultsCount(results.length)),
              if (response?.failures.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    strings.partialSourceFailures(response!.failures.length),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              for (final result in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Builder(
                    builder: (context) {
                      final audioBook = catalog.audioBookForSearchResult(
                        result,
                      );
                      final key = _resultKey(result);
                      final isCurrentBook = _playbackBookMatchesResult(
                        playbackController.state.book,
                        result,
                      );
                      final downloadState = _downloadStateForResult(
                        downloadManager,
                        result,
                      );
                      return BookCard(
                        book: audioBook,
                        yearLabel: result.year?.toString(),
                        isFavorite: libraryStore.isFavorite(audioBook),
                        downloadState: downloadState,
                        downloadProgress: _downloadProgressForResult(
                          downloadManager,
                          result,
                        ),
                        isCurrentBook: isCurrentBook,
                        isPlaying: playbackController.state.isPlaying,
                        isPlaybackLoading:
                            isCurrentBook &&
                            (playbackController.state.status ==
                                    AudioPlaybackStatus.loading ||
                                playbackController.state.status ==
                                    AudioPlaybackStatus.buffering),
                        isPlayLoading:
                            playLoadingIds.contains(key) && !isCurrentBook,
                        isDownloadLoading: downloadLoadingIds.contains(key),
                        onFavoritePressed: () => onFavoriteToggle(audioBook),
                        onDownloadPressed: () => onDownloadPressed(result),
                        onPlay: () => onPlayPressed(result),
                        onTap: () => unawaited(
                          context.push(
                            '/source-book/${result.sourceId}/${result.sourceBookId}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchHistory extends StatelessWidget {
  const _SearchHistory({required this.history, required this.onTap});

  final List<SearchHistoryEntry> history;
  final ValueChanged<SearchHistoryEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    if (history.isEmpty) {
      return StatePlaceholder.empty(
        title: strings.searchReadyTitle,
        message: strings.searchReadyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: strings.recentSearches),
        for (final entry in history)
          ListTile(
            leading: const AppIcon(AppIconAssets.navSearch),
            title: Text(entry.query),
            subtitle: Text(_kindLabel(context, entry.kind)),
            trailing: Text('${entry.usageCount}'),
            onTap: () => onTap(entry),
          ),
      ],
    );
  }
}

String _resultKey(BookSearchResult result) {
  return '${result.sourceId}:${result.sourceBookId}';
}

String _resultVersionId(BookSearchResult result) {
  return switch (result.sourceId) {
    'izib' => 'izib-${result.sourceBookId}',
    _ => result.sourceBookId,
  };
}

BookCardDownloadState _downloadStateForResult(
  DownloadManager manager,
  BookSearchResult result,
) {
  final book = _playbackBookForResult(manager, result);
  if (book != null) {
    return downloadStateForBook(manager, book);
  }

  final tasks = manager.tasks
      .where((task) => task.bookVersionId == _resultVersionId(result))
      .toList();
  if (tasks.isEmpty) {
    return BookCardDownloadState.none;
  }

  if (tasks.any((task) => task.status == DownloadTaskStatus.running)) {
    return BookCardDownloadState.downloading;
  }
  if (tasks.any((task) => task.status == DownloadTaskStatus.queued)) {
    return BookCardDownloadState.queued;
  }
  if (tasks.any((task) => task.status == DownloadTaskStatus.failed)) {
    return BookCardDownloadState.failed;
  }
  if (tasks.any((task) => task.status == DownloadTaskStatus.paused)) {
    return BookCardDownloadState.paused;
  }
  if (tasks.any((task) => task.status == DownloadTaskStatus.completed)) {
    final completedCount = tasks
        .where((task) => task.status == DownloadTaskStatus.completed)
        .length;
    final chapterCount = result.chapterCount;
    if (chapterCount == null || completedCount >= chapterCount) {
      return BookCardDownloadState.downloaded;
    }
    return BookCardDownloadState.paused;
  }
  return BookCardDownloadState.none;
}

double _downloadProgressForResult(
  DownloadManager manager,
  BookSearchResult result,
) {
  final book = _playbackBookForResult(manager, result);
  if (book != null) {
    return downloadProgressForBook(manager, book);
  }

  final tasks = manager.tasks
      .where((task) => task.bookVersionId == _resultVersionId(result))
      .toList();
  if (tasks.isEmpty) {
    return 0;
  }
  final summed = tasks.fold<double>(
    0,
    (sum, task) => sum + task.progress.clamp(0, 1).toDouble(),
  );
  final chapterCount = result.chapterCount;
  final totalCount = chapterCount == null || chapterCount < tasks.length
      ? tasks.length
      : chapterCount;
  return (summed / totalCount).clamp(0, 1).toDouble();
}

AudioPlaybackBook? _playbackBookForResult(
  DownloadManager manager,
  BookSearchResult result,
) {
  for (final task in manager.tasks) {
    if (task.bookVersionId != _resultVersionId(result)) {
      continue;
    }
    final book = manager.bookForTask(task.id);
    if (book != null) {
      return book;
    }
  }
  for (final task in manager.tasks) {
    final book = manager.bookForTask(task.id);
    if (_playbackBookMatchesResult(book, result)) {
      return book;
    }
  }
  return null;
}

bool _playbackBookMatchesResult(
  AudioPlaybackBook? book,
  BookSearchResult result,
) {
  if (book == null || book.sourceId != result.sourceId) {
    return false;
  }

  return book.sourceBookId == result.sourceBookId ||
      book.versionId == _resultVersionId(result) ||
      book.id == 'izib-book-${result.sourceBookId}' ||
      book.id == result.sourceBookId ||
      (_looselySameText(book.title, result.title) &&
          _looselySamePerson(book.author, result.author));
}

bool _looselySamePerson(String bookPerson, String? resultPerson) {
  final normalizedResult = _normalizeLoose(resultPerson ?? '');
  if (normalizedResult.isEmpty) {
    return true;
  }
  return _looselySameText(bookPerson, normalizedResult);
}

bool _looselySameText(String left, String right) {
  final normalizedLeft = _normalizeLoose(left);
  final normalizedRight = _normalizeLoose(right);
  if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
    return false;
  }
  return normalizedLeft == normalizedRight ||
      normalizedLeft.contains(normalizedRight) ||
      normalizedRight.contains(normalizedLeft);
}

String _normalizeLoose(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zа-яё0-9]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _kindLabel(BuildContext context, SearchKind kind) {
  final strings = context.strings;
  return switch (kind) {
    SearchKind.title => strings.searchByTitle,
    SearchKind.author => strings.searchByAuthor,
    SearchKind.narrator => strings.searchByNarrator,
    SearchKind.series => strings.searchBySeries,
    SearchKind.all => strings.search,
  };
}
