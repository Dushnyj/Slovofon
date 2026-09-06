import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller.dart';
import '../../services/audio/playback_controller_provider.dart';
import 'book_cover.dart';
import 'desktop_volume_control.dart';
import 'seek_interval_icon.dart';
import '../icons/app_icons.dart';
import 'playback_source_label.dart';
import 'source_badge.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
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
            surfaceTintColor: Colors.transparent,
            child: InkWell(
              onTap: () => unawaited(context.push('/player')),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: state.bookProgress,
                      minHeight: 2,
                      color: colorScheme.primary,
                      backgroundColor: tokens.onPlayerSurface.withValues(
                        alpha: 0.14,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
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
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.title,
                                    key: const ValueKey('mobile-player-title'),
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
                                    _miniPlayerChapterLabel(chapter),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: tokens.onPlayerSurface
                                              .withValues(alpha: 0.76),
                                          height: 1.05,
                                        ),
                                  ),
                                  // Reflow metadata instead of capping the real
                                  // system + in-app text scaler in player chrome.
                                  Wrap(
                                    spacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '${_formatMiniPlayerDuration(state.position)} · ${(state.bookProgress * 100).round()}%',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: tokens.onPlayerSurface
                                                  .withValues(alpha: 0.66),
                                              height: 1.05,
                                            ),
                                      ),
                                      SourceBadge(
                                        key: const ValueKey(
                                          'mobile-player-source',
                                        ),
                                        sourceId: book.sourceId,
                                        maxLines: 3,
                                      ),
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
                              disabledColor: tokens.onPlayerSurface.withValues(
                                alpha: 0.34,
                              ),
                              onPressed: service.togglePlayPause,
                            ),
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

class DesktopMiniPlayerBar extends ConsumerWidget {
  const DesktopMiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final service = ref.watch(playbackControllerProvider);

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final state = service.state;
        final book = state.book;
        final chapter = state.currentChapter;

        if (book == null || chapter == null) {
          return const SizedBox.shrink();
        }

        if (_isWindowsDesktopPlayer(context)) {
          return _WindowsPlaybackDock(service: service, state: state);
        }

        final chapterDuration = state.chapterDuration;
        final canSeek = chapterDuration > Duration.zero;
        final progress = state.chapterProgress.clamp(0, 1).toDouble();

        return Material(
          key: const ValueKey('desktop-mini-player-bar'),
          color: tokens.playerSurface,
          child: Container(
            constraints: const BoxConstraints(minHeight: 78),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final metadata = _DesktopMiniPlayerMetadata(
                  book: book,
                  chapter: chapter,
                  progress: state.bookProgress,
                );
                final transport = _DesktopTransportControls(
                  service: service,
                  state: state,
                );
                final timeline = _DesktopMiniPlayerProgress(
                  position: state.position,
                  duration: chapterDuration,
                  progress: progress,
                  canSeek: canSeek,
                  onSeek: (value) => unawaited(
                    service.seek(
                      Duration(
                        milliseconds: (chapterDuration.inMilliseconds * value)
                            .round(),
                      ),
                    ),
                  ),
                );
                final tools = _DesktopMiniPlayerTools(
                  volume: state.volume,
                  onOpenChapters: () =>
                      unawaited(context.push('/player?tab=chapters')),
                  onToggleMute: () => unawaited(service.toggleMute()),
                  onVolumeChanged: (value) =>
                      unawaited(service.setVolume(value)),
                  onOpenFullPlayer: () => unawaited(context.push('/player')),
                );
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                if (constraints.maxWidth < 1200 || textScale > 1.5) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: metadata),
                          const SizedBox(width: 18),
                          tools,
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          transport,
                          const SizedBox(width: 22),
                          Expanded(child: timeline),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    transport,
                    const SizedBox(width: 18),
                    SizedBox(width: 330, child: metadata),
                    const SizedBox(width: 22),
                    Expanded(child: timeline),
                    const SizedBox(width: 20),
                    tools,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

bool _isWindowsDesktopPlayer(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.windows;

class _WindowsPlaybackDock extends StatefulWidget {
  const _WindowsPlaybackDock({required this.service, required this.state});

  final PlaybackController service;
  final AudioPlaybackState state;

  @override
  State<_WindowsPlaybackDock> createState() => _WindowsPlaybackDockState();
}

class _WindowsPlaybackDockState extends State<_WindowsPlaybackDock> {
  double? _dragProgress;

  @override
  void didUpdateWidget(covariant _WindowsPlaybackDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.currentChapter?.id != widget.state.currentChapter?.id) {
      _dragProgress = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = widget.state;
    final service = widget.service;
    final book = state.book!;
    final chapter = state.currentChapter!;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final windowHeight = MediaQuery.sizeOf(context).height;
    final lowHeight =
        windowHeight < 560 || (windowHeight < 800 && textScale > 1.25);

    return Material(
      key: const ValueKey('desktop-mini-player-bar'),
      color: colors.surfaceContainerLow,
      child: Container(
        key: const ValueKey('windows-playback-dock'),
        constraints: BoxConstraints(minHeight: lowHeight ? 104 : 116),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Growing text also needs horizontal space: otherwise the source
            // label can otherwise wrap twice in the smallest desktop window.
            final metadataWidth =
                (constraints.maxWidth * 0.29).clamp(190.0, 350.0) +
                ((textScale - 1) * 90).clamp(0.0, 135.0);
            final metadata = Tooltip(
              message: lowHeight
                  ? '${book.title}\n${book.author}\n${chapter.title}\n${context.strings.openFullPlayer}'
                  : context.strings.openFullPlayer,
              child: InkWell(
                key: const ValueKey('desktop-player-book-link'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => unawaited(context.push('/player')),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: lowHeight ? 0 : 4,
                  ),
                  child: Row(
                    children: [
                      BookCover(
                        title: book.title,
                        imageUrl: book.coverUrl,
                        width: 48,
                        height: 66,
                        showProgressPercent: false,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!lowHeight) ...[
                              const SizedBox(height: 3),
                              Text(
                                book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                chapter.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            if (lowHeight) const SizedBox(height: 3),
                            PlaybackSourceLabel(
                              key: const ValueKey('windows-dock-source'),
                              sourceId: book.sourceId,
                              sourceName: book.sourceName,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            final transportControls = _DesktopTransportControls(
              service: service,
              state: state,
            );
            final timeline = _WindowsDockTimeline(
              position: state.position,
              duration: state.chapterDuration,
              slider: SizedBox(
                height: 30,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: colors.surfaceContainerHighest,
                  ),
                  child: Slider(
                    key: const ValueKey('desktop-player-seek'),
                    value: (_dragProgress ?? state.chapterProgress).clamp(0, 1),
                    onChanged: state.chapterDuration > Duration.zero
                        ? (value) => setState(() => _dragProgress = value)
                        : null,
                    onChangeEnd: (value) {
                      setState(() => _dragProgress = null);
                      unawaited(
                        service.seek(
                          Duration(
                            milliseconds:
                                (state.chapterDuration.inMilliseconds * value)
                                    .round(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            final transport = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                transportControls,
                const SizedBox(height: 6),
                timeline,
              ],
            );
            final tools = _DesktopMiniPlayerTools(
              volume: state.volume,
              onOpenChapters: () =>
                  unawaited(context.push('/player?tab=chapters')),
              onToggleMute: () => unawaited(service.toggleMute()),
              onVolumeChanged: (value) => unawaited(service.setVolume(value)),
              onOpenFullPlayer: () => unawaited(context.push('/player')),
            );
            if (lowHeight && constraints.maxWidth >= 800) {
              return Padding(
                key: const ValueKey('windows-low-height-playback-dock'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: metadata),
                        const SizedBox(width: 16),
                        transportControls,
                        const SizedBox(width: 16),
                        tools,
                      ],
                    ),
                    const SizedBox(height: 4),
                    timeline,
                  ],
                ),
              );
            }
            final compact =
                constraints.maxWidth < metadataWidth + 216 + 128 + 88;
            return Padding(
              key: compact
                  ? const ValueKey('windows-compact-playback-dock')
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: compact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(child: metadata),
                            const SizedBox(width: 12),
                            tools,
                          ],
                        ),
                        const SizedBox(height: 12),
                        transport,
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(width: metadataWidth, child: metadata),
                        const SizedBox(width: 24),
                        Expanded(child: transport),
                        const SizedBox(width: 24),
                        tools,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _WindowsDockTimeline extends StatelessWidget {
  const _WindowsDockTimeline({
    required this.position,
    required this.duration,
    required this.slider,
  });

  final Duration position;
  final Duration duration;
  final Widget slider;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final times = [position, duration];
      var timeWidth = 0.0;
      for (final value in times) {
        final painter = TextPainter(
          text: TextSpan(
            text: _formatMiniPlayerDuration(value),
            style: _WindowsDockTime.textStyle(context),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        timeWidth += painter.width;
        painter.dispose();
      }
      if (constraints.maxWidth >= timeWidth + 120) {
        return Row(
          children: [
            _WindowsDockTime(value: position),
            Expanded(child: slider),
            _WindowsDockTime(value: duration),
          ],
        );
      }
      // Preserve both full-size timestamps and a usable seek target when the
      // metadata needs more width at a large accessibility text scale.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          slider,
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final value in times) _WindowsDockTime(value: value),
            ],
          ),
        ],
      );
    },
  );
}

class _WindowsDockTime extends StatelessWidget {
  const _WindowsDockTime({required this.value});
  final Duration value;

  static TextStyle? textStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @override
  Widget build(BuildContext context) =>
      Text(_formatMiniPlayerDuration(value), style: textStyle(context));
}

class _DesktopTransportControls extends StatelessWidget {
  const _DesktopTransportControls({required this.service, required this.state});

  final PlaybackController service;
  final AudioPlaybackState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final strings = context.strings;

    return SizedBox(
      width: _isWindowsDesktopPlayer(context) ? 216 : 264,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _DesktopMiniIconButton(
            tooltip: strings.previousChapter,
            iconAsset: AppIconAssets.playerPreviousChapter,
            color: _isWindowsDesktopPlayer(context)
                ? colorScheme.onSurfaceVariant
                : colorScheme.primary,
            disabledColor: tokens.onPlayerSurface.withValues(alpha: 0.34),
            onPressed: service.previousChapter,
          ),
          _DesktopMiniIconButton(
            tooltip: strings.rewind15,
            iconAsset: AppIconAssets.playerRewind15,
            color: _isWindowsDesktopPlayer(context)
                ? colorScheme.onSurfaceVariant
                : colorScheme.primary,
            disabledColor: tokens.onPlayerSurface.withValues(alpha: 0.34),
            onPressed: () => service.skipBy(const Duration(seconds: -15)),
          ),
          _DesktopPlayButton(
            isPlaying: state.isPlaying,
            onPressed: service.togglePlayPause,
          ),
          _DesktopMiniIconButton(
            tooltip: strings.forward15,
            iconAsset: AppIconAssets.playerForward15,
            color: _isWindowsDesktopPlayer(context)
                ? colorScheme.onSurfaceVariant
                : colorScheme.primary,
            disabledColor: tokens.onPlayerSurface.withValues(alpha: 0.34),
            onPressed: () => service.skipBy(const Duration(seconds: 15)),
          ),
          _DesktopMiniIconButton(
            tooltip: strings.nextChapter,
            iconAsset: AppIconAssets.playerNextChapter,
            color: _isWindowsDesktopPlayer(context)
                ? colorScheme.onSurfaceVariant
                : colorScheme.primary,
            disabledColor: tokens.onPlayerSurface.withValues(alpha: 0.34),
            onPressed: service.nextChapter,
          ),
        ],
      ),
    );
  }
}

class _DesktopMiniPlayerMetadata extends StatelessWidget {
  const _DesktopMiniPlayerMetadata({
    required this.book,
    required this.chapter,
    required this.progress,
  });

  final AudioPlaybackBook book;
  final AudioPlaybackChapter chapter;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppColorTokens>()!;

    return Row(
      children: [
        BookCover(
          title: book.title,
          progress: progress,
          imageUrl: book.coverUrl,
          showProgressPercent: false,
          width: 42,
          height: 54,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                key: const ValueKey('wide-player-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: tokens.onPlayerSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _miniPlayerChapterLabel(chapter),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.onPlayerSurface.withValues(alpha: 0.72),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SourceBadge(
                    key: const ValueKey('wide-player-source'),
                    sourceId: book.sourceId,
                    maxLines: 3,
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.onPlayerSurface.withValues(alpha: 0.66),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopMiniPlayerProgress extends StatelessWidget {
  const _DesktopMiniPlayerProgress({
    required this.position,
    required this.duration,
    required this.progress,
    required this.canSeek,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final double progress;
  final bool canSeek;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: tokens.onPlayerSurface.withValues(alpha: 0.74),
      height: 1,
    );
    final times = [
      _formatMiniPlayerDuration(position),
      _formatMiniPlayerDuration(duration),
    ];
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      child: Slider(value: progress, onChanged: canSeek ? onSeek : null),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        var timeWidth = 0.0;
        for (final value in times) {
          final painter = TextPainter(
            text: TextSpan(text: value, style: style),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
            maxLines: 1,
          )..layout();
          timeWidth += painter.width;
          painter.dispose();
        }
        if (constraints.maxWidth >= timeWidth + 96) {
          return Row(
            children: [
              Text(times.first, style: style),
              Expanded(child: slider),
              Text(times.last, style: style),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            slider,
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [for (final time in times) Text(time, style: style)],
            ),
          ],
        );
      },
    );
  }
}

class _DesktopMiniPlayerTools extends StatelessWidget {
  const _DesktopMiniPlayerTools({
    required this.volume,
    required this.onOpenChapters,
    required this.onToggleMute,
    required this.onVolumeChanged,
    required this.onOpenFullPlayer,
  });

  final double volume;
  final VoidCallback onOpenChapters;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onOpenFullPlayer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final strings = context.strings;

    return SizedBox(
      width: _isWindowsDesktopPlayer(context) ? 128 : 152,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _DesktopMiniIconButton(
            tooltip: strings.chapters,
            iconAsset: AppIconAssets.playerChapters,
            color: _isWindowsDesktopPlayer(context)
                ? colorScheme.onSurfaceVariant
                : colorScheme.primary,
            disabledColor: tokens.onPlayerSurface.withValues(alpha: 0.34),
            onPressed: onOpenChapters,
          ),
          DesktopVolumeControl(
            volume: volume,
            onToggleMute: onToggleMute,
            onVolumeChanged: onVolumeChanged,
          ),
          _DesktopMiniIconButton(
            tooltip: strings.openFullPlayer,
            iconAsset: AppIconAssets.systemExpand,
            color: _isWindowsDesktopPlayer(context)
                ? colorScheme.onSurfaceVariant
                : colorScheme.primary,
            disabledColor: tokens.onPlayerSurface.withValues(alpha: 0.34),
            onPressed: onOpenFullPlayer,
          ),
        ],
      ),
    );
  }
}

class _DesktopMiniIconButton extends StatelessWidget {
  const _DesktopMiniIconButton({
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
    final desktop = _isWindowsDesktopPlayer(context);
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style:
          IconButton.styleFrom(
            minimumSize: Size.square(desktop ? 40 : 48),
            fixedSize: Size.square(desktop ? 40 : 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            foregroundColor: color,
            disabledForegroundColor: disabledColor,
            hoverColor: desktop ? colors.surfaceContainerHighest : null,
            focusColor: desktop ? colors.primary.withValues(alpha: 0.12) : null,
            shape: desktop
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
          ).copyWith(
            animationDuration:
                desktop && MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : null,
            side: desktop
                ? WidgetStateProperty.resolveWith(
                    (states) => BorderSide(
                      color: states.contains(WidgetState.focused)
                          ? colors.primary
                          : colors.surfaceContainerLow,
                      width: 1.5,
                    ),
                  )
                : null,
          ),
      icon:
          desktop &&
              (iconAsset == AppIconAssets.playerRewind15 ||
                  iconAsset == AppIconAssets.playerForward15)
          ? SeekIntervalIcon(
              forward: iconAsset == AppIconAssets.playerForward15,
              color: color,
              size: 24,
            )
          : AppIcon(iconAsset, color: color, size: 21),
    );
  }
}

class _DesktopPlayButton extends StatelessWidget {
  const _DesktopPlayButton({required this.isPlaying, required this.onPressed});

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final desktop = _isWindowsDesktopPlayer(context);

    return IconButton.filled(
      tooltip: isPlaying ? strings.pause : strings.play,
      onPressed: onPressed,
      style:
          IconButton.styleFrom(
            fixedSize: Size.square(desktop ? 46 : 48),
            minimumSize: Size.square(desktop ? 46 : 48),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: desktop
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  )
                : null,
          ).copyWith(
            animationDuration:
                desktop && MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : null,
          ),
      icon: AppIcon(
        isPlaying ? AppIconAssets.playerPause : AppIconAssets.playerPlay,
        color: colorScheme.onPrimary,
        size: 25,
      ),
    );
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
              height: 48,
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

String _miniPlayerChapterLabel(AudioPlaybackChapter chapter) {
  return 'Глава ${chapter.index.toString().padLeft(2, '0')}. ${chapter.title}';
}

String _formatMiniPlayerDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }

  return '$minutes:$seconds';
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
        minimumSize: const Size.square(48),
        fixedSize: const Size.square(48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        foregroundColor: color,
        disabledForegroundColor: disabledColor,
      ),
      icon: AppIcon(iconAsset, color: color, size: 23),
    );
  }
}
