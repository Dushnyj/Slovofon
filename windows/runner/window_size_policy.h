#ifndef RUNNER_WINDOW_SIZE_POLICY_H_
#define RUNNER_WINDOW_SIZE_POLICY_H_

#include <algorithm>
#include <cstdint>
#include <limits>

// Pure geometry: DIPs describe the client, while Win32 sizing messages use the
// outer rectangle in physical pixels. No monitor, application data or UI state
// is read here, so this policy can also be tested without starting Flutter.
namespace window_size_policy {

struct Size {
  int width;
  int height;
};

struct Bounds {
  int x;
  int y;
  int width;
  int height;
};

struct Limits {
  Size minimum;
  Size maximum;
};

struct Insets {
  int left;
  int top;
  int right;
  int bottom;
};

inline int ScaleDips(int value, unsigned int dpi) {
  const auto scaled =
      (static_cast<int64_t>(std::max(0, value)) * std::max(1u, dpi) + 95) / 96;
  return static_cast<int>(
      std::min(scaled, static_cast<int64_t>(std::numeric_limits<int>::max())));
}

inline Size OuterSize(Size client_dips, unsigned int dpi, Size frame) {
  const auto add_frame = [](int client, int border) {
    return static_cast<int>(std::min(
        static_cast<int64_t>(client) + std::max(0, border),
        static_cast<int64_t>(std::numeric_limits<int>::max())));
  };
  return {add_frame(ScaleDips(client_dips.width, dpi), frame.width),
          add_frame(ScaleDips(client_dips.height, dpi), frame.height)};
}

inline Limits GetLimits(Size minimum_client_dips, unsigned int dpi, Size frame,
                        const Bounds& work_area) {
  const Size available{std::max(1, work_area.width),
                       std::max(1, work_area.height)};
  const Size requested = OuterSize(minimum_client_dips, dpi, frame);
  // A small/high-DPI display must remain usable: relax each minimum only as
  // much as necessary to keep the complete outer window in its work area.
  return {{std::clamp(requested.width, 1, available.width),
           std::clamp(requested.height, 1, available.height)},
          available};
}

inline Bounds FitToWorkArea(Bounds requested, const Bounds& work_area,
                            const Limits& limits) {
  requested.width =
      std::clamp(requested.width, limits.minimum.width, limits.maximum.width);
  requested.height =
      std::clamp(requested.height, limits.minimum.height, limits.maximum.height);
  requested.x = std::clamp(requested.x, work_area.x,
                           work_area.x + limits.maximum.width - requested.width);
  requested.y = std::clamp(requested.y, work_area.y,
                           work_area.y + limits.maximum.height - requested.height);
  return requested;
}

// A normal snapped window may extend its invisible resize borders outside the
// work area. Fit its visible frame, without relaxing the client-size minimum or
// letting its caption/visible edges escape the screen. Creation stays strict.
inline Bounds FitToVisibleWorkArea(Bounds requested, const Bounds& work_area,
                                   const Limits& limits, Insets invisible) {
  invisible.left = std::max(0, invisible.left);
  invisible.top = std::max(0, invisible.top);
  invisible.right = std::max(0, invisible.right);
  invisible.bottom = std::max(0, invisible.bottom);
  const Bounds available{
      work_area.x - invisible.left, work_area.y - invisible.top,
      limits.maximum.width + invisible.left + invisible.right,
      limits.maximum.height + invisible.top + invisible.bottom};
  return FitToWorkArea(
      requested, available,
      {limits.minimum, {available.width, available.height}});
}

}  // namespace window_size_policy

#endif  // RUNNER_WINDOW_SIZE_POLICY_H_
