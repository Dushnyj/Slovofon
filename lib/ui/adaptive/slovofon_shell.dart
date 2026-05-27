import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final destinations = _destinations(strings);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return;
        }
        SystemNavigator.pop();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final body = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 450 &&
                  navigationShell.currentIndex != 0) {
                navigationShell.goBranch(0);
              }
            },
            child: navigationShell,
          );

          if (constraints.maxWidth >= 900) {
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: _goToBranch,
                      destinations: [
                        for (final destination in destinations)
                          NavigationRailDestination(
                            icon: AppIcon(destination.iconAsset),
                            selectedIcon: AppIcon(destination.iconAsset),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: body),
                          const MiniPlayerBar(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            body: SafeArea(child: body),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayerBar(),
                NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _goToBranch,
                  destinations: [
                    for (final destination in destinations)
                      NavigationDestination(
                        icon: AppIcon(destination.iconAsset),
                        selectedIcon: AppIcon(destination.iconAsset),
                        label: destination.label,
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  List<_ShellDestination> _destinations(AppStrings strings) {
    return [
      _ShellDestination(strings.home, AppIconAssets.navHome),
      _ShellDestination(strings.search, AppIconAssets.navSearch),
      _ShellDestination(strings.library, AppIconAssets.navLibrary),
      _ShellDestination(strings.downloads, AppIconAssets.navDownloads),
      _ShellDestination(strings.settings, AppIconAssets.navSettings),
    ];
  }
}

class _ShellDestination {
  const _ShellDestination(this.label, this.iconAsset);

  final String label;
  final String iconAsset;
}
