import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../components/mini_player_bar.dart';

class SlovofonShell extends StatelessWidget {
  const SlovofonShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Scaffold(
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerBar(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: strings.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.search_outlined),
                selectedIcon: const Icon(Icons.search_rounded),
                label: strings.search,
              ),
              NavigationDestination(
                icon: const Icon(Icons.library_books_outlined),
                selectedIcon: const Icon(Icons.library_books_rounded),
                label: strings.library,
              ),
              NavigationDestination(
                icon: const Icon(Icons.download_outlined),
                selectedIcon: const Icon(Icons.download_rounded),
                label: strings.downloads,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: strings.settings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
