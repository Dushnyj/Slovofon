#ifndef RUNNER_WINDOWS_CLOSE_REQUEST_H_
#define RUNNER_WINDOWS_CLOSE_REQUEST_H_

#include <cstdint>
#include <functional>
#include <mutex>
#include <utility>

namespace windows_lifecycle {

// The result callback owns only this state, never a FlutterWindow or messenger.
// Notifier must only post a message: it must not destroy or re-enter the window.
class CloseRequest {
 public:
  using Token = std::uintptr_t;
  using Notifier = std::function<bool(Token)>;

  explicit CloseRequest(Notifier notifier) : notifier_(std::move(notifier)) {}

  bool Start(Token token) {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (!active_ || pending_ || token == 0) return false;
    token_ = token;
    pending_ = true;
    approved_ = false;
    return true;
  }

  void Complete(Token token, bool approved) {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (!active_ || !pending_ || approved_ || token != token_) return;
    approved_ = approved;
    if (!approved || !notifier_ || !notifier_(token)) {
      pending_ = false;
      approved_ = false;
    }
  }

  bool TakeApproval(Token token) {
    const std::lock_guard<std::mutex> lock(mutex_);
    if (!active_ || !pending_ || !approved_ || token != token_) return false;
    pending_ = false;
    approved_ = false;
    return true;
  }

  void Deactivate() {
    const std::lock_guard<std::mutex> lock(mutex_);
    active_ = false;
    pending_ = false;
    approved_ = false;
    notifier_ = nullptr;
  }

 private:
  std::mutex mutex_;
  Notifier notifier_;
  Token token_ = 0;
  bool active_ = true;
  bool pending_ = false;
  bool approved_ = false;
};

}  // namespace windows_lifecycle

#endif  // RUNNER_WINDOWS_CLOSE_REQUEST_H_
