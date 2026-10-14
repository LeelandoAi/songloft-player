#include "parent_window_position_observer.h"

#include <iostream>
#include <stdexcept>

namespace {

void Require(bool condition, const char* message) {
  if (!condition) {
    throw std::runtime_error(message);
  }
}

// This test uses real HWNDs and comctl32 message delivery. The controller is a
// probe: a Windows/WebView2 dual-monitor test is still required for acceptance.
struct ControllerProbe {
  HWND parent;
  ULONG references = 1;
  int notifications = 0;
  RECT notified_bounds = {};
  ULONG AddRef() { return ++references; }
  ULONG Release() { return --references; }
  HRESULT NotifyParentWindowPositionChanged() {
    ++notifications;
    return GetWindowRect(parent, &notified_bounds) ? S_OK : E_FAIL;
  }
};

struct NativeWindow {
  HWND handle;
  ~NativeWindow() {
    if (handle) {
      DestroyWindow(handle);
    }
  }
};

}  // namespace

int main() {
  using flutter_inappwebview_plugin::ObserveParentWindowPosition;
  using flutter_inappwebview_plugin::StopObservingParentWindowPosition;
  try {
    WNDCLASSW window_class = {};
    window_class.lpfnWndProc = DefWindowProcW;
    window_class.hInstance = GetModuleHandleW(nullptr);
    window_class.lpszClassName = L"SongloftPositionObserverTest";
    Require(RegisterClassW(&window_class) != 0, "register window class failed");
    NativeWindow owner{CreateWindowExW(
        0, window_class.lpszClassName, L"", 0, 100, 100, 800, 600, nullptr,
        nullptr, window_class.hInstance, nullptr)};
    NativeWindow parent{CreateWindowExW(
        0, window_class.lpszClassName, L"", 0, 120, 150, 800, 600, owner.handle,
        nullptr, window_class.hInstance, nullptr)};
    Require(owner.handle && parent.handle, "create native windows failed");
    ControllerProbe controller{parent.handle};
    Require(ObserveParentWindowPosition(parent.handle, &controller),
            "attach real subclass failed");

    Require(SetWindowPos(parent.handle, nullptr, -1800, -830, 0, 0,
                         SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE) != 0,
            "native move failed");
    RECT bounds = {};
    Require(GetWindowRect(parent.handle, &bounds) != 0, "query native bounds failed");
    Require(controller.notifications > 0 &&
                controller.notified_bounds.left == bounds.left &&
                controller.notified_bounds.top == bounds.top &&
                bounds.left == -1800 && bounds.top == -830,
            "real WM_WINDOWPOSCHANGED must notify after position is applied");
    Require(controller.references == 1, "native callback leaked a COM reference");

    const int notifications = controller.notifications;
    StopObservingParentWindowPosition(parent.handle, &controller);
    SetWindowPos(parent.handle, nullptr, 100, 200, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    Require(controller.notifications == notifications,
            "explicit teardown must remove the native callback");
    Require(ObserveParentWindowPosition(parent.handle, &controller),
            "reattach real subclass failed");
    Require(DestroyWindow(parent.handle) != 0, "native destruction failed");
    parent.handle = nullptr;
    Require(controller.notifications == notifications && controller.references == 1,
            "native destruction must detach without notifying or leaking");
    std::cout << "Real Win32 parent position and teardown tests passed\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
