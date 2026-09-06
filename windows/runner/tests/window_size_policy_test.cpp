#include "../window_size_policy.h"

#include <cassert>
#include <iostream>

int main() {
  using namespace window_size_policy;
  for (const unsigned int dpi : {96u, 120u, 144u, 192u, 240u}) {
    const Bounds desktop{0, 0, 7680, 4320};
    const Size frame{ScaleDips(16, dpi), ScaleDips(39, dpi)};
    const auto limits = GetLimits({900, 600}, dpi, frame, desktop);
    assert(limits.minimum.width == ScaleDips(900, dpi) + frame.width);
    assert(limits.minimum.height == ScaleDips(600, dpi) + frame.height);
    const auto initial = FitToWorkArea(
        {10, 10, OuterSize({1280, 720}, dpi, frame).width,
         OuterSize({1280, 720}, dpi, frame).height}, desktop, limits);
    assert(initial.width - frame.width == ScaleDips(1280, dpi));
    assert(initial.height - frame.height == ScaleDips(720, dpi));
    const auto tiny = FitToWorkArea({10, 10, 212, 200}, desktop, limits);
    assert(tiny.width == limits.minimum.width);
    assert(tiny.height == limits.minimum.height);
  }
  // Fractional DPI rounds upward, never below the promised minimum client DIP.
  assert(ScaleDips(1, 120) == 2);
  assert(ScaleDips(901, 120) == 1127);

  // A 4K work area at 200% is the same logical workspace as FHD at 100%.
  // Display pixels must be converted exactly once, without a separate 4K zoom.
  const Bounds fhd_work{0, 0, 1920, 1032};
  const Bounds uhd_work{-3840, 0, 3840, 2064};
  const auto fhd_limits = GetLimits({900, 600}, 96, {16, 39}, fhd_work);
  const auto uhd_limits = GetLimits({900, 600}, 192, {32, 78}, uhd_work);
  assert(uhd_limits.minimum.width == 2 * fhd_limits.minimum.width);
  assert(uhd_limits.minimum.height == 2 * fhd_limits.minimum.height);
  assert(uhd_limits.maximum.width == 2 * fhd_limits.maximum.width);
  assert(uhd_limits.maximum.height == 2 * fhd_limits.maximum.height);

  // At FHD/200% the work area cannot fit 600 client DIPs vertically.
  // Only that axis relaxes; the width minimum remains 900 client DIPs.
  const auto fhd_200 = GetLimits({900, 600}, 192, {32, 78}, fhd_work);
  assert(fhd_200.minimum.width == 1832);
  assert(fhd_200.minimum.height == 1032);

  // Suggested normal bounds when moving among mixed-DPI monitors preserve
  // client DIPs and remain within each destination work area, including a
  // negative-origin monitor. This tests geometry, not real WM_DPICHANGED input.
  for (const unsigned int dpi : {96u, 120u, 144u, 192u}) {
    const Bounds work{-ScaleDips(1920, dpi), -ScaleDips(200, dpi),
                      ScaleDips(1920, dpi), ScaleDips(1032, dpi)};
    const Size frame{ScaleDips(16, dpi), ScaleDips(39, dpi)};
    const auto client = OuterSize({1280, 720}, dpi, frame);
    const auto monitor_limits = GetLimits({900, 600}, dpi, frame, work);
    const auto moved = FitToWorkArea(
        {work.x - 10000, work.y + 10000, client.width, client.height},
        work, monitor_limits);
    assert(moved.width - frame.width == ScaleDips(1280, dpi));
    assert(moved.height - frame.height == ScaleDips(720, dpi));
    assert(moved.x >= work.x && moved.x + moved.width <= work.x + work.width);
    assert(moved.y >= work.y && moved.y + moved.height <= work.y + work.height);
  }

  const Bounds small{0, 0, 800, 560};
  const auto small_limits = GetLimits({900, 600}, 192, {32, 78}, small);
  const auto fitted = FitToWorkArea({100, 100, 2560, 1440}, small, small_limits);
  assert(fitted.x == 0 && fitted.y == 0);
  assert(fitted.width == 800 && fitted.height == 560);
  // One axis can relax without discarding the minimum on the other axis.
  const auto short_limits = GetLimits({900, 600}, 96, {16, 39},
                                     {0, 0, 1920, 500});
  assert(short_limits.minimum.width == 916);
  assert(short_limits.minimum.height == 500);

  const Bounds secondary{-1920, -200, 1920, 1040};
  const auto limits = GetLimits({900, 600}, 96, {16, 39}, secondary);
  const auto restored = FitToWorkArea({3000, -9000, 10, 10}, secondary, limits);
  assert(restored.x == -916 && restored.y == -200);
  assert(restored.width == 916 && restored.height == 639);
  const auto oversized = FitToWorkArea({-8000, -8000, 10000, 10000},
                                       secondary, limits);
  assert(oversized.x == -1920 && oversized.y == -200);
  assert(oversized.width == 1920 && oversized.height == 1040);

  // Snap keeps invisible resize borders outside rcWork, including on negative
  // monitor origins and at high DPI. Its client minimum is not reduced.
  for (const unsigned int dpi : {96u, 144u, 192u}) {
    const int border = ScaleDips(8, dpi);
    const Bounds work{-ScaleDips(1920, dpi), -ScaleDips(200, dpi),
                      ScaleDips(1920, dpi), ScaleDips(1032, dpi)};
    const Size frame{ScaleDips(16, dpi), ScaleDips(39, dpi)};
    const auto snap_limits = GetLimits({900, 600}, dpi, frame, work);
    const Insets invisible{border, 0, border, border};
    const Bounds left{work.x - border, work.y,
                      work.width / 2 + 2 * border, work.height + border};
    const auto snap_left = FitToVisibleWorkArea(left, work, snap_limits, invisible);
    assert(snap_left.x == left.x && snap_left.y == left.y);
    assert(snap_left.width == left.width && snap_left.height == left.height);
    const Bounds right{work.x + work.width / 2 - border, work.y,
                       work.width / 2 + 2 * border, work.height + border};
    const auto snap_right = FitToVisibleWorkArea(right, work, snap_limits, invisible);
    assert(snap_right.x == right.x && snap_right.y == right.y);
    assert(snap_right.width == right.width && snap_right.height == right.height);
    assert(snap_left.width - frame.width >= ScaleDips(900, dpi));
    const auto micro = FitToVisibleWorkArea(
        {work.x - 10000, work.y - 10000, 10, 10}, work, snap_limits, invisible);
    assert(micro.width == snap_limits.minimum.width);
    assert(micro.height == snap_limits.minimum.height);
    assert(micro.x == work.x - border && micro.y == work.y);
    const auto huge = FitToVisibleWorkArea(
        {work.x - 10000, work.y - 10000, 100000, 100000},
        work, snap_limits, invisible);
    assert(huge.x + border == work.x && huge.y == work.y);
    assert(huge.width - 2 * border == work.width);
    assert(huge.height - border == work.height);
  }
  // A too-small physical work area still bounds the entire visible window.
  const auto small_visible = FitToVisibleWorkArea(
      {100, 100, 2560, 1440}, small, small_limits, {16, 0, 16, 16});
  assert(small_visible.x == -16 && small_visible.y == 0);
  assert(small_visible.width == 832 && small_visible.height == 576);
  assert(small_visible.width >= small_limits.minimum.width);
  assert(small_visible.height >= small_limits.minimum.height);

  // Compact windows can opt out; main's 900x600 must not become a global rule.
  const auto compact = GetLimits({0, 0}, 96, {16, 39}, secondary);
  assert(FitToWorkArea({-1000, 0, 320, 180}, secondary, compact).width == 320);
  std::cout << "window_size_policy: all geometry checks passed\n";
  return 0;
}
