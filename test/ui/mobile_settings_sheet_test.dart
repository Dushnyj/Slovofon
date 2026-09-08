import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/ui/adaptive/adaptive_sheet.dart';
import 'package:slovofon/ui/components/filter_picker_sheet.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(412, 892)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('language sheet covers shell and keeps action visible '
          '$size scale=$scale', (tester) async {
        final root = _RouteObserver();
        final branch = _RouteObserver();
        var completed = false;
        await _pumpShell(
          tester,
          size: size,
          scale: scale,
          root: root,
          branch: branch,
          onComplete: () => completed = true,
        );
        await tester.tap(find.text('Open language'));
        await tester.pumpAndSettle();

        expect(
          root.routes.whereType<ModalBottomSheetRoute<void>>(),
          hasLength(1),
        );
        expect(branch.routes.whereType<ModalBottomSheetRoute<void>>(), isEmpty);
        expect(
          find.byKey(const ValueKey('persistent-shell-controls')).hitTestable(),
          findsNothing,
          reason: 'The mini-player and navigation must be behind the modal',
        );
        final action = find.byKey(const ValueKey('mobile-picker-action'));
        expect(action.hitTestable(), findsOneWidget);
        final rect = tester.getRect(action);
        expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
        expect(rect.height, greaterThanOrEqualTo(40));
        if (scale == 1) {
          expect(find.text('System language').hitTestable(), findsOneWidget);
          expect(find.text('Українська').hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(completed, isTrue);
        expect(find.byType(BottomSheet), findsNothing);
        expect(
          find.byKey(const ValueKey('persistent-shell-controls')).hitTestable(),
          findsOneWidget,
        );
      });
    }
  }

  for (final keyboard in [0.0, 200.0]) {
    testWidgets('short landscape sheet leaves every action reachable '
        'keyboard=$keyboard', (tester) async {
      await _pumpShell(tester, size: const Size(740, 360), scale: 2);
      await tester.tap(find.text('Open language'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Українська'));
      await tester.pumpAndSettle();
      expect(find.text('Українська').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.text('Done'));
      expect(rect.bottom, lessThanOrEqualTo(360 - keyboard));
      expect(find.text('Done').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  required double scale,
  _RouteObserver? root,
  _RouteObserver? branch,
  VoidCallback? onComplete,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark().copyWith(platform: TargetPlatform.android),
      navigatorObservers: [?root],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        bottomNavigationBar: const SizedBox(
          key: ValueKey('persistent-shell-controls'),
          height: 120,
          child: Text('Mini-player / navigation'),
        ),
        body: Navigator(
          observers: [?branch],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showAdaptiveSheet<void>(
                  context: context,
                  title: 'Language',
                  builder: (context) => FilterPickerSheet(
                    options: [
                      for (final name in [
                        'System language',
                        'Русский',
                        'English',
                        'Қазақша',
                        'Беларуская',
                        'Українська',
                      ])
                        ListTile(title: Text(name), onTap: () {}),
                    ],
                    action: FilledButton(
                      onPressed: () {
                        onComplete?.call();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ),
                ),
                child: const Text('Open language'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RouteObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
  }
}
