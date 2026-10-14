#ifndef SONGLOFT_PARENT_WINDOW_POSITION_OBSERVER_H_
#define SONGLOFT_PARENT_WINDOW_POSITION_OBSERVER_H_

#include <windows.h>
#include <commctrl.h>

namespace flutter_inappwebview_plugin {

// The HWND and the WebView2 controller have separate position state. Observe
// the actual composition parent so both runner moves and plugin setPosition
// calls update the controller, after DefWindowProc updates child windows.
template <typename Controller>
LRESULT CALLBACK ParentWindowPositionObserver(HWND window, UINT message,
                                              WPARAM wparam, LPARAM lparam,
                                              UINT_PTR id, DWORD_PTR data) {
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(window, ParentWindowPositionObserver<Controller>, id);
  }
  auto* controller = message == WM_WINDOWPOSCHANGED
                         ? reinterpret_cast<Controller*>(data)
                         : nullptr;
  if (controller) {
    // Default processing can reenter and destroy the WebView. Keep the COM
    // object alive, but do not notify it after its observer was detached.
    controller->AddRef();
  }
  const LRESULT result = DefSubclassProc(window, message, wparam, lparam);
  if (controller) {
    DWORD_PTR current = 0;
    if (GetWindowSubclass(window, ParentWindowPositionObserver<Controller>, id,
                          &current) && current == data) {
      controller->NotifyParentWindowPositionChanged();
    }
    controller->Release();
  }
  return result;
}

template <typename Controller>
bool ObserveParentWindowPosition(HWND window, Controller* controller) {
  return SetWindowSubclass(window, ParentWindowPositionObserver<Controller>, 1,
                           reinterpret_cast<DWORD_PTR>(controller)) != FALSE;
}

template <typename Controller>
void StopObservingParentWindowPosition(HWND window, Controller* controller) {
  // A destroyed HWND can be reused before its old WebView wrapper is released.
  // Only detach this controller's observer, never a new view on the same handle.
  DWORD_PTR current = 0;
  if (GetWindowSubclass(window, ParentWindowPositionObserver<Controller>, 1,
                        &current) &&
      current == reinterpret_cast<DWORD_PTR>(controller)) {
    RemoveWindowSubclass(window, ParentWindowPositionObserver<Controller>, 1);
  }
}

}  // namespace flutter_inappwebview_plugin

#endif  // SONGLOFT_PARENT_WINDOW_POSITION_OBSERVER_H_
