import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/mock_books.dart';
import '../../ui/components/book_card.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(strings.search),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.separated(
            itemCount: mockBooks.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: strings.searchHint,
                  ),
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

