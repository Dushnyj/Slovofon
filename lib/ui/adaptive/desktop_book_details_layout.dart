import 'package:flutter/material.dart';

import 'desktop_layout.dart';

/// A single lazy scroll surface shared by both Windows book-details routes.
/// The split uses the space left by the shell, not the physical screen width.
class DesktopBookDetailsLayout extends StatefulWidget {
  const DesktopBookDetailsLayout({
    required this.summary,
    required this.contentSlivers,
    super.key,
  });

  final Widget summary;
  final List<Widget> contentSlivers;

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
    final padding = DesktopLayout.pagePadding(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final extraScale = (scale - 1).clamp(0.0, 2.0);
    final summaryMinimum = 300 + 60 * extraScale;
    final contentMinimum = 460 + 140 * extraScale;
    const gap = 32.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - padding.horizontal;
        final split = available >= summaryMinimum + gap + contentMinimum;
        final summaryWidth = (available * 0.28).clamp(
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
                          slivers: [
                            SliverConstrainedCrossAxis(
                              maxExtent: summaryWidth,
                              sliver: summary,
                            ),
                            SliverCrossAxisExpanded(
                              flex: 1,
                              sliver: SliverPadding(
                                padding: const EdgeInsets.only(left: gap),
                                sliver: content,
                              ),
                            ),
                          ],
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
}
