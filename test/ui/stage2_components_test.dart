import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/components/app_buttons.dart';
import 'package:slovofon/ui/components/app_chips.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/chapter_tile.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';
import 'package:slovofon/ui/components/state_placeholder.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  testWidgets('common buttons and chips render labels and tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              AppPrimaryButton(
                iconAsset: AppIconAssets.playerPlay,
                label: 'Слушать',
                onPressed: () {},
              ),
              AppSecondaryButton(
                iconAsset: AppIconAssets.systemInfo,
                label: 'Подробнее',
                onPressed: () {},
              ),
              const SourceChip(label: 'Akniga', color: Color(0xFF2F6FED)),
              const AccessChip(
                label: 'Бесплатно',
                iconAsset: AppIconAssets.bookFree,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Слушать'), findsOneWidget);
    expect(find.text('Подробнее'), findsOneWidget);
    expect(find.text('Akniga'), findsOneWidget);
    expect(find.text('Бесплатно'), findsOneWidget);
  });

  testWidgets('chapter tile exposes title, duration, progress and semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ChapterTile(
            index: 1,
            title: 'Глава 1',
            durationLabel: '12 мин',
            progress: 0.5,
            isDownloaded: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Глава 1'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Delete downloaded'), findsOneWidget);
  });

  testWidgets('chapter tile shows circular cancel control while downloading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ChapterTile(
            index: 2,
            title: 'Глава 2',
            durationLabel: '10 мин',
            progress: 0,
            downloadState: BookCardDownloadState.downloading,
            downloadProgress: 0.4,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('download-action-progress')),
      findsOneWidget,
    );
    expect(find.byTooltip('Cancel download'), findsWidgets);
    expect(find.byTooltip('Delete downloaded'), findsNothing);
  });

  testWidgets('chapter tile keeps three digit numbers inside the circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ChapterTile(
            index: 128,
            title: 'Глава 128',
            durationLabel: '12 мин',
            progress: 0.25,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('128'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('book card prefers pause over loading once playback starts', (
    tester,
  ) async {
    const book = AudioBook(
      id: 'izib-book-1',
      sourceBookId: '1',
      title: 'Полураспад',
      author: 'Александр Зорич',
      narrator: 'Чайцын Александр',
      sourceId: 'izib',
      sourceName: 'Izib',
      durationLabel: '11 ч 49 мин',
      chapterCount: 64,
      progress: 0,
      access: BookAccess.free,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookCard(
            book: book,
            isCurrentBook: true,
            isPlaying: true,
            isPlaybackLoading: true,
            onPlay: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('book-card-play-loading')), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('book card shows dense metadata without pills progress or info', (
    tester,
  ) async {
    const book = AudioBook(
      id: 'akniga-book-1',
      sourceBookId: '1',
      title:
          'Очень длинное название аудиокниги, которое должно аккуратно обрезаться внутри карточки',
      author: 'Первый Автор, Второй Автор, Третий Автор',
      narrator: 'Первый Чтец, Второй Чтец, Третий Чтец',
      sourceId: 'akniga',
      sourceName: 'Akniga',
      durationLabel: '11 ч 49 мин',
      chapterCount: 64,
      progress: 0.42,
      access: BookAccess.free,
      seriesTitle: 'S.T.A.L.K.E.R.',
      ratingValue: 4.6,
      ratingCount: 81,
      year: 2019,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookCard(
            book: book,
            isFavorite: true,
            onTap: () {},
            onPlay: () {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(
      find.textContaining('Очень длинное название').first,
    );
    expect(title.maxLines, 2);
    expect(find.text('Первый Автор, Второй Автор et al.'), findsOneWidget);
    expect(find.text('Первый Чтец, Второй Чтец et al.'), findsOneWidget);
    expect(find.text('S.T.A.L.K.E.R.'), findsOneWidget);
    expect(find.text('4.6 out of 5'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
    expect(find.byTooltip('Details'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('book card switches to desktop tile layout on wide cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const book = AudioBook(
      id: 'akniga-book-1',
      sourceBookId: '1',
      title:
          'Очень длинное название аудиокниги, которое должно аккуратно обрезаться внутри карточки',
      author: 'Первый Автор, Второй Автор, Третий Автор',
      narrator: 'Первый Чтец, Второй Чтец, Третий Чтец',
      sourceId: 'akniga',
      sourceName: 'Akniga',
      durationLabel: '11 ч 49 мин',
      chapterCount: 64,
      progress: 0.42,
      access: BookAccess.free,
      seriesTitle: 'S.T.A.L.K.E.R.',
      ratingValue: 4.6,
      ratingCount: 81,
      year: 2019,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 960,
              child: BookCard(
                book: book,
                isFavorite: true,
                onTap: () {},
                onPlay: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('book-card-desktop-tile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('book-card-desktop-layout')),
      findsNothing,
    );
    expect(find.text('Первый Автор, Второй Автор et al.'), findsOneWidget);
    expect(find.text('Первый Чтец, Второй Чтец et al.'), findsOneWidget);
    expect(find.text('S.T.A.L.K.E.R.'), findsOneWidget);
    expect(find.text('11 h 49 min'), findsOneWidget);
    expect(find.text('2019'), findsOneWidget);
    expect(find.text('4.6 out of 5'), findsOneWidget);
  });

  testWidgets('book card pins colored source label under the cover', (
    tester,
  ) async {
    const book = AudioBook(
      id: 'izib-book-1',
      sourceBookId: '1',
      title: 'Полураспад',
      author: 'Александр Зорич',
      narrator: 'Чайцын Александр',
      sourceId: 'izib',
      sourceName: 'Izib',
      durationLabel: '11 ч 49 мин',
      chapterCount: 64,
      progress: 0.42,
      access: BookAccess.free,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookCard(book: book, onPlay: () {}),
        ),
      ),
    );

    final coverRect = tester.getRect(find.byType(BookCover));
    final sourceRect = tester.getRect(find.text('Izib'));
    expect(sourceRect.top, greaterThanOrEqualTo(coverRect.bottom + 3));
    expect(sourceRect.center.dx, closeTo(coverRect.center.dx, 8));
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('mini player is compact and shows source in metadata line', (
    tester,
  ) async {
    final controller = PlaybackController(engine: InMemoryAudioEngine());
    addTearDown(controller.dispose);
    await controller.loadBook(_miniPlayerBook, autoPlay: true);
    await controller.seek(const Duration(seconds: 65));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: Align(child: MiniPlayerBar())),
        ),
      ),
    );
    await tester.pump();

    final barRect = tester.getRect(find.byType(MiniPlayerBar));
    expect(barRect.height, lessThanOrEqualTo(50));
    expect(find.text('Izib'), findsOneWidget);
    expect(find.textContaining('01:05'), findsOneWidget);
    expect(find.textContaining('11%'), findsOneWidget);
  });

  testWidgets('mini player does not absorb bottom system safe area', (
    tester,
  ) async {
    final controller = PlaybackController(engine: InMemoryAudioEngine());
    addTearDown(controller.dispose);
    await controller.loadBook(_miniPlayerBook, autoPlay: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
            child: Align(child: MiniPlayerBar()),
          ),
        ),
      ),
    );
    await tester.pump();

    final barRect = tester.getRect(find.byType(MiniPlayerBar));
    expect(barRect.height, lessThanOrEqualTo(50));
  });

  testWidgets('state placeholders expose loading, empty and error variants', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              StatePlaceholder.loading(title: 'Загрузка'),
              StatePlaceholder.empty(title: 'Пусто', message: 'Нет данных'),
              StatePlaceholder.error(title: 'Ошибка', message: 'Повторите'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Загрузка'), findsOneWidget);
    expect(find.text('Пусто'), findsOneWidget);
    expect(find.text('Ошибка'), findsOneWidget);
  });
}

const _miniPlayerBook = AudioPlaybackBook(
  id: 'izib-book-1',
  versionId: 'izib-1',
  sourceId: 'izib',
  sourceBookId: '1',
  title: 'S.T.A.L.K.E.R. Полураспад',
  author: 'Александр Зорич',
  narrator: 'Чайцын Александр',
  sourceName: 'Izib',
  coverUrl: 'https://i.izib.uk/cover.jpg',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-1',
      index: 1,
      title: '000-01',
      duration: Duration(minutes: 10),
    ),
  ],
);
