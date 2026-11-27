import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/download_task.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/bookmarks/bookmark_store.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/settings/local_data_report.dart';

abstract final class LocalDataReportActions {
  static Future<void> exportProgress(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.localProgressExport),
        content: Text(strings.localProgressExportConfirmation),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.localCopyJson),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final persistence = ref.read(playbackPersistenceStoreProvider);
      if (persistence == null) {
        throw StateError('Saved progress is unavailable');
      }
      final store = ref.read(bookmarkStoreProvider);
      await store.load();
      await store.flushPendingWrites();
      if (store.error != null) {
        throw StateError('Saved bookmarks are unavailable');
      }
      final output = LocalDataReport.progressAndBookmarks(
        progress: await persistence.loadProgress(),
        bookmarks: store.entries,
        exportedAt: DateTime.now(),
      );
      if (!context.mounted) return;
      // Mobile clipboards have a bounded IPC buffer. Never truncate an export.
      if (defaultTargetPlatform == TargetPlatform.android &&
          utf8.encode(output).length > 384 * 1024) {
        _showMessage(context, strings.localExportTooLarge);
        return;
      }
      await _copy(context, output);
    } on Object {
      if (context.mounted) _showMessage(context, strings.libraryActionError);
    }
  }

  static Future<void> showDiagnostics(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final persistence = ref.read(downloadPersistenceStoreProvider);
    final playbackStatus = ref.read(playbackControllerProvider).state.status;
    List<DownloadTaskStatus>? downloadStatuses;
    try {
      final tasks = await persistence.loadTasks().timeout(
        const Duration(seconds: 2),
      );
      downloadStatuses = [for (final task in tasks) task.status];
    } on Object {
      // Leave unavailable counters null rather than exposing a database error.
    }
    if (!context.mounted) return;

    final strings = context.strings;
    final output = LocalDataReport.diagnostics(
      platform: defaultTargetPlatform,
      playbackStatus: playbackStatus,
      downloadStatuses: downloadStatuses,
    );
    final copy = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.localDiagnostics),
        content: SelectableText(output),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.localCopyJson),
          ),
        ],
      ),
    );
    if (copy == true && context.mounted) await _copy(context, output);
  }

  static Future<void> _copy(BuildContext context, String data) async {
    final strings = context.strings;
    try {
      await Clipboard.setData(ClipboardData(text: data));
      if (context.mounted) _showMessage(context, strings.localJsonCopied);
    } on Object {
      if (context.mounted) _showMessage(context, strings.libraryActionError);
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
