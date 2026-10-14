# audio_service 本地补丁

来源：pub.dev `audio_service 0.18.19`，保留 MIT 许可证和原始运行时源码（`lib/`、`android/`、`darwin/`）。`audio_service_web` 与 platform interface 仍使用上游依赖。英文说明见 [README.en.md](README.en.md)。

关联 [songloft-org/songloft#520](https://github.com/songloft-org/songloft/issues/520)：`androidStopForegroundOnPause=false` 时，应用界面通过 MediaBrowser 仍绑定服务，`stopSelf()` 不立即触发 `onDestroy()`。上游 `stop()` 直接取消尚在前台的通知，系统仍保留通知与播放唤醒锁。

除移除上游个别行末空白外，仅修改 Android `AudioService.stop()`：先 `ServiceCompat.stopForeground(..., STOP_FOREGROUND_REMOVE)`，释放播放唤醒锁，再执行原来的媒体会话注销与 `stopSelf()`。暂停策略保持不变；再次播放仍走原来的前台启动流程。Dart handler 同时拒绝停止后的迟到事件与加载结果。

此补丁需要完整 APK，Dart 热更新无法改变旧壳的原生服务。升级上游时对照 `stop()` / `onDestroy()` / 前台与唤醒锁生命周期，确认修复后再移除 override。验收记录见 [Issue 520](../../docs/cn/issue-520.md)。
