import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'remote reveals the entire frame moving down and back up at $scale',
      (tester) async {
        final controller = ScrollController();
        final nodes = List.generate(
          12,
          (index) => FocusNode(debugLabel: 'row-$index'),
        );
        addTearDown(controller.dispose);
        for (final node in nodes) {
          addTearDown(node.dispose);
        }
        tester.view.physicalSize = const Size(600, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: TelevisionTheme.from(
              AppTheme.dark(),
            ).copyWith(platform: TargetPlatform.android),
            home: MediaQuery(
              data: MediaQueryData(
                navigationMode: NavigationMode.directional,
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 360,
                    height: 150,
                    child: ClipRect(
                      key: const ValueKey('viewport'),
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: SingleChildScrollView(
                          controller: controller,
                          child: Column(
                            children: [
                              for (var index = 0; index < nodes.length; index++)
                                TelevisionFocusFrame(
                                  key: ValueKey('frame-$index'),
                                  radius: 14,
                                  child: SizedBox(
                                    height: scale == 1 ? 60 : 100,
                                    child: ListTile(
                                      focusNode: nodes[index],
                                      autofocus: index == 0,
                                      title: Text('Option $index'),
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final viewport = tester.getRect(find.byKey(const ValueKey('viewport')));
        void expectVisible(int index) {
          expect(
            nodes[index].hasPrimaryFocus,
            isTrue,
            reason: 'No extra frame focus stop',
          );
          final frame = tester.getRect(find.byKey(ValueKey('frame-$index')));
          expect(
            frame.top,
            greaterThanOrEqualTo(viewport.top - .01),
            reason: 'Top border and padding clipped on row $index',
          );
          expect(
            frame.bottom,
            lessThanOrEqualTo(viewport.bottom + .01),
            reason: 'Bottom border and padding clipped on row $index',
          );
        }

        expectVisible(0);
        for (var index = 1; index < nodes.length; index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expectVisible(index);
        }
        expect(controller.offset, greaterThan(0));
        for (var index = nodes.length - 2; index >= 0; index--) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          expectVisible(index);
        }
        expect(controller.offset, closeTo(0, .01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      'selected ink and focus border share the rounded Material dark=$dark',
      (tester) async {
        final base = dark ? AppTheme.dark() : AppTheme.light();
        final theme = TelevisionTheme.from(
          base,
        ).copyWith(platform: TargetPlatform.android);
        final colors = theme.colorScheme;
        final boundaryKey = GlobalKey();
        final node = FocusNode();
        addTearDown(node.dispose);
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: Material(
                    color: colors.surface,
                    child: SizedBox(
                      width: 256,
                      height: 100,
                      child: Center(
                        child: SizedBox(
                          width: 224,
                          child: TelevisionFocusFrame(
                            key: const ValueKey('selected-frame'),
                            radius: 18,
                            child: SizedBox(
                              height: 64,
                              child: ListTile(
                                focusNode: node,
                                selected: true,
                                selectedTileColor: colors.secondaryContainer,
                                focusColor: colors.secondaryContainer,
                                title: const Text('Selected'),
                                onTap: () {},
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final frameFinder = find.byKey(const ValueKey('selected-frame'));
        final materialFinder = find
            .descendant(of: frameFinder, matching: find.byType(Material))
            .first;
        final material = tester.widget<Material>(materialFinder);
        final shape = material.shape! as RoundedRectangleBorder;
        expect(material.clipBehavior, Clip.antiAlias);
        expect(shape.borderRadius, BorderRadius.circular(18));
        expect(shape.side.width, 1);
        // The nearest ink host is the rounded frame, not the rectangular ancestor.
        final tileContext = tester.element(find.byType(ListTile));
        expect(
          tileContext.findAncestorWidgetOfExactType<Material>(),
          same(material),
        );
        final before = tester.getRect(materialFinder);
        final boundaryRect = tester.getRect(find.byKey(boundaryKey));
        final local = before.shift(-boundaryRect.topLeft);
        Future<ByteData> pixels() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(boundaryKey),
          );
          final data = await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            return data!;
          });
          return data!;
        }

        final selectedPixels = await pixels();
        expect(
          _pixel(
            selectedPixels,
            256,
            local.left.toInt() + 1,
            local.top.toInt() + 1,
          ),
          colors.surface.toARGB32(),
          reason:
              'Selected rectangular ink must not leak outside the rounded corner',
        );
        expect(
          _pixel(
            selectedPixels,
            256,
            local.center.dx.toInt(),
            local.top.toInt() + 7,
          ),
          colors.secondaryContainer.toARGB32(),
          reason: 'Selected fill remains visible inside the same rounded frame',
        );
        node.requestFocus();
        await tester.pumpAndSettle();
        final focused = tester.widget<Material>(materialFinder);
        final focusedShape = focused.shape! as RoundedRectangleBorder;
        expect(focusedShape.borderRadius, shape.borderRadius);
        expect(focusedShape.side.width, 2);
        expect(focusedShape.side.color, colors.primary);
        expect(
          tester.getRect(materialFinder),
          before,
          reason: 'Focus border does not shift layout',
        );
        final focusedPixels = await pixels();
        expect(
          _pixel(
            focusedPixels,
            256,
            local.left.toInt() + 1,
            local.top.toInt() + 1,
          ),
          colors.surface.toARGB32(),
        );
        expect(
          _pixel(
            focusedPixels,
            256,
            local.center.dx.toInt(),
            local.top.toInt() + 1,
          ),
          colors.primary.toARGB32(),
          reason: 'The focused outline is painted above the selected ink',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('pending reveal is harmless after a focused frame is removed', (
    tester,
  ) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TelevisionFocusFrame(
              child: ListTile(
                focusNode: node,
                title: const Text('Option'),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

int _pixel(ByteData data, int width, int x, int y) {
  final offset = (y * width + x) * 4;
  return Color.fromARGB(
    data.getUint8(offset + 3),
    data.getUint8(offset),
    data.getUint8(offset + 1),
    data.getUint8(offset + 2),
  ).toARGB32();
}
