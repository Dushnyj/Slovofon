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

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final service = ref.watch(playbackControllerProvider);
    final strings = context.strings;

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
          child: Material(
            color: tokens.playerSurface,
            child: InkWell(
              onTap: () => unawaited(context.push('/player')),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 62,
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: state.bookProgress,
                        minHeight: 2.5,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              BookCover(
                                title: book.title,
                                progress: state.bookProgress,
                                imageUrl: book.coverUrl,
                                showProgressPercent: false,
                                width: 38,
                                height: 48,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    const SizedBox(height: 3),
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
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatDuration(state.position)} · ${(state.bookProgress * 100).round()}%',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: tokens.onPlayerSurface
                                                .withValues(alpha: 0.66),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: state.isPlaying
                                    ? strings.pause
                                    : strings.play,
                                onPressed: () => service.togglePlayPause(),
                                icon: AppIcon(
                                  state.isPlaying
                                      ? AppIconAssets.playerPause
                                      : AppIconAssets.playerPlay,
                                  color: tokens.onPlayerSurface,
                                ),
                              ),
                              IconButton(
                                tooltip: strings.nextChapter,
                                onPressed: () => service.nextChapter(),
                                icon: AppIcon(
                                  AppIconAssets.playerNextChapter,
                                  color: tokens.onPlayerSurface,
                                ),
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
