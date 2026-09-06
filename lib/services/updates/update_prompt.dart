import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/app_strings.dart';
import '../../app/project_links.dart';
import '../../ui/adaptive/television_layout.dart';
import '../../ui/icons/app_icons.dart';
import 'update_error_text.dart';
import 'update_installer.dart';
import 'update_service.dart';

/// UI ownership is scoped to the app, not to a Settings page or a route instance.
/// The service separately coalesces network requests and persists skip choices.
final _promptCoordinatorProvider = Provider((ref) => _PromptCoordinator());

class _PromptCoordinator {
  Future<void>? prompt;
  Future<void>? manualCheck;
  int generation = 0;

  bool get isBusy => prompt != null || manualCheck != null;
}

final updateReleasePageLauncherProvider = Provider<Future<bool> Function(Uri)>((
  ref,
) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

class UpdateStartupGate extends ConsumerStatefulWidget {
  const UpdateStartupGate({required this.child, this.navigatorKey, super.key});

  final Widget child;

  /// MaterialApp.router's builder is ABOVE the Navigator. Its own context must
  /// never be passed to Navigator.of/showDialog; use the mounted root overlay.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  ConsumerState<UpdateStartupGate> createState() => _UpdateStartupGateState();
}

class _UpdateStartupGateState extends ConsumerState<UpdateStartupGate>
    with WidgetsBindingObserver {
  Timer? _foregroundTimer;
  bool _checking = false;
  UpdateInfo? _pendingInfo;
  int? _pendingGeneration;
  bool get _isForeground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restartForegroundTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkAutomatically());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _restartForegroundTimer();
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkAutomatically());
    }
  }

  void _restartForegroundTimer() {
    _foregroundTimer?.cancel();
    _foregroundTimer = _isForeground
        ? Timer.periodic(const Duration(hours: 4), (_) {
            unawaited(_checkAutomatically());
          })
        : null;
  }

  @override
  void dispose() {
    _foregroundTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  BuildContext? get _promptContext {
    if (widget.navigatorKey != null) {
      return widget.navigatorKey!.currentState?.overlay?.context;
    }
    // Supports gate use below a Navigator, including focused widget fixtures.
    return Navigator.maybeOf(context, rootNavigator: true)?.overlay?.context;
  }

  Future<void> _checkAutomatically() async {
    if (!mounted || !_isForeground || _checking) return;
    final coordinator = ref.read(_promptCoordinatorProvider);
    if (coordinator.isBusy || _promptContext == null) return;
    _checking = true;
    final generation = coordinator.generation;
    try {
      final pending = _pendingGeneration == generation ? _pendingInfo : null;
      _pendingInfo = null;
      _pendingGeneration = null;
      final result = pending != null
          ? UpdateCheckResult.available(pending)
          : await ref.read(updateServiceProvider).checkForAutomaticUpdate();
      if (!mounted ||
          coordinator.isBusy ||
          coordinator.generation != generation ||
          result.status != UpdateCheckStatus.available ||
          result.info == null) {
        return;
      }
      if (!_isForeground) {
        // A completed request must not be lost to the automatic cooldown just
        // because the app was backgrounded while waiting for the response.
        _pendingInfo = result.info;
        _pendingGeneration = generation;
        return;
      }
      final promptContext = _promptContext;
      if (promptContext == null || !promptContext.mounted) return;
      await showUpdatePrompt(promptContext, ref, result.info!);
    } on Object {
      // Automatic checks stay silent; Settings displays actionable errors.
    } finally {
      _checking = false;
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
  if (!hostContext.mounted) return Future<void>.value();
  final coordinator = ref.read(_promptCoordinatorProvider);
  if (coordinator.prompt != null) return coordinator.prompt!;
  if (coordinator.manualCheck != null) return Future<void>.value();
  return _presentUpdatePrompt(hostContext, ref, info, coordinator);
}

Future<void> _presentUpdatePrompt(
  BuildContext hostContext,
  WidgetRef ref,
  UpdateInfo info,
  _PromptCoordinator coordinator,
) {
  if (coordinator.prompt != null) return coordinator.prompt!;
  coordinator.generation++;
  final navigator = Navigator.of(hostContext, rootNavigator: true);
  final service = ref.read(updateServiceProvider);
  final launchReleasePage = ref.read(updateReleasePageLauncherProvider);
  final messenger = ScaffoldMessenger.maybeOf(hostContext);
  late final DialogRoute<void> updateRoute;
  updateRoute = DialogRoute<void>(
    context: hostContext,
    themes: InheritedTheme.capture(from: hostContext, to: navigator.context),
    barrierDismissible: false,
    builder: (dialogContext) => _UpdatePromptDialog(
      info: info,
      service: service,
      launchReleasePage: launchReleasePage,
      onClose: () {
        if (navigator.mounted && updateRoute.isActive) {
          navigator.removeRoute(updateRoute);
        }
      },
      onInstalled: (message) {
        if (messenger?.mounted ?? false) {
          messenger!.showSnackBar(SnackBar(content: Text(message)));
        }
      },
    ),
  );
  final completion = Completer<void>();
  coordinator.prompt = completion.future;
  unawaited(
    navigator
        .push(updateRoute)
        .then(
          (_) {
            coordinator.prompt = null;
            completion.complete();
          },
          onError: (Object error, StackTrace stack) {
            coordinator.prompt = null;
            completion.completeError(error, stack);
          },
        ),
  );
  return completion.future;
}

class _UpdatePromptDialog extends StatefulWidget {
  const _UpdatePromptDialog({
    required this.info,
    required this.service,
    required this.launchReleasePage,
    required this.onClose,
    required this.onInstalled,
  });

  final UpdateInfo info;
  final UpdateService service;
  final Future<bool> Function(Uri) launchReleasePage;
  final VoidCallback onClose;
  final ValueChanged<String> onInstalled;

  @override
  State<_UpdatePromptDialog> createState() => _UpdatePromptDialogState();
}

class _UpdatePromptDialogState extends State<_UpdatePromptDialog> {
  bool _isBusy = false;
  bool _savingSkip = false;
  bool _retryAction = false;
  int _downloadedBytes = 0;
  int? _totalBytes;
  int _bytesPerSecond = 0;
  String? _message;
  final _downloadTimer = Stopwatch();
  final _notesFocus = FocusNode(debugLabel: 'update-release-notes');

  @override
  void dispose() {
    _notesFocus.dispose();
    super.dispose();
  }

  bool get _canClose => !_isBusy && !_savingSkip;

  Widget _remoteAction(Widget child, {required bool notesAvailable}) {
    if (!TelevisionLayout.isActive(context) || !notesAvailable) return child;
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent ||
            event.logicalKey != LogicalKeyboardKey.arrowUp) {
          return KeyEventResult.ignored;
        }
        // The notes heading may start below the clipped viewport. Geometric
        // directional traversal alone cannot reach that offscreen control.
        _notesFocus.requestFocus();
        final notesContext = _notesFocus.context;
        if (notesContext != null) {
          unawaited(Scrollable.ensureVisible(notesContext, alignment: 0));
        }
        return KeyEventResult.handled;
      },
      child: child,
    );
  }

  KeyEventResult _scrollNotesWithRemote(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.pageDown => 1,
      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.pageUp => -1,
      _ => 0,
    };
    final scroll = node.context == null
        ? null
        : Scrollable.maybeOf(node.context!)?.position;
    if (direction == 0 || scroll == null) return KeyEventResult.ignored;
    return _scrollNotes(scroll, direction)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  bool _scrollNotes(ScrollPosition scroll, int direction) {
    final target = (scroll.pixels + direction * scroll.viewportDimension * .7)
        .clamp(scroll.minScrollExtent, scroll.maxScrollExtent);
    if ((target - scroll.pixels).abs() < .5) return false;
    // The focused notes heading stays focused while scrolling. At either edge,
    // unhandled D-pad events return to normal TV focus traversal and actions.
    scroll.jumpTo(target);
    return true;
  }

  Future<void> _skip() async {
    if (!_canClose) return;
    setState(() {
      _savingSkip = true;
      _message = null;
    });
    try {
      await widget.service.skip(widget.info);
      if (mounted) widget.onClose();
    } on Object {
      if (!mounted) return;
      setState(() {
        _savingSkip = false;
        _message = context.strings.updateSkipFailed;
      });
    }
  }

  Future<void> _startDownload() async {
    if (!_canClose) return;
    final strings = context.strings;
    setState(() {
      _isBusy = true;
      _retryAction = false;
      _message = null;
      _downloadedBytes = 0;
      _totalBytes = widget.info.asset.size > 0 ? widget.info.asset.size : null;
      _bytesPerSecond = 0;
    });
    _downloadTimer
      ..reset()
      ..start();
    try {
      if (widget.info.requiresManualDownload) {
        // The fixed repository URL cannot be replaced by untrusted release text.
        final opened = await widget.launchReleasePage(
          Uri.parse(ProjectLinks.githubReleases),
        );
        if (!mounted) return;
        if (opened) {
          widget.onClose();
        } else {
          setState(() {
            _isBusy = false;
            _retryAction = true;
            _message = strings.updateReleasePageFailed;
          });
        }
        return;
      }
      await widget.service.downloadAndInstall(
        widget.info,
        onProgress: (downloaded, total) {
          if (!mounted) return;
          final elapsedMs = _downloadTimer.elapsedMilliseconds;
          setState(() {
            _downloadedBytes = downloaded;
            _totalBytes = total ?? _totalBytes;
            _bytesPerSecond = elapsedMs <= 0
                ? 0
                : (downloaded * 1000 / elapsedMs).round();
          });
        },
      );
      if (!mounted) return;
      widget.onClose();
      widget.onInstalled(
        widget.info.isPortableUpdate
            ? strings.updatePortableReady
            : strings.updateInstallerStarted,
      );
    } on UpdateInstallPermissionRequired {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _message = strings.updateInstallPermissionRequired;
      });
    } on Object catch (error) {
      if (!mounted) return;
      final text = updateDownloadErrorText(strings: strings, error: error);
      setState(() {
        _isBusy = false;
        _retryAction = true;
        _message = widget.info.requiresManualDownload
            ? strings.updateReleasePageFailed
            : '${text.title}\n${text.message}';
      });
    } finally {
      _downloadTimer.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final progress = _totalBytes == null || _totalBytes! <= 0
        ? null
        : (_downloadedBytes / _totalBytes!).clamp(0.0, 1.0);
    final expectedBytes = _totalBytes ?? info.asset.size;
    final notes = info.manifest.releaseNotes?.trim();
    final actionLabel = info.requiresManualDownload
        ? strings.updateOpenReleases
        : info.isPortableUpdate
        ? strings.updateDownloadZip
        : strings.updateNow;
    return PopScope(
      canPop: _canClose,
      child: AlertDialog(
        scrollable: true,
        icon: const AppIcon(AppIconAssets.systemRefresh),
        title: Text(
          !_isBusy
              ? strings.updateAvailableTitle
              : progress != null && progress >= 1
              ? strings.updatePreparingTitle
              : strings.updateDownloading,
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.updateAvailableMessage(
                  info.version,
                  _formatBytes(info.asset.size, strings.locale),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                info.requiresManualDownload
                    ? strings.updateManualDownloadHint
                    : info.isPortableUpdate
                    ? strings.updatePortableHint
                    : strings.updateInstallerHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!_isBusy && notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                if (TelevisionLayout.isActive(context))
                  Focus(
                    canRequestFocus: false,
                    onKeyEvent: _scrollNotesWithRemote,
                    child: Builder(
                      builder: (notesContext) => TextButton(
                        key: const ValueKey('update-notes-remote-focus'),
                        focusNode: _notesFocus,
                        onPressed: () {
                          final position = Scrollable.maybeOf(
                            notesContext,
                          )?.position;
                          if (position != null) _scrollNotes(position, 1);
                        },
                        child: Text(strings.updateReleaseNotes),
                      ),
                    ),
                  )
                else
                  Text(
                    strings.updateReleaseNotes,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                const SizedBox(height: 8),
                // Release notes are untrusted plain text, not executable HTML.
                Text(notes),
              ],
              if (_isBusy) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  expectedBytes > 0
                      ? strings.updateDownloadProgress(
                          _formatBytes(_downloadedBytes, strings.locale),
                          _formatBytes(expectedBytes, strings.locale),
                          _formatBytes(_bytesPerSecond, strings.locale),
                        )
                      : strings.updateDownloading,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(_message!, style: TextStyle(color: colors.error)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!_isBusy) ...[
            _remoteAction(
              TextButton(
                onPressed: _canClose ? widget.onClose : null,
                child: Text(strings.updateLater),
              ),
              notesAvailable: notes != null && notes.isNotEmpty,
            ),
            if (!info.manifest.mandatory)
              _remoteAction(
                TextButton(
                  onPressed: _canClose ? _skip : null,
                  child: Text(strings.skipUpdate),
                ),
                notesAvailable: notes != null && notes.isNotEmpty,
              ),
            _remoteAction(
              FilledButton(
                autofocus: true,
                onPressed: _canClose ? _startDownload : null,
                child: Text(_retryAction ? strings.retry : actionLabel),
              ),
              notesAvailable: notes != null && notes.isNotEmpty,
            ),
          ],
        ],
      ),
    );
  }
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

Future<void> checkUpdatesManually(BuildContext context, WidgetRef ref) {
  if (!context.mounted) return Future<void>.value();
  final coordinator = ref.read(_promptCoordinatorProvider);
  if (coordinator.prompt != null) return coordinator.prompt!;
  if (coordinator.manualCheck != null) return coordinator.manualCheck!;
  final completion = Completer<void>();
  coordinator.generation++;
  coordinator.manualCheck = completion.future;
  unawaited(
    _checkUpdatesManually(context, ref, coordinator).then(
      (_) {
        coordinator.manualCheck = null;
        completion.complete();
      },
      onError: (Object error, StackTrace stack) {
        coordinator.manualCheck = null;
        completion.completeError(error, stack);
      },
    ),
  );
  return completion.future;
}

Future<void> _checkUpdatesManually(
  BuildContext context,
  WidgetRef ref,
  _PromptCoordinator coordinator,
) async {
  final strings = context.strings;
  final navigator = Navigator.of(context, rootNavigator: true);
  final service = ref.read(updateServiceProvider);
  var retry = true;
  while (retry && context.mounted && navigator.mounted) {
    if (!context.mounted || !navigator.mounted) return;
    retry = false;
    final progressRoute = DialogRoute<void>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        scrollable: true,
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
      ),
    );
    unawaited(navigator.push(progressRoute));

    bool closeProgressIfCurrent() {
      if (!navigator.mounted || !progressRoute.isActive) return false;
      final wasCurrent = progressRoute.isCurrent;
      // Remove only this exact route. Back or an unrelated top route dismisses
      // the eventual result rather than closing somebody else's screen.
      navigator.removeRoute(progressRoute);
      return wasCurrent && context.mounted;
    }

    try {
      final result = await service.checkForUpdate(includeSkipped: true);
      if (!closeProgressIfCurrent() || !context.mounted) return;
      if (result.status == UpdateCheckStatus.available && result.info != null) {
        await _presentUpdatePrompt(context, ref, result.info!, coordinator);
        return;
      }
      final message = result.status == UpdateCheckStatus.unsupported
          ? strings.updateUnsupportedPlatform
          : strings.noUpdatesAvailable;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (error) {
      if (!closeProgressIfCurrent() || !context.mounted) return;
      final text = updateCheckErrorText(strings: strings, error: error);
      retry =
          await showDialog<bool>(
            context: context,
            builder: (errorContext) => AlertDialog(
              scrollable: true,
              icon: const AppIcon(AppIconAssets.systemWarning),
              title: Text(text.title),
              content: Text(text.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(errorContext).pop(false),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(errorContext).pop(true),
                  child: Text(strings.retry),
                ),
              ],
            ),
          ) ??
          false;
    }
  }
}
