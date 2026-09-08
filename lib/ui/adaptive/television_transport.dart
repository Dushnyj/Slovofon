import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../components/book_cover.dart';
import '../components/playback_source_label.dart';
import '../components/seek_interval_icon.dart';
import '../icons/app_icons.dart';

/// Persistent TV transport: artwork, source, chapter and seeking, without a
/// second oversized information card. Text scaling reflows rather than clips.
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
        final busy =
            state.status == AudioPlaybackStatus.loading ||
            state.status == AudioPlaybackStatus.buffering;
        final canSeek = state.chapterDuration > Duration.zero && !busy;
        final canSkip = state.currentChapter != null && !busy;
        const secondaryStyle = ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size.square(36)),
          fixedSize: WidgetStatePropertyAll(Size.square(36)),
          maximumSize: WidgetStatePropertyAll(Size.square(36)),
          padding: WidgetStatePropertyAll(EdgeInsets.all(6)),
        );
        Widget secondaryButton({
          required String key,
          required String tooltip,
          required Widget icon,
          required VoidCallback? onPressed,
        }) => ExcludeFocus(
          // Material keeps disabled InkWell targets focusable in directional
          // mode. Skip unavailable boundary controls, while retaining their
          // disabled appearance and semantics.
          excluding: onPressed == null,
          child: IconButton(
            key: ValueKey(key),
            tooltip: tooltip,
            onPressed: onPressed,
            style: icon is SeekIntervalIcon
                ? secondaryStyle.copyWith(
                    padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
                  )
                : secondaryStyle,
            icon: icon,
          ),
        );
        final controls = Row(
          key: const ValueKey('tv-transport-controls'),
          mainAxisSize: MainAxisSize.min,
          children: [
            secondaryButton(
              key: 'tv-previous-chapter',
              tooltip: strings.previousChapter,
              onPressed: canSkip && state.chapterIndex > 0
                  ? controller.previousChapter
                  : null,
              icon: const AppIcon(
                AppIconAssets.playerPreviousChapter,
                size: 20,
              ),
            ),
            const SizedBox(width: 3),
            secondaryButton(
              key: 'tv-rewind-15',
              tooltip: strings.rewind15,
              onPressed: canSkip
                  ? () => controller.skipBy(const Duration(seconds: -15))
                  : null,
              icon: const SeekIntervalIcon(forward: false),
            ),
            const SizedBox(width: 3),
            IconButton.filled(
              key: const ValueKey('tv-play-pause'),
              tooltip: state.isPlaying || busy ? strings.pause : strings.play,
              onPressed: state.currentChapter == null
                  ? null
                  : controller.togglePlayPause,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
                fixedSize: const WidgetStatePropertyAll(Size.square(40)),
                maximumSize: const WidgetStatePropertyAll(Size.square(40)),
                backgroundColor: WidgetStatePropertyAll(colors.primary),
                foregroundColor: WidgetStatePropertyAll(colors.onPrimary),
                side: WidgetStateProperty.resolveWith(
                  (states) => BorderSide(
                    color: states.contains(WidgetState.focused)
                        ? colors.onPrimary
                        : colors.primary,
                    width: 2,
                  ),
                ),
              ),
              icon: busy
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : AppIcon(
                      state.isPlaying
                          ? AppIconAssets.playerPause
                          : AppIconAssets.playerPlay,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 3),
            secondaryButton(
              key: 'tv-forward-15',
              tooltip: strings.forward15,
              onPressed: canSkip
                  ? () => controller.skipBy(const Duration(seconds: 15))
                  : null,
              icon: const SeekIntervalIcon(forward: true),
            ),
            const SizedBox(width: 3),
            secondaryButton(
              key: 'tv-next-chapter',
              tooltip: strings.nextChapter,
              onPressed:
                  canSkip && state.chapterIndex < book.chapters.length - 1
                  ? controller.nextChapter
                  : null,
              icon: const AppIcon(AppIconAssets.playerNextChapter, size: 20),
            ),
          ],
        );
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                  final wide = constraints.maxWidth >= 700 * scale;
                  final identity = TextButton(
                    key: const ValueKey('tv-open-player'),
                    onPressed: () => context.push('/player'),
                    style: ButtonStyle(
                      padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
                      overlayColor: WidgetStatePropertyAll(
                        colors.primary.withValues(alpha: 0),
                      ),
                      backgroundColor: WidgetStatePropertyAll(
                        colors.surfaceContainer,
                      ),
                      foregroundColor: WidgetStatePropertyAll(colors.onSurface),
                      side: WidgetStateProperty.resolveWith(
                        (states) => BorderSide(
                          color: states.contains(WidgetState.focused)
                              ? colors.primary
                              : colors.surfaceContainer,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: BookCover(
                            title: book.title,
                            imageUrl: book.coverUrl,
                            width: 32,
                            height: 46,
                            showProgressPercent: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (wide && book.author.isNotEmpty)
                                Text(
                                  book.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              PlaybackSourceLabel(
                                sourceId: book.sourceId,
                                sourceName: book.sourceName,
                                maxLines: 1,
                                textStyle: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  final progress = _TelevisionChapterProgress(
                    key: ValueKey(
                      '${book.id}/${book.versionId}/${state.currentChapter?.id}',
                    ),
                    chapter: state.currentChapter?.title ?? '',
                    position: state.position,
                    duration: state.chapterDuration,
                    enabled: canSeek,
                    onSeek: controller.seek,
                    onSkip: controller.skipBy,
                  );
                  if (wide) {
                    return Row(
                      key: const ValueKey('tv-transport-wide'),
                      children: [
                        SizedBox(
                          width: (constraints.maxWidth * .30).clamp(
                            180.0,
                            240.0,
                          ),
                          child: identity,
                        ),
                        const SizedBox(width: 12),
                        controls,
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: progress),
                      ],
                    );
                  }
                  return Column(
                    key: const ValueKey('tv-transport-reflowed'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (constraints.maxWidth >= 360 + 80 * (scale - 1))
                        Row(
                          children: [
                            Expanded(child: identity),
                            const SizedBox(width: 8),
                            controls,
                          ],
                        )
                      else ...[
                        identity,
                        const SizedBox(height: 4),
                        controls,
                      ],
                      progress,
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TelevisionChapterProgress extends StatefulWidget {
  const _TelevisionChapterProgress({
    super.key,
    required this.chapter,
    required this.position,
    required this.duration,
    required this.enabled,
    required this.onSeek,
    required this.onSkip,
  });
  final String chapter;
  final Duration position, duration;
  final bool enabled;
  final ValueChanged<Duration> onSeek, onSkip;
  @override
  State<_TelevisionChapterProgress> createState() =>
      _TelevisionChapterProgressState();
}

class _TelevisionChapterProgressState
    extends State<_TelevisionChapterProgress> {
  double? _drag;
  late final _seekFocus = FocusNode(
    debugLabel: 'TV chapter seek',
    onKeyEvent: (_, event) {
      if (!widget.enabled ||
          (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
        return KeyEventResult.ignored;
      }
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight) {
        widget.onSkip(
          Duration(seconds: key == LogicalKeyboardKey.arrowRight ? 15 : -15),
        );
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  @override
  void dispose() {
    _seekFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = widget.duration.inMilliseconds;
    final fraction = duration > 0
        ? (widget.position.inMilliseconds / duration).clamp(0.0, 1.0)
        : 0.0;
    final value = widget.enabled ? (_drag ?? fraction) : fraction;
    final position = duration > 0
        ? Duration(milliseconds: (duration * value).round())
        : widget.position;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.chapter,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Row(
          children: [
            Text(_time(position), style: theme.textTheme.labelSmall),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 4,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  key: const ValueKey('tv-chapter-progress'),
                  focusNode: _seekFocus,
                  value: value,
                  semanticFormatterCallback: (value) =>
                      _time(Duration(milliseconds: (duration * value).round())),
                  onChanged: widget.enabled
                      ? (value) => setState(() => _drag = value)
                      : null,
                  onChangeEnd: widget.enabled
                      ? (value) {
                          setState(() => _drag = null);
                          widget.onSeek(
                            Duration(milliseconds: (duration * value).round()),
                          );
                        }
                      : null,
                ),
              ),
            ),
            Text(_time(widget.duration), style: theme.textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

String _time(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 1 << 31);
  final minutes = (seconds ~/ 60 % 60).toString().padLeft(2, '0');
  final tail = (seconds % 60).toString().padLeft(2, '0');
  return seconds >= 3600
      ? '${seconds ~/ 3600}:$minutes:$tail'
      : '${seconds ~/ 60}:$tail';
}
