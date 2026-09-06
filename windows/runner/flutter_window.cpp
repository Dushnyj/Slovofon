#include "flutter_window.h"

#include <process.h>

#include <atomic>
#include <new>
#include <optional>
#include <utility>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"
#include "windows_installation_info.h"

namespace {

constexpr UINT kWindowsInstallationCompleted = WM_APP + 0x530;
constexpr UINT kWindowsInstallationTimeoutMs = 5000;
// High, process-wide tokens avoid ordinary plugin timer IDs and stale replies
// after HWND reuse. The message carries only this number, never a heap pointer.
std::atomic<UINT_PTR> next_windows_installation_token{0x53000000};

struct InstallationWorkerContext {
  std::shared_ptr<windows_installation::InstallationTask> task;
  UINT_PTR token;
};

unsigned __stdcall ReadInstallationOnWorker(void* raw_context) noexcept {
  std::unique_ptr<InstallationWorkerContext> context(
      static_cast<InstallationWorkerContext*>(raw_context));
  windows_installation::InstallationInfo info;
  try {
    // All registry, MSI and filesystem work stays outside the platform thread
    // and outside the state mutex. The same worker enumerates every MSI entry.
    info = windows_installation::ReadInstallationInfo();
  } catch (...) {
    info = {};
  }
  context->task->Complete(context->token, std::move(info));
  return 0;
}

flutter::EncodableValue InstallationInfoValue(
    const windows_installation::InstallationInfo& info) {
  const auto directory = Utf8FromUtf16(info.directory.c_str());
  const auto kind = directory.empty() ? windows_installation::Kind::kUnknown
                                     : info.classification.kind;
  flutter::EncodableMap value{
      {flutter::EncodableValue("kind"),
       flutter::EncodableValue(windows_installation::KindName(kind))},
      {flutter::EncodableValue("directory"), flutter::EncodableValue(directory)},
      {flutter::EncodableValue("systemDirectory"),
       flutter::EncodableValue(Utf8FromUtf16(info.system_directory.c_str()))},
      {flutter::EncodableValue("windowsDirectory"),
       flutter::EncodableValue(Utf8FromUtf16(info.windows_directory.c_str()))},
  };
  if (kind == windows_installation::Kind::kSetup) {
    value[flutter::EncodableValue("scope")] = flutter::EncodableValue(
        info.classification.scope == windows_installation::Scope::kUser
            ? "user" : "machine");
  }
  return flutter::EncodableValue(value);
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  CancelWindowsInstallationRequest();
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  windows_update_hwnd_ = GetHandle();
  windows_update_task_ =
      std::make_shared<windows_installation::InstallationTask>(
          [hwnd = windows_update_hwnd_](
              windows_installation::InstallationTask::Token token) {
            return PostMessageW(hwnd, kWindowsInstallationCompleted,
                                static_cast<WPARAM>(token), 0) != FALSE;
          });
  windows_update_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "com.slovofon.app/windows_update",
          &flutter::StandardMethodCodec::GetInstance());
  windows_update_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getInstallationInfo") {
          StartWindowsInstallationRequest(std::move(result));
        } else {
          result->NotImplemented();
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  CancelWindowsInstallationRequest();
  windows_update_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::StartWindowsInstallationRequest(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!windows_update_task_ || !windows_update_hwnd_ || windows_update_pending_) {
    result->Success(InstallationInfoValue({}));
    return;
  }
  const auto token =
      next_windows_installation_token.fetch_add(1, std::memory_order_relaxed);
  if (!windows_update_task_->Start(token)) {
    result->Success(InstallationInfoValue({}));
    return;
  }
  // A native timer makes timeout independent of Dart scheduling and of a
  // blocked WinAPI worker. Never start I/O unless the fallback timer exists.
  if (SetTimer(windows_update_hwnd_, token, kWindowsInstallationTimeoutMs,
               nullptr) == 0) {
    windows_update_task_->StartFailed(token);
    result->Success(InstallationInfoValue({}));
    return;
  }
  windows_update_pending_ = std::move(result);
  windows_update_token_ = token;
  windows_update_deadline_ = GetTickCount64() + kWindowsInstallationTimeoutMs;
  auto* context = new (std::nothrow) InstallationWorkerContext{
      windows_update_task_, token};
  const auto worker = context == nullptr ? 0 :
      _beginthreadex(nullptr, 0, ReadInstallationOnWorker, context, 0, nullptr);
  if (worker == 0) {
    delete context;
    windows_update_task_->StartFailed(token);
    FinishWindowsInstallationRequest(token, true);
    return;
  }
  // The worker owns context now; no join on timeout or window destruction.
  CloseHandle(reinterpret_cast<HANDLE>(worker));
}

void FlutterWindow::FinishWindowsInstallationRequest(UINT_PTR token,
                                                    bool timed_out) {
  if (token == 0 || token != windows_update_token_ ||
      !windows_update_pending_ || !windows_update_task_) {
    return;
  }
  std::optional<windows_installation::InstallationInfo> info;
  if (timed_out || GetTickCount64() >= windows_update_deadline_) {
    windows_update_task_->Expire(token);
  } else {
    info = windows_update_task_->TakeCompleted(token);
    // Ignore spurious/stale messages without consuming the actual deadline.
    if (!info) return;
  }
  KillTimer(windows_update_hwnd_, token);
  windows_update_token_ = 0;
  windows_update_deadline_ = 0;
  auto result = std::move(windows_update_pending_);
  result->Success(InstallationInfoValue(
      info ? *info : windows_installation::InstallationInfo{}));
}

void FlutterWindow::CancelWindowsInstallationRequest() {
  // Deactivation and the worker's PostMessage use the same short lock. Late
  // workers retain no FlutterWindow/MethodResult/messenger pointer to touch.
  if (windows_update_task_) windows_update_task_->Deactivate();
  if (windows_update_token_ != 0 && windows_update_hwnd_) {
    KillTimer(windows_update_hwnd_, windows_update_token_);
  }
  windows_update_hwnd_ = nullptr;
  windows_update_token_ = 0;
  windows_update_deadline_ = 0;
  auto result = std::move(windows_update_pending_);
  if (result) result->Success(InstallationInfoValue({}));
  windows_update_task_.reset();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Owned completion messages and timers must not be swallowed by plugins.
  if (message == kWindowsInstallationCompleted) {
    FinishWindowsInstallationRequest(static_cast<UINT_PTR>(wparam), false);
    return 0;
  }
  if (message == WM_TIMER && windows_update_token_ != 0 &&
      wparam == windows_update_token_) {
    FinishWindowsInstallationRequest(static_cast<UINT_PTR>(wparam), true);
    return 0;
  }
  if (message == WM_DESTROY) {
    // Win32Window clears GetHandle() before OnDestroy; deactivate while this
    // HWND is still valid, also if a plugin consumes WM_DESTROY afterward.
    CancelWindowsInstallationRequest();
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    // Plugins still receive these messages, but cannot bypass the main native
    // window's sizing policy or prevent the normal WM_SIZE/WM_MOVE dispatch.
    const bool sizing_message = message == WM_GETMINMAXINFO ||
        message == WM_WINDOWPOSCHANGING || message == WM_WINDOWPOSCHANGED ||
        message == WM_DPICHANGED || message == WM_SIZE ||
        message == WM_DISPLAYCHANGE ||
        (message == WM_SETTINGCHANGE && wparam == SPI_SETWORKAREA);
    if (result && !sizing_message) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
