#include "windows_single_instance.h"

#include <sddl.h>

#include <algorithm>
#include <vector>

namespace windows_activation {
namespace {

std::wstring UserSid(HANDLE process) {
  HANDLE token = nullptr;
  if (!OpenProcessToken(process, TOKEN_QUERY, &token)) return {};
  DWORD bytes = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &bytes);
  std::vector<uint8_t> buffer(bytes);
  const bool read = bytes > 0 &&
      GetTokenInformation(token, TokenUser, buffer.data(), bytes, &bytes);
  CloseHandle(token);
  if (!read) return {};
  auto* user = reinterpret_cast<TOKEN_USER*>(buffer.data());
  wchar_t* sid = nullptr;
  if (!ConvertSidToStringSidW(user->User.Sid, &sid)) return {};
  const std::wstring result(sid);
  LocalFree(sid);
  return result;
}

HWND CreateSenderWindow() {
  // A sender HWND lets the receiver verify user/session without trusting a PID
  // supplied inside the payload. It is message-only and never shown.
  return CreateWindowExW(0, L"STATIC", L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                         nullptr, GetModuleHandleW(nullptr), nullptr);
}

}  // namespace

SingleInstance::SingleInstance(const std::wstring& application_id) {
  user_sid_ = UserSid(GetCurrentProcess());
  if (user_sid_.empty() ||
      !ProcessIdToSessionId(GetCurrentProcessId(), &session_id_)) return;
  mutex_name_ = L"Local\\" + application_id + L".Instance." + user_sid_;
  window_property_ = application_id + L".InstanceWindow." + user_sid_;
}

SingleInstance::~SingleInstance() {
  DetachWindow();
  if (owns_mutex_) ReleaseMutex(mutex_);
  if (mutex_) CloseHandle(mutex_);
}

SingleInstance::Result SingleInstance::AcquireOrActivate(
    const Arguments& arguments, DWORD timeout_ms) {
  if (mutex_ || mutex_name_.empty()) return Result::kUnavailable;
  const auto packet = Encode(arguments);
  if (!packet) return Result::kUnavailable;
  // Keep access private to the current user and SYSTEM. The Local namespace
  // prevents cross-session interference; no handles are inherited by children.
  const auto sddl = L"D:P(A;;GA;;;SY)(A;;GA;;;" + user_sid_ + L")";
  PSECURITY_DESCRIPTOR descriptor = nullptr;
  if (!ConvertStringSecurityDescriptorToSecurityDescriptorW(
          sddl.c_str(), SDDL_REVISION_1, &descriptor, nullptr)) {
    return Result::kUnavailable;
  }
  SECURITY_ATTRIBUTES attributes{sizeof(SECURITY_ATTRIBUTES), descriptor, FALSE};
  mutex_ = CreateMutexExW(&attributes, mutex_name_.c_str(), 0,
                          SYNCHRONIZE | MUTEX_MODIFY_STATE);
  LocalFree(descriptor);
  if (!mutex_) return Result::kUnavailable;

  const ULONGLONG deadline = GetTickCount64() + timeout_ms;
  HWND sender = nullptr;
  Result result = Result::kUnavailable;
  do {
    const DWORD wait = WaitForSingleObject(mutex_, 0);
    if (wait == WAIT_OBJECT_0 || wait == WAIT_ABANDONED) {
      owns_mutex_ = true;
      result = Result::kPrimary;
      break;
    }
    if (wait != WAIT_TIMEOUT) break;
    const HWND primary = FindPrimaryWindow();
    if (primary) {
      if (!sender) sender = CreateSenderWindow();
      if (!sender) break;
      DWORD process_id = 0;
      GetWindowThreadProcessId(primary, &process_id);
      AllowSetForegroundWindow(process_id);
      COPYDATASTRUCT data{static_cast<ULONG_PTR>(kCopyDataTag),
                          static_cast<DWORD>(packet->size()),
                          const_cast<uint8_t*>(packet->data())};
      DWORD_PTR accepted = 0;
      const auto remaining = deadline > GetTickCount64()
          ? deadline - GetTickCount64() : 1;
      const auto timeout = static_cast<UINT>(std::min<ULONGLONG>(remaining, 1000));
      // One delivery attempt: retrying an uncertain timeout could open a link
      // twice. Never create another engine when the owner is busy/hung.
      if (SendMessageTimeoutW(primary, WM_COPYDATA,
                              reinterpret_cast<WPARAM>(sender),
                              reinterpret_cast<LPARAM>(&data),
                              SMTO_ABORTIFHUNG | SMTO_BLOCK | SMTO_ERRORONEXIT,
                              timeout, &accepted) && accepted == TRUE) {
        result = Result::kActivated;
      }
      break;
    }
    // Owner may still be constructing Flutter, or may have exited/crashed.
    // Polling the held mutex closes the stale-owner/startup race.
    if (GetTickCount64() >= deadline) break;
    Sleep(25);
  } while (GetTickCount64() <= deadline);
  if (sender) DestroyWindow(sender);
  return result;
}

bool SingleInstance::SameUserAndSession(DWORD process_id) const {
  DWORD session = 0;
  if (!process_id || !ProcessIdToSessionId(process_id, &session) ||
      session != session_id_) return false;
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
  if (!process) return false;
  const auto sid = UserSid(process);
  CloseHandle(process);
  return !sid.empty() && sid == user_sid_;
}

HWND SingleInstance::FindPrimaryWindow() const {
  struct Search { const SingleInstance* instance; HWND found; } search{this, nullptr};
  EnumWindows([](HWND window, LPARAM parameter) -> BOOL {
    auto* search = reinterpret_cast<Search*>(parameter);
    if (!GetPropW(window, search->instance->window_property_.c_str())) return TRUE;
    DWORD process_id = 0;
    GetWindowThreadProcessId(window, &process_id);
    if (!search->instance->SameUserAndSession(process_id)) return TRUE;
    search->found = window;
    return FALSE;
  }, reinterpret_cast<LPARAM>(&search));
  return search.found;
}

bool SingleInstance::AttachWindow(HWND window) {
  if (!owns_mutex_ || !window || window_) return false;
  if (!SetPropW(window, window_property_.c_str(),
                reinterpret_cast<HANDLE>(static_cast<ULONG_PTR>(1)))) {
    return false;
  }
  window_ = window;
  return true;
}

void SingleInstance::DetachWindow() {
  if (window_) RemovePropW(window_, window_property_.c_str());
  window_ = nullptr;
}

bool SingleInstance::IsValidSender(HWND sender) const {
  if (!owns_mutex_ || !IsWindow(sender)) return false;
  DWORD process_id = 0;
  GetWindowThreadProcessId(sender, &process_id);
  return process_id != GetCurrentProcessId() && SameUserAndSession(process_id);
}

void SingleInstance::RestoreAndActivate(HWND window) {
  if (!IsWindow(window)) return;
  ShowWindow(window, IsIconic(window) ? SW_RESTORE : SW_SHOW);
  // Preserve maximized state and normal placement; also reveals a hidden/tray
  // workspace. No synthetic keystrokes or global foreground-lock changes.
  const HWND popup = GetLastActivePopup(window);
  const HWND target = popup != window && IsWindowVisible(popup) ? popup : window;
  if (!SetForegroundWindow(target)) {
    FLASHWINFO flash{sizeof(FLASHWINFO), target, FLASHW_TRAY, 3, 0};
    FlashWindowEx(&flash);
  }
}

}  // namespace windows_activation
