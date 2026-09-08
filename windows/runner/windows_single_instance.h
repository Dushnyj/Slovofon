#ifndef RUNNER_WINDOWS_SINGLE_INSTANCE_H_
#define RUNNER_WINDOWS_SINGLE_INSTANCE_H_

#include <windows.h>

#include <string>

#include "windows_activation.h"

namespace windows_activation {

// One owner per Windows user and logon session, independent of install path or
// version. Construct before the Flutter project; destroy after the HWND/engine.
class SingleInstance {
 public:
  enum class Result { kPrimary, kActivated, kUnavailable };
  explicit SingleInstance(const std::wstring& application_id = L"Slovofon.App");
  ~SingleInstance();
  SingleInstance(const SingleInstance&) = delete;
  SingleInstance& operator=(const SingleInstance&) = delete;

  Result AcquireOrActivate(const Arguments& arguments, DWORD timeout_ms = 10000);
  bool AttachWindow(HWND window);
  void DetachWindow();
  bool IsValidSender(HWND sender) const;
  static void RestoreAndActivate(HWND window);

 private:
  HWND FindPrimaryWindow() const;
  bool SameUserAndSession(DWORD process_id) const;
  std::wstring user_sid_;
  std::wstring mutex_name_;
  std::wstring window_property_;
  DWORD session_id_ = 0;
  HANDLE mutex_ = nullptr;
  bool owns_mutex_ = false;
  HWND window_ = nullptr;
};

}  // namespace windows_activation

#endif  // RUNNER_WINDOWS_SINGLE_INSTANCE_H_
