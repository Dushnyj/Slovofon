import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../components/mini_player_bar.dart';
import '../icons/app_icons.dart';

class SlovofonShell extends StatelessWidget {
  const SlovofonShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final destinations = _destinations(strings);
    final router = GoRouter.of(context);

    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final shellIsCurrent = _isShellRoute(router.state.uri.path);

        return PopScope(
          canPop: !shellIsCurrent,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || !shellIsCurrent) {
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
                          onDestinationSelected: (index) =>
                              _goToBranch(context, index),
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
                    SlovofonBottomNavigationBar(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (index) =>
                          _goToBranch(context, index),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _goToBranch(BuildContext context, int index) {
    if (index == navigationShell.currentIndex && index == 1) {
      context.go('/search?reset=${DateTime.now().microsecondsSinceEpoch}');
      return;
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  bool _isShellRoute(String path) {
    return switch (path) {
      '/' || '/search' || '/library' || '/downloads' || '/settings' => true,
      _ => false,
    };
  }
}

class SlovofonBottomNavigationBar extends StatelessWidget {
  const SlovofonBottomNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: _MobileNavigationBar(
        destinations: _destinations(context.strings),
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }
}

void goToSlovofonTab(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go('/');
    case 1:
      context.go('/search?reset=${DateTime.now().microsecondsSinceEpoch}');
    case 2:
      context.go('/library');
    case 3:
      context.go('/downloads');
    case 4:
      context.go('/settings');
  }
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

class _MobileNavigationBar extends StatelessWidget {
  const _MobileNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      key: const ValueKey('mobile-navigation-bar'),
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          key: const ValueKey('mobile-navigation-bar-content'),
          height: 64,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _MobileNavigationItem(
                    destination: destinations[index],
                    index: index,
                    total: destinations.length,
                    selected: index == selectedIndex,
                    onSelected: () => onDestinationSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavigationItem extends StatelessWidget {
  const _MobileNavigationItem({
    required this.destination,
    required this.index,
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  final _ShellDestination destination;
  final int index;
  final int total;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final strings = context.strings;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: strings.navigationTabLabel(destination.label, index + 1, total),
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 34,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      width: selected ? 56 : 40,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected ? tokens.selected : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Center(
                        child: AppIcon(
                          destination.iconAsset,
                          color: foreground,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination(this.label, this.iconAsset);

  final String label;
  final String iconAsset;
}
