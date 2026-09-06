import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../components/playback_source_label.dart';
import '../components/seek_interval_icon.dart';
import '../icons/app_icons.dart';
import 'television_metrics.dart';

/// The menu uses its content width; extra TV space belongs to books, not tabs.
class TelevisionShell extends StatefulWidget {
  const TelevisionShell({
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  State<TelevisionShell> createState() => _TelevisionShellState();
}

class _TelevisionShellState extends State<TelevisionShell> {
  final _navigationFocus = List.generate(
    5,
    (index) => FocusNode(debugLabel: 'TV navigation $index'),
  );

  @override
  void initState() {
    super.initState();
    _focusSelected();
  }

  @override
  void didUpdateWidget(TelevisionShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _focusSelected();
  }

  void _focusSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        _navigationFocus[widget.selectedIndex].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final node in _navigationFocus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('television-shell'),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TelevisionNavigation(
          selectedIndex: widget.selectedIndex,
          onSelected: widget.onSelected,
          focusNodes: _navigationFocus,
        ),
        const SizedBox(height: 8),
        Expanded(child: FocusTraversalGroup(child: widget.child)),
        const TelevisionTransport(),
      ],
    ),
  );
}

/// Root details retain TV chrome without nesting a phone Scaffold/navbar.
/// [child] is the route's body (including loading/error states), not an AppBar.
class TelevisionStandaloneShell extends StatefulWidget {
  const TelevisionStandaloneShell({
    required this.title,
    required this.child,
    this.leading,
    this.selectedIndex,
    this.showTransport = true,
    super.key,
  });
  final String title;
  final Widget child;
  final Widget? leading;
  final int? selectedIndex;
  final bool showTransport;

  @override
  State<TelevisionStandaloneShell> createState() =>
      _TelevisionStandaloneShellState();
}

class _TelevisionStandaloneShellState extends State<TelevisionStandaloneShell> {
  final _backFocus = FocusNode(debugLabel: 'TV standalone back');
  final _navigationFocus = List.generate(
    5,
    (index) => FocusNode(debugLabel: 'TV standalone navigation $index'),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.leading == null &&
          ModalRoute.of(context)?.isCurrent != false) {
        _backFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _backFocus.dispose();
    for (final node in _navigationFocus) {
      node.dispose();
    }
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _goToDestination(int index) {
    const paths = ['/', '/search', '/library', '/downloads', '/settings'];
    context.go(paths[index]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('television-standalone-shell'),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TelevisionNavigation(
          selectedIndex: widget.selectedIndex,
          onSelected: _goToDestination,
          focusNodes: _navigationFocus,
          keyPrefix: 'tv-standalone-nav',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            widget.leading ??
                IconButton(
                  key: const ValueKey('tv-standalone-back'),
                  focusNode: _backFocus,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: _back,
                  icon: const AppIcon(AppIconAssets.systemBack, size: 22),
                ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: widget.child),
        if (widget.showTransport) const TelevisionTransport(),
      ],
    ),
  );
}

class _TelevisionNavigation extends StatelessWidget {
  const _TelevisionNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.focusNodes,
    this.keyPrefix = 'tv-nav',
  });
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FocusNode> focusNodes;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final items = [
      (strings.home, AppIconAssets.navHome),
      (strings.search, AppIconAssets.navSearch),
      (strings.library, AppIconAssets.navLibrary),
      (strings.downloads, AppIconAssets.navDownloads),
      (strings.settings, AppIconAssets.navSettings),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const SizedBox(width: 6),
            Semantics(
              selected: index == selectedIndex,
              child: TextButton.icon(
                key: ValueKey('$keyPrefix-$index'),
                focusNode: focusNodes[index],
                onPressed: () => onSelected(index),
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
                  foregroundColor: WidgetStatePropertyAll(
                    index == selectedIndex
                        ? colors.onSecondaryContainer
                        : colors.onSurface,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (index == selectedIndex) {
                      return colors.secondaryContainer;
                    }
                    return states.contains(WidgetState.focused)
                        ? colors.surfaceContainerHigh
                        : colors.surface;
                  }),
                  side: WidgetStateProperty.resolveWith(
                    (states) => BorderSide(
                      color: states.contains(WidgetState.focused)
                          ? colors.primary
                          : colors.outlineVariant,
                      width: states.contains(WidgetState.focused) ? 2 : 1,
                    ),
                  ),
                ),
                icon: AppIcon(item.$2, size: 18),
                label: Text(item.$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TelevisionTransport extends ConsumerWidget {
  const TelevisionTransport({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(playbackControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final book = state.book;
        if (book == null) return const SizedBox.shrink();
        final strings = context.strings;
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: colors.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TelevisionMetrics.transportMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: book.title,
                        child: TextButton(
                          key: const ValueKey('tv-open-player'),
                          onPressed: () => context.push('/player'),
                          // A focus outline preserves contrast of source-owned
                          // colors; do not put those labels on a purple fill.
                          style: ButtonStyle(
                            overlayColor: WidgetStatePropertyAll(
                              colors.primary.withValues(alpha: 0),
                            ),
                            backgroundColor: WidgetStatePropertyAll(
                              colors.surfaceContainer,
                            ),
                            foregroundColor: WidgetStatePropertyAll(
                              colors.onSurface,
                            ),
                            padding: const WidgetStatePropertyAll(
                              EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            side: WidgetStateProperty.resolveWith(
                              (states) => BorderSide(
                                color: states.contains(WidgetState.focused)
                                    ? colors.primary
                                    : colors.surfaceContainer,
                                width: states.contains(WidgetState.focused)
                                    ? 2
                                    : 1,
                              ),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                PlaybackSourceLabel(
                                  sourceId: book.sourceId,
                                  sourceName: book.sourceName,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: strings.rewind15,
                      onPressed: () =>
                          controller.skipBy(const Duration(seconds: -15)),
                      icon: const SeekIntervalIcon(forward: false),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      key: const ValueKey('tv-play-pause'),
                      tooltip: state.isPlaying ? strings.pause : strings.play,
                      onPressed: controller.togglePlayPause,
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                        backgroundColor: WidgetStatePropertyAll(colors.primary),
                        foregroundColor: WidgetStatePropertyAll(
                          colors.onPrimary,
                        ),
                        side: WidgetStateProperty.resolveWith(
                          (states) => BorderSide(
                            color: states.contains(WidgetState.focused)
                                ? colors.onPrimary
                                : colors.primary,
                            width: states.contains(WidgetState.focused) ? 2 : 1,
                          ),
                        ),
                      ),
                      icon: AppIcon(
                        state.isPlaying
                            ? AppIconAssets.playerPause
                            : AppIconAssets.playerPlay,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: strings.forward15,
                      onPressed: () =>
                          controller.skipBy(const Duration(seconds: 15)),
                      icon: const SeekIntervalIcon(forward: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
