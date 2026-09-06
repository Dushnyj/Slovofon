import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/responsive_tile_grid.dart';
import 'package:slovofon/ui/components/television_book_card.dart';

const _book = AudioBook(
  id: 'classic',
  title: 'A classic with a longer but readable title',
  author: 'Author of this classic',
  narrator: 'Narrator of this recording',
  sourceId: 'izib',
  sourceName: 'Izib',
  durationLabel: '2 h 12 min',
  chapterCount: 11,
  progress: .25,
  access: BookAccess.free,
);

void main() {
  for (final ratio in [1.0, 2.0, 4.0]) {
    testWidgets('TV 850 logical dp keeps two columns at DPR $ratio', (
      tester,
    ) async {
      await _pump(tester, devicePixelRatio: ratio, child: _grid(4));
      final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
      final second = tester.getRect(find.byKey(const ValueKey('tile-1')));
      final third = tester.getRect(find.byKey(const ValueKey('tile-2')));
      expect(first.width, 419);
      expect(second.top, first.top);
      expect(second.left, first.right + 12);
      expect(third.top, first.bottom + 12);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV single book retains its shelf column width', (tester) async {
    await _pump(tester, child: _grid(1));
    expect(tester.getSize(find.byKey(const ValueKey('tile-0'))).width, 419);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TV wider logical viewport gains columns without physical hints',
    (tester) async {
      await _pump(
        tester,
        viewport: const Size(1920, 1080),
        contentWidth: 1700,
        child: _grid(5),
      );
      final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
      final fourth = tester.getRect(find.byKey(const ValueKey('tile-3')));
      final fifth = tester.getRect(find.byKey(const ValueKey('tile-4')));
      expect(first.width, 416);
      expect(fourth.top, first.top);
      expect(fifth.top, first.bottom + 12);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TV 200 percent text uses one column without reducing text', (
    tester,
  ) async {
    await _pump(tester, scale: 2, child: _grid(2));
    final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
    final second = tester.getRect(find.byKey(const ValueKey('tile-1')));
    expect(first.width, 850);
    expect(second.top, first.bottom + 12);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const ValueKey('tile-0'))),
      ).scale(14),
      28,
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('TV book cards remain compact and grow for text dark=$dark', (
      tester,
    ) async {
      Widget cards() => ResponsiveTileGrid(
        children: [
          for (var index = 0; index < 2; index++)
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
      final second = tester.getRect(find.byType(TelevisionBookCard).last);
      expect(first.width, 419);
      expect(first.height, lessThan(260));
      expect(second.top, first.top);
      final cover = tester.widget<BookCover>(find.byType(BookCover).first);
      expect(cover.width, 64);
      expect(cover.height, 96);
      expect(tester.takeException(), isNull);

      await _pump(tester, dark: dark, scale: 2, child: cards());
      final enlarged = tester.getRect(find.byType(TelevisionBookCard).first);
      final following = tester.getRect(find.byType(TelevisionBookCard).last);
      expect(enlarged.width, 850);
      expect(enlarged.height, greaterThan(first.height));
      expect(following.top, enlarged.bottom + 12);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV remote reaches all visible actions in a two-column shelf', (
    tester,
  ) async {
    final actions = <String>[];
    await _pump(
      tester,
      child: ResponsiveTileGrid(
        children: [
          BookCard(
            book: _book,
            onTap: () => actions.add('details'),
            onPlay: () => actions.add('play'),
            onFavoritePressed: () => actions.add('favorite'),
            onLaterPressed: () => actions.add('later'),
            onDownloadPressed: () => actions.add('download'),
          ),
          BookCard(
            book: _book.copyWith(id: 'second'),
            onTap: () {},
          ),
        ],
      ),
    );
    final firstCard = find.byType(TelevisionBookCard).first;
    final details = tester.widget<InkWell>(
      find.descendant(of: firstCard, matching: find.byType(InkWell)).first,
    );
    details.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(actions, ['details']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    for (final action in ['play', 'favorite', 'later', 'download']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(actions.last, action);
      if (action != 'download') {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(details.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Widget _grid(int count) => ResponsiveTileGrid(
  children: [
    for (var i = 0; i < count; i++)
      SizedBox(key: ValueKey('tile-$i'), height: 80),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  double contentWidth = 850,
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
