import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../../data/mock/mock_books.dart';
import '../../ui/components/app_buttons.dart';
import '../../ui/components/app_chips.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/chapter_tile.dart';
import '../../ui/components/state_placeholder.dart';
import '../../ui/icons/app_icons.dart';

class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;

    return Scaffold(
      appBar: AppBar(title: Text(strings.themePreview)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            strings.previewButtons,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {},
                icon: const AppIcon(AppIconAssets.playerPlay),
                label: Text(strings.play),
              ),
              AppPrimaryButton(
                iconAsset: AppIconAssets.playerBookmark,
                label: 'Primary',
                onPressed: () {},
              ),
              AppSecondaryButton(
                iconAsset: AppIconAssets.systemFilter,
                label: 'Secondary',
                onPressed: () {},
              ),
              AppQuietButton(
                iconAsset: AppIconAssets.systemMore,
                label: 'Quiet',
                onPressed: () {},
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const AppIcon(AppIconAssets.download),
                label: Text(strings.download),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const AppIcon(AppIconAssets.systemInfo),
                label: Text(strings.details),
              ),
              IconButton.filled(
                tooltip: strings.pause,
                onPressed: () {},
                icon: const AppIcon(AppIconAssets.playerPause),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            strings.previewChips,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const Chip(label: Text('Yakniga')),
              const Chip(label: Text('Izib')),
              const Chip(label: Text('Akniga')),
              const SourceChip(label: 'Akniga', color: Color(0xFF2F6FED)),
              const SourceChip(label: 'Yakniga', color: Color(0xFF1F7A4D)),
              const AccessChip(
                label: 'Subscription',
                iconAsset: AppIconAssets.bookSubscription,
              ),
              FilterChip(
                selected: true,
                label: Text(strings.free),
                onSelected: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            strings.previewCards,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          BookCard(book: mockBooks.first),
          const SizedBox(height: 12),
          ChapterTile(
            index: 1,
            title: 'Глава 1. Начало',
            durationLabel: '24 мин',
            progress: 0.42,
            isDownloaded: true,
            isCurrent: true,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          const StatePlaceholder.empty(
            title: 'Empty state',
            message: 'Secondary text stays readable.',
          ),
          const SizedBox(height: 12),
          const StatePlaceholder.error(
            title: 'Error state',
            message: 'Error text and actions use theme colors.',
          ),
          const SizedBox(height: 12),
          const StatePlaceholder.loading(title: 'Loading state'),
          const SizedBox(height: 24),
          Text(
            strings.previewInputs,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.all(14),
                child: AppIcon(AppIconAssets.navSearch, size: 22),
              ),
              hintText: strings.searchHint,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            strings.previewStates,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: 0.42,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StateBadge(
                label: strings.success,
                background: tokens.success,
                foreground: tokens.onSuccess,
              ),
              _StateBadge(
                label: strings.warning,
                background: tokens.warning,
                foreground: tokens.onWarning,
              ),
              _StateBadge(
                label: strings.info,
                background: tokens.info,
                foreground: tokens.onInfo,
              ),
              _StateBadge(
                label: 'Error',
                background: tokens.error,
                foreground: tokens.onError,
              ),
              _StateBadge(
                label: 'Focus',
                background: tokens.focus,
                foreground: AppColorTokens.readableOn(tokens.focus),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: strings.snackbarPreview,
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(strings.mockDataNotice)));
        },
        child: const AppIcon(AppIconAssets.systemNotification),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
