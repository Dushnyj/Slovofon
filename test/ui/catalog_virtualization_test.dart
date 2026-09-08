import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/components/active_listenable_builder.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';
import 'package:slovofon/ui/components/responsive_tile_grid.dart';

void main() {
  for (final variant in ['phone', 'tv', 'windows']) {
    for (final count in [120, 500]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$variant $count books at $scale only mount visible rows', (
          tester,
        ) async {
          final model = ValueNotifier(0);
          addTearDown(model.dispose);
          var builds = 0;
          await _pump(
            tester,
            variant,
            scale,
            ActiveListenableBuilder(
              listenable: model,
              builder: (context, _) => SliverResponsiveTileGrid.builder(
                itemCount: count,
                itemKeyBuilder: (index) => ValueKey(index),
                maxColumns: variant == 'windows' ? 1 : 5,
                stretchDesktopColumns: variant == 'windows',
                itemBuilder: (context, index) {
                  builds++;
                  return _card(index);
                },
              ),
            ),
          );
          expect(
            find.byType(BookCard, skipOffstage: false).evaluate().length,
            inInclusiveRange(1, 24),
          );
          expect(
            find.byType(BookCover, skipOffstage: false).evaluate().length,
            inInclusiveRange(1, 24),
          );
          expect(builds, lessThan(25));
          final before = builds;
          model.value++;
          await tester.pumpAndSettle();
          expect(builds - before, lessThan(25));
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -1800),
          );
          await tester.pumpAndSettle();
          expect(
            find.byType(BookCard, skipOffstage: false).evaluate().length,
            inInclusiveRange(1, 24),
          );
          expect(find.byKey(const ValueKey('card-0')), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
    for (final scale in [1.0, 2.0]) {
      testWidgets('$variant $scale lazy rows preserve box grid geometry', (
        tester,
      ) async {
        List<Widget> tiles() => [
          for (var i = 0; i < 6; i++)
            SizedBox(key: ValueKey('geometry-$i'), height: 44.0 + i % 3 * 7),
        ];
        await _pump(
          tester,
          variant,
          scale,
          SliverToBoxAdapter(child: ResponsiveTileGrid(children: tiles())),
        );
        final expected = [
          for (var i = 0; i < 6; i++)
            tester.getRect(find.byKey(ValueKey('geometry-$i'))),
        ];
        await _pump(
          tester,
          variant,
          scale,
          SliverResponsiveTileGrid.builder(
            itemCount: 6,
            itemBuilder: (context, index) => tiles()[index],
          ),
        );
        for (var i = 0; i < 6; i++) {
          expect(
            tester.getRect(find.byKey(ValueKey('geometry-$i'))),
            expected[i],
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'TV D-pad traverses lazy cache edges without losing the selected card',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        'tv',
        1,
        SliverResponsiveTileGrid.builder(
          itemCount: 120,
          itemKeyBuilder: (index) => ValueKey(index),
          itemBuilder: (context, index) => _card(index),
        ),
        controller: controller,
      );
      final first = tester.widget<InkWell>(
        find
            .descendant(
              of: find.byKey(const ValueKey('card-0')),
              matching: find.byType(InkWell),
            )
            .first,
      );
      first.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      for (var step = 0; step < 25; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        final card = FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<BookCard>();
        expect(card, isNotNull);
        expect(card!.key, ValueKey('card-${(step + 1) * 2}'));
        expect(
          find.byType(BookCard, skipOffstage: false).evaluate().length,
          lessThan(25),
        );
      }
      expect(controller.offset, greaterThan(1000));
      for (var step = 0; step < 25; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
      }
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<BookCard>()
            ?.key,
        const ValueKey('card-0'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV focused identity survives result reorder and one-column resize',
    (tester) async {
      final ids = ValueNotifier(List.generate(120, (index) => index));
      addTearDown(ids.dispose);
      final sliver = ValueListenableBuilder<List<int>>(
        valueListenable: ids,
        builder: (context, values, _) => SliverResponsiveTileGrid.builder(
          itemCount: values.length,
          itemKeyBuilder: (index) => ValueKey(values[index]),
          itemBuilder: (context, index) => _card(values[index]),
        ),
      );
      await _pump(tester, 'tv', 1, sliver);
      final button = tester.widget<InkWell>(
        find
            .descendant(
              of: find.byKey(const ValueKey('card-2')),
              matching: find.byType(InkWell),
            )
            .first,
      );
      final node = button.focusNode!;
      node.requestFocus();
      await tester.pumpAndSettle();
      ids.value = [0, 2, 1, ...List.generate(117, (index) => index + 3)];
      await tester.pumpAndSettle();
      expect(node.hasPrimaryFocus, isTrue);
      await _pump(tester, 'tv', 1, sliver, viewport: const Size(600, 540));
      expect(node.hasPrimaryFocus, isTrue);
      expect(
        node.context?.findAncestorWidgetOfExactType<BookCard>()?.key,
        const ValueKey('card-2'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hidden retained catalog ignores ticks and reopens with latest state and scroll',
    (tester) async {
      final visible = ValueNotifier(true);
      final tick = ValueNotifier(0);
      final controller = ScrollController();
      addTearDown(visible.dispose);
      addTearDown(tick.dispose);
      addTearDown(controller.dispose);
      var builds = 0;
      final catalog = CustomScrollView(
        controller: controller,
        slivers: [
          ActiveListenableBuilder(
            listenable: tick,
            builder: (context, _) {
              builds++;
              return SliverResponsiveTileGrid.builder(
                singleColumn: true,
                itemCount: 500,
                itemBuilder: (context, index) =>
                    SizedBox(height: 120, child: Text('$index:${tick.value}')),
              );
            },
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              child: catalog,
              builder: (context, value, child) => TickerMode(
                enabled: value,
                child: Offstage(offstage: !value, child: child!),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(1200);
      await tester.pumpAndSettle();
      visible.value = false;
      await tester.pumpAndSettle();
      final before = builds;
      for (var i = 0; i < 50; i++) {
        tick.value++;
        await tester.pump();
      }
      expect(builds, before);
      visible.value = true;
      await tester.pumpAndSettle();
      expect(builds, before + 1);
      expect(controller.offset, 1200);
      expect(find.text('10:50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

BookCard _card(int index) => BookCard(
  key: ValueKey('card-$index'),
  book: AudioBook(
    id: '$index',
    title: 'Book $index',
    author: 'Author',
    narrator: 'Narrator',
    sourceId: 'izib',
    sourceName: 'Izib',
    durationLabel: '2 ч 7 мин',
    chapterCount: 50,
    progress: 0,
    access: BookAccess.free,
  ),
  desktopPresentation: DesktopBookPresentation.result,
  onTap: () {},
  onPlay: () {},
  onFavoritePressed: () {},
  onDownloadPressed: () {},
  onLaterPressed: () {},
);

Future<void> _pump(
  WidgetTester tester,
  String variant,
  double scale,
  Widget sliver, {
  ScrollController? controller,
  Size? viewport,
}) async {
  final size =
      viewport ??
      switch (variant) {
        'phone' => const Size(393, 852),
        'tv' => const Size(960, 540),
        _ => const Size(1280, 720),
      };
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final base = AppTheme.dark().copyWith(
    platform: variant == 'windows'
        ? TargetPlatform.windows
        : TargetPlatform.android,
  );
  Widget page = Scaffold(
    body: CustomScrollView(
      controller: controller,
      slivers: [
        SliverPadding(padding: const EdgeInsets.all(16), sliver: sliver),
      ],
    ),
  );
  if (variant == 'tv') page = TelevisionViewport(child: page);
  await tester.pumpWidget(
    MaterialApp(
      theme: variant == 'tv' ? TelevisionTheme.from(base) : base,
      home: TelevisionLayout(
        enabled: variant == 'tv',
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: page,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
