import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/ui/motion/app_motion.dart';
import 'package:slovofon/ui/motion/motion_tooltip.dart';

List<SemanticsNode> _nodes(SemanticsNode root) {
  final result = <SemanticsNode>[root];
  root.visitChildren((child) {
    result.addAll(_nodes(child));
    return true;
  });
  return result;
}

void main() {
  for (final mode in AppAnimationsMode.values) {
    testWidgets(
      'sibling tooltip portal anchors survive list merging: $mode',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final motion = AppMotion(mode);
        await tester.pumpWidget(
          AppMotionScope(
            motion: motion,
            child: MaterialApp(
              theme: motion.applyTheme(
                ThemeData(platform: TargetPlatform.windows),
              ),
              home: Scaffold(
                body: ListView(
                  children: [
                    Row(
                      children: [
                        for (final name in ['A', 'B', 'C'])
                          AppTooltip(
                            message: 'Details $name',
                            waitDuration: Duration.zero,
                            child: SizedBox(
                              key: ValueKey(name),
                              width: 100,
                              height: 80,
                              child: Text(name),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final row = tester.getSemantics(find.byType(Row).first);
        final anchors = _nodes(
          row,
        ).where((node) => node.traversalParentIdentifier != null).toList();
        expect(
          anchors,
          hasLength(3),
          reason: 'Every portal keeps its own anchor',
        );
        expect(
          anchors.map((node) => node.traversalParentIdentifier).toSet(),
          hasLength(3),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        for (final name in ['A', 'B', 'C', 'A']) {
          await mouse.moveTo(tester.getCenter(find.byKey(ValueKey(name))));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Details $name'), findsOneWidget);
        }
        await mouse.moveTo(const Offset(700, 500));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
