import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Full logical bounds, including lazy rows rather than clipped paint extent.
/// Offscreen SliverMainAxisGroup children have clamped paint offsets. Derive
/// their content origin through childScrollOffset/getOffsetToReveal instead.
Rect? scrollContentBounds(RenderObject? render) {
  final double width;
  final double height;
  if (render is RenderBox && render.hasSize) {
    width = render.size.width;
    height = render.size.height;
  } else if (render is RenderSliver && render.geometry != null) {
    width = render.constraints.crossAxisExtent;
    height = render.geometry!.scrollExtent;
  } else {
    return null;
  }
  final origin = MatrixUtils.transformPoint(
    render!.getTransformTo(null),
    Offset.zero,
  );
  final viewport = RenderAbstractViewport.maybeOf(render);
  if (viewport is RenderViewportBase &&
      axisDirectionToAxis(viewport.axisDirection) == Axis.vertical) {
    final revealed = viewport.getOffsetToReveal(render, 0);
    final viewportOrigin = viewport.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      origin.dx,
      viewportOrigin.dy + revealed.offset - viewport.offset.pixels,
      width,
      height,
    );
  }
  return Rect.fromLTWH(origin.dx, origin.dy, width, height);
}

Rect scrollContentRect(WidgetTester tester, Finder finder) =>
    scrollContentBounds(tester.element(finder).findRenderObject())!;
