#include "../windows_close_request.h"

#include <cassert>
#include <iostream>
#include <memory>
#include <vector>

int main() {
  using windows_lifecycle::CloseRequest;
  std::vector<CloseRequest::Token> posted;
  CloseRequest request([&posted](CloseRequest::Token token) {
    posted.push_back(token);
    return true;
  });

  assert(!request.Start(0));
  assert(request.Start(100));
  assert(!request.Start(101));  // Repeated Alt+F4 shares the in-flight request.
  assert(!request.TakeApproval(100));  // Never close before Dart has replied.
  request.Complete(99, true);
  assert(posted.empty());
  request.Complete(100, false);  // Save error, cancellation or missing handler.
  assert(posted.empty());
  assert(!request.TakeApproval(100));
  assert(request.Start(101));  // A later close can retry.
  request.Complete(100, true);  // A stale reply cannot approve the new request.
  assert(posted.empty());
  request.Complete(101, true);
  assert(posted.size() == 1 && posted.back() == 101);
  assert(!request.Start(102));  // Keep single-flight until posted message runs.
  request.Complete(101, true);
  request.Complete(101, false);
  assert(posted.size() == 1);
  assert(!request.TakeApproval(100));
  assert(request.TakeApproval(101));
  assert(!request.TakeApproval(101));  // Exactly one close authorization.

  CloseRequest failed_post([](CloseRequest::Token) { return false; });
  assert(failed_post.Start(200));
  failed_post.Complete(200, true);
  assert(!failed_post.TakeApproval(200));
  assert(failed_post.Start(201));  // A failed PostMessage does not trap the UI.

  auto window = std::make_shared<CloseRequest>(
      [&posted](CloseRequest::Token token) {
        posted.push_back(token);
        return true;
      });
  assert(window->Start(300));
  auto outstanding = window;
  window->Deactivate();  // WM_DESTROY happens before the late Dart reply.
  window.reset();
  outstanding->Complete(300, true);
  assert(posted.size() == 1);  // No post to a destroyed/reused HWND.
  assert(!outstanding->TakeApproval(300));
  assert(!outstanding->Start(301));

  CloseRequest queued([&posted](CloseRequest::Token token) {
    posted.push_back(token);
    return true;
  });
  assert(queued.Start(400));
  queued.Complete(400, true);
  queued.Deactivate();
  assert(!queued.TakeApproval(400));  // Teardown also invalidates queued posts.
  CloseRequest replacement([](CloseRequest::Token) { return true; });
  assert(replacement.Start(401));
  replacement.Complete(401, true);
  assert(!replacement.TakeApproval(400));  // Unique process-wide HWND tokens.
  assert(replacement.TakeApproval(401));

  std::cout << "Windows close request contracts passed\n";
}
