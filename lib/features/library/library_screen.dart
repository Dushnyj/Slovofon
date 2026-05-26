import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../data/mock/mock_audio_playback.dart';
import '../../data/mock/stage3_mock_data.dart';
import '../../services/downloads/download_manager.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../ui/components/book_card.dart';
import '../../ui/components/section_header.dart';
import '../shared/download_ui_state.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _selectedShelf = 0;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final downloadManager = ref.watch(downloadManagerProvider);
    final shelves = _localizedShelves(strings, downloadManager);
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
            subtitle: strings.booksCount(selected.books.length),
          ),
          for (final book in selected.books)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Builder(
                builder: (context) {
                  final playbackBook = mockAudioPlaybackBook(book);
                  return BookCard(
                    book: book.toAudioBook(),
                    yearLabel: '${book.year}',
                    isFavorite: book.isFavorite,
                    downloadState: downloadStateForBook(
                      downloadManager,
                      playbackBook,
                    ),
                    downloadProgress: downloadProgressForBook(
                      downloadManager,
                      playbackBook,
                    ),
                    onDownloadPressed: () =>
                        toggleBookDownload(downloadManager, playbackBook),
                    onPlay: () => context.go('/player'),
                    onTap: () => context.go('/book/${book.id}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<MockLibraryShelf> _localizedShelves(
    AppStrings strings,
    DownloadManager downloadManager,
  ) {
    final shelves = stage3LibraryShelves;
    final downloadedBooks = stage3MockBooks
        .where(
          (book) =>
              downloadStateForBook(
                downloadManager,
                mockAudioPlaybackBook(book),
              ) ==
              BookCardDownloadState.downloaded,
        )
        .toList();
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
        MockLibraryShelf(
          label: labels[index],
          books: index == 4 ? downloadedBooks : shelves[index].books,
        ),
    ];
  }
}
