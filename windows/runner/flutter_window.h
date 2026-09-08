#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"
#include "windows_close_request.h"
#include "windows_installation_task.h"
#include "windows_single_instance.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  FlutterWindow(const flutter::DartProject& project,
                windows_activation::SingleInstance& single_instance);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void RequestWindowsClose();
  void CancelWindowsClose();
  void StartWindowsInstallationRequest(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void FinishWindowsInstallationRequest(UINT_PTR token, bool timed_out);
  void CancelWindowsInstallationRequest();

  // The project to run.
  flutter::DartProject project_;
  windows_activation::SingleInstance& single_instance_;
  windows_activation::PendingActivations pending_activations_;
  bool activation_listener_ready_ = false;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // Destroy the channel before its engine/binary messenger.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      windows_activation_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      windows_update_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      windows_lifecycle_channel_;
  std::shared_ptr<windows_lifecycle::CloseRequest> windows_close_request_;

  // Only the platform thread owns/replies to MethodResult. Workers retain only
  // the independent shared state, which is deactivated before engine teardown.
  std::shared_ptr<windows_installation::InstallationTask> windows_update_task_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
      windows_update_pending_;
  HWND windows_update_hwnd_ = nullptr;
  UINT_PTR windows_update_token_ = 0;
  ULONGLONG windows_update_deadline_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
