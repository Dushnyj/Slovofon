import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';

class BookCard extends StatelessWidget {
  const BookCard({required this.book, super.key});

  final AudioBook book;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = context.strings;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: colorScheme.onPrimaryContainer,
                    ),
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
                              icon: Icons.record_voice_over_rounded,
                              label: book.narrator,
                            ),
                            _InfoChip(
                              icon: Icons.schedule_rounded,
                              label: book.durationLabel,
                            ),
                            _InfoChip(
                              icon: Icons.source_rounded,
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
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(strings.play),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.info_outline_rounded),
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
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
      label: Text(label, overflow: TextOverflow.ellipsis),
      visualDensity: VisualDensity.compact,
    );
  }
}
