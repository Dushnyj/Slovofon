import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';

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
            icon: Icons.palette_rounded,
            title: strings.appearance,
            subtitle: strings.openThemePreview,
            onTap: () => context.go('/theme-preview'),
          ),
          _SettingsTile(
            icon: Icons.source_rounded,
            title: strings.sources,
            subtitle: strings.mockDataNotice,
          ),
          _SettingsTile(
            icon: Icons.headphones_rounded,
            title: strings.player,
            subtitle: strings.mockDataNotice,
          ),
          _SettingsTile(
            icon: Icons.lan_rounded,
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
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
