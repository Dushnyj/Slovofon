import '../../ui/motion/motion_tooltip.dart';
import '../../ui/motion/motion_progress_indicator.dart';
import '../../ui/motion/motion_controls.dart';
import '../../ui/motion/app_motion.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import '../../services/library/library_metadata.dart';
import '../../services/library/library_store.dart';
import '../../services/search/downloaded_catalog_search.dart';
import '../../services/search/search_history_store.dart';
import '../../services/sources/source_book_cache.dart';
import '../../services/sources/source_catalog_provider.dart';
import '../../services/sources/source_catalog_service.dart';
import '../../services/sources/source_settings_store.dart';
import '../../sources/sources.dart';
import '../../ui/components/app_bar_text.dart';
import '../../ui/adaptive/adaptive_sheet.dart';
import '../../ui/adaptive/desktop_layout.dart';
import '../../ui/adaptive/television_layout.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/filter_picker_sheet.dart';
import '../../ui/components/responsive_tile_grid.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/source_badge.dart';
import '../../ui/components/state_placeholder.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';
import '../shared/playback_resume.dart';
import 'search_result_projection.dart';

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
  late final _televisionEditorFocus = FocusNode(
    debugLabel: 'TV search editor',
    onKeyEvent: _onTelevisionEditorKey,
  );
  final _televisionFiltersFocus = FocusNode(debugLabel: 'TV search filters');

  Set<SearchKind> _selectedKinds = _allSearchKinds;
  SearchSort _selectedSort = SearchSort.relevance;
  _SearchDisplayOptions _displayOptions = const _SearchDisplayOptions();
  String _activeQuery = '';
  Future<SourceSearchResponse>? _searchFuture;
  final _searchUpdates = ValueNotifier<SourceSearchResponse?>(null);
  SourceSearchCancellation? _searchCancellation;
  SearchRequest? _activeRequest;
  SourceCatalogService? _activeCatalog;
  SourceSearchResponse? _completedSearch;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  bool _scrollLoadScheduled = false;
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
    _searchCancellation?.cancel();
    _searchUpdates.dispose();
    _controller.dispose();
    _televisionEditorFocus.dispose();
    _televisionFiltersFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onTelevisionEditorKey(FocusNode node, KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        TelevisionLayout.isActive(context) &&
        View.of(context).viewInsets.bottom == 0) {
      // Android may hide the IME on Back but leave EditableText focused.
      // Intercept at its own FocusNode before the caret's arrow-key shortcuts.
      // Read the real view: Scaffold removes the bottom inset from the body's
      // MediaQuery when it resizes for an IME. Editing stays untouched while
      // that system keyboard is visible.
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _televisionFiltersFocus.requestFocus();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Directional traversal can cross the TV branch scope to its top
        // navigation. Unfocus would instead restore this editor's history.
        node.focusInDirection(TraversalDirection.up);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // With the IME hidden, Left leaves the editor for the TV navigation
        // rail. While editing with an open IME it remains a caret movement.
        node.focusInDirection(TraversalDirection.left);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _submitTelevisionSearch([String? query]) {
    // A stable control remains mounted while async history/search is loading.
    // Down from this filter reaches the result shelf when it is ready, without
    // stealing focus back from someone already navigating with the remote.
    _televisionFiltersFocus.requestFocus();
    return _submitSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final desktop = DesktopLayout.isActive(context);
    final libraryStore = ref.watch(libraryStoreProvider);

    if (desktop) return _buildDesktopWorkspace(context, libraryStore);
    if (TelevisionLayout.isActive(context)) {
      return _buildTelevisionWorkspace(context, libraryStore);
    }

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
          child: _withSearchPaging(
            CustomScrollView(
              slivers: [
                SliverAppBar(
                  toolbarHeight: appBarToolbarHeight(context),
                  floating: true,
                  automaticallyImplyLeading: false,
                  leading: AppIconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => _handleResultsBack(context),
                    icon: const AppIcon(AppIconAssets.systemBack),
                  ),
                  title: preserveAppBarTextScale(
                    context,
                    _SearchResultsTitle(
                      searchFuture: _searchFuture,
                      updates: _searchUpdates,
                      options: _displayOptions,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _SearchOptionsChip(
                        options: _displayOptions,
                        onChanged: _applyDisplayOptions,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: _SearchResults(
                    query: _activeQuery,
                    searchFuture: _searchFuture,
                    updates: _searchUpdates,
                    options: _displayOptions,
                    libraryStore: libraryStore,
                    playLoadingIds: _playLoadingIds,
                    downloadLoadingIds: _downloadLoadingIds,
                    history: _history,
                    onHistoryTap: _runHistorySearch,
                    onHistoryDelete: _deleteHistoryEntry,
                    onFavoriteToggle: _toggleFavorite,
                    onLaterToggle: _toggleLater,
                    onRetry: _retrySearch,
                    onLoadMore: _loadMore,
                    onPlayPressed: _playResult,
                    onDownloadPressed: _downloadResult,
                  ),
                ),
              ],
            ),
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
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverList.list(
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
                      suffixIcon: AppIconButton(
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
                    options: _displayOptions,
                    onOptionsChanged: _applyDisplayOptions,
                    onKindsChanged: (kinds) {
                      setState(() => _selectedKinds = kinds);
                    },
                    onSortChanged: (sort) {
                      setState(() => _selectedSort = sort);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
              _SearchResults(
                query: _activeQuery,
                searchFuture: _searchFuture,
                updates: _searchUpdates,
                options: _displayOptions,
                libraryStore: libraryStore,
                playLoadingIds: _playLoadingIds,
                downloadLoadingIds: _downloadLoadingIds,
                history: _history,
                onHistoryTap: _runHistorySearch,
                onHistoryDelete: _deleteHistoryEntry,
                onFavoriteToggle: _toggleFavorite,
                onLaterToggle: _toggleLater,
                onRetry: _retrySearch,
                onLoadMore: _loadMore,
                onPlayPressed: _playResult,
                onDownloadPressed: _downloadResult,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTelevisionWorkspace(
    BuildContext context,
    LibraryStore libraryStore,
  ) {
    final strings = context.strings;
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!_showResultsPage || !_isSearchRouteCurrent(context)) return false;
        _handleResultsBack(context);
        return true;
      },
      child: CustomScrollView(
        key: const ValueKey('tv-search-workspace'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverList.list(
                  children: [
                    _TelevisionSearchToolbar(
                      editor: TextField(
                        key: const ValueKey('tv-search-editor'),
                        controller: _controller,
                        focusNode: _televisionEditorFocus,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _submitTelevisionSearch,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(8),
                            child: AppIcon(AppIconAssets.navSearch, size: 18),
                          ),
                          suffixIcon: AppIconButton(
                            key: const ValueKey('search-submit'),
                            tooltip: strings.search,
                            // This is part of the input, not a separate dark TV card.
                            // Keep the remote target and its focus outline without an
                            // idle fill/border contrasting with the field's own surface.
                            style: ButtonStyle(
                              backgroundColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                              foregroundColor: WidgetStatePropertyAll(
                                Theme.of(context).colorScheme.onSurface,
                              ),
                              side: WidgetStateProperty.resolveWith(
                                (states) => states.contains(WidgetState.focused)
                                    ? BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 2,
                                      )
                                    : BorderSide.none,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            padding: const EdgeInsets.all(8),
                            onPressed: _submitTelevisionSearch,
                            icon: const AppIcon(
                              AppIconAssets.navSearch,
                              size: 18,
                            ),
                          ),
                          hintText: strings.searchHint,
                        ),
                      ),
                      filters: _SearchFilters(
                        compactLabels: true,
                        scopeFocusNode: _televisionFiltersFocus,
                        selectedKinds: _selectedKinds,
                        selectedSort: _selectedSort,
                        options: _displayOptions,
                        onOptionsChanged: _applyDisplayOptions,
                        onKindsChanged: (kinds) =>
                            setState(() => _selectedKinds = kinds),
                        onSortChanged: (sort) =>
                            setState(() => _selectedSort = sort),
                      ),
                    ),
                    if (_showResultsPage)
                      Padding(
                        key: const ValueKey('tv-search-result-count'),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: DefaultTextStyle.merge(
                          style: Theme.of(context).textTheme.bodySmall,
                          child: _SearchResultsTitle(
                            searchFuture: _searchFuture,
                            updates: _searchUpdates,
                            options: _displayOptions,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 4),
                  ],
                ),
                _SearchResults(
                  query: _activeQuery,
                  searchFuture: _searchFuture,
                  updates: _searchUpdates,
                  options: _displayOptions,
                  libraryStore: libraryStore,
                  playLoadingIds: _playLoadingIds,
                  downloadLoadingIds: _downloadLoadingIds,
                  history: _history,
                  onHistoryTap: _runHistorySearch,
                  onHistoryDelete: _deleteHistoryEntry,
                  onFavoriteToggle: _toggleFavorite,
                  onLaterToggle: _toggleLater,
                  onRetry: _retrySearch,
                  onLoadMore: _loadMore,
                  onPlayPressed: _playResult,
                  onDownloadPressed: _downloadResult,
                ),
              ],
            ),
          ),
        ],
      ),
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
              suffixIcon: AppIconButton(
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
            options: _displayOptions,
            onOptionsChanged: _applyDisplayOptions,
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
    final primary = SliverMainAxisGroup(
      key: const ValueKey('desktop-search-primary'),
      slivers: [
        if (_showResultsPage)
          SliverToBoxAdapter(
            child: Padding(
              key: const ValueKey('desktop-search-results-heading'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppIconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => _handleResultsBack(context),
                    icon: const AppIcon(AppIconAssets.systemBack),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.titleMedium,
                      child: _SearchResultsTitle(
                        searchFuture: _searchFuture,
                        updates: _searchUpdates,
                        options: _displayOptions,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_activeQuery.isNotEmpty || _searchFuture != null)
          _SearchResults(
            query: _activeQuery,
            searchFuture: _searchFuture,
            updates: _searchUpdates,
            options: _displayOptions,
            libraryStore: libraryStore,
            playLoadingIds: _playLoadingIds,
            downloadLoadingIds: _downloadLoadingIds,
            history: _history,
            onHistoryTap: _runHistorySearch,
            onHistoryDelete: _deleteHistoryEntry,
            onFavoriteToggle: _toggleFavorite,
            onLaterToggle: _toggleLater,
            onRetry: _retrySearch,
            onLoadMore: _loadMore,
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
                    AppIconButton(
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
      child: _withSearchPaging(
        CustomScrollView(
          key: const PageStorageKey('desktop-search-scroll'),
          slivers: [
            SliverPadding(
              padding: DesktopLayout.pagePadding(context),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverList.list(
                    children: [
                      DesktopPageHeader(
                        title: strings.search,
                        bottomSpacing: 16,
                      ),
                      controls,
                      SizedBox(height: _activeQuery.isEmpty ? 24 : 12),
                    ],
                  ),
                  if (_activeQuery.isEmpty)
                    SliverToBoxAdapter(
                      child: _DesktopSearchContextPanels(
                        key: const ValueKey('desktop-search-secondary'),
                        children: contextPanels,
                      ),
                    )
                  else
                    SliverWorkspaceColumns(
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
            ),
          ],
        ),
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
    _cancelSearch();

    void apply() {
      if (query.isNotEmpty || (widget.resetToken ?? '').isNotEmpty) {
        _displayOptions = const _SearchDisplayOptions();
      }
      if (initialKinds != null && initialKinds.isNotEmpty) {
        // A scoped author/narrator link must update both the submitted query
        // and its visible filters. Otherwise the next submit silently searches
        // titles even though the initial request searched the selected entity.
        _selectedKinds = Set<SearchKind>.unmodifiable(
          initialKinds.contains(SearchKind.all)
              ? _searchKindOptions
              : initialKinds,
        );
      }
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

  void _applyDisplayOptions(_SearchDisplayOptions options) {
    final changedScope =
        options.downloadedOnly != _displayOptions.downloadedOnly;
    final active = _activeRequest;
    setState(() => _displayOptions = options);
    if (changedScope && (active != null || options.downloadedOnly)) {
      unawaited(
        _submitSearchWithKinds(
          active?.query,
          searchKindsOverride: active?.kinds,
          sortOverride: active?.sort,
          remember: false,
        ),
      );
    }
  }

  Future<void> _submitSearchWithKinds(
    String? submittedQuery, {
    Set<SearchKind>? searchKindsOverride,
    SearchSort? sortOverride,
    bool remember = true,
  }) async {
    final generation = ++_searchRequestGeneration;
    _cancelSearch();
    final cancellation = SourceSearchCancellation();
    _searchCancellation = cancellation;
    final query = (submittedQuery ?? _controller.text).trim();
    final downloadedOnly = _displayOptions.downloadedOnly;
    if (query.length < 2 && !downloadedOnly) {
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
    final sort = sortOverride ?? _selectedSort;
    setState(() {
      _activeQuery = query;
      _showResultsPage = true;
      final request = SearchRequest(
        query: query,
        kind: historyKind,
        kinds: searchKinds,
        sort: sort,
      );
      _activeRequest = request;
      if (downloadedOnly) {
        _searchFuture = _fetchDownloadedSearch(
          request,
          cancellation,
          generation,
        );
      } else {
        final catalog = ref.read(sourceCatalogServiceProvider);
        _activeCatalog = catalog;
        _searchFuture = _fetchSearch(
          catalog,
          request,
          cancellation,
          generation,
        );
      }
    });
    if (remember && query.length >= 2) {
      unawaited(
        _recordHistory(query, historyKind, searchKinds, sort, generation),
      );
    }
  }

  Future<void> _recordHistory(
    String query,
    SearchKind kind,
    Set<SearchKind> kinds,
    SearchSort sort,
    int generation,
  ) async {
    try {
      final history = await ref
          .read(searchHistoryStoreProvider)
          .record(query, kind, kinds: kinds, sort: sort);
      if (mounted && generation == _searchRequestGeneration) {
        setState(() => _history = history);
      }
    } catch (_) {
      // History is optional and must never block a query.
    }
  }

  Future<SourceSearchResponse> _fetchSearch(
    SourceCatalogService catalog,
    SearchRequest request,
    SourceSearchCancellation cancellation,
    int generation, {
    SourceSearchResponse? previous,
  }) async {
    bool current() =>
        mounted &&
        generation == _searchRequestGeneration &&
        !cancellation.isCancelled;
    try {
      final response = await catalog.search(
        request,
        cancellation: cancellation,
        onUpdate: (response) {
          if (current()) _searchUpdates.value = response;
        },
      );
      if (current()) _completedSearch = response;
      return response;
    } catch (_) {
      if (previous != null && current()) {
        _searchUpdates.value = previous;
        _loadMoreFailed = true;
      }
      rethrow;
    } finally {
      if (current() && previous != null) _loadingMore = false;
    }
  }

  Future<SourceSearchResponse> _fetchDownloadedSearch(
    SearchRequest request,
    SourceSearchCancellation cancellation,
    int generation,
  ) async {
    final search = DownloadedCatalogSearch(ref.read(downloadStorageProvider));
    final response = await cancellation.wait(
      search.search(request, cancellation: cancellation),
    );
    if (mounted &&
        generation == _searchRequestGeneration &&
        !cancellation.isCancelled) {
      _completedSearch = response;
    }
    return response;
  }

  void _retrySearch() {
    final retry = _completedSearch?.retryContinuation;
    if (retry != null) {
      _loadMore(continuation: retry);
      return;
    }
    final request = _activeRequest;
    if (request != null) {
      unawaited(
        _submitSearchWithKinds(
          request.query,
          searchKindsOverride: request.kinds,
          sortOverride: request.sort,
          remember: false,
        ),
      );
    }
  }

  void _loadMore({SourceSearchContinuation? continuation}) {
    final request = _activeRequest;
    final catalog = _activeCatalog;
    final previous = _completedSearch;
    final next = continuation ?? previous?.continuation;
    final cancellation = _searchCancellation;
    if (_loadingMore ||
        catalog == null ||
        request == null ||
        previous == null ||
        next == null ||
        cancellation == null ||
        cancellation.isCancelled) {
      return;
    }

    _searchUpdates.value = previous;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
      _searchFuture = _fetchSearch(
        catalog,
        request.copyWith(continuation: next),
        cancellation,
        _searchRequestGeneration,
        previous: previous,
      );
    });
  }

  Widget _withSearchPaging(Widget child) {
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical &&
            (notification.scrollDelta ?? 0) > 0 &&
            notification.metrics.extentAfter < 280 &&
            _completedSearch?.hasMore == true &&
            !_loadingMore &&
            !_loadMoreFailed &&
            !_scrollLoadScheduled) {
          _scrollLoadScheduled = true;
          final generation = _searchRequestGeneration;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || generation != _searchRequestGeneration) return;
            _scrollLoadScheduled = false;
            if (!_loadMoreFailed) _loadMore();
          });
        }
        return false;
      },
      child: child,
    );
  }

  void _cancelSearch() {
    _searchCancellation?.cancel();
    _activeRequest = null;
    _activeCatalog = null;
    _completedSearch = null;
    _loadingMore = false;
    _loadMoreFailed = false;
    _scrollLoadScheduled = false;
    _searchUpdates.value = null;
  }

  void _runHistorySearch(SearchHistoryEntry entry) {
    _controller.text = entry.query;
    _controller.selection = TextSelection.collapsed(offset: entry.query.length);
    setState(() {
      _selectedKinds = entry.effectiveKinds;
      _selectedSort = entry.sort;
    });
    _submitSearch();
  }

  Future<void> _deleteHistoryEntry(SearchHistoryEntry entry) async {
    final history = await ref
        .read(searchHistoryStoreProvider)
        .delete(entry.query, entry.kind, kinds: entry.kinds, sort: entry.sort);
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
    _cancelSearch();
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
    final cacheOnlineDetails = !_displayOptions.downloadedOnly;
    final added = await ref.read(libraryStoreProvider).toggleFavorite(book);
    if (added &&
        mounted &&
        cacheOnlineDetails &&
        !_displayOptions.downloadedOnly) {
      _cacheFavoriteDetails(book);
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showMotionSnackBar(
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
      ScaffoldMessenger.of(context).showMotionSnackBar(
        SnackBar(content: Text(context.strings.libraryActionError)),
      );
    }
  }

  Future<void> _playResult(BookSearchResult result) async {
    final id = _resultKey(result);
    final playbackController = ref.read(playbackControllerProvider);
    final response = _completedSearch;
    final local = response is DownloadedSearchResponse
        ? response.bookFor(result)
        : null;
    if (_displayOptions.downloadedOnly && local == null) return;
    final active = playbackController.state.book;
    final matchesActive = local == null
        ? _playbackBookMatchesResult(active, result) &&
              active?.offlineOnly != true
        : active?.sourceId == local.sourceId &&
              active?.versionId == local.versionId &&
              active?.offlineOnly == true;
    if (matchesActive) {
      await playbackController.togglePlayPause();
      return;
    }

    if (_playLoadingIds.contains(id)) {
      return;
    }

    final selection = playbackController.beginPlaybackSelection();
    final downloads = ref.read(downloadManagerProvider);
    final persistence = ref.read(playbackPersistenceStoreProvider);
    final visibility = ref.read(homeListeningVisibilityStoreProvider);
    final storage = ref.read(downloadStorageProvider);
    setState(() => _playLoadingIds.add(id));
    try {
      final AudioPlaybackBook playbackBook;
      if (local != null) {
        final verified = await DownloadedCatalogSearch(
          storage,
        ).playableBook(local);
        if (verified == null) {
          throw StateError('Downloaded files are no longer available.');
        }
        playbackBook = verified;
      } else {
        final snapshot = await ref
            .read(sourceCatalogServiceProvider)
            .loadBookPreview(result.ref);
        if (!mounted ||
            !playbackController.isPlaybackSelectionCurrent(selection)) {
          return;
        }
        unawaited(_cacheSnapshot(snapshot));
        playbackBook = await downloads.offlinePlaybackBook(
          snapshot.playbackBook,
        );
      }
      final progressSnapshots =
          await persistence?.loadProgress() ??
          const <PlaybackProgressSnapshot>[];
      if (!mounted ||
          !playbackController.isPlaybackSelectionCurrent(selection)) {
        return;
      }
      final resumePoint = playbackResumePointForBook(
        playbackBook,
        progressSnapshots,
        fallbackVersionId: local?.versionId ?? _resultVersionId(result),
      );
      await playbackController.loadBook(
        playbackBook,
        chapterIndex: resumePoint.chapterIndex,
        position: resumePoint.position,
        autoPlay: true,
        playbackSelection: selection,
      );
      if (!mounted ||
          !playbackController.isPlaybackSelectionCurrent(selection)) {
        return;
      }
      await visibility.show(homeListeningBookKeyFor(playbackBook));
      if (mounted) ref.invalidate(playbackProgressSnapshotsProvider);
    } catch (_) {
      if (mounted && playbackController.isPlaybackSelectionCurrent(selection)) {
        ScaffoldMessenger.of(context).showMotionSnackBar(
          SnackBar(content: Text(context.strings.savedBookPlaybackError)),
        );
      }
    } finally {
      if (mounted) setState(() => _playLoadingIds.remove(id));
    }
  }

  Future<void> _downloadResult(BookSearchResult result) async {
    if (_displayOptions.downloadedOnly) return;
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
            .loadBookPreview(result.ref);
        await runBookCardDownloadAction(downloadManager, snapshot.playbackBook);
        unawaited(_cacheSnapshot(snapshot));
        added = true;
      }
      if (mounted && added) {
        ScaffoldMessenger.of(context).showMotionSnackBar(
          SnackBar(content: Text(context.strings.downloadQueuedMessage)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showMotionSnackBar(
          SnackBar(content: Text(context.strings.libraryActionError)),
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
          .loadBookPreview(
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

/// TV controls use the same logical viewport as the catalog. Wide screens put
/// the editor and short filter labels side by side; large accessible text gets
/// its own row instead of being scaled down to fit a fixed-height toolbar.
class _TelevisionSearchToolbar extends StatelessWidget {
  const _TelevisionSearchToolbar({required this.editor, required this.filters});

  final Widget editor;
  final Widget filters;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      if (constraints.maxWidth >= 740 * textScale) {
        return Row(
          key: const ValueKey('tv-search-toolbar-inline'),
          children: [
            // The TV filter group now has three targets. Give it enough
            // width to stay on the editor row at the standard text size.
            Expanded(flex: 4, child: editor),
            const SizedBox(width: 8),
            Flexible(flex: 5, child: filters),
          ],
        );
      }
      return Column(
        key: const ValueKey('tv-search-toolbar-stacked'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [editor, const SizedBox(height: 4), filters],
      );
    },
  );
}

class _SearchFilters extends StatelessWidget {
  const _SearchFilters({
    required this.selectedKinds,
    required this.selectedSort,
    required this.options,
    required this.onOptionsChanged,
    required this.onKindsChanged,
    required this.onSortChanged,
    this.scopeFocusNode,
    this.compactLabels = false,
  });

  final Set<SearchKind> selectedKinds;
  final SearchSort selectedSort;
  final _SearchDisplayOptions options;
  final ValueChanged<_SearchDisplayOptions> onOptionsChanged;
  final ValueChanged<Set<SearchKind>> onKindsChanged;
  final ValueChanged<SearchSort> onSortChanged;
  final FocusNode? scopeFocusNode;
  final bool compactLabels;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Wrap(
      spacing: 8,
      runSpacing: compactLabels ? 4 : 8,
      children: [
        InputChip(
          key: scopeFocusNode == null
              ? null
              : const ValueKey('tv-search-kinds'),
          focusNode: scopeFocusNode,
          avatar: const AppIcon(AppIconAssets.systemFilter, size: 16),
          tooltip: compactLabels ? strings.searchScope : null,
          label: Text(
            compactLabels
                ? _kindsLabel(context, selectedKinds)
                : '${strings.searchScope}: ${_kindsLabel(context, selectedKinds)}',
          ),
          onPressed: () => _pickKinds(context),
        ),
        InputChip(
          key: compactLabels ? const ValueKey('tv-search-sort') : null,
          avatar: const AppIcon(AppIconAssets.systemSort, size: 16),
          tooltip: compactLabels ? strings.sort : null,
          label: Text(
            compactLabels
                ? _sortLabel(context, selectedSort)
                : '${strings.sort}: ${_sortLabel(context, selectedSort)}',
          ),
          onPressed: () => _pickSort(context),
        ),
        _SearchOptionsChip(options: options, onChanged: onOptionsChanged),
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
                  AppCheckboxListTile(
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

class _SearchDisplayOptions {
  const _SearchDisplayOptions({
    this.downloadedOnly = false,
    this.edition = SearchEditionFilter.all,
    this.groupEditions = false,
  });

  final bool downloadedOnly;
  final SearchEditionFilter edition;
  final bool groupEditions;

  _SearchDisplayOptions copyWith({
    bool? downloadedOnly,
    SearchEditionFilter? edition,
    bool? groupEditions,
  }) => _SearchDisplayOptions(
    downloadedOnly: downloadedOnly ?? this.downloadedOnly,
    edition: edition ?? this.edition,
    groupEditions: groupEditions ?? this.groupEditions,
  );
}

class _SearchOptionsChip extends StatelessWidget {
  const _SearchOptionsChip({required this.options, required this.onChanged});

  final _SearchDisplayOptions options;
  final ValueChanged<_SearchDisplayOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final label = options.downloadedOnly
        ? strings.searchOnlyDownloaded
        : options.edition != SearchEditionFilter.all
        ? _editionLabel(strings, options.edition)
        : strings.filter;
    return InputChip(
      key: const ValueKey('search-options'),
      avatar: const AppIcon(AppIconAssets.systemFilter, size: 16),
      label: Text(label),
      selected:
          options.downloadedOnly ||
          options.edition != SearchEditionFilter.all ||
          options.groupEditions,
      onPressed: () => _pickOptions(context),
    );
  }

  Future<void> _pickOptions(BuildContext context) async {
    var draft = options;
    final next = await showAdaptiveSheet<_SearchDisplayOptions>(
      context: context,
      title: context.strings.filter,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final strings = context.strings;
          return FilterPickerSheet(
            options: [
              AppCheckboxListTile(
                key: const ValueKey('search-only-downloaded'),
                value: draft.downloadedOnly,
                title: Text(strings.searchOnlyDownloaded),
                visualDensity: VisualDensity.compact,
                onChanged: (value) => setModalState(() {
                  draft = draft.copyWith(downloadedOnly: value);
                }),
              ),
              for (final edition in SearchEditionFilter.values)
                ListTile(
                  key: ValueKey('search-edition-${edition.name}'),
                  selected: draft.edition == edition,
                  title: Text(_editionLabel(strings, edition)),
                  visualDensity: VisualDensity.compact,
                  trailing: draft.edition == edition
                      ? AppIcon(
                          AppIconAssets.systemCheck,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => setModalState(() {
                    draft = draft.copyWith(edition: edition);
                  }),
                ),
              AppCheckboxListTile(
                key: const ValueKey('search-group-editions'),
                value: draft.groupEditions,
                title: Text(strings.searchGroupEditions),
                visualDensity: VisualDensity.compact,
                onChanged: (value) => setModalState(() {
                  draft = draft.copyWith(groupEditions: value);
                }),
              ),
            ],
            action: FilledButton(
              onPressed: () => Navigator.of(context).pop(draft),
              child: Text(strings.apply),
            ),
          );
        },
      ),
    );
    if (next != null && context.mounted) onChanged(next);
  }
}

String _editionLabel(AppStrings strings, SearchEditionFilter edition) =>
    switch (edition) {
      SearchEditionFilter.all => strings.searchEveryEdition,
      SearchEditionFilter.complete => strings.searchFullEditions,
      SearchEditionFilter.fragments => strings.searchFragmentEditions,
    };

class _SearchResultsTitle extends StatelessWidget {
  const _SearchResultsTitle({
    required this.searchFuture,
    required this.updates,
    required this.options,
  });

  final Future<SourceSearchResponse>? searchFuture;
  final ValueListenable<SourceSearchResponse?> updates;
  final _SearchDisplayOptions options;

  @override
  Widget build(BuildContext context) {
    final future = searchFuture;
    if (future == null) {
      return Text(context.strings.search);
    }

    return ValueListenableBuilder<SourceSearchResponse?>(
      valueListenable: updates,
      builder: (context, partial, _) => FutureBuilder<SourceSearchResponse>(
        future: future,
        builder: (context, snapshot) {
          final pending = snapshot.connectionState != ConnectionState.done;
          if (DesktopLayout.isActive(context) &&
              !pending &&
              snapshot.hasError &&
              partial?.hasMore != true &&
              snapshot.error is! SourceSearchCancelled) {
            return Text(context.strings.sourceSearchError);
          }
          final response = pending || snapshot.hasError
              ? partial
              : snapshot.data;
          if (response == null) {
            return Text(
              options.downloadedOnly
                  ? context.strings.searchingDownloads
                  : context.strings.searchingSources,
            );
          }
          final count = context.strings.sourceResultsCount(
            visibleSearchResults(
              response,
              edition: options.edition,
              groupEditions: false,
            ).length,
          );
          return Text(
            pending || response.isPartial
                ? context.strings.searchResultsSoFar(count)
                : count,
          );
        },
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.searchFuture,
    required this.updates,
    required this.options,
    required this.libraryStore,
    required this.playLoadingIds,
    required this.downloadLoadingIds,
    required this.history,
    required this.onHistoryTap,
    required this.onHistoryDelete,
    required this.onFavoriteToggle,
    required this.onLaterToggle,
    required this.onRetry,
    required this.onLoadMore,
    required this.onPlayPressed,
    required this.onDownloadPressed,
  });

  final String query;
  final Future<SourceSearchResponse>? searchFuture;
  final ValueListenable<SourceSearchResponse?> updates;
  final _SearchDisplayOptions options;
  final LibraryStore libraryStore;
  final Set<String> playLoadingIds;
  final Set<String> downloadLoadingIds;
  final List<SearchHistoryEntry> history;
  final ValueChanged<SearchHistoryEntry> onHistoryTap;
  final ValueChanged<SearchHistoryEntry> onHistoryDelete;
  final Future<void> Function(AudioBook book) onFavoriteToggle;
  final Future<void> Function(AudioBook book) onLaterToggle;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final ValueChanged<BookSearchResult> onPlayPressed;
  final ValueChanged<BookSearchResult> onDownloadPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final future = searchFuture;

    if (query.isEmpty && future == null) {
      return SliverToBoxAdapter(
        child: _SearchHistory(
          history: history,
          onTap: onHistoryTap,
          onDelete: onHistoryDelete,
        ),
      );
    }

    if (future == null) {
      return SliverToBoxAdapter(
        child: StatePlaceholder.empty(
          title: strings.searchShortQueryTitle,
          message: strings.searchShortQueryMessage,
        ),
      );
    }

    return ValueListenableBuilder<SourceSearchResponse?>(
      valueListenable: updates,
      builder: (context, partial, _) => FutureBuilder<SourceSearchResponse>(
        future: future,
        builder: (context, snapshot) {
          final pending = snapshot.connectionState != ConnectionState.done;
          if (pending &&
              (!kDebugMode || partial?.sourceStatuses.isNotEmpty != true) &&
              visibleSearchResults(
                partial,
                edition: options.edition,
                groupEditions: false,
              ).isEmpty) {
            return SliverToBoxAdapter(
              child: StatePlaceholder.loading(
                title: options.downloadedOnly
                    ? strings.searchingDownloads
                    : strings.searchingSources,
              ),
            );
          }

          // FutureBuilder retains an old error while a replacement future is
          // waiting. A cancelled previous request must not hide new partials.
          final continuationFailed =
              !pending &&
              snapshot.hasError &&
              (partial?.hasMore == true ||
                  partial?.retryContinuation != null) &&
              snapshot.error is! SourceSearchCancelled;
          if (!pending && snapshot.hasError && !continuationFailed) {
            if (snapshot.error is SourceSearchCancelled) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverToBoxAdapter(
              child: _SearchRecoveryNotice(partial: false, onRetry: onRetry),
            );
          }

          final response = pending || continuationFailed
              ? partial
              : snapshot.data;
          final results = visibleSearchResults(
            response,
            edition: options.edition,
            groupEditions: options.groupEditions,
          );
          final statuses =
              response?.sourceStatuses ?? const <SearchSourceStatus>[];
          final hasFailures = response?.hasFailures == true;
          final showDebugDiagnostics = kDebugMode && statuses.isNotEmpty;
          final showEmpty =
              !pending &&
              results.isEmpty &&
              !hasFailures &&
              response?.hasMore != true;
          if (showEmpty && !showDebugDiagnostics) {
            return SliverToBoxAdapter(
              child: StatePlaceholder.empty(
                title: strings.noSearchResults,
                message: strings.filteredNoSearchResults,
              ),
            );
          }

          final cached = response is DownloadedSearchResponse ? response : null;
          final catalog = cached == null
              ? ref.read(sourceCatalogServiceProvider)
              : null;
          return SliverMainAxisGroup(
            slivers: [
              if (pending)
                const SliverToBoxAdapter(
                  key: ValueKey('search-partial-progress'),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: AppLinearProgressIndicator(),
                  ),
                ),
              if (!pending && hasFailures)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SearchRecoveryNotice(
                      partial:
                          response?.results.isNotEmpty == true ||
                          response?.hasMore == true,
                      onRetry: onRetry,
                    ),
                  ),
                ),
              if (showDebugDiagnostics)
                SliverToBoxAdapter(
                  key: const ValueKey('search-source-status-sliver'),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SearchSourceStatuses(statuses: statuses),
                  ),
                ),
              if (results.isNotEmpty)
                SliverResponsiveTileGrid.builder(
                  key: const ValueKey('search-results-grid'),
                  stretchDesktopColumns: DesktopLayout.isActive(context),
                  maxColumns: DesktopLayout.isActive(context) ? 1 : 5,
                  itemCount: results.length,
                  itemKeyBuilder: (index) =>
                      ValueKey(_resultKey(results[index])),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final localBook = cached?.bookFor(result);
                    final key = _resultKey(result);
                    return _SearchResultCard(
                      result: result,
                      localBook: localBook,
                      baseBook: localBook == null
                          ? catalog!.audioBookForSearchResult(result)
                          : libraryCardBook(localBook).copyWith(
                              coverUrl: result.coverUri?.toString() ?? '',
                            ),
                      libraryStore: libraryStore,
                      isPlayLoading: playLoadingIds.contains(key),
                      isDownloadLoading: downloadLoadingIds.contains(key),
                      onFavoriteToggle: onFavoriteToggle,
                      onLaterToggle: onLaterToggle,
                      onPlayPressed: onPlayPressed,
                      onDownloadPressed: onDownloadPressed,
                    );
                  },
                ),
              if (showEmpty)
                SliverToBoxAdapter(
                  child: StatePlaceholder.empty(
                    title: strings.noSearchResults,
                    message: strings.filteredNoSearchResults,
                  ),
                ),
              if (!pending && response?.hasMore == true)
                SliverToBoxAdapter(
                  key: const ValueKey('search-load-more-sliver'),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: OutlinedButton(
                        key: const ValueKey('search-load-more'),
                        onPressed: onLoadMore,
                        child: Text(
                          continuationFailed
                              ? strings.searchRetryMore
                              : strings.searchLoadMore,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

final _searchPlaybackProvider =
    NotifierProvider.autoDispose<_SearchPlayback, AudioPlaybackState>(
      _SearchPlayback.new,
    );

class _SearchPlayback extends Notifier<AudioPlaybackState> {
  @override
  AudioPlaybackState build() {
    final controller = ref.watch(playbackControllerProvider);
    void changed() => state = controller.state;
    controller.addListener(changed);
    ref.onDispose(() => controller.removeListener(changed));
    return controller.state;
  }
}

final _searchSavedProgressProvider = Provider.autoDispose<Map<String, double>>((
  ref,
) {
  final snapshots =
      ref.watch(playbackProgressSnapshotsProvider).asData?.value ?? const [];
  final progress = <String, double>{};
  for (final snapshot in snapshots) {
    progress.putIfAbsent(
      snapshot.bookVersionId,
      () => (snapshot.percent / 100).clamp(0, 1).toDouble(),
    );
  }
  return progress;
});

final _searchDownloadIndexProvider = Provider.autoDispose<_SearchCardIndex>(
  (ref) => _SearchCardIndex(ref.watch(downloadManagerProvider)),
);

// These selectors invalidate only the affected visible card, not the result
// projection or sliver delegate, on a playback tick or download update.
class _SearchResultCard extends ConsumerWidget {
  const _SearchResultCard({
    required this.result,
    required this.localBook,
    required this.baseBook,
    required this.libraryStore,
    required this.isPlayLoading,
    required this.isDownloadLoading,
    required this.onFavoriteToggle,
    required this.onLaterToggle,
    required this.onPlayPressed,
    required this.onDownloadPressed,
  });

  final BookSearchResult result;
  final AudioPlaybackBook? localBook;
  final AudioBook baseBook;
  final LibraryStore libraryStore;
  final bool isPlayLoading;
  final bool isDownloadLoading;
  final Future<void> Function(AudioBook) onFavoriteToggle;
  final Future<void> Function(AudioBook) onLaterToggle;
  final ValueChanged<BookSearchResult> onPlayPressed;
  final ValueChanged<BookSearchResult> onDownloadPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = TickerMode.valuesOf(context).enabled;
    final local = localBook;
    final playbackProvider = _searchPlaybackProvider.select((state) {
      final book = state.book;
      final matchesRemote =
          local == null && _playbackBookMatchesResult(book, result);
      final isCurrent = local == null
          ? matchesRemote && book?.offlineOnly != true
          : book?.sourceId == local.sourceId &&
                book?.versionId == local.versionId &&
                book?.offlineOnly == true;
      return (
        current: isCurrent,
        playing: isCurrent && state.isPlaying,
        loading:
            isCurrent &&
            (state.status == AudioPlaybackStatus.loading ||
                state.status == AudioPlaybackStatus.buffering),
        progress: isCurrent || matchesRemote ? state.bookProgress : null,
      );
    });
    final playback = active
        ? ref.watch(playbackProvider)
        : ref.read(playbackProvider);
    final versionId = local?.versionId ?? _resultVersionId(result);
    final savedProgress = _searchSavedProgressProvider.select(
      (index) => index[versionId] ?? 0.0,
    );
    final audioBook = baseBook.copyWith(
      progress:
          playback.progress ??
          (active ? ref.watch(savedProgress) : ref.read(savedProgress)),
    );
    final downloadProvider = _searchDownloadIndexProvider.select(
      (index) => index.downloadFor(result),
    );
    final download = local == null
        ? (active ? ref.watch(downloadProvider) : ref.read(downloadProvider))
        : (state: BookCardDownloadState.downloaded, progress: 1.0);
    return BookCard(
      book: audioBook,
      desktopPresentation: DesktopBookPresentation.result,
      yearLabel: result.year?.toString(),
      isFavorite: libraryStore.isFavorite(audioBook),
      isLater: libraryStore.isLater(audioBook),
      onLaterPressed: () => onLaterToggle(audioBook),
      downloadState: download.state,
      downloadProgress: download.progress,
      isCurrentBook: playback.current,
      isPlaying: playback.playing,
      isPlaybackLoading: playback.loading,
      isPlayLoading: isPlayLoading && !playback.current,
      isDownloadLoading: isDownloadLoading,
      onFavoritePressed: () => onFavoriteToggle(audioBook),
      onDownloadPressed: local == null ? () => onDownloadPressed(result) : null,
      onPlay: () => onPlayPressed(result),
      onTap: local != null
          ? () => onPlayPressed(result)
          : () => unawaited(
              context.push(
                '/source-book/${result.sourceId}/${Uri.encodeComponent(result.sourceBookId)}',
                extra: result,
              ),
            ),
    );
  }
}

class _SearchSourceStatuses extends StatelessWidget {
  const _SearchSourceStatuses({required this.statuses});

  final List<SearchSourceStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ExpansionTile(
      key: const PageStorageKey('search-source-statuses'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.only(bottom: 4),
      title: Text(strings.searchSourceStatuses),
      children: [
        for (final status in statuses)
          ListTile(
            key: ValueKey('search-status-${status.sourceId}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(strings.sourceDisplayName(status.sourceId)),
            subtitle: Text(_describe(strings, status).join('\n')),
          ),
      ],
    );
  }

  static List<String> _describe(AppStrings strings, SearchSourceStatus status) {
    final failure = status.failureKind;
    return switch (status.participation) {
      SearchSourceParticipation.disabled => [strings.searchSourceDisabled],
      SearchSourceParticipation.filtered => [strings.searchSourceFiltered],
      SearchSourceParticipation.searching => [
        strings.searchSourceSearching,
        if (status.matchCount > 0)
          strings.sourceResultsCount(status.matchCount),
      ],
      SearchSourceParticipation.completed => [
        if (status.matchCount > 0 || failure == null)
          strings.sourceResultsCount(status.matchCount),
        if (failure != null)
          _describeSearchFailure(strings, failure, status.failedPage),
        if (status.paginationLimited) strings.searchSourcePaginationLimited,
        if (status.metadataIncomplete) strings.searchSourceMetadataIncomplete,
      ],
    };
  }
}

String _describeSearchFailure(
  AppStrings strings,
  SourceErrorKind failure,
  int? page,
) {
  final reason = switch (failure) {
    SourceErrorKind.accessRestricted => strings.searchSourceAccessRestricted,
    SourceErrorKind.rateLimited => strings.searchSourceRateLimited,
    SourceErrorKind.parser => strings.searchSourceUnreadable,
    _ => null,
  };
  return page == null
      ? (reason ?? strings.searchSourceLoadFailed)
      : strings.searchSourcePageLoadFailed(page, reason: reason);
}

class _SearchRecoveryNotice extends StatelessWidget {
  const _SearchRecoveryNotice({required this.partial, required this.onRetry});

  final bool partial;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return Wrap(
      key: const ValueKey('search-source-failures'),
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          partial
              ? strings.partialSearchUnavailable
              : strings.sourceSearchError,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          key: const ValueKey('search-retry'),
          onPressed: onRetry,
          child: Text(strings.partialSearchRetry),
        ),
      ],
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
                AppIconButton(
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

const _allSearchKinds = {
  SearchKind.title,
  SearchKind.author,
  SearchKind.narrator,
  SearchKind.series,
  SearchKind.genre,
};

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
  final selected = kinds.isEmpty ? _allSearchKinds : kinds;
  if (selected.length == _searchKindOptions.length) {
    return context.strings.all;
  }
  return selected.map((kind) => _kindLabel(context, kind)).join(', ');
}

typedef _CardDownload = ({BookCardDownloadState state, double progress});

class _SearchCardIndex {
  _SearchCardIndex(DownloadManager manager) {
    for (final task in manager.tasks) {
      if (task.status == DownloadTaskStatus.canceled) continue;
      final book = manager.bookForTask(task.id);
      final scope = book?.sourceId ?? task.sourceId;
      final byVersion = (scope, task.bookVersionId);
      _versions.putIfAbsent(byVersion, () => []).add(task);
      if (book == null) continue;
      final bookKey = (book.sourceId, book.versionId);
      _books[bookKey] = book;
      _bookTasks.putIfAbsent(bookKey, () => []).add(task);
      final externalId = book.sourceBookId;
      if (externalId != null) _bookKeys[(book.sourceId, externalId)] = bookKey;
      _bookKeys[(book.sourceId, book.id)] = bookKey;
    }
  }

  final _versions = <(String, String), List<DownloadTask>>{};
  final _books = <(String, String), AudioPlaybackBook>{};
  final _bookTasks = <(String, String), List<DownloadTask>>{};
  final _bookKeys = <(String, String), (String, String)>{};

  _CardDownload downloadFor(BookSearchResult result) {
    final version = (result.sourceId, _resultVersionId(result));
    final bookKey = _books.containsKey(version)
        ? version
        : _bookKeys[(result.sourceId, result.sourceBookId)] ??
              _bookKeys[(result.sourceId, 'izib-book-${result.sourceBookId}')];
    final book = _books[bookKey];
    if (book != null) {
      final tasks = _bookTasks[bookKey]!;
      return (
        state: downloadStateForBookTasks(tasks, book),
        progress: downloadProgressForBookTasks(tasks, book),
      );
    }
    final tasks = _versions[version] ?? const [];
    return (
      state: _downloadStateFromTasks(tasks, result.chapterCount),
      progress: _downloadProgressFromTasks(tasks, result.chapterCount),
    );
  }
}

BookCardDownloadState _downloadStateForResult(
  DownloadManager manager,
  BookSearchResult result,
) {
  final book = _playbackBookForResult(manager, result);
  if (book != null) {
    return downloadStateForBook(manager, book);
  }

  return _SearchCardIndex(manager).downloadFor(result).state;
}

BookCardDownloadState _downloadStateFromTasks(
  List<DownloadTask> tasks,
  int? chapterCount,
) {
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
    if (chapterCount == null || completedCount >= chapterCount) {
      return BookCardDownloadState.downloaded;
    }
    return BookCardDownloadState.paused;
  }
  return BookCardDownloadState.none;
}

double _downloadProgressFromTasks(List<DownloadTask> tasks, int? chapterCount) {
  if (tasks.isEmpty) {
    return 0;
  }
  final summed = tasks.fold<double>(
    0,
    (sum, task) => sum + task.progress.clamp(0, 1).toDouble(),
  );
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
