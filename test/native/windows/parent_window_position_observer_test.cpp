#include "parent_window_position_observer.h"

#include <iostream>
#include <stdexcept>

struct FakeWindow {
  SUBCLASSPROC observer = nullptr;
  UINT_PTR id = 0;
  DWORD_PTR data = 0;
  bool installable = true;
  bool destroy_during_default = false;
  int default_calls = 0;
  int applied_x = 0;
  int target_x = 0;
};

namespace {

void Require(bool condition, const char* message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

struct Controller {
  explicit Controller(HWND parent) : parent(parent) {}
  HWND parent;
  int references = 1;
  int notifications = 0;
  int cached_x = 0;
  void AddRef() { ++references; }
  void Release() { --references; }
  void NotifyParentWindowPositionChanged() {
    Require(parent->default_calls > 0,
            "controller notification must follow default window processing");
    ++notifications;
    cached_x = parent->applied_x;
  }
};

using flutter_inappwebview_plugin::ObserveParentWindowPosition;
using flutter_inappwebview_plugin::StopObservingParentWindowPosition;

LRESULT Dispatch(HWND window, UINT message) {
  if (window->observer) {
    return window->observer(window, message, 0, 0, window->id, window->data);
  }
  return DefSubclassProc(window, message, 0, 0);
}

void TestPositionNotification() {
  FakeWindow window;
  Controller controller(&window);
  Require(ObserveParentWindowPosition(&window, &controller), "attach failed");
  window.target_x = -1920;
  Require(Dispatch(&window, WM_WINDOWPOSCHANGED) == 42,
          "subclass must preserve the default result");
  Require(controller.cached_x == -1920 && controller.notifications == 1,
          "moving the HWND must also update the controller's position state");
  window.target_x = 100;
  Dispatch(&window, WM_WINDOWPOSCHANGED);
  Require(controller.cached_x == 100 && controller.notifications == 2,
          "moving back must update the same controller without recreation");
  Require(controller.references == 1, "notifications must not leak COM refs");
}

void TestUnrelatedMessage() {
  FakeWindow window;
  Controller controller(&window);
  ObserveParentWindowPosition(&window, &controller);
  Dispatch(&window, 123);
  Require(window.default_calls == 1 && controller.notifications == 0 &&
              controller.references == 1,
          "unrelated messages must pass through without touching the controller");
}

void TestDetachBeforeControllerRelease() {
  FakeWindow window;
  {
    Controller controller(&window);
    ObserveParentWindowPosition(&window, &controller);
    StopObservingParentWindowPosition(&window, &controller);
  }
  Dispatch(&window, WM_WINDOWPOSCHANGED);
  Require(!window.observer && window.default_calls == 1,
          "detached observer must never target a released controller");
}

void TestWindowDestruction() {
  FakeWindow window;
  Controller controller(&window);
  ObserveParentWindowPosition(&window, &controller);
  Dispatch(&window, WM_NCDESTROY);
  Require(!window.observer && controller.notifications == 0,
          "window destruction must remove the callback");
  StopObservingParentWindowPosition(&window, &controller);
}

void TestReentrantDestruction() {
  FakeWindow window;
  Controller controller(&window);
  ObserveParentWindowPosition(&window, &controller);
  window.destroy_during_default = true;
  Dispatch(&window, WM_WINDOWPOSCHANGED);
  Require(!window.observer && controller.notifications == 0 &&
              controller.references == 1,
          "reentrant teardown must skip notification and release the temporary ref");
}

void TestFailedAttach() {
  FakeWindow window;
  Controller controller(&window);
  window.installable = false;
  Require(!ObserveParentWindowPosition(&window, &controller),
          "failed subclass installation must be reported");
  Dispatch(&window, WM_WINDOWPOSCHANGED);
  Require(controller.notifications == 0 && controller.references == 1,
          "failed attach must not retain or notify the controller");
}

void TestIndependentControllers() {
  FakeWindow first;
  FakeWindow second;
  Controller first_controller(&first);
  Controller second_controller(&second);
  ObserveParentWindowPosition(&first, &first_controller);
  ObserveParentWindowPosition(&second, &second_controller);
  first.target_x = -800;
  Dispatch(&first, WM_WINDOWPOSCHANGED);
  Require(first_controller.cached_x == -800 &&
              second_controller.notifications == 0,
          "one WebView's HWND must not notify another controller");
}

void TestReusedWindowHandle() {
  FakeWindow window;
  Controller old_controller(&window);
  ObserveParentWindowPosition(&window, &old_controller);
  Dispatch(&window, WM_NCDESTROY);
  Controller new_controller(&window);
  ObserveParentWindowPosition(&window, &new_controller);
  StopObservingParentWindowPosition(&window, &old_controller);
  window.target_x = -300;
  Dispatch(&window, WM_WINDOWPOSCHANGED);
  Require(new_controller.notifications == 1 &&
              new_controller.cached_x == -300 && old_controller.notifications == 0,
          "late teardown must not detach a new controller on a reused HWND");
}

}  // namespace

BOOL SetWindowSubclass(HWND window, SUBCLASSPROC callback, UINT_PTR id,
                       DWORD_PTR data) {
  if (!window->installable) {
    return FALSE;
  }
  window->observer = callback;
  window->id = id;
  window->data = data;
  return TRUE;
}

BOOL RemoveWindowSubclass(HWND window, SUBCLASSPROC callback, UINT_PTR id) {
  if (window->observer != callback || window->id != id) {
    return FALSE;
  }
  window->observer = nullptr;
  window->data = 0;
  return TRUE;
}

BOOL GetWindowSubclass(HWND window, SUBCLASSPROC callback, UINT_PTR id,
                      DWORD_PTR* data) {
  if (window->observer != callback || window->id != id) {
    return FALSE;
  }
  *data = window->data;
  return TRUE;
}

LRESULT DefSubclassProc(HWND window, UINT message, WPARAM, LPARAM) {
  ++window->default_calls;
  if (message == WM_WINDOWPOSCHANGED) {
    window->applied_x = window->target_x;
    if (window->destroy_during_default) {
      Dispatch(window, WM_NCDESTROY);
    }
  }
  return 42;
}

int main() {
  try {
    TestPositionNotification();
    TestUnrelatedMessage();
    TestDetachBeforeControllerRelease();
    TestWindowDestruction();
    TestReentrantDestruction();
    TestFailedAttach();
    TestIndependentControllers();
    TestReusedWindowHandle();
    std::cout << "8 WebView2 parent position observer tests passed\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
