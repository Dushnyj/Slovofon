import '../../ui/motion/motion_tooltip.dart';
import '../../ui/motion/motion_controls.dart';
import '../../ui/motion/app_motion.dart';
import '../../ui/motion/motion_progress_indicator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/bookmarks/bookmark_store.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../sources/source_models.dart';
import '../../ui/components/book_card.dart';
import '../../ui/adaptive/adaptive_sheet.dart';
import '../../ui/adaptive/television_layout.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/book_fragment_badge.dart';
import '../../ui/components/chapter_tile.dart';
import '../../ui/components/playback_source_label.dart';
import '../../ui/components/desktop_volume_control.dart';
import '../../ui/components/seek_interval_icon.dart';
import '../../ui/components/source_badge.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/download_ui_state.dart';

class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({this.initialTabIndex = 0, super.key});

  final int initialTabIndex;

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen>
    with TickerProviderStateMixin {
  late TabController _tabs;
  Duration? _tabDuration;
  bool _tabsInitialized = false;
  // Keep the tab pages (and chapter scroll position) when the book panel moves
  // between the wide sidebar and the compact information dialog.
  final _windowsContentKey = GlobalKey(debugLabel: 'windows-player-content');
  Offset? _pointerDownPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextDuration = TelevisionLayout.isActive(context)
        ? Duration.zero
        : AppMotion.of(context).spatialDuration();
    if (!_tabsInitialized || _tabDuration != nextDuration) {
      final previous = _tabsInitialized ? _tabs : null;
      final index = previous?.index ?? widget.initialTabIndex.clamp(0, 3);
      _tabsInitialized = true;
      _tabDuration = nextDuration;
      _tabs = TabController(
        length: 4,
        initialIndex: index,
        // TabBarView reads the controller duration. Changing the preference
        // updates this too, not merely individual animateTo invocations.
        animationDuration: nextDuration,
        vsync: this,
      );
      previous?.dispose();
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(playbackControllerProvider);
    final downloadManager = ref.watch(downloadManagerProvider);

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final state = service.state;
        final book = state.book;
        final mockBook = _mockBookForPlayback(book);

        if (book == null) {
          final colors = Theme.of(context).colorScheme;
          final strings = context.strings;
          final loading =
              state.status == AudioPlaybackStatus.loading ||
              state.status == AudioPlaybackStatus.buffering;
          return Scaffold(
            key: const ValueKey('windows-full-player'),
            backgroundColor: colors.surfaceContainerLowest,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        AppIconButton(
                          key: const ValueKey('windows-empty-player-back'),
                          tooltip: strings.home,
                          onPressed: () => _close(context),
                          icon: const AppIcon(AppIconAssets.systemBack),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings.fullPlayer,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        AppIconButton(
                          tooltip: strings.cancel,
                          onPressed: () => _close(context),
                          icon: const AppIcon(AppIconAssets.systemClose),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: Padding(
                              key: ValueKey(
                                loading
                                    ? 'windows-player-loading-state'
                                    : 'windows-player-empty-state',
                              ),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (loading)
                                    const AppCircularProgressIndicator()
                                  else ...[
                                    AppIcon(
                                      AppIconAssets.playerAudio,
                                      size: 48,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      strings.realSourceHomeTitle,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      key: const ValueKey(
                                        'windows-player-empty-search',
                                      ),
                                      onPressed: () => context.go('/search'),
                                      icon: const AppIcon(
                                        AppIconAssets.navSearch,
                                      ),
                                      label: Text(strings.openSearch),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (TelevisionLayout.isActive(context)) {
          return _TelevisionFullPlayer(
            state: state,
            service: service,
            downloadManager: downloadManager,
            controller: _tabs,
            onClose: () => _close(context),
          );
        }

        if (_usesLargeScreenPlayer(context)) {
          final colors = Theme.of(context).colorScheme;
          final strings = context.strings;
          final windowSize = MediaQuery.sizeOf(context);
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final heightFactor = 1 + 0.35 * (textScale - 1).clamp(0.0, 2.0);
          final compact =
              windowSize.width < 1100 || windowSize.height / heightFactor < 700;
          return Scaffold(
            key: const ValueKey('windows-full-player'),
            backgroundColor: colors.surfaceContainerLowest,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: compact
                        ? const EdgeInsets.fromLTRB(12, 8, 12, 0)
                        : const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        AppIconButton(
                          tooltip: strings.home,
                          onPressed: () => _close(context),
                          icon: const AppIcon(AppIconAssets.systemBack),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: compact
                              ? _CompactWindowsPlayerHeader(
                                  book: book,
                                  downloadManager: downloadManager,
                                )
                              : Text(
                                  strings.fullPlayer,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                        ),
                        AppIconButton(
                          tooltip: strings.cancel,
                          onPressed: () => _close(context),
                          icon: const AppIcon(AppIconAssets.systemClose),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 12 : 24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final textScale =
                              MediaQuery.textScalerOf(context).scale(14) / 14;
                          final bookPanelWidth =
                              (constraints.maxWidth * 0.28 +
                                      ((textScale - 1) * 100).clamp(0.0, 100.0))
                                  .clamp(300.0, 440.0);
                          final contentPanel = Material(
                            key: _windowsContentKey,
                            color: colors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: colors.outlineVariant),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                _WindowsPlayerTabs(
                                  controller: _tabs,
                                  compact: compact,
                                ),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabs,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: [
                                      _WindowsNowPlayingDetails(
                                        state: state,
                                        service: service,
                                        downloadManager: downloadManager,
                                        onShowChapters: () => _tabs.animateTo(
                                          1,
                                          duration: AppMotion.of(context)
                                              .spatialDuration(
                                                full: const Duration(
                                                  milliseconds: 180,
                                                ),
                                              ),
                                        ),
                                      ),
                                      _ChaptersPage(
                                        state: state,
                                        service: service,
                                        downloadManager: downloadManager,
                                      ),
                                      _BookmarksPage(
                                        book: book,
                                        service: service,
                                      ),
                                      _InformationPage(
                                        book: book,
                                        mockBook: mockBook,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (compact) {
                            return KeyedSubtree(
                              key: const ValueKey(
                                'windows-compact-full-player-content',
                              ),
                              child: contentPanel,
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                key: const ValueKey(
                                  'windows-player-book-panel',
                                ),
                                width: bookPanelWidth,
                                child: _WindowsPlayerBookPanel(
                                  book: book,
                                  downloadManager: downloadManager,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(child: contentPanel),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  _PlayerChrome(
                    state: state,
                    service: service,
                    controller: _tabs,
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: Row(
                    children: [
                      AppIconButton(
                        tooltip: context.strings.home,
                        onPressed: () => _close(context),
                        icon: const AppIcon(AppIconAssets.systemBack),
                      ),
                      const Spacer(),
                      AppIconButton(
                        tooltip: context.strings.cancel,
                        onPressed: () => _close(context),
                        icon: const AppIcon(AppIconAssets.systemClose),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (event) {
                          _pointerDownPosition = event.position;
                        },
                        onPointerCancel: (_) {
                          _pointerDownPosition = null;
                        },
                        onPointerUp: (event) {
                          final start = _pointerDownPosition;
                          _pointerDownPosition = null;
                          if (start == null || _tabs.index != 0) {
                            return;
                          }
                          final delta = event.position - start;
                          if (delta.dx > 120 && delta.dy.abs() < 90) {
                            _close(context);
                          }
                        },
                        child: _NowPlayingPage(
                          state: state,
                          downloadManager: downloadManager,
                        ),
                      ),
                      _ChaptersPage(
                        state: state,
                        service: service,
                        downloadManager: downloadManager,
                      ),
                      _BookmarksPage(book: book, service: service),
                      _InformationPage(book: book, mockBook: mockBook),
                    ],
                  ),
                ),
                _PlayerChrome(
                  state: state,
                  service: service,
                  controller: _tabs,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

bool _usesLargeScreenPlayer(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.windows ||
    TelevisionLayout.isActive(context);

/// TV has a small logical viewport even on a 4K panel. Physical pixels must not
/// select the desktop compact mode or remove the artwork from this composition.
class _TelevisionFullPlayer extends StatefulWidget {
  const _TelevisionFullPlayer({
    required this.state,
    required this.service,
    required this.downloadManager,
    required this.controller,
    required this.onClose,
  });
  final AudioPlaybackState state;
  final PlaybackController service;
  final DownloadManager downloadManager;
  final TabController controller;
  final VoidCallback onClose;

  @override
  State<_TelevisionFullPlayer> createState() => _TelevisionFullPlayerState();
}

class _TelevisionFullPlayerState extends State<_TelevisionFullPlayer> {
  final _tabs = List.generate(
    4,
    (index) => FocusNode(debugLabel: 'tv-player-tab-$index'),
  );
  final _content = List.generate(
    4,
    (index) => FocusScopeNode(
      debugLabel: 'tv-player-content-$index',
      directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
    ),
  );

  @override
  void dispose() {
    for (final node in [..._tabs, ..._content]) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode? _entryNode(int index) {
    final scope = _content[index];
    final nodes = scope.traversalDescendants.where(
      (node) =>
          node is! FocusScopeNode &&
          node.canRequestFocus &&
          !node.skipTraversal,
    );
    // Lazy chapter lists can keep previous rows alive outside their viewport.
    // Enter a visible action, not an offscreen cached chapter or global seek.
    for (final node in nodes) {
      if (node.context != null &&
          scope.context != null &&
          node.rect.overlaps(scope.rect)) {
        return node;
      }
    }
    return nodes.firstOrNull;
  }

  void _select(int index) =>
      widget.controller.animateTo(index, duration: Duration.zero);

  void _enterContent(int index) {
    _select(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _entryNode(index);
      target?.requestFocus();
      if (target?.context case final context?) {
        unawaited(Scrollable.ensureVisible(context, duration: Duration.zero));
      }
    });
  }

  Widget _page(int index, Widget child) => FocusScope(
    node: _content[index],
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowUp &&
          FocusManager.instance.primaryFocus ==
              _content[index].traversalDescendants
                  .where(
                    (node) =>
                        node is! FocusScopeNode &&
                        node.canRequestFocus &&
                        !node.skipTraversal,
                  )
                  .firstOrNull) {
        _tabs[index].requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final book = widget.state.book!;
    final colors = Theme.of(context).colorScheme;
    final strings = context.strings;
    final labels = [
      strings.nowPlaying,
      strings.chapters,
      strings.bookmarks,
      strings.information,
    ];
    final panel = Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  for (var index = 0; index < labels.length; index++)
                    Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          _enterContent(index);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: TextButton(
                          key: ValueKey('tv-player-tab-$index'),
                          focusNode: _tabs[index],
                          autofocus: index == widget.controller.index,
                          onFocusChange: (focused) {
                            if (focused && _tabs[index].context != null) {
                              unawaited(
                                Scrollable.ensureVisible(
                                  _tabs[index].context!,
                                  duration: Duration.zero,
                                ),
                              );
                            }
                          },
                          style:
                              TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ).copyWith(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) =>
                                          states.contains(WidgetState.focused)
                                          ? colors.primary
                                          : widget.controller.index == index
                                          ? colors.surfaceContainerHigh
                                          : colors.surface,
                                    ),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) =>
                                          states.contains(WidgetState.focused)
                                          ? colors.onPrimary
                                          : colors.onSurface,
                                    ),
                              ),
                          onPressed: () => _select(index),
                          child: Text(labels[index]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: widget.controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _page(
                  0,
                  ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text(
                        '${widget.state.chapterIndex + 1} / ${book.chapters.length}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.state.currentChapter?.title ?? book.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${strings.bookProgress}: ${(widget.state.bookProgress * 100).round()}%',
                      ),
                      const SizedBox(height: 8),
                      AppLinearProgressIndicator(
                        value: widget.state.bookProgress.clamp(0, 1),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          key: const ValueKey('tv-player-open-chapters'),
                          onPressed: () {
                            _select(1);
                            _tabs[1].requestFocus();
                          },
                          icon: const AppIcon(
                            AppIconAssets.playerChapters,
                            size: 20,
                          ),
                          label: Text(strings.chapters),
                        ),
                      ),
                    ],
                  ),
                ),
                _page(
                  1,
                  _ChaptersPage(
                    state: widget.state,
                    service: widget.service,
                    downloadManager: widget.downloadManager,
                  ),
                ),
                _page(2, _BookmarksPage(book: book, service: widget.service)),
                _page(
                  3,
                  _InformationPage(
                    book: book,
                    mockBook: _mockBookForPlayback(book),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      key: const ValueKey('television-full-player'),
      backgroundColor: colors.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Row(
                children: [
                  AppIconButton(
                    tooltip: strings.home,
                    onPressed: widget.onClose,
                    icon: const AppIcon(AppIconAssets.systemBack),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.fullPlayer,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  AppIconButton(
                    tooltip: strings.cancel,
                    onPressed: widget.onClose,
                    icon: const AppIcon(AppIconAssets.systemClose),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        MediaQuery.textScalerOf(context).scale(16) / 16;
                    final split =
                        constraints.maxWidth >=
                        680 + 100 * (scale - 1).clamp(0, 1);
                    final identity = _TelevisionPlayerIdentity(
                      book: book,
                      downloadManager: widget.downloadManager,
                    );
                    if (!split) {
                      // Narrow accessibility fallback remains scrollable, never scales
                      // down text or drops artwork/controls to imitate a wider device.
                      return ListView(
                        children: [
                          identity,
                          const SizedBox(height: 8),
                          SizedBox(
                            height: constraints.maxHeight.clamp(240, 460),
                            child: panel,
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: (constraints.maxWidth * .33).clamp(240, 330),
                          child: identity,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: panel),
                      ],
                    );
                  },
                ),
              ),
            ),
            _PlayerChrome(
              state: widget.state,
              service: widget.service,
              controller: widget.controller,
            ),
          ],
        ),
      ),
    );
  }
}

class _TelevisionPlayerIdentity extends StatelessWidget {
  const _TelevisionPlayerIdentity({
    required this.book,
    required this.downloadManager,
  });
  final AudioPlaybackBook book;
  final DownloadManager downloadManager;

  @override
  Widget build(BuildContext context) => _PlayerMetadataScrollView(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final titleStyle = Theme.of(context).textTheme.titleLarge;
            final scaler = MediaQuery.textScalerOf(context);
            final scale = scaler.scale(22) / 22;
            final titleMeasure = TextPainter(
              text: TextSpan(text: book.title, style: titleStyle),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout();
            // Keep words intact where possible and leave a readable title
            // column. Move the cover instead of reducing accessibility text.
            final longestWord = titleMeasure.minIntrinsicWidth;
            titleMeasure.dispose();
            final minimumTitleWidth = longestWord > 140 * scale
                ? longestWord
                : 140 * scale;
            final stacked = constraints.maxWidth - 88 - 12 < minimumTitleWidth;
            final artwork = BookCover(
              key: const ValueKey('tv-player-artwork'),
              title: book.title,
              imageUrl: book.coverUrl,
              width: 88,
              height: 126,
              showProgressPercent: false,
            );
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  book.title,
                  key: const ValueKey('tv-player-title'),
                  style: titleStyle,
                ),
                const SizedBox(height: 8),
                PlaybackSourceLabel(
                  key: const ValueKey('tv-full-player-source'),
                  sourceId: book.sourceId,
                  sourceName: book.sourceName,
                  maxLines: null,
                ),
              ],
            );
            if (stacked) {
              return Column(
                key: const ValueKey('tv-player-identity-stacked'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: artwork,
                  ),
                  const SizedBox(height: 12),
                  identity,
                ],
              );
            }
            return Row(
              key: const ValueKey('tv-player-identity-horizontal'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                artwork,
                const SizedBox(width: 12),
                Expanded(child: identity),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(book.author, style: Theme.of(context).textTheme.bodyLarge),
        if (book.narrator.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(book.narrator, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: 8),
        Text(
          _formatShortDuration(context, book.totalDuration),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (book.isFragment) const BookFragmentBadge(),
        const SizedBox(height: 8),
        DownloadActionButton(
          state: downloadStateForBook(downloadManager, book),
          progress: downloadProgressForBook(downloadManager, book),
          size: 40,
          onPressed: () =>
              unawaited(runBookCardDownloadAction(downloadManager, book)),
        ),
      ],
    ),
  );
}

class _CompactWindowsPlayerHeader extends StatelessWidget {
  const _CompactWindowsPlayerHeader({
    required this.book,
    required this.downloadManager,
  });

  final AudioPlaybackBook book;
  final DownloadManager downloadManager;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('windows-compact-full-player-header'),
    children: [
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTooltip(
              message: book.title,
              child: Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            PlaybackSourceLabel(
              key: const ValueKey('windows-full-player-source'),
              sourceId: book.sourceId,
              sourceName: book.sourceName,
            ),
          ],
        ),
      ),
      AppIconButton(
        key: const ValueKey('windows-compact-player-book-details'),
        tooltip: context.strings.information,
        onPressed: () => showAdaptiveSheet<void>(
          context: context,
          builder: (context) => _WindowsPlayerBookPanel(
            book: book,
            downloadManager: downloadManager,
            sourceLabelKey: const ValueKey(
              'windows-compact-player-book-source',
            ),
          ),
        ),
        icon: const AppIcon(AppIconAssets.systemInfo),
      ),
    ],
  );
}

class _WindowsPlayerBookPanel extends StatelessWidget {
  const _WindowsPlayerBookPanel({
    required this.book,
    required this.downloadManager,
    this.sourceLabelKey = const ValueKey('windows-full-player-source'),
  });

  final AudioPlaybackBook book;
  final DownloadManager downloadManager;
  final Key sourceLabelKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: _PlayerMetadataScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: BookCover(
                title: book.title,
                imageUrl: book.coverUrl,
                width: 190,
                height: 258,
                showProgressPercent: false,
              ),
            ),
            const SizedBox(height: 24),
            PlaybackSourceLabel(
              key: sourceLabelKey,
              sourceId: book.sourceId,
              sourceName: book.sourceName,
              maxLines: null,
            ),
            const SizedBox(height: 12),
            Text(
              book.title,
              style: text.titleLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final author in _splitPeople(book.author))
                  _MetaTextLink(
                    label: author,
                    query: author,
                    searchKind: SearchKind.author,
                    wrapLabel: true,
                  ),
              ],
            ),
            if (book.narrator.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(
                    AppIconAssets.bookNarrator,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final narrator in _splitPeople(book.narrator))
                          _MetaTextLink(
                            label: narrator,
                            query: narrator,
                            searchKind: SearchKind.narrator,
                            wrapLabel: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (book.isFragment) ...[
              const SizedBox(height: 12),
              const BookFragmentBadge(),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.strings.chaptersCount(book.chapters.length),
                    style: text.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                DownloadActionButton(
                  state: downloadStateForBook(downloadManager, book),
                  progress: downloadProgressForBook(downloadManager, book),
                  size: 40,
                  onPressed: () {
                    unawaited(runBookCardDownloadAction(downloadManager, book));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerMetadataScrollView extends StatefulWidget {
  const _PlayerMetadataScrollView({required this.padding, required this.child});
  final EdgeInsets padding;
  final Widget child;
  @override
  State<_PlayerMetadataScrollView> createState() =>
      _PlayerMetadataScrollViewState();
}

class _PlayerMetadataScrollViewState extends State<_PlayerMetadataScrollView> {
  final _controller = ScrollController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _controller,
      padding: widget.padding,
      child: widget.child,
    ),
  );
}

class _WindowsPlayerTabs extends StatefulWidget {
  const _WindowsPlayerTabs({required this.controller, this.compact = false});

  final TabController controller;
  final bool compact;

  @override
  State<_WindowsPlayerTabs> createState() => _WindowsPlayerTabsState();
}

class _WindowsPlayerTabsState extends State<_WindowsPlayerTabs> {
  final _scroll = ScrollController();
  final _buttons = List.generate(4, (_) => GlobalKey());
  bool _overflow = false;
  double? _viewportWidth;
  Size? _hostSize;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_revealSelected);
    _scroll.addListener(_onScroll);
    _revealSelected();
  }

  @override
  void didUpdateWidget(_WindowsPlayerTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_revealSelected);
      widget.controller.addListener(_revealSelected);
      _revealSelected();
    } else if (oldWidget.compact != widget.compact) {
      _revealSelected();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _revealSelected();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_revealSelected);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  void _revealSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _buttons[widget.controller.index].currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: Duration.zero,
        );
      }
      setState(() {});
    });
  }

  void _measureOverflow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final overflow = _scroll.position.maxScrollExtent > 0.5;
      if (_overflow != overflow) setState(() => _overflow = overflow);
      final width = _scroll.position.viewportDimension;
      if (_viewportWidth != width) {
        _viewportWidth = width;
        _revealSelected();
      }
    });
  }

  void _move(double direction) {
    if (!_scroll.hasClients) return;
    final target =
        (_scroll.offset + direction * _scroll.position.viewportDimension * 0.7)
            .clamp(0.0, _scroll.position.maxScrollExtent)
            .toDouble();
    if (!AppMotion.of(context).hasSpatialMotion) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (_hostSize != size) {
      _hostSize = size;
      _revealSelected();
    }
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final labels = [
      strings.nowPlaying,
      strings.chapters,
      strings.bookmarks,
      strings.information,
    ];
    final canBack = _scroll.hasClients && _scroll.offset > 0.5;
    final canForward =
        _scroll.hasClients &&
        _scroll.offset < _scroll.position.maxScrollExtent - 0.5;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          if (_overflow)
            AppIconButton(
              key: const ValueKey('windows-player-tabs-back'),
              tooltip: strings.previousTabs,
              onPressed: canBack ? () => _move(-1) : null,
              icon: const AppIcon(AppIconAssets.systemBack),
            ),
          Expanded(
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                _measureOverflow();
                return false;
              },
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.all(widget.compact ? 6 : 12),
                child: Row(
                  children: [
                    for (var index = 0; index < labels.length; index++)
                      Padding(
                        key: _buttons[index],
                        padding: const EdgeInsets.only(right: 4),
                        child: Semantics(
                          selected: widget.controller.index == index,
                          child: TextButton(
                            key: ValueKey('windows-player-tab-$index'),
                            style:
                                TextButton.styleFrom(
                                  foregroundColor:
                                      widget.controller.index == index
                                      ? colors.onSurface
                                      : colors.onSurfaceVariant,
                                  backgroundColor:
                                      widget.controller.index == index
                                      ? colors.surfaceContainerHigh
                                      : null,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: widget.compact ? 8 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ).copyWith(
                                  animationDuration: AppMotion.of(
                                    context,
                                  ).duration(),
                                ),
                            onPressed: () => widget.controller.animateTo(
                              index,
                              duration: AppMotion.of(context).spatialDuration(
                                full: const Duration(milliseconds: 180),
                              ),
                            ),
                            child: Text(labels[index]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_overflow)
            AppIconButton(
              key: const ValueKey('windows-player-tabs-forward'),
              tooltip: strings.nextTabs,
              onPressed: canForward ? () => _move(1) : null,
              icon: const AppIcon(AppIconAssets.systemForward),
            ),
        ],
      ),
    );
  }
}

class _WindowsNowPlayingDetails extends StatelessWidget {
  const _WindowsNowPlayingDetails({
    required this.state,
    required this.service,
    required this.downloadManager,
    required this.onShowChapters,
  });

  final AudioPlaybackState state;
  final PlaybackController service;
  final DownloadManager downloadManager;
  final VoidCallback onShowChapters;

  @override
  Widget build(BuildContext context) {
    final book = state.book!;
    final chapter = state.currentChapter!;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final firstNearbyChapter = (state.chapterIndex - 1).clamp(
      0,
      (book.chapters.length - 3).clamp(0, book.chapters.length),
    );
    final overview = Column(
      key: const ValueKey('windows-player-overview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chapter.title,
          style: text.headlineMedium?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            Text(
              '${state.chapterIndex + 1} / ${book.chapters.length}',
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            Text(
              _formatShortDuration(context, state.chapterDuration),
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(context.strings.bookProgress, style: text.labelLarge),
            ),
            Text(
              '${(state.bookProgress * 100).round()}%',
              style: text.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppLinearProgressIndicator(
          key: const ValueKey('windows-player-book-progress'),
          value: state.bookProgress,
          minHeight: 4,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 10),
        Text(
          '${_formatPlaybackDuration(state.bookPosition)} / '
          '${_formatPlaybackDuration(book.totalDuration)}',
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
    final description = book.description?.trim().isNotEmpty == true
        ? Column(
            key: const ValueKey('windows-player-description'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.strings.information,
                style: text.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                book.description!,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.65,
                ),
              ),
            ],
          )
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        // Split actual content rather than stretch a short summary across an
        // ultrawide panel. Large text keeps its own readable vertical flow.
        final splitSummary =
            description != null &&
            constraints.maxWidth - 64 >= 1040 * textScale.clamp(1.0, 2.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description != null && splitSummary)
                Row(
                  key: const ValueKey('windows-player-summary-columns'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: overview),
                    const SizedBox(width: 32),
                    Expanded(child: description),
                  ],
                )
              else
                overview,
              const SizedBox(height: 20),
              Divider(color: colors.outlineVariant),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onShowChapters,
                  label: Text(
                    context.strings.chaptersCount(book.chapters.length),
                  ),
                  icon: const AppIcon(AppIconAssets.playerChapters, size: 20),
                ),
              ),
              const SizedBox(height: 8),
              for (
                var index = firstNearbyChapter;
                index < book.chapters.length && index < firstNearbyChapter + 3;
                index++
              )
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ChapterTile(
                    key: ValueKey(
                      'windows-nearby-chapter-${book.chapters[index].id}',
                    ),
                    index: index + 1,
                    title: book.chapters[index].title,
                    durationLabel: _formatShortDuration(
                      context,
                      book.chapters[index].duration,
                    ),
                    progress: service.chapterProgressAt(index),
                    isCurrent: index == state.chapterIndex,
                    isDownloaded: isChapterDownloaded(
                      downloadManager,
                      book.chapters[index],
                      book: book,
                    ),
                    downloadState: downloadStateForChapter(
                      downloadManager,
                      book.chapters[index],
                      book: book,
                    ),
                    downloadProgress: downloadProgressForChapter(
                      downloadManager,
                      book.chapters[index],
                      book: book,
                    ),
                    onTap: () => service.playChapterAt(index),
                    onDownloadPressed: () => runChapterCardDownloadAction(
                      downloadManager,
                      book,
                      book.chapters[index],
                    ),
                  ),
                ),
              if (!splitSummary && description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: description,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NowPlayingPage extends StatelessWidget {
  const _NowPlayingPage({required this.state, required this.downloadManager});

  final AudioPlaybackState state;
  final DownloadManager downloadManager;

  @override
  Widget build(BuildContext context) {
    final book = state.book!;
    final currentChapter = state.currentChapter!;
    final seriesLabel = _seriesLabel(book.seriesTitle, book.seriesNumber);
    final yearLabel = book.publishedYear?.toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final isCompact = constraints.maxHeight < 560;
        final coverRatio = textScale > 1.15
            ? (isCompact ? 0.34 : 0.42)
            : (isCompact ? 0.46 : 0.58);
        final scalePenalty = ((textScale - 1) * 120).clamp(0.0, 54.0);
        final coverHeight = (constraints.maxHeight * coverRatio - scalePenalty)
            .clamp(
              textScale > 1.15 ? 172.0 : (isCompact ? 218.0 : 282.0),
              textScale > 1.15 ? 258.0 : (isCompact ? 286.0 : 368.0),
            );
        final coverWidth = coverHeight * 0.715;
        final horizontalPadding = constraints.maxWidth < 380 ? 18.0 : 22.0;
        final gap = textScale > 1.15 ? 5.0 : 10.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            18,
          ),
          children: [
            Center(
              child: BookCover(
                title: book.title,
                progress: state.bookProgress,
                imageUrl: book.coverUrl,
                width: coverWidth,
                height: coverHeight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              book.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: gap),
            if (book.isFragment) const Center(child: BookFragmentBadge()),
            _LinkedPeopleMetaLine(
              iconAsset: AppIconAssets.bookAuthor,
              people: _splitPeople(book.author),
              searchKind: SearchKind.author,
            ),
            const SizedBox(height: 3),
            _LinkedPeopleMetaLine(
              iconAsset: AppIconAssets.bookNarrator,
              people: _splitPeople(book.narrator),
              searchKind: SearchKind.narrator,
            ),
            if (seriesLabel != null) ...[
              const SizedBox(height: 3),
              _LinkedMetaLine(
                iconAsset: AppIconAssets.bookSeries,
                label: seriesLabel,
                query: book.seriesTitle!,
                searchKind: SearchKind.series,
              ),
            ],
            if (yearLabel != null) ...[
              const SizedBox(height: 3),
              _PlainMetaLine(
                iconAsset: AppIconAssets.bookYear,
                label: yearLabel,
              ),
            ],
            SizedBox(height: gap),
            SourceBadge(
              key: const ValueKey('mobile-full-player-source'),
              sourceId: book.sourceId,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    '${currentChapter.index}/${book.chapters.length} · ${currentChapter.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 8),
                DownloadActionButton(
                  state: downloadStateForBook(downloadManager, book),
                  progress: downloadProgressForBook(downloadManager, book),
                  size: 40,
                  onPressed: () {
                    unawaited(runBookCardDownloadAction(downloadManager, book));
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LinkedPeopleMetaLine extends StatelessWidget {
  const _LinkedPeopleMetaLine({
    required this.iconAsset,
    required this.people,
    required this.searchKind,
  });

  final String iconAsset;
  final List<String> people;
  final SearchKind searchKind;

  @override
  Widget build(BuildContext context) {
    final visiblePeople = people.take(2).toList();
    if (visiblePeople.isEmpty) {
      return const SizedBox.shrink();
    }
    final hasMore = people.length > visiblePeople.length;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(iconAsset, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var index = 0; index < visiblePeople.length; index++) ...[
                _MetaTextLink(
                  label: visiblePeople[index],
                  query: visiblePeople[index],
                  searchKind: searchKind,
                ),
                if (index < visiblePeople.length - 1) const _MetaText(', '),
              ],
              if (hasMore) _MetaText(context.strings.peopleAndOthers('')),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkedMetaLine extends StatelessWidget {
  const _LinkedMetaLine({
    required this.iconAsset,
    required this.label,
    required this.query,
    required this.searchKind,
  });

  final String iconAsset;
  final String label;
  final String query;
  final SearchKind searchKind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(iconAsset, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: _MetaTextLink(
            label: label,
            query: query,
            searchKind: searchKind,
          ),
        ),
      ],
    );
  }
}

class _PlainMetaLine extends StatelessWidget {
  const _PlainMetaLine({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(iconAsset, size: 17, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(child: _MetaText(label)),
      ],
    );
  }
}

class _MetaTextLink extends StatelessWidget {
  const _MetaTextLink({
    required this.label,
    required this.query,
    required this.searchKind,
    this.wrapLabel = false,
  });

  final String label;
  final String query;
  final SearchKind searchKind;
  final bool wrapLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (TelevisionLayout.isActive(context)) {
      return TextButton(
        onPressed: () => _openScopedSearch(context, query, searchKind),
        child: Text(
          label,
          maxLines: wrapLabel ? null : 1,
          overflow: wrapLabel ? TextOverflow.clip : TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    if (!_usesLargeScreenPlayer(context)) {
      final bodyStyle = Theme.of(context).textTheme.bodyMedium;
      return TextButton(
        key: ValueKey('mobile-player-meta-${searchKind.name}-$query'),
        style:
            TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ).copyWith(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.pressed)
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.focused) ||
                        states.contains(WidgetState.pressed)
                    ? colorScheme.primary
                    : states.contains(WidgetState.hovered)
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.surface.withValues(alpha: 0),
              ),
              // Each state already has a complete readable pair; do not tint its
              // foreground/background again with the default primary overlay.
              overlayColor: WidgetStatePropertyAll(
                colorScheme.surface.withValues(alpha: 0),
              ),
            ),
        onPressed: () => _openScopedSearch(context, query, searchKind),
        child: Text(
          label,
          maxLines: wrapLabel ? null : 1,
          overflow: wrapLabel ? TextOverflow.clip : TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: bodyStyle?.fontFamily,
            fontSize: bodyStyle?.fontSize,
            height: bodyStyle?.height,
            letterSpacing: bodyStyle?.letterSpacing,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: colorScheme.primary,
      ),
      onPressed: () => _openScopedSearch(context, query, searchKind),
      child: Text(
        label,
        maxLines: wrapLabel ? null : 1,
        overflow: wrapLabel ? TextOverflow.clip : TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
    );
  }
}

class _ChaptersPage extends StatefulWidget {
  const _ChaptersPage({
    required this.state,
    required this.service,
    required this.downloadManager,
  });

  final AudioPlaybackState state;
  final PlaybackController service;
  final DownloadManager downloadManager;

  @override
  State<_ChaptersPage> createState() => _ChaptersPageState();
}

class _ChaptersPageState extends State<_ChaptersPage> {
  double _chapterExtent = 96;
  Object? _extentConfiguration;

  late final ScrollController _controller;
  String? _lastBookVersionId;
  int? _lastChapterIndex;
  bool _showCurrentChapterButton = false;
  bool _currentChapterScrollPending = false;
  int _chapterScrollRequest = 0;

  @override
  void initState() {
    super.initState();
    _lastBookVersionId = widget.state.book?.versionId;
    _lastChapterIndex = widget.state.chapterIndex;
    _controller = ScrollController(
      initialScrollOffset: _initialScrollOffset(widget.state.chapterIndex),
    )..addListener(_handleScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCurrentChapterButton();
    });
  }

  void _updateChapterExtent(double availableWidth) {
    final textTheme = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final configuration = (
      availableWidth,
      textTheme,
      scaler,
      Localizations.localeOf(context),
      widget.state.book,
    );
    if (_extentConfiguration == configuration) {
      return;
    }
    _extentConfiguration = configuration;
    final title = textTheme.titleSmall!;
    final subtitle = textTheme.bodySmall!;
    // Account for the duration wrapping beside the index and download button.
    // Cache the measurement; playback position ticks do not remeasure chapters.
    final textWidth = (availableWidth - 32 - 24 - 38 - 12 - 44).clamp(
      1.0,
      double.infinity,
    );
    var subtitleHeight =
        scaler.scale(subtitle.fontSize!) * (subtitle.height ?? 1.4);
    for (final label in {
      for (final chapter in widget.state.book!.chapters)
        _formatShortDuration(context, chapter.duration),
    }) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: subtitle),
        textDirection: Directionality.of(context),
        textScaler: scaler,
      )..layout(maxWidth: textWidth);
      if (painter.height > subtitleHeight) {
        subtitleHeight = painter.height;
      }
      painter.dispose();
    }
    final contentHeight =
        51 +
        scaler.scale(title.fontSize!) * (title.height ?? 1.4) +
        subtitleHeight;
    final nextExtent = contentHeight < 96 ? 96.0 : contentHeight.ceilToDouble();
    if (nextExtent == _chapterExtent) {
      return;
    }
    final previousExtent = _chapterExtent;
    final previousOffset = _controller.hasClients
        ? _controller.offset
        : _initialScrollOffset(widget.state.chapterIndex);
    _chapterExtent = nextExtent;
    if (_currentChapterScrollPending) {
      // Navigation's callback uses the new extent. A proportional correction
      // here would run after it and restore the previous book's position.
      return;
    }
    final scrollRequest = _chapterScrollRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_controller.hasClients ||
          scrollRequest != _chapterScrollRequest) {
        return;
      }
      _controller.jumpTo(
        (previousOffset / previousExtent * nextExtent).clamp(
          0,
          _controller.position.maxScrollExtent,
        ),
      );
      _syncCurrentChapterButton();
    });
  }

  @override
  void didUpdateWidget(covariant _ChaptersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextBookVersionId = widget.state.book?.versionId;
    final nextChapterIndex = widget.state.chapterIndex;
    if (nextBookVersionId == _lastBookVersionId &&
        nextChapterIndex == _lastChapterIndex) {
      return;
    }
    _lastBookVersionId = nextBookVersionId;
    _lastChapterIndex = nextChapterIndex;
    _currentChapterScrollPending = true;
    final scrollRequest = ++_chapterScrollRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || scrollRequest != _chapterScrollRequest) {
        return;
      }
      _currentChapterScrollPending = false;
      if (!_controller.hasClients) {
        return;
      }
      _moveToChapter(nextChapterIndex, const Duration(milliseconds: 220));
      _syncCurrentChapterButton();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScrollChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final book = widget.state.book!;

    return LayoutBuilder(
      builder: (context, constraints) {
        _updateChapterExtent(constraints.maxWidth);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_usesLargeScreenPlayer(context)) ...[
                Text(
                  strings.chapters,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      key: const ValueKey('full-player-chapters-list'),
                      controller: _controller,
                      itemExtent: _chapterExtent,
                      itemCount: book.chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = book.chapters[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ChapterTile(
                            key: ValueKey('full-player-chapter-${chapter.id}'),
                            index: index + 1,
                            title: chapter.title,
                            durationLabel: _formatShortDuration(
                              context,
                              chapter.duration,
                            ),
                            progress: widget.service.chapterProgressAt(index),
                            isDownloaded: isChapterDownloaded(
                              widget.downloadManager,
                              chapter,
                              book: book,
                            ),
                            downloadState: downloadStateForChapter(
                              widget.downloadManager,
                              chapter,
                              book: book,
                            ),
                            downloadProgress: downloadProgressForChapter(
                              widget.downloadManager,
                              chapter,
                              book: book,
                            ),
                            isCurrent:
                                chapter.id == widget.state.currentChapter?.id,
                            onTap: () => widget.service.playChapterAt(index),
                            onDownloadPressed: () =>
                                runChapterCardDownloadAction(
                                  widget.downloadManager,
                                  book,
                                  chapter,
                                ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: AnimatedSwitcher(
                        duration: AppMotion.of(
                          context,
                        ).duration(full: const Duration(milliseconds: 180)),
                        child: _showCurrentChapterButton
                            ? Center(
                                child: _CurrentChapterButton(
                                  onPressed: _scrollToCurrentChapter,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _initialScrollOffset(int chapterIndex) {
    if (chapterIndex <= 0) {
      return 0;
    }
    return chapterIndex * _chapterExtent;
  }

  void _handleScrollChanged() {
    _syncCurrentChapterButton();
  }

  void _syncCurrentChapterButton() {
    if (!mounted) {
      return;
    }
    final shouldShow = _shouldShowCurrentChapterButton();
    if (shouldShow == _showCurrentChapterButton) {
      return;
    }
    setState(() => _showCurrentChapterButton = shouldShow);
  }

  bool _shouldShowCurrentChapterButton() {
    if (!_controller.hasClients) {
      return false;
    }
    final position = _controller.position;
    if (!position.hasViewportDimension) {
      return false;
    }
    final index = widget.state.chapterIndex;
    final itemTop = index * _chapterExtent;
    final itemBottom = itemTop + _chapterExtent;
    final viewportTop = _controller.offset;
    final viewportBottom = viewportTop + position.viewportDimension;
    return itemBottom < viewportTop + 6 || itemTop > viewportBottom - 6;
  }

  void _scrollToCurrentChapter() {
    if (!_controller.hasClients) {
      return;
    }
    _moveToChapter(
      widget.state.chapterIndex,
      const Duration(milliseconds: 240),
    );
  }

  void _moveToChapter(int chapterIndex, Duration duration) {
    final target = _initialScrollOffset(
      chapterIndex,
    ).clamp(0.0, _controller.position.maxScrollExtent);
    if (!AppMotion.of(context).hasSpatialMotion) {
      _controller.jumpTo(target);
    } else {
      unawaited(
        _controller.animateTo(
          target,
          duration: duration,
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }
}

class _CurrentChapterButton extends StatelessWidget {
  const _CurrentChapterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (TelevisionLayout.isActive(context)) {
      // Inherit both foreground and background from the TV focus state. A
      // primary-colored label disappears against the focused primary fill.
      return TextButton.icon(
        key: const ValueKey('full-player-current-chapter-button'),
        onPressed: onPressed,
        icon: const AppIcon(AppIconAssets.playerNextChapter, size: 18),
        label: Text(context.strings.goToCurrentChapter),
      );
    }

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.88),
      elevation: 4,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        hoverDuration: AppMotion.of(context).duration(
          full: const Duration(milliseconds: 50),
          reduced: const Duration(milliseconds: 40),
        ),
        key: const ValueKey('full-player-current-chapter-button'),
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIconAssets.playerNextChapter,
                size: 17,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  context.strings.goToCurrentChapter,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarksPage extends ConsumerStatefulWidget {
  const _BookmarksPage({required this.book, required this.service});
  final AudioPlaybackBook book;
  final PlaybackController service;
  @override
  ConsumerState<_BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<_BookmarksPage> {
  bool _adding = false;
  final _removing = <String>{};

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showMotionSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final snapshot = widget.service.state;
    final book = snapshot.book;
    final chapter = snapshot.currentChapter;
    if (_adding ||
        book == null ||
        chapter == null ||
        book.versionId != widget.book.versionId) {
      return;
    }
    setState(() => _adding = true);
    try {
      final note = await showAdaptiveSheet<String>(
        context: context,
        title: context.strings.addBookmark,
        maxWidth: 480,
        isScrollControlled: true,
        builder: (_) => _BookmarkEditor(
          chapterTitle: chapter.title,
          position: snapshot.position,
        ),
      );
      if (note == null || !mounted) return;
      await ref
          .read(bookmarkStoreProvider)
          .add(
            book: book,
            chapterId: chapter.id,
            positionMs: snapshot.position.inMilliseconds,
            note: note.isEmpty ? null : note,
          );
      if (mounted) _message(context.strings.bookmarkAdded);
    } catch (_) {
      if (mounted) _message(context.strings.libraryActionError);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(PlaybackBookmark bookmark) async {
    if (_removing.contains(bookmark.id)) return;
    final confirmed = await showMotionDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('player-bookmark-delete-dialog'),
        constraints: const BoxConstraints(maxWidth: 560),
        scrollable: true,
        title: Text(context.strings.deleteBookmark),
        content: Text(context.strings.deleteBookmarkDescription),
        actions: [
          TextButton(
            key: const ValueKey('player-bookmark-delete-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            key: const ValueKey('player-bookmark-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(context.strings.deleteBookmarkAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing.add(bookmark.id));
    try {
      await ref.read(bookmarkStoreProvider).remove(bookmark.id);
      if (mounted) _message(context.strings.bookmarkRemoved);
    } catch (_) {
      if (mounted) _message(context.strings.libraryActionError);
    } finally {
      if (mounted) setState(() => _removing.remove(bookmark.id));
    }
  }

  void _jump(PlaybackBookmark bookmark) {
    final active = widget.service.state.book;
    if (active == null || active.versionId != bookmark.bookVersionId) return;
    final index = active.chapters.indexWhere(
      (chapter) => chapter.id == bookmark.chapterId,
    );
    if (index < 0) return;
    unawaited(
      widget.service.seekChapterAt(
        index,
        Duration(milliseconds: bookmark.positionMs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(bookmarkStoreProvider);
    final strings = context.strings;
    final entries = store.forBook(widget.book.versionId);
    return ListView(
      key: const PageStorageKey('player-bookmarks-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            key: const ValueKey('player-bookmark-add'),
            onPressed: _adding || !store.isLoaded ? null : _add,
            icon: const AppIcon(AppIconAssets.playerBookmark),
            label: Text(strings.addBookmark),
          ),
        ),
        const SizedBox(height: 16),
        if (!store.isLoaded)
          const Center(child: AppCircularProgressIndicator())
        else if (store.error != null) ...[
          Text(strings.libraryLoadError),
          TextButton(
            onPressed: () => unawaited(store.load()),
            child: Text(strings.retry),
          ),
        ] else if (entries.isEmpty)
          Text(
            strings.noBookmarks,
            key: const ValueKey('player-bookmarks-empty'),
          ),
        for (final bookmark in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: ListTile(
                      key: ValueKey('player-bookmark-${bookmark.id}'),
                      leading: const AppIcon(AppIconAssets.playerBookmark),
                      title: Text(
                        '${bookmark.title} · ${_formatPlaybackDuration(Duration(milliseconds: bookmark.positionMs))}',
                      ),
                      subtitle: bookmark.note?.isNotEmpty == true
                          ? Text(bookmark.note!)
                          : null,
                      onTap:
                          widget.book.chapters.any(
                            (chapter) => chapter.id == bookmark.chapterId,
                          )
                          ? () => _jump(bookmark)
                          : null,
                    ),
                  ),
                  AppIconButton(
                    key: ValueKey('player-bookmark-delete-${bookmark.id}'),
                    tooltip: strings.deleteBookmarkAction,
                    onPressed: _removing.contains(bookmark.id)
                        ? null
                        : () => _remove(bookmark),
                    icon: const AppIcon(AppIconAssets.systemTrash),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BookmarkEditor extends StatefulWidget {
  const _BookmarkEditor({required this.chapterTitle, required this.position});
  final String chapterTitle;
  final Duration position;
  @override
  State<_BookmarkEditor> createState() => _BookmarkEditorState();
}

class _BookmarkEditorState extends State<_BookmarkEditor> {
  final _note = TextEditingController();
  late final FocusNode _noteFocus = FocusNode(
    debugLabel: 'player-bookmark-note',
    onKeyEvent: _noteKey,
  );
  final _saveFocus = FocusNode(debugLabel: 'player-bookmark-save');

  void _finishTelevisionEditing() {
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
    _saveFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _saveFocus.context != null) {
        unawaited(
          Scrollable.ensureVisible(
            _saveFocus.context!,
            duration: Duration.zero,
          ),
        );
      }
    });
  }

  KeyEventResult _noteKey(FocusNode node, KeyEvent event) {
    // When Back has already dismissed the TV keyboard, Down means leave the
    // editor. While the IME is visible it still owns normal caret navigation.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowDown &&
        TelevisionLayout.isActive(context) &&
        // Dialog removes its consumed IME padding from the descendant
        // MediaQuery. The FlutterView still reports the real keyboard state.
        View.of(context).viewInsets.bottom == 0) {
      _finishTelevisionEditing();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _note.dispose();
    _noteFocus.dispose();
    _saveFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      8,
      24,
      // TV's adaptive Dialog already consumes the IME inset.
      24 +
          (TelevisionLayout.isActive(context)
              ? 0
              : MediaQuery.viewInsetsOf(context).bottom),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_usesLargeScreenPlayer(context)) ...[
          Text(
            context.strings.addBookmark,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
        ],
        Text(
          '${widget.chapterTitle} · ${_formatPlaybackDuration(widget.position)}',
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('player-bookmark-note'),
          controller: _note,
          focusNode: _noteFocus,
          autofocus: true,
          minLines: 2,
          maxLines: TelevisionLayout.isActive(context) ? 2 : 4,
          textInputAction: TelevisionLayout.isActive(context)
              ? TextInputAction.done
              : null,
          onSubmitted: TelevisionLayout.isActive(context)
              ? (_) => _finishTelevisionEditing()
              : null,
          maxLength: 1000,
          decoration: InputDecoration(labelText: context.strings.bookmarkNote),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('player-bookmark-save'),
          focusNode: _saveFocus,
          onPressed: () => Navigator.of(context).pop(_note.text.trim()),
          child: Text(context.strings.saveBookmark),
        ),
      ],
    ),
  );
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({required this.book, required this.mockBook});

  final AudioPlaybackBook book;
  final MockBook? mockBook;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        if (!_usesLargeScreenPlayer(context)) ...[
          Text(
            strings.information,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
        ],
        ListTile(
          title: PlaybackSourceLabel(
            key: const ValueKey('full-player-info-source'),
            sourceId: book.sourceId,
            sourceName: book.sourceName,
            textStyle: Theme.of(context).textTheme.bodyLarge,
            maxLines: null,
          ),
          subtitle: Text(
            [
                  book.genre ?? mockBook?.genre,
                  _formatShortDuration(context, book.totalDuration),
                ]
                .whereType<String>()
                .where((value) => value.isNotEmpty)
                .join(' · '),
          ),
        ),
        ListTile(
          leading: const AppIcon(AppIconAssets.bookAuthor),
          title: Text(book.author),
          subtitle: Text(book.narrator),
        ),
        ListTile(
          leading: const AppIcon(AppIconAssets.bookYear),
          title: Text(
            [
              book.publishedYear?.toString() ?? mockBook?.year.toString(),
              if (mockBook != null) 'audio ${mockBook!.audioYear}',
            ].whereType<String>().join(' / '),
          ),
          subtitle: Text(mockBook?.ratingLabel ?? book.sourceUrl ?? ''),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppIconButton.filled(
            tooltip: strings.bookDetails,
            onPressed: () {
              final sourceBookId = book.sourceBookId;
              if (sourceBookId == null) {
                unawaited(context.push('/book/${book.id}'));
                return;
              }
              unawaited(
                context.push(
                  '/source-book/${book.sourceId}/${Uri.encodeComponent(sourceBookId)}',
                ),
              );
            },
            icon: const AppIcon(AppIconAssets.systemInfo),
          ),
        ),
      ],
    );
  }
}

MockBook? _mockBookForPlayback(AudioPlaybackBook? book) {
  if (book == null) {
    return null;
  }

  for (final mockBook in stage3MockBooks) {
    if (mockBook.id == book.id) {
      return mockBook;
    }
  }
  return null;
}

class _PlayerChrome extends StatefulWidget {
  const _PlayerChrome({
    required this.state,
    required this.service,
    required this.controller,
  });

  final AudioPlaybackState state;
  final PlaybackController service;
  final TabController controller;

  @override
  State<_PlayerChrome> createState() => _PlayerChromeState();
}

class _PlayerChromeState extends State<_PlayerChrome> {
  double? _dragProgress;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final service = widget.service;
    final currentChapter = state.currentChapter;
    final sliderValue = (_dragProgress ?? state.chapterProgress)
        .clamp(0, 1)
        .toDouble();

    if (_usesLargeScreenPlayer(context)) {
      final television = TelevisionLayout.isActive(context);
      final compact = television || MediaQuery.sizeOf(context).width < 900;
      final transportControls = <Widget>[
        _ControlIcon(
          tooltip: strings.previousChapter,
          iconAsset: AppIconAssets.playerPreviousChapter,
          onPressed: service.previousChapter,
        ),
        const SizedBox(width: 8),
        _ControlIcon(
          tooltip: strings.rewind15,
          iconAsset: AppIconAssets.playerRewind15,
          onPressed: () => service.skipBy(const Duration(seconds: -15)),
        ),
        const SizedBox(width: 16),
        AppIconButton.filled(
          key: television ? const ValueKey('tv-full-player-toggle') : null,
          tooltip: state.isPlaying ? strings.pause : strings.play,
          style:
              IconButton.styleFrom(
                fixedSize: Size.square(television ? 40 : 52),
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ).copyWith(
                side: television
                    ? WidgetStateProperty.resolveWith(
                        (states) => BorderSide(
                          color: states.contains(WidgetState.focused)
                              ? colorScheme.onPrimary
                              : colorScheme.primary,
                          width: states.contains(WidgetState.focused) ? 2 : 1,
                        ),
                      )
                    : null,
                animationDuration: AppMotion.of(context).duration(),
              ),
          onPressed: service.togglePlayPause,
          icon: AppIcon(
            state.isPlaying
                ? AppIconAssets.playerPause
                : AppIconAssets.playerPlay,
            size: television ? 24 : 30,
          ),
        ),
        const SizedBox(width: 16),
        _ControlIcon(
          tooltip: strings.forward15,
          iconAsset: AppIconAssets.playerForward15,
          onPressed: () => service.skipBy(const Duration(seconds: 15)),
        ),
        const SizedBox(width: 8),
        _ControlIcon(
          tooltip: strings.nextChapter,
          iconAsset: AppIconAssets.playerNextChapter,
          onPressed: service.nextChapter,
        ),
      ];
      final speedButton = TextButton.icon(
        key: const ValueKey('windows-player-speed'),
        onPressed: () => _showSpeedSheet(context),
        icon: const AppIcon(AppIconAssets.playerSpeed, size: 20),
        label: Text('${state.speed.toStringAsFixed(2)}x'),
      );
      final timerControls = <Widget>[
        DesktopVolumeControl(
          key: const ValueKey('windows-full-player-volume'),
          volume: state.volume,
          onToggleMute: () => unawaited(service.toggleMute()),
          onVolumeChanged: (value) => unawaited(service.setVolume(value)),
        ),
        if ((state.sleepTimerRemaining ?? Duration.zero) > Duration.zero)
          _SleepTimerPill(
            key: const ValueKey('sleep-timer-pill'),
            label: _formatPlaybackDuration(state.sleepTimerRemaining!),
          ),
        _ControlIcon(
          tooltip: strings.sleepTimer,
          iconAsset: AppIconAssets.playerSleepTimer,
          onPressed: () => _showSleepTimerSheet(context),
        ),
      ];
      return Material(
        key: const ValueKey('windows-full-player-controls'),
        color: colorScheme.surfaceContainerLow,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Padding(
            padding: television
                ? const EdgeInsets.fromLTRB(8, 4, 8, 6)
                : compact
                ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
                : const EdgeInsets.fromLTRB(32, 12, 32, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatPlaybackDuration(state.position),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                            ),
                            child: AppSlider(
                              key: const ValueKey('windows-full-player-seek'),
                              value: sliderValue,
                              onChanged: state.chapterDuration > Duration.zero
                                  ? (value) =>
                                        setState(() => _dragProgress = value)
                                  : null,
                              onChangeEnd: (value) {
                                unawaited(
                                  service.seek(
                                    Duration(
                                      milliseconds:
                                          (state
                                                      .chapterDuration
                                                      .inMilliseconds *
                                                  value)
                                              .round(),
                                    ),
                                  ),
                                );
                                setState(() => _dragProgress = null);
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatPlaybackDuration(state.chapterDuration),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (compact)
                      Wrap(
                        key: const ValueKey('windows-compact-player-controls'),
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          speedButton,
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: transportControls,
                          ),
                          ...timerControls,
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: speedButton,
                            ),
                          ),
                          ...transportControls,
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 4,
                                children: timerControls,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PlayerDots(controller: widget.controller),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: AppSlider(
                value: sliderValue,
                onChanged: (value) => setState(() => _dragProgress = value),
                onChangeEnd: (value) {
                  final duration = state.chapterDuration;
                  service.seek(
                    Duration(
                      milliseconds: (duration.inMilliseconds * value).round(),
                    ),
                  );
                  setState(() => _dragProgress = null);
                },
              ),
            ),
            _PlayerTimeLabels(
              position: state.position,
              duration: currentChapter?.duration ?? Duration.zero,
              sleepTimerRemaining: state.sleepTimerRemaining,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ControlIcon(
                  tooltip: '${state.speed.toStringAsFixed(2)}x',
                  iconAsset: AppIconAssets.playerSpeed,
                  onPressed: () => _showSpeedSheet(context),
                ),
                _ControlIcon(
                  tooltip: strings.previousChapter,
                  iconAsset: AppIconAssets.playerPreviousChapter,
                  onPressed: service.previousChapter,
                ),
                _ControlIcon(
                  tooltip: strings.rewind15,
                  iconAsset: AppIconAssets.playerRewind15,
                  onPressed: () => service.skipBy(const Duration(seconds: -15)),
                ),
                AppIconButton.filled(
                  tooltip: state.isPlaying ? strings.pause : strings.play,
                  iconSize: 34,
                  onPressed: service.togglePlayPause,
                  icon: AppIcon(
                    state.isPlaying
                        ? AppIconAssets.playerPause
                        : AppIconAssets.playerPlay,
                    size: 34,
                  ),
                ),
                _ControlIcon(
                  tooltip: strings.forward15,
                  iconAsset: AppIconAssets.playerForward15,
                  onPressed: () => service.skipBy(const Duration(seconds: 15)),
                ),
                _ControlIcon(
                  tooltip: strings.nextChapter,
                  iconAsset: AppIconAssets.playerNextChapter,
                  onPressed: service.nextChapter,
                ),
                _ControlIcon(
                  tooltip: strings.sleepTimer,
                  iconAsset: AppIconAssets.playerSleepTimer,
                  onPressed: () => _showSleepTimerSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSpeedSheet(BuildContext context) async {
    final selected = await _showPlayerOptions<double>(
      context: context,
      title: context.strings.playbackSpeed,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final speed in const [0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                ListTile(
                  leading: widget.state.speed == speed
                      ? const AppIcon(AppIconAssets.systemCheck)
                      : const SizedBox.square(dimension: 24),
                  title: Text('${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x'),
                  onTap: () => Navigator.of(context).pop(speed),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await widget.service.setSpeed(selected);
    }
  }

  Future<void> _showSleepTimerSheet(BuildContext context) async {
    final selected = await _showPlayerOptions<_SleepTimerChoice>(
      context: context,
      title: context.strings.sleepTimer,
      builder: (context) {
        const options = [
          _SleepTimerChoice.off(),
          _SleepTimerChoice.duration(Duration(minutes: 15)),
          _SleepTimerChoice.duration(Duration(minutes: 30)),
          _SleepTimerChoice.duration(Duration(minutes: 60)),
          _SleepTimerChoice.duration(Duration(minutes: 90)),
          _SleepTimerChoice.endOfChapter(),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                ListTile(
                  leading: option.kind == _SleepTimerChoiceKind.off
                      ? const AppIcon(AppIconAssets.systemClose)
                      : const AppIcon(AppIconAssets.playerSleepTimer),
                  title: Text(_sleepTimerOptionLabel(context, option)),
                  onTap: () => Navigator.of(context).pop(option),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) {
      return;
    }
    switch (selected.kind) {
      case _SleepTimerChoiceKind.off:
        widget.service.clearSleepTimer();
      case _SleepTimerChoiceKind.duration:
        widget.service.setSleepTimer(selected.duration!);
      case _SleepTimerChoiceKind.endOfChapter:
        widget.service.setSleepTimerToChapterEnd();
    }
  }
}

Future<T?> _showPlayerOptions<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) {
  if (_usesLargeScreenPlayer(context)) {
    return showAdaptiveSheet<T>(
      context: context,
      title: title,
      maxWidth: 420,
      builder: (context) => SizedBox(
        key: const ValueKey('windows-player-options'),
        child: SingleChildScrollView(child: builder(context)),
      ),
    );
  }
  return showMotionBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(child: builder(context)),
    ),
  );
}

enum _SleepTimerChoiceKind { off, duration, endOfChapter }

class _SleepTimerChoice {
  const _SleepTimerChoice._(this.kind, this.duration);
  const _SleepTimerChoice.off() : this._(_SleepTimerChoiceKind.off, null);
  const _SleepTimerChoice.duration(Duration duration)
    : this._(_SleepTimerChoiceKind.duration, duration);
  const _SleepTimerChoice.endOfChapter()
    : this._(_SleepTimerChoiceKind.endOfChapter, null);

  final _SleepTimerChoiceKind kind;
  final Duration? duration;
}

class _PlayerDots extends StatefulWidget {
  const _PlayerDots({required this.controller});

  final TabController controller;

  @override
  State<_PlayerDots> createState() => _PlayerDotsState();
}

class _PlayerDotsState extends State<_PlayerDots> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
  }

  @override
  void didUpdateWidget(_PlayerDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleChanged);
      widget.controller.addListener(_handleChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final labels = [
      strings.nowPlaying,
      strings.chapters,
      strings.bookmarks,
      strings.information,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < widget.controller.length; index++)
          Semantics(
            key: ValueKey('mobile-player-dot-$index'),
            button: true,
            selected: widget.controller.index == index,
            label: labels[index],
            onTap: () => widget.controller.animateTo(index),
            child: ExcludeSemantics(
              child: AppTooltip(
                message: labels[index],
                child: SizedBox.square(
                  dimension: 48,
                  child: InkResponse(
                    hoverDuration: AppMotion.of(context).duration(
                      full: const Duration(milliseconds: 50),
                      reduced: const Duration(milliseconds: 40),
                    ),
                    onTap: () => widget.controller.animateTo(index),
                    containedInkWell: true,
                    radius: 24,
                    child: Center(
                      child: AnimatedContainer(
                        key: ValueKey('mobile-player-dot-visual-$index'),
                        duration: AppMotion.of(context).spatialDuration(
                          full: const Duration(milliseconds: 180),
                        ),
                        width: widget.controller.index == index ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.controller.index == index
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _handleChanged() => setState(() {});
}

class _PlayerTimeLabels extends StatelessWidget {
  const _PlayerTimeLabels({
    required this.position,
    required this.duration,
    required this.sleepTimerRemaining,
  });

  final Duration position;
  final Duration duration;
  final Duration? sleepTimerRemaining;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    final positionText = _formatPlaybackDuration(position);
    final durationText = _formatPlaybackDuration(duration);
    final remaining = sleepTimerRemaining;
    final timerText = remaining != null && remaining > Duration.zero
        ? _formatPlaybackDuration(remaining)
        : null;
    final timer = timerText == null
        ? null
        : _SleepTimerPill(
            key: const ValueKey('sleep-timer-pill'),
            label: timerText,
          );
    final positionLabel = Text(positionText, style: style);
    final durationLabel = Text(durationText, style: style);
    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final requiredWidth =
            measure(positionText, style) +
            measure(durationText, style) +
            (timerText == null
                ? 0
                : measure(
                        timerText,
                        style?.copyWith(fontWeight: FontWeight.w700),
                      ) +
                      41) +
            24;
        if (requiredWidth <= constraints.maxWidth) {
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Row(
              children: [
                positionLabel,
                Expanded(child: Center(child: timer)),
                durationLabel,
              ],
            ),
          );
        }
        // Let timestamps and the sleep timer use their natural text heights;
        // a fixed-height Stack overlaps them at large accessibility scales.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [positionLabel, durationLabel],
            ),
            if (timer != null) ...[
              const SizedBox(height: 4),
              Center(child: timer),
            ],
          ],
        );
      },
    );
  }
}

class _SleepTimerPill extends StatelessWidget {
  const _SleepTimerPill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colorScheme.onSecondaryContainer,
      fontWeight: FontWeight.w700,
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final rowWidth = painter.width + 41;
    painter.dispose();
    final icon = AppIcon(
      AppIconAssets.playerSleepTimer,
      size: 16,
      color: colorScheme.onSecondaryContainer,
    );
    final text = Text(label, style: style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = rowWidth > constraints.maxWidth;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: vertical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, const SizedBox(height: 4), text],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, const SizedBox(width: 5), text],
                ),
        );
      },
    );
  }
}

class _ControlIcon extends StatelessWidget {
  const _ControlIcon({
    required this.tooltip,
    required this.iconAsset,
    this.onPressed,
  });

  final String tooltip;
  final String iconAsset;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final desktop = _usesLargeScreenPlayer(context);
    final colors = Theme.of(context).colorScheme;
    final televisionSeek =
        TelevisionLayout.isActive(context) &&
        (iconAsset == AppIconAssets.playerRewind15 ||
            iconAsset == AppIconAssets.playerForward15);
    return AppIconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: desktop && !TelevisionLayout.isActive(context)
          ? IconButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              hoverColor: colors.surfaceContainerHighest,
              focusColor: colors.primary.withValues(alpha: 0.12),
              fixedSize: const Size.square(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ).copyWith(
              animationDuration: AppMotion.of(context).duration(),
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? colors.primary
                      : colors.surfaceContainerLow,
                  width: 1.5,
                ),
              ),
            )
          : televisionSeek
          ? const ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.all(6)),
            )
          : null,
      icon:
          (iconAsset == AppIconAssets.playerRewind15 ||
              iconAsset == AppIconAssets.playerForward15)
          ? SeekIntervalIcon(
              forward: iconAsset == AppIconAssets.playerForward15,
            )
          : AppIcon(iconAsset),
    );
  }
}

String _formatPlaybackDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }

  return '$minutes:$seconds';
}

void _openScopedSearch(BuildContext context, String query, SearchKind kind) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return;
  }
  context.push(
    Uri(
      path: '/scoped-search',
      queryParameters: {'q': trimmed, 'kind': kind.name, 'run': '1'},
    ).toString(),
  );
}

List<String> _splitPeople(String value) {
  return value
      .split(RegExp(r'\s*[,;]\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && part != '-' && part != '—')
      .toList();
}

String? _seriesLabel(String? title, double? number) {
  final cleanedTitle = title?.trim();
  if (cleanedTitle == null || cleanedTitle.isEmpty || cleanedTitle == '-') {
    return null;
  }
  final numberLabel = _seriesNumberLabel(number);
  return numberLabel == null ? cleanedTitle : '$cleanedTitle ($numberLabel)';
}

String? _seriesNumberLabel(double? value) {
  if (value == null || value <= 0) {
    return null;
  }
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

String _sleepTimerOptionLabel(BuildContext context, _SleepTimerChoice choice) {
  return switch (choice.kind) {
    _SleepTimerChoiceKind.off => context.strings.disableSleepTimer,
    _SleepTimerChoiceKind.endOfChapter =>
      context.strings.sleepTimerUntilChapterEnd,
    _SleepTimerChoiceKind.duration => context.strings.minutesLabel(
      choice.duration!.inMinutes,
    ),
  };
}

String _formatShortDuration(BuildContext context, Duration duration) =>
    context.strings.formatDuration(duration);
