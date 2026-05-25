import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';
import 'book_cover.dart';
import '../icons/app_icons.dart';

class BookCard extends StatelessWidget {
  const BookCard({required this.book, this.onTap, super.key});

  final AudioBook book;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = context.strings;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                    title: book.title,
                    progress: book.progress,
                    width: 56,
                    height: 72,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _InfoChip(
                              iconAsset: AppIconAssets.bookNarrator,
                              label: book.narrator,
                            ),
                            _InfoChip(
                              iconAsset: AppIconAssets.bookDuration,
                              label: book.durationLabel,
                            ),
                            _InfoChip(
                              iconAsset: AppIconAssets.bookSource,
                              label: book.sourceName,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (book.progress > 0) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: book.progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(99),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const AppIcon(AppIconAssets.playerPlay),
                    label: Text(strings.play),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const AppIcon(AppIconAssets.systemInfo),
                    label: Text(strings.details),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.iconAsset, required this.label});

  final String iconAsset;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: AppIcon(iconAsset, size: 16, color: colorScheme.onSurfaceVariant),
      label: Text(label, overflow: TextOverflow.ellipsis),
      visualDensity: VisualDensity.compact,
    );
  }
}
