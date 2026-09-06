import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_version.dart';
import '../../app/localization/app_strings.dart';
import '../../app/project_links.dart';
import '../../app/theme/app_color_tokens.dart';
import '../../app/theme/app_text_scaler.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/windows_theme.dart';
import '../../domain/models/app_settings.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/downloads/download_storage.dart';
import '../../services/settings/app_settings_store.dart';
import '../../services/sources/source_settings_store.dart';
import '../../services/updates/update_prompt.dart';
import '../../ui/components/app_bar_text.dart';
import '../../ui/adaptive/adaptive_sheet.dart';
import '../../ui/adaptive/desktop_layout.dart';
import '../../ui/components/filter_picker_sheet.dart';
import '../../ui/icons/app_icons.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Keep Slider's active gesture and focus when text scaling reflows columns.
  final _inlineAppearanceKey = GlobalKey(
    debugLabel: 'inline-appearance-editor',
  );
  Future<CardCacheStats>? _cacheStatsFuture;
  // Owned above the responsive columns: changing text scale can reparent the
  // editor from a Row to a Column while an earlier save is still completing.
  double? _inlinePreviewScale;
  int _inlinePreviewRevision = 0;
  final _sectionKeys = List.generate(5, (_) => GlobalKey());
  final _sectionMenuController = MenuController();

  void _jumpToSection(int index) {
    // The menu route must detach its semantics before moving the page beneath it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _sectionKeys[index].currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: DesktopLayout.motionDuration(context),
      );
    });
  }

  Future<void> _commitInlineScale(double value) async {
    final revision = _inlinePreviewRevision;
    await ref.read(appSettingsStoreProvider).setTextScale(value);
    if (mounted && revision == _inlinePreviewRevision) {
      setState(() => _inlinePreviewScale = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final desktop = DesktopLayout.isActive(context);
    final appSettingsStore = ref.watch(appSettingsStoreProvider);
    final sourceSettings = ref.watch(sourceSettingsStoreProvider);
    final downloadStorage = ref.watch(downloadStorageProvider);
    final appSettings = appSettingsStore.settings;
    final themeMode = appSettings.themeMode == AppThemeMode.amoled
        ? AppThemeMode.dark
        : appSettings.themeMode;
    _cacheStatsFuture ??= downloadStorage.cardCacheStats();

    final personalizationTiles = <Widget>[
      _SettingsActionTile(
        iconAsset: AppIconAssets.systemTheme,
        title: strings.appearance,
        subtitle:
            '${_themeModeName(strings, themeMode)} · ${strings.textSizeLabel((appSettings.textScale * 100).round())}',
        onTap: () => _openAppearanceSheet(context, ref, appSettings),
      ),
      _SettingsActionTile(
        iconAsset: AppIconAssets.systemLanguage,
        title: strings.language,
        subtitle: _languageName(strings, appSettings.languageCode),
        onTap: () => _pickLanguage(context, ref, appSettings.languageCode),
      ),
    ];
    final contentTiles = <Widget>[
      _SettingsActionTile(
        iconAsset: AppIconAssets.bookSource,
        title: strings.sources,
        subtitle:
            '${_sourcesSubtitle(context, sourceSettings)} · ${strings.enabledInSearch}',
        onTap: () => _pickSources(context, ref, sourceSettings),
      ),
      _SettingsActionTile(
        iconAsset: AppIconAssets.systemCache,
        title: strings.cacheAndMetadata,
        subtitle: '',
        subtitleBuilder: (context) => FutureBuilder<CardCacheStats>(
          future: _cacheStatsFuture,
          builder: (context, snapshot) {
            final stats = snapshot.data;
            if (stats == null) {
              return Text(strings.calculatingTotalSize);
            }
            return Text(
              '${strings.cacheSize(_formatBytes(stats.bytes))} · ${strings.cacheBooks(stats.bookCount)}',
            );
          },
        ),
        onTap: () => _openCacheSheet(context, downloadStorage),
      ),
    ];
    final applicationTiles = <Widget>[
      _SettingsActionTile(
        iconAsset: AppIconAssets.systemRefresh,
        title: strings.appUpdates,
        subtitle: strings.appUpdatesHint,
        onTap: () => checkUpdatesManually(context, ref),
      ),
      _SettingsActionTile(
        iconAsset: AppIconAssets.systemInfo,
        title: strings.aboutApp,
        subtitle: strings.aboutAppHint,
        onTap: () => _openAboutSheet(context),
      ),
    ];

    return Scaffold(
      appBar: desktop
          ? null
          : AppBar(
              toolbarHeight: appBarToolbarHeight(context),
              title: preserveAppBarTextScale(context, Text(strings.settings)),
            ),
      body: desktop
          ? LayoutBuilder(
              builder: (context, constraints) {
                final factor = DesktopLayout.workspaceScaleFactor(context);
                final sideWidth = math.max(
                  360.0,
                  (constraints.maxWidth - 64 - 24) / 2 / factor,
                );
                return Column(
                  children: [
                    Padding(
                      padding: DesktopLayout.pagePadding(
                        context,
                      ).copyWith(bottom: 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DesktopPageHeader(title: strings.settings),
                          ),
                          MenuAnchor(
                            controller: _sectionMenuController,
                            builder: (context, controller, child) => IconButton(
                              key: const ValueKey('settings-section-menu'),
                              tooltip: strings.settingsSections,
                              icon: const AppIcon(AppIconAssets.playerChapters),
                              onPressed: () => controller.isOpen
                                  ? controller.close()
                                  : controller.open(),
                            ),
                            menuChildren: [
                              for (final entry in [
                                strings.appearance,
                                strings.cards,
                                strings.settingsPersonalization,
                                strings.settingsContent,
                                strings.settingsApplication,
                              ].indexed)
                                MenuItemButton(
                                  onPressed: () {
                                    _sectionMenuController.close();
                                    _jumpToSection(entry.$1);
                                  },
                                  child: Text(entry.$2),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: DesktopLayout.pagePadding(
                          context,
                        ).copyWith(top: 0),
                        children: [
                          Column(
                            key: const ValueKey('settings-desktop-content'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DesktopWorkspaceColumns(
                                key: const ValueKey(
                                  'settings-desktop-workspace',
                                ),
                                minimumPrimaryWidth: 420,
                                secondaryWidth: sideWidth,
                                primary: Column(
                                  key: const ValueKey(
                                    'settings-desktop-primary',
                                  ),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    KeyedSubtree(
                                      key: _sectionKeys[0],
                                      child: _DesktopSettingsGroup(
                                        key: const ValueKey(
                                          'settings-group-appearance',
                                        ),
                                        title: strings.appearance,
                                        children: [
                                          _DesktopAppearanceEditor(
                                            key: _inlineAppearanceKey,
                                            previewScale: _inlinePreviewScale,
                                            onScaleChanged: (value) =>
                                                setState(() {
                                                  _inlinePreviewRevision++;
                                                  _inlinePreviewScale = value;
                                                }),
                                            onScaleCommitted:
                                                _commitInlineScale,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                secondary: Column(
                                  key: const ValueKey(
                                    'settings-desktop-secondary',
                                  ),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    KeyedSubtree(
                                      key: _sectionKeys[1],
                                      child: _DesktopSettingsGroup(
                                        key: const ValueKey(
                                          'settings-group-cards',
                                        ),
                                        title: strings.cards,
                                        children: [
                                          SwitchListTile.adaptive(
                                            key: const ValueKey(
                                              'settings-compact-cards',
                                            ),
                                            title: Text(strings.compactCards),
                                            value: appSettings.compactCards,
                                            onChanged: appSettingsStore
                                                .setCompactCards,
                                          ),
                                          SwitchListTile.adaptive(
                                            key: const ValueKey(
                                              'settings-show-source',
                                            ),
                                            title: Text(
                                              strings.showSourceOnCards,
                                            ),
                                            value:
                                                appSettings.showSourceOnCards,
                                            onChanged: appSettingsStore
                                                .setShowSourceOnCards,
                                          ),
                                          SwitchListTile.adaptive(
                                            key: const ValueKey(
                                              'settings-show-percent',
                                            ),
                                            title: Text(
                                              strings.showPercentOnCovers,
                                            ),
                                            value:
                                                appSettings.showPercentOnCovers,
                                            onChanged: appSettingsStore
                                                .setShowPercentOnCovers,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    KeyedSubtree(
                                      key: _sectionKeys[2],
                                      child: _DesktopSettingsGroup(
                                        key: const ValueKey(
                                          'settings-group-personalization',
                                        ),
                                        title: strings.settingsPersonalization,
                                        children: [
                                          personalizationTiles.last,
                                          _SettingsActionTile(
                                            iconAsset:
                                                AppIconAssets.systemTheme,
                                            title: strings.animations,
                                            subtitle: _animationsModeName(
                                              strings,
                                              appSettings.animationsMode,
                                            ),
                                            onTap: () async {
                                              final next =
                                                  await _pickAnimationsMode(
                                                    context,
                                                    appSettings.animationsMode,
                                                  );
                                              if (next != null && mounted) {
                                                await appSettingsStore
                                                    .setAnimationsMode(next);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    KeyedSubtree(
                                      key: _sectionKeys[3],
                                      child: _DesktopSettingsGroup(
                                        key: const ValueKey(
                                          'settings-group-content',
                                        ),
                                        title: strings.settingsContent,
                                        children: contentTiles,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    KeyedSubtree(
                                      key: _sectionKeys[4],
                                      child: _DesktopSettingsGroup(
                                        key: const ValueKey(
                                          'settings-group-application',
                                        ),
                                        title: strings.settingsApplication,
                                        children: applicationTiles,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                ...personalizationTiles,
                ...contentTiles,
                ...applicationTiles,
              ],
            ),
    );
  }

  void _refreshCacheStats(FileDownloadStorage storage) {
    setState(() {
      _cacheStatsFuture = storage.cardCacheStats();
    });
  }

  String _sourcesSubtitle(BuildContext context, SourceSettingsStore store) {
    final enabled = store.enabledSearchSourceIds.length;
    if (enabled == store.settings.length) {
      return context.strings.allSources;
    }
    return context.strings.selectedSourcesCount(enabled);
  }

  Future<void> _openAppearanceSheet(
    BuildContext context,
    WidgetRef ref,
    AppSettings appSettings,
  ) async {
    var draft = appSettings;
    await showAdaptiveSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedTheme = draft.themeMode == AppThemeMode.amoled
                ? AppThemeMode.dark
                : draft.themeMode;

            Future<void> setAccent(String id) async {
              await ref.read(appSettingsStoreProvider).setAccentColor(id);
              if (!context.mounted) return;
              setModalState(() {
                draft = draft.copyWith(accentColor: id);
              });
            }

            return FilterPickerSheet(
              options: [
                _SectionHeader(title: context.strings.theme),
                for (final mode in const [
                  AppThemeMode.system,
                  AppThemeMode.light,
                  AppThemeMode.dark,
                ])
                  _ChoiceTile<AppThemeMode>(
                    value: mode,
                    selected: selectedTheme,
                    title: _themeModeName(context.strings, mode),
                    onSelected: (value) async {
                      await ref
                          .read(appSettingsStoreProvider)
                          .setThemeMode(value);
                      if (!context.mounted) return;
                      setModalState(() {
                        draft = draft.copyWith(themeMode: value);
                      });
                    },
                  ),
                _AccentColorPicker(
                  selectedId: draft.accentColor,
                  onChanged: (id) {
                    setModalState(() {
                      draft = draft.copyWith(accentColor: id);
                    });
                    ref.read(appSettingsStoreProvider).setAccentColor(id);
                  },
                  onCustom: () async {
                    final colorId = await _pickCustomAccentColor(
                      context,
                      _accentColorForId(draft.accentColor),
                    );
                    if (colorId != null) {
                      await setAccent(colorId);
                    }
                  },
                ),
                _TextScaleSlider(
                  value: draft.textScale,
                  onChanged: (value) {
                    setModalState(() {
                      draft = draft.copyWith(textScale: value);
                    });
                  },
                  onChangeEnd: (value) async {
                    final clamped = AppSettings.normalizeTextScale(value);
                    await ref
                        .read(appSettingsStoreProvider)
                        .setTextScale(clamped);
                    // onChanged already owns the preview. A delayed save must
                    // not replace the draft of a newer drag after it completes.
                  },
                ),
                _SettingsActionTile(
                  iconAsset: AppIconAssets.systemTheme,
                  title: context.strings.animations,
                  subtitle: _animationsModeName(
                    context.strings,
                    draft.animationsMode,
                  ),
                  onTap: () async {
                    final next = await _pickAnimationsMode(
                      context,
                      draft.animationsMode,
                    );
                    if (next != null) {
                      await ref
                          .read(appSettingsStoreProvider)
                          .setAnimationsMode(next);
                      if (!context.mounted) return;
                      setModalState(() {
                        draft = draft.copyWith(animationsMode: next);
                      });
                    }
                  },
                ),
              ],
              action: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.strings.apply),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    String selected,
  ) async {
    final strings = context.strings;
    final languages = ['system', 'ru', 'en', 'kk', 'be', 'uk'];
    final next = await showAdaptiveSheet<String>(
      context: context,
      title: strings.language,
      maxWidth: 440,
      showDragHandle: true,
      builder: (context) {
        return FilterPickerSheet(
          options: [
            for (final languageCode in languages)
              _ChoiceTile<String>(
                value: languageCode,
                selected: selected,
                title: _languageName(strings, languageCode),
                onSelected: (value) => Navigator.of(context).pop(value),
              ),
          ],
          action: DesktopLayout.isActive(context)
              ? null
              : FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: Text(strings.apply),
                ),
        );
      },
    );
    if (next != null) {
      await ref.read(appSettingsStoreProvider).setLanguageCode(next);
    }
  }

  Future<AppAnimationsMode?> _pickAnimationsMode(
    BuildContext context,
    AppAnimationsMode selected,
  ) async {
    final strings = context.strings;
    return showAdaptiveSheet<AppAnimationsMode>(
      context: context,
      title: strings.animations,
      maxWidth: 440,
      showDragHandle: true,
      builder: (context) {
        return FilterPickerSheet(
          options: [
            for (final mode in AppAnimationsMode.values)
              _ChoiceTile<AppAnimationsMode>(
                value: mode,
                selected: selected,
                title: _animationsModeName(strings, mode),
                onSelected: (value) => Navigator.of(context).pop(value),
              ),
          ],
          action: DesktopLayout.isActive(context)
              ? null
              : FilledButton(
                  onPressed: () => Navigator.of(context).pop(selected),
                  child: Text(strings.apply),
                ),
        );
      },
    );
  }

  Future<void> _pickSources(
    BuildContext context,
    WidgetRef ref,
    SourceSettingsStore store,
  ) async {
    final settings = store.settings;
    // A route builder may run again on resize; the user's draft belongs to the
    // whole dialog session, not to one invocation of that builder.
    var draft = {
      for (final setting in settings)
        if (setting.isEnabled) setting.sourceId,
    };
    final next = await showAdaptiveSheet<Set<String>>(
      context: context,
      title: context.strings.sources,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FilterPickerSheet(
              options: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    context.strings.selectAtLeastOneSource,
                    key: const ValueKey('sources-selection-hint'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                for (final setting in settings)
                  CheckboxListTile(
                    key: ValueKey('source-choice-${setting.sourceId}'),
                    value: draft.contains(setting.sourceId),
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      context.strings.sourceDisplayName(setting.sourceId),
                    ),
                    subtitle: Text(
                      draft.contains(setting.sourceId)
                          ? context.strings.sourceSearchEnabled
                          : context.strings.sourceSearchDisabled,
                    ),
                    onChanged:
                        draft.length == 1 && draft.contains(setting.sourceId)
                        ? null
                        : (value) {
                            setModalState(() {
                              final nextDraft = draft.toSet();
                              if (value == true) {
                                nextDraft.add(setting.sourceId);
                              } else if (nextDraft.length > 1) {
                                nextDraft.remove(setting.sourceId);
                              }
                              draft = nextDraft;
                            });
                          },
                  ),
              ],
              action: FilledButton(
                onPressed: () => Navigator.of(context).pop(draft),
                child: Text(context.strings.apply),
              ),
            );
          },
        );
      },
    );
    if (next != null) {
      await ref.read(sourceSettingsStoreProvider).setEnabledSources(next);
    }
  }

  Future<void> _openCacheSheet(
    BuildContext context,
    FileDownloadStorage storage,
  ) async {
    var statsFuture = storage.cardCacheStats();
    await showAdaptiveSheet<void>(
      context: context,
      title: context.strings.cacheAndMetadata,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => FutureBuilder<CardCacheStats>(
          future: statsFuture,
          builder: (context, snapshot) {
            final strings = context.strings;
            final stats = snapshot.data;
            final content = <Widget>[
              if (!DesktopLayout.isActive(context))
                Text(
                  strings.cacheAndMetadata,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              const SizedBox(height: 8),
              Text(
                strings.cacheAndMetadataHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    strings.cacheSize(
                      stats == null ? '...' : _formatBytes(stats.bytes),
                    ),
                  ),
                  Text(
                    stats == null
                        ? strings.calculatingTotalSize
                        : strings.cacheBooks(stats.bookCount),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                strings.downloadedBooksPreserved,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(strings.clearCacheSafetyHint),
            ];
            final action = FilledButton.icon(
              key: const ValueKey('cache-clear-action'),
              onPressed: stats == null || stats.bytes == 0
                  ? null
                  : () async {
                      final confirmed = await _confirmClearCache(context);
                      if (confirmed != true) return;
                      final cleared = await storage.clearCardCache();
                      if (!context.mounted) return;
                      setModalState(
                        () => statsFuture = storage.cardCacheStats(),
                      );
                      _refreshCacheStats(storage);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.strings.cacheCleared(
                              cleared.bookCount,
                              _formatBytes(cleared.bytes),
                            ),
                          ),
                        ),
                      );
                    },
              icon: const AppIcon(AppIconAssets.systemTrash),
              label: Text(strings.clearCardCache),
            );
            if (DesktopLayout.isActive(context)) {
              return FilterPickerSheet(options: content, action: action);
            }
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...content, const SizedBox(height: 16), action],
                ),
              ),
            );
          },
        ),
      ),
    );
    _refreshCacheStats(storage);
  }

  Future<bool?> _confirmClearCache(BuildContext context) {
    final strings = context.strings;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          constraints: DesktopLayout.isActive(context)
              ? const BoxConstraints(maxWidth: 560)
              : null,
          scrollable: DesktopLayout.isActive(context),
          title: Text(strings.clearCardCache),
          content: Text(strings.clearCardCacheConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.clearCardCache),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAboutSheet(BuildContext context) async {
    await showAdaptiveSheet<void>(
      context: context,
      title: context.strings.aboutApp,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final githubColor = colorScheme.brightness == Brightness.dark
            ? const Color(0xFFF0F6FC)
            : const Color(0xFF181717);

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!DesktopLayout.isActive(context))
                    Text(
                      context.strings.aboutApp,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    iconAsset: AppIconAssets.systemInfo,
                    title: context.strings.appVersion,
                    subtitle: AppVersion.version,
                  ),
                  _InfoRow(
                    iconAsset: AppIconAssets.systemNotification,
                    title: context.strings.buildNumber,
                    subtitle: AppVersion.buildNumber,
                  ),
                  const SizedBox(height: 8),
                  _LinkRow(
                    iconAsset: AppIconAssets.systemGithub,
                    iconColor: githubColor,
                    title: context.strings.githubRepository,
                    subtitle: ProjectLinks.githubRepository,
                    onTap: () =>
                        _openUrl(context, ProjectLinks.githubRepository),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUrl(BuildContext context, String value) async {
    final uri = Uri.parse(value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.sourcePageOpenError)),
      );
    }
  }
}

/// The desktop page edits appearance in place; the mobile sheet stays unchanged.
class _DesktopAppearanceEditor extends ConsumerWidget {
  const _DesktopAppearanceEditor({
    super.key,
    required this.previewScale,
    required this.onScaleChanged,
    required this.onScaleCommitted,
  });
  final double? previewScale;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<double> onScaleCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appSettingsStoreProvider);
    final settings = store.settings;
    return Padding(
      key: const ValueKey('settings-appearance-editor'),
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.strings.theme,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _DesktopThemeChoices(
                  selected: settings.themeMode,
                  accent: _accentColorForId(settings.accentColor),
                  onSelected: store.setThemeMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _AccentColorPicker(
            selectedId: settings.accentColor,
            onChanged: store.setAccentColor,
            onCustom: () async {
              final next = await _pickCustomAccentColor(
                context,
                _accentColorForId(settings.accentColor),
              );
              if (next != null && context.mounted) {
                await store.setAccentColor(next);
              }
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Divider(height: 1),
          ),
          _TextScaleSlider(
            value: previewScale ?? settings.textScale,
            onChanged: onScaleChanged,
            onChangeEnd: onScaleCommitted,
          ),
        ],
      ),
    );
  }
}

/// Actual theme palettes, not three identical navigation tiles. The thumbnail
/// is illustrative; its enclosing control is keyboard operable and labelled.
class _DesktopThemeChoices extends StatelessWidget {
  const _DesktopThemeChoices({
    required this.selected,
    required this.accent,
    required this.onSelected,
  });
  final AppThemeMode selected;
  final Color accent;
  final ValueChanged<AppThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final light = WindowsTheme.from(
      AppTheme.light(accent: accent, highContrast: highContrast),
    ).colorScheme;
    final dark = WindowsTheme.from(
      AppTheme.dark(accent: accent, highContrast: highContrast),
    ).colorScheme;
    final effective = selected == AppThemeMode.amoled
        ? AppThemeMode.dark
        : selected;
    const modes = [AppThemeMode.system, AppThemeMode.light, AppThemeMode.dark];
    if (MediaQuery.sizeOf(context).height < 800) {
      // On short windows the setting matters more than its illustrative preview.
      return Wrap(
        key: const ValueKey('settings-compact-theme-choices'),
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mode in modes)
            ChoiceChip(
              key: ValueKey('settings-theme-${mode.name}'),
              label: Text(_themeModeName(context.strings, mode)),
              selected: effective == mode,
              onSelected: (_) => onSelected(mode),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final minimum = 140 * DesktopLayout.workspaceScaleFactor(context);
        final columns = ((constraints.maxWidth + gap) / (minimum + gap))
            .floor()
            .clamp(1, 3);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final mode in modes)
              SizedBox(
                width: width,
                child: Semantics(
                  selected: effective == mode,
                  button: true,
                  child: Material(
                    color: effective == mode
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: effective == mode
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('settings-theme-${mode.name}'),
                      onTap: () => onSelected(mode),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ExcludeSemantics(
                            child: SizedBox(
                              height: 72,
                              child: mode == AppThemeMode.system
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: _ThemeThumbnail(scheme: light),
                                        ),
                                        Expanded(
                                          child: _ThemeThumbnail(scheme: dark),
                                        ),
                                      ],
                                    )
                                  : _ThemeThumbnail(
                                      scheme: mode == AppThemeMode.light
                                          ? light
                                          : dark,
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _themeModeName(context.strings, mode),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: effective == mode
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (effective == mode)
                                  AppIcon(
                                    AppIconAssets.systemCheck,
                                    size: 18,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  )
                                else
                                  const SizedBox.square(dimension: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeThumbnail extends StatelessWidget {
  const _ThemeThumbnail({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: scheme.surface,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: ColoredBox(
              color: scheme.surfaceContainerHigh,
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 4,
                  child: ColoredBox(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(height: 4, child: ColoredBox(color: scheme.primary)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DesktopSettingsGroup extends StatelessWidget {
  const _DesktopSettingsGroup({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Material(
          color: colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: ListTileTheme(
            data: ListTileTheme.of(context).copyWith(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              textColor: colorScheme.onSurface,
              iconColor: colorScheme.onSurfaceVariant,
            ),
            child: Column(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0)
                    Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: colorScheme.outlineVariant,
                    ),
                  children[index],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.value,
    required this.selected,
    required this.title,
    required this.onSelected,
  });

  final T value;
  final T selected;
  final String title;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = value == selected;

    return ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(title),
      trailing: isSelected
          ? AppIcon(AppIconAssets.systemCheck, color: colorScheme.primary)
          : null,
      selected: isSelected,
      onTap: () => onSelected(value),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    this.subtitleBuilder,
    this.onTap,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final WidgetBuilder? subtitleBuilder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: AppIcon(iconAsset, color: colorScheme.primary),
      title: Text(title),
      subtitle: subtitleBuilder?.call(context) ?? Text(subtitle),
      trailing: onTap == null
          ? null
          : const AppIcon(AppIconAssets.systemForward),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
  });

  final String iconAsset;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: AppIcon(iconAsset, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  final String iconAsset;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: AppIcon(iconAsset, color: iconColor ?? colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const AppIcon(AppIconAssets.systemForward),
      onTap: onTap,
    );
  }
}

class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker({
    required this.selectedId,
    required this.onChanged,
    required this.onCustom,
  });

  final String selectedId;
  final ValueChanged<String> onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorScheme = Theme.of(context).colorScheme;
    final customSelected = selectedId.startsWith('custom:#');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                AppIconAssets.systemAccentColor,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(strings.accentColor)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final swatch in _accentSwatches)
                Tooltip(
                  message: swatch.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onChanged(swatch.id),
                    child: SizedBox.square(
                      dimension: 40,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: swatch.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedId == swatch.id
                                ? colorScheme.onSurface
                                : colorScheme.outlineVariant,
                            width: selectedId == swatch.id ? 3 : 1,
                          ),
                        ),
                        child: selectedId == swatch.id
                            ? AppIcon(
                                AppIconAssets.systemCheck,
                                color: AppColorTokens.readableOn(swatch.color),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              Tooltip(
                message: strings.customColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onCustom,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: customSelected
                          ? _accentColorForId(selectedId)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: customSelected
                            ? colorScheme.onSurface
                            : colorScheme.outlineVariant,
                        width: customSelected ? 3 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          customSelected
                              ? AppIconAssets.systemCheck
                              : AppIconAssets.systemAccentColor,
                          size: 18,
                          color: customSelected
                              ? AppColorTokens.readableOn(
                                  _accentColorForId(selectedId),
                                )
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            strings.customColor,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: customSelected
                                      ? AppColorTokens.readableOn(
                                          _accentColorForId(selectedId),
                                        )
                                      : colorScheme.onSurface,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextScaleSlider extends StatelessWidget {
  const _TextScaleSlider({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final normalized = AppSettings.normalizeTextScale(value);
    final percent = (normalized * 100).round();
    final colors = Theme.of(context).colorScheme;
    final inheritedScaler = MediaQuery.textScalerOf(context);
    final systemScaler = inheritedScaler is AppTextScaler
        ? inheritedScaler.systemScaler
        : inheritedScaler;

    return ListTile(
      titleAlignment: DesktopLayout.isActive(context)
          ? ListTileTitleAlignment.top
          : null,
      leading: AppIcon(
        AppIconAssets.systemEdit,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(strings.textSizeLabel(percent)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Slider(
            key: const ValueKey('appearance-text-scale-slider'),
            value: normalized,
            min: AppSettings.minTextScale,
            max: AppSettings.maxTextScale,
            divisions:
                ((AppSettings.maxTextScale - AppSettings.minTextScale) /
                        AppSettings.textScaleStep)
                    .round(),
            label: '$percent%',
            semanticFormatterCallback: (value) => '${(value * 100).round()}%',
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(AppSettings.minTextScale * 100).round()}%'),
              Text('${(AppSettings.maxTextScale * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            // Preview while dragging without moving the slider under the
            // pointer or writing every intermediate value to the database.
            child: Text(
              strings.textSizePreview,
              key: const ValueKey('appearance-text-scale-preview'),
              textScaler: AppTextScaler(systemScaler, normalized),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurface),
            ),
          ),
          const SizedBox(height: 8),
          Text(strings.textSizeHint),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('appearance-text-scale-reset'),
              onPressed: () {
                onChanged(AppSettings.defaultTextScale);
                onChangeEnd(AppSettings.defaultTextScale);
              },
              child: Text(strings.textSizeReset),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentSwatch {
  const _AccentSwatch(this.id, this.color, this.label);

  final String id;
  final Color color;
  final String label;
}

const _accentSwatches = <_AccentSwatch>[
  _AccentSwatch('default', Color(0xFF516AA4), 'Default'),
  _AccentSwatch('green', Color(0xFF1F7A4D), 'Green'),
  _AccentSwatch('teal', Color(0xFF0F766E), 'Teal'),
  _AccentSwatch('red', Color(0xFFB42318), 'Red'),
  _AccentSwatch('gold', Color(0xFF8A5B00), 'Gold'),
];

const _customAccentPalette = <Color>[
  Color(0xFF2563EB),
  Color(0xFF0F766E),
  Color(0xFF15803D),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFFDC2626),
  Color(0xFFEA580C),
  Color(0xFFCA8A04),
  Color(0xFF475569),
  Color(0xFF111827),
];

Future<String?> _pickCustomAccentColor(
  BuildContext context,
  Color initialColor,
) {
  var draft = HSVColor.fromColor(initialColor);
  return showAdaptiveSheet<String>(
    context: context,
    title: context.strings.customColor,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final color = draft.toColor();
        final colors = Theme.of(context).colorScheme;
        final desktop = DesktopLayout.isActive(context);
        final preview = Row(
          key: const ValueKey('custom-accent-preview'),
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.strings.colorPreview)),
          ],
        );
        final controls = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            preview,
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _customAccentPalette)
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setModalState(() {
                      draft = HSVColor.fromColor(preset);
                    }),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: preset,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == preset
                              ? colors.onSurface
                              : colors.outlineVariant,
                          width: color == preset ? 2.5 : 1,
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 32,
                        child: color == preset
                            ? AppIcon(
                                AppIconAssets.systemCheck,
                                color: AppColorTokens.readableOn(preset),
                                size: 17,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _ColorSlider(
              label: context.strings.colorBrightness,
              value: draft.value,
              min: 0.35,
              max: 1,
              onChanged: (value) => setModalState(() {
                draft = draft.withValue(value);
              }),
            ),
          ],
        );
        final apply = FilledButton(
          key: const ValueKey('custom-accent-apply'),
          onPressed: () => Navigator.of(context).pop(_customAccentId(color)),
          child: Text(context.strings.apply),
        );
        Widget wheel(double size) => _ColorWheelPicker(
          hsv: draft,
          size: size,
          onChanged: (value) => setModalState(() => draft = value),
        );
        if (desktop) {
          return FilterPickerSheet(
            options: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // The graphic, unlike the text, may shrink to leave room for
                  // brightness and the pinned apply action in a short window.
                  if (constraints.maxWidth >= 520) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        wheel(200),
                        const SizedBox(width: 24),
                        Expanded(child: controls),
                      ],
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      wheel(160),
                      const SizedBox(height: 16),
                      controls,
                    ],
                  );
                },
              ),
            ],
            action: apply,
          );
        }
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .88,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.strings.customColor,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: wheel(
                      math.min(MediaQuery.sizeOf(context).width - 72, 292),
                    ),
                  ),
                  const SizedBox(height: 16),
                  controls,
                  const SizedBox(height: 8),
                  apply,
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ColorWheelPicker extends StatelessWidget {
  const _ColorWheelPicker({
    required this.hsv,
    required this.size,
    required this.onChanged,
  });

  final HSVColor hsv;
  final double size;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (details) => _select(details.localPosition),
      onPanUpdate: (details) => _select(details.localPosition),
      child: CustomPaint(
        size: Size.square(size),
        painter: _ColorWheelPainter(hsv: hsv),
      ),
    );
  }

  void _select(Offset position) {
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;
    final delta = position - center;
    final distance = delta.distance.clamp(0, radius).toDouble();
    final saturation = (distance / radius).clamp(0, 1).toDouble();
    final radians = math.atan2(-delta.dy, delta.dx);
    final hue = (radians * 180 / math.pi + 360) % 360;
    onChanged(hsv.withHue(hue).withSaturation(saturation));
  }
}

class _ColorWheelPainter extends CustomPainter {
  const _ColorWheelPainter({required this.hsv});

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.shortestSide / 2;

    final clip = Path()..addOval(rect);
    canvas.save();
    canvas.clipPath(clip);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          stops: [0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1],
          colors: [
            Color(0xFFE53935),
            Color(0xFFD81B60),
            Color(0xFF1E88E5),
            Color(0xFF00ACC1),
            Color(0xFF43A047),
            Color(0xFFFFEB3B),
            Color(0xFFE53935),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, Colors.white.withValues(alpha: 0)],
          stops: const [0, 1],
        ).createShader(rect),
    );
    if (hsv.value < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: 1 - hsv.value),
      );
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.10),
    );

    final angle = hsv.hue * math.pi / 180;
    final markerRadius = radius * hsv.saturation;
    final marker =
        center + Offset(math.cos(angle), -math.sin(angle)) * markerRadius;
    final color = hsv.toColor();
    canvas.drawCircle(
      marker,
      10,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
    canvas.drawCircle(
      marker,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColorTokens.readableOn(color),
    );
    canvas.drawCircle(
      marker,
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.hsv != hsv;
  }
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

Color _accentColorForId(String id) {
  if (id.startsWith('custom:#')) {
    final hex = id.substring('custom:#'.length);
    if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return Color(0xFF000000 | int.parse(hex, radix: 16));
    }
  }
  return _accentSwatches
      .firstWhere(
        (swatch) => swatch.id == id,
        orElse: () => _accentSwatches.first,
      )
      .color;
}

String _customAccentId(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return 'custom:#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

String _themeModeName(AppStrings strings, AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.system => strings.themeSystem,
    AppThemeMode.light => strings.themeLight,
    AppThemeMode.dark => strings.themeDark,
    AppThemeMode.amoled => strings.themeAmoled,
  };
}

String _animationsModeName(AppStrings strings, AppAnimationsMode mode) {
  return switch (mode) {
    AppAnimationsMode.full => strings.animationsFull,
    AppAnimationsMode.reduced => strings.animationsReduced,
    AppAnimationsMode.off => strings.animationsOff,
  };
}

String _languageName(AppStrings strings, String code) {
  return switch (code) {
    'system' => strings.systemLanguage,
    'ru' => strings.russianLanguage,
    'en' => strings.englishLanguage,
    'kk' => strings.kazakhLanguage,
    'be' => strings.belarusianLanguage,
    'uk' => strings.ukrainianLanguage,
    _ => code,
  };
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
}
