import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/adaptive/windows_playback_shortcuts.dart';

void main() {
  for (final width in [900.0, 1280.0]) {
    testWidgets(
      'Windows startup and pointer navigation keep Ctrl+tabs in the shell focus chain width=$width',
      (tester) async {
        final router = await _pump(tester, width: width);
        expect(router.state.uri.path, '/');
        final fallback = tester.widget<Focus>(
          find.byKey(const ValueKey('windows-shell-shortcut-focus')),
        );
        expect(fallback.skipTraversal, isTrue);
        // Deliberately no tap, Tab, requestFocus or autofocus in the route body:
        // this reproduces the real startup interaction, including app wrapper.
        await _tabKey(tester, LogicalKeyboardKey.digit2);
        expect(router.state.uri.path, '/search');
        await _tabKey(tester, LogicalKeyboardKey.digit1);
        expect(router.state.uri.path, '/');
        await tester.tap(find.byKey(const ValueKey('windows-navigation-1')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/search');
        await _tabKey(tester, LogicalKeyboardKey.digit3);
        expect(router.state.uri.path, '/library');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'standalone Windows details receive tab shortcuts without manual focus',
    (tester) async {
      final router = await _pump(tester, initialLocation: '/book');
      expect(
        find.byKey(const ValueKey('desktop-standalone-shell')),
        findsOneWidget,
      );
      await _tabKey(tester, LogicalKeyboardKey.digit2);
      expect(router.state.uri.path, '/search');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shell fallback does not steal dialog focus or route through a modal',
    (tester) async {
      final router = await _pump(tester);
      final routeContext = tester.element(find.text('route:/'));
      final dialog = showDialog<void>(
        context: routeContext,
        builder: (context) => AlertDialog(
          title: const Text('Modal'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _tabKey(tester, LogicalKeyboardKey.digit3);
      expect(router.state.uri.path, '/');
      expect(find.text('Modal'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await dialog;
      await _tabKey(tester, LogicalKeyboardKey.digit3);
      expect(router.state.uri.path, '/library');
    },
  );
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  double width = 1280,
  String initialLocation = '/',
}) async {
  tester.view.physicalSize = Size(width, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final playback = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(playback.dispose);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            SlovofonShell(navigationShell: shell),
        branches: [
          for (final path in [
            '/',
            '/search',
            '/library',
            '/downloads',
            '/settings',
          ])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) => Text('route:$path'),
                ),
              ],
            ),
        ],
      ),
      GoRoute(
        path: '/book',
        builder: (context, state) => const DesktopStandaloneShell(
          selectedIndex: 0,
          child: Text('Standalone book'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playbackControllerProvider.overrideWithValue(playback)],
      child: MaterialApp.router(
        routerConfig: router,
        theme: WindowsTheme.from(
          AppTheme.light(),
        ).copyWith(platform: TargetPlatform.windows),
        builder: (context, child) => WindowsPlaybackShortcuts(child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _tabKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}
