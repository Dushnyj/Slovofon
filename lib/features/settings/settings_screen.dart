import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_version.dart';
import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../../domain/models/app_settings.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/downloads/download_storage.dart';
import '../../services/settings/app_settings_store.dart';
import '../../services/sources/source_settings_store.dart';
import '../../ui/components/filter_picker_sheet.dart';
import '../../ui/icons/app_icons.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<CardCacheStats>? _cacheStatsFuture;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final appSettingsStore = ref.watch(appSettingsStoreProvider);
    final sourceSettings = ref.watch(sourceSettingsStoreProvider);
    final downloadStorage = ref.watch(downloadStorageProvider);
    final appSettings = appSettingsStore.settings;
    final themeMode = appSettings.themeMode == AppThemeMode.amoled
        ? AppThemeMode.dark
        : appSettings.themeMode;
    _cacheStatsFuture ??= downloadStorage.cardCacheStats();

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
        children: [
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
          _SettingsActionTile(
            iconAsset: AppIconAssets.systemInfo,
            title: strings.aboutApp,
            subtitle: strings.aboutAppHint,
            onTap: () => _openAboutSheet(context),
          ),
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
    await showModalBottomSheet<void>(
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
                    final clamped = value.clamp(0.9, 1.3).toDouble();
                    await ref
                        .read(appSettingsStoreProvider)
                        .setTextScale(clamped);
                    setModalState(() {
                      draft = draft.copyWith(textScale: clamped);
                    });
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
    final next = await showModalBottomSheet<String>(
      context: context,
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
          action: FilledButton(
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
    return showModalBottomSheet<AppAnimationsMode>(
      context: context,
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
          action: FilledButton(
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
    final next = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var draft = {
          for (final setting in settings)
            if (setting.isEnabled) setting.sourceId,
        };
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FilterPickerSheet(
              options: [
                for (final setting in settings)
                  CheckboxListTile(
                    value: draft.contains(setting.sourceId),
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      context.strings.sourceDisplayName(setting.sourceId),
                    ),
                    subtitle: Text(context.strings.enabledInSearch),
                    onChanged: (value) {
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FutureBuilder<CardCacheStats>(
                  future: statsFuture,
                  builder: (context, snapshot) {
                    final strings = context.strings;
                    final stats = snapshot.data;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.cacheAndMetadata,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.cacheAndMetadataHint,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 14),
                        _InfoRow(
                          iconAsset: AppIconAssets.systemCache,
                          title: strings.cacheSize(
                            stats == null ? '...' : _formatBytes(stats.bytes),
                          ),
                          subtitle: stats == null
                              ? strings.calculatingTotalSize
                              : strings.cacheBooks(stats.bookCount),
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          iconAsset: AppIconAssets.downloaded,
                          title: strings.downloadedBooksPreserved,
                          subtitle: strings.clearCacheSafetyHint,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: stats == null || stats.bytes == 0
                                ? null
                                : () async {
                                    final confirmed = await _confirmClearCache(
                                      context,
                                    );
                                    if (confirmed != true) {
                                      return;
                                    }
                                    final cleared = await storage
                                        .clearCardCache();
                                    if (!context.mounted) {
                                      return;
                                    }
                                    setModalState(() {
                                      statsFuture = storage.cardCacheStats();
                                    });
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
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
    _refreshCacheStats(storage);
  }

  Future<bool?> _confirmClearCache(BuildContext context) {
    final strings = context.strings;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
    const githubUrl = 'https://github.com/Dushnyj/Slovofon';
    const telegramUrl = 'https://t.me/+mAwEtHjpV6kwYTBi';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  title: 'GitHub',
                  subtitle: githubUrl,
                  onTap: () => _openUrl(context, githubUrl),
                ),
                _LinkRow(
                  iconAsset: AppIconAssets.systemTelegram,
                  title: 'Telegram',
                  subtitle: telegramUrl,
                  onTap: () => _openUrl(context, telegramUrl),
                ),
              ],
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
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: AppIcon(iconAsset, color: colorScheme.primary),
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
              Text(strings.accentColor),
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
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        Text(
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
    final percent = (value * 100).round();

    return ListTile(
      leading: AppIcon(
        AppIconAssets.systemEdit,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(strings.textSizeLabel(percent)),
      subtitle: Slider(
        value: value.clamp(0.9, 1.3),
        min: 0.9,
        max: 1.3,
        divisions: 8,
        label: '$percent%',
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
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
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final color = draft.toColor();
          final colorScheme = Theme.of(context).colorScheme;
          final size = MediaQuery.sizeOf(context);
          final maxHeight = size.height * 0.88;
          final wheelSize = math.min(size.width - 72, 292.0);
          final readableOnAccent = AppColorTokens.readableOn(color);

          return SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.strings.customColor,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: _ColorWheelPicker(
                          hsv: draft,
                          size: wheelSize,
                          onChanged: (value) {
                            setModalState(() => draft = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            context.strings.customColor,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: readableOnAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                                        ? colorScheme.onSurface
                                        : colorScheme.outlineVariant,
                                    width: color == preset ? 2.5 : 1,
                                  ),
                                ),
                                child: SizedBox.square(
                                  dimension: 32,
                                  child: color == preset
                                      ? AppIcon(
                                          AppIconAssets.systemCheck,
                                          color: AppColorTokens.readableOn(
                                            preset,
                                          ),
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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(context).pop(_customAccentId(color)),
                          child: Text(context.strings.apply),
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
    },
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
