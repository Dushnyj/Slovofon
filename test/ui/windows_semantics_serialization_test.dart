import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/core/platform/app_device_profile.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/features/player/full_player_screen.dart';
import 'package:slovofon/features/settings/settings_screen.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/ui/motion/app_motion.dart';
import 'package:slovofon/ui/motion/motion_controls.dart';
import 'package:slovofon/ui/motion/motion_reveal.dart';
import 'package:slovofon/ui/motion/motion_tooltip.dart';

import 'support/catalog_performance_fixture.dart'
    show CatalogPerformanceFixture;

final probe = _SerialProbe();
void main() {
  _ProbeBinding();
  setUp(probe.reset);
  test('serial checker rejects a reference without a node definition', () {
    probe.apply({
      0: (children: [1], name: 'root'),
    });
    expect(probe.errors.single, contains('missing child 1'));
    probe.reset();
  });
  test('serial checker models removal of unchanged reparented descendants', () {
    probe.apply({
      0: (children: [1, 2], name: 'root'),
      1: (children: [3], name: 'old parent'),
      2: (children: <int>[], name: 'new parent'),
      3: (children: [4], name: 'moved node'),
      4: (children: <int>[], name: 'unchanged descendant'),
    });
    expect(probe.errors, isEmpty);
    probe.apply({
      1: (children: <int>[], name: 'old parent'),
      2: (children: [3], name: 'new parent'),
      3: (children: [4], name: 'moved node'),
    });
    expect(probe.errors.single, contains('missing child 4'));
    probe.reset();
  });
  for (final mode in AppAnimationsMode.values) {
    testWidgets(
      'serial slider route $mode retains actions and focus',
      (tester) async {
        final handle = tester.ensureSemantics();
        final navigator = GlobalKey<NavigatorState>();
        final focus = FocusNode();
        var value = .5;
        var starts = 0;
        var ends = 0;
        final motion = AppMotion(mode);
        await tester.pumpWidget(
          AppMotionScope(
            motion: motion,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: motion.applyTheme(
                ThemeData(platform: TargetPlatform.windows),
              ),
              home: const Scaffold(body: Text('Home')),
            ),
          ),
        );
        final popped = navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              body: StatefulBuilder(
                builder: (context, set) => Column(
                  children: [
                    const Text('Position'),
                    AppSlider(
                      key: const ValueKey('probe-slider'),
                      value: value,
                      divisions: 10,
                      semanticFormatterCallback: (position) =>
                          '${(position * 100).round()} percent',
                      focusNode: focus,
                      onChangeStart: (_) => starts++,
                      onChangeEnd: (_) => ends++,
                      onChanged: (next) => set(() => value = next),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(Slider), findsOneWidget);
        final node = tester.getSemantics(
          find.byKey(const ValueKey('probe-slider')),
        );
        SemanticsNode? actionNode;
        void inspect(SemanticsNode candidate) {
          if (candidate.getSemanticsData().hasAction(
            ui.SemanticsAction.increase,
          )) {
            actionNode = candidate;
          }
          candidate.visitChildren((child) {
            inspect(child);
            return true;
          });
        }

        inspect(node);
        expect(actionNode, isNotNull);
        expect(actionNode!.getSemanticsData().value, '50 percent');
        tester
            .renderObject(find.byType(Slider))
            .owner!
            .semanticsOwner!
            .performAction(actionNode!.id, ui.SemanticsAction.increase);
        await tester.pumpAndSettle();
        expect(value, closeTo(.6, .0001));
        expect(starts, 1);
        expect(ends, 1);
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(value, closeTo(.5, .0001));
        expect(focus.hasFocus, isTrue);
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        await popped;
        await tester.pumpWidget(const SizedBox());
        focus.dispose();
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
    for (final kind in ['icon', 'nested', 'sidebar', 'filled']) {
      testWidgets(
        'serial graph $mode $kind reveal hover scroll',
        (tester) async {
          final semantics = tester.ensureSemantics();
          var branch = 0;
          late StateSetter set;
          final motion = AppMotion(mode);
          Widget item(String name) {
            final button = AppIconButton(
              tooltip: name,
              onPressed: () {},
              icon: const Icon(Icons.play_arrow),
            );
            return switch (kind) {
              'icon' => button,
              'nested' => AppTooltip(
                message: 'Outer $name',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name),
                    AppTooltip(
                      message: 'Inner $name',
                      excludeFromSemantics: true,
                      child: const Text('Source'),
                    ),
                  ],
                ),
              ),
              'sidebar' => Semantics(
                selected: branch == 0,
                child: AppTooltip(
                  message: name,
                  child: InkWell(
                    onTap: () {},
                    child: const SizedBox(
                      width: 60,
                      height: 40,
                      child: Icon(Icons.home),
                    ),
                  ),
                ),
              ),
              _ => FilledButton(
                onPressed: () {},
                child: AppTooltip(
                  message: name,
                  child: Semantics(
                    label: name,
                    child: const Icon(Icons.play_arrow),
                  ),
                ),
              ),
            };
          }

          await tester.pumpWidget(
            AppMotionScope(
              motion: motion,
              child: MaterialApp(
                theme: motion.applyTheme(
                  ThemeData(platform: TargetPlatform.windows),
                ),
                home: StatefulBuilder(
                  builder: (context, setter) {
                    set = setter;
                    return Scaffold(
                      body: AppContentReveal(
                        changeKey: branch,
                        child: IndexedStack(
                          index: branch,
                          children: [
                            for (var b = 0; b < 2; b++)
                              ListView(
                                children: [
                                  Row(
                                    children: [
                                      for (final n in ['A', 'B', 'C'])
                                        SizedBox(
                                          key: ValueKey('$b$n'),
                                          width: 160,
                                          height: 80,
                                          child: item('$b$n'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 1500),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          if (kind == 'icon') {
            final root = tester.getSemantics(find.byKey(const ValueKey('0A')));
            var namedAction = false;
            void inspect(SemanticsNode node) {
              final data = node.getSemanticsData();
              if (data.label == '0A' &&
                  data.hasAction(ui.SemanticsAction.tap)) {
                namedAction = true;
              }
              node.visitChildren((child) {
                inspect(child);
                return true;
              });
            }

            inspect(root);
            expect(
              namedAction,
              isTrue,
              reason:
                  'Actual Material button retains accessible name and tap action',
            );
          }
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          for (final n in ['A', 'B', 'C']) {
            await mouse.moveTo(tester.getCenter(find.byKey(ValueKey('0$n'))));
            await tester.pumpAndSettle();
          }
          for (final b in [1, 0, 1, 0]) {
            set(() => branch = b);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 1));
            await tester.pumpAndSettle();
          }
          await mouse.removePointer();
          await tester.pumpWidget(const SizedBox());
          semantics.dispose();
          expect(
            probe.errors,
            isEmpty,
            reason: probe.errors.take(3).join('\n'),
          );
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
  testWidgets(
    'serial graph actual Home late accessibility, Settings scroll and warm navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1010);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = CatalogPerformanceFixture(bookCount: 4);
      fixture.books[0] = AudioPlaybackBook(
        id: 'white-nights',
        versionId: 'white-nights-v1',
        sourceId: 'izib',
        sourceBookId: 'art4331',
        title: 'Белые ночи',
        author: 'Федор Достоевский',
        narrator: 'Василий Дахненко',
        sourceName: 'Изибук',
        description:
            'Повесть знакомит слушателя с историей двух молодых людей.',
        chapters: List.generate(
          11,
          (i) => AudioPlaybackChapter(
            id: 'chapter-$i',
            index: i,
            title: 'Глава ${i + 1}',
            duration: const Duration(minutes: 11),
          ),
        ),
      );
      await fixture.initialize();
      await fixture.settings.setLanguageCode('ru');
      appRouter.go('/');
      await tester.pumpWidget(
        fixture.app(profile: const AppDeviceProfile(isTelevision: false)),
      );
      await tester.pumpAndSettle();
      await fixture.controller.seek(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await tester.pump();
      for (final route in [
        '/library',
        '/settings',
        '/',
        '/search',
        '/settings',
        '/',
        '/settings',
        '/',
      ]) {
        probe.scene = route;
        appRouter.go(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        if (route == '/settings') {
          final scrollables = find.descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          );
          for (final state in tester.stateList<ScrollableState>(scrollables)) {
            if (state.position.axis != Axis.vertical ||
                !state.position.hasContentDimensions) {
              continue;
            }
            for (final fraction in [0.5, 1.0, 0.0]) {
              probe.scene = '$route scroll $fraction';
              state.position.jumpTo(state.position.maxScrollExtent * fraction);
              await tester.pumpAndSettle();
            }
          }
        }
      }
      // Match native navigation: the player is pushed above the retained shell,
      // and accessibility is already enabled before the hidden route-layout frame.
      for (final route in ['/player', '/book/white-nights']) {
        appRouter.go('/library');
        await tester.pumpAndSettle();
        probe.scene = 'push $route';
        final popped = appRouter.push<void>(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        if (route == '/player') {
          expect(find.byType(FullPlayerScreen), findsOneWidget);
          for (final tab in [1, 2, 3, 0, 1]) {
            probe.scene = 'player tab $tab';
            await tester.tap(find.byKey(ValueKey('windows-player-tab-$tab')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 1));
            await tester.pumpAndSettle();
            for (final state
                in tester
                    .stateList<ScrollableState>(
                      find.descendant(
                        of: find.byType(FullPlayerScreen),
                        matching: find.byType(Scrollable),
                      ),
                    )
                    .toList()) {
              if (state.position.axis != Axis.vertical ||
                  !state.position.hasContentDimensions) {
                continue;
              }
              for (final fraction in [0.5, 1.0, 0.0]) {
                probe.scene = 'player tab $tab scroll $fraction';
                state.position.jumpTo(
                  state.position.maxScrollExtent * fraction,
                );
                await tester.pumpAndSettle();
              }
            }
          }
        }
        probe.scene = 'pop $route';
        appRouter.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        await popped;
      }
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
      expect(probe.errors, isEmpty, reason: probe.errors.take(3).join('\n'));
    },
    semanticsEnabled: false,
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  tearDown(
    () =>
        expect(probe.errors, isEmpty, reason: probe.errors.take(3).join('\n')),
  );
}

class _ProbeBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _Builder();
}

class _Builder extends Fake implements ui.SemanticsUpdateBuilder {
  final updates = <int, ({List<int> children, String name})>{};
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #updateNode) {
      final args = i.namedArguments;
      updates[args[#id] as int] = (
        children: List<int>.from(args[#childrenInTraversalOrder] as Iterable),
        name: '${args[#label]} / ${args[#tooltip]}',
      );
      return null;
    }
    if (i.memberName == #updateCustomAction) return null;
    return super.noSuchMethod(i);
  }

  @override
  ui.SemanticsUpdate build() {
    probe.apply(updates);
    return ui.SemanticsUpdateBuilder().build();
  }
}

class _SerialProbe {
  final nodes = <int, ({List<int> children, String name})>{};
  final errors = <String>[];
  var frame = 0;
  String scene = 'initial';
  void reset() {
    nodes.clear();
    errors.clear();
    frame = 0;
    scene = 'initial';
  }

  void apply(Map<int, ({List<int> children, String name})> update) {
    frame++;
    // Win32 removes reparented subtrees before re-adding their pending updates.
    // Retaining a descendant only in our old graph would hide missing native
    // definitions after that removal phase.
    final parents = <int, int>{};
    for (final entry in nodes.entries) {
      for (final child in entry.value.children) {
        parents[child] = entry.key;
      }
    }
    final removed = <int>{};
    void removeSubtree(int id) {
      if (!removed.add(id)) return;
      for (final child in nodes[id]?.children ?? const <int>[]) {
        removeSubtree(child);
      }
    }

    for (final entry in update.entries) {
      for (final child in entry.value.children) {
        if (parents.containsKey(child) && parents[child] != entry.key) {
          removeSubtree(child);
        }
      }
    }
    nodes.removeWhere((id, _) => removed.contains(id));
    nodes.addAll(update);
    final visited = <int>{};
    void walk(int id) {
      if (!visited.add(id)) return;
      for (final child in nodes[id]?.children ?? const <int>[]) {
        if (!nodes.containsKey(child)) {
          errors.add(
            'Frame $frame $scene missing child $child of $id: ${nodes[id]?.name}',
          );
        }
        walk(child);
      }
    }

    walk(0);
    for (final entry in update.entries) {
      if (!visited.contains(entry.key)) {
        errors.add(
          'Frame $frame $scene orphan ${entry.key}: ${entry.value.name}, children=${entry.value.children}',
        );
      }
    }
    nodes.removeWhere((id, _) => !visited.contains(id));
  }
}
