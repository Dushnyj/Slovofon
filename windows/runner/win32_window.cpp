#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"
#include "window_size_policy.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

window_size_policy::Bounds WorkAreaForMonitor(HMONITOR monitor) {
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  RECT work{};
  if (GetMonitorInfo(monitor, &info)) {
    work = info.rcWork;
  } else if (!SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0)) {
    work = {0, 0, GetSystemMetrics(SM_CXSCREEN),
            GetSystemMetrics(SM_CYSCREEN)};
  }
  return {work.left, work.top, work.right - work.left, work.bottom - work.top};
}

window_size_policy::Bounds WorkAreaForRect(const RECT& rect) {
  return WorkAreaForMonitor(MonitorFromRect(&rect, MONITOR_DEFAULTTONEAREST));
}

window_size_policy::Size NonClientFrame(HWND hwnd, UINT dpi) {
  // Use the restored frame even while Windows asks about tracking limits of a
  // minimized/maximized window. The minimum always describes normal client DIPs.
  const DWORD style = hwnd
      ? static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_STYLE)) &
            ~(WS_MAXIMIZE | WS_MINIMIZE)
      : WS_OVERLAPPEDWINDOW;
  const DWORD ex_style =
      hwnd ? static_cast<DWORD>(GetWindowLongPtr(hwnd, GWL_EXSTYLE)) : 0;
  RECT frame{};
  if (!AdjustWindowRectExForDpi(&frame, style, hwnd && GetMenu(hwnd), ex_style,
                               dpi)) {
    AdjustWindowRectEx(&frame, style, hwnd && GetMenu(hwnd), ex_style);
  }
  return {frame.right - frame.left, frame.bottom - frame.top};
}

window_size_policy::Insets InvisibleResizeInsets(HWND hwnd, UINT dpi) {
  if (!hwnd || !(GetWindowLongPtr(hwnd, GWL_STYLE) & WS_THICKFRAME)) {
    return {0, 0, 0, 0};
  }
  const int padding = GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
  const int horizontal =
      std::max(0, GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) + padding);
  const int vertical =
      std::max(0, GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi) + padding);
  // During creation/DPI transitions DWM may still describe the old frame.
  // The fallback never allows the caption's top edge outside the work area.
  const window_size_policy::Insets fallback{horizontal, 0, horizontal, vertical};
  if (IsIconic(hwnd) || IsZoomed(hwnd) || GetDpiForWindow(hwnd) != dpi) {
    return fallback;
  }
  RECT outer{}, visible{};
  if (!GetWindowRect(hwnd, &outer) ||
      FAILED(DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, &visible,
                                   sizeof(visible)))) {
    return fallback;
  }
  const window_size_policy::Insets actual{
      visible.left - outer.left, visible.top - outer.top,
      outer.right - visible.right, outer.bottom - visible.bottom};
  // Reject stale/animation bounds rather than treating an arbitrary difference
  // as an invisible border. All permitted overflow is bounded by frame metrics.
  if (actual.left < 0 || actual.top < 0 || actual.right < 0 || actual.bottom < 0 ||
      actual.left > horizontal || actual.right > horizontal ||
      actual.top > vertical || actual.bottom > vertical) {
    return fallback;
  }
  return actual;
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  current_dpi_ = FlutterDesktopGetDpiForMonitor(monitor);
  if (current_dpi_ == 0) current_dpi_ = 96;
  const auto frame = NonClientFrame(nullptr, current_dpi_);
  const auto outer = window_size_policy::OuterSize(
      {static_cast<int>(size.width), static_cast<int>(size.height)},
      current_dpi_, frame);
  const auto work = WorkAreaForMonitor(monitor);
  const auto limits = window_size_policy::GetLimits(
      {static_cast<int>(minimum_client_size_.width),
       static_cast<int>(minimum_client_size_.height)}, current_dpi_, frame, work);
  const auto initial = window_size_policy::FitToWorkArea(
      {origin.x, origin.y, outer.width, outer.height}, work, limits);

  HWND window = CreateWindow(
      window_class, title.c_str(), WS_OVERLAPPEDWINDOW,
      initial.x, initial.y, initial.width, initial.height,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_GETMINMAXINFO: {
      // Preserve the OS maximize/snap policy, changing only minimum tracking.
      const LRESULT result = DefWindowProc(hwnd, message, wparam, lparam);
      if (HasMinimumClientSize()) {
        RECT window_rect{};
        GetWindowRect(hwnd, &window_rect);
        const auto work = WorkAreaForRect(window_rect);
        const auto limits = window_size_policy::GetLimits(
            {static_cast<int>(minimum_client_size_.width),
             static_cast<int>(minimum_client_size_.height)},
            current_dpi_, NonClientFrame(hwnd, current_dpi_), work);
        auto info = reinterpret_cast<MINMAXINFO*>(lparam);
        info->ptMinTrackSize = {limits.minimum.width, limits.minimum.height};
      }
      return result;
    }

    case WM_WINDOWPOSCHANGING: {
      // DefWindowProc also consults WM_GETMINMAXINFO. The explicit normal-size
      // guard covers MoveWindow/SetWindowPos/restore, not just border dragging.
      const LRESULT result = DefWindowProc(hwnd, message, wparam, lparam);
      auto position = reinterpret_cast<WINDOWPOS*>(lparam);
      if (!HasMinimumClientSize() || IsIconic(hwnd) || IsZoomed(hwnd) ||
          (position->flags & SWP_NOSIZE)) {
        return result;
      }
      RECT current{};
      GetWindowRect(hwnd, &current);
      const int x = (position->flags & SWP_NOMOVE) ? current.left : position->x;
      const int y = (position->flags & SWP_NOMOVE) ? current.top : position->y;
      const RECT requested{x, y, x + position->cx, y + position->cy};
      const RECT bounded = ConstrainNormalBounds(requested, current_dpi_);
      position->cx = bounded.right - bounded.left;
      position->cy = bounded.bottom - bounded.top;
      if (bounded.left != x || bounded.top != y) {
        position->flags &= ~SWP_NOMOVE;
        position->x = bounded.left;
        position->y = bounded.top;
      }
      return result;
    }

    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      current_dpi_ = LOWORD(wparam);
      if (current_dpi_ == 0) current_dpi_ = 96;
      // Never restore or activate a background/minimized window on DPI change.
      if (IsIconic(hwnd)) return 0;
      const auto suggested = reinterpret_cast<RECT*>(lparam);
      const RECT next = HasMinimumClientSize() && !IsZoomed(hwnd)
          ? ConstrainNormalBounds(*suggested, current_dpi_)
          : *suggested;
      SetWindowPos(hwnd, nullptr, next.left, next.top, next.right - next.left,
                   next.bottom - next.top, SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }
    case WM_SIZE: {
      // Also handles callers using SWP_NOSENDCHANGING and restores whose old
      // iconic/maximized style was still set during WM_WINDOWPOSCHANGING.
      if (wparam == SIZE_RESTORED) EnforceNormalBounds();
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_DISPLAYCHANGE:
      EnforceNormalBounds();
      break;

    case WM_SETTINGCHANGE:
      if (wparam == SPI_SETWORKAREA) EnforceNormalBounds();
      break;

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

void Win32Window::SetMinimumClientSize(const Size& size) {
  minimum_client_size_ = size;
  EnforceNormalBounds();
}

bool Win32Window::HasMinimumClientSize() const {
  return minimum_client_size_.width > 0 || minimum_client_size_.height > 0;
}

RECT Win32Window::ConstrainNormalBounds(const RECT& requested, UINT dpi) const {
  const auto work = WorkAreaForRect(requested);
  const auto limits = window_size_policy::GetLimits(
      {static_cast<int>(minimum_client_size_.width),
       static_cast<int>(minimum_client_size_.height)},
      dpi, NonClientFrame(window_handle_, dpi), work);
  const auto bounded = window_size_policy::FitToVisibleWorkArea(
      {requested.left, requested.top, requested.right - requested.left,
       requested.bottom - requested.top}, work, limits,
      InvisibleResizeInsets(window_handle_, dpi));
  return {bounded.x, bounded.y, bounded.x + bounded.width,
          bounded.y + bounded.height};
}

void Win32Window::EnforceNormalBounds() {
  if (!window_handle_ || !HasMinimumClientSize() || adjusting_bounds_ ||
      IsIconic(window_handle_) || IsZoomed(window_handle_)) {
    return;
  }
  RECT current{};
  if (!GetWindowRect(window_handle_, &current)) return;
  const RECT bounded = ConstrainNormalBounds(current, current_dpi_);
  if (EqualRect(&current, &bounded)) return;
  adjusting_bounds_ = true;
  SetWindowPos(window_handle_, nullptr, bounded.left, bounded.top,
               bounded.right - bounded.left, bounded.bottom - bounded.top,
               SWP_NOZORDER | SWP_NOACTIVATE);
  adjusting_bounds_ = false;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
