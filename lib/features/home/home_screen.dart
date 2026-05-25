import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/mock_books.dart';
import '../../ui/components/book_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return CustomScrollView(
      slivers: [
        SliverAppBar(floating: true, title: Text(strings.appTitle)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.separated(
            itemCount: mockBooks.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _HomeHeader(
                  title: strings.continueListening,
                  subtitle: strings.mockDataNotice,
                );
              }

              return BookCard(book: mockBooks[index - 1]);
            },
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
