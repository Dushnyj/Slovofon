import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../components/playback_source_label.dart';
import '../components/seek_interval_icon.dart';
import '../icons/app_icons.dart';

/// TV-specific top navigation and transport; never a stretched phone navbar.
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
      if (mounted) _navigationFocus[widget.selectedIndex].requestFocus();
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
  Widget build(BuildContext context) {
    final strings = context.strings;
    final items = [
      (strings.home, AppIconAssets.navHome),
      (strings.search, AppIconAssets.navSearch),
      (strings.library, AppIconAssets.navLibrary),
      (strings.downloads, AppIconAssets.navDownloads),
      (strings.settings, AppIconAssets.navSettings),
    ];
    return Scaffold(
      key: const ValueKey('television-shell'),
      body: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final labels =
                  constraints.maxWidth >=
                  760 * (MediaQuery.textScalerOf(context).scale(17) / 17);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    for (final (index, item) in items.indexed) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: item.$1,
                          child: FilledButton(
                            key: ValueKey('tv-nav-$index'),
                            focusNode: _navigationFocus[index],
                            onPressed: () => widget.onSelected(index),
                            style: index == widget.selectedIndex
                                ? ButtonStyle(
                                    side: WidgetStatePropertyAll(
                                      BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        width: 3,
                                      ),
                                    ),
                                  )
                                : null,
                            child: labels
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AppIcon(item.$2, size: 22),
                                      const SizedBox(width: 8),
                                      Flexible(child: Text(item.$1)),
                                    ],
                                  )
                                : AppIcon(item.$2, size: 26),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          Expanded(child: FocusTraversalGroup(child: widget.child)),
          const TelevisionTransport(),
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
        final colors = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Material(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('tv-open-player'),
                      onPressed: () => context.push('/player'),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
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
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: strings.rewind15,
                    onPressed: () =>
                        controller.skipBy(const Duration(seconds: -15)),
                    icon: const SeekIntervalIcon(forward: false),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('tv-play-pause'),
                    tooltip: state.isPlaying ? strings.pause : strings.play,
                    onPressed: controller.togglePlayPause,
                    icon: AppIcon(
                      state.isPlaying
                          ? AppIconAssets.playerPause
                          : AppIconAssets.playerPlay,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 8),
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
        );
      },
    );
  }
}
