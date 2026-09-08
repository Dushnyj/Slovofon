import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/core/platform/app_device_profile.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/features/home/home_screen.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/motion/app_motion.dart';
import 'package:slovofon/ui/icons/app_icons.dart';
import 'package:slovofon/ui/motion/motion_controls.dart';
import 'package:slovofon/ui/motion/motion_progress_indicator.dart';
import 'package:slovofon/ui/motion/motion_tooltip.dart';

void main() {
  test('three policies distinguish color, spatial and disabled motion', () {
    const full = AppMotion(AppAnimationsMode.full);
    const reduced = AppMotion(AppAnimationsMode.reduced);
    const off = AppMotion(AppAnimationsMode.off);
    expect(full.duration().inMilliseconds, 160);
    expect(reduced.duration().inMilliseconds, 80);
    expect(off.duration(), Duration.zero);
    expect(full.spatialDuration().inMilliseconds, 220);
    expect(reduced.spatialDuration(), Duration.zero);
    expect(off.spatialDuration(), Duration.zero);
    expect(
      AppMotion.resolve(AppAnimationsMode.full, systemReduceMotion: true).mode,
      AppAnimationsMode.reduced,
    );
    expect(
      AppMotion.resolve(AppAnimationsMode.off, systemReduceMotion: true).mode,
      AppAnimationsMode.off,
    );
  });

  for (final profile in [
    ('windows', TargetPlatform.windows, const Size(1280, 800), false),
    ('phone', TargetPlatform.android, const Size(390, 844), false),
    ('tablet', TargetPlatform.android, const Size(1100, 800), false),
    ('tv', TargetPlatform.android, const Size(1280, 720), true),
  ]) {
    testWidgets(
      'actual app applies all modes and persists on ${profile.$1}',
      (tester) async {
        tester.view.physicalSize = profile.$3;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final persistence = MemoryAppSettingsPersistenceStore();
        final settings = AppSettingsStore(persistence);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appSettingsStoreProvider.overrideWith((ref) => settings),
              appDeviceProfileProvider.overrideWithValue(
                AppDeviceProfile(isTelevision: profile.$4),
              ),
            ],
            child: const SlovofonApp(),
          ),
        );
        await tester.pumpAndSettle();
        for (final mode in AppAnimationsMode.values) {
          await settings.setAnimationsMode(mode);
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(HomeScreen));
          final motion = AppMotion.of(context);
          expect(motion.mode, mode);
          expect((await persistence.load())!.animationsMode, mode);
          expect(
            MediaQuery.disableAnimationsOf(context),
            mode != AppAnimationsMode.full,
          );
          expect(DesktopLayout.motionDuration(context), motion.duration());
          final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
          expect(app.themeAnimationDuration, motion.themeDuration);
          final theme = Theme.of(context);
          expect(
            theme.filledButtonTheme.style!.animationDuration,
            motion.duration(),
          );
          expect(
            theme.expansionTileTheme.expansionAnimationStyle!.duration,
            motion.spatialDuration(),
          );
          expect(
            theme.pageTransitionsTheme.builders[profile.$2]!.transitionDuration,
            motion.routeDuration,
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(profile.$2),
    );
  }

  for (final mode in AppAnimationsMode.values) {
    testWidgets('$mode route transitions use policy duration and no off fade', (
      tester,
    ) async {
      final motion = AppMotion(mode);
      await tester.pumpWidget(
        _harness(
          mode,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('destination')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      final context = tester.element(
        find.text('destination', skipOffstage: false),
      );
      final route = ModalRoute.of(context)!;
      expect(route.transitionDuration, motion.routeDuration);
      if (mode == AppAnimationsMode.off) {
        await tester.pump();
        expect(route.animation!.value, 1);
      } else {
        await tester.pump(motion.routeDuration ~/ 2);
        expect(route.animation!.value, greaterThan(0));
        expect(route.animation!.value, lessThan(1));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode dialogs and sheets expose matching durations', (
      tester,
    ) async {
      final motion = AppMotion(mode);
      await tester.pumpWidget(
        _harness(
          mode,
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showMotionDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('dialog')),
                  ),
                  child: const Text('open dialog'),
                ),
                TextButton(
                  onPressed: () => showMotionBottomSheet<void>(
                    context: context,
                    builder: (_) =>
                        const SizedBox(height: 100, child: Text('sheet')),
                  ),
                  child: const Text('open sheet'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('open dialog'));
      await tester.pump();
      final dialogRoute = ModalRoute.of(tester.element(find.text('dialog')))!;
      expect(
        dialogRoute.transitionDuration,
        motion.dialogAnimationStyle.duration,
      );
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('open sheet'));
      await tester.pump();
      final sheetRoute = ModalRoute.of(tester.element(find.text('sheet')))!;
      expect(
        sheetRoute.transitionDuration,
        motion.sheetAnimationStyle.duration,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('already-open dialog and sheet adopt Off before closing', (
    tester,
  ) async {
    final selected = ValueNotifier(AppAnimationsMode.full);
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<AppAnimationsMode>(
        valueListenable: selected,
        builder: (_, mode, _) => _harness(
          mode,
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showMotionDialog<void>(
                    context: context,
                    builder: (_) =>
                        const AlertDialog(content: Text('dynamic dialog')),
                  ),
                  child: const Text('dialog open'),
                ),
                TextButton(
                  onPressed: () => showMotionBottomSheet<void>(
                    context: context,
                    builder: (_) => const SizedBox(
                      height: 100,
                      child: Text('dynamic sheet'),
                    ),
                  ),
                  child: const Text('sheet open'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final kind in ['dialog', 'sheet']) {
      selected.value = AppAnimationsMode.full;
      await tester.pumpAndSettle();
      await tester.tap(find.text('$kind open'));
      await tester.pumpAndSettle();
      selected.value = AppAnimationsMode.off;
      await tester.pump();
      final context = tester.element(find.text('dynamic $kind'));
      expect(ModalRoute.of(context)!.reverseTransitionDuration, Duration.zero);
      Navigator.of(context).pop();
      await tester.pump();
      await tester.pump();
      expect(find.text('dynamic $kind'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  for (final mode in [AppAnimationsMode.reduced, AppAnimationsMode.off]) {
    testWidgets('$mode tooltip keeps help and removes the default fade', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          mode,
          const AppIconButton(
            tooltip: 'Previous chapter',
            onPressed: null,
            icon: Icon(Icons.skip_previous),
          ),
        ),
      );
      final tooltip = tester.widget<RawTooltip>(find.byType(RawTooltip));
      expect(tooltip.animationStyle.duration, AppMotion(mode).duration());
      expect(tooltip.semanticsTooltip, 'Previous chapter');
      expect(find.byType(IconButton), findsOneWidget);
      tester
          .state<RawTooltipState>(find.byType(RawTooltip))
          .ensureTooltipVisible();
      await tester.pumpAndSettle();
      expect(find.text('Previous chapter'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'system reduced motion updates the running app without changing preference',
    (tester) async {
      final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appSettingsStoreProvider.overrideWith((ref) => settings)],
          child: const SlovofonApp(),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpAndSettle();
      expect(
        AppMotion.of(tester.element(find.byType(HomeScreen))).mode,
        AppAnimationsMode.reduced,
      );
      expect(settings.settings.animationsMode, AppAnimationsMode.full);
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpAndSettle();
      expect(
        AppMotion.of(tester.element(find.byType(HomeScreen))).mode,
        AppAnimationsMode.full,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Off loading and toggle controls settle without freezing any tickers',
    (tester) async {
      var checked = false;
      var switched = false;
      await tester.pumpWidget(
        _harness(
          AppAnimationsMode.off,
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                const AppCircularProgressIndicator(semanticsLabel: 'loading'),
                const AppLinearProgressIndicator(semanticsLabel: 'loading'),
                AppCheckboxListTile(
                  value: checked,
                  title: const Text('check'),
                  onChanged: (value) => setState(() => checked = value!),
                ),
                AppSwitchListTile(
                  value: switched,
                  title: const Text('switch'),
                  onChanged: (value) => setState(() => switched = value),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      final ring = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, isNotNull);
      await tester.tap(find.text('check'));
      await tester.pump();
      await tester.pump();
      expect(checked, true);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppIcon && widget.asset == AppIconAssets.systemCheck,
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('switch'));
      await tester.pump();
      await tester.pump();
      expect(switched, true);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'non-spatial discrete slider retains exact keyboard step and quantization',
    (tester) async {
      var value = 1.0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _harness(
          AppAnimationsMode.off,
          StatefulBuilder(
            builder: (_, setState) => AppSlider(
              value: value,
              min: .5,
              max: 2,
              divisions: 30,
              focusNode: focus,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, closeTo(1.05, .00001));
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.divisions, isNull);
      slider.onChanged!(1.129);
      await tester.pump();
      expect(value, closeTo(1.15, .00001));
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _harness(AppAnimationsMode mode, Widget child) {
  final motion = AppMotion(mode);
  return AppMotionScope(
    motion: motion,
    child: MaterialApp(
      theme: motion.applyTheme(ThemeData()),
      themeAnimationDuration: motion.themeDuration,
      home: Scaffold(body: child),
    ),
  );
}
