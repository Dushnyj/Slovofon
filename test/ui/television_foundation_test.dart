import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/ui/adaptive/television_focus.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/adaptive/television_metrics.dart';

void main() {
  testWidgets(
    'TV Full HD and 4K preserve logical layout, DPR and user text scale',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Rect? firstBounds;
      for (final dpr in [2.0, 4.0]) {
        tester.view.physicalSize = Size(960 * dpr, 540 * dpr);
        tester.view.devicePixelRatio = dpr;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: TelevisionViewport(child: child!),
            ),
            home: Builder(
              builder: (context) {
                final media = MediaQuery.of(context);
                expect(media.devicePixelRatio, dpr);
                expect(media.textScaler.scale(16), 24);
                expect(media.navigationMode, NavigationMode.directional);
                expect(media.size.width, closeTo(883.2, .001));
                expect(media.size.height, closeTo(496.8, .001));
                return const SizedBox.expand(key: ValueKey('working-area'));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bounds = tester.getRect(
          find.byKey(const ValueKey('working-area')),
        );
        if (firstBounds != null) expect(bounds, firstBounds);
        firstBounds = bounds;
        expect(tester.takeException(), isNull);
      }
    },
  );

  test(
    'TV wider logical panels gain space, rather than changing the font scale',
    () {
      final insets = TelevisionMetrics.safeInsetsFor(const Size(1920, 1080));
      expect(insets.horizontal, 128);
      expect(insets.vertical, 80);
      final theme = TelevisionTheme.from(AppTheme.dark());
      expect(theme.textTheme.bodyMedium!.fontSize, 14);
      expect(theme.textTheme.titleLarge!.fontSize, 20);
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({}),
        const Size(36, 36),
      );
      expect(theme.outlinedButtonTheme.style!.side!.resolve({})!.width, 1);
      expect(
        theme.outlinedButtonTheme.style!.side!.resolve({
          WidgetState.focused,
        })!.width,
        2,
      );
    },
  );

  testWidgets('TV highlight is deterministic and restores the prior strategy', (
    tester,
  ) async {
    final manager = FocusManager.instance;
    final before = manager.highlightStrategy;
    manager.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    addTearDown(() => manager.highlightStrategy = before);
    await tester.pumpWidget(
      const MaterialApp(home: TelevisionViewport(child: SizedBox())),
    );
    await tester.pumpAndSettle();
    expect(manager.highlightMode, FocusHighlightMode.traditional);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(manager.highlightStrategy, FocusHighlightStrategy.alwaysTouch);
  });

  for (final television in [true, false]) {
    testWidgets(
      'Only TV branch route edges reach shell chrome tv=$television',
      (tester) async {
        final top = FocusNode(debugLabel: 'top');
        final first = FocusNode(debugLabel: 'first');
        final last = FocusNode(debugLabel: 'last');
        final bottom = FocusNode(debugLabel: 'bottom');
        for (final node in [top, first, last, bottom]) {
          addTearDown(node.dispose);
        }
        await tester.pumpWidget(
          MaterialApp(
            home: TelevisionLayout(
              enabled: television,
              child: Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      focusNode: top,
                      onPressed: () {},
                      child: const Text('Navigation'),
                    ),
                    Expanded(
                      child: Navigator(
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (context) => TelevisionBranchFocus(
                            child: Scaffold(
                              body: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextButton(
                                    focusNode: first,
                                    onPressed: () {},
                                    child: const Text('First'),
                                  ),
                                  TextButton(
                                    focusNode: last,
                                    onPressed: () {
                                      showDialog<void>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Modal'),
                                          actions: [
                                            TextButton(
                                              autofocus: true,
                                              onPressed: () {},
                                              child: const Text('Modal action'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text('Last'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      focusNode: bottom,
                      onPressed: () {},
                      child: const Text('Transport'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        first.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(top.hasPrimaryFocus, television);
        expect(first.hasPrimaryFocus, !television);
        last.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(bottom.hasPrimaryFocus, television);
        expect(last.hasPrimaryFocus, !television);
        if (television) {
          last.requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.text('Modal'), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(bottom.hasFocus, isFalse);
          expect(top.hasFocus, isFalse);
          final focusedContext = FocusManager.instance.primaryFocus!.context!;
          expect(ModalRoute.of(focusedContext), isA<DialogRoute<void>>());
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('TV slider arrows adjust horizontally and leave vertically', (
    tester,
  ) async {
    final sliderFocus = FocusNode();
    final nextFocus = FocusNode();
    addTearDown(sliderFocus.dispose);
    addTearDown(nextFocus.dispose);
    var value = .5;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TelevisionViewport(child: child!),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                Slider(
                  focusNode: sliderFocus,
                  value: value,
                  divisions: 10,
                  onChanged: (next) => setState(() => value = next),
                ),
                TextButton(
                  focusNode: nextFocus,
                  onPressed: () {},
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    sliderFocus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(value, closeTo(.6, .001));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(value, closeTo(.6, .001));
    expect(nextFocus.hasPrimaryFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
