import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../../data/mock/mock_books.dart';
import '../../ui/components/book_card.dart';

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
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(strings.play),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download_rounded),
                label: Text(strings.download),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.info_outline_rounded),
                label: Text(strings.details),
              ),
              IconButton.filled(
                tooltip: strings.pause,
                onPressed: () {},
                icon: const Icon(Icons.pause_rounded),
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
          const SizedBox(height: 24),
          Text(
            strings.previewInputs,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
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
        child: const Icon(Icons.notifications_rounded),
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
