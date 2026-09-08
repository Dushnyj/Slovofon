import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/ui/icons/app_icons.dart';
import 'package:slovofon/ui/motion/app_motion.dart';
import 'package:slovofon/ui/motion/motion_tooltip.dart';

void main() {
  for (final mode in AppAnimationsMode.values) {
    testWidgets('search suffix semantics survives viewport clipping in $mode', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
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
                controller: scroll,
                scrollCacheExtent: const ScrollCacheExtent.pixels(1000),
                children: [
                  const SizedBox(height: 40),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Title, author or narrator',
                      suffixIcon: AppIconButton(
                        key: const ValueKey('search-submit'),
                        tooltip: 'Search',
                        onPressed: () {},
                        icon: const AppIcon(AppIconAssets.navSearch),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      for (final size in [
        const Size(900, 600),
        const Size(768, 480),
        const Size(1200, 800),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        for (final offset in [0.0, 40.0, 80.0, 120.0, 387.2, 800.0, 0.0]) {
          scroll.jumpTo(offset);
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '$mode $size scroll $offset',
          );
        }
      }
      expect(
        find.byKey(const ValueKey('search-submit')).hitTestable(),
        findsOneWidget,
      );
      final node = tester.getSemantics(
        find.byKey(const ValueKey('search-submit')),
      );
      expect(node.getSemanticsData().tooltip, 'Search');
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
