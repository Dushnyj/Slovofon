import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mock/stage3_mock_data.dart';
import '../features/book_details/book_details_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/player/full_player_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/theme_preview/theme_preview_screen.dart';
import '../ui/adaptive/slovofon_shell.dart';

final GoRouter appRouter = GoRouter(
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
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/downloads',
              builder: (context, state) => const DownloadsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/book/:bookId',
      builder: (context, state) {
        final book = mockBookById(state.pathParameters['bookId']);
        return BookDetailsScreen(book: book);
      },
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) => const FullPlayerScreen(),
    ),
    GoRoute(
      path: '/theme-preview',
      builder: (context, state) => const ThemePreviewScreen(),
    ),
  ],
);
