import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';

const _logicalDesktop = Size(1920, 1080);
const _dpiScales = [1.0, 1.25, 1.5, 2.0];
const _bodyKey = ValueKey('dpi-probe-body');
const _textKey = ValueKey('dpi-probe-text');
const _primaryKey = ValueKey('dpi-primary');
const _secondaryKey = ValueKey('dpi-secondary');

void main() {
  for (final direction in TextDirection.values) {
    for (final textScale in [.75, 1.0, 2.0]) {
      testWidgets(
        'Windows logical geometry is DPI invariant: $direction text=$textScale',
        (tester) async {
          await _pumpShell(tester, direction: direction, textScale: textScale);
          Rect? sidebar;
          Rect? content;
          Size? dock;
          for (final dpi in _dpiScales) {
            _resize(tester, physical: _logicalDesktop * dpi, dpi: dpi);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final navigation = find.byKey(
              const ValueKey('desktop-navigation-sidebar'),
            );
            expect(navigation, findsOneWidget);
            final nextSidebar = tester.getRect(navigation);
            final nextContent = tester.getRect(find.byKey(_bodyKey));
            final nextDock = tester.getSize(find.byType(DesktopMiniPlayerBar));
            sidebar ??= nextSidebar;
            content ??= nextContent;
            dock ??= nextDock;
            expect(nextSidebar, sidebar);
            expect(nextContent, content);
            expect(nextDock, dock);
            expect(nextSidebar.width, lessThanOrEqualTo(320));
            expect(nextDock.height, lessThan(300));

            final context = tester.element(find.byKey(_textKey));
            expect(MediaQuery.sizeOf(context), _logicalDesktop);
            expect(MediaQuery.devicePixelRatioOf(context), dpi);
            // Pixel density must never become a second font multiplier.
            expect(Theme.of(context).textTheme.bodyMedium!.fontSize, 14);
            expect(
              MediaQuery.textScalerOf(context).scale(14),
              closeTo(14 * textScale, .001),
            );
            final paragraph = tester.renderObject<RenderParagraph>(
              find.byKey(_textKey),
            );
            expect(paragraph.textScaler.scale(14), 14 * textScale);
            if (direction == TextDirection.rtl) {
              expect(nextSidebar.right, _logicalDesktop.width);
              expect(nextContent.left, 0);
              final brand = find.descendant(
                of: navigation,
                matching: find.byKey(
                  const ValueKey('desktop-navigation-brand'),
                ),
              );
              expect(brand, findsOneWidget);
              expect(
                tester.widget<FittedBox>(brand).alignment,
                AlignmentDirectional.centerStart,
              );
            } else {
              expect(nextSidebar.left, 0);
              expect(nextContent.right, _logicalDesktop.width);
            }
          }
        },
      );
    }
  }

  testWidgets(
    'FHD high-DPI fallback keeps desktop navigation and active player',
    (tester) async {
      await _pumpShell(tester, textScale: 2);
      for (final profile in [
        for (final dpi in _dpiScales) (const Size(1920, 1080), dpi),
        (const Size(900, 600), 1.0),
        // Native minimums relax only when the monitor cannot accommodate them.
        (const Size(768, 480), 1.0),
      ]) {
        final (physical, dpi) = profile;
        _resize(tester, physical: physical, dpi: dpi);
        await tester.pumpAndSettle();
        final logical = physical / dpi;
        final compact = logical.width < 1100;
        expect(
          find.byKey(const ValueKey('windows-compact-navigation-rail')),
          compact ? findsOneWidget : findsNothing,
        );
        expect(find.byType(SlovofonBottomNavigationBar), findsNothing);
        final dock = tester.getSize(find.byType(DesktopMiniPlayerBar));
        expect(dock.width, closeTo(logical.width, .001));
        expect(dock.height, lessThan(logical.height / 2));
        expect(tester.getSize(find.byKey(_bodyKey)).height, greaterThan(200));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('4K at 100% adds workspace, not automatic interface zoom', (
    tester,
  ) async {
    await _pumpShell(tester);
    _resize(tester, physical: _logicalDesktop, dpi: 1);
    await tester.pumpAndSettle();
    final sidebar = tester.getSize(
      find.byKey(const ValueKey('desktop-navigation-sidebar')),
    );
    final dock = tester.getSize(find.byType(DesktopMiniPlayerBar));
    _resize(tester, physical: const Size(3840, 2160), dpi: 1);
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('desktop-navigation-sidebar')))
          .width,
      sidebar.width,
    );
    expect(
      tester.getSize(find.byType(DesktopMiniPlayerBar)).height,
      dock.height,
    );
    expect(
      tester.getSize(find.byKey(_bodyKey)).width,
      3840 - sidebar.width - 1,
    );
    expect(tester.getSize(find.byKey(_secondaryKey)).width, 340);
    expect(tester.getSize(find.byKey(_primaryKey)).width, greaterThan(3000));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system text scaling and app preference compose once, not with DPI',
    (tester) async {
      await _pumpShell(tester, textScale: 2, systemTextScale: 1.25);
      _resize(tester, physical: const Size(3840, 2160), dpi: 2);
      await tester.pumpAndSettle();
      final context = tester.element(find.byKey(_textKey));
      expect(MediaQuery.sizeOf(context), _logicalDesktop);
      expect(MediaQuery.textScalerOf(context).scale(14), 35);
      expect(Theme.of(context).textTheme.bodyMedium!.fontSize, 14);
      expect(tester.takeException(), isNull);
    },
  );
}

void _resize(
  WidgetTester tester, {
  required Size physical,
  required double dpi,
}) {
  tester.view.devicePixelRatio = dpi;
  tester.view.physicalSize = physical;
}

Future<void> _pumpShell(
  WidgetTester tester, {
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  double systemTextScale = 1,
}) async {
  _resize(tester, physical: _logicalDesktop, dpi: 1);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final playback = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(playback.dispose);
  await playback.loadBook(
    const AudioPlaybackBook(
      id: 'dpi-book',
      versionId: 'dpi-book-version',
      sourceId: 'izib',
      sourceName: 'Изибук',
      title: 'Белые ночи',
      author: 'Фёдор Достоевский',
      narrator: 'Василий Дахненко',
      chapters: [
        AudioPlaybackChapter(
          id: 'dpi-chapter',
          index: 0,
          title: 'Ночь первая',
          duration: Duration(minutes: 30),
        ),
      ],
    ),
  );
  final router = GoRouter(
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
                  builder: (context, state) => const _WorkspaceProbe(),
                ),
              ],
            ),
        ],
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
          AppTheme.dark().copyWith(platform: TargetPlatform.windows),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: AppTextScaler(
              TextScaler.linear(systemTextScale),
              textScale,
            ),
            disableAnimations: true,
          ),
          child: Directionality(textDirection: direction, child: child!),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _WorkspaceProbe extends StatelessWidget {
  const _WorkspaceProbe();

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: _bodyKey,
    child: ListView(
      padding: DesktopLayout.pagePadding(context),
      children: [
        const DesktopPageHeader(title: 'Library'),
        Text(
          'Logical text',
          key: _textKey,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        const DesktopWorkspaceColumns(
          primary: SizedBox(key: _primaryKey, height: 80),
          secondary: SizedBox(key: _secondaryKey, height: 80),
        ),
      ],
    ),
  );
}
