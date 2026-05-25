import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../ui/icons/app_icons.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsTile(
            iconAsset: AppIconAssets.systemTheme,
            title: strings.appearance,
            subtitle: strings.openThemePreview,
            onTap: () => context.go('/theme-preview'),
          ),
          _SettingsTile(
            iconAsset: AppIconAssets.bookSource,
            title: strings.sources,
            subtitle: strings.mockDataNotice,
          ),
          _SettingsTile(
            iconAsset: AppIconAssets.playerVolume,
            title: strings.player,
            subtitle: strings.mockDataNotice,
          ),
          _SettingsTile(
            iconAsset: AppIconAssets.systemProxy,
            title: strings.proxy,
            subtitle: strings.mockDataNotice,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: AppIcon(iconAsset, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap == null
          ? null
          : const AppIcon(AppIconAssets.systemForward),
      onTap: onTap,
    );
  }
}
