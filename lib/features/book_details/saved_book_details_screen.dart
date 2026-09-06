import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../domain/models/audio_book.dart';
import '../../services/audio/audio_state.dart';
import '../../services/audio/playback_controller_provider.dart';
import '../../services/downloads/download_manager_provider.dart';
import '../../services/library/library_metadata.dart';
import '../../services/library/library_store.dart';
import '../../sources/sources.dart';
import '../../ui/adaptive/desktop_book_details_layout.dart';
import '../../ui/adaptive/desktop_layout.dart';
import '../../ui/adaptive/slovofon_shell.dart';
import '../../ui/adaptive/television_layout.dart';
import '../../ui/adaptive/television_shell.dart';
import '../../ui/components/app_bar_text.dart';
import '../../ui/components/book_cover.dart';
import '../../ui/components/book_fragment_badge.dart';
import '../../ui/components/source_badge.dart';
import '../../ui/components/state_placeholder.dart';
import '../../ui/icons/app_icons.dart';
import '../shared/playback_resume.dart';
import '../source_books/source_book_details_screen.dart';

/// Resolves a saved identity, never a demonstration book or the first library item.
class SavedBookDetailsScreen extends ConsumerStatefulWidget {
  const SavedBookDetailsScreen({required this.bookId, super.key});

  final String bookId;

  @override
  ConsumerState<SavedBookDetailsScreen> createState() =>
      _SavedBookDetailsScreenState();
}

class _SavedBookDetailsScreenState
    extends ConsumerState<SavedBookDetailsScreen> {
  bool _busy = false;
  int _operation = 0;

  @override
  void didUpdateWidget(SavedBookDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookId != widget.bookId) {
      _operation++;
      _busy = false;
    }
  }

  void _retry() {
    ref.invalidate(libraryPlaybackBooksProvider);
    unawaited(ref.read(libraryStoreProvider).load());
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryStoreProvider);
    final metadata = ref.watch(libraryPlaybackBooksProvider);
    final controller = ref.watch(playbackControllerProvider);
    final downloads = ref.watch(downloadManagerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final playbackMatches = <String, AudioPlaybackBook>{};
        for (final book in [
          ...?metadata.asData?.value,
          for (final task in downloads.tasks)
            if (downloads.bookForTask(task.id) != null)
              downloads.bookForTask(task.id)!,
          if (controller.state.book != null) controller.state.book!,
        ]) {
          if (book.id == widget.bookId || book.versionId == widget.bookId) {
            playbackMatches[libraryPlaybackKey(book)] = book;
          }
        }
        final cards = <String, AudioBook>{};
        for (final entry in [...library.entries, ...library.later]) {
          if (entry.book.id == widget.bookId) {
            cards['${entry.book.sourceId}:${entry.book.id}'] = entry.book;
          }
        }
        for (final book in playbackMatches.values) {
          cards['${book.sourceId}:${book.id}'] = libraryCardBook(book);
        }
        // An old unqualified route cannot disambiguate duplicate IDs from two
        // sources/versions. Do not silently choose a different narrator/book.
        if (cards.length > 1 || playbackMatches.length > 1) {
          return _status(error: true);
        }
        if (cards.isEmpty) {
          if (metadata.hasError ||
              library.error != null ||
              library.laterError != null) {
            return _status(error: true);
          }
          if (metadata.isLoading || !library.isLoaded) {
            return _status(loading: true);
          }
          return _status();
        }
        final card = cards.values.single;
        final playback = playbackMatches.values.firstOrNull;
        if (playback == null && metadata.isLoading) {
          return _status(loading: true);
        }
        if (playback == null && metadata.hasError) {
          return _status(error: true);
        }
        final sourceBookId = card.sourceBookId;
        if ((playback == null || playback.chapters.isEmpty) &&
            sourceBookId != null &&
            sourceBookId.isNotEmpty) {
          return SourceBookDetailsScreen(
            key: ValueKey('saved-source-${card.sourceId}:$sourceBookId'),
            ref: SourceBookRef(
              sourceId: card.sourceId,
              sourceBookId: sourceBookId,
            ),
          );
        }
        return _details(card, playback);
      },
    );
  }

  Widget _frame(Widget body) {
    if (TelevisionLayout.isActive(context)) {
      return TelevisionStandaloneShell(
        key: const ValueKey('saved-book-details-screen'),
        title: context.strings.bookDetails,
        selectedIndex: 2,
        child: body,
      );
    }
    final screen = Scaffold(
      key: const ValueKey('saved-book-details-screen'),
      appBar: AppBar(
        toolbarHeight: appBarToolbarHeight(context),
        title: preserveAppBarTextScale(
          context,
          Text(context.strings.bookDetails),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
    return DesktopLayout.isActive(context)
        ? DesktopStandaloneShell(selectedIndex: 2, child: screen)
        : screen;
  }

  Widget _status({bool loading = false, bool error = false}) {
    final strings = context.strings;
    return _frame(
      ListView(
        key: ValueKey(
          loading
              ? 'saved-book-loading'
              : error
              ? 'saved-book-error'
              : 'saved-book-not-found',
        ),
        padding: const EdgeInsets.all(16),
        children: [
          if (loading)
            StatePlaceholder.loading(title: strings.bookDetails)
          else if (error)
            StatePlaceholder.error(title: strings.bookDetailsLoadFailedTitle)
          else
            StatePlaceholder.empty(title: strings.savedBookNotFound),
          if (!loading) ...[
            Center(
              child: TextButton(onPressed: _retry, child: Text(strings.retry)),
            ),
            Center(
              child: FilledButton(
                key: const ValueKey('saved-book-search'),
                onPressed: () => context.go('/search'),
                child: Text(strings.openSearch),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _details(AudioBook book, AudioPlaybackBook? playback) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final library = ref.watch(libraryStoreProvider);
    final chapters = playback?.chapters ?? const <AudioPlaybackChapter>[];
    final hasChapters = chapters.isNotEmpty;
    final genre = playback?.genre;
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          book.sourceName,
          style: theme.textTheme.labelLarge?.copyWith(
            color: sourceColorForId(book.sourceId, theme.colorScheme),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          book.title,
          key: const ValueKey('saved-book-title'),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        if (book.author.trim().isNotEmpty)
          Text(book.author, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text(
          book.narrator.trim().isEmpty
              ? strings.narratorUnknown
              : book.narrator,
          key: const ValueKey('saved-book-narrator'),
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
    final facts = Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        Text(
          strings.chaptersCount(playback?.chapters.length ?? book.chapterCount),
        ),
        if (book.durationLabel.isNotEmpty) Text(book.durationLabel),
        if (book.seriesTitle?.isNotEmpty == true)
          Text(
            '${book.seriesTitle}${book.seriesNumber == null ? '' : ' #${book.seriesNumber}'}',
          ),
        if (book.year != null) Text('${book.year}'),
        if (book.ratingValue != null) Text('${book.ratingValue} / 5'),
        if (genre != null && genre.isNotEmpty) Text(genre),
        if (book.isFragment) const BookFragmentBadge(),
      ],
    );
    final actions = Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (hasChapters)
          FilledButton.icon(
            key: const ValueKey('saved-book-play'),
            onPressed: _busy ? null : () => unawaited(_play(playback!)),
            icon: const AppIcon(AppIconAssets.playerPlay),
            label: Text(strings.play),
          ),
        OutlinedButton.icon(
          key: const ValueKey('saved-book-favorite'),
          onPressed: _busy ? null : () => unawaited(_favorite(book)),
          icon: AppIcon(
            library.isFavorite(book)
                ? AppIconAssets.bookFavoriteFilled
                : AppIconAssets.bookFavorite,
          ),
          label: Text(
            library.isFavorite(book)
                ? strings.removeFavorite
                : strings.addFavorite,
          ),
        ),
      ],
    );
    final content = <Widget>[
      if (!hasChapters) ...[
        Text(
          strings.savedBookMediaUnavailable,
          key: const ValueKey('saved-book-media-unavailable'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => context.go('/search'),
            child: Text(strings.openSearch),
          ),
        ),
      ],
      if (book.description?.trim().isNotEmpty == true) ...[
        Text(strings.description, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(book.description!, key: const ValueKey('saved-book-description')),
        const SizedBox(height: 24),
      ],
      if (hasChapters)
        Text(strings.chapters, style: theme.textTheme.titleLarge),
    ];
    Widget chapter(int index) {
      final saved = playback!;
      final item = saved.chapters[index];
      return Card(
        child: ListTile(
          key: ValueKey('saved-book-chapter-$index'),
          title: Text(item.title),
          subtitle: Text(_duration(item.duration)),
          leading: Text('${index + 1}'),
          onTap: _busy
              ? null
              : () => unawaited(_play(saved, chapterIndex: index)),
        ),
      );
    }

    if (DesktopLayout.isActive(context) || TelevisionLayout.isActive(context)) {
      return _frame(
        DesktopBookDetailsLayout(
          key: ValueKey('saved-book-layout-${book.sourceId}:${book.id}'),
          summary: DesktopBookSummary(
            coverBuilder: (width) => BookCover(
              title: book.title,
              imageUrl: book.coverUrl,
              width: width,
              height: width * 1.4,
              showProgressPercent: false,
            ),
            metadata: identity,
            details: facts,
            actions: actions,
          ),
          contentSlivers: [
            SliverList.list(children: content),
            if (hasChapters)
              SliverList.builder(
                itemCount: chapters.length,
                itemBuilder: (context, index) => chapter(index),
              ),
          ],
        ),
      );
    }
    return _frame(
      CustomScrollView(
        key: ValueKey('saved-book-layout-${book.sourceId}:${book.id}'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverList.list(
                  children: [
                    identity,
                    const SizedBox(height: 16),
                    actions,
                    const SizedBox(height: 16),
                    facts,
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BookCover(
                        title: book.title,
                        imageUrl: book.coverUrl,
                        width: 112,
                        height: 156,
                        showProgressPercent: false,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...content,
                  ],
                ),
                if (hasChapters)
                  SliverList.builder(
                    itemCount: chapters.length,
                    itemBuilder: (context, index) => chapter(index),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _favorite(AudioBook book) async {
    setState(() => _busy = true);
    final operation = ++_operation;
    try {
      await ref.read(libraryStoreProvider).toggleFavorite(book);
    } catch (_) {
      if (mounted && operation == _operation) {
        _error(context.strings.libraryActionError);
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  Future<void> _play(AudioPlaybackBook book, {int? chapterIndex}) async {
    setState(() => _busy = true);
    final operation = ++_operation;
    final controller = ref.read(playbackControllerProvider);
    final downloads = ref.read(downloadManagerProvider);
    final strings = context.strings;
    try {
      final current = controller.state.book;
      if (current?.sourceId == book.sourceId &&
          current?.versionId == book.versionId) {
        if (chapterIndex != null) {
          await controller.playChapterAt(chapterIndex);
        } else if (!controller.state.isPlaying) {
          await controller.play();
        }
      } else {
        final resolved = await downloads.offlinePlaybackBook(book);
        if (!mounted || operation != _operation) return;
        final snapshots = await ref.read(
          playbackProgressSnapshotsProvider.future,
        );
        if (!mounted || operation != _operation) return;
        final resume = playbackResumePointForBook(resolved, snapshots);
        final index = chapterIndex ?? resume.chapterIndex;
        if (resolved.chapters.isEmpty ||
            index >= resolved.chapters.length ||
            resolved.chapters[index].mediaSource == null) {
          _error(strings.savedBookMediaUnavailable);
          return;
        }
        await controller.loadBook(
          resolved,
          chapterIndex: index,
          position: chapterIndex == null ? resume.position : Duration.zero,
          autoPlay: true,
        );
      }
      if (!mounted || operation != _operation) return;
      if (controller.state.status == AudioPlaybackStatus.error ||
          controller.state.book?.sourceId != book.sourceId ||
          controller.state.book?.versionId != book.versionId) {
        _error(strings.savedBookPlaybackError);
        return;
      }
      unawaited(context.push('/player'));
    } catch (_) {
      if (mounted && operation == _operation) {
        _error(strings.savedBookPlaybackError);
      }
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  void _error(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _duration(Duration value) =>
    '${value.inMinutes}:${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';
