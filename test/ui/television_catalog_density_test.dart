import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/playback_source_label.dart';
import 'package:slovofon/ui/components/responsive_tile_grid.dart';
import 'package:slovofon/ui/components/television_book_card.dart';
import 'package:slovofon/ui/icons/app_icons.dart';
import 'package:slovofon/ui/motion/motion_tooltip.dart';

const _book = AudioBook(
  id: 'classic',
  title: 'White nights',
  author: 'Fyodor Dostoevsky',
  narrator: 'Alexander Petrov',
  sourceId: 'izib',
  sourceName: 'Izib',
  durationLabel: '2 h 12 min',
  chapterCount: 11,
  progress: .25,
  access: BookAccess.free,
  seriesTitle: 'Russian classics',
  seriesNumber: 2.5,
  year: 1881,
  ratingValue: 4.7,
);

void main() {
  // Real Full-HD route widths after safe insets, the rail and page padding:
  // Deliberately constrained grids also cover smaller embedded working areas;
  // fullscreen shell geometry is verified separately by foundation/UI tests.
  for (final width in [791.0, 799.0, 815.0]) {
    for (final ratio in [1.0, 2.0, 4.0]) {
      testWidgets(
        'TV $width logical dp keeps two audiobook cards at DPR $ratio',
        (tester) async {
          await _pump(
            tester,
            contentWidth: width,
            devicePixelRatio: ratio,
            child: _grid(3),
          );
          final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
          final second = tester.getRect(find.byKey(const ValueKey('tile-1')));
          final third = tester.getRect(find.byKey(const ValueKey('tile-2')));
          expect(first.width, closeTo((width - 12) / 2, .001));
          expect(second.top, first.top);
          expect(second.right, closeTo(width, .001));
          expect(third.top, first.bottom + 12);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('TV single book retains its card column width', (tester) async {
    await _pump(tester, child: _grid(1));
    expect(
      tester.getSize(find.byKey(const ValueKey('tile-0'))).width,
      closeTo((791 - 12) / 2, .001),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV wider logical viewport gains readable audiobook columns', (
    tester,
  ) async {
    await _pump(
      tester,
      viewport: const Size(1920, 1080),
      contentWidth: 1700,
      child: _grid(5),
    );
    final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
    final fourth = tester.getRect(find.byKey(const ValueKey('tile-3')));
    final nextRow = tester.getRect(find.byKey(const ValueKey('tile-4')));
    expect(first.width, closeTo((1700 - 3 * 12) / 4, .001));
    expect(fourth.top, first.top);
    expect(nextRow.top, first.bottom + 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV 200 percent text uses one column without reducing text', (
    tester,
  ) async {
    await _pump(tester, scale: 2, child: _grid(4));
    final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
    final second = tester.getRect(find.byKey(const ValueKey('tile-1')));
    expect(first.width, 791);
    expect(second.top, first.bottom + 12);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const ValueKey('tile-0'))),
      ).scale(14),
      28,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV rich tiles keep their explicit minimum and scale naturally', (
    tester,
  ) async {
    Widget richGrid() => ResponsiveTileGrid(
      televisionMinTileWidth: 360,
      children: [
        for (var i = 0; i < 3; i++)
          SizedBox(key: ValueKey('rich-$i'), height: 80),
      ],
    );
    await _pump(tester, child: richGrid());
    final first = tester.getRect(find.byKey(const ValueKey('rich-0')));
    final second = tester.getRect(find.byKey(const ValueKey('rich-1')));
    expect(first.width, 389.5);
    expect(second.top, first.top);
    await _pump(tester, scale: 2, child: richGrid());
    final enlarged = tester.getRect(find.byKey(const ValueKey('rich-0')));
    final following = tester.getRect(find.byKey(const ValueKey('rich-1')));
    expect(enlarged.width, 791);
    expect(following.top, enlarged.bottom + 12);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'TV audiobook cards retain readable metadata and grow for text dark=$dark',
      (tester) async {
        Widget cards() => ResponsiveTileGrid(
          children: [
            for (var index = 0; index < 4; index++)
              BookCard(
                book: _book.copyWith(id: 'book-$index'),
                onTap: () {},
                onPlay: () {},
                onFavoritePressed: () {},
                onLaterPressed: () {},
                onDownloadPressed: () {},
              ),
          ],
        );
        await _pump(tester, dark: dark, child: cards());
        final first = tester.getRect(find.byType(TelevisionBookCard).first);
        expect(first.width, closeTo((791 - 12) / 2, .001));
        expect(first.height, lessThan(160));
        expect(first.height, greaterThanOrEqualTo(100));
        final cover = tester.widget<BookCover>(find.byType(BookCover).first);
        expect(cover.width, 48);
        expect(cover.height, 72);
        final source = tester.widget<PlaybackSourceLabel>(
          find.byType(PlaybackSourceLabel).first,
        );
        expect(source.maxLines, isNull);
        expect(source.textStyle!.fontSize, 12);
        expect(find.text('25%'), findsNWidgets(4));
        expect(find.byType(IconButton), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(tester.takeException(), isNull);

        await _pump(tester, dark: dark, scale: 2, child: cards());
        final enlarged = tester.getRect(find.byType(TelevisionBookCard).first);
        final following = tester.getRect(find.byType(TelevisionBookCard).at(1));
        expect(enlarged.width, 791);
        expect(enlarged.height, greaterThan(first.height));
        expect(following.top, closeTo(enlarged.bottom + 12, .001));
        expect(
          tester.widget<BookCover>(find.byType(BookCover).first).width,
          48,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'TV audiobook cards show every available field with its role icon',
    (tester) async {
      await _pump(
        tester,
        child: ResponsiveTileGrid(
          children: [BookCard(book: _book, onTap: () {})],
        ),
      );
      for (final value in [
        _book.title,
        _book.author,
        _book.narrator,
        'Russian classics #2.5',
        _book.durationLabel,
        '1881',
        '4.7 / 5',
      ]) {
        final text = tester.widget<Text>(find.text(value));
        expect(text.maxLines, isNull, reason: value);
        expect(text.overflow, isNot(TextOverflow.ellipsis), reason: value);
      }
      final assets = tester
          .widgetList<AppIcon>(find.byType(AppIcon))
          .map((icon) => icon.asset);
      expect(
        assets,
        containsAll([
          AppIconAssets.bookAuthor,
          AppIconAssets.bookNarrator,
          AppIconAssets.bookSeries,
          AppIconAssets.bookDuration,
          AppIconAssets.playerChapters,
          AppIconAssets.bookYear,
          AppIconAssets.bookRating,
        ]),
      );
      expect(find.byType(PlaybackSourceLabel), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, .25);
      expect(bar.minHeight, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV audiobook card respects year override and hides only absent fields',
    (tester) async {
      await _pump(
        tester,
        child: ResponsiveTileGrid(
          children: [
            BookCard(
              book: _book.copyWith(
                author: '',
                narrator: '',
                seriesTitle: '',
                durationLabel: '',
                chapterCount: 0,
                ratingValue: 0,
              ),
              yearLabel: '2020',
              onTap: () {},
            ),
          ],
        ),
      );
      expect(find.text('2020'), findsOneWidget);
      expect(find.text('1881'), findsNothing);
      final assets = tester
          .widgetList<AppIcon>(find.byType(AppIcon))
          .map((icon) => icon.asset)
          .toList();
      expect(assets, contains(AppIconAssets.bookYear));
      for (final absent in [
        AppIconAssets.bookAuthor,
        AppIconAssets.bookNarrator,
        AppIconAssets.bookSeries,
        AppIconAssets.bookDuration,
        AppIconAssets.playerChapters,
        AppIconAssets.bookRating,
      ]) {
        expect(assets, isNot(contains(absent)));
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 791.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('TV complete metadata reflows at width $width scale $scale', (
        tester,
      ) async {
        final longBook = _book.copyWith(
          title: 'An unabridged audiobook with a complete and very long title',
          author: 'First author, Second author, Third author, Fourth author',
          narrator:
              'The full narrator name and the name of the recording studio',
          seriesTitle:
              'A complete and very long cycle title that must not disappear',
        );
        await _pump(
          tester,
          contentWidth: width,
          scale: scale,
          child: ResponsiveTileGrid(
            children: [BookCard(book: longBook, onTap: () {})],
          ),
        );
        for (final value in [
          longBook.author,
          longBook.narrator,
          '${longBook.seriesTitle} #2.5',
        ]) {
          final field = tester.widget<Text>(find.text(value));
          expect(field.maxLines, isNull);
          expect(field.style!.fontSize, 12);
          expect(
            MediaQuery.textScalerOf(tester.element(find.text(value))).scale(12),
            12 * scale,
          );
        }
        final cover = tester.widget<BookCover>(find.byType(BookCover));
        expect(cover.width, 48);
        expect(cover.height, 72);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('TV D-pad has one stop per card and moves between rows', (
    tester,
  ) async {
    final actions = <String>[];
    await _pump(
      tester,
      child: ResponsiveTileGrid(
        children: [
          for (var index = 0; index < 6; index++)
            BookCard(
              book: _book.copyWith(id: 'book-$index'),
              onTap: () => actions.add('details-$index'),
              onPlay: () => actions.add('play-$index'),
              onFavoritePressed: () => actions.add('favorite-$index'),
              onLaterPressed: () => actions.add('later-$index'),
              onDownloadPressed: () => actions.add('download-$index'),
            ),
        ],
      ),
    );
    _cardFocus(tester, 0).requestFocus();
    await tester.pumpAndSettle();
    for (var index = 0; index < 2; index++) {
      expect(_cardFocus(tester, index).hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(actions.last, 'details-$index');
      if (index < 1) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_cardFocus(tester, 3).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(_cardFocus(tester, 2).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_cardFocus(tester, 0).hasFocus, isTrue);
    expect(actions, ['details-0', 'details-1']);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'TV audiobook cards distinguish narrations and focus without changing source fill dark=$dark',
      (tester) async {
        await _pump(
          tester,
          dark: dark,
          child: ResponsiveTileGrid(
            children: [
              BookCard(
                book: _book.copyWith(narrator: 'First narrator'),
                onTap: () {},
              ),
              BookCard(
                book: _book.copyWith(
                  id: 'other-recording',
                  sourceId: 'akniga',
                  narrator: 'Second narrator with a longer name',
                ),
                onTap: () {},
              ),
            ],
          ),
        );
        for (final narrator in [
          'First narrator',
          'Second narrator with a longer name',
        ]) {
          final text = tester.widget<Text>(find.text(narrator));
          expect(text.maxLines, isNull);
          expect(text.style!.fontSize, 12);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is AppTooltip && widget.message == narrator,
            ),
            findsOneWidget,
          );
        }
        expect(find.text(_book.author), findsNWidgets(2));
        expect(
          tester
              .widgetList<PlaybackSourceLabel>(find.byType(PlaybackSourceLabel))
              .map((label) => label.sourceId),
          ['izib', 'akniga'],
        );
        final first = find.byType(TelevisionBookCard).first;
        final frame = find.descendant(
          of: first,
          matching: find.byType(TelevisionFocusFrame),
        );
        expect(frame, findsOneWidget);
        Material cardSurface() =>
            tester.widget<TelevisionFocusFrame>(frame).child as Material;
        Color background() => cardSurface().color!;
        BorderSide outline() {
          // Focus ink and its rounded outline now share a Material surface.
          // Select that surface explicitly, not a cover's DecoratedBox or the
          // transparent focus layer when checking the book's background fill.
          final card = cardSurface();
          final surface = find.descendant(
            of: frame,
            matching: find.byWidgetPredicate(
              (widget) => widget is Material && identical(widget.child, card),
            ),
          );
          expect(surface, findsOneWidget);
          return (tester.widget<Material>(surface).shape!
                  as RoundedRectangleBorder)
              .side;
        }

        final restingBackground = background();
        expect(
          restingBackground,
          Theme.of(tester.element(first)).colorScheme.surfaceContainerLow,
        );
        expect(outline().width, 1);
        final bounds = tester.getRect(first);
        _cardFocus(tester, 0).requestFocus();
        await tester.pumpAndSettle();
        expect(outline().width, 2);
        expect(
          outline().color,
          Theme.of(tester.element(first)).colorScheme.primary,
        );
        expect(background(), restingBackground);
        expect(tester.getRect(first), bounds);
        final ink = tester.widget<InkWell>(
          find.descendant(of: first, matching: find.byType(InkWell)),
        );
        expect(
          ink.overlayColor!.resolve({WidgetState.focused}),
          Colors.transparent,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'TV Select opens details and system Back restores its card focus',
    (tester) async {
      await _pump(
        tester,
        child: Builder(
          builder: (context) => ResponsiveTileGrid(
            children: [
              for (var index = 0; index < 3; index++)
                BookCard(
                  book: _book.copyWith(id: 'book-$index'),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: TextButton(
                          autofocus: true,
                          onPressed: () {},
                          child: Text('Details $index'),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      _cardFocus(tester, 1).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('Details 1'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Details 1'), findsNothing);
      expect(_cardFocus(tester, 1).hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TV play-only cards retain activation but not while loading', (
    tester,
  ) async {
    var played = 0;
    Widget card({bool loading = false}) => ResponsiveTileGrid(
      children: [
        BookCard(book: _book, onPlay: () => played++, isPlayLoading: loading),
      ],
    );
    await _pump(tester, child: card());
    _cardFocus(tester, 0).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(played, 1);
    await _pump(tester, child: card(loading: true));
    final ink = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(TelevisionBookCard),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.onTap, isNull);
    expect(tester.takeException(), isNull);
  });
}

FocusNode _cardFocus(WidgetTester tester, int index) => tester
    .widget<InkWell>(
      find.descendant(
        of: find.byType(TelevisionBookCard).at(index),
        matching: find.byType(InkWell),
      ),
    )
    .focusNode!;

Widget _grid(int count) => ResponsiveTileGrid(
  children: [
    for (var i = 0; i < count; i++)
      SizedBox(key: ValueKey('tile-$i'), height: 80),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  double contentWidth = 791,
  Size viewport = const Size(960, 540),
  double devicePixelRatio = 1,
  double scale = 1,
  bool dark = true,
}) async {
  tester.view.devicePixelRatio = devicePixelRatio;
  tester.view.physicalSize = viewport * devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: TelevisionTheme.from(dark ? AppTheme.dark() : AppTheme.light()),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          navigationMode: NavigationMode.directional,
        ),
        child: TelevisionLayout(
          enabled: true,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
            },
            child: child!,
          ),
        ),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            child: SizedBox(width: contentWidth, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
