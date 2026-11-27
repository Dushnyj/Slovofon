import '../../ui/motion/motion_tooltip.dart';
import '../../ui/motion/app_motion.dart';
import '../../ui/motion/motion_progress_indicator.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/app_strings.dart';
import '../../app/localization/duration_label.dart';
import '../../domain/models/audio_book.dart';
import '../../domain/models/book_version.dart';
import '../../services/audio/audio_persistence.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/home/home_listening_visibility_store.dart';
import '../../services/library/library_store.dart';
import '../../services/sources/source_book_cache.dart';
import '../../services/sources/source_catalog_provider.dart';
import '../../services/sources/source_catalog_service.dart';
import '../../services/deep_links/slovofon_deep_link.dart';
import '../../sources/sources.dart';
import '../../ui/components/app_bar_text.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/book_fragment_badge.dart';
import '../../ui/components/chapter_tile.dart';
import '../../ui/components/app_buttons.dart';
import '../../ui/components/download_action_button.dart';
import '../../ui/components/mini_player_bar.dart';
import '../../ui/components/section_header.dart';
import '../../ui/components/source_badge.dart';
import '../../ui/adaptive/slovofon_shell.dart';
import '../../ui/adaptive/adaptive_sheet.dart';
import '../../ui/adaptive/desktop_layout.dart';
import '../../ui/adaptive/desktop_book_details_layout.dart';
import '../../ui/adaptive/television_layout.dart';
import '../../ui/adaptive/television_shell.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';
import '../shared/playback_resume.dart';
import 'source_book_error_text.dart';

bool _sameBookRef(SourceBookRef? left, SourceBookRef right) =>
    left?.sourceId == right.sourceId &&
    left?.sourceBookId == right.sourceBookId;

class SourceBookDetailsScreen extends ConsumerStatefulWidget {
  const SourceBookDetailsScreen({
    required this.ref,
    this.initialResult,
    super.key,
  });

  final SourceBookRef ref;
  final BookSearchResult? initialResult;

  @override
  ConsumerState<SourceBookDetailsScreen> createState() {
    return _SourceBookDetailsScreenState();
  }
}

class _SourceBookDetailsScreenState
    extends ConsumerState<SourceBookDetailsScreen> {
  late Future<SourceBookSnapshot> _snapshotFuture;
  late Future<BookVersionDetails> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  @override
  void didUpdateWidget(SourceBookDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameBookRef(oldWidget.ref, widget.ref)) {
      _loadSnapshot();
    }
  }

  void _loadSnapshot({bool forceRefresh = false}) {
    final catalog = ref.read(sourceCatalogServiceProvider);
    // A retry can fail before the next frame subscribes its FutureBuilder.
    // Keep the original futures so the UI can still render their states.
    _snapshotFuture = catalog.loadBookPreview(
      widget.ref,
      forceRefresh: forceRefresh,
    )..ignore();
    _detailsFuture = catalog.loadBookDetails(widget.ref)..ignore();
  }

  void _retrySnapshot() => setState(() => _loadSnapshot(forceRefresh: true));

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final desktop = DesktopLayout.isActive(context);
    final television = TelevisionLayout.isActive(context);
    final body = SafeArea(
      top: false,
      child: FutureBuilder<SourceBookSnapshot>(
        key: ValueKey((widget.ref.sourceId, widget.ref.sourceBookId)),
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            final seed = widget.initialResult;
            final catalog = ref.read(sourceCatalogServiceProvider);
            return FutureBuilder<BookVersionDetails>(
              future: _detailsFuture,
              builder: (context, details) {
                final value = details.data;
                final initial = _sameBookRef(seed?.ref, widget.ref)
                    ? seed
                    : null;
                final book = value != null
                    ? catalog.audioBookForDetails(value, 0)
                    : initial == null
                    ? null
                    : catalog.audioBookForSearchResult(initial);
                return book == null
                    ? const Center(child: AppCircularProgressIndicator())
                    : _SourceBookLoadingSummary(book: book);
              },
            );
          }

          if (snapshot.hasError) {
            final errorText = sourceBookErrorText(
              strings: strings,
              sourceId: widget.ref.sourceId,
              error: snapshot.error!,
            );
            return _DetailsError(
              title: errorText.title,
              message: errorText.message,
              onRetry: _retrySnapshot,
            );
          }

          final book = snapshot.data!;
          return _SourceBookDetailsBody(snapshot: book);
        },
      ),
    );
    if (television) {
      return TelevisionStandaloneShell(
        title: strings.bookDetails,
        selectedIndex: 1,
        child: body,
      );
    }
    final screen = Scaffold(
      appBar: AppBar(
        toolbarHeight: appBarToolbarHeight(context),
        title: preserveAppBarTextScale(context, Text(strings.bookDetails)),
      ),
      bottomNavigationBar: desktop
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayerBar(),
                SlovofonBottomNavigationBar(
                  selectedIndex: -1,
                  onDestinationSelected: (index) =>
                      goToSlovofonTab(context, index),
                ),
              ],
            ),
      body: body,
    );
    if (desktop) {
      return DesktopStandaloneShell(selectedIndex: 1, child: screen);
    }
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 450) {
          unawaited(Navigator.of(context).maybePop());
        }
      },
      child: screen,
    );
  }
}

class _SourceBookLoadingSummary extends StatelessWidget {
  const _SourceBookLoadingSummary({required this.book});

  final AudioBook book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credits = [
      book.author,
      book.narrator,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    return ListView(
      key: const ValueKey('source-details-loading-summary'),
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(
              title: book.title,
              sourceId: book.sourceId,
              imageUrl: book.coverUrl,
              width: 116,
              height: 166,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: theme.textTheme.titleLarge),
                  if (credits.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(credits, style: theme.textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 8),
                  SourceBadge(sourceId: book.sourceId),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Center(child: AppCircularProgressIndicator()),
      ],
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
  bool _showFullDescription = false;
  bool _isResolvingPlay = false;
  int? _resolvingChapterIndex;
  int _playInvocation = 0;
  String? _cachedSnapshotKey;
  Future<List<BookSearchResult>>? _otherNarrationsFuture;
  SourceSearchCancellation? _otherNarrationsCancellation;

  @override
  void initState() {
    super.initState();
    _cacheFreshSnapshot(widget.snapshot);
  }

  @override
  void didUpdateWidget(covariant _SourceBookDetailsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.details.ref.sourceId !=
            widget.snapshot.details.ref.sourceId ||
        oldWidget.snapshot.details.ref.sourceBookId !=
            widget.snapshot.details.ref.sourceBookId) {
      _otherNarrationsCancellation?.cancel();
      _otherNarrationsCancellation = null;
      _otherNarrationsFuture = null;
      _cacheFreshSnapshot(widget.snapshot);
    }
  }

  @override
  void dispose() {
    _otherNarrationsCancellation?.cancel();
    super.dispose();
  }

  void _searchOtherNarrations() {
    final cancellation = SourceSearchCancellation();
    _otherNarrationsCancellation?.cancel();
    _otherNarrationsCancellation = cancellation;
    final catalog = ref.read(sourceCatalogServiceProvider);
    final snapshot = widget.snapshot;
    final timer = Timer(const Duration(seconds: 12), cancellation.cancel);
    final future = catalog
        .findOtherNarrations(snapshot, cancellation: cancellation)
        .whenComplete(timer.cancel);
    future.ignore();
    setState(() {
      _otherNarrationsFuture = future;
    });
  }

  Widget _otherNarrationsSection() => _OtherNarrationsSection(
    initialAlternatives: widget.snapshot.details.alternatives.where(
      (alternative) =>
          !_sameBookRef(alternative.ref, widget.snapshot.details.ref),
    ),
    future: _otherNarrationsFuture,
    onSearch: _searchOtherNarrations,
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final desktop = DesktopLayout.isActive(context);
    final television = TelevisionLayout.isActive(context);
    final colorScheme = Theme.of(context).colorScheme;
    final downloadManager = ref.watch(downloadManagerProvider);
    final libraryStore = ref.watch(libraryStoreProvider);
    final playbackController = ref.watch(playbackControllerProvider);
    final progressSnapshots =
        ref.watch(playbackProgressSnapshotsProvider).asData?.value ??
        const <PlaybackProgressSnapshot>[];
    final snapshot = widget.snapshot;
    final details = snapshot.details;
    final version = details.version;
    final audioBook = snapshot.audioBook;
    final playbackBook = snapshot.playbackBook;
    final bookDownloadState = downloadStateForBook(
      downloadManager,
      playbackBook,
    );
    final bookDownloadProgress = downloadProgressForBook(
      downloadManager,
      playbackBook,
    );
    final savedProgress = playbackProgressForBook(
      playbackBook,
      progressSnapshots,
      fallbackVersionId: widget.snapshot.details.ref.sourceBookId,
    );
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final visibleChapterCount =
        _showAllChapters || snapshot.chapters.length <= _collapsedChapterCount
        ? snapshot.chapters.length
        : _collapsedChapterCount;

    return ListenableBuilder(
      listenable: playbackController,
      builder: (context, _) {
        final playbackState = playbackController.state;
        final isCurrentBook = _playbackMatchesBook(
          playbackState.book,
          playbackBook,
        );
        final isPlaybackLoading =
            isCurrentBook &&
            (playbackState.status == AudioPlaybackStatus.loading ||
                playbackState.status == AudioPlaybackStatus.buffering);
        final isPlaying = isCurrentBook && playbackState.isPlaying;
        final showPlayLoading = _isResolvingPlay || isPlaybackLoading;
        final effectiveProgress = isCurrentBook
            ? playbackState.bookProgress
            : ((savedProgress?.percent ?? 0) / 100).clamp(0, 1).toDouble();

        final actions = Wrap(
          spacing: television
              ? 6
              : desktop
              ? 12
              : 18,
          runSpacing: desktop ? 12 : 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (television)
              TelevisionBookPlayButton(
                buttonKey: showPlayLoading
                    ? null
                    : const ValueKey('source-details-play'),
                tooltip: isPlaying ? strings.pause : strings.play,
                onPressed: showPlayLoading
                    ? null
                    : () => _handlePlayButton(
                        context,
                        playbackController,
                        isCurrentBook,
                        isPlaying,
                      ),
                icon: showPlayLoading
                    ? SizedBox.square(
                        key: const ValueKey('source-details-play-loading'),
                        dimension: 18,
                        child: AppCircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : AppIcon(
                        isPlaying
                            ? AppIconAssets.playerPause
                            : AppIconAssets.playerPlay,
                        size: 20,
                      ),
              )
            else if (desktop)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: showPlayLoading
                      ? null
                      : const ValueKey('source-details-play'),
                  onPressed: showPlayLoading
                      ? null
                      : () => _handlePlayButton(
                          context,
                          playbackController,
                          isCurrentBook,
                          isPlaying,
                        ),
                  icon: showPlayLoading
                      ? SizedBox.square(
                          key: const ValueKey('source-details-play-loading'),
                          dimension: 24,
                          child: AppCircularProgressIndicator(
                            strokeWidth: 2.7,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : AppIcon(
                          isPlaying
                              ? AppIconAssets.playerPause
                              : AppIconAssets.playerPlay,
                        ),
                  label: Text(
                    isPlaying ? strings.pause : strings.play,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (showPlayLoading)
              SizedBox.square(
                dimension: 36,
                child: Center(
                  child: SizedBox.square(
                    key: const ValueKey('source-details-play-loading'),
                    dimension: 24,
                    child: AppCircularProgressIndicator(
                      strokeWidth: 2.7,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              )
            else
              AppIconActionButton(
                buttonKey: const ValueKey('source-details-play'),
                tooltip: isPlaying ? strings.pause : strings.play,
                onPressed: () => _handlePlayButton(
                  context,
                  playbackController,
                  isCurrentBook,
                  isPlaying,
                ),
                iconAsset: isPlaying
                    ? AppIconAssets.playerPause
                    : AppIconAssets.playerPlay,
                foregroundColor: colorScheme.primary,
                buttonSize: desktop ? 44 : 48,
                iconSize: 26,
              ),
            DownloadActionButton(
              buttonKey: const ValueKey('source-details-download'),
              state: bookDownloadState,
              progress: bookDownloadProgress,
              size: television
                  ? 36
                  : desktop
                  ? 44
                  : 48,
              onPressed: () =>
                  unawaited(_runBookDownload(downloadManager, widget.snapshot)),
            ),
            AppIconActionButton(
              buttonKey: const ValueKey('source-details-favorite'),
              tooltip: libraryStore.isFavorite(audioBook)
                  ? strings.removeFavorite
                  : strings.addFavorite,
              onPressed: () async {
                final added = await libraryStore.toggleFavorite(audioBook);
                if (added) {
                  _cacheFreshSnapshot(widget.snapshot);
                }
              },
              iconAsset: libraryStore.isFavorite(audioBook)
                  ? AppIconAssets.bookFavoriteFilled
                  : AppIconAssets.bookFavorite,
              foregroundColor: libraryStore.isFavorite(audioBook)
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
              buttonSize: television
                  ? 36
                  : desktop
                  ? 44
                  : 48,
              iconSize: television ? 20 : 25,
            ),
            AppIconActionButton(
              buttonKey: const ValueKey('source-details-share'),
              tooltip: strings.share,
              onPressed: () => _showShareSheet(context, version),
              iconAsset: AppIconAssets.systemShare,
              foregroundColor: colorScheme.onSurfaceVariant,
              buttonSize: television
                  ? 36
                  : desktop
                  ? 44
                  : 48,
              iconSize: television ? 20 : 25,
            ),
            if (television)
              AppIconButton(
                key: const ValueKey('source-details-later'),
                tooltip: libraryStore.isLater(audioBook)
                    ? strings.removeFromLater
                    : strings.addToLater,
                onPressed: () async {
                  try {
                    final added = await libraryStore.toggleLater(audioBook);
                    if (added) _cacheFreshSnapshot(widget.snapshot);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showMotionSnackBar(
                        SnackBar(content: Text(strings.libraryActionError)),
                      );
                    }
                  }
                },
                icon: AppIcon(
                  libraryStore.isLater(audioBook)
                      ? AppIconAssets.systemCheck
                      : AppIconAssets.bookDuration,
                  size: 20,
                ),
              ),
          ],
        );
        final informationChildren = <Widget>[
          if ((version.description ?? '').trim().isNotEmpty) ...[
            if (!desktop && !television) const SizedBox(height: 18),
            if (television)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  strings.description,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            else
              SectionHeader(title: strings.description),
            _CollapsibleDescription(
              text: version.description!.trim(),
              expanded: _showFullDescription,
              onToggle: () {
                setState(() => _showFullDescription = !_showFullDescription);
              },
            ),
          ],
          _SourceFacts(version: version),
        ];
        final chapterChildren = <Widget>[
          if (!television) SectionHeader(title: strings.chapters),
          for (var index = 0; index < visibleChapterCount; index++)
            Builder(
              builder: (context) {
                final sourceChapter = snapshot.chapters[index];
                final audioChapter = playbackBook.chapters[index];
                final chapterProgress =
                    savedProgress?.currentChapterId == audioChapter.id
                    ? ((savedProgress?.currentPositionMs ?? 0) /
                              (audioChapter.duration.inMilliseconds <= 0
                                  ? 1
                                  : audioChapter.duration.inMilliseconds))
                          .clamp(0, 1)
                          .toDouble()
                    : 0.0;
                final activeChapter = playbackState.currentChapter;
                final isCurrentChapter =
                    isCurrentBook &&
                    activeChapter != null &&
                    _sameChapter(audioChapter, activeChapter);
                return ChapterTile(
                  key: ValueKey('source-details-chapter-$index'),
                  index: index + 1,
                  title: sourceChapter.title,
                  durationLabel: context.strings.formatDuration(
                    Duration(milliseconds: sourceChapter.durationMs ?? 0),
                  ),
                  progress: isCurrentChapter
                      ? playbackState.chapterProgress
                      : chapterProgress,
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
                  isCurrent: isCurrentChapter,
                  onTap: () {
                    final activeIndex = isCurrentBook
                        ? _chapterIndexIn(playbackState.book!, audioChapter)
                        : null;
                    if (activeIndex != null) {
                      unawaited(playbackController.playChapterAt(activeIndex));
                      return;
                    }
                    unawaited(_play(context, ref, index));
                  },
                  onDownloadPressed: () =>
                      unawaited(_runChapterDownload(downloadManager, index)),
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
        ];
        final bodyChildren = <Widget>[
          ...informationChildren,
          _otherNarrationsSection(),
          const SizedBox(height: 20),
          ...chapterChildren,
        ];
        if (desktop || television) {
          return DesktopBookDetailsLayout(
            key: const ValueKey('desktop-source-details-content'),
            summary: DesktopBookSummary(
              coverBuilder: (width) => BookCover(
                title: version.title,
                sourceId: version.sourceId,
                progress: effectiveProgress,
                imageUrl: version.coverUrl,
                width: width,
                height: width * 1.43,
                showProgressPercent: false,
              ),
              source: SourceBadge(sourceId: playbackBook.sourceId, maxLines: 2),
              metadata: _SourceHeaderDetails(
                snapshot: snapshot,
                section: _SourceHeaderSection.identity,
              ),
              details: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SourceHeaderDetails(
                    snapshot: snapshot,
                    section: _SourceHeaderSection.facts,
                  ),
                  if (effectiveProgress > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${strings.bookProgress}: '
                      '${(effectiveProgress * 100).round()}%',
                    ),
                  ],
                ],
              ),
              actions: actions,
            ),
            contentSlivers: [SliverList.list(children: bodyChildren)],
            televisionTabs: [
              TelevisionBookDetailsTab(
                title: strings.chapters,
                slivers: [SliverList.list(children: chapterChildren)],
              ),
              TelevisionBookDetailsTab(
                title: strings.information,
                slivers: [
                  SliverList.list(
                    children: [
                      ...informationChildren,
                      const SizedBox(height: 12),
                      _otherNarrationsSection(),
                    ],
                  ),
                ],
              ),
            ],
          );
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 40 + bottomInset),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 640;
                final coverWidth = compact ? 116.0 : 148.0;
                final cover = SizedBox(
                  width: coverWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BookCover(
                        title: version.title,
                        sourceId: version.sourceId,
                        progress: effectiveProgress,
                        imageUrl: version.coverUrl,
                        width: coverWidth,
                        height: compact ? 166 : 212,
                      ),
                      const SizedBox(height: 5),
                      SourceBadge(
                        sourceId: playbackBook.sourceId,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
                final header = _SourceHeaderDetails(snapshot: snapshot);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    cover,
                    SizedBox(width: compact ? 12 : 24),
                    Expanded(child: header),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            actions,
            ...bodyChildren,
          ],
        );
      },
    );
  }

  Future<void> _handlePlayButton(
    BuildContext context,
    PlaybackController playbackController,
    bool isCurrentBook,
    bool isPlaying,
  ) async {
    if (isCurrentBook) {
      await playbackController.togglePlayPause();
      return;
    }
    await _play(context, ref, null);
  }

  Future<void> _play(
    BuildContext context,
    WidgetRef ref,
    int? chapterIndex,
  ) async {
    if (_isResolvingPlay && _resolvingChapterIndex == chapterIndex) {
      return;
    }
    final invocation = ++_playInvocation;
    setState(() {
      _isResolvingPlay = true;
      _resolvingChapterIndex = chapterIndex;
    });
    final playback = ref.read(playbackControllerProvider);
    final selection = playback.beginPlaybackSelection();
    final snapshot = widget.snapshot;
    final requestedBook = snapshot.playbackBook;
    final requestedChapter = chapterIndex == null
        ? null
        : requestedBook.chapters[chapterIndex];
    try {
      final playbackBook = await ref
          .read(downloadManagerProvider)
          .offlinePlaybackBook(requestedBook);
      if (!mounted || !playback.isPlaybackSelectionCurrent(selection)) return;
      final progressSnapshots =
          await ref.read(playbackPersistenceStoreProvider)?.loadProgress() ??
          const [];
      if (!mounted || !playback.isPlaybackSelectionCurrent(selection)) return;
      final resumePoint = playbackResumePointForBook(
        playbackBook,
        progressSnapshots,
        fallbackVersionId: snapshot.details.ref.sourceBookId,
      );
      final targetChapterIndex = requestedChapter == null
          ? resumePoint.chapterIndex
          : _chapterIndexIn(playbackBook, requestedChapter);
      if (targetChapterIndex == null) {
        throw StateError('The selected chapter is no longer available.');
      }
      final targetPosition = resumePoint.chapterIndex == targetChapterIndex
          ? resumePoint.position
          : Duration.zero;
      await playback.loadBook(
        playbackBook,
        chapterIndex: targetChapterIndex,
        position: targetPosition,
        autoPlay: true,
        replayChapterAtEnd: chapterIndex != null,
        playbackSelection: selection,
      );
      if (!mounted || !playback.isPlaybackSelectionCurrent(selection)) return;
      await ref
          .read(homeListeningVisibilityStoreProvider)
          .show(homeListeningBookKeyFor(playbackBook));
      if (!mounted || !playback.isPlaybackSelectionCurrent(selection)) return;
      ref.invalidate(playbackProgressSnapshotsProvider);
    } catch (_) {
      if (mounted &&
          context.mounted &&
          playback.isPlaybackSelectionCurrent(selection)) {
        ScaffoldMessenger.of(context).showMotionSnackBar(
          SnackBar(content: Text(context.strings.savedBookPlaybackError)),
        );
      }
    } finally {
      if (mounted && invocation == _playInvocation) {
        setState(() {
          _isResolvingPlay = false;
          _resolvingChapterIndex = null;
        });
      }
    }
  }

  Future<void> _showShareSheet(
    BuildContext context,
    BookVersion version,
  ) async {
    final strings = context.strings;
    final sourceUrl = _trimOrNull(version.sourceUrl);
    final slovofonLink = slovofonBookDeepLink(
      sourceId: version.sourceId,
      sourceBookId: version.sourceBookId,
    ).toString();

    await showAdaptiveSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.share,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _ShareOption(
                  iconAsset: AppIconAssets.systemShare,
                  title: strings.shareSlovofonLink,
                  subtitle: slovofonLink,
                  onTap: () => _copyShareLink(context, slovofonLink),
                ),
                if (sourceUrl != null)
                  _ShareOption(
                    iconAsset: AppIconAssets.bookSource,
                    title: strings.shareSourceLink,
                    subtitle: sourceUrl,
                    onTap: () => _copyShareLink(context, sourceUrl),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyShareLink(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showMotionSnackBar(
      SnackBar(content: Text(context.strings.shareLinkCopied)),
    );
  }

  void _cacheFreshSnapshot(SourceBookSnapshot snapshot) {
    final playbackBook = snapshot.playbackBook;
    final key = '${playbackBook.sourceId}:${playbackBook.versionId}';
    if (_cachedSnapshotKey == key) {
      return;
    }
    _cachedSnapshotKey = key;
    unawaited(
      _writeSnapshotCache(snapshot).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Failed to cache source book metadata: $error');
        return snapshot;
      }),
    );
  }

  Future<void> _runBookDownload(
    DownloadManager downloadManager,
    SourceBookSnapshot snapshot,
  ) async {
    await runBookCardDownloadAction(downloadManager, snapshot.playbackBook);
  }

  Future<void> _runChapterDownload(
    DownloadManager downloadManager,
    int chapterIndex,
  ) async {
    final playbackBook = widget.snapshot.playbackBook;
    final chapter = playbackBook.chapters[chapterIndex];
    await runChapterCardDownloadAction(downloadManager, playbackBook, chapter);
  }

  Future<SourceBookSnapshot> _writeSnapshotCache(
    SourceBookSnapshot snapshot,
  ) async {
    final cache = SourceBookCache(
      downloadStorage: ref.read(downloadStorageProvider),
      downloadManager: ref.read(downloadManagerProvider),
      libraryStore: ref.read(libraryStoreProvider),
    );
    return cache.refresh(snapshot);
  }
}

class _OtherNarrationsSection extends StatelessWidget {
  const _OtherNarrationsSection({
    required this.initialAlternatives,
    required this.future,
    required this.onSearch,
  });

  final Iterable<BookSearchResult> initialAlternatives;
  final Future<List<BookSearchResult>>? future;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BookSearchResult>>(
      future: future,
      builder: (context, snapshot) {
        final alternatives = snapshot.data ?? initialAlternatives;
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alternatives.isNotEmpty) ...[
                SectionHeader(title: context.strings.otherNarrations),
                const SizedBox(height: 6),
              ],
              for (final alternative in alternatives)
                _OtherNarrationTile(alternative: alternative),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: AppCircularProgressIndicator(),
                )
              else if (future == null || snapshot.hasError)
                OutlinedButton(
                  key: const ValueKey('source-details-find-other-narrations'),
                  onPressed: onSearch,
                  child: Text(context.strings.otherNarrations),
                )
              else if (alternatives.isEmpty)
                Text(context.strings.noSearchResults),
            ],
          ),
        );
      },
    );
  }
}

class _OtherNarrationTile extends StatelessWidget {
  const _OtherNarrationTile({required this.alternative});

  final BookSearchResult alternative;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final narrator = _trimOrNull(alternative.narrator);
    final duration = context.strings.formatDuration(
      alternative.duration ?? Duration.zero,
    );

    return Card(
      key: ValueKey(
        'other-narration-${alternative.sourceId}-${alternative.sourceBookId}',
      ),
      child: InkWell(
        hoverDuration: AppMotion.of(context).duration(
          full: const Duration(milliseconds: 50),
          reduced: const Duration(milliseconds: 40),
        ),
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          unawaited(
            context.push(
              '/source-book/${alternative.sourceId}/${Uri.encodeComponent(alternative.sourceBookId)}',
              extra: alternative,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              AppIcon(
                AppIconAssets.bookNarrator,
                size: 22,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      narrator ?? context.strings.narratorUnknown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SourceBadge(sourceId: alternative.sourceId),
                        if (alternative.duration != null)
                          Text(
                            duration,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppIcon(
                AppIconAssets.systemForward,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsibleDescription extends StatelessWidget {
  const _CollapsibleDescription({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final collapsedText = _collapsedDescription(text);
    final canCollapse = collapsedText != text;
    final visibleText = expanded || !canCollapse ? text : collapsedText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          visibleText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        if (canCollapse)
          TextButton(
            key: const ValueKey('source-details-description-toggle'),
            onPressed: onToggle,
            style: TelevisionLayout.isActive(context)
                ? null
                : TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
            child: Text(
              expanded ? strings.hideDescription : strings.showFullDescription,
            ),
          ),
      ],
    );
  }
}

class _SourceFacts extends StatelessWidget {
  const _SourceFacts({required this.version});

  final BookVersion version;

  @override
  Widget build(BuildContext context) {
    final sourceUrl = _trimOrNull(version.sourceUrl);
    final genre = version.genres.where(_isMeaningful).join(', ');
    final stats = _SourceStats.fromRaw(version.rawSourceDataJson);

    if (sourceUrl == null && genre.isEmpty && !stats.hasAny) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          if (sourceUrl != null)
            _SourceFactTile(
              label: context.strings.sourcePage,
              child: _SourceUrlLink(url: sourceUrl),
            ),
          if (genre.isNotEmpty)
            _SourceFactTile(
              label: context.strings.genre,
              child: Text(
                genre,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          if (stats.hasAny)
            _SourceFactTile(
              label: context.strings.sourceStats,
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (stats.views != null)
                    _CounterIcon(
                      iconAsset: AppIconAssets.sourceViews,
                      label: _formatInt(stats.views!),
                    ),
                  if (stats.likes != null)
                    _CounterIcon(
                      iconAsset: AppIconAssets.sourceLikes,
                      label: _formatInt(stats.likes!),
                    ),
                  if (stats.dislikes != null)
                    _CounterIcon(
                      iconAsset: AppIconAssets.sourceDislikes,
                      label: _formatInt(stats.dislikes!),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceFactTile extends StatelessWidget {
  const _SourceFactTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: TelevisionLayout.isActive(context)
            ? colorScheme.surfaceContainerLow
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }
}

class _SourceUrlLink extends StatelessWidget {
  const _SourceUrlLink({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (TelevisionLayout.isActive(context)) {
      return TextButton(
        key: const ValueKey('tv-source-details-url'),
        onPressed: () => _openExternalUrl(context, url),
        style: TextButton.styleFrom(
          alignment: AlignmentDirectional.centerStart,
        ),
        child: Text(
          url,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    return InkWell(
      hoverDuration: AppMotion.of(context).duration(
        full: const Duration(milliseconds: 50),
        reduced: const Duration(milliseconds: 40),
      ),
      onTap: () => _openExternalUrl(context, url),
      child: Text(
        url,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: colorScheme.primary,
        ),
      ),
    );
  }
}

class _CounterIcon extends StatelessWidget {
  const _CounterIcon({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(iconAsset, size: 18, color: colorScheme.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppIcon(iconAsset, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _SourceStats {
  const _SourceStats({this.views, this.likes, this.dislikes});

  factory _SourceStats.fromRaw(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _SourceStats();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return const _SourceStats();
      }
      return _SourceStats(
        views: _intFromAny(
          decoded['views'] ??
              decoded['viewCount'] ??
              decoded['viewsCount'] ??
              decoded['visits'],
        ),
        likes: _intFromAny(decoded['likes'] ?? decoded['likeCount']),
        dislikes: _intFromAny(decoded['dislikes'] ?? decoded['dislikeCount']),
      );
    } on Object {
      return const _SourceStats();
    }
  }

  final int? views;
  final int? likes;
  final int? dislikes;

  bool get hasAny => views != null || likes != null || dislikes != null;
}

enum _SourceHeaderSection { all, identity, facts }

class _SourceHeaderDetails extends StatelessWidget {
  const _SourceHeaderDetails({
    required this.snapshot,
    this.section = _SourceHeaderSection.all,
  });

  final SourceBookSnapshot snapshot;
  final _SourceHeaderSection section;

  @override
  Widget build(BuildContext context) {
    final version = snapshot.details.version;
    final identity = section != _SourceHeaderSection.facts;
    final facts = section != _SourceHeaderSection.identity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (identity) ...[
          Text(
            version.title,
            style: TelevisionLayout.isActive(context)
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.headlineSmall,
          ),
          if (version.isFragment) const BookFragmentBadge(),
          const SizedBox(height: 8),
        ],
        if (facts && version.authors.isNotEmpty)
          _HeaderMetaLinks(
            iconAsset: AppIconAssets.bookAuthor,
            values: version.authors,
            searchKind: SearchKind.author,
          ),
        if (identity && version.narrators.isNotEmpty)
          _HeaderMetaLinks(
            iconAsset: AppIconAssets.bookNarrator,
            values: version.narrators,
            searchKind: SearchKind.narrator,
          ),
        if (facts && _trimOrNull(version.seriesTitle) != null)
          _HeaderMetaLinks(
            iconAsset: AppIconAssets.bookSeries,
            values: [_seriesLabel(version.seriesTitle, version.seriesNumber)!],
            searchQueries: [version.seriesTitle!],
            searchKind: SearchKind.series,
          ),
        if (facts) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (version.publishedYear != null)
                _HeaderInlineMeta(
                  iconAsset: AppIconAssets.bookYear,
                  label: '${version.publishedYear}',
                ),
              if (snapshot.audioBook.durationLabel.trim().isNotEmpty &&
                  snapshot.audioBook.durationLabel != '—')
                _HeaderInlineMeta(
                  iconAsset: AppIconAssets.bookDuration,
                  label: context.strings.formatDurationLabel(
                    snapshot.audioBook.durationLabel,
                  ),
                ),
              _HeaderInlineMeta(
                iconAsset: AppIconAssets.playerChapters,
                label: context.strings.chaptersCount(snapshot.chapters.length),
              ),
              if (_ratingLabel(context.strings, version.ratingValue) != null)
                _HeaderInlineMeta(
                  iconAsset: AppIconAssets.bookRating,
                  label: _ratingLabel(context.strings, version.ratingValue)!,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _HeaderMetaLinks extends StatelessWidget {
  const _HeaderMetaLinks({
    required this.iconAsset,
    required this.values,
    required this.searchKind,
    this.searchQueries,
  });

  final String iconAsset;
  final List<String> values;
  final List<String>? searchQueries;
  final SearchKind searchKind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final television = TelevisionLayout.isActive(context);
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.2,
      fontWeight: FontWeight.w600,
    );
    final linkStyle = textStyle?.copyWith(
      color: colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: television ? 12 : 2),
            child: AppIcon(
              iconAsset,
              size: 15,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 0,
              runSpacing: 2,
              children: [
                for (var index = 0; index < values.length; index++) ...[
                  if (television)
                    TextButton(
                      key: ValueKey(
                        'tv-source-details-${searchKind.name}-$index',
                      ),
                      onPressed: () => _openScopedSearch(
                        context,
                        searchQueries?[index] ?? values[index],
                        searchKind,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        alignment: AlignmentDirectional.centerStart,
                      ),
                      child: Text(
                        values[index],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  else
                    InkWell(
                      hoverDuration: AppMotion.of(context).duration(
                        full: const Duration(milliseconds: 50),
                        reduced: const Duration(milliseconds: 40),
                      ),
                      onTap: () => _openScopedSearch(
                        context,
                        searchQueries?[index] ?? values[index],
                        searchKind,
                      ),
                      child: Text(values[index], style: linkStyle),
                    ),
                  if (index != values.length - 1) Text(', ', style: textStyle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderInlineMeta extends StatelessWidget {
  const _HeaderInlineMeta({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(iconAsset, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(child: text),
      ],
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIconAssets.systemWarning,
              size: 42,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.strings.retry),
            ),
          ],
        ),
      ),
    );
    if (Theme.of(context).platform == TargetPlatform.windows ||
        TelevisionLayout.isActive(context)) {
      // The error can exceed a short window once text accessibility scaling and
      // the persistent player reduce the viewport. Keep Retry scroll-reachable
      // in Windows and the shorter TV viewport.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const ValueKey('windows-source-details-error-scroll'),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        ),
      );
    }
    return Center(child: content);
  }
}

String _collapsedDescription(String text) {
  final normalized = text.trim();
  if (normalized.length <= 120) {
    return normalized;
  }
  final firstSentenceEnd = normalized.indexOf(RegExp(r'[.!?]\s'));
  if (firstSentenceEnd >= 40 && firstSentenceEnd < normalized.length - 1) {
    return '${normalized.substring(0, firstSentenceEnd + 1)}...';
  }
  return '${normalized.substring(0, 120).trimRight()}...';
}

String? _seriesLabel(String? title, double? number) {
  final cleanedTitle = _trimOrNull(title);
  if (cleanedTitle == null) {
    return null;
  }
  final numberLabel = _seriesNumberLabel(number);
  return numberLabel == null ? cleanedTitle : '$cleanedTitle #$numberLabel';
}

String? _seriesNumberLabel(double? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

String? _ratingLabel(AppStrings strings, double? value) {
  if (value == null || value <= 0) {
    return null;
  }
  final rounded = double.parse(value.clamp(0, 5).toStringAsFixed(1));
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return strings.ratingOutOfFive(text);
}

String _formatInt(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(raw[index]);
  }
  return buffer.toString();
}

int? _intFromAny(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
  }
  return null;
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

bool _sameChapter(AudioPlaybackChapter requested, AudioPlaybackChapter active) {
  final identity = requested.storageIdentity;
  if (identity != null) return active.storageIdentity == identity;
  final reference = requested.storageMediaReference;
  return active.id == requested.id &&
      (reference == null || active.storageMediaReference == reference);
}

int? _chapterIndexIn(AudioPlaybackBook active, AudioPlaybackChapter requested) {
  int? result;
  for (final (index, chapter) in active.chapters.indexed) {
    if (!_sameChapter(requested, chapter)) continue;
    if (result != null) return null;
    result = index;
  }
  return result;
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == '-' || trimmed == '—') {
    return null;
  }
  return trimmed;
}

bool _isMeaningful(String value) {
  return _trimOrNull(value) != null;
}

void _openScopedSearch(BuildContext context, String query, SearchKind kind) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return;
  }
  final uri = Uri(
    path: '/scoped-search',
    queryParameters: {
      'q': trimmed,
      'kind': _searchKindRouteValue(kind),
      'run': '1',
    },
  );
  context.push(uri.toString());
}

String _searchKindRouteValue(SearchKind kind) {
  return switch (kind) {
    SearchKind.title => 'title',
    SearchKind.author => 'author',
    SearchKind.narrator => 'narrator',
    SearchKind.series => 'series',
    SearchKind.genre => 'genre',
    SearchKind.all => 'all',
  };
}

Future<void> _openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showMotionSnackBar(
      SnackBar(content: Text(context.strings.sourcePageOpenError)),
    );
  }
}
