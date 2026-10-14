# 歌词页屏幕常亮与退出应用 · songloft-org/songloft#520

2026-10-14。最初批次只实现常亮配置；后续退出修复记录见下方，早期验证对象保留。

## 后续：Android 退出与通知停止

2026-10-15 完成交付检查；本批调查/实现跨 10 月 14–15 日。

基线 `3860205b0d8cf8449d8cf31746c254ef597c55e3` + 未提交工作树。源码 SHA-256 `a4096442900eb8a067cad0ca8305056737b1400e3124f7164fcb59514c95b2bb`（算法/范围见验收 JSON）。用户已确认开发版开启歌词常亮后正常，本批处理其后续退出反馈。

- 「设置 → 账户 → 退出应用」停止音频、隐藏悬浮歌词、停止 Bundle 后端，再关闭 Android 任务与进程，保留登录和本机偏好；重复点击共用一次清理，单个步骤报错或超时不阻止其他清理。划掉任务调用同一流程。Home/普通切后台仍继续播放。
- 标准媒体 STOP 在 audio_service 0.18.19 的 Android 12 及以下进入普通通知按钮；Android 13+ 自动转换为系统自定义 STOP。额外自定义按钮会使旧系统缺按钮，重复注册则在新系统重复。通知停止只停止播放并移除通知，保留正在浏览的界面。
- 原生结束任务走既有悬浮歌词 `exec` 的 `exitApp` 子命令，无新增 MethodChannel 方法名或原生插件。旧 APK 不识别子命令时退回停止资源、SystemNavigator.pop 与结束进程；完整任务移除以新 APK 为准。新入口仅 Android 显示。
- 停止状态拒绝底层迟到 ready/completed 与旧异步加载，避免通知复活/自动切歌。本地 [audio_service 0.18.19 补丁](../../third_party/audio_service/README.md)在 stop 时先移除前台状态并释放唤醒锁：界面仍绑定服务时，不能依赖 onDestroy 才清理。此原生修复需要完整 APK。
- Linux / Flutter 3.44.8 / Dart 3.12.2：格式、静态分析、完整 708 项测试与 Debug APK 编译通过。停止回归覆盖迟到事件、完成回调、初始化等待与待完成音源；删除停止状态后 2 项目标回归失败，缺少标准 STOP 时 4 项失败。日志 `/tmp/songloft-520-exit-flutter-{analyze-final,tests-final,apk4}.log`、`/tmp/songloft-520-stop-lifecycle-{final,negative}.log`。本批工作树标识/APK 哈希与验收清单见 `/tmp/songloft-520-exit-validation.json`。
- Android API 34 模拟器，明确 x86_64 安装，1080×1920/density 440，隔离服务器与合成音频：通知面板只有一个 STOP；播放中点击停止后 playing=false、媒体失活、活动通知=0、startRequested=false，界面绑定记录可保留且重新点歌恢复播放。播放中账户退出与从最近任务划掉后 PID、活动服务和通知归零；重开恢复登录。证据 `/tmp/songloft-520-flutter-{stop-before,stop-after,replay,exit-before,exit-after,task-before,task-after}-final.json`。
- Not run：鸿蒙 4.2 真机、Android 12 及以下实际通知布局、Bundle Android 内嵌后端实际退出、实际开启悬浮歌词时退出、iOS/桌面原生构建；标准 APK 和模拟器不能替代这些验收。2026-10-15 用户已授权提交、推送和回复 Issue；最终 SHA、开发包与 CI 状态以 Git/同一 SHA 工作流为准，本批不打正式版 tag。

## 行为

「设置 → 播放设置 → 歌词页屏幕常亮」位于自动进入歌词选项之后。默认关闭，偏好 `player_lyrics_keep_screen_on` 仅保存到本机。手机仅在歌词页可见时保持亮屏；宽屏为并列歌词。暂停仍生效，返回封面、覆盖播放器路由、离开页面或应用退后台时释放，前台恢复可见歌词时重新申请。

复用已由 `media_kit_video` 引入并注册的 `wakelock_plus 1.5.2`；只提升为直接依赖，不新增原生插件或 Kotlin 方法。歌词和原生视频共用带所有者集合、串行原生写入的控制器，释放歌词不会取消视频请求。浏览器拒绝或不支持时不影响播放。

## 验证对象与结果

- 仓库：`songloft-org/songloft-player`，基线 `57db9766ac36b58f136b4e7ae41a2d1c51a079ce` + 未提交工作树。源码 SHA-256 `4ee8dddc9c095b05e25cd891e1ff7e66b245dfe902c9bd97d9d02c6ec1be863d`；算法和路径范围见 `/tmp/songloft-520-validation.json`（`git diff --binary` 加范围内未跟踪文件路径及内容，文档不计入源码标识）。
- 环境：Linux、Flutter 3.41.5、Web embedded；浏览器为 Docker `browserless/chrome:latest`。UI 使用隔离服务端/临时数据库，未操作现有用户数据。
- `dart format lib/ test/`、`flutter analyze --no-pub`、`flutter test --no-pub --reporter expanded` 通过，完整测试 696 项；新测试包含缺省/恢复、初始化竞态、快速写入、前后台、路由覆盖、卸载、歌词/视频并发所有权和迟到原生调用。
- `flutter build web --no-pub --no-web-resources-cdn --dart-define=DEPLOY_MODE=embedded --output /tmp/songloft-520-flutter-web` 通过。沿真实 UI 登录并进入播放设置、开启常亮，本机 `flutter.player_lyrics_keep_screen_on` 实际保存为 `true`，页面异常为空；截图 `/tmp/songloft-520-flutter-toggle.png`，结果 `/tmp/songloft-520-flutter-settings-ui.json`。
- 日志：`/tmp/songloft-520-flutter-{focused,analyze,build,tests-final}.log`。格式、差异及 UTF-8 检查通过。
- Not run：Android/iOS/桌面的真实熄屏和视频交接验收，无连接设备；Flutter Web 的物理熄屏与系统电源策略未验收，截图/持久化不能替代该行为验证。

上述验证执行于提交前；用户随后授权提交、推送及回复 Issue。最终提交以 Git 记录为准，推送后的 CI/开发包状态以同一 SHA 的工作流为准；本批不打正式版 tag。现有 v2.13.1 安装包不包含本批功能。报告人的鸿蒙 4.2 截图与 Flutter Android 版一致，安装方式仍需本人确认；Lynx HAP 面向 HarmonyOS NEXT，不能将其直接当成 4.2 的替代安装包。
