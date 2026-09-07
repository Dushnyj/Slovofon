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
