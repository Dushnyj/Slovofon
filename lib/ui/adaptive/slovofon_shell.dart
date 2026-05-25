import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../components/mini_player_bar.dart';
import '../icons/app_icons.dart';

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
                icon: const AppIcon(AppIconAssets.navHome),
                selectedIcon: const AppIcon(AppIconAssets.navHome),
                label: strings.home,
              ),
              NavigationDestination(
                icon: const AppIcon(AppIconAssets.navSearch),
                selectedIcon: const AppIcon(AppIconAssets.navSearch),
                label: strings.search,
              ),
              NavigationDestination(
                icon: const AppIcon(AppIconAssets.navLibrary),
                selectedIcon: const AppIcon(AppIconAssets.navLibrary),
                label: strings.library,
              ),
              NavigationDestination(
                icon: const AppIcon(AppIconAssets.navDownloads),
                selectedIcon: const AppIcon(AppIconAssets.navDownloads),
                label: strings.downloads,
              ),
              NavigationDestination(
                icon: const AppIcon(AppIconAssets.navSettings),
                selectedIcon: const AppIcon(AppIconAssets.navSettings),
                label: strings.settings,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
