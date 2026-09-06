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
    this.stretchDesktopColumns = false,
    super.key,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double minTileWidth;
  final int maxColumns;

  /// Fill complete Windows rows while retaining the readable minimum width.
  /// Other consumers keep stable card widths unless they explicitly opt in.
  final bool stretchDesktopColumns;

  @override
  Widget build(BuildContext context) {
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

        final calculatedColumns = ((width + spacing) / (minTileWidth + spacing))
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
