import 'package:flutter/material.dart';

import '../../app/theme/app_color_tokens.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../icons/app_icons.dart';

class DownloadStatusChip extends StatelessWidget {
  const DownloadStatusChip({required this.status, super.key});

  final MockDownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final background = switch (status) {
      MockDownloadStatus.downloaded => tokens.success,
      MockDownloadStatus.downloading => tokens.info,
      MockDownloadStatus.queued => colorScheme.secondaryContainer,
      MockDownloadStatus.paused => tokens.warning,
      MockDownloadStatus.failed => tokens.error,
    };
    final foreground = AppColorTokens.readableOn(background);

    return Chip(
      avatar: AppIcon(_iconAsset, size: 16, color: foreground),
      label: Text(_label),
      labelStyle: TextStyle(color: foreground),
      backgroundColor: background,
      side: BorderSide(color: background),
      visualDensity: VisualDensity.compact,
    );
  }

  String get _label {
    return switch (status) {
      MockDownloadStatus.downloaded => 'Downloaded',
      MockDownloadStatus.downloading => 'Downloading',
      MockDownloadStatus.queued => 'Queued',
      MockDownloadStatus.paused => 'Paused',
      MockDownloadStatus.failed => 'Failed',
    };
  }

  String get _iconAsset {
    return switch (status) {
      MockDownloadStatus.downloaded => AppIconAssets.downloaded,
      MockDownloadStatus.downloading => AppIconAssets.downloading,
      MockDownloadStatus.queued => AppIconAssets.downloadQueued,
      MockDownloadStatus.paused => AppIconAssets.pauseDownload,
      MockDownloadStatus.failed => AppIconAssets.downloadError,
    };
  }
}
