import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'desktop_layout.dart';
import 'television_layout.dart';

/// A lazy details surface shared by Windows and television book-details routes.
/// The split uses the space left by the shell, not the physical screen width.
class DesktopBookDetailsLayout extends StatefulWidget {
  const DesktopBookDetailsLayout({
    required this.summary,
    required this.contentSlivers,
    this.televisionTabs,
    super.key,
  });

  final Widget summary;
  final List<Widget> contentSlivers;
  final List<TelevisionBookDetailsTab>? televisionTabs;

  @override
  State<DesktopBookDetailsLayout> createState() =>
      _DesktopBookDetailsLayoutState();
}

class _DesktopBookDetailsLayoutState extends State<DesktopBookDetailsLayout> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final television = TelevisionLayout.isActive(context);
    if (television && widget.televisionTabs != null) {
      return _TelevisionTabbedDetails(
        summary: widget.summary,
        tabs: widget.televisionTabs!,
      );
    }
    final padding = television
        ? const EdgeInsets.fromLTRB(4, 8, 4, 12)
        : DesktopLayout.pagePadding(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final extraScale = (scale - 1).clamp(0.0, 2.0);
    final summaryMinimum = television
        ? 280 + 60 * extraScale
        : 300 + 60 * extraScale;
    final contentMinimum = television
        ? 330 + 80 * extraScale
        : 460 + 140 * extraScale;
    final gap = television ? 16.0 : 32.0;
    final direction = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - padding.horizontal;
        final split = available >= summaryMinimum + gap + contentMinimum;
        final summaryWidth = (available * (television ? 0.37 : 0.28)).clamp(
          summaryMinimum,
          420 + 10 * extraScale,
        );
        final summary = SliverToBoxAdapter(
          child: SizedBox(
            key: const ValueKey('desktop-details-summary'),
            child: _DetailsViewport(
              height: constraints.maxHeight,
              child: widget.summary,
            ),
          ),
        );
        final content = SliverMainAxisGroup(
          key: const ValueKey('desktop-details-main-column'),
          slivers: widget.contentSlivers,
        );
        final summaryColumn = SliverConstrainedCrossAxis(
          maxExtent: summaryWidth,
          sliver: summary,
        );
        final contentColumn = SliverCrossAxisExpanded(
          flex: 1,
          sliver: SliverPadding(
            padding: EdgeInsetsDirectional.only(start: gap).resolve(direction),
            sliver: content,
          ),
        );
        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: Scrollbar(
            controller: _controller,
            child: CustomScrollView(
              key: const ValueKey('desktop-details-scroll'),
              controller: _controller,
              slivers: [
                SliverPadding(
                  padding: padding,
                  sliver: split
                      ? SliverCrossAxisGroup(
                          key: const ValueKey('desktop-details-split'),
                          // SliverCrossAxisGroup lays out physical left-to-right;
                          // put the summary at the reading start in either locale.
                          slivers: direction == TextDirection.rtl
                              ? [contentColumn, summaryColumn]
                              : [summaryColumn, contentColumn],
                        )
                      : SliverMainAxisGroup(
                          key: const ValueKey('desktop-details-stacked'),
                          slivers: [
                            summary,
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 28),
                            ),
                            content,
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TelevisionBookDetailsTab {
  const TelevisionBookDetailsTab({required this.title, required this.slivers});
  final String title;
  final List<Widget> slivers;
}

/// A recognisable primary action without spending a TV profile row on a label.
/// The tooltip remains the accessible name; focus keeps a contrasting outline.
class TelevisionBookPlayButton extends StatelessWidget {
  const TelevisionBookPlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
    super.key,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton.filled(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size.square(40)),
        minimumSize: const WidgetStatePropertyAll(Size.square(40)),
        maximumSize: const WidgetStatePropertyAll(Size.square(40)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.surfaceContainerHigh
              : colors.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colors.onSurface.withValues(alpha: .38)
              : colors.onPrimary,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            width: states.contains(WidgetState.focused) ? 2 : 1,
            color: states.contains(WidgetState.focused)
                ? colors.onPrimary
                : colors.primary,
          ),
        ),
      ),
    );
  }
}

/// Chapters get their own viewport; a long description or book profile must
/// never push the first playable row below the television's fold.
class _TelevisionTabbedDetails extends StatefulWidget {
  const _TelevisionTabbedDetails({required this.summary, required this.tabs});
  final Widget summary;
  final List<TelevisionBookDetailsTab> tabs;
  @override
  State<_TelevisionTabbedDetails> createState() =>
      _TelevisionTabbedDetailsState();
}

class _TelevisionTabbedDetailsState extends State<_TelevisionTabbedDetails> {
  final _summary = ScrollController();
  final _content = ScrollController();
  final _contentFocus = FocusNode(skipTraversal: true);
  final _tabFocus = <FocusNode>[];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _syncTabFocus();
  }

  @override
  void didUpdateWidget(_TelevisionTabbedDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTabFocus();
  }

  void _syncTabFocus() {
    while (_tabFocus.length < widget.tabs.length) {
      _tabFocus.add(
        FocusNode(debugLabel: 'TV details tab ${_tabFocus.length}'),
      );
    }
    while (_tabFocus.length > widget.tabs.length) {
      _tabFocus.removeLast().dispose();
    }
  }

  KeyEventResult _contentKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    // Flutter drops directional history between the horizontal tab scroller and
    // this vertical list. Geometric Up from a wide first row would then select
    // whichever tab is nearest its centre, rather than the active chapter tab.
    if (_content.hasClients && _content.offset > .5) {
      return KeyEventResult.ignored;
    }
    final current = FocusManager.instance.primaryFocus;
    if (current == null) return KeyEventResult.ignored;
    final earlierRow = node.traversalDescendants.any(
      (candidate) =>
          candidate != current &&
          candidate.canRequestFocus &&
          !candidate.skipTraversal &&
          candidate.rect.top < current.rect.top - 1,
    );
    if (earlierRow) return KeyEventResult.ignored;
    _tabFocus[_selected.clamp(0, _tabFocus.length - 1)].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _summary.dispose();
    _content.dispose();
    _contentFocus.dispose();
    for (final node in _tabFocus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final extra = (scale - 1).clamp(0.0, 2.0);
    final selected = _selected.clamp(0, widget.tabs.length - 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final profile = _DetailsViewport(
          height: constraints.maxHeight,
          child: SizedBox(
            key: const ValueKey('desktop-details-summary'),
            child: widget.summary,
          ),
        );
        final panel = Column(
          key: const ValueKey('television-details-panel'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < widget.tabs.length; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: TextButton(
                        key: ValueKey('television-details-tab-$i'),
                        focusNode: _tabFocus[i],
                        style: ButtonStyle(
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.focused)
                                ? colors.onPrimary
                                : colors.onSurface,
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.focused)
                                ? colors.primary
                                : selected == i
                                ? colors.surfaceContainerHigh
                                : colors.surface,
                          ),
                          side: WidgetStateProperty.resolveWith(
                            (states) => BorderSide(
                              width: states.contains(WidgetState.focused)
                                  ? 2
                                  : 1,
                              color: states.contains(WidgetState.focused)
                                  ? colors.onPrimary
                                  : colors.outlineVariant,
                            ),
                          ),
                        ),
                        onPressed: () {
                          if (selected == i) return;
                          if (_content.hasClients) _content.jumpTo(0);
                          setState(() => _selected = i);
                        },
                        child: Semantics(
                          selected: selected == i,
                          child: Text(widget.tabs[i].title),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Focus(
                focusNode: _contentFocus,
                canRequestFocus: false,
                onKeyEvent: _contentKey,
                child: Scrollbar(
                  controller: _content,
                  child: CustomScrollView(
                    key: const ValueKey('desktop-details-scroll'),
                    controller: _content,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsetsDirectional.only(
                          end: 4,
                          bottom: 8,
                        ),
                        sliver: SliverMainAxisGroup(
                          slivers: widget.tabs[selected].slivers,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        final split = constraints.maxWidth >= 660 + 120 * extra;
        if (!split) {
          return ListView(
            key: const ValueKey('television-details-stacked'),
            padding: const EdgeInsets.all(4),
            children: [
              profile,
              const SizedBox(height: 12),
              SizedBox(height: constraints.maxHeight, child: panel),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            key: const ValueKey('television-details-split'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: (constraints.maxWidth * .34).clamp(
                  248 + 40 * extra,
                  288 + 40 * extra,
                ),
                child: Scrollbar(
                  controller: _summary,
                  child: SingleChildScrollView(
                    key: const ValueKey('television-details-summary-scroll'),
                    controller: _summary,
                    child: profile,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: panel),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsViewport extends InheritedWidget {
  const _DetailsViewport({required this.height, required super.child});

  final double height;

  static double heightOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DetailsViewport>()?.height ??
      MediaQuery.sizeOf(context).height;

  @override
  bool updateShouldNotify(_DetailsViewport oldWidget) =>
      height != oldWidget.height;
}

/// Covers remain artwork-sized; text, metadata and actions retain their actual
/// accessibility scale. A stacked page may use a horizontal summary when it fits.
class DesktopBookSummary extends StatelessWidget {
  const DesktopBookSummary({
    required this.coverBuilder,
    required this.metadata,
    required this.actions,
    this.details,
    this.source,
    super.key,
  });

  final Widget Function(double width) coverBuilder;
  final Widget metadata;
  final Widget actions;
  final Widget? details;
  final Widget? source;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final viewportHeight = _DetailsViewport.heightOf(context);
    if (TelevisionLayout.isActive(context)) {
      return _televisionSummary(context, viewportHeight);
    }
    final shortViewport = viewportHeight < 560;
    final inset = shortViewport ? 16.0 : 24.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal =
                constraints.maxWidth >= 500 + 200 * (scale - 1).clamp(0, 2);
            // A short client must not spend its first viewport on artwork.
            // This only bounds the cover, never the user's text scaler.
            final coverLimit = (viewportHeight * 0.32).clamp(100.0, 220.0);
            final coverWidth =
                (horizontal
                        ? constraints.maxWidth * 0.28
                        : constraints.maxWidth)
                    .clamp(0.0, coverLimit);
            final artwork = KeyedSubtree(
              key: const ValueKey('desktop-details-artwork'),
              child: coverBuilder(coverWidth),
            );
            final information = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (source != null) ...[source!, const SizedBox(height: 8)],
                KeyedSubtree(
                  key: const ValueKey('desktop-details-identity'),
                  child: metadata,
                ),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: const ValueKey('desktop-details-actions'),
                  child: actions,
                ),
                if (details != null) ...[
                  const SizedBox(height: 12),
                  Divider(color: colors.outlineVariant),
                  const SizedBox(height: 8),
                  details!,
                ],
              ],
            );
            if (horizontal) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: coverWidth, child: artwork),
                  const SizedBox(width: 28),
                  Expanded(child: information),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                information,
                const SizedBox(height: 20),
                Center(child: artwork),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _televisionSummary(BuildContext context, double viewportHeight) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('television-book-summary'),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final coverWidth = (viewportHeight * 0.20).clamp(64.0, 80.0);
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final horizontal =
                constraints.maxWidth >= coverWidth + 10 + 124 * scale;
            final identity = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (source != null) ...[source!, const SizedBox(height: 4)],
                metadata,
              ],
            );
            final artwork = SizedBox(
              key: const ValueKey('television-details-artwork'),
              width: coverWidth,
              child: coverBuilder(coverWidth),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (horizontal)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      artwork,
                      const SizedBox(width: 10),
                      Expanded(child: identity),
                    ],
                  )
                else ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: artwork,
                  ),
                  const SizedBox(height: 10),
                  identity,
                ],
                const SizedBox(height: 8),
                actions,
                if (details != null) ...[const SizedBox(height: 8), details!],
              ],
            );
          },
        ),
      ),
    );
  }
}
