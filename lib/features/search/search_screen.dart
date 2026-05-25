import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/section_header.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/mock_book_card_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final normalizedQuery = _query.trim().toLowerCase();
    final results = normalizedQuery.isEmpty
        ? stage3MockBooks
        : stage3MockBooks.where((book) {
            return book.title.toLowerCase().contains(normalizedQuery) ||
                book.author.toLowerCase().contains(normalizedQuery) ||
                book.narrator.toLowerCase().contains(normalizedQuery) ||
                book.sourceName.toLowerCase().contains(normalizedQuery);
          }).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(floating: true, title: Text(strings.search)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(14),
                    child: AppIcon(AppIconAssets.navSearch, size: 22),
                  ),
                  hintText: strings.searchHint,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    selected: true,
                    label: Text(strings.groupedDuplicates),
                    onSelected: (_) {},
                  ),
                  FilterChip(
                    selected: true,
                    label: const Text('All sources'),
                    onSelected: (_) {},
                  ),
                  FilterChip(
                    selected: true,
                    label: Text(strings.free),
                    onSelected: (_) {},
                  ),
                  InputChip(
                    avatar: const AppIcon(AppIconAssets.systemSort, size: 16),
                    label: Text(strings.sortRelevance),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SectionHeader(
                title: '${results.length} mock results',
                subtitle: 'Grouped by title, narrator, source and duration.',
              ),
              for (final book in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BookCard(
                    book: book.toAudioBook(),
                    yearLabel: '${book.year}',
                    isFavorite: book.isFavorite,
                    downloadState: mockDownloadStateFor(book.downloadStatus),
                    downloadProgress: book.progress,
                    onPlay: () => context.go('/player'),
                    onTap: () => context.go('/book/${book.id}'),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}
