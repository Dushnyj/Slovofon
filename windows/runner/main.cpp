#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "utils.h"
#include "windows_single_instance.h"

namespace {

// Declared before the Flutter project/window so COM outlives their destructors,
// including a framework-requested exit that posts WM_QUIT without WM_DESTROY.
class ScopedComApartment {
 public:
  ScopedComApartment()
      : result_(::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED)) {}
  ~ScopedComApartment() {
    if (SUCCEEDED(result_)) ::CoUninitialize();
  }
  ScopedComApartment(const ScopedComApartment&) = delete;
  ScopedComApartment& operator=(const ScopedComApartment&) = delete;

 private:
  const HRESULT result_;
};

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Claim the user/session before creating COM, Flutter, audio or the database.
  // A repeated shortcut only activates the existing workspace and exits.
  windows_activation::SingleInstance single_instance;
  const auto instance_result =
      single_instance.AcquireOrActivate(GetCommandLineArguments());
  if (instance_result != windows_activation::SingleInstance::Result::kPrimary) {
    return instance_result == windows_activation::SingleInstance::Result::kActivated
        ? EXIT_SUCCESS : EXIT_FAILURE;
  }
  SetCurrentProcessExplicitAppUserModelID(L"Slovofon.App");
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ScopedComApartment com_apartment;

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, single_instance);
  // Main workspace only; independent compact windows can keep their own policy.
  window.SetMinimumClientSize(Win32Window::Size(900, 600));
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Slovofon", origin, size)) {
    return EXIT_FAILURE;
  }
  if (!single_instance.AttachWindow(window.GetHandle())) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  return EXIT_SUCCESS;
}
