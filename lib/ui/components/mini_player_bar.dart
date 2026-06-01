import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller_provider.dart';
import 'book_cover.dart';
import '../icons/app_icons.dart';
import 'source_badge.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final service = ref.watch(playbackControllerProvider);
    final strings = context.strings;
    final rawTextScale = MediaQuery.textScalerOf(context).scale(1);
    final chromeTextScale = rawTextScale.clamp(1.0, 1.12).toDouble();
    final barHeight = rawTextScale > 1.05 ? 58.0 : 48.0;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final state = service.state;
        final book = state.book;
        final chapter = state.currentChapter;

        if (book == null || chapter == null) {
          return const SizedBox.shrink();
        }

        return Tooltip(
          message: strings.openFullPlayer,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(chromeTextScale)),
            child: Material(
              color: tokens.playerSurface,
              surfaceTintColor: Colors.transparent,
              child: InkWell(
                onTap: () => unawaited(context.push('/player')),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: SizedBox(
                    height: barHeight,
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: state.bookProgress,
                          minHeight: 2,
                          color: colorScheme.primary,
                          backgroundColor: tokens.onPlayerSurface.withValues(
                            alpha: 0.14,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                BookCover(
                                  title: book.title,
                                  progress: state.bookProgress,
                                  imageUrl: book.coverUrl,
                                  showProgressPercent: false,
                                  width: 34,
                                  height: 42,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        book.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: tokens.onPlayerSurface,
                                            ),
                                      ),
                                      Text(
                                        _chapterLabel(chapter),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: tokens.onPlayerSurface
                                                  .withValues(alpha: 0.76),
                                              height: 1.05,
                                            ),
                                      ),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '${_formatDuration(state.position)} · ${(state.bookProgress * 100).round()}%',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: tokens
                                                        .onPlayerSurface
                                                        .withValues(
                                                          alpha: 0.66,
                                                        ),
                                                    height: 1.05,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SourceBadge(sourceId: book.sourceId),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                _MiniPlayerIconButton(
                                  tooltip: state.isPlaying
                                      ? strings.pause
                                      : strings.play,
                                  iconAsset: state.isPlaying
                                      ? AppIconAssets.playerPause
                                      : AppIconAssets.playerPlay,
                                  color: colorScheme.primary,
                                  disabledColor: tokens.onPlayerSurface
                                      .withValues(alpha: 0.34),
                                  onPressed: service.togglePlayPause,
                                ),
                                _MiniPlayerIconButton(
                                  tooltip: strings.nextChapter,
                                  iconAsset: AppIconAssets.playerNextChapter,
                                  color: colorScheme.primary,
                                  disabledColor: tokens.onPlayerSurface
                                      .withValues(alpha: 0.34),
                                  onPressed: service.nextChapter,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _chapterLabel(AudioPlaybackChapter chapter) {
    return 'Глава ${chapter.index.toString().padLeft(2, '0')}. ${chapter.title}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }

    return '$minutes:$seconds';
  }
}

class MiniPlayerControlsBar extends ConsumerWidget {
  const MiniPlayerControlsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(playbackControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final strings = context.strings;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final state = service.state;
        if (!state.hasBook) {
          return const SizedBox.shrink();
        }

        return Material(
          color: tokens.playerSurface,
          surfaceTintColor: Colors.transparent,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniPlayerIconButton(
                    tooltip: strings.previousChapter,
                    iconAsset: AppIconAssets.playerPreviousChapter,
                    color: colorScheme.primary,
                    disabledColor: tokens.onPlayerSurface.withValues(
                      alpha: 0.34,
                    ),
                    onPressed: service.previousChapter,
                  ),
                  const SizedBox(width: 12),
                  _MiniPlayerIconButton(
                    tooltip: strings.rewind15,
                    iconAsset: AppIconAssets.playerRewind15,
                    color: colorScheme.primary,
                    disabledColor: tokens.onPlayerSurface.withValues(
                      alpha: 0.34,
                    ),
                    onPressed: () =>
                        service.skipBy(const Duration(seconds: -15)),
                  ),
                  const SizedBox(width: 12),
                  _MiniPlayerIconButton(
                    tooltip: state.isPlaying ? strings.pause : strings.play,
                    iconAsset: state.isPlaying
                        ? AppIconAssets.playerPause
                        : AppIconAssets.playerPlay,
                    color: colorScheme.primary,
                    disabledColor: tokens.onPlayerSurface.withValues(
                      alpha: 0.34,
                    ),
                    onPressed: service.togglePlayPause,
                  ),
                  const SizedBox(width: 12),
                  _MiniPlayerIconButton(
                    tooltip: strings.forward15,
                    iconAsset: AppIconAssets.playerForward15,
                    color: colorScheme.primary,
                    disabledColor: tokens.onPlayerSurface.withValues(
                      alpha: 0.34,
                    ),
                    onPressed: () =>
                        service.skipBy(const Duration(seconds: 15)),
                  ),
                  const SizedBox(width: 12),
                  _MiniPlayerIconButton(
                    tooltip: strings.nextChapter,
                    iconAsset: AppIconAssets.playerNextChapter,
                    color: colorScheme.primary,
                    disabledColor: tokens.onPlayerSurface.withValues(
                      alpha: 0.34,
                    ),
                    onPressed: service.nextChapter,
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

class _MiniPlayerIconButton extends StatelessWidget {
  const _MiniPlayerIconButton({
    required this.tooltip,
    required this.iconAsset,
    required this.color,
    required this.disabledColor,
    required this.onPressed,
  });

  final String tooltip;
  final String iconAsset;
  final Color color;
  final Color disabledColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(34),
        fixedSize: const Size.square(34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        foregroundColor: color,
        disabledForegroundColor: disabledColor,
      ),
      icon: AppIcon(iconAsset, color: color, size: 23),
    );
  }
}
