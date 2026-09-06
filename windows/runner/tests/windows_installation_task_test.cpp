#include "../windows_installation_task.h"

#include <cassert>
#include <iostream>
#include <memory>
#include <vector>

int main() {
  using namespace windows_installation;
  using Token = InstallationTask::Token;
  InstallationInfo setup;
  setup.classification = {Kind::kSetup, Scope::kUser};
  setup.directory = L"D:\\Apps\\Slovofon";
  std::vector<Token> posted;
  InstallationTask task([&posted](Token token) {
    posted.push_back(token);
    return true;
  });

  assert(!task.Start(0));
  assert(task.Start(100));
  assert(!task.Start(101));
  assert(!task.TakeCompleted(100));
  task.Complete(99, setup);
  assert(posted.empty());
  assert(!task.Start(101));
  task.Complete(100, setup);
  assert(posted.size() == 1 && posted.back() == 100);
  assert(!task.TakeCompleted(99));
  assert(!task.Start(101));  // Reply not yet consumed by the platform thread.
  const auto completed = task.TakeCompleted(100);
  assert(completed && completed->classification.kind == Kind::kSetup);
  assert(completed->directory == setup.directory);
  assert(!task.TakeCompleted(100));  // Never reply twice.

  // Timeout is a response deadline, not permission to accumulate OS workers.
  assert(task.Start(101));
  task.Expire(100);  // An old queued WM_TIMER cannot cancel a new request.
  assert(!task.Start(102));
  task.Expire(101);
  assert(!task.TakeCompleted(101));
  assert(!task.Start(102));  // Old I/O is still running after the deadline.
  task.Complete(101, setup);
  assert(posted.size() == 1);  // Late completion does not post or cache a reply.
  assert(!task.TakeCompleted(101));
  assert(task.Start(102));
  task.Complete(100, setup);  // An old worker token cannot complete a new one.
  assert(!task.TakeCompleted(102));
  task.Complete(102, setup);
  task.Expire(102);  // Completion was posted, but deadline won before dispatch.
  assert(!task.TakeCompleted(102));

  // Timer/allocation/thread-start failure can release the gate immediately.
  assert(task.Start(103));
  task.StartFailed(102);
  assert(!task.Start(104));
  task.StartFailed(103);
  assert(task.Start(104));
  task.StartFailed(104);

  // Failed PostMessage is completed by the native timer, not by the worker.
  size_t failed_posts = 0;
  InstallationTask failed_notifier([&failed_posts](Token) {
    ++failed_posts;
    return false;
  });
  assert(failed_notifier.Start(200));
  failed_notifier.Complete(200, setup);
  assert(failed_posts == 1);
  assert(!failed_notifier.Start(201));
  failed_notifier.Expire(200);
  assert(!failed_notifier.TakeCompleted(200));
  assert(failed_notifier.Start(201));

  // Window teardown releases its state ownership without waiting on a worker.
  // A worker holding the last reference must neither post nor touch Flutter.
  size_t closed_window_posts = 0;
  auto window = std::make_shared<InstallationTask>([&closed_window_posts](Token) {
    ++closed_window_posts;
    return true;
  });
  auto worker = window;
  assert(window->Start(300));
  window->Deactivate();
  window.reset();
  worker->Complete(300, setup);
  assert(closed_window_posts == 0);
  assert(!worker->TakeCompleted(300));
  assert(!worker->Start(301));
  worker.reset();

  // A queued token for a closed HWND is harmless to a newly created window.
  InstallationTask old_window([](Token) { return true; });
  InstallationTask new_window([](Token) { return true; });
  assert(old_window.Start(400));
  old_window.Complete(400, setup);
  old_window.Deactivate();
  assert(new_window.Start(401));
  assert(!new_window.TakeCompleted(400));
  new_window.Complete(401, setup);
  assert(new_window.TakeCompleted(401));

  std::cout << "Windows installation task lifecycle tests passed.\n";
}
