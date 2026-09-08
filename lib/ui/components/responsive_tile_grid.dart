import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../adaptive/desktop_layout.dart';
import '../adaptive/television_layout.dart';

bool isDesktopTileLayout(BuildContext context) {
  return !TelevisionLayout.isActive(context) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class ResponsiveTileGrid extends StatelessWidget {
  const ResponsiveTileGrid({
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.minTileWidth = 300,
    this.maxColumns = 5,
    this.televisionMinTileWidth = televisionBookMinWidth,
    this.televisionMaxColumns,
    this.stretchDesktopColumns = false,
    super.key,
  });

  static const televisionBookMinWidth = 360.0;

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double minTileWidth;
  final int maxColumns;

  /// Horizontal TV audiobook cards keep full metadata and a small cover.
  /// Actual text scaling reduces columns without changing the system scaler.
  final double televisionMinTileWidth;
  final int? televisionMaxColumns;

  /// Fill complete Windows rows while retaining the readable minimum width.
  /// Other consumers keep stable card widths unless they explicitly opt in.
  final bool stretchDesktopColumns;

  @override
  Widget build(BuildContext context) {
    if (TelevisionLayout.isActive(context)) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // TV density is expressed in logical pixels. Full HD at DPR 2 and
          // 4K at DPR 4 have the same number and size of readable columns.
          final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final minimum =
              math.max(1.0, televisionMinTileWidth) * math.max(1.0, textScale);
          final width = constraints.maxWidth;
          final availableColumns = math.max(
            1,
            ((width + spacing) / (minimum + spacing)).floor(),
          );
          final columns = math.max(
            1,
            math.min(
              televisionMaxColumns ?? availableColumns,
              availableColumns,
            ),
          );
          // Use the available column width, not the number of books: one
          // result keeps its place in a shelf instead of becoming a banner.
          return _tiles((width - spacing * (columns - 1)) / columns);
        },
      );
    }
    if (!isDesktopTileLayout(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) SizedBox(height: runSpacing),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (DesktopLayout.isActive(context)) {
          // Keep a readable, stable card width as columns are added. Dividing
          // all available space by a changing column count made cards shrink
          // when the window grew, even when there was only one book.
          final preferredWidth = math.max(
            minTileWidth,
            464.0 *
                (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                  1.0,
                  1.5,
                ),
          );
          if (stretchDesktopColumns) {
            final columns = math.max(
              1,
              math.min(
                maxColumns,
                ((width + spacing) / (preferredWidth + spacing)).floor(),
              ),
            );
            final tileWidth = (width - spacing * (columns - 1)) / columns;
            return _tiles(tileWidth);
          }
          final tileWidth = math.min(width, preferredWidth);
          final gridWidth = math.min(
            width,
            tileWidth * math.max(1, maxColumns) +
                spacing * (math.max(1, maxColumns) - 1),
          );
          return Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(width: gridWidth, child: _tiles(tileWidth)),
          );
        }

        // Wide touch layouts need space for larger text just like the TV
        // shelf, without changing the user's actual TextScaler. Bound the
        // preferred minimum to the viewport so even very large text can
        // fall back to one full-width column instead of overflowing it.
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final minimum = math.min(
          width,
          minTileWidth * math.max(1.0, textScale),
        );
        final calculatedColumns = ((width + spacing) / (minimum + spacing))
            .floor();
        final columns = math.max(1, math.min(maxColumns, calculatedColumns));
        final tileWidth = columns == 1
            ? width
            : (width - spacing * (columns - 1)) / columns;

        return _tiles(tileWidth);
      },
    );
  }

  Widget _tiles(double tileWidth) => Wrap(
    spacing: spacing,
    runSpacing: runSpacing,
    children: [
      for (final child in children) SizedBox(width: tileWidth, child: child),
    ],
  );
}

/// Shared pure geometry for lazy catalog rows and mixed-section SliverLists.
/// This intentionally matches the bounded box ResponsiveTileGrid layout.
({int columns, double tileWidth}) resolveResponsiveTileGridGeometry(
  BuildContext context,
  double width, {
  double spacing = 12,
  double minTileWidth = 300,
  int maxColumns = 5,
  double televisionMinTileWidth = ResponsiveTileGrid.televisionBookMinWidth,
  int? televisionMaxColumns,
  bool stretchDesktopColumns = false,
  bool singleColumn = false,
}) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  var columns = 1;
  var tileWidth = width;
  if (!singleColumn && TelevisionLayout.isActive(context)) {
    final minimum =
        math.max(1.0, televisionMinTileWidth) * math.max(1.0, scale);
    final available = math.max(
      1,
      ((width + spacing) / (minimum + spacing)).floor(),
    );
    columns = math.max(
      1,
      math.min(televisionMaxColumns ?? available, available),
    );
    tileWidth = (width - spacing * (columns - 1)) / columns;
  } else if (!singleColumn && isDesktopTileLayout(context)) {
    if (DesktopLayout.isActive(context)) {
      final preferred = math.max(minTileWidth, 464.0 * scale.clamp(1.0, 1.5));
      columns = math.max(
        1,
        math.min(
          maxColumns,
          ((width + spacing) / (preferred + spacing)).floor(),
        ),
      );
      tileWidth = stretchDesktopColumns
          ? (width - spacing * (columns - 1)) / columns
          : math.min(width, preferred);
    } else {
      final minimum = math.min(width, minTileWidth * math.max(1.0, scale));
      columns = math.max(
        1,
        math.min(maxColumns, ((width + spacing) / (minimum + spacing)).floor()),
      );
      tileWidth = (width - spacing * (columns - 1)) / columns;
    }
  }
  return (columns: columns, tileWidth: tileWidth);
}

/// Scroll-native equivalent of [ResponsiveTileGrid]. Only viewport/cache rows
/// are mounted; row height remains natural (including 200% text), as with Wrap.
/// Use the box variant only for small, bounded collections.
class SliverResponsiveTileGrid extends StatefulWidget {
  const SliverResponsiveTileGrid.builder({
    required this.itemCount,
    required this.itemBuilder,
    this.itemKeyBuilder,
    this.spacing = 12,
    this.runSpacing = 12,
    this.minTileWidth = 300,
    this.maxColumns = 5,
    this.televisionMinTileWidth = ResponsiveTileGrid.televisionBookMinWidth,
    this.televisionMaxColumns,
    this.stretchDesktopColumns = false,
    this.singleColumn = false,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final LocalKey Function(int index)? itemKeyBuilder;
  final double spacing;
  final double runSpacing;
  final double minTileWidth;
  final int maxColumns;
  final double televisionMinTileWidth;
  final int? televisionMaxColumns;
  final bool stretchDesktopColumns;
  final bool singleColumn;

  @override
  State<SliverResponsiveTileGrid> createState() =>
      _SliverResponsiveTileGridState();
}

class _SliverResponsiveTileGridState extends State<SliverResponsiveTileGrid> {
  // Stable, lazily allocated keys retain a focused card when incremental search
  // inserts/sorts results into different rows. Never key by list position.
  final _itemKeys = <LocalKey, GlobalKey>{};
  int get itemCount => widget.itemCount;
  IndexedWidgetBuilder get itemBuilder => widget.itemBuilder;
  LocalKey Function(int)? get itemKeyBuilder => widget.itemKeyBuilder;
  double get spacing => widget.spacing;
  double get runSpacing => widget.runSpacing;
  double get minTileWidth => widget.minTileWidth;
  int get maxColumns => widget.maxColumns;
  double get televisionMinTileWidth => widget.televisionMinTileWidth;
  int? get televisionMaxColumns => widget.televisionMaxColumns;
  bool get stretchDesktopColumns => widget.stretchDesktopColumns;
  bool get singleColumn => widget.singleColumn;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.crossAxisExtent;
      final geometry = resolveResponsiveTileGridGeometry(
        context,
        width,
        spacing: spacing,
        minTileWidth: minTileWidth,
        maxColumns: maxColumns,
        televisionMinTileWidth: televisionMinTileWidth,
        televisionMaxColumns: televisionMaxColumns,
        stretchDesktopColumns: stretchDesktopColumns,
        singleColumn: singleColumn,
      );
      final columns = geometry.columns;
      final tileWidth = geometry.tileWidth;
      final rowCount = (itemCount / columns).ceil();
      if (itemKeyBuilder != null && _itemKeys.isNotEmpty) {
        final currentKeys = {
          for (var i = 0; i < itemCount; i++) itemKeyBuilder!(i),
        };
        _itemKeys.removeWhere((key, _) => !currentKeys.contains(key));
      }
      // A keyed row lets the sliver retain state when entries reorder. The
      // item keys inside it also keep focus/state aligned with book identity.
      final rowIndices = itemKeyBuilder == null
          ? null
          : <Key, int>{
              for (var row = 0; row < rowCount; row++)
                ValueKey<LocalKey>(itemKeyBuilder!(row * columns)): row,
            };
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, row) {
            final start = row * columns;
            return Padding(
              key: itemKeyBuilder == null
                  ? null
                  : ValueKey<LocalKey>(itemKeyBuilder!(start)),
              padding: EdgeInsets.only(
                bottom: row == rowCount - 1 ? 0 : runSpacing,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (
                    var column = 0;
                    column < columns && start + column < itemCount;
                    column++
                  ) ...[
                    if (column > 0) SizedBox(width: spacing),
                    SizedBox(
                      key: itemKeyBuilder?.call(start + column),
                      width: tileWidth,
                      child: itemKeyBuilder == null
                          ? itemBuilder(context, start + column)
                          : KeyedSubtree(
                              key: _itemKeys.putIfAbsent(
                                itemKeyBuilder!(start + column),
                                GlobalKey.new,
                              ),
                              child: itemBuilder(context, start + column),
                            ),
                    ),
                  ],
                ],
              ),
            );
          },
          childCount: rowCount,
          findChildIndexCallback: rowIndices == null
              ? null
              : (key) => rowIndices[key],
        ),
      );
    },
  );
}

/// Scroll-native desktop split: both columns share the same scroll offset but
/// only visible primary rows build. The compact breakpoint matches the box
/// DesktopWorkspaceColumns; neither pane owns an extra nested scroll view.
class SliverWorkspaceColumns extends StatelessWidget {
  const SliverWorkspaceColumns({
    required this.primary,
    required this.secondary,
    this.secondaryWidth = 340,
    this.minimumPrimaryWidth = 560,
    this.gap = 24,
    super.key,
  });
  final Widget primary;
  final Widget secondary;
  final double secondaryWidth;
  final double minimumPrimaryWidth;
  final double gap;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final factor = DesktopLayout.workspaceScaleFactor(context);
      final sideWidth = secondaryWidth * factor;
      if (constraints.crossAxisExtent <
          minimumPrimaryWidth * factor + sideWidth + gap) {
        return SliverMainAxisGroup(
          slivers: [
            primary,
            SliverToBoxAdapter(child: SizedBox(height: gap)),
            SliverToBoxAdapter(child: secondary),
          ],
        );
      }
      return SliverCrossAxisGroup(
        slivers: [
          SliverCrossAxisExpanded(flex: 1, sliver: primary),
          SliverConstrainedCrossAxis(
            maxExtent: gap,
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          SliverConstrainedCrossAxis(
            maxExtent: sideWidth,
            sliver: SliverToBoxAdapter(child: secondary),
          ),
        ],
      );
    },
  );
}
