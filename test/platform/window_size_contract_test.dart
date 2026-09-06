import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final main = File('windows/runner/main.cpp').readAsStringSync();
  final header = File('windows/runner/win32_window.h').readAsStringSync();
  final runner = File('windows/runner/win32_window.cpp').readAsStringSync();
  final flutter = File('windows/runner/flutter_window.cpp').readAsStringSync();
  final policy = File('windows/runner/window_size_policy.h').readAsStringSync();

  String message(String name, String next) => runner.substring(
    runner.indexOf('case $name:'),
    runner.indexOf('case $next:', runner.indexOf('case $name:')),
  );

  test('main opts into a client DIP minimum before native window creation', () {
    expect(main, contains('SetMinimumClientSize(Win32Window::Size(900, 600))'));
    expect(main, contains('Win32Window::Size size(1280, 720)'));
    expect(
      main.indexOf('SetMinimumClientSize'),
      lessThan(main.indexOf('.Create(')),
    );
    expect(header, contains('Size minimum_client_size_{0, 0}'));
    expect(header, contains('UINT current_dpi_ = 96'));
  });

  test('creation converts client DIPs plus frame on the target work area', () {
    final create = runner.substring(
      runner.indexOf('bool Win32Window::Create('),
      runner.indexOf('bool Win32Window::Show('),
    );
    expect(create, contains('FlutterDesktopGetDpiForMonitor(monitor)'));
    expect(create, contains('NonClientFrame(nullptr, current_dpi_)'));
    expect(create, contains('window_size_policy::OuterSize('));
    expect(create, contains('WorkAreaForMonitor(monitor)'));
    expect(create, contains('window_size_policy::FitToWorkArea('));
    expect(
      create,
      contains('initial.x, initial.y, initial.width, initial.height'),
    );
    expect(create, isNot(contains('Scale(origin.')));
    expect(runner, contains('AdjustWindowRectExForDpi('));
    expect(runner, contains('work = info.rcWork'));
  });

  test('minimum tracking does not override system maximize bounds', () {
    final minmax = message('WM_GETMINMAXINFO', 'WM_WINDOWPOSCHANGING');
    expect(minmax, contains('HasMinimumClientSize()'));
    expect(minmax, contains('window_size_policy::GetLimits('));
    expect(minmax, contains('info->ptMinTrackSize ='));
    expect(minmax, isNot(contains('info->ptMaxSize =')));
    expect(minmax, isNot(contains('info->ptMaxPosition =')));
  });

  test(
    'programmatic resize is constrained without intercepting normal moves',
    () {
      final changing = message('WM_WINDOWPOSCHANGING', 'WM_DESTROY');
      expect(
        changing,
        contains('DefWindowProc(hwnd, message, wparam, lparam)'),
      );
      expect(changing, contains('position->flags & SWP_NOSIZE'));
      expect(changing, contains('IsIconic(hwnd) || IsZoomed(hwnd)'));
      expect(
        changing,
        contains('ConstrainNormalBounds(requested, current_dpi_)'),
      );
      expect(changing, contains('position->cx = bounded.right - bounded.left'));
      expect(changing, contains('position->cy = bounded.bottom - bounded.top'));
    },
  );

  test('restore and NOSENDCHANGING get a guarded final-size safety net', () {
    expect(
      message('WM_SIZE', 'WM_DISPLAYCHANGE'),
      contains('if (wparam == SIZE_RESTORED) EnforceNormalBounds()'),
    );
    final enforce = runner.substring(
      runner.indexOf('void Win32Window::EnforceNormalBounds()'),
    );
    expect(enforce, contains('adjusting_bounds_ ||'));
    expect(
      enforce,
      contains('IsIconic(window_handle_) || IsZoomed(window_handle_)'),
    );
    expect(enforce, contains('if (EqualRect(&current, &bounded)) return'));
    expect(
      enforce.indexOf('adjusting_bounds_ = true'),
      lessThan(enforce.indexOf('SetWindowPos(')),
    );
    expect(enforce, contains('SWP_NOZORDER | SWP_NOACTIVATE'));
    expect(enforce, contains('adjusting_bounds_ = false'));
  });

  test('DPI change uses the new DPI and keeps minimized/maximized states', () {
    final dpi = message('WM_DPICHANGED', 'WM_SIZE');
    expect(dpi, contains('current_dpi_ = LOWORD(wparam)'));
    expect(dpi, contains('if (IsIconic(hwnd)) return 0'));
    expect(dpi, contains('HasMinimumClientSize() && !IsZoomed(hwnd)'));
    expect(dpi, contains('ConstrainNormalBounds(*suggested, current_dpi_)'));
    expect(
      dpi.indexOf('current_dpi_ = LOWORD'),
      lessThan(dpi.indexOf('ConstrainNormalBounds(')),
    );
    expect(dpi, contains('SWP_NOZORDER | SWP_NOACTIVATE'));
    expect(
      File('windows/runner/runner.exe.manifest').readAsStringSync(),
      contains('PerMonitorV2'),
    );
  });

  test('display and work-area changes recheck only normal bounds', () {
    expect(
      message('WM_DISPLAYCHANGE', 'WM_SETTINGCHANGE'),
      contains('EnforceNormalBounds()'),
    );
    expect(
      message('WM_SETTINGCHANGE', 'WM_ACTIVATE'),
      contains('if (wparam == SPI_SETWORKAREA) EnforceNormalBounds()'),
    );
  });

  test('plugin handling cannot bypass native sizing messages', () {
    for (final name in [
      'WM_GETMINMAXINFO',
      'WM_WINDOWPOSCHANGING',
      'WM_WINDOWPOSCHANGED',
      'WM_DPICHANGED',
      'WM_SIZE',
      'WM_DISPLAYCHANGE',
    ]) {
      expect(flutter, contains('message == $name'));
    }
    expect(flutter, contains('if (result && !sizing_message)'));
  });

  test('early system font changes do not dereference an uncreated engine', () {
    final fonts = flutter.substring(flutter.indexOf('case WM_FONTCHANGE:'));
    expect(
      fonts,
      contains('if (flutter_controller_ && flutter_controller_->engine())'),
    );
    expect(
      fonts.indexOf('if (flutter_controller_'),
      lessThan(fonts.indexOf('ReloadSystemFonts()')),
    );
  });

  test('normal snap fit allows only bounded invisible resize borders', () {
    final constrain = runner.substring(
      runner.indexOf('RECT Win32Window::ConstrainNormalBounds('),
      runner.indexOf('void Win32Window::EnforceNormalBounds()'),
    );
    expect(constrain, contains('window_size_policy::FitToVisibleWorkArea('));
    expect(constrain, contains('InvisibleResizeInsets(window_handle_, dpi)'));
    expect(runner, contains('DWMWA_EXTENDED_FRAME_BOUNDS'));
    expect(runner, contains('GetDpiForWindow(hwnd) != dpi'));
    expect(runner, contains('actual.left < 0'));
    expect(runner, contains('actual.right > horizontal'));
    expect(
      policy,
      contains('{limits.minimum, {available.width, available.height}}'),
    );
    final helper = File(
      'tools/windows/Test-WindowSizing.ps1',
    ).readAsStringSync();
    expect(helper, contains('SetThreadDpiAwarenessContext([IntPtr]::new(-4))'));
    expect(
      helper,
      contains('SetThreadDpiAwarenessContext(\$previousDpiContext)'),
    );
  });

  test(
    'geometry policy supports small screens and signed monitor positions',
    () {
      expect(
        policy,
        contains('std::clamp(requested.width, 1, available.width)'),
      );
      expect(
        policy,
        contains('std::clamp(requested.height, 1, available.height)'),
      );
      expect(header, contains('Point(int x, int y)'));
      final nativeTests = File(
        'windows/runner/tests/window_size_policy_test.cpp',
      ).readAsStringSync();
      expect(nativeTests, contains('{96u, 120u, 144u, 192u, 240u}'));
      expect(nativeTests, contains('GetLimits({0, 0}'));
      expect(nativeTests, contains('Bounds secondary{-1920, -200'));
    },
  );
}
