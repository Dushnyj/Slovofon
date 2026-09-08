import '../motion/motion_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../app/app_version.dart';
import 'desktop_layout.dart';
import 'television_layout.dart';
import 'television_shell.dart';
import '../components/mini_player_bar.dart';
import '../icons/app_icons.dart';
import '../motion/app_motion.dart';
import '../motion/motion_reveal.dart';

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
              if (TelevisionLayout.isActive(context)) {
                return TelevisionShell(
                  selectedIndex: navigationShell.currentIndex,
                  onSelected: (index) => _goToBranch(context, index),
                  child: AppContentReveal(
                    changeKey: navigationShell.currentIndex,
                    child: navigationShell,
                  ),
                );
              }
              final body = GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: DesktopLayout.isActive(context)
                    ? null
                    : (details) {
                        if ((details.primaryVelocity ?? 0) > 450 &&
                            navigationShell.currentIndex != 0) {
                          navigationShell.goBranch(0);
                        }
                      },
                child: AppContentReveal(
                  changeKey: navigationShell.currentIndex,
                  child: navigationShell,
                ),
              );

              if (DesktopLayout.isActive(context) ||
                  constraints.maxWidth >= 900) {
                return Scaffold(
                  body: _DesktopShellLayout(
                    destinations: destinations,
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: (index) =>
                        _goToBranch(context, index),
                    child: body,
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

/// Details routes retain their back stack while sharing the Windows chrome.
class DesktopStandaloneShell extends StatelessWidget {
  const DesktopStandaloneShell({
    required this.child,
    required this.selectedIndex,
    super.key,
  });
  final Widget child;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (!DesktopLayout.isActive(context)) return child;
    return Scaffold(
      key: const ValueKey('desktop-standalone-shell'),
      body: _DesktopShellLayout(
        destinations: _destinations(context.strings),
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => goToSlovofonTab(context, index),
        child: child,
      ),
    );
  }
}

class _DesktopShellLayout extends StatelessWidget {
  const _DesktopShellLayout({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final polished = DesktopLayout.isActive(context);

    final layout = Material(
      color: polished
          ? colorScheme.surface
          : colorScheme.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (polished && MediaQuery.sizeOf(context).width < 1100)
                    _WindowsCompactNavigationRail(
                      destinations: destinations,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                    )
                  else if (polished)
                    _WindowsNavigationSidebar(
                      destinations: destinations,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                    )
                  else
                    _DesktopNavigationSidebar(
                      destinations: destinations,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: onDestinationSelected,
                    ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                  Expanded(
                    // The wide touch shell can host routes without their own
                    // Scaffold. Paint ListTile/InkWell feedback above this
                    // surface, not on the ancestor Material behind it.
                    child: Material(
                      color: polished
                          ? colorScheme.surface
                          : colorScheme.surfaceContainerLowest,
                      child: polished
                          ? SizedBox.expand(
                              key: const ValueKey('desktop-content-frame'),
                              child: child,
                            )
                          : Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                key: const ValueKey('desktop-content-frame'),
                                constraints: const BoxConstraints(
                                  maxWidth: 1680,
                                ),
                                child: child,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const DesktopMiniPlayerBar(),
          ],
        ),
      ),
    );
    if (!polished) return layout;
    return CallbackShortcuts(
      bindings: {
        for (final (index, key) in [
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.digit3,
          LogicalKeyboardKey.digit4,
          LogicalKeyboardKey.digit5,
        ].indexed)
          SingleActivator(key, control: true): () =>
              onDestinationSelected(index),
      },
      // CallbackShortcuts cannot request focus itself. Without a descendant
      // focus target, the app-level playback scope can own startup focus and
      // Ctrl+1..5 never enters this shell's event chain. Skip traversal so the
      // fallback does not add an empty keyboard stop before real controls.
      child: _DesktopShortcutFocus(child: layout),
    );
  }
}

/// Navigator can focus the enclosing route scope after pointer navigation,
/// bypassing a shortcut listener below that scope. Recover only that empty
/// scope focus, never focus belonging to a control, another route or a dialog.
class _DesktopShortcutFocus extends StatefulWidget {
  const _DesktopShortcutFocus({required this.child});
  final Widget child;

  @override
  State<_DesktopShortcutFocus> createState() => _DesktopShortcutFocusState();
}

class _DesktopShortcutFocusState extends State<_DesktopShortcutFocus> {
  final _focus = FocusNode(debugLabel: 'Windows shell shortcut focus');
  FocusScopeNode? _scope;
  bool _restoreScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = FocusScope.of(context);
    if (!identical(scope, _scope)) {
      _scope?.removeListener(_restoreEmptyScopeFocus);
      _scope = scope..addListener(_restoreEmptyScopeFocus);
    }
    _restoreEmptyScopeFocus();
  }

  void _restoreEmptyScopeFocus() {
    if (_restoreScheduled || !(_scope?.hasPrimaryFocus ?? false)) return;
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      if (!mounted ||
          !(_scope?.hasPrimaryFocus ?? false) ||
          !_focus.canRequestFocus ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      _focus.requestFocus();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _scope?.removeListener(_restoreEmptyScopeFocus);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    key: const ValueKey('windows-shell-shortcut-focus'),
    focusNode: _focus,
    autofocus: true,
    skipTraversal: true,
    child: widget.child,
  );
}

class _WindowsCompactNavigationRail extends StatelessWidget {
  const _WindowsCompactNavigationRail({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('windows-compact-navigation-rail'),
      color: colors.surfaceContainerLowest,
      child: SizedBox(
        width: 80,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            children: [
              AppTooltip(
                message: context.strings.appTitle,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: AppIcon(
                    AppIconAssets.playerAudio,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
              ),
              for (var index = 0; index < destinations.length; index++) ...[
                if (index == destinations.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: colors.outlineVariant),
                  ),
                Semantics(
                  selected: selectedIndex == index,
                  label: destinations[index].label,
                  child: AppIconButton(
                    key: ValueKey('windows-navigation-$index'),
                    tooltip: '${destinations[index].label} · Ctrl+${index + 1}',
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      backgroundColor: selectedIndex == index
                          ? colors.secondaryContainer
                          : Colors.transparent,
                      foregroundColor: selectedIndex == index
                          ? colors.onSecondaryContainer
                          : colors.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => onDestinationSelected(index),
                    icon: AppIcon(destinations[index].iconAsset, size: 24),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowsNavigationSidebar extends StatelessWidget {
  const _WindowsNavigationSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = context.strings;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Material(
      key: const ValueKey('desktop-navigation-sidebar'),
      color: scheme.surfaceContainerLowest,
      child: SizedBox(
        width:
            ((MediaQuery.sizeOf(context).width >= 1200 ? 244.0 : 216.0) +
                    (scale - 1).clamp(0, 2) * 80)
                .clamp(216, 320),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AppIcon(
                                      AppIconAssets.playerAudio,
                                      size: 24,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FittedBox(
                                        key: const ValueKey(
                                          'desktop-navigation-brand',
                                        ),
                                        fit: BoxFit.scaleDown,
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: Text(
                                          strings.appTitle,
                                          maxLines: 1,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontFamily: 'Georgia',
                                                fontWeight: FontWeight.w700,
                                                fontSize: 22,
                                                letterSpacing: -0.7,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  strings.desktopLibraryLabel,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (var index = 0; index < 4; index++) ...[
                            _WindowsNavigationItem(
                              destination: destinations[index],
                              index: index,
                              selected: index == selectedIndex,
                              onSelected: () => onDestinationSelected(index),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 36 * scale.clamp(1, 2)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Divider(color: scheme.outlineVariant, height: 24),
                            _WindowsNavigationItem(
                              destination: destinations[4],
                              index: 4,
                              selected: selectedIndex == 4,
                              onSelected: () => onDestinationSelected(4),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                '${strings.appVersion} ${AppVersion.version}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WindowsNavigationItem extends StatefulWidget {
  const _WindowsNavigationItem({
    required this.destination,
    required this.index,
    required this.selected,
    required this.onSelected,
  });
  final _ShellDestination destination;
  final int index;
  final bool selected;
  final VoidCallback onSelected;

  @override
  State<_WindowsNavigationItem> createState() => _WindowsNavigationItemState();
}

class _WindowsNavigationItemState extends State<_WindowsNavigationItem> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = widget.selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;
    return Semantics(
      selected: widget.selected,
      child: AppTooltip(
        message: '${widget.destination.label} · Ctrl+${widget.index + 1}',
        child: AnimatedContainer(
          duration: DesktopLayout.motionDuration(context),
          decoration: BoxDecoration(
            color: widget.selected
                ? scheme.secondaryContainer
                : _hovered
                ? scheme.surfaceContainerLow
                : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            hoverDuration: AppMotion.of(context).duration(
              full: const Duration(milliseconds: 50),
              reduced: const Duration(milliseconds: 40),
            ),
            key: ValueKey('windows-navigation-${widget.index}'),
            onTap: widget.onSelected,
            onFocusChange: (value) => setState(() => _focused = value),
            onHover: (value) => setState(() => _hovered = value),
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    AppIcon(
                      widget.destination.iconAsset,
                      color: foreground,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (widget.selected)
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavigationSidebar extends StatelessWidget {
  const _DesktopNavigationSidebar({
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
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final brandStyle = DefaultTextStyle.of(context).style.merge(
      Theme.of(context).textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
    );
    final brandPainter = TextPainter(
      text: TextSpan(text: context.strings.appTitle, style: brandStyle),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.localeOf(context),
      maxLines: 1,
    )..layout();
    final brandWidth = brandPainter.width.ceilToDouble();
    brandPainter.dispose();
    final preferredWidth = (236 + (textScale - 1).clamp(0, 2) * 60)
        .clamp(236, 356)
        .toDouble();
    // A tablet keeps the user's real font size. Move the icon above the word
    // before widening the sidebar, and never split the product name mid-word.
    final minimumBrandWidth = brandWidth + 36;

    return Material(
      key: const ValueKey('desktop-navigation-sidebar'),
      color: colorScheme.surface,
      child: SizedBox(
        width: preferredWidth < minimumBrandWidth
            ? minimumBrandWidth
            : preferredWidth,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DesktopBrandHeader(style: brandStyle, textWidth: brandWidth),
                const SizedBox(height: 28),
                for (var index = 0; index < destinations.length; index++) ...[
                  _DesktopNavigationItem(
                    destination: destinations[index],
                    index: index,
                    total: destinations.length,
                    selected: index == selectedIndex,
                    onSelected: () => onDestinationSelected(index),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopBrandHeader extends StatelessWidget {
  const _DesktopBrandHeader({required this.style, required this.textWidth});

  final TextStyle style;
  final double textWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: AppIcon(
          AppIconAssets.playerAudio,
          size: 24,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
    final title = Text(
      context.strings.appTitle,
      key: const ValueKey('wide-navigation-brand'),
      style: style,
      maxLines: 1,
      softWrap: false,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (textWidth + 42 + 12 > constraints.maxWidth) {
          return Column(
            key: const ValueKey('wide-navigation-brand-stacked'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [icon, const SizedBox(height: 10), title],
          );
        }
        return Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(child: title),
          ],
        );
      },
    );
  }
}

class _DesktopNavigationItem extends StatelessWidget {
  const _DesktopNavigationItem({
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
    final strings = context.strings;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: strings.navigationTabLabel(destination.label, index + 1, total),
      child: AppTooltip(
        message: destination.label,
        child: InkWell(
          hoverDuration: AppMotion.of(context).duration(
            full: const Duration(milliseconds: 50),
            reduced: const Duration(milliseconds: 40),
          ),
          key: ValueKey('wide-navigation-item-$index'),
          borderRadius: BorderRadius.circular(14),
          onTap: onSelected,
          child: AnimatedContainer(
            duration: AppMotion.of(context).duration(),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.secondaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                AppIcon(destination.iconAsset, color: foreground, size: 23),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
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
    return _MobileNavigationBar(
      destinations: _destinations(context.strings),
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
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

    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium!.copyWith(height: 1, fontWeight: FontWeight.w700);
    final textScaler = MediaQuery.textScalerOf(context);

    return Material(
      key: const ValueKey('mobile-navigation-bar'),
      color: colorScheme.surface,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / destinations.length;
            var showAllLabels = true;
            var labelHeight = 0.0;
            for (final destination in destinations) {
              final painter = TextPainter(
                text: TextSpan(text: destination.label, style: labelStyle),
                textScaler: textScaler,
                textDirection: Directionality.of(context),
                locale: Localizations.localeOf(context),
                maxLines: 1,
              )..layout();
              if (painter.width > itemWidth - 4) showAllLabels = false;
              if (painter.height > labelHeight) labelHeight = painter.height;
              painter.dispose();
            }
            // Five large labels cannot fit a phone. Keep every destination
            // available and show the active label at full width, never shrink
            // the user's font or let fixed-height chrome clip it.
            return Column(
              key: const ValueKey('mobile-navigation-bar-content'),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: showAllLabels
                      ? (44 + labelHeight).clamp(64, double.infinity)
                      : 48,
                  child: Row(
                    children: [
                      for (var index = 0; index < destinations.length; index++)
                        Expanded(
                          child: _MobileNavigationItem(
                            destination: destinations[index],
                            index: index,
                            total: destinations.length,
                            selected: index == selectedIndex,
                            showLabel: showAllLabels,
                            onSelected: () => onDestinationSelected(index),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!showAllLabels &&
                    selectedIndex >= 0 &&
                    selectedIndex < destinations.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: ExcludeSemantics(
                      child: Text(
                        destinations[selectedIndex].label,
                        key: const ValueKey('mobile-navigation-active-label'),
                        textAlign: TextAlign.center,
                        style: labelStyle.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
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
    required this.showLabel,
    required this.onSelected,
  });

  final _ShellDestination destination;
  final int index;
  final int total;
  final bool selected;
  final bool showLabel;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: strings.navigationTabLabel(destination.label, index + 1, total),
      child: AppTooltip(
        message: destination.label,
        child: InkWell(
          hoverDuration: AppMotion.of(context).duration(
            full: const Duration(milliseconds: 50),
            reduced: const Duration(milliseconds: 40),
          ),
          key: ValueKey('mobile-navigation-item-$index'),
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
                      duration: AppMotion.of(context).duration(),
                      curve: Curves.easeOut,
                      width: selected ? 56 : 40,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.secondaryContainer
                            : Colors.transparent,
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
                if (showLabel) ...[
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : null,
                      height: 1.0,
                    ),
                  ),
                ],
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
