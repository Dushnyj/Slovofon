import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/book_details/saved_book_details_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/player/full_player_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/source_books/source_book_details_screen.dart';
import '../features/theme_preview/theme_preview_screen.dart';
import '../services/deep_links/slovofon_deep_link.dart';
import '../sources/sources.dart';
import '../ui/adaptive/slovofon_shell.dart';
import '../ui/adaptive/television_focus.dart';
import '../ui/adaptive/television_layout.dart';
import '../ui/adaptive/television_shell.dart';
import 'localization/app_strings.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'app-root');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder:
          (
            BuildContext context,
            GoRouterState state,
            StatefulNavigationShell navigationShell,
          ) {
            return SlovofonShell(navigationShell: navigationShell);
          },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const TelevisionBranchFocus(child: HomeScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) {
                final query = state.uri.queryParameters['q'];
                final kind = _searchKindFromQuery(
                  state.uri.queryParameters['kind'],
                );
                return TelevisionBranchFocus(
                  child: SearchScreen(
                    initialQuery: query,
                    initialKinds: kind == null ? null : {kind},
                    submitInitialSearch:
                        state.uri.queryParameters['run'] == '1',
                    resetToken: state.uri.queryParameters['reset'],
                  ),
                );
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) =>
                  const TelevisionBranchFocus(child: LibraryScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/downloads',
              builder: (context, state) =>
                  const TelevisionBranchFocus(child: DownloadsScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) =>
                  const TelevisionBranchFocus(child: SettingsScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/book',
      redirect: (context, state) {
        return sourceBookLocationFromDeepLink(state.uri) ?? '/';
      },
    ),
    GoRoute(
      path: '/book/:bookId',
      builder: (context, state) {
        return SavedBookDetailsScreen(bookId: state.pathParameters['bookId']!);
      },
    ),
    GoRoute(
      path: '/source-book/:sourceId/:sourceBookId',
      builder: (context, state) {
        return SourceBookDetailsScreen(
          ref: SourceBookRef(
            sourceId: state.pathParameters['sourceId']!,
            sourceBookId: Uri.decodeComponent(
              state.pathParameters['sourceBookId']!,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/scoped-search',
      builder: (context, state) {
        final query = state.uri.queryParameters['q'];
        final kind = _searchKindFromQuery(state.uri.queryParameters['kind']);
        final search = SearchScreen(
          initialQuery: query,
          initialKinds: kind == null ? null : {kind},
          submitInitialSearch: state.uri.queryParameters['run'] == '1',
          popOnResultsBack: true,
          resetToken: state.uri.queryParameters['reset'],
        );
        if (TelevisionLayout.isActive(context)) {
          return TelevisionStandaloneShell(
            title: context.strings.search,
            selectedIndex: 1,
            child: search,
          );
        }
        return Scaffold(body: search);
      },
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) {
        final initialTabIndex = switch (state.uri.queryParameters['tab']) {
          'chapters' => 1,
          'bookmarks' => 2,
          'information' => 3,
          _ => 0,
        };
        return FullPlayerScreen(initialTabIndex: initialTabIndex);
      },
    ),
    GoRoute(
      path: '/theme-preview',
      builder: (context, state) => const ThemePreviewScreen(),
    ),
  ],
);

SearchKind? _searchKindFromQuery(String? value) {
  return switch (value) {
    'title' => SearchKind.title,
    'author' => SearchKind.author,
    'narrator' => SearchKind.narrator,
    'series' => SearchKind.series,
    'genre' => SearchKind.genre,
    'all' => SearchKind.all,
    _ => null,
  };
}
