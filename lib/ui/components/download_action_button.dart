import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../icons/app_icons.dart';
import 'app_buttons.dart';

enum BookCardDownloadState {
  none,
  queued,
  downloading,
  downloaded,
  paused,
  failed,
}

class DownloadActionButton extends StatelessWidget {
  const DownloadActionButton({
    required this.state,
    required this.onPressed,
    this.progress = 0,
    this.isResolving = false,
    this.size = 44,
    super.key,
  });

  final BookCardDownloadState state;
  final VoidCallback? onPressed;
  final double progress;
  final bool isResolving;
  final double size;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;

    if (isResolving) {
      return Tooltip(
        message: strings.download,
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: SizedBox.square(
              key: const ValueKey('download-action-resolving'),
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    if (state == BookCardDownloadState.downloading ||
        state == BookCardDownloadState.queued) {
      final boundedProgress = progress.clamp(0, 1).toDouble();
      final isIndeterminate =
          state == BookCardDownloadState.downloading && boundedProgress <= 0;
      return SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: size - 8,
              child: CircularProgressIndicator(
                key: const ValueKey('download-action-progress'),
                value: isIndeterminate ? null : boundedProgress,
                strokeWidth: 3,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            AppIconActionButton(
              tooltip: strings.cancelDownload,
              iconAsset: AppIconAssets.systemClose,
              onPressed: onPressed,
              iconSize: 18,
              buttonSize: size,
              foregroundColor: colorScheme.error,
            ),
          ],
        ),
      );
    }

    return AppIconActionButton(
      tooltip: _tooltip(strings, state),
      iconAsset: _icon(state),
      onPressed: onPressed,
      buttonSize: size,
      foregroundColor: _foreground(colorScheme, state),
    );
  }

  String _icon(BookCardDownloadState state) {
    return switch (state) {
      BookCardDownloadState.downloaded => AppIconAssets.deleteDownload,
      BookCardDownloadState.paused => AppIconAssets.resumeDownload,
      BookCardDownloadState.failed => AppIconAssets.downloadRetry,
      BookCardDownloadState.none => AppIconAssets.download,
      BookCardDownloadState.queued ||
      BookCardDownloadState.downloading => AppIconAssets.systemClose,
    };
  }

  String _tooltip(AppStrings strings, BookCardDownloadState state) {
    return switch (state) {
      BookCardDownloadState.downloaded => strings.deleteDownloaded,
      BookCardDownloadState.paused => strings.resumeDownload,
      BookCardDownloadState.failed => strings.retry,
      BookCardDownloadState.none => strings.download,
      BookCardDownloadState.queued ||
      BookCardDownloadState.downloading => strings.cancelDownload,
    };
  }

  Color _foreground(ColorScheme colorScheme, BookCardDownloadState state) {
    return switch (state) {
      BookCardDownloadState.downloaded => colorScheme.error,
      BookCardDownloadState.failed => colorScheme.error,
      BookCardDownloadState.paused => colorScheme.primary,
      BookCardDownloadState.none => colorScheme.onSurfaceVariant,
      BookCardDownloadState.queued ||
      BookCardDownloadState.downloading => colorScheme.error,
    };
  }
}
