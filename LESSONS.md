# Flutter 客户端开发经验

## 范围与来源

记录songloft-org/songloft-player 的 Flutter、Provider、音频、Bundle 与原生宿主行为。流程见 [本地 AI 开发流程](docs/cn/ai-development.md)，公共宿主约束见父仓库。已有 AGENTS 和业务文档仍是权威规则，LESSONS 链接证据而不复制历史全文。

## 记录与升级

每条含规则、适用范围、完整 owner/repo#编号、失败/修复 commit SHA、实际验证和 Done right 示例；没有正确示例时写待补。Seen 只统计不同日期的独立事件，同一事故重复复盘不增加。三个日期后提出升级并标记规范位置，已有铁律/严重问题立即处理。与 [英文版](LESSONS.en.md) 同步，不虚构历史次数、修复结论或设备验收，敏感信息脱敏。

## 条目

### AUDIO-001：通知停止动作要核对 SDK 的分平台转换

- 范围：Flutter audio_service 通知和 Android 系统媒体面板，songloft-org/songloft#520。
- 规则：核对锁定版本的 `createCustomAction`、通知动作列表和分平台转换，不把 Dart 的 customAction 字段当成所有 Android 版本的渲染证明。
- 证据：2026-10-14，基线 `3860205b0d8cf8449d8cf31746c254ef597c55e3` 的停止为显式 customAction，audio_service 0.18.19 的普通通知列表会排除它。本批初版额外加入标准 STOP，API 34 实际 MediaSession 出现两个 Stop；库在 Android 13+ 已会自动把标准 STOP 转为自定义 STOP，双注册多余。
- Done right：只保留标准 STOP，旧通知有停止动作、新面板只有一个停止动作。隔离副本缺少标准动作时 4 项回归失败，修复后通过；最终 API 34/x86_64 原生播放时 Stop 数量为 1，播放中点账户退出后 PID、服务和通知归零。证据 `/tmp/songloft-520-flutter-{single-stop,final-playing,playing-exit}.json`；工作树对象见 [#520 记录](docs/cn/issue-520.md)。
- 停止生命周期补充：真实 API 34 验收发现底层迟到 ready/completed 事件会重新发布播放态，且界面绑定使上游 `stopSelf()` 不触发销毁，前台通知/唤醒锁未释放。Dart 停止状态拒绝旧加载和完成回调；本地 audio_service 0.18.19 在 stop 中先结束前台并释放唤醒锁。停止后通知为 0、媒体失活且 startRequested=false；重新点歌可恢复。本批经验仍计一次。
- 图标补充（2026-10-15，同一 Issue）：覆盖库图标需核对密度配置；新 APK 使用 `drawable-anydpi` 同名矢量资源，保留旧包可解析的 `audio_service_*` 名字。`aapt2 dump resources` 与 API 34 实际通知分别确认打包配置及 X 停止效果，见 [后续记录](docs/cn/issue-520.md)。契约检查覆盖默认标准控件及应用/库两处资源，不能再按 `audio_service_*` 前缀直接跳过。
- Not run：鸿蒙 4.2 实机通知布局；API 34 不能替代该设备验收。
- Seen 1× (2026-10-14)。状态：经验；修复提交以 Git 为准，不把模拟器结果写成真机验收。

### WIN-001：辅助窗口坐标测试不等于 WebView2 桌面输入验收

- 范围：Windows 插件 WebView2、跨屏移动与残留区域鼠标输入。
- 规则：分别核对修复提交、发布版本和实际输入；模拟 Win32 坐标测试及 Windows 编译不能证明旧区域恢复桌面右键。覆盖全屏插件、跨屏往返、不同 DPI、最小化和托盘恢复，记录真实窗口及输入证据。
- 失败：songloft-org/songloft#499 的位置同步补丁 [f1ef7f2](https://github.com/songloft-org/songloft-player/commit/f1ef7f2d8aabf4ba9e9da12cac029f52e211e189) 于 2026-10-06 合入，仅验证模拟窗口及编译，明确未做双屏实测。2026-10-14，报告人[反馈客户端 2.13.1 仍屏蔽右键](https://github.com/songloft-org/songloft/issues/499#issuecomment-6160069251)。标准版 v2.13.1 与父仓库同版 gitlink 都指向 f684da386c75bb8825713b1b14fdd2a3c24d7adb，包含该补丁；不能归为发布遗漏。
- 调查：基线 1cb9b4947cdc1c641507e9486b0a0024fc274e97 下，Linux/GCC 12.2 的原有 7 个模拟场景通过。测试没有 WebView2 控制器或真实鼠标命中。基线 runner 及锁定的 flutter_inappwebview_windows 0.6.0 未调用 `NotifyParentWindowPositionChanged`，属于已确认的接口缺口，但不能据此认定复发根因。
- 候选修复：本次候选补丁将 Windows 平台包 vendoring 到 `third_party/flutter_inappwebview_windows`，辅助 HWND 的 `WM_WINDOWPOSCHANGED` 默认处理后通知控制器；退出与窗口销毁均解绑，防重入与 HWND 复用。Windows 打包 CI 增加真实 HWND/comctl32 检查，ZIP 包含只读 `webview_hit_test.exe`，若仍复发可取证实际命中窗口。范围与验收见[补丁说明](third_party/flutter_inappwebview_windows/README.md)及[平台说明](docs/cn/platform-notes.md#windows-插件与桌面右键验收)。
- Done right：Linux/GCC 12.2 `cmake` 与 `ctest` 通过（7 个原有坐标场景 + 8 个 observer 场景，目录 `/tmp/songloft-499-native-20261014-02`）；隔离副本删掉关键通知或显式解绑后均编译成功且目标测试失败，日志分别在 `/tmp/songloft-499-no-notify-final-20261014/validation.log`、`/tmp/songloft-499-no-detach-final-20261014/validation.log`。这属于破坏检查，不是旧包的 Windows 复现。Flutter 3.41.5 下 13 个插件相关测试、`flutter analyze`、格式和 diff 检查通过。Not run：Windows 完整编译、真实 HWND 检查、诊断工具运行及双屏/WebView2 输入验收；开发机为 Linux，用户也无 Windows 环境，待 CI 构建与报告人测试。
- Seen 1× (2026-10-14)。状态：经验，#499 未完成实机验收。

### LYRIC-001：歌词前景要按实际背景计算对比度

- 范围：Flutter 手机与桌面全屏歌词，songloft-org/songloft#523。
- 证据：2026-10-15，基线 `b80e03b47eefb1aaedf07d611b1d9d3c3d48257b` 的背景叠加封面深色与顶部黑罩，歌词直接使用主题 primary，译文/罗马音再降低透明度。隔离副本使用旧 `lyrics_view.dart` 配合新的柔和背景时，亮色当前行 5.17:1、暗色译文 5.82:1，均未达到本次 7:1 目标；两项渲染回归按预期失败，日志 `/tmp/songloft-523/before-lyrics.log`。
- 规则：背景取色与前景一起设计；半透明文本要先合成到实际背景再测对比度，不能把 Material 在默认 surface 上的保障直接套到任意封面遮罩。缺失/失败封面要核对统一兜底，增强对比度要覆盖动态图层。
- Done right：统一 `PlayerBackdrop` 将取色混合到当前 surface，按背景加强强调色；当前行/翻译/罗马音/逐字共用完整对比度。六种内置配色与极端封面的亮暗渐变采样通过，完整 716 项测试、静态分析、嵌入构建通过；实际浏览器切歌及缺失/失败封面比对见 [#523 记录](docs/cn/issue-523.md)。Not run：原生真机户外验收。
- Seen 1× (2026-10-15)。状态：经验，未提交工作树对象见任务记录；发布状态另按 Git/CI 核对。
