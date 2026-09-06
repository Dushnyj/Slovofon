import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';
import '../../domain/models/download_task.dart';
import '../../services/audio/audio_persistence.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/home/home_listening_visibility_store.dart';
import '../../services/library/library_store.dart';
import '../../services/search/search_history_store.dart';
import '../../services/sources/source_book_cache.dart';
import '../../services/sources/source_catalog_provider.dart';
import '../../services/sources/source_catalog_service.dart';
import '../../services/sources/source_settings_store.dart';
import '../../sources/sources.dart';
import '../../ui/components/app_bar_text.dart';
import '../../ui/adaptive/adaptive_sheet.dart';
import '../../ui/adaptive/desktop_layout.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/filter_picker_sheet.dart';
import '../../ui/components/responsive_tile_grid.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/source_badge.dart';
import '../../ui/components/state_placeholder.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';
import '../shared/playback_resume.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    this.initialQuery,
    this.initialKinds,
    this.submitInitialSearch = false,
    this.popOnResultsBack = false,
    this.resetToken,
    super.key,
  });

  final String? initialQuery;
  final Set<SearchKind>? initialKinds;
  final bool submitInitialSearch;
  final bool popOnResultsBack;
  final String? resetToken;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  Set<SearchKind> _selectedKinds = const {SearchKind.title};
  SearchSort _selectedSort = SearchSort.relevance;
  String _activeQuery = '';
  Future<SourceSearchResponse>? _searchFuture;
  List<SearchHistoryEntry> _history = const [];
  bool _showResultsPage = false;
  final _playLoadingIds = <String>{};
  final _downloadLoadingIds = <String>{};
  String? _appliedInitialRouteKey;
  int _searchRequestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _applyInitialRoute(rebuild: false);
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyInitialRoute(rebuild: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final desktop = DesktopLayout.isActive(context);
    final libraryStore = ref.watch(libraryStoreProvider);

    if (desktop) return _buildDesktopWorkspace(context, libraryStore);

    if (_showResultsPage) {
      return BackButtonListener(
        onBackButtonPressed: () async {
          if (!_isSearchRouteCurrent(context)) {
            return false;
          }
          _handleResultsBack(context);
          return true;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 520) {
              _handleResultsBack(context);
            }
          },
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                toolbarHeight: appBarToolbarHeight(context),
                floating: true,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => _handleResultsBack(context),
                  icon: const AppIcon(AppIconAssets.systemBack),
                ),
                title: preserveAppBarTextScale(
                  context,
                  _SearchResultsTitle(searchFuture: _searchFuture),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _SearchResults(
                      query: _activeQuery,
                      searchFuture: _searchFuture,
                      libraryStore: libraryStore,
                      playLoadingIds: _playLoadingIds,
                      downloadLoadingIds: _downloadLoadingIds,
                      history: _history,
                      onHistoryTap: _runHistorySearch,
                      onHistoryDelete: _deleteHistoryEntry,
                      onFavoriteToggle: _toggleFavorite,
                      onLaterToggle: _toggleLater,
                      onRetry: () => _submitSearch(_activeQuery),
                      onPlayPressed: _playResult,
                      onDownloadPressed: _downloadResult,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          toolbarHeight: appBarToolbarHeight(context),
          floating: true,
          title: preserveAppBarTextScale(context, Text(strings.search)),
        ),
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
                selectedKinds: _selectedKinds,
                selectedSort: _selectedSort,
                onKindsChanged: (kinds) {
                  setState(() => _selectedKinds = kinds);
                },
                onSortChanged: (sort) {
                  setState(() => _selectedSort = sort);
                },
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
                onHistoryDelete: _deleteHistoryEntry,
                onFavoriteToggle: _toggleFavorite,
                onLaterToggle: _toggleLater,
                onRetry: () => _submitSearch(_activeQuery),
                onPlayPressed: _playResult,
                onDownloadPressed: _downloadResult,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopWorkspace(
    BuildContext context,
    LibraryStore libraryStore,
  ) {
    final strings = context.strings;
    final enabledSources = ref
        .watch(sourceSettingsStoreProvider)
        .enabledSearchSourceIds;
    final controls = _DesktopSearchPanel(
      key: const ValueKey('desktop-search-controls'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            selectedKinds: _selectedKinds,
            selectedSort: _selectedSort,
            onKindsChanged: (kinds) {
              setState(() => _selectedKinds = kinds);
            },
            onSortChanged: (sort) {
              setState(() => _selectedSort = sort);
            },
          ),
        ],
      ),
    );
    final primary = Column(
      key: const ValueKey('desktop-search-primary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showResultsPage)
          Padding(
            key: const ValueKey('desktop-search-results-heading'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => _handleResultsBack(context),
                  icon: const AppIcon(AppIconAssets.systemBack),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.titleMedium,
                    child: _SearchResultsTitle(searchFuture: _searchFuture),
                  ),
                ),
              ],
            ),
          ),
        if (_activeQuery.isNotEmpty)
          _SearchResults(
            query: _activeQuery,
            searchFuture: _searchFuture,
            libraryStore: libraryStore,
            playLoadingIds: _playLoadingIds,
            downloadLoadingIds: _downloadLoadingIds,
            history: _history,
            onHistoryTap: _runHistorySearch,
            onHistoryDelete: _deleteHistoryEntry,
            onFavoriteToggle: _toggleFavorite,
            onLaterToggle: _toggleLater,
            onRetry: () => _submitSearch(_activeQuery),
            onPlayPressed: _playResult,
            onDownloadPressed: _downloadResult,
          ),
      ],
    );
    final contextPanels = <Widget>[
      _DesktopSearchPanel(
        key: const ValueKey('desktop-search-history'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchContextHeading(title: strings.recentSearches),
            if (_history.isEmpty)
              Text(strings.searchHistoryEmptyMessage)
            else
              for (final entry in _history)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.query),
                        subtitle: Text(_kindLabel(context, entry.kind)),
                        onTap: () => _runHistorySearch(entry),
                      ),
                    ),
                    IconButton(
                      tooltip: strings.deleteSearchHistoryEntry,
                      onPressed: () => _deleteHistoryEntry(entry),
                      icon: const AppIcon(AppIconAssets.systemClose),
                    ),
                  ],
                ),
          ],
        ),
      ),
      _DesktopSearchPanel(
        key: const ValueKey('desktop-search-sources'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchContextHeading(title: strings.enabledInSearch),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                for (final source in enabledSources)
                  Text(
                    strings.sourceDisplayName(source),
                    key: ValueKey('desktop-search-source-$source'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: sourceColorForId(
                        source,
                        Theme.of(context).colorScheme,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => context.go('/settings'),
                icon: const AppIcon(AppIconAssets.navSettings),
                label: Text(strings.settings),
              ),
            ),
          ],
        ),
      ),
    ];
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!_showResultsPage || !_isSearchRouteCurrent(context)) return false;
        _handleResultsBack(context);
        return true;
      },
      child: ListView(
        padding: DesktopLayout.pagePadding(context),
        children: [
          DesktopPageHeader(title: strings.search, bottomSpacing: 16),
          controls,
          SizedBox(height: _activeQuery.isEmpty ? 24 : 12),
          if (_activeQuery.isEmpty)
            _DesktopSearchContextPanels(
              key: const ValueKey('desktop-search-secondary'),
              children: contextPanels,
            )
          else
            DesktopWorkspaceColumns(
              key: const ValueKey('desktop-search-workspace'),
              minimumPrimaryWidth: 620,
              primary: primary,
              secondary: Column(
                key: const ValueKey('desktop-search-secondary'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  contextPanels[0],
                  const SizedBox(height: 16),
                  contextPanels[1],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadHistory() async {
    final history = await ref.read(searchHistoryStoreProvider).load();
    if (mounted) {
      setState(() => _history = history);
    }
  }

  void _applyInitialRoute({required bool rebuild}) {
    final query = widget.initialQuery?.trim() ?? '';
    final initialKinds = widget.initialKinds;
    final initialKindNames = initialKinds?.map((kind) => kind.name).toList()
      ?..sort();
    final routeKey = [
      query,
      ...?initialKindNames,
      widget.submitInitialSearch ? 'run' : 'idle',
      widget.resetToken ?? '',
    ].join('|');
    if (_appliedInitialRouteKey == routeKey) {
      return;
    }
    _appliedInitialRouteKey = routeKey;
    _searchRequestGeneration++;

    void apply() {
      if ((widget.resetToken ?? '').isNotEmpty && query.isEmpty) {
        _controller.clear();
        _activeQuery = '';
        _searchFuture = null;
        _showResultsPage = false;
        return;
      }
      if (query.isNotEmpty) {
        _controller.text = query;
        _controller.selection = TextSelection.collapsed(offset: query.length);
      }
    }

    if (rebuild) {
      setState(apply);
    } else {
      apply();
    }

    if (widget.submitInitialSearch && query.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _appliedInitialRouteKey == routeKey) {
          _submitSearchWithKinds(query, searchKindsOverride: initialKinds);
        }
      });
    }
  }

  Future<void> _submitSearch([String? submittedQuery]) {
    return _submitSearchWithKinds(submittedQuery);
  }

  Future<void> _submitSearchWithKinds(
    String? submittedQuery, {
    Set<SearchKind>? searchKindsOverride,
  }) async {
    final generation = ++_searchRequestGeneration;
    final query = (submittedQuery ?? _controller.text).trim();
    if (query.length < 2) {
      setState(() {
        _activeQuery = query;
        _searchFuture = null;
        _showResultsPage = false;
      });
      return;
    }

    final searchKinds =
        searchKindsOverride != null && searchKindsOverride.isNotEmpty
        ? Set<SearchKind>.unmodifiable(searchKindsOverride)
        : _selectedKinds;
    final historyKind = _historyKindFor(searchKinds);
    final sort = _selectedSort;
    var history = _history;
    try {
      history = await ref
          .read(searchHistoryStoreProvider)
          .record(query, historyKind);
    } catch (_) {
      // History is optional: a local write failure must not block the search.
    }
    if (!mounted || generation != _searchRequestGeneration) {
      return;
    }

    setState(() {
      _history = history;
      _activeQuery = query;
      _showResultsPage = true;
      _searchFuture = ref
          .read(sourceCatalogServiceProvider)
          .search(
            SearchRequest(
              query: query,
              kind: historyKind,
              kinds: searchKinds,
              sort: sort,
            ),
          );
    });
  }

  void _runHistorySearch(SearchHistoryEntry entry) {
    _controller.text = entry.query;
    _controller.selection = TextSelection.collapsed(offset: entry.query.length);
    setState(() {
      _selectedKinds = entry.kind == SearchKind.all
          ? const {
              SearchKind.title,
              SearchKind.author,
              SearchKind.narrator,
              SearchKind.series,
              SearchKind.genre,
            }
          : {entry.kind};
    });
    _submitSearch();
  }

  Future<void> _deleteHistoryEntry(SearchHistoryEntry entry) async {
    final history = await ref
        .read(searchHistoryStoreProvider)
        .delete(entry.query, entry.kind);
    if (mounted) {
      setState(() => _history = history);
    }
  }

  void _closeResultsPage() {
    if (!mounted || !_showResultsPage) {
      return;
    }
    setState(() {
      _showResultsPage = false;
      _activeQuery = '';
      _searchFuture = null;
    });
  }

  void _handleResultsBack(BuildContext context) {
    _searchRequestGeneration++;
    if (widget.popOnResultsBack && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _closeResultsPage();
  }

  bool _isSearchRouteCurrent(BuildContext context) {
    final path = GoRouter.of(context).state.uri.path;
    return path == '/search' || path == '/scoped-search';
  }

  Future<void> _toggleFavorite(AudioBook book) async {
    final added = await ref.read(libraryStoreProvider).toggleFavorite(book);
    if (added) {
      _cacheFavoriteDetails(book);
    }
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

  Future<void> _toggleLater(AudioBook book) async {
    try {
      await ref.read(libraryStoreProvider).toggleLater(book);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.libraryActionError)),
      );
    }
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
      unawaited(_cacheSnapshot(snapshot));
      final playbackBook = await ref
          .read(downloadManagerProvider)
          .offlinePlaybackBook(snapshot.playbackBook);
      final progressSnapshots =
          await ref.read(playbackPersistenceStoreProvider)?.loadProgress() ??
          const <PlaybackProgressSnapshot>[];
      final resumePoint = playbackResumePointForBook(
        playbackBook,
        progressSnapshots,
        fallbackVersionId: _resultVersionId(result),
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
        unawaited(_cacheSnapshot(snapshot));
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

  Future<SourceBookSnapshot> _cacheSnapshot(SourceBookSnapshot snapshot) async {
    try {
      return await SourceBookCache(
        downloadStorage: ref.read(downloadStorageProvider),
        downloadManager: ref.read(downloadManagerProvider),
        libraryStore: ref.read(libraryStoreProvider),
      ).refresh(snapshot);
    } catch (error) {
      debugPrint('Failed to cache source book metadata: $error');
      return snapshot;
    }
  }

  void _cacheFavoriteDetails(AudioBook book) {
    final sourceBookId = book.sourceBookId;
    if (sourceBookId == null || sourceBookId.isEmpty) {
      return;
    }
    unawaited(
      ref
          .read(sourceCatalogServiceProvider)
          .loadBook(
            SourceBookRef(sourceId: book.sourceId, sourceBookId: sourceBookId),
          )
          .then((snapshot) => unawaited(_cacheSnapshot(snapshot)))
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint('Failed to cache favorite source book metadata: $error');
          }),
    );
  }
}

class _DesktopSearchContextPanels extends StatelessWidget {
  const _DesktopSearchContextPanels({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 24.0;
      final minimumWidth = 360 * DesktopLayout.workspaceScaleFactor(context);
      if (constraints.maxWidth >= minimumWidth * 2 + gap) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: gap),
            Expanded(child: children[1]),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          children[0],
          const SizedBox(height: gap),
          children[1],
        ],
      );
    },
  );
}

class _DesktopSearchPanel extends StatelessWidget {
  const _DesktopSearchPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SearchContextHeading extends StatelessWidget {
  const _SearchContextHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class _SearchFilters extends StatelessWidget {
  const _SearchFilters({
    required this.selectedKinds,
    required this.selectedSort,
    required this.onKindsChanged,
    required this.onSortChanged,
  });

  final Set<SearchKind> selectedKinds;
  final SearchSort selectedSort;
  final ValueChanged<Set<SearchKind>> onKindsChanged;
  final ValueChanged<SearchSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        InputChip(
          avatar: const AppIcon(AppIconAssets.systemFilter, size: 16),
          label: Text(
            '${strings.searchScope}: ${_kindsLabel(context, selectedKinds)}',
          ),
          onPressed: () => _pickKinds(context),
        ),
        InputChip(
          avatar: const AppIcon(AppIconAssets.systemSort, size: 16),
          label: Text('${strings.sort}: ${_sortLabel(context, selectedSort)}'),
          onPressed: () => _pickSort(context),
        ),
      ],
    );
  }

  Future<void> _pickKinds(BuildContext context) async {
    // Keep the in-progress selection when the dialog's viewport is resized.
    var draft = selectedKinds.toSet();
    final next = await showAdaptiveSheet<Set<SearchKind>>(
      context: context,
      title: context.strings.searchScope,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FilterPickerSheet(
              options: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(context.strings.selectAtLeastOneSearchKind),
                ),
                for (final kind in _searchKindOptions)
                  CheckboxListTile(
                    value: draft.contains(kind),
                    visualDensity: VisualDensity.compact,
                    title: Text(_kindLabel(context, kind)),
                    onChanged: draft.length == 1 && draft.contains(kind)
                        ? null
                        : (value) {
                            setModalState(() {
                              final nextDraft = draft.toSet();
                              if (value == true) {
                                nextDraft.add(kind);
                              } else if (nextDraft.length > 1) {
                                nextDraft.remove(kind);
                              }
                              draft = nextDraft;
                            });
                          },
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
    if (next != null && next.isNotEmpty) {
      onKindsChanged(Set.unmodifiable(next));
    }
  }

  Future<void> _pickSort(BuildContext context) async {
    final next = await showAdaptiveSheet<SearchSort>(
      context: context,
      title: context.strings.sort,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FilterPickerSheet(
          options: [
            for (final sort in SearchSort.values)
              ListTile(
                visualDensity: VisualDensity.compact,
                title: Text(_sortLabel(context, sort)),
                trailing: sort == selectedSort
                    ? AppIcon(
                        AppIconAssets.systemCheck,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                selected: sort == selectedSort,
                onTap: () => Navigator.of(context).pop(sort),
              ),
          ],
          action: DesktopLayout.isActive(context)
              ? null
              : FilledButton(
                  onPressed: () => Navigator.of(context).pop(selectedSort),
                  child: Text(context.strings.apply),
                ),
        );
      },
    );
    if (next != null) {
      onSortChanged(next);
    }
  }
}

class _SearchResultsTitle extends StatelessWidget {
  const _SearchResultsTitle({required this.searchFuture});

  final Future<SourceSearchResponse>? searchFuture;

  @override
  Widget build(BuildContext context) {
    final future = searchFuture;
    if (future == null) {
      return Text(context.strings.search);
    }

    return FutureBuilder<SourceSearchResponse>(
      future: future,
      builder: (context, snapshot) {
        if (DesktopLayout.isActive(context) && snapshot.hasError) {
          return Text(context.strings.sourceSearchError);
        }
        if (!snapshot.hasData) {
          return Text(context.strings.searchingSources);
        }
        return Text(
          context.strings.sourceResultsCount(snapshot.data!.results.length),
        );
      },
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
    required this.onHistoryDelete,
    required this.onFavoriteToggle,
    required this.onLaterToggle,
    required this.onRetry,
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
  final ValueChanged<SearchHistoryEntry> onHistoryDelete;
  final Future<void> Function(AudioBook book) onFavoriteToggle;
  final Future<void> Function(AudioBook book) onLaterToggle;
  final VoidCallback onRetry;
  final ValueChanged<BookSearchResult> onPlayPressed;
  final ValueChanged<BookSearchResult> onDownloadPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final future = searchFuture;
    final downloadManager = ref.watch(downloadManagerProvider);
    final playbackController = ref.watch(playbackControllerProvider);
    final progressSnapshots =
        ref.watch(playbackProgressSnapshotsProvider).asData?.value ??
        const <PlaybackProgressSnapshot>[];

    if (query.isEmpty) {
      return _SearchHistory(
        history: history,
        onTap: onHistoryTap,
        onDelete: onHistoryDelete,
      );
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
              return _SearchFailuresNotice(
                failures: response!.failures,
                onRetry: onRetry,
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
              if (response?.failures.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SearchFailuresNotice(
                    failures: response!.failures,
                    onRetry: onRetry,
                  ),
                ),
              ResponsiveTileGrid(
                stretchDesktopColumns: DesktopLayout.isActive(context),
                maxColumns: DesktopLayout.isActive(context) ? 1 : 5,
                children: [
                  for (final result in results)
                    Builder(
                      builder: (context) {
                        final audioBook = catalog
                            .audioBookForSearchResult(result)
                            .copyWith(
                              progress: _progressForResult(
                                playbackController.state,
                                progressSnapshots,
                                result,
                              ),
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
                          desktopPresentation: DesktopBookPresentation.result,
                          yearLabel: result.year?.toString(),
                          isFavorite: libraryStore.isFavorite(audioBook),
                          isLater: libraryStore.isLater(audioBook),
                          onLaterPressed: () => onLaterToggle(audioBook),
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
                              '/source-book/${result.sourceId}/${Uri.encodeComponent(result.sourceBookId)}',
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchFailuresNotice extends StatelessWidget {
  const _SearchFailuresNotice({required this.failures, required this.onRetry});
  final List<SourceFailure> failures;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final names = failures
        .map((failure) => strings.sourceDisplayName(failure.sourceId))
        .toSet()
        .join(', ');
    return Material(
      key: const ValueKey('search-source-failures'),
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              strings.partialSearchSources(names),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onErrorContainer),
            ),
            TextButton.icon(
              key: const ValueKey('search-retry'),
              style: TextButton.styleFrom(
                foregroundColor: colors.onErrorContainer,
              ),
              onPressed: onRetry,
              icon: const AppIcon(AppIconAssets.systemRefresh, size: 18),
              label: Text(strings.partialSearchRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHistory extends StatelessWidget {
  const _SearchHistory({
    required this.history,
    required this.onTap,
    required this.onDelete,
  });

  final List<SearchHistoryEntry> history;
  final ValueChanged<SearchHistoryEntry> onTap;
  final ValueChanged<SearchHistoryEntry> onDelete;

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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${entry.usageCount}'),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: strings.deleteSearchHistoryEntry,
                  onPressed: () => onDelete(entry),
                  icon: AppIcon(
                    AppIconAssets.systemClose,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            onTap: () => onTap(entry),
          ),
      ],
    );
  }
}

String _resultKey(BookSearchResult result) {
  return '${result.sourceId}:${result.sourceBookId}';
}

const _searchKindOptions = [
  SearchKind.title,
  SearchKind.author,
  SearchKind.narrator,
  SearchKind.series,
  SearchKind.genre,
];

String _resultVersionId(BookSearchResult result) {
  return switch (result.sourceId) {
    'izib' => 'izib-${result.sourceBookId}',
    'akniga' => 'akniga-${result.sourceBookId}',
    'yakniga' => 'yakniga-${result.sourceBookId}',
    'knigavuhe' => 'knigavuhe-${_versionIdSegment(result.sourceBookId)}',
    'knigoblud' => 'knigoblud-${result.sourceBookId}',
    'baza_knig' => 'baza-knig-${_versionIdSegment(result.sourceBookId)}',
    _ => result.sourceBookId,
  };
}

String _versionIdSegment(String sourceBookId) {
  return sourceBookId
      .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-яЁё]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '')
      .toLowerCase();
}

SearchKind _historyKindFor(Set<SearchKind> selectedKinds) {
  return selectedKinds.length == 1 ? selectedKinds.single : SearchKind.all;
}

String _kindsLabel(BuildContext context, Set<SearchKind> kinds) {
  final selected = kinds.isEmpty ? const {SearchKind.title} : kinds;
  if (selected.length == _searchKindOptions.length) {
    return context.strings.all;
  }
  return selected.map((kind) => _kindLabel(context, kind)).join(', ');
}

double _progressForResult(
  AudioPlaybackState playbackState,
  List<PlaybackProgressSnapshot> snapshots,
  BookSearchResult result,
) {
  if (_playbackBookMatchesResult(playbackState.book, result)) {
    return playbackState.bookProgress;
  }

  final versionId = _resultVersionId(result);
  for (final snapshot in snapshots) {
    if (snapshot.bookVersionId == versionId) {
      return (snapshot.percent / 100).clamp(0, 1).toDouble();
    }
  }
  return 0;
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
      book.id == result.sourceBookId;
}

String _kindLabel(BuildContext context, SearchKind kind) {
  final strings = context.strings;
  return switch (kind) {
    SearchKind.title => strings.searchByTitle,
    SearchKind.author => strings.searchByAuthor,
    SearchKind.narrator => strings.searchByNarrator,
    SearchKind.series => strings.searchBySeries,
    SearchKind.genre => strings.searchByGenre,
    SearchKind.all => strings.search,
  };
}

String _sortLabel(BuildContext context, SearchSort sort) {
  final strings = context.strings;
  return switch (sort) {
    SearchSort.relevance => strings.sortByRelevance,
    SearchSort.rating => strings.sortByRating,
    SearchSort.year => strings.sortByYear,
    SearchSort.duration => strings.sortByDuration,
    SearchSort.title => strings.sortByTitle,
  };
}
