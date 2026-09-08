import '../motion/motion_tooltip.dart';
import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';

import '../icons/app_icons.dart';
import 'television_metrics.dart';
import 'television_transport.dart';
export 'television_transport.dart';

/// A slim persistent rail leaves the vertical working area to the catalog.
class TelevisionShell extends StatefulWidget {
  const TelevisionShell({
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;

  @override
  State<TelevisionShell> createState() => _TelevisionShellState();
}

class _TelevisionShellState extends State<TelevisionShell> {
  final _navigationFocus = List.generate(
    5,
    (index) => FocusNode(debugLabel: 'TV navigation $index'),
  );

  @override
  void initState() {
    super.initState();
    _focusSelected();
  }

  @override
  void didUpdateWidget(TelevisionShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _focusSelected();
  }

  void _focusSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        _navigationFocus[widget.selectedIndex].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final node in _navigationFocus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('television-shell'),
    body: Row(
      children: [
        _TelevisionNavigation(
          selectedIndex: widget.selectedIndex,
          onSelected: widget.onSelected,
          focusNodes: _navigationFocus,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: TelevisionMetrics.contentInset,
                    right: TelevisionMetrics.contentInset,
                  ),
                  child: FocusTraversalGroup(child: widget.child),
                ),
              ),
              const TelevisionTransport(),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Root details retain TV chrome without nesting a phone Scaffold/navbar.
/// [child] is the route's body (including loading/error states), not an AppBar.
class TelevisionStandaloneShell extends StatefulWidget {
  const TelevisionStandaloneShell({
    required this.title,
    required this.child,
    this.leading,
    this.selectedIndex,
    this.showTransport = true,
    super.key,
  });
  final String title;
  final Widget child;
  final Widget? leading;
  final int? selectedIndex;
  final bool showTransport;

  @override
  State<TelevisionStandaloneShell> createState() =>
      _TelevisionStandaloneShellState();
}

class _TelevisionStandaloneShellState extends State<TelevisionStandaloneShell> {
  final _backFocus = FocusNode(debugLabel: 'TV standalone back');
  final _navigationFocus = List.generate(
    5,
    (index) => FocusNode(debugLabel: 'TV standalone navigation $index'),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.leading == null &&
          ModalRoute.of(context)?.isCurrent != false) {
        _backFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _backFocus.dispose();
    for (final node in _navigationFocus) {
      node.dispose();
    }
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _goToDestination(int index) {
    const paths = ['/', '/search', '/library', '/downloads', '/settings'];
    context.go(paths[index]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('television-standalone-shell'),
    body: Row(
      children: [
        _TelevisionNavigation(
          selectedIndex: widget.selectedIndex,
          onSelected: _goToDestination,
          focusNodes: _navigationFocus,
          keyPrefix: 'tv-standalone-nav',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: TelevisionMetrics.contentInset,
                    right: TelevisionMetrics.contentInset,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          widget.leading ??
                              AppIconButton(
                                key: const ValueKey('tv-standalone-back'),
                                focusNode: _backFocus,
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).backButtonTooltip,
                                onPressed: _back,
                                icon: const AppIcon(
                                  AppIconAssets.systemBack,
                                  size: 22,
                                ),
                              ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: widget.child),
                    ],
                  ),
                ),
              ),
              if (widget.showTransport) const TelevisionTransport(),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TelevisionNavigation extends StatelessWidget {
  const _TelevisionNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.focusNodes,
    this.keyPrefix = 'tv-nav',
  });
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final List<FocusNode> focusNodes;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final items = [
      (strings.home, AppIconAssets.navHome),
      (strings.search, AppIconAssets.navSearch),
      (strings.library, AppIconAssets.navLibrary),
      (strings.downloads, AppIconAssets.navDownloads),
      (strings.settings, AppIconAssets.navSettings),
    ];
    return Padding(
      padding: const EdgeInsets.only(
        left: TelevisionMetrics.contentInset,
        top: TelevisionMetrics.contentInset,
        bottom: TelevisionMetrics.contentInset,
      ),
      child: SizedBox(
        width: 56,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final (index, item) in items.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                Semantics(
                  selected: index == selectedIndex,
                  child: AppTooltip(
                    message: item.$1,
                    child: AppIconButton(
                      key: ValueKey('$keyPrefix-$index'),
                      focusNode: focusNodes[index],
                      onPressed: () => onSelected(index),
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                        foregroundColor: WidgetStatePropertyAll(
                          index == selectedIndex
                              ? colors.onSecondaryContainer
                              : colors.onSurfaceVariant,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (index == selectedIndex) {
                            return colors.secondaryContainer;
                          }
                          return states.contains(WidgetState.focused)
                              ? colors.surfaceContainerHigh
                              : colors.surface;
                        }),
                        side: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.focused)
                              ? BorderSide(color: colors.primary, width: 2)
                              : BorderSide(
                                  color: colors.surface.withValues(alpha: 0),
                                  width: 2,
                                ),
                        ),
                      ),
                      icon: AppIcon(item.$2, size: 22),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
