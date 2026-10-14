# Local Windows WebView2 patch

See [README.md](README.md) for Chinese. This directory vendors `flutter_inappwebview_windows` **0.6.0** from pub.dev, retaining its `lib/`, `windows/`, `pubspec.yaml`, and Apache-2.0 `LICENSE`. The application uses it through `dependency_overrides`. Upstream: [flutter_inappwebview](https://github.com/pichillilorenzo/flutter_inappwebview/tree/master/flutter_inappwebview_windows).

## Patch scope

Related to [songloft-org/songloft#499](https://github.com/songloft-org/songloft/issues/499). The runner moves the `CustomPlatformView` HWND, but upstream never calls the WebView2 controller's `NotifyParentWindowPositionChanged`. This notification is separate from HWND position and controller Bounds. [Microsoft's documentation](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2controller#notifyparentwindowpositionchanged) requires notifying the controller when its host moves, for accessibility and certain dialogs. The missing notification is a confirmed integration gap; whether it causes the reporter's blocked desktop context menu still requires a dual-monitor test.

Only the native Windows layer changes:

- `windows/custom_platform_view/parent_window_position_observer.h`: subclass the auxiliary HWND with comctl32 and notify the controller on `WM_WINDOWPOSCHANGED` after default processing. This covers both runner movement and plugin `setPosition`. A temporary COM reference protects notification; reentrant destruction skips it.
- `windows/in_app_webview/in_app_webview.{cpp,h}`: attach the observer when a composition WebView is created and detach before destruction; `WM_NCDESTROY` also removes it. Store the observed HWND so teardown does not depend on a successful `get_ParentWindow` during shutdown.
- `windows/CMakeLists.txt`: link `comctl32`.

Git normalizes imported line endings to LF; five upstream trailing-space occurrences were also removed. Upstream Dart APIs, package name, and version remain at 0.6.0. When updating upstream, compare these files individually and retain equivalent regression checks; successful compilation alone is insufficient to remove the patch.

## Validation

Run from the client root:

```sh
cmake -S test/native/windows -B build/native-webview-tests
cmake --build build/native-webview-tests --config Release
ctest --test-dir build/native-webview-tests -C Release --output-on-failure
```

Linux runs seven simulated window-coordinate scenarios and eight notification/lifecycle scenarios. Windows additionally checks real HWND/comctl32 message delivery and detachment, with a probe controller rather than actual WebView2. Standard and Bundle Windows CI run these checks before packaging, then compile the complete client. They do not replace [Windows dual-monitor acceptance](../../docs/en/platform-notes.md#windows-plugin-and-desktop-context-menu-acceptance).
