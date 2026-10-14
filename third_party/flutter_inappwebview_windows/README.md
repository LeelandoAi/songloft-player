# Windows WebView2 本地补丁

英文版见 [README.en.md](README.en.md)。本目录来自 pub.dev 的 `flutter_inappwebview_windows` **0.6.0**，保留其 `lib/`、`windows/`、`pubspec.yaml` 和 Apache-2.0 `LICENSE`；主应用通过 `dependency_overrides` 引用。上游：[flutter_inappwebview](https://github.com/pichillilorenzo/flutter_inappwebview/tree/master/flutter_inappwebview_windows)。

## 补丁范围

关联 [songloft-org/songloft#499](https://github.com/songloft-org/songloft/issues/499)。现有 runner 移动 `CustomPlatformView` HWND，但上游没有调用 WebView2 控制器的 `NotifyParentWindowPositionChanged`。此通知独立于 HWND 的位置和控制器 Bounds，[微软文档](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2controller#notifyparentwindowpositionchanged)要求宿主移动时通知控制器，以更新无障碍及部分对话框定位。缺失通知是已确认的接口缺口，是否导致报告人的桌面右键残留仍待双屏实测。

改动仅在原生 Windows 层：

- `windows/custom_platform_view/parent_window_position_observer.h`：通过 comctl32 子类化辅助 HWND，默认消息处理完成后，在 `WM_WINDOWPOSCHANGED` 调用控制器通知；兼容 runner 移动和插件 `setPosition`。通知期间持有临时 COM 引用，重入销毁时跳过通知。
- `windows/in_app_webview/in_app_webview.{cpp,h}`：创建 composition WebView 时安装 observer，销毁时先解绑；`WM_NCDESTROY` 也清理回调。存储已观察的 HWND，解绑不依赖退出时 `get_ParentWindow` 是否成功。
- `windows/CMakeLists.txt`：链接 `comctl32`。

导入时 Git 统一 LF，另清理 5 处上游行尾空格。上游 Dart API、包名及版本保持 0.6.0。更新上游时先逐项比较以上文件，并保留同等回归检查；不要仅因能编译就删除补丁。

## 验证

在客户端根目录运行：

```sh
cmake -S test/native/windows -B build/native-webview-tests
cmake --build build/native-webview-tests --config Release
ctest --test-dir build/native-webview-tests -C Release --output-on-failure
```

Linux 可运行 7 个窗口坐标和 8 个通知／生命周期模拟场景。Windows 额外执行真实 HWND/comctl32 消息与解绑检查，其控制器仍是探针，并非真正 WebView2。标准版和 Bundle 版 Windows CI 在打包前运行上述检查，随后编译完整客户端；它们不替代 [Windows 双屏验收](../../docs/cn/platform-notes.md#windows-插件与桌面右键验收)。
