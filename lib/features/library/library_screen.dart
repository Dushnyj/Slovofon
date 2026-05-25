import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/section_header.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedShelf = 0;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final shelves = _localizedShelves(strings);
    final selected = shelves[_selectedShelf];

    return Scaffold(
      appBar: AppBar(title: Text(strings.library)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < shelves.length; index++)
                ChoiceChip(
                  selected: index == _selectedShelf,
                  label: Text(shelves[index].label),
                  onSelected: (_) => setState(() => _selectedShelf = index),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SectionHeader(
            title: selected.label,
            subtitle: '${selected.books.length} mock books',
          ),
          for (final book in selected.books)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BookCard(
                book: book.toAudioBook(),
                onTap: () => context.go('/book/${book.id}'),
              ),
            ),
        ],
      ),
    );
  }

  List<MockLibraryShelf> _localizedShelves(AppStrings strings) {
    final shelves = stage3LibraryShelves;
    final labels = [
      strings.all,
      strings.listening,
      strings.favorites,
      strings.later,
      strings.downloaded,
      strings.finished,
      strings.bookmarks,
      strings.history,
    ];

    return [
      for (var index = 0; index < shelves.length; index++)
        MockLibraryShelf(label: labels[index], books: shelves[index].books),
    ];
  }
}
