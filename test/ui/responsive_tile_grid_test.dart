import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/ui/components/responsive_tile_grid.dart';

void main() {
  for (final scale in [.75, 1.0, 2.0, 3.0]) {
    testWidgets('opt-in Windows rows fill available width at scale $scale', (
      tester,
    ) async {
      _configureView(tester);
      for (final width in [420.0, 939.0, 940.0, 959.0, 1248.0, 2600.0]) {
        await _pumpGrid(
          tester,
          width: width,
          count: 15,
          scale: scale,
          stretchDesktopColumns: true,
        );
        final minimum = 464 * scale.clamp(1.0, 1.5);
        final columns = ((width + 12) / (minimum + 12)).floor().clamp(1, 5);
        final expectedWidth = (width - 12 * (columns - 1)) / columns;
        expect(_tileRect(tester, columns - 1).right, closeTo(width, .001));
        for (var index = 0; index < 15; index++) {
          final rect = _tileRect(tester, index);
          expect(rect.width, closeTo(expectedWidth, .001));
          expect(rect.width, greaterThanOrEqualTo(math.min(width, minimum)));
          expect(
            rect.left,
            closeTo((index % columns) * (expectedWidth + 12), .001),
          );
          expect(rect.top, (index ~/ columns) * 92.0);
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('opt-in grid honors maxColumns and leaves Android unchanged', (
    tester,
  ) async {
    _configureView(tester);
    await _pumpGrid(
      tester,
      width: 3500,
      count: 3,
      maxColumns: 2,
      stretchDesktopColumns: true,
    );
    expect(_tileRect(tester, 0).width, 1744);
    expect(_tileRect(tester, 1).right, 3500);
    expect(_tileRect(tester, 2).top, 92);
    for (final viewportWidth in [899.0, 1920.0]) {
      await _pumpGrid(
        tester,
        width: 800,
        viewportWidth: viewportWidth,
        count: 3,
        platform: TargetPlatform.android,
      );
      // MaterialApp retains and animates the previous Windows ThemeData.
      // Compare settled Android layouts, not the platform-transition frame.
      await tester.pumpAndSettle();
      final gridContext = tester.element(find.byType(ResponsiveTileGrid));
      expect(Theme.of(gridContext).platform, TargetPlatform.android);
      expect(MediaQuery.sizeOf(gridContext).width, viewportWidth);
      final original = [
        for (var index = 0; index < 3; index++) _tileRect(tester, index),
      ];
      await _pumpGrid(
        tester,
        width: 800,
        viewportWidth: viewportWidth,
        count: 3,
        platform: TargetPlatform.android,
        stretchDesktopColumns: true,
      );
      await tester.pumpAndSettle();
      expect([
        for (var index = 0; index < 3; index++) _tileRect(tester, index),
      ], original);
      expect(tester.takeException(), isNull);
    }
  });

  for (final count in [1, 13]) {
    testWidgets(
      'Windows tiles never shrink while desktop content grows, count=$count',
      (tester) async {
        _configureView(tester);
        var previousWidth = 0.0;
        // Include the old 360 px column breakpoints as well as the new
        // 464 px wrapping thresholds, with samples immediately on both sides.
        final widths = <double>{360, 463, 464, 465, 959, 1267, 1536, 2600};
        for (var columns = 2; columns <= 6; columns++) {
          for (final nominalWidth in [360.0, 464.0]) {
            final threshold = columns * nominalWidth + (columns - 1) * 12;
            widths.addAll([threshold - 1, threshold, threshold + 1]);
          }
        }
        final sortedWidths = widths.toList()..sort();
        for (final availableWidth in sortedWidths) {
          await _pumpGrid(tester, width: availableWidth, count: count);
          final expectedWidth = math.min(464.0, availableWidth);
          final first = _tileRect(tester, 0);
          expect(
            first.width,
            greaterThanOrEqualTo(previousWidth),
            reason: 'Card shrank when available width reached $availableWidth',
          );
          previousWidth = first.width;
          for (var index = 0; index < count; index++) {
            final rect = _tileRect(tester, index);
            expect(
              rect.width,
              closeTo(expectedWidth, 0.001),
              reason: 'available=$availableWidth index=$index',
            );
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(availableWidth + 0.001));
          }
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('Windows cards wrap at the exact next-column threshold', (
    tester,
  ) async {
    _configureView(tester);
    for (var columns = 2; columns <= 5; columns++) {
      final threshold = columns * 464.0 + (columns - 1) * 12;
      await _pumpGrid(tester, width: threshold - 1, count: columns);
      expect(_tileRect(tester, columns - 1).top, greaterThan(0));
      await _pumpGrid(tester, width: threshold, count: columns);
      expect(_tileRect(tester, columns - 1).top, 0);
      expect(_tileRect(tester, columns - 1).width, 464);
      expect(_tileRect(tester, columns - 1).right, threshold);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Windows short last row has the same widths as a full row', (
    tester,
  ) async {
    _configureView(tester);
    await _pumpGrid(tester, width: 1600, count: 7);
    for (var index = 0; index < 7; index++) {
      final rect = _tileRect(tester, index);
      expect(rect.width, 464);
      expect(rect.left, (index % 3) * 476.0);
      expect(rect.top, (index ~/ 3) * 92.0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows adding and removing books does not resize cards', (
    tester,
  ) async {
    _configureView(tester);
    for (final count in [1, 2, 3, 7, 2, 1]) {
      await _pumpGrid(tester, width: 1600, count: count);
      expect(_tileRect(tester, 0), const Rect.fromLTWH(0, 0, 464, 80));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Windows maxColumns does not stretch tiles across spare space', (
    tester,
  ) async {
    _configureView(tester);
    for (final maxColumns in [1, 2, 5]) {
      await _pumpGrid(
        tester,
        width: 3500,
        count: maxColumns + 1,
        maxColumns: maxColumns,
      );
      for (var index = 0; index < maxColumns; index++) {
        expect(_tileRect(tester, index).top, 0);
        expect(_tileRect(tester, index).width, 464);
      }
      final nextRow = _tileRect(tester, maxColumns);
      expect(nextRow.left, 0);
      expect(nextRow.top, 92);
      expect(nextRow.width, 464);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Windows honors custom minimum width and both spacing values', (
    tester,
  ) async {
    _configureView(tester);
    await _pumpGrid(
      tester,
      width: 2400,
      count: 5,
      minTileWidth: 720,
      maxColumns: 2,
      spacing: 23,
      runSpacing: 17,
    );
    for (var index = 0; index < 5; index++) {
      final rect = _tileRect(tester, index);
      expect(rect.width, 720);
      expect(rect.left, (index % 2) * 743.0);
      expect(rect.top, (index ~/ 2) * 97.0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows clamps oversized minimum to available width', (
    tester,
  ) async {
    _configureView(tester);
    await _pumpGrid(tester, width: 420, count: 2, minTileWidth: 720);
    expect(_tileRect(tester, 0), const Rect.fromLTWH(0, 0, 420, 80));
    expect(_tileRect(tester, 1), const Rect.fromLTWH(0, 92, 420, 80));
    expect(tester.takeException(), isNull);
  });

  for (final profile in [
    (0.8, 464.0),
    (1.0, 464.0),
    (1.3, 603.2),
    (1.5, 696.0),
    (2.6, 696.0),
  ]) {
    testWidgets('Windows preferred width follows text scale ${profile.$1}', (
      tester,
    ) async {
      _configureView(tester);
      await _pumpGrid(tester, width: 2500, count: 5, scale: profile.$1);
      for (var index = 0; index < 5; index++) {
        expect(_tileRect(tester, index).width, closeTo(profile.$2, 0.001));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Windows custom minimum still wins over scaled preferred width', (
    tester,
  ) async {
    _configureView(tester);
    await _pumpGrid(
      tester,
      width: 2500,
      count: 3,
      scale: 1.5,
      minTileWidth: 800,
    );
    expect(_tileRect(tester, 0).width, 800);
    expect(_tileRect(tester, 1).left, 812);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android wide grid keeps equal-column sizing at 100 percent', (
    tester,
  ) async {
    _configureView(tester);
    for (final (width, columns, expectedWidth) in [
      (960.0, 3, 312.0),
      (1240.0, 4, 301.0),
      (1600.0, 5, 310.4),
    ]) {
      await _pumpGrid(
        tester,
        width: width,
        count: 7,
        platform: TargetPlatform.android,
      );
      for (var index = 0; index < 7; index++) {
        final rect = _tileRect(tester, index);
        expect(rect.width, closeTo(expectedWidth, .001));
        expect(
          rect.left,
          closeTo((index % columns) * (expectedWidth + 12), .001),
        );
        expect(rect.top, (index ~/ columns) * 92.0);
      }
      expect(tester.takeException(), isNull);
    }
  });

  for (final (scale, layouts) in [
    (
      2.0,
      [
        (960.0, 1, 960.0),
        (1211.0, 1, 1211.0),
        (1212.0, 2, 600.0),
        (1240.0, 2, 614.0),
        (1600.0, 2, 794.0),
        (1824.0, 3, 600.0),
      ],
    ),
    (2.6, [(960.0, 1, 960.0), (1240.0, 1, 1240.0), (1600.0, 2, 794.0)]),
  ]) {
    testWidgets('Android wide grid reflows without reducing text scale $scale', (
      tester,
    ) async {
      _configureView(tester);
      // At 200%, a 300 dp minimum becomes 600 dp. This deliberately reduces
      // the number of columns instead of squeezing larger text into the old
      // 100% cells. Keep the above baseline and verify actual wrap thresholds.
      for (final (width, columns, expectedWidth) in layouts) {
        await _pumpGrid(
          tester,
          width: width,
          count: 7,
          scale: scale,
          platform: TargetPlatform.android,
        );
        final context = tester.element(find.byType(ResponsiveTileGrid));
        expect(
          MediaQuery.textScalerOf(context).scale(14),
          closeTo(14 * scale, .001),
        );
        for (var index = 0; index < 7; index++) {
          final rect = _tileRect(tester, index);
          expect(rect.width, closeTo(expectedWidth, .001));
          expect(
            rect.left,
            closeTo((index % columns) * (expectedWidth + 12), .001),
          );
          expect(rect.top, (index ~/ columns) * 92.0);
        }
        expect(_tileRect(tester, columns - 1).right, closeTo(width, .001));
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('$platform narrow windows retain a full-width list', (
      tester,
    ) async {
      _configureView(tester);
      await _pumpGrid(
        tester,
        width: 867,
        viewportWidth: 899,
        count: 3,
        platform: platform,
        runSpacing: 17,
      );
      for (var index = 0; index < 3; index++) {
        expect(
          _tileRect(tester, index),
          Rect.fromLTWH(0, index * 97.0, 867, 80),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty lists lay out without phantom cards or exceptions', (
    tester,
  ) async {
    _configureView(tester);
    for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
      for (final viewportWidth in [899.0, 1920.0]) {
        await _pumpGrid(
          tester,
          width: 600,
          viewportWidth: viewportWidth,
          count: 0,
          platform: platform,
        );
        expect(find.byKey(const ValueKey('tile-0')), findsNothing);
        expect(find.byType(ResponsiveTileGrid), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('scrolling a large keyed sliver reuses the row delegate', (
    tester,
  ) async {
    _configureView(tester, size: const Size(420, 480));
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var keyCalls = 0;
    var itemCalls = 0;
    const count = 1200;
    await tester.pumpWidget(
      _sliverHost(
        controller: controller,
        itemCount: count,
        keyBuilder: (index) {
          keyCalls++;
          return ValueKey(index);
        },
        itemBuilder: (context, index) {
          itemCalls++;
          return SizedBox(height: 60, child: Text('Book $index'));
        },
      ),
    );
    expect(keyCalls, count);
    expect(itemCalls, lessThan(20));
    final originalDelegate = tester
        .widget<SliverList>(find.byType(SliverList))
        .delegate;
    keyCalls = 0;
    itemCalls = 0;
    for (var row = 1; row <= 24; row++) {
      controller.jumpTo(row * 72.0);
      await tester.pump();
      expect(
        tester.widget<SliverList>(find.byType(SliverList)).delegate,
        same(originalDelegate),
      );
    }
    expect(controller.offset, 1728);
    expect(find.text('Book 26'), findsOneWidget);
    expect(keyCalls, 0, reason: 'Scrolling must not reindex the result set.');
    expect(itemCalls, inInclusiveRange(20, 34));
    expect(tester.takeException(), isNull);
  });

  for (final width in [420.0, 960.0]) {
    testWidgets('same-count reorder keeps card state and focus at $width', (
      tester,
    ) async {
      _configureView(tester, size: Size(width, 520));
      var order = [0, 1, 2, 3, 4, 5];
      // The callback has the same identity before and after the reorder.
      LocalKey keyBuilder(int index) => ValueKey(order[index]);
      Widget itemBuilder(BuildContext context, int index) =>
          _StatefulTile(key: ValueKey('card-${order[index]}'));
      Widget grid() => _sliverHost(
        itemCount: order.length,
        keyBuilder: keyBuilder,
        itemBuilder: itemBuilder,
      );

      await tester.pumpWidget(grid());
      final card = find.byKey(const ValueKey('card-4'));
      final before = tester.state<_StatefulTileState>(card);
      final beforePosition = tester.getTopLeft(card);
      before.focus.requestFocus();
      await tester.pump();
      expect(before.focus.hasPrimaryFocus, isTrue);

      // Keep the same count and move the focused card to the preceding row.
      order = [0, 4, 2, 3, 1, 5];
      await tester.pumpWidget(grid());
      await tester.pump();
      expect(tester.state<_StatefulTileState>(card), same(before));
      expect(before.focus.hasPrimaryFocus, isTrue);
      expect(tester.getTopLeft(card).dy, lessThan(beforePosition.dy));
      expect(tester.takeException(), isNull);
    });
  }
}

void _configureView(WidgetTester tester, {Size size = const Size(4000, 2200)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpGrid(
  WidgetTester tester, {
  required double width,
  required int count,
  TargetPlatform platform = TargetPlatform.windows,
  double viewportWidth = 4000,
  double scale = 1,
  double spacing = 12,
  double runSpacing = 12,
  double minTileWidth = 300,
  int maxColumns = 5,
  bool stretchDesktopColumns = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(platform: platform),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: Size(viewportWidth, 2200),
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: ResponsiveTileGrid(
            stretchDesktopColumns: stretchDesktopColumns,
            spacing: spacing,
            runSpacing: runSpacing,
            minTileWidth: minTileWidth,
            maxColumns: maxColumns,
            children: [
              for (var index = 0; index < count; index++)
                SizedBox(key: ValueKey('tile-$index'), height: 80),
            ],
          ),
        ),
      ),
    ),
  ),
);

Rect _tileRect(WidgetTester tester, int index) =>
    tester.getRect(find.byKey(ValueKey('tile-$index')));

Widget _sliverHost({
  ScrollController? controller,
  required int itemCount,
  required LocalKey Function(int) keyBuilder,
  required IndexedWidgetBuilder itemBuilder,
}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.android),
  home: Scaffold(
    body: CustomScrollView(
      controller: controller,
      slivers: [
        SliverResponsiveTileGrid.builder(
          itemCount: itemCount,
          itemKeyBuilder: keyBuilder,
          itemBuilder: itemBuilder,
        ),
      ],
    ),
  ),
);

class _StatefulTile extends StatefulWidget {
  const _StatefulTile({required super.key});

  @override
  State<_StatefulTile> createState() => _StatefulTileState();
}

class _StatefulTileState extends State<_StatefulTile> {
  final focus = FocusNode();

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Focus(focusNode: focus, child: const SizedBox.expand()),
  );
}
