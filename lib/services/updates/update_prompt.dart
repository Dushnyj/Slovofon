import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_strings.dart';
import '../../ui/icons/app_icons.dart';
import 'update_installer.dart';
import 'update_service.dart';

class UpdateStartupGate extends ConsumerStatefulWidget {
  const UpdateStartupGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdateStartupGate> createState() => _UpdateStartupGateState();
}

class _UpdateStartupGateState extends ConsumerState<UpdateStartupGate> {
  var _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) {
      return;
    }
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkOnStartup());
    });
  }

  Future<void> _checkOnStartup() async {
    if (!mounted) {
      return;
    }
    try {
      final result = await ref.read(updateServiceProvider).checkForUpdate();
      if (!mounted ||
          result.status != UpdateCheckStatus.available ||
          result.info == null) {
        return;
      }
      await showUpdatePrompt(context, ref, result.info!);
    } on Object {
      // Startup checks stay silent; manual checks report errors in Settings.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> showUpdatePrompt(
  BuildContext hostContext,
  WidgetRef ref,
  UpdateInfo info,
) {
  return showDialog<void>(
    context: hostContext,
    barrierDismissible: false,
    builder: (dialogContext) {
      var isBusy = false;
      var downloadedBytes = 0;
      int? totalBytes;
      var bytesPerSecond = 0;
      final downloadTimer = Stopwatch();

      return StatefulBuilder(
        builder: (dialogBodyContext, setDialogState) {
          final strings = dialogBodyContext.strings;
          final progress = totalBytes == null || totalBytes == 0
              ? null
              : downloadedBytes / totalBytes!;
          final expectedBytes = totalBytes ?? info.asset.size;
          final downloadStatus = expectedBytes > 0
              ? strings.updateDownloadProgress(
                  _formatBytes(downloadedBytes, strings.locale),
                  _formatBytes(expectedBytes, strings.locale),
                  _formatBytes(bytesPerSecond, strings.locale),
                )
              : strings.updateDownloading;

          return AlertDialog(
            icon: const AppIcon(AppIconAssets.systemRefresh),
            title: Text(strings.updateAvailableTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.updateAvailableMessage(
                    info.version,
                    _formatBytes(info.asset.size, strings.locale),
                  ),
                ),
                if (isBusy) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    downloadStatus,
                    style: Theme.of(dialogBodyContext).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        await ref.read(updateServiceProvider).skip(info);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                child: Text(strings.skipUpdate),
              ),
              FilledButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        downloadTimer
                          ..reset()
                          ..start();
                        setDialogState(() {
                          isBusy = true;
                          downloadedBytes = 0;
                          totalBytes = info.asset.size > 0
                              ? info.asset.size
                              : null;
                          bytesPerSecond = 0;
                        });
                        try {
                          await ref
                              .read(updateServiceProvider)
                              .downloadAndInstall(
                                info,
                                onProgress: (downloaded, total) {
                                  final elapsedMs =
                                      downloadTimer.elapsedMilliseconds;
                                  setDialogState(() {
                                    downloadedBytes = downloaded;
                                    totalBytes =
                                        total ??
                                        (info.asset.size > 0
                                            ? info.asset.size
                                            : null);
                                    bytesPerSecond = elapsedMs <= 0
                                        ? 0
                                        : (downloaded * 1000 / elapsedMs)
                                              .round();
                                  });
                                },
                              );
                          downloadTimer.stop();
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (hostContext.mounted) {
                            ScaffoldMessenger.of(hostContext).showSnackBar(
                              SnackBar(
                                content: Text(strings.updateInstallerStarted),
                              ),
                            );
                          }
                        } on UpdateInstallPermissionRequired {
                          downloadTimer.stop();
                          if (hostContext.mounted) {
                            ScaffoldMessenger.of(hostContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  strings.updateInstallPermissionRequired,
                                ),
                              ),
                            );
                          }
                          setDialogState(() => isBusy = false);
                        } on Object {
                          downloadTimer.stop();
                          if (hostContext.mounted) {
                            ScaffoldMessenger.of(hostContext).showSnackBar(
                              SnackBar(
                                content: Text(strings.updateDownloadFailed),
                              ),
                            );
                          }
                          setDialogState(() => isBusy = false);
                        }
                      },
                child: Text(strings.updateNow),
              ),
            ],
          );
        },
      );
    },
  );
}

String _formatBytes(int bytes, Locale locale) {
  if (bytes <= 0) {
    return locale.languageCode == 'ru' ? '0 Б' : '0 B';
  }
  final units = locale.languageCode == 'ru'
      ? const ['Б', 'КБ', 'МБ', 'ГБ']
      : const ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final digits = value >= 10 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

Future<void> checkUpdatesManually(BuildContext context, WidgetRef ref) async {
  final strings = context.strings;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(strings.checkingUpdates)),
            ],
          ),
        );
      },
    ),
  );

  try {
    final result = await ref
        .read(updateServiceProvider)
        .checkForUpdate(includeSkipped: true);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!context.mounted) {
      return;
    }
    if (result.status == UpdateCheckStatus.available && result.info != null) {
      await showUpdatePrompt(context, ref, result.info!);
      return;
    }
    final message = result.status == UpdateCheckStatus.unsupported
        ? strings.updateUnsupportedPlatform
        : strings.noUpdatesAvailable;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  } on Object {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.updateCheckFailed)));
    }
  }
}
