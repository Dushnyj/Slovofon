#ifndef RUNNER_WINDOWS_INSTALLATION_TASK_H_
#define RUNNER_WINDOWS_INSTALLATION_TASK_H_

#include <cstdint>
#include <functional>
#include <mutex>
#include <optional>
#include <utility>

#include "windows_installation_info.h"

namespace windows_installation {

// Contains no Flutter objects or owning window pointers. The native worker
// keeps this state alive after the window closes. Notifier is nonblocking and
// must not re-enter the state; production uses only PostMessage(HWND, token).
class InstallationTask {
 public:
  using Token = std::uintptr_t;
  using Notifier = std::function<bool(Token)>;

  explicit InstallationTask(Notifier notifier) : notifier_(std::move(notifier)) {}

  bool Start(Token token) {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (!active_ || running_ || waiting_ || token == 0) return false;
    token_ = token;
    running_ = true;
    waiting_ = true;
    completed_.reset();
    return true;
  }

  // Only for failure before an OS worker was started (timer/allocation/thread).
  void StartFailed(Token token) {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (token != token_) return;
    running_ = false;
    waiting_ = false;
    completed_.reset();
  }

  void Complete(Token token, InstallationInfo info) {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (token != token_ || !running_) return;
    running_ = false;
    if (!active_ || !waiting_) return;
    completed_ = std::move(info);
    // Deactivate clears this callback under the same lock, so it cannot post
    // to a destroyed/reused HWND after the window deactivates. No I/O is locked.
    // Failed PostMessage leaves the platform timer responsible for completion.
    if (notifier_) notifier_(token);
  }

  std::optional<InstallationInfo> TakeCompleted(Token token) {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (!active_ || !waiting_ || token != token_ || !completed_) {
      return std::nullopt;
    }
    waiting_ = false;
    auto result = std::move(completed_);
    completed_.reset();
    return result;
  }

  void Expire(Token token) {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (token != token_) return;
    waiting_ = false;
    completed_.reset();
    // A timed-out OS call is not cancelled. Keep single-flight while it runs.
  }

  void Deactivate() {
    const std::lock_guard<std::mutex> lock(mutex_);
    active_ = false;
    waiting_ = false;
    completed_.reset();
    notifier_ = nullptr;
  }

 private:
  std::mutex mutex_;
  Notifier notifier_;
  Token token_ = 0;
  bool active_ = true;
  bool running_ = false;
  bool waiting_ = false;
  std::optional<InstallationInfo> completed_;
};

}  // namespace windows_installation

#endif  // RUNNER_WINDOWS_INSTALLATION_TASK_H_
