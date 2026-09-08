import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/core/platform/app_device_profile.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/home/home_screen.dart';
import 'package:slovofon/features/library/library_screen.dart';
import 'package:slovofon/features/search/search_screen.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';

import 'support/catalog_performance_fixture.dart';

void main() {
  for (final variant in ['phone', 'tv', 'windows']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'real $variant catalogs stay lazy at 500 books text=$scale',
        (tester) async {
          await _setView(tester, variant);
          final fixture = CatalogPerformanceFixture();
          await fixture.initialize(textScale: scale);
          appRouter.go('/');
          await tester.pumpWidget(
            fixture.app(
              profile: AppDeviceProfile(isTelevision: variant == 'tv'),
            ),
          );
          await tester.pumpAndSettle();
          for (final route in [
            '/',
            '/library',
            '/search?q=Audiobook&run=1&reset=performance',
          ]) {
            appRouter.go(route);
            await tester.pumpAndSettle();
            final page = find.byType(
              route == '/'
                  ? HomeScreen
                  : route == '/library'
                  ? LibraryScreen
                  : SearchScreen,
            );
            final mounted = find
                .descendant(
                  of: page,
                  matching: find.byType(BookCard, skipOffstage: false),
                  skipOffstage: false,
                )
                .evaluate()
                .length;
            final covers = find
                .descendant(
                  of: page,
                  matching: find.byType(BookCover, skipOffstage: false),
                  skipOffstage: false,
                )
                .evaluate()
                .length;
            debugPrint(
              'CATALOG_PERF $variant text=$scale route=$route data=${route.startsWith('/search') ? 120 : 500} mounted=$mounted covers=$covers',
            );
            expect(mounted, inInclusiveRange(1, 24));
            expect(covers, inInclusiveRange(1, 26));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(
          variant == 'windows'
              ? TargetPlatform.windows
              : TargetPlatform.android,
        ),
      );
    }
  }

  testWidgets(
    'retained real catalog branches ignore 50 playback ticks and restore scroll',
    (tester) async {
      await _setView(tester, 'windows');
      final fixture = CatalogPerformanceFixture();
      await fixture.initialize();
      appRouter.go('/');
      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      final homeScroll = find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(homeScroll).position.jumpTo(800);
      await tester.pumpAndSettle();
      final homeOffset = tester
          .state<ScrollableState>(homeScroll)
          .position
          .pixels;
      for (final route in [
        '/library',
        '/search?q=Audiobook&run=1&reset=hidden',
        '/settings',
      ]) {
        appRouter.go(route);
        await tester.pumpAndSettle();
      }
      await fixture.controller.play();
      await tester.pumpAndSettle();
      var hiddenCatalogBuilds = 0;
      final previousHook = debugOnRebuildDirtyWidget;
      addTearDown(() => debugOnRebuildDirtyWidget = previousHook);
      debugOnRebuildDirtyWidget = (element, _) {
        var catalog = false;
        var hidden = false;
        element.visitAncestorElements((ancestor) {
          final widget = ancestor.widget;
          catalog |=
              widget is HomeScreen ||
              widget is LibraryScreen ||
              widget is SearchScreen;
          hidden |= widget is Offstage && widget.offstage;
          return true;
        });
        if (catalog && hidden) hiddenCatalogBuilds++;
      };
      for (var tick = 1; tick <= 50; tick++) {
        await fixture.engine.seek(Duration(seconds: 600 + tick));
        await tester.pump();
      }
      debugOnRebuildDirtyWidget = previousHook;
      debugPrint(
        'CATALOG_PERF real hidden ticks=50 hiddenCatalogBuilds=$hiddenCatalogBuilds',
      );
      expect(hiddenCatalogBuilds, 0);
      appRouter.go('/');
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(homeScroll).position.pixels,
        homeOffset,
      );
      expect(fixture.controller.state.position, const Duration(seconds: 650));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets(
    'real catalogs gate 50 hidden download notifications and refresh on return',
    (tester) async {
      await _setView(tester, 'windows');
      final fixture = CatalogPerformanceFixture();
      await fixture.initialize();
      final book = fixture.books.first;
      appRouter.go('/');
      await tester.pumpWidget(fixture.app());
      await tester.pumpAndSettle();
      const routes = [
        '/',
        '/library',
        '/search?q=Audiobook&run=1&reset=downloads',
      ];
      Finder card() => find.byWidgetPredicate(
        (widget) =>
            widget is BookCard && widget.book.sourceBookId == book.sourceBookId,
      );
      for (final route in routes) {
        appRouter.go(route);
        await tester.pumpAndSettle();
        fixture.downloads.updateBook(book, DownloadTaskStatus.paused, .25);
        await tester.pumpAndSettle();
        expect(card(), findsOneWidget, reason: 'Visible fixture-0 on $route');
        expect(
          tester.widget<BookCard>(card()).downloadState,
          BookCardDownloadState.paused,
          reason: 'Active paused notification on $route',
        );
        fixture.downloads.updateBook(book, DownloadTaskStatus.failed, .5);
        await tester.pumpAndSettle();
        expect(
          tester.widget<BookCard>(card()).downloadState,
          BookCardDownloadState.failed,
          reason: 'Active failed notification on $route',
        );
      }
      appRouter.go('/');
      await tester.pumpAndSettle();
      final homeScroll = find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(homeScroll).position.jumpTo(800);
      await tester.pumpAndSettle();
      appRouter.go('/settings');
      await tester.pumpAndSettle();
      var hiddenBuilds = 0;
      final previousHook = debugOnRebuildDirtyWidget;
      addTearDown(() => debugOnRebuildDirtyWidget = previousHook);
      debugOnRebuildDirtyWidget = (element, _) {
        var catalog = false;
        var hidden = false;
        element.visitAncestorElements((ancestor) {
          final widget = ancestor.widget;
          catalog |=
              widget is HomeScreen ||
              widget is LibraryScreen ||
              widget is SearchScreen;
          hidden |= widget is Offstage && widget.offstage;
          return true;
        });
        if (catalog && hidden) hiddenBuilds++;
      };
      for (var tick = 0; tick < 50; tick++) {
        fixture.downloads.updateBook(
          book,
          DownloadTaskStatus.paused,
          tick / 100,
        );
        await tester.pump();
      }
      debugOnRebuildDirtyWidget = previousHook;
      debugPrint(
        'CATALOG_PERF hidden download notifications=50 hiddenCatalogBuilds=$hiddenBuilds',
      );
      expect(hiddenBuilds, 0);
      appRouter.go('/');
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(homeScroll).position.pixels, 800);
      tester.state<ScrollableState>(homeScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      for (final route in routes) {
        appRouter.go(route);
        await tester.pumpAndSettle();
        expect(card(), findsOneWidget, reason: 'Visible fixture-0 on $route');
        expect(
          tester.widget<BookCard>(card()).downloadState,
          BookCardDownloadState.paused,
          reason: 'Latest hidden notification restored on $route',
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}

Future<void> _setView(WidgetTester tester, String variant) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = switch (variant) {
    'windows' => const Size(1440, 900),
    'tv' => const Size(960, 540),
    _ => const Size(393, 852),
  };
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
