import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/responsive_tile_grid.dart';

void main() {
  for (final scale in [1.0, 2.0, 3.0]) {
    for (final ratio in [1.0, 2.0, 3.0]) {
      testWidgets('tablet 1280 dp scale=$scale DPR=$ratio adapts columns', (
        tester,
      ) async {
        await _pump(tester, scale: scale, ratio: ratio);
        final columns = switch (scale) {
          1.0 => 4,
          2.0 => 2,
          _ => 1,
        };
        final expectedWidth = (1280 - 12 * (columns - 1)) / columns;
        final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
        expect(first.width, expectedWidth);
        for (var index = 1; index < columns; index++) {
          final next = tester.getRect(find.byKey(ValueKey('tile-$index')));
          expect(next.top, first.top);
          expect(next.width, expectedWidth);
        }
        final nextRow = tester.getRect(find.byKey(ValueKey('tile-$columns')));
        expect(nextRow.top, first.bottom + 12);
        expect(
          MediaQuery.textScalerOf(
            tester.element(find.byKey(const ValueKey('tile-0'))),
          ).scale(14),
          14 * scale,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('narrow phone stays one full-width column at scale=$scale', (
      tester,
    ) async {
      await _pump(tester, width: 390, scale: scale);
      final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
      final second = tester.getRect(find.byKey(const ValueKey('tile-1')));
      expect(first.width, 390);
      expect(second.left, first.left);
      expect(second.top, first.bottom + 12);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tablet respects caller minimum tile width at enlarged text', (
    tester,
  ) async {
    await _pump(tester, scale: 2, minimum: 360);
    final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
    final second = tester.getRect(find.byKey(const ValueKey('tile-1')));
    expect(first.width, 1280);
    expect(second.top, first.bottom + 12);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('real tablet BookCard uses font-aware cell at scale=$scale', (
      tester,
    ) async {
      await _pump(
        tester,
        scale: scale,
        children: [
          BookCard(
            book: _book,
            onTap: () {},
            onPlay: () {},
            onFavoritePressed: () {},
            onDownloadPressed: () {},
          ),
        ],
      );
      final columns = scale == 1 ? 4 : (scale == 2 ? 2 : 1);
      final cellWidth = (1280 - 12 * (columns - 1)) / columns;
      final card = tester.getRect(find.byType(Card));
      final content = tester.getRect(
        find.byKey(const ValueKey('book-card-desktop-tile')),
      );
      final cover = tester.getRect(find.byType(BookCover));
      final title = tester.getRect(find.text(_book.title));
      final author = tester.getRect(find.text(_book.author));
      expect(card.width, cellWidth);
      if (scale > 1) expect(content.width, greaterThan(420));
      expect(title.left, greaterThan(cover.right));
      expect(title.right, lessThanOrEqualTo(content.right));
      expect(author.left, greaterThan(cover.right));
      expect(author.right, lessThanOrEqualTo(content.right));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(_book.author),
      );
      expect(paragraph.textScaler.scale(14), 14 * scale);
      expect(tester.takeException(), isNull);
    });
  }
}

const _book = AudioBook(
  id: 'classic',
  title: 'White nights, a classic story with a deliberately longer title',
  author: 'Fyodor Mikhailovich Dostoevsky',
  narrator: 'Reader of the classic recording',
  sourceId: 'izib',
  sourceName: 'Izib',
  durationLabel: '2 h 12 min',
  chapterCount: 11,
  progress: .25,
  access: BookAccess.free,
);

Future<void> _pump(
  WidgetTester tester, {
  double width = 1280,
  double scale = 1,
  double ratio = 1,
  double minimum = 300,
  List<Widget>? children,
}) async {
  tester.view.devicePixelRatio = ratio;
  tester.view.physicalSize = Size(width, 800) * ratio;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark().copyWith(platform: TargetPlatform.android),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ResponsiveTileGrid(
            minTileWidth: minimum,
            children:
                children ??
                [
                  for (var index = 0; index < 5; index++)
                    SizedBox(key: ValueKey('tile-$index'), height: 60),
                ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
