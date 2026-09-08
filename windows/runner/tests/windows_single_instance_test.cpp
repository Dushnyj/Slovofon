// Native Win32 fixture, deliberately isolated from Slovofon's identity/data.
// Compile with windows_single_instance.cpp and user32/advapi32/shell32.
#include "../windows_single_instance.h"

#include <shellapi.h>

#include <cassert>
#include <iostream>
#include <string>
#include <vector>

using windows_activation::Arguments;
using windows_activation::SingleInstance;

namespace {
constexpr int kPrimary = 10;
constexpr int kActivated = 11;
constexpr int kUnavailable = 12;
constexpr wchar_t kFixtureClass[] = L"SlovofonSingleInstanceTestOnly";

struct Fixture {
  SingleInstance* instance;
  int deliveries = 0;
  Arguments arguments;
};

LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    SetWindowLongPtrW(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  }
  auto* fixture = reinterpret_cast<Fixture*>(GetWindowLongPtrW(window, GWLP_USERDATA));
  if (message == WM_COPYDATA && fixture) {
    const auto* data = reinterpret_cast<COPYDATASTRUCT*>(lparam);
    if (!data || data->dwData != windows_activation::kCopyDataTag ||
        !fixture->instance->IsValidSender(reinterpret_cast<HWND>(wparam))) return FALSE;
    const auto args = windows_activation::Decode(data->lpData, data->cbData);
    if (!args) return FALSE;
    fixture->arguments = *args;
    fixture->deliveries++;
    SingleInstance::RestoreAndActivate(window);
    return TRUE;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

std::wstring ExePath() {
  std::vector<wchar_t> path(32768);
  const DWORD size = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  assert(size && size < path.size());
  return std::wstring(path.data(), size);
}

HANDLE Child(const std::wstring& mode, const std::wstring& scope) {
  auto command = L"\"" + ExePath() + L"\" " + mode + L" \"" + scope + L"\"";
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION process{};
  assert(CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE,
                        CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process));
  CloseHandle(process.hThread);
  return process.hProcess;
}

DWORD AwaitChild(HANDLE child) {
  const auto deadline = GetTickCount64() + 15000;
  while (WaitForSingleObject(child, 0) == WAIT_TIMEOUT) {
    MSG message;
    while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
      TranslateMessage(&message);
      DispatchMessageW(&message);
    }
    assert(GetTickCount64() < deadline);
    Sleep(5);
  }
  DWORD code = 0;
  assert(GetExitCodeProcess(child, &code));
  CloseHandle(child);
  return code;
}

HWND CreateFixtureWindow(Fixture* fixture) {
  auto window = CreateWindowExW(WS_EX_TOOLWINDOW, kFixtureClass,
      L"Slovofon isolated single-instance test", WS_OVERLAPPEDWINDOW,
      100, 100, 480, 260, nullptr, nullptr, GetModuleHandleW(nullptr), fixture);
  assert(window);
  return window;
}

int Secondary(const std::wstring& scope, DWORD timeout) {
  SingleInstance instance(scope);
  const auto result = instance.AcquireOrActivate(
      {u8"slovofon://book?source=izib&book=Белые%20ночи", "--not-executed"}, timeout);
  if (result == SingleInstance::Result::kPrimary) return kPrimary;
  if (result == SingleInstance::Result::kActivated) return kActivated;
  return kUnavailable;
}
}  // namespace

int main() {
  int argc = 0;
  wchar_t** argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  assert(argv);
  if (argc == 3) {
    const std::wstring mode(argv[1]);
    const std::wstring scope(argv[2]);
    LocalFree(argv);
    if (mode == L"--secondary") return Secondary(scope, 10000);
    if (mode == L"--timeout") return Secondary(scope, 150);
    if (mode == L"--abandon") {
      // ExitProcess intentionally skips C++ RAII in this isolated child only.
      auto* owner = new SingleInstance(scope);
      assert(owner->AcquireOrActivate({}) == SingleInstance::Result::kPrimary);
      HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, (scope + L".Ready").c_str());
      HANDLE leave = OpenEventW(SYNCHRONIZE, FALSE, (scope + L".Leave").c_str());
      assert(ready && leave && SetEvent(ready));
      assert(WaitForSingleObject(leave, 10000) == WAIT_OBJECT_0);
      ExitProcess(kPrimary);
    }
    return 99;
  }
  LocalFree(argv);
  WNDCLASSW window_class{};
  window_class.lpfnWndProc = WindowProc;
  window_class.hInstance = GetModuleHandleW(nullptr);
  window_class.lpszClassName = kFixtureClass;
  assert(RegisterClassW(&window_class));
  const auto scope = L"Slovofon.Test.SingleInstance." + std::to_wstring(GetCurrentProcessId());

  {
    SingleInstance owner(scope);
    assert(owner.AcquireOrActivate({}) == SingleInstance::Result::kPrimary);
    Fixture fixture{&owner, 0, {}};
    HWND window = CreateFixtureWindow(&fixture);
    // Duplicate during early startup waits, without another primary/engine.
    HANDLE early = Child(L"--secondary", scope);
    Sleep(200);
    assert(WaitForSingleObject(early, 0) == WAIT_TIMEOUT);
    assert(owner.AttachWindow(window));
    assert(AwaitChild(early) == kActivated);
    assert(fixture.deliveries == 1 && fixture.arguments.size() == 2);
    assert(fixture.arguments[0] == u8"slovofon://book?source=izib&book=Белые%20ночи");
    assert(fixture.arguments[1] == "--not-executed");
    assert(IsWindowVisible(window));

    ShowWindow(window, SW_MINIMIZE);
    assert(AwaitChild(Child(L"--secondary", scope)) == kActivated);
    assert(IsWindowVisible(window) && !IsIconic(window));
    ShowWindow(window, SW_HIDE);
    assert(AwaitChild(Child(L"--secondary", scope)) == kActivated);
    assert(IsWindowVisible(window));
    ShowWindow(window, SW_MAXIMIZE);
    assert(AwaitChild(Child(L"--secondary", scope)) == kActivated);
    assert(IsZoomed(window));

    std::vector<HANDLE> children;
    for (int i = 0; i < 6; ++i) children.push_back(Child(L"--secondary", scope));
    for (HANDLE child : children) assert(AwaitChild(child) == kActivated);
    assert(fixture.deliveries == 10);
    assert(!owner.IsValidSender(nullptr));
    assert(!owner.IsValidSender(window));  // Same-process spoof is not a launch.
    owner.DetachWindow();
    DestroyWindow(window);
    assert(AwaitChild(Child(L"--timeout", scope)) == kUnavailable);
  }
  // A normal owner exit releases the mutex; a new process may become primary.
  assert(AwaitChild(Child(L"--secondary", scope)) == kPrimary);
  // Keep the named object alive across abrupt owner death to exercise the
  // WAIT_ABANDONED path, not merely creation of a fresh mutex after process exit.
  HANDLE ready = CreateEventW(nullptr, TRUE, FALSE, (scope + L".Ready").c_str());
  HANDLE leave = CreateEventW(nullptr, TRUE, FALSE, (scope + L".Leave").c_str());
  assert(ready && leave);
  HANDLE crash_owner = Child(L"--abandon", scope);
  assert(WaitForSingleObject(ready, 10000) == WAIT_OBJECT_0);
  {
    SingleInstance waiter(scope);
    assert(waiter.AcquireOrActivate({}, 50) == SingleInstance::Result::kUnavailable);
    assert(SetEvent(leave));
    assert(AwaitChild(crash_owner) == kPrimary);
    assert(AwaitChild(Child(L"--secondary", scope)) == kPrimary);
  }
  CloseHandle(ready);
  CloseHandle(leave);
  UnregisterClassW(kFixtureClass, GetModuleHandleW(nullptr));
  std::cout << "Win32 single-instance early-start, repeated launch, hidden/minimized/"
               "maximized restore, burst, timeout and restart: PASS\n";
}
